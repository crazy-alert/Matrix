#!/bin/sh
set -e

CONFIG_FILE="/data/homeserver.yaml"
TEMPLATE_FILE="/tmp/homeserver.template.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo '📝 Копируем шаблон конфига...'
    cp "$TEMPLATE_FILE" "$CONFIG_FILE"

    echo '🔧 Подставляем SERVER_NAME...'
    sed -i "s/__SERVER_NAME__/${SERVER_NAME}/g" "$CONFIG_FILE"

    echo '🔧 Подставляем пароль PostgreSQL...'
    sed -i "s/__POSTGRES_PASSWORD__/${POSTGRES_PASSWORD}/g" "$CONFIG_FILE"

    # Генерируем секреты, если их нет
    if ! grep -q "registration_shared_secret" "$CONFIG_FILE"; then
        echo 'registration_shared_secret: '$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) >> "$CONFIG_FILE"
    fi
    if ! grep -q "macaroon_secret_key" "$CONFIG_FILE"; then
        echo 'macaroon_secret_key: '$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) >> "$CONFIG_FILE"
    fi
    if ! grep -q "form_secret" "$CONFIG_FILE"; then
        echo 'form_secret: '$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) >> "$CONFIG_FILE"
    fi
fi

echo '🚀 Запускаем Synapse...'
exec python -m synapse.app.homeserver --config-path "$CONFIG_FILE"