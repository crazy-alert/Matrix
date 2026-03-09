#!/bin/bash
set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Параметры по умолчанию
REPO_URL="https://github.com/crazy-alert/Matrix.git"
DEFAULT_INSTALL_DIR="/opt/Matrix"

# Функции вывода
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Проверка наличия команды
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "Команда '$1' не найдена. Установите её и повторите."
    fi
}

# Настройка UFW
configure_ufw() {
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        warn "Обнаружен активный UFW. Необходимо открыть порты для Matrix."
        read -p "Разрешить автоматически добавить правила UFW? (y/N): " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            info "Добавление правил UFW..."
            ufw allow 22/tcp comment 'ssh'
            ufw allow 80/tcp comment 'Matrix HTTP'
            ufw allow 443/tcp comment 'Matrix HTTPS'
            ufw allow 3478/udp comment 'Coturn TURN'
            ufw allow 49160:49200/udp comment 'Coturn relay'
            ufw reload
            info "Правила UFW добавлены."
        else
            warn "Не забудьте вручную открыть порты: 80/tcp, 443/tcp, 3478/udp, 49160-49200/udp"
        fi
    else
        info "UFW не установлен или не активен. Пропускаем настройку файрвола."
    fi
}

# Проверка статуса контейнеров
check_containers() {
    local compose_cmd="$1"
    sleep 5
    if $compose_cmd ps | grep -q "Exit"; then
        warn "Некоторые контейнеры остановились. Проверьте логи: $compose_cmd logs"
    else
        info "Все контейнеры запущены успешно."
    fi
}

# Основная функция
main() {
    info "Добро пожаловать в установщик Matrix-сервера!"

    # 1. Директория установки
    read -p "Введите директорию для установки (Enter для использования $DEFAULT_INSTALL_DIR): " INSTALL_DIR
    INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
    info "Директория установки: $INSTALL_DIR"

    # 2. Обновление системы и установка необходимых пакетов
    info "Обновление списка пакетов и установка git, curl, dnsutils..."
    apt update && apt install -y git curl dnsutils

    # 3. Проверка Docker и Docker Compose
    info "Проверка Docker и Docker Compose..."
    check_command docker
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        error "Docker Compose не найден. Установите docker-compose или docker compose."
    fi
    info "Используется команда: $COMPOSE_CMD"

    # 4. Подготовка директории и клонирование репозитория
    if [ -d "$INSTALL_DIR" ]; then
        warn "Директория $INSTALL_DIR уже существует."
        read -p "Продолжить и перезаписать файлы? (y/N): " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            error "Установка отменена."
        fi
        rm -rf "$INSTALL_DIR"
    fi
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    info "Клонирование репозитория..."
    git clone -v "$REPO_URL" .

    # 5. Запрос домена и проверка DNS
    read -p "Введите ваш домен (например, example.org): " DOMAIN
    [ -z "$DOMAIN" ] && error "Домен не может быть пустым."

    # Определяем внешний IP
    info "Определение внешнего IP..."
    EXTERNAL_IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || curl -s -4 ipinfo.io/ip)
    if [ -z "$EXTERNAL_IP" ]; then
        error "Не удалось определить внешний IP сервера."
    fi
    info "Внешний IP: $EXTERNAL_IP"

    # Проверка DNS
    check_dns() {
        local host="$1"
        local ip
        ip=$(dig +short "$host" A | head -n1)
        if [ -z "$ip" ]; then
            error "Не удалось получить IP для $host. Проверьте DNS-записи."
        fi
        if [ "$ip" != "$EXTERNAL_IP" ]; then
            error "IP домена $host ($ip) не совпадает с внешним IP сервера ($EXTERNAL_IP)."
        fi
        info "$host -> $ip (OK)"
    }
    info "Проверка DNS для основного домена..."
    check_dns "$DOMAIN"
    info "Проверка DNS для matrix.$DOMAIN..."
    check_dns "matrix.$DOMAIN"

    # 6. Создание .env из примера
    if [ ! -f "example.env" ]; then
        error "Файл example.env не найден в репозитории."
    fi
    cp example.env .env
    info "Файл .env создан."

    # 7. Замена переменных в .env
    MATRIX_SERVER_NAME="matrix.$DOMAIN"
    COTURN_EXTERNAL_IP="$EXTERNAL_IP"
    COTURN_INTERNAL_IP="$EXTERNAL_IP"

    sed -i "s/^DOMAIN=.*/DOMAIN=$DOMAIN/" .env
    sed -i "s/^MATRIX_SERVER_NAME=.*/MATRIX_SERVER_NAME=$MATRIX_SERVER_NAME/" .env
    sed -i "s/^COTURN_EXTERNAL_IP=.*/COTURN_EXTERNAL_IP=$COTURN_EXTERNAL_IP/" .env
    sed -i "s/^COTURN_INTERNAL_IP=.*/COTURN_INTERNAL_IP=$COTURN_INTERNAL_IP/" .env
    info "Переменные в .env обновлены."

    # 8. Запуск генератора конфигурации
    if [ ! -f "generate_config.sh" ]; then
        error "Скрипт generate_config.sh не найден."
    fi
    chmod +x generate_config.sh
    info "Запуск generate_config.sh..."
    if ! ./generate_config.sh; then
        error "generate_config.sh завершился с ошибкой. Проверьте вывод выше."
    fi
    info "generate_config.sh выполнен успешно."

    # 9. Настройка UFW (опционально)
    configure_ufw

    # 10. Запуск Docker-стека
    info "Запуск контейнеров с помощью $COMPOSE_CMD..."
    $COMPOSE_CMD up -d

    # 11. Проверка статуса контейнеров
    check_containers "$COMPOSE_CMD"

    # 12. Финальное сообщение
    echo -e "${GREEN}"
    cat << EOF
✅ Установка завершена!

Ваш Matrix-сервер доступен по адресам:
- Сервер Synapse: https://$MATRIX_SERVER_NAME
- Веб-клиент Element: https://element.$DOMAIN (если настроен)
- Админ-панель: https://admin.$DOMAIN

Пароль PostgreSQL сохранён в файле .env (переменная POSTGRES_PASSWORD).

Создать первого пользователя:
  $COMPOSE_CMD exec synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008

Для просмотра логов:
  $COMPOSE_CMD logs -f

Управление регистрацией описано в README.
EOF
    echo -e "${NC}"
}

# Запуск
main