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
docker run -it --rm -v matrix_synapse_data:/data alpine chown -R 991:991 /data

---
#### Coturn — самая капризная часть. Если звонки не работают, проверьте логи и настройки файрвола (UDP порты 3478, 50000-51000 должны быть открыты). Вариант установки Coturn на хост-машину (вне Docker) часто надежнее.

Добавить правила:
```bash
ufw allow 3478/udp &&
ufw allow 50000:51000/udp
```
Убедитесь, что правила добавлены:
```bash
ufw status numbered
```

Вы должны увидеть что-то похожее на это:
```
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 80/tcp                     ALLOW IN    Anywhere                   # HTTP
[ 2] 443/tcp                    ALLOW IN    Anywhere                   # HTTPS
[ 3] 8448/tcp                   ALLOW IN    Anywhere                   # Matrix (или другой сервис)
[ 4] 22/tcp                     ALLOW IN    Anywhere                   # ssh
[ 5] 3478/udp                   ALLOW IN    Anywhere
[ 6] 50000:51000/udp            ALLOW IN    Anywhere
[ 7] 80/tcp (v6)                ALLOW IN    Anywhere (v6)              # HTTP
[ 8] 443/tcp (v6)               ALLOW IN    Anywhere (v6)              # HTTPS
[ 9] 8448/tcp (v6)              ALLOW IN    Anywhere (v6)              # Matrix (или другой сервис)
[10] 22/tcp (v6)                ALLOW IN    Anywhere (v6)              # ssh
[11] 3478/udp (v6)              ALLOW IN    Anywhere (v6)
[12] 50000:51000/udp (v6)       ALLOW IN    Anywhere (v6)
```
----
Посмотреть пользователей:

```bash
docker exec -it matrix_synapse_db_1 psql -U synapse -d synapse -c "SELECT name FROM users;"
```

Чтобы установить (сменить) пароль для существующего пользователя в Synapse, выполните команду:
```bash
docker exec -it matrix_synapse_1 register_new_matrix_user -c /data/homeserver.yaml -u ИМЯ_ПОЛЬЗОВАТЕЛЯ -p НОВЫЙ_ПАРОЛЬ http://localhost:8008
```

