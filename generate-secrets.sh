#!/bin/bash

# Generar secretos seguros para Guacamole

set -e

echo "Generando secretos..."
echo ""

# Generar contraseñas aleatorias de 32 caracteres
JWT_SECRET=$(openssl rand -hex 32)
SESSION_SECRET=$(openssl rand -hex 32)
STORAGE_ENCRYPTION_KEY=$(openssl rand -hex 32)
DB_PASS=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)

echo "Secretos generados:"
echo ""
echo "────────────────────────────────────────────────────────"
echo "JWT_SECRET=$JWT_SECRET"
echo "SESSION_SECRET=$SESSION_SECRET"
echo "STORAGE_ENCRYPTION_KEY=$STORAGE_ENCRYPTION_KEY"
echo "GUACAMOLE_DB_PASSWORD=$DB_PASS"
echo "────────────────────────────────────────────────────────"
echo ""

# Actualizar .env.guacamole con los secretos
echo "Actualizando .env.guacamole..."
if [ -f .env.guacamole ]; then
  # Hacer backup
  cp .env.guacamole .env.guacamole.bak

  # Actualizar los valores
  sed -i.tmp "s|^JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" .env.guacamole
  sed -i.tmp "s|^SESSION_SECRET=.*|SESSION_SECRET=$SESSION_SECRET|" .env.guacamole
  sed -i.tmp "s|^STORAGE_ENCRYPTION_KEY=.*|STORAGE_ENCRYPTION_KEY=$STORAGE_ENCRYPTION_KEY|" .env.guacamole
  sed -i.tmp "s|^GUACAMOLE_DB_PASSWORD=.*|GUACAMOLE_DB_PASSWORD=$DB_PASS|" .env.guacamole

  # Limpiar archivos temporales
  rm -f .env.guacamole.tmp

  echo "OK - .env.guacamole actualizado"
else
  echo "❌ .env.guacamole no encontrado"
  exit 1
fi

echo ""

# Opcionalmente generar hash de contraseña para usuario admin
echo "¿Generar hash de contraseña para admin? (s/N)"
read -r -t 3 GENERATE_HASH || GENERATE_HASH="N"

if [[ "$GENERATE_HASH" =~ ^[Ss]$ ]]; then
  echo "Escribe una contraseña (será oculta):"
  read -s ADMIN_PASSWORD

  # Verificar si Docker está disponible
  if command -v docker &> /dev/null; then
    ADMIN_HASH=$(docker run --rm authelia/authelia:4.37.5 \
      authelia hash-password "$ADMIN_PASSWORD" 2>/dev/null | grep -oP '\$argon2id\$[^$]*\$[^$]*\$[^$]*\$[^$]*' || echo "")

    if [ -n "$ADMIN_HASH" ]; then
      echo ""
      echo "📋 Hash de contraseña para usuario admin:"
      echo "────────────────────────────────────────────────────────"
      echo "  password: \"$ADMIN_HASH\""
      echo "────────────────────────────────────────────────────────"
      echo ""
      echo ""
    else
      echo "⚠️  No se pudo generar el hash. Asegúrate de que Docker está en ejecución."
    fi
  else
    echo "⚠️  Docker no está disponible. Genera el hash más tarde con:"
    echo "   docker run --rm authelia/authelia:4.37.5 authelia hash-password 'tu_contraseña'"
  fi
else
  echo "Saltando generación de hash"
fi

echo ""
echo "OK - Setup de secretos completado"
echo ""
echo "Próximos pasos:"
echo "   1. Revisa .env.guacamole"
echo "   2. Edita DOMAIN y ACME_EMAIL en .env.guacamole"
echo "   3. Ejecuta: make setup"
echo ""
