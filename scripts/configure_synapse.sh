#!/bin/sh
# scripts/configure_synapse.sh

set -e

CONFIG_FILE="/data/homeserver.yaml"
echo "🔧 Настройка Synapse для работы с PostgreSQL..."

# Проверяем, что файл существует
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Ошибка: $CONFIG_FILE не найден!"
    exit 1
fi

# Резервная копия
cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

# Полностью заменяем секцию database
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

# Включаем регистрацию (опционально)
sed -i 's/enable_registration: false/enable_registration: true/' "$CONFIG_FILE"

echo "✅ Конфиг настроен!"