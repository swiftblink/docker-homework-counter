# Проверки домашнего задания по Docker

## Один контейнер

Сборка `docker build -t counter-app:1 .` завершилась успешно. Контейнер был запущен с публикацией `127.0.0.1:8080:8000` и переменной `GREETING='Привет из Docker!'`.

- `GET /` вернул `count: 0`, `storage: "sqlite"` и переданное приветствие.
- `POST /increment` вернул `count: 1`; следующий `GET /` также вернул `count: 1`.
- `GET /readyz` вернул `{"status": "ready", "storage": "sqlite"}`.
- `docker logs counter-app` показал запуск приложения и успешные HTTP-запросы со статусом `200`.

## Compose и сохранение SQLite

В Compose были настроены порт, приветствие и именованный volume для `/data`.

- После `docker compose down` и `docker compose up -d` `GET /` вернул прежний `count: 1`.
- Hostname изменился с `1706a50fc7e6` на `738630a8d442`, то есть ответ пришёл от заново созданного контейнера.

## Redis, сохранение и готовность

В финальной конфигурации Compose запущены сервисы `app` и `redis`. Redis использует именованный volume `/data` и AOF persistence.

- `docker compose config` прошёл после исправления YAML; `docker compose up -d --build` запустил оба сервиса, Redis стал `healthy`.
- В режиме Redis `POST /increment` увеличил счётчик до `1`.
- После `docker compose down` и повторного `up -d` `GET /` сохранил `count: 1`; hostname сменился с `117b6fe549f4` на `7c068e01d6d2`.
- После `docker compose stop redis`: `/healthz` вернул `200`; `/readyz`, `GET /` и `POST /increment` вернули `503` с `storage_unavailable`.
- После `docker compose start redis`: `/readyz` снова вернул `200`, `GET /` показал сохранённый `count: 1`, следующий `POST /increment` вернул `count: 2`.

## Проверочный скрипт

Добавлен `scripts/check.sh` для автоматизации проверки Redis-backed запуска, инкремента, сохранения данных, поведения при недоступном Redis и восстановления.
