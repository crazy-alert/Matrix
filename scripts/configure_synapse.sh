#!/bin/sh
set -e
CONFIG_FILE="/data/homeserver.yaml"
echo "🔧 Настройка PostgreSQL в конфиге..."
sed -i '/^database:/,/^[^ ]/c\
database:\
  name: psycopg2\
  args:\
    user: synapse\
    password: '"$POSTGRES_PASSWORD"'\
    database: synapse\
    host: synapse_db\
    cp_min: 5\
    cp_max: 10' "$CONFIG_FILE"
echo "✅ Готово."