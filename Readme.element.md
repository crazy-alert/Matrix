# 🔧 Основные настройки и их влияние
## 1. Подключение к серверу
   ```json
   {
   "default_server_config": {
       "m.homeserver": {
        "base_url": "https://matrix.ваш-домен.ru"
       },
       "m.identity_server": {
       "  base_url": "https://vector.im"
       }
   }
   }
   ```
`base_url` — главный адрес вашего Synapse-сервера (обычно https://matrix.ваш-домен.ru). Клиент будет отправлять все запросы (логин, отправка сообщений, синхронизация) именно сюда.

`identity_server` — сервер идентификации (для поиска пользователей по email/телефону). По умолчанию vector.im, можно отключить или указать свой.

## 2. Интерфейс и брендирование
   ```json
   {
   "brand": "Element",
   "desktop_build": false,
   "mobile_build": false
   }
   ```
`brand` — название клиента, отображаемое в заголовке и интерфейсе. Можно заменить на своё, например "Чат компании".

`desktop_build`/`mobile_build` — флаги, определяющие, для какой платформы собирается интерфейс (влияет на некоторые адаптации).

## 3. Ограничения и функции
   ```json
   {
   "disable_custom_urls": true,
   "disable_3pid_login": false,
   "disable_login_language_selector": false,
   "features": {
    "feature_pinning": true
   }
   }
   ```
`disable_custom_urls` — если true, пользователь не сможет вручную ввести адрес другого Matrix-сервера при входе.

`disable_3pid_login` — запретить вход через email/телефон.

`features` — включение экспериментальных функций (зависят от версии Element).

## 4. Настройки по умолчанию для новых пользователей
   ```json
   {
   "default_theme": "light",
   "default_country_code": "RU",
   "room_directory": {
      "servers": ["matrix.org"]
   }
   }
   ```
`default_theme` — светлая или тёмная тема по умолчанию.

`room_directory` — список серверов, чьи публичные комнаты показывать в каталоге.


### 🛠️ Типичный пример для данного стека
```json
{
    "default_server_config": {
        "m.homeserver": {
          "base_url": "https://matrix.вашдомен.ru"
        },
        "m.identity_server": {
          "base_url": "https://vector.im"
        }
    },
    "disable_custom_urls": false,
    "disable_3pid_login": false,
    "brand": "Element",
    "integrations_ui_url": "https://scalar.vector.im/",
    "integrations_rest_url": "https://scalar.vector.im/api",
    "integrations_jitsi_widget_url": "https://scalar.vector.im/api/widgets/jitsi.html",
    "room_directory": {
      "servers": ["matrix.org", "вашдомен.ru"]
    }
}
```

Разумеется, после внесения изменений необходимо перезагрузить контейнер