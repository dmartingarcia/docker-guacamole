# Docker Guacamole

Production-ready stack with Guacamole (RDP/VNC), Authelia (2FA authentication), Traefik (reverse proxy), and Let's Encrypt (automatic SSL).

## Quick Start

```bash
make setup          # Generate secrets, build images
nano .env.guacamole # Configure DOMAIN and ACME_EMAIL
make up             # Start services
```

**Available services:**
- Guacamole: `https://guacamole.your-domain.com`
- Authelia: `https://authelia.your-domain.com`
- Traefik: `https://traefik.your-domain.com`

Initial credentials: username/password defined in `authelia/users_database.yml`

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Makefile Commands](#makefile-commands)
- [Configuration](#configuration)
- [Users and Authentication](#users-and-authentication)
- [Security](#security)
- [Guacamole](#guacamole)
- [Operations](#operations)
- [Troubleshooting](#troubleshooting)
- [References](#references)

## Requirements

- **Docker** 20.10+
- **Docker Compose** 1.29+
- **DNS domain** pointing to the server
- **Ports 80 and 443** open
- **OpenSSL** to generate secrets

## Installation

### Step 1: Generate secrets

```bash
chmod +x generate-secrets.sh
./generate-secrets.sh
```

Automatically generates:
- JWT_SECRET (authentication token)
- SESSION_SECRET (Authelia sessions)
- STORAGE_ENCRYPTION_KEY (encryption)
- GUACAMOLE_DB_PASSWORD (PostgreSQL)

### Step 2: Configure domain

```bash
nano .env.guacamole
```

**Change:**
```bash
DOMAIN=your-domain.com        # Must point in DNS
ACME_EMAIL=admin@your-domain.com  # For Let's Encrypt certificates
```

### Step 3: Start services

```bash
make up
make ps  # Verify status
make logs # View logs
```

**Verify:** Services are running in `docker logs guacamole_*`

## Makefile Commands

```bash
make setup      # Initial setup (secrets, images)
make up         # Start services
make down       # Stop services
make logs       # View logs in real time
make ps         # Container status
make restart    # Restart services
make clean      # Delete EVERYTHING (dangerous, deletes data)
make help       # Show help
make build      # Build images without starting
```

**Useful examples:**

```bash
# Monitoring
make logs              # Logs from all services
make ps                # Current status
docker logs guacamole_authelia -f  # Authelia specific logs

# Control
docker restart guacamole_guacamole  # Restart Guacamole
docker restart guacamole_authelia   # Restart Authelia
make restart           # Restart everything

# Data
docker volume ls | grep guacamole   # View volumes
docker exec -it guacamole_postgres psql -U guacamole -d guacamole  # Access database
```

## Configuration

### File structure

```
docker-guacamole/
├── Makefile                      # Automation
├── docker-compose.yml            # Orchestration
├── .env.guacamole                # Environment variables
├── generate-secrets.sh           # Generate secrets
├── init-guacamole.sh             # Initialize database
├── authelia/
│   ├── configuration.yml         # Authelia config
│   └── users_database.yml        # Users
├── traefik/
│   ├── traefik.yml              # Traefik config
│   └── config.yml               # Routes and headers
├── guacamole/
│   └── guacamole.properties     # Guacamole config
└── README.md                     # This file
```

### Services

| Service | Version | Function |
|---------|---------|----------|
| Traefik | 2.10.7 | Reverse proxy + Let's Encrypt SSL |
| Authelia | 4.37.5 | Centralized 2FA authentication |
| Guacamole | 1.5.4 | RDP/VNC access |
| Guacd | 1.5.4 | Guacamole daemon |
| PostgreSQL | 15.6 | Database |

## Users and Authentication

### Create users

Edit `authelia/users_database.yml`:

```yaml
users:
  admin:
    displayname: "Administrator"
    password: "$argon2id$v=19$m=65540,t=3,p=4$..."  # Argon2id hash
    email: admin@your-domain.com
    groups:
      - admin
      - users
  user1:
    displayname: "Regular User"
    password: "$argon2id$v=19$m=65540,t=3,p=4$..."
    email: user1@your-domain.com
    groups:
      - users
```

### Generate password hashes

```bash
./generate-secrets.sh
```

Or manually:

```bash
docker run --rm authelia/authelia:4.37.5 \
  authelia hash-password 'your_password_here'
```

Output:
```
$argon2id$v=19$m=65540,t=3,p=4$...long_hash...
```

### Restart after changes

```bash
docker restart guacamole_authelia
```

## Security

### Guacamole Authentication

**Flow:**

```
User → Traefik → Authelia (validate 2FA) → Guacamole (trusts Remote-User header)
```

**Configuration:**

```properties
# guacamole/guacamole.properties
disable-default-login: true       # No login form
auth-request-parameter: Remote-User  # Trusts header
EXTENSIONS: auth-header           # Header extension
```

**Behavior:**
- ✅ No internal login form in Guacamole
- ✅ Guacamole trusts 100% in Authelia
- ✅ Without Authelia validation, no access

### Rate Limiting (Brute-Force)

**Authelia Configuration:**
```yaml
regulation:
  max_retries: 3        # Maximum 3 failed attempts
  find_time: 300        # Within 5 minutes
  ban_time: 3600        # Block for 1 hour
```

**Behavior:**
- 3 failed attempts in 5 minutes = IP blocked for 1 hour
- The IP cannot make more attempts during that time
- Counter resets after the block

### Password Reset

**Disabled** in Authelia. Users cannot reset passwords without administrator intervention.

```yaml
password_reset:
  enabled: false
```

### Security HTTP Headers

Traefik automatically adds:

```yaml
X-Content-Type-Options: nosniff              # No MIME inference
X-Frame-Options: DENY                        # Not embeddable in iframes
X-XSS-Protection: 1; mode=block              # XSS protection
Referrer-Policy: strict-origin-when-cross-origin
```

### SSL/TLS

- **Certificates:** Let's Encrypt (automatic)
- **Protocol:** HTTPS TLS 1.2-1.3
- **Validation:** HTTP Challenge (doesn't require Cloudflare)

**Verify certificates:**

```bash
curl -v https://guacamole.your-domain.com 2>&1 | grep "subject="
```

### Password Storage

- **Algorithm:** Argon2id
- **Iterations:** 3
- **Memory:** 65540 KB
- **Parallelism:** 4
- **Salt:** 16 bytes

**Requirements:** Minimum 12 characters, special characters recommended.

### 2FA TOTP

Enabled in Authelia. Users can configure 2FA in their profile.

### Sessions

- **Storage:** SQLite
- **Location:** `/var/lib/authelia/session.db`
- **Encrypted:** Yes, with STORAGE_ENCRYPTION_KEY

## Guacamole

### First access

1. Go to `https://guacamole.your-domain.com`
2. Authelia prompts for credentials
3. After 2FA (if enabled), access to Guacamole granted

### Add RDP connection

1. **Login** with admin user
2. **Settings** (gear icon) → **Connections** → **New Connection**
3. Configure:
   - **Name:** My Windows Server
   - **Protocol:** RDP
   - **Hostname:** 192.168.1.100 (server IP)
   - **Port:** 3389
   - **Username:** rdp_user
   - **Password:** rdp_password
   - **Domain:** DOMAIN (if on Active Directory)
4. **Save**

### Add VNC connection

Similar to RDP but with VNC protocol, typically port 5900.

### Guacamole Protection

```properties
MAX_LOG_IN_ATTEMPTS: 3        # Maximum attempts (redundant)
disable-default-login: true   # No internal form
```

**Note:** Guacamole passwords in PostgreSQL are independent of Authelia. Authelia handles login, Guacamole handles permissions and connections.

## Operations

### Monitoring

```bash
# General status
make ps

# Real-time logs
make logs

# Specific logs
docker logs guacamole_authelia -f
docker logs guacamole_guacamole -f
docker logs guacamole_traefik -f

# Statistics
docker stats
```

### Database

```bash
# Access PostgreSQL
docker exec -it guacamole_postgres psql -U guacamole -d guacamole

# View tables
\dt

# Query example: view Guacamole users
SELECT username, password_hash FROM guacamole_user;

# Exit
\q

# Backup
docker exec guacamole_postgres pg_dump -U guacamole guacamole > backup.sql

# Restore
docker exec -i guacamole_postgres psql -U guacamole guacamole < backup.sql
```

### Execute commands in containers

```bash
# Guacamole shell
docker exec -it guacamole_guacamole sh

# Verify Redis connectivity
docker exec guacamole_redis redis-cli ping

# Verify DNS
docker exec guacamole_guacamole nslookup your-domain.com
```

### Clean and reset

```bash
# Stop without deleting data
make down

# Restart everything
make restart

# Delete COMPLETELY (dangerous)
make clean

# Start from scratch
make clean && make setup && make up
```

## Troubleshooting

### Certificates not being generated

**Symptoms:** SSL error in browser

```bash
# 1. Verify DNS
nslookup guacamole.your-domain.com

# 2. View Traefik logs
docker logs guacamole_traefik | grep -i acme

# 3. Check Let's Encrypt issues
# - Does the domain point correctly?
# - Is port 80 accessible?
# - Are there Let's Encrypt rate limits?
```

### "Access Denied" in Authelia

```bash
# 1. View logs
docker logs guacamole_authelia

# 2. Verify password hash
# - Hashes must start with $argon2id$
# - Regenerate if necessary

# 3. Restart Authelia
docker restart guacamole_authelia
```

### PostgreSQL not connecting

```bash
# 1. View logs
docker logs guacamole_postgres

# 2. Verify it's running
docker ps | grep postgres

# 3. Verify environment variables
docker exec guacamole_postgres env | grep POSTGRES
```

### Cannot connect to RDP server

```bash
# 1. Verify connectivity from Docker
docker exec guacamole_guacd ping 192.168.1.100

# 2. View guacd logs
docker logs guacamole_guacd

# 3. Verify RDP is open
# - Is the server on?
# - Is port 3389 open?
# - Are credentials correct?
```

### Rate limiting block

```bash
# View failed attempts
docker logs guacamole_authelia | grep -i "banned\|failed"

# Wait 1 hour or restart container
docker restart guacamole_authelia
```

### Services not starting

```bash
# See what's wrong
make logs

# Delete and begin again
make clean
make setup
make up
```

### Port already in use

```bash
# Find what's using the port
lsof -i :80      # Port 80
lsof -i :443     # Port 443

# Or with Docker
docker ps | grep -E "80|443"
```

## Advanced Examples

### Volume backups

```bash
# Authelia backup
docker run --rm -v guacamole_authelia_data:/data \
  -v /backup:/backup alpine \
  tar czf /backup/authelia-backup.tar.gz /data

# PostgreSQL backup
docker run --rm \
  -v guacamole_postgres_data:/data \
  -v /backup:/backup postgres:15.6 \
  pg_dump -U guacamole -h postgres guacamole > /backup/db.sql
```

### Rate limiting testing (NOT in production)

```bash
# Simulate 3 failed attempts
for i in {1..3}; do
  curl -I https://authelia.your-domain.com/api/verify \
    -H "Authorization: Basic incorrect:password" \
    2>/dev/null
done

# IP should be blocked afterwards
```

### Reset Guacamole password

```bash
# Access PostgreSQL
docker exec -it guacamole_postgres psql -U guacamole -d guacamole

# Update password (MD5 hash)
UPDATE guacamole_user SET password_hash=MD5('new_password')
WHERE username='admin';

# Exit
\q

# Restart Guacamole
docker restart guacamole_guacamole
```

### View access attempts

```bash
# All logs
docker logs guacamole_traefik | grep "method=GET\|method=POST"

# Authentication errors only
docker logs guacamole_authelia | grep -i "failed\|denied"

# Access patterns
docker logs guacamole_guacamole | tail -100
```

## Production Recommendations

- [ ] Change all secrets in `.env.guacamole`
- [ ] Strong passwords for all users (minimum 12 characters)
- [ ] Verify DNS points correctly
- [ ] Ports 80 and 443 accessible from internet
- [ ] Enable 2FA for all users
- [ ] Review logs regularly: `make logs`
- [ ] Automatic volume backups
- [ ] Recommended firewall: HTTPS and SSH only (if remote access)
- [ ] Monitoring: Alerts if services go down
- [ ] Scalability: LDAP/AD if many users

## References

- [Guacamole Documentation](https://guacamole.apache.org/doc/)
- [Authelia Documentation](https://www.authelia.com/configuration/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

---

**Status:** ✅ Production Ready

**Last updated:** 2026

**Support:** Review logs with `make logs` and documentation above
