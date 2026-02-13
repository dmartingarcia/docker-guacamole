#!/bin/bash

# Script de inicialización para Guacamole con PostgreSQL
# Uso: ./init-guacamole.sh

set -e

COMPOSE_FILE="docker-compose-guacamole.yml"
DB_CONTAINER="guacamole_postgres"
GUAC_CONTAINER="guacamole_app"
SCHEMA_DIR="./guacamole-schema"

echo "🚀 Iniciando setup de Guacamole..."

# 1. Levantar los servicios
echo "⏳ Levantando servicios..."
docker-compose -f $COMPOSE_FILE up -d

# 2. Esperar a que PostgreSQL esté listo
echo "⏳ Esperando a PostgreSQL..."
for i in {1..30}; do
  if docker exec $DB_CONTAINER pg_isready -U guacamole > /dev/null 2>&1; then
    echo "✅ PostgreSQL listo"
    break
  fi
  echo "  Intento $i/30..."
  sleep 2
done

# 3. Crear directorio para schema
mkdir -p $SCHEMA_DIR

# 4. Descargar schema de Guacamole
echo "⏳ Descargando schema de Guacamole..."
if [ ! -f "$SCHEMA_DIR/001-create-tables.sql" ]; then
  docker pull guacamole/guacamole:latest &> /dev/null

  # Extraer el schema del contenedor
  docker run --rm guacamole/guacamole:latest \
    sh -c 'cat /opt/guacamole/mysql-schema/001-create-tables.sql' > "$SCHEMA_DIR/001-create-tables.sql"

  docker run --rm guacamole/guacamole:latest \
    sh -c 'cat /opt/guacamole/mysql-schema/002-create-admin-user.sql' > "$SCHEMA_DIR/002-create-admin-user.sql" 2>/dev/null || true

  echo "✅ Schema descargado"
else
  echo "✅ Schema ya existe"
fi

# 5. Aplicar schema a PostgreSQL
echo "⏳ Aplicando schema a PostgreSQL..."

# Convertir de MySQL a PostgreSQL syntax (simple)
if [ -f "$SCHEMA_DIR/001-create-tables.sql" ]; then
  # Copiar archivo al contenedor
  docker cp "$SCHEMA_DIR/001-create-tables.sql" "$DB_CONTAINER:/tmp/schema.sql"

  # Aplicar el schema
  docker exec $DB_CONTAINER psql -U guacamole -d guacamole -f /tmp/schema.sql || true

  echo "✅ Schema aplicado"
fi

# 6. Crear usuario admin en Guacamole
echo "⏳ Creando usuario administrador..."
docker exec $DB_CONTAINER psql -U guacamole -d guacamole << 'EOF'
-- Crear usuario admin si no existe
INSERT INTO guacamole_user (username)
SELECT 'admin'
WHERE NOT EXISTS (SELECT 1 FROM guacamole_user WHERE username = 'admin');

-- Crear entidad system si no existe
INSERT INTO guacamole_entity (name, type)
SELECT 'admin', 'USER'
WHERE NOT EXISTS (SELECT 1 FROM guacamole_entity WHERE name = 'admin' AND type = 'USER');

COMMIT;
EOF

echo "✅ Usuario admin creado"

# 7. Esperar a que Guacamole esté listo
echo "⏳ Esperando a que Guacamole inicie..."
for i in {1..30}; do
  if docker exec $GUAC_CONTAINER curl -s http://localhost:8080/guacamole/ > /dev/null; then
    echo "✅ Guacamole listo"
    break
  fi
  echo "  Intento $i/30..."
  sleep 2
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup completado exitosamente"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Próximos pasos:"
echo "  1. Asegurar que tu dominio apunta a esta máquina"
echo "  2. Acceder a: https://guacamole.example.com"
echo "  3. Usuario: admin"
echo "  4. (No hay contraseña por defecto, configura en Guacamole)"
echo ""
echo "📝 Comandos útiles:"
echo "  Ver logs: docker-compose -f $COMPOSE_FILE logs -f"
echo "  Parar: docker-compose -f $COMPOSE_FILE down"
echo "  Recrear: docker-compose -f $COMPOSE_FILE down -v && bash $0"
echo ""
