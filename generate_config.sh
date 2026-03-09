#!/bin/bash
set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Функции вывода (дублируются на случай запуска отдельно)
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Генератор пароля
generate_password() {
    tr -dc 'a-zA-Z0-9!@#$%^&*()_+' < /dev/urandom 2>/dev/null | fold -w 32 | head -n1 || openssl rand -base64 32
}

# Генерация/проверка пароля PostgreSQL
setup_postgres_password() {
    local env_file="$1"
    if ! grep -q '^POSTGRES_PASSWORD=' "$env_file"; then
        NEW_PASS=$(generate_password)
        echo "POSTGRES_PASSWORD=$NEW_PASS" >> "$env_file"
        info "Сгенерирован новый пароль PostgreSQL и добавлен в .env"
    else
        CURRENT_PASS=$(grep '^POSTGRES_PASSWORD=' "$env_file" | cut -d'=' -f2-)
        if [ "$CURRENT_PASS" = "changeme" ]; then
            NEW_PASS=$(generate_password)
            sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$NEW_PASS/" "$env_file"
            info "Пароль PostgreSQL изменён с 'changeme' на случайный"
        else
            info "Пароль PostgreSQL уже задан в .env"
        fi
    fi
}

# ----------------------------------------------------------------------
# Основная часть
# ----------------------------------------------------------------------

# Проверяем наличие .env
if [ ! -f .env ]; then
    error "Файл .env не найден!"
fi

# Генерируем пароль БД (если требуется) до загрузки переменных
setup_postgres_password ".env"

# Загружаем переменные
set -a
source .env
set +a

# Проверяем обязательные переменные
if [ -z "$DOMAIN" ]; then
    error "DOMAIN не задан в .env"
fi
if [ -z "$POSTGRES_PASSWORD" ]; then
    error "POSTGRES_PASSWORD не задан в .env"
fi

# Определяем имя сервера
SERVER_NAME="${MATRIX_SERVER_NAME:-$DOMAIN}"

info "  ! ! ! ! check    DOMAIN : $DOMAIN"
info "  ! ! ! ! check    SERVER_NAME : $SERVER_NAME"
info "  ! ! ! ! check    MATRIX_SERVER_NAME : $MATRIX_SERVER_NAME"

# Генерация секретов, если отсутствуют
if [ -z "$MACAROON_SECRET_KEY" ]; then
    MACAROON_SECRET_KEY=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 32 | head -n1)
    echo "MACAROON_SECRET_KEY=${MACAROON_SECRET_KEY}" >> .env
    info "Сгенерирован MACAROON_SECRET_KEY и добавлен в .env"
fi

if [ -z "$REGISTRATION_SHARED_SECRET" ]; then
    REGISTRATION_SHARED_SECRET=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 32 | head -n1)
    echo "REGISTRATION_SHARED_SECRET=${REGISTRATION_SHARED_SECRET}" >> .env
    info "Сгенерирован REGISTRATION_SHARED_SECRET и добавлен в .env"
fi

if [ -z "$FORM_SECRET" ]; then
    FORM_SECRET=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 32 | head -n1)
    echo "FORM_SECRET=${FORM_SECRET}" >> .env
    info "Сгенерирован FORM_SECRET и добавлен в .env"
fi

# ----------------------------------------------------------------------
# Генерация homeserver.yaml
# ----------------------------------------------------------------------
TEMPLATE="template.yaml"
OUTPUT="homeserver.yaml"
if [ ! -f "$TEMPLATE" ]; then
    error "Шаблон $TEMPLATE не найден!"
fi

cp "$TEMPLATE" "$OUTPUT"
sed -i "s/__SERVER_NAME__/${SERVER_NAME}/g" "$OUTPUT"
sed -i "s/__POSTGRES_PASSWORD__/${POSTGRES_PASSWORD}/g" "$OUTPUT"
sed -i '/log_config:/d' "$OUTPUT"

# Добавляем секреты, если их нет
if ! grep -q "macaroon_secret_key" "$OUTPUT"; then
    echo "macaroon_secret_key: ${MACAROON_SECRET_KEY}" >> "$OUTPUT"
fi
if ! grep -q "registration_shared_secret" "$OUTPUT"; then
    echo "registration_shared_secret: ${REGISTRATION_SHARED_SECRET}" >> "$OUTPUT"
fi
if ! grep -q "form_secret" "$OUTPUT"; then
    echo "form_secret: ${FORM_SECRET}" >> "$OUTPUT"
fi

chmod 644 "$OUTPUT"
info "Файл $OUTPUT успешно создан с правами 644"

# ----------------------------------------------------------------------
# Генерация element-config.json
# ----------------------------------------------------------------------
TEMPLATE="element-config.json.template"
OUTPUT="element-config.json"
if [ ! -f "$TEMPLATE" ]; then
    error "Шаблон $TEMPLATE не найден!"
fi

cp "$TEMPLATE" "$OUTPUT"
sed -i "s/__SERVER_NAME__/${SERVER_NAME}/g" "$OUTPUT"
sed -i "s/__MATRIX_SERVER_NAME__/${MATRIX_SERVER_NAME}/g" "$OUTPUT"

chmod 644 "$OUTPUT"
info "Файл $OUTPUT успешно создан с правами 644"

echo -e "${GREEN}✅ Генерация конфигурации завершена.${NC}"