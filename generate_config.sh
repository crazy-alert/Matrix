#!/bin/bash
set -e

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Генерация homeserver.yaml из шаблона...${NC}"

# Проверяем наличие .env
if [ ! -f .env ]; then
    echo -e "${RED}❌ Файл .env не найден!${NC}"
    exit 1
fi

# Загружаем переменные из .env (игнорируем комментарии и пустые строки)
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

# Определяем SERVER_NAME (если MATRIX_SERVER_NAME не задан, используем DOMAIN)
SERVER_NAME="${MATRIX_SERVER_NAME:-$DOMAIN}"

# Пути
TEMPLATE="template.yaml"
OUTPUT="homeserver.yaml"

if [ ! -f "$TEMPLATE" ]; then
    echo -e "${RED}❌ Шаблон $TEMPLATE не найден!${NC}"
    exit 1
fi

# Копируем шаблон в выходной файл
cp "$TEMPLATE" "$OUTPUT"

# Заменяем плейсхолдеры
sed -i "s/__SERVER_NAME__/${SERVER_NAME}/g" "$OUTPUT"
sed -i "s/__POSTGRES_PASSWORD__/${POSTGRES_PASSWORD}/g" "$OUTPUT"

echo -e "${GREEN}✅ Файл $OUTPUT успешно создан!${NC}"
echo -e "${GREEN}📄 Содержимое:${NC}"
head -20 "$OUTPUT"