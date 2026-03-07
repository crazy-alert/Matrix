# 🚀 Matrix-сервер на Tuwunel с Docker Compose

Этот репозиторий содержит готовый Docker‑стек для развёртывания собственного Matrix‑сервера на базе **Tuwunel** (лёгкий сервер на Rust), PostgreSQL, Caddy (автоматический HTTPS) и Unbound (кеширующий DNS). Всё это упаковано в удобный `docker-compose.yml` – достаточно склонировать, поправить конфиги и запустить.
---
## 🔧 Предварительные требования

- Сервер (VPS или выделенный) с **Ubuntu 20.04+ / Debian 11+**, минимум 1 GB RAM (рекомендуется 2 GB).
- Установленные **Docker** и **Docker Compose** (обычно `docker compose` входит в состав Docker).
- Доменное имя, направленное на IP вашего сервера. Понадобятся два поддомена:
    - `matrix.ваш-домен.ru` – для сервера Matrix
    - (опционально) `element.ваш-домен.ru` – если позже захотите поставить веб‑клиент Element
- Открытые порты в фаерволе: **80**, **443**, **8448** (TCP).

---
## ⚙️ Настройка перед запуском
### 0. Обновление системы, установка зависимостей
```bash
apt update && apt install -y git 
```
---
### 1. Клонируйте репозиторий и перейдите в него
Создать директорию в которую установим, например `/opt/Matrix`, перейти в неё и скопировать этот репозиторий в неё
```bash
mkdir /opt/Matrix &&
cd /opt/Matrix &&
git clone -v  https://github.com/crazy-alert/Matrix.git . 
```
---
### 2. Настройка
В редакторе nao сочетания кнопок: `Ctrl+o` - сохранить (после нажать Enter), `Ctrl+x` - закрыть

Скопируйте файл примеры конфигурации и отредактируйте его:
Чтобы узнать COTURN_INTERNAL_IP (внутренний IP вашего сервера), выполните на сервере одну из этих команд:

```bash
hostname -I | awk '{print $1}'
```
Это главный конфиг сервера. Обязательно замените:
server_name – ваш домен (например, `matrix.example.ru`).

```bash
cp example.env .env &&
nano .env
```
Создайте конфиг matrix
```bash
chmod +x generate_config.sh && ./generate_config.sh
```
---
### 3. 🚀 Запуск сервера
Выполните в каталоге с ```docker-compose.yml```:

```bash
docker-compose up -d
```
Через минуту все контейнеры будут запущены. Проверьте логи:
```bash
docker compose logs -f
```
---

### Создать пользователя:
- Вас попросят ввести:
  - имя пользователя (без домена, например friend)
  - пароль
  - подтверждение пароля
  - сделать ли администратором (ответьте yes или no)
```bash
docker exec -it matrix_synapse_1 register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008
```


---
#### Coturn — самая капризная часть. Если звонки не работают, проверьте логи и настройки файрвола (UDP порты 3478, 50000-51000 должны быть открыты). Вариант установки Coturn на хост-машину (вне Docker) часто надежнее.

Если вы не планируете использовать звонки, можно закомментировать или удалить сервис coturn из `docker-compose.yml`.
---
### 📦 Управление стеком
* Остановить: ```docker compose down```
* Запустить: ```docker compose up -d```
* Перезапустить конкретный сервис: ```docker compose restart tuwunel```
* Посмотреть логи: ```docker compose logs -f [имя_сервиса]```
* Остановить, обновить образы, запустить: ```docker compose down && docker compose pull && docker compose up -d```
* Остановить, обновить образы, запустить: ```docker-compose down && docker-compose pull && docker-compose up -d```
* Остановить, обновить ропозиторий, запустить: ```docker-compose down && git pull && docker-compose up -d```