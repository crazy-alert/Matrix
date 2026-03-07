#!/bin/bash
set -e

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔧 Генерация homeserver.yaml из шаблона...${NC}"

# Проверяем .env
if [ ! -f .env ]; then
    echo -e "${RED}❌ Файл .env не найден!${NC}"
    exit 1
fi

# Загружаем переменные окружения из .env
set -a
source .env
set +a

# Проверяем обязательные переменные
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ DOMAIN не задан в .env${NC}"
    exit 1
fi
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo -e "${RED}❌ POSTGRES_PASSWORD не задан в .env${NC}"
    exit 1
fi

# Определяем имя сервера
SERVER_NAME="${MATRIX_SERVER_NAME:-$DOMAIN}"

# Генерация секретов, если они не заданы в .env
if [ -z "$MACAROON_SECRET_KEY" ]; then
    MACAROON_SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    echo "MACAROON_SECRET_KEY=${MACAROON_SECRET_KEY}" >> .env
    echo -e "${GREEN}✨ Сгенерирован MACAROON_SECRET_KEY и добавлен в .env${NC}"
fi

if [ -z "$REGISTRATION_SHARED_SECRET" ]; then
    REGISTRATION_SHARED_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    echo "REGISTRATION_SHARED_SECRET=${REGISTRATION_SHARED_SECRET}" >> .env
    echo -e "${GREEN}✨ Сгенерирован REGISTRATION_SHARED_SECRET и добавлен в .env${NC}"
fi

if [ -z "$FORM_SECRET" ]; then
    FORM_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    echo "FORM_SECRET=${FORM_SECRET}" >> .env
    echo -e "${GREEN}✨ Сгенерирован FORM_SECRET и добавлен в .env${NC}"
fi

# Пути
TEMPLATE="template.yaml"
OUTPUT="homeserver.yaml"

if [ ! -f "$TEMPLATE" ]; then
    echo -e "${RED}❌ Шаблон $TEMPLATE не найден!${NC}"
    exit 1
fi

# Копируем шаблон
cp "$TEMPLATE" "$OUTPUT"

# Заменяем плейсхолдеры
sed -i "s/__SERVER_NAME__/${SERVER_NAME}/g" "$OUTPUT"
sed -i "s/__POSTGRES_PASSWORD__/${POSTGRES_PASSWORD}/g" "$OUTPUT"

# Удаляем log_config, если он есть (чтобы логи шли в stdout)
sed -i '/log_config:/d' "$OUTPUT"

# Добавляем секреты, если их нет в файле
if ! grep -q "macaroon_secret_key" "$OUTPUT"; then
    echo "macaroon_secret_key: ${MACAROON_SECRET_KEY}" >> "$OUTPUT"
fi
if ! grep -q "registration_shared_secret" "$OUTPUT"; then
    echo "registration_shared_secret: ${REGISTRATION_SHARED_SECRET}" >> "$OUTPUT"
fi
if ! grep -q "form_secret" "$OUTPUT"; then
    echo "form_secret: ${FORM_SECRET}" >> "$OUTPUT"
fi

# Устанавливаем права 644, чтобы контейнер (пользователь 991) мог читать
chmod 644 "$OUTPUT"

echo -e "${GREEN}✅ Файл $OUTPUT успешно создан с правами 644${NC}"
echo -e "${GREEN}📄 Первые 20 строк:${NC}"
head -20 "$OUTPUT"