#!/bin/sh
# scripts/configure_synapse.sh

set -e  # остановиться при любой ошибке

CONFIG_FILE="/data/homeserver.yaml"
TEMP_FILE="/data/homeserver.yaml.tmp"

echo "🔧 Настройка Synapse для работы с PostgreSQL..."

# Создаем резервную копию
cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

# Заменяем SQLite на PostgreSQL
awk '
  /^database:/ { in_db=1; print; next }
  in_db && /^  name:/ { print "  name: psycopg2"; next }
  in_db && /^  args:/ { print "  args:"; next }
  in_db && /^    database:/ { print "    database: '"${POSTGRES_DB}"'"; next }
  in_db && /^    host:/ { print "    host: '"${POSTGRES_HOST}"'"; next }
  in_db && /^    password:/ { print "    password: '"${POSTGRES_PASSWORD}"'"; next }
  in_db && /^    user:/ { print "    user: '"${POSTGRES_USER}"'"; next }
  in_db && /^    cp_min:/ { print "    cp_min: 5"; next }
  in_db && /^    cp_max:/ { print "    cp_max: 10"; next }
  in_db && /^[^ ]/ { in_db=0; print; next }
  { print }
' "$CONFIG_FILE" > "$TEMP_FILE"

# Добавляем параметры пула соединений если их нет
if ! grep -q "cp_min" "$TEMP_FILE"; then
  sed -i '/^database:/,/^[^ ]/ s/  args:/  args:\n    cp_min: 5\n    cp_max: 10/' "$TEMP_FILE"
fi

mv "$TEMP_FILE" "$CONFIG_FILE"

# Включаем регистрацию (опционально)
sed -i 's/enable_registration: false/enable_registration: true/' "$CONFIG_FILE"

echo "✅ Конфиг Synapse успешно настроен!"