# 🚀 Matrix-сервер

Для ЛЛ в репозитарий добавлен установщик, вы можете развернуть Matrix сервер одной командой:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/crazy-alert/Matrix/refs/heads/main/installer.sh?timestamp=123)
```


Так же в данном репозитории:
 - файл `Readme.element.md` - описание настроек Web клиента Element
 - файл `Readme.turn.md` - описание настроек TURN сервера для организации аудио- и видеозвонков в Matrix (оно уже работает, но мало ли...)
______
# Ниже описана установка без использования автоматического установщика (не для ЛЛ)
______

## 📦 Состав Docker-стека

#### Стек состоит из нескольких контейнеров, которые вместе образуют полноценный Matrix-сервер с веб-клиентом, TURN-сервером для звонков и автоматическим HTTPS.
- `caddy`	Обратный прокси-сервер с автоматическим получением SSL-сертификатов (Let's Encrypt). Маршрутизирует трафик на внутренние сервисы: matrix.${DOMAIN} → synapse, ${DOMAIN} → element-web, admin.${DOMAIN} → synapse-admin.
- `permissions`	Вспомогательный однократный контейнер (на основе alpine). Исправляет права доступа на томе synapse_data, устанавливая владельца 991:991 (UID пользователя synapse в контейнере). Без этого шага Synapse не сможет писать логи, медиафайлы и ключи.
- `synapse`	Основной сервер Matrix (реализация Synapse на Python). Хранит данные в томе synapse_data, читает конфигурацию из примонтированного homeserver.yaml. Зависит от PostgreSQL.
- `synapse_db`	База данных PostgreSQL, используемая Synapse для хранения метаданных, комнат, пользователей и т.д. Данные сохраняются в томе synapse_db_data.
- `coturn`	TURN-сервер для организации аудио- и видеозвонков через Matrix (когда клиенты не могут соединиться напрямки). Конфигурация генерируется на лету из шаблона с подстановкой переменных окружения.
- `element-web`	Веб-клиент Element (ранее Riot), через который пользователи заходят в свой Matrix-аккаунт. Конфиг element-config.json монтируется в контейнер.
- `synapse-admin`	Административная панель для управления пользователями, комнатами и просмотра статистики. Доступна по поддомену (например, admin.${DOMAIN}).

#### Сети и тома
- `internal` – изолированная bridge-сеть, через которую контейнеры общаются между собой (только `Caddy` имеет доступ к портам 80/443 наружу).
- `caddy_data`, `caddy_config` – тома для хранения сертификатов и настроек `Caddy`.
- `synapse_data` – том для медиафайлов, логов и ключей `Synapse`.
- `synapse_db_data` – том для файлов базы данных `PostgreSQL`.

___________
# Звучит сложно, но с помощью данного репозитория поднимается реально за минуты.

3 шага с подсказками, всё описано
_________


## 🔧 Предварительные требования

- Сервер (VPS или выделенный) с **Ubuntu 20.04+ / Debian 11+**, минимум 1 GB RAM (рекомендуется 2 GB).
- Установленные **Docker** и **Docker Compose** (обычно `docker compose` входит в состав Docker).
- Доменное имя, направленное на IP вашего сервера. Понадобятся два поддомена:
    - `matrix.ваш-домен.ru` – для сервера Matrix
    - (опционально) `element.ваш-домен.ru` – если позже захотите поставить веб‑клиент Element
- Открытые порты в фаерволе:
    - **80/tcp**, **443/tcp** – для веб-интерфейса и клиентов
    - **3478/udp** и **49160-49200/udp** – для TURN-сервера (звонки)
    - (опционально) **8448/tcp** – для федерации, если вы не используете делегирование через .well-known

---
##  Приступим
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
Выполните следующую команду, она скопирует файл примера конфигурации в `.env` и откроет его для редактирования в редакторе `nano`.
В редакторе `nano` сочетания кнопок: `Ctrl+o` - сохранить изменеия(после нажать Enter), `Ctrl+x` - закрыть.

#### `.env` это главный конфиг сервера. Обязательно замените:
 - DOMAIN=example.org – ваш домен (вместо `example.org` подставьте ваш домен).
 - MATRIX_SERVER_NAME=matrix.example.org – это прямой адрес вашего сервера Synapse (обычно используется поддомен 'matrix').
 - COTURN_EXTERNAL_IP=ваш_публичный_айпи - подставьте внешний ip сервера (можно узнать командой `hostname -I | awk '{print $1}'`)
 - COTURN_INTERNAL_IP=ваш_внутренний_айпи - внутренний ip внутри сети, обычно совпадает с внешним
Команда
```bash
cp example.env .env &&
nano .env
```
🔧 Автоматическая генерация конфигурации (`generate_config.sh`)
Скрипт `generate_config.sh` создаёт финальные файлы конфигурации на основе шаблонов и переменных из `.env`. 

Что он делает:
- Проверяет наличие файла `.env` и загружает переменные.
- Генерирует случайные секреты (`macaroon`, `registration shared secret`, `form secret`), если они не заданы, и дописывает их в `.env`.
- Создаёт `homeserver.yaml` из шаблона `template.yaml`, подставляя имя сервера и пароль `PostgreSQL`.
- Создаёт `element-config.json` из шаблона `element-config.json.template` для веб-клиента Element.
- Устанавливает права доступа 644, чтобы контейнеры могли читать файлы.

Запускайте этот скрипт после настройки .env и перед первым запуском Docker-стека.

Команда для запуска:
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
------

### Создание пользователей:
- Вас попросят ввести:
  - имя пользователя (без домена, например friend)
  - пароль
  - подтверждение пароля
  - сделать ли администратором (ответьте yes или no)
```bash
docker-compose exec synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008
```
### Просмотр пользователей:
```bash
docker-compose exec synapse_db psql -U synapse -d synapse -c "SELECT name FROM users;"
```

(Все эти операции доступны через web при установленном `synapse-admin`, если Вы ничего не меняли)


---
#### Coturn — самая капризная часть. Если звонки не работают, проверьте логи и настройки файрвола (UDP порты 3478, 50000-51000 должны быть открыты). Вариант установки Coturn на хост-машину (вне Docker) часто надежнее.

Добавить правила:
```bash
ufw allow 3478/udp
ufw allow 49160:49200/udp
ufw reload
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
docker exec -it synapse_db psql -U synapse -d synapse -c "SELECT name FROM users;"
```

Чтобы установить (сменить) пароль для существующего пользователя в Synapse, выполните команду:
```bash
docker exec -it synapse register_new_matrix_user -c /data/homeserver.yaml -u ИМЯ_ПОЛЬЗОВАТЕЛЯ -p НОВЫЙ_ПАРОЛЬ http://localhost:8008
```
______
# Адреса:
 - https://admin.ваш_сервер.com - панель synapse-admin
 - https://element.ваш_сервер.com - клиент Element web (это как web.whatsapp.com или web.telegram.org)
 - https://federationtester.matrix.org/?server_name=ваш_сервер.com - можете проверить федерацию
 - https://matrix.вашсервер.com - должен переадресовать вас на matrix.ваш_сервер.com_matrix/static/ на страницу Synapse
 - 
_____
#        Готово! Но одно но:
Сейчас любой желающий может зарегестрироваться на вашем сервере (в клиентах или через element-web).
---
Управление регистрацией в Synapse задаётся в файле homeserver.yaml. Сейчас у вас включены параметры:
```yaml
enable_registration: true
enable_registration_without_verification: true
```
Это означает, что любой желающий может зарегистрироваться (даже без подтверждения email).
---
## 🔧 Варианты ограничения регистрации:
1. Полное закрытие регистрации (только ручное создание пользователей)
   Самый простой способ – отключить регистрацию совсем. Тогда новые учётные записи смогут создавать только администраторы через команду `register_new_matrix_user` или через API с использованием `registration_shared_secret` (он у вас уже есть).
   В homeserver.yaml измените:
    ```yaml
    enable_registration: false
    # enable_registration_without_verification можно удалить или закомментировать
    ```
   Сохраните файл и перезапустите Synapse:
   ```bash
   docker-compose restart synapse
    ```
   После этого кнопка регистрации в Element Web исчезнет, и попытка зарегистрироваться через клиент будет отклонена.
2. Регистрация только по приглашениям (с токенами)
   Если вы хотите, чтобы пользователи могли регистрироваться самостоятельно, но только по специальным ссылкам-приглашениям, включите регистрацию по токенам.
   - Настройка:
     - Установите `enable_registration`: true (оставьте как есть).
     - Добавьте параметр:
     ```yaml
     registration_requires_token: true
     ```
     - Создайте токены приглашений. Это можно сделать через API или утилиту `register_new_matrix_user` с опцией `--token`. Например, войдите в контейнер `synapse` и выполните:
    ```bash
    docker-compose exec synapse register_new_matrix_user --token=TOKEN_ДЛЯ_ПРИГЛАШЕНИЯ -c /data/homeserver.yaml https://localhost:8008
    ```
   (можно не указывать пользователя, утилита спросит его отдельно)
    - Либо используйте клиентский API для массового создания токенов.
      После включения `registration_requires_token` при регистрации нужно будет ввести токен (обычно это поле появляется в клиенте).
3. Ограничение по доменам email (если используется email)
   Если вы планируете подтверждать email и хотите разрешить регистрацию только с определёнными адресами, можно настроить:
    ```yaml
    enable_registration: true
    enable_registration_without_verification: false  # требовать подтверждения email
    registrations_require_3pid:
      - email
    allowed_local_3pids:
      - medium: email
    pattern: "^.*@ваш-домен\\.ru$"   # регулярка для разрешённых доменов
    ```
   Не забудьте настроить email-отправку (параметры email в конфиге) – иначе подтверждение работать не будет.



