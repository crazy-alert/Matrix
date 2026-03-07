#!/bin/sh
set -e

CONFIG_FILE="/data/homeserver.yaml"
echo "🔧 Настройка Synapse..."

cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

# 1. Настройка PostgreSQL: заменяем секцию database
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

# 2. Убираем bind_addresses из listeners (более безопасно)
sed -i '/bind_addresses:/,+2 d' "$CONFIG_FILE"

# 3. Если после удаления остаётся пустая строка, убираем её (опционально)
sed -i '/^  - port: 8008/ { N; s/\n  \n/\n/; }' "$CONFIG_FILE"

# 4. Включаем регистрацию
sed -i 's/enable_registration: false/enable_registration: true/' "$CONFIG_FILE"

echo "✅ Конфиг Synapse готов!"