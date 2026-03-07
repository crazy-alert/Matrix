#!/bin/sh
set -e

CONFIG_FILE="/data/homeserver.yaml"
echo "🔧 Настройка Synapse..."

# 1. Резервная копия
cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

# 2. Замена базы данных на PostgreSQL
echo "⚙️ Настройка PostgreSQL..."
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

# 3. Убираем привязку к localhost в listeners
#    Удаляем блок bind_addresses целиком, чтобы слушал на всех интерфейсах
echo "🌐 Настройка listeners для работы в Docker-сети..."
sed -i '/bind_addresses:/,+2 d' "$CONFIG_FILE"
# Если после удаления остаётся пустая строка, можно убрать (опционально)
sed -i '/^  - port: 8008/ s/^/  /' "$CONFIG_FILE" # выравнивание отступа (на всякий случай)

# 4. Включение регистрации (если нужно)
echo "🔓 Включение регистрации..."
sed -i 's/enable_registration: false/enable_registration: true/' "$CONFIG_FILE"

echo "✅ Конфиг Synapse готов!"