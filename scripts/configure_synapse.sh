#!/bin/sh
# scripts/configure_synapse.sh

set -e

CONFIG_FILE="/data/homeserver.yaml"
echo "🔧 Настройка Synapse для работы с PostgreSQL..."

# Резервная копия
cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

# Заменяем SQLite на PostgreSQL
sed -i \
  -e '/^database:/,/^[^ ]/c\
database:\n  name: psycopg2\n  args:\n    user: synapse\n    password: '"$POSTGRES_PASSWORD"'\n    database: synapse\n    host: synapse_db\n    cp_min: 5\n    cp_max: 10' \
  "$CONFIG_FILE"

# Включаем регистрацию
sed -i 's/enable_registration: false/enable_registration: true/' "$CONFIG_FILE"

echo "✅ Конфиг настроен!"