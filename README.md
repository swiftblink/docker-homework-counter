# Счётчик в Docker

## Запуск через Compose

```bash
cp .env.example .env
docker compose up -d --build --wait
```

В `.env` можно изменить `HOST_PORT` (по умолчанию `8080`) и `GREETING` (текст приветствия). В `compose.yaml` описаны два сервиса: `app` и `redis`. Приложение подключается к Redis по адресу `redis://redis:6379/0`. Наружу опубликован только порт приложения. Redis сохраняет данные в именованном томе `redis-data`, подключённом к `/data`.

```bash
curl -fsS http://127.0.0.1:8080/
curl -fsS -X POST http://127.0.0.1:8080/increment
curl -fsS http://127.0.0.1:8080/readyz
```

Первый запрос читает счётчик, второй увеличивает его на единицу, третий проверяет доступность хранилища. Если поменял порт в `.env`, подставь его в команды.

## Запуск одного контейнера

При свободном порте `8080` можно запустить приложение с SQLite:

```bash
docker build -t counter-app:1 .
docker run -d --name counter-app -p 127.0.0.1:8080:8000 -e GREETING="Привет из Docker!" counter-app:1
docker logs counter-app
```

Для остановки и удаления контейнера выполни `docker stop counter-app` и `docker rm counter-app`.

## Проверка

Из корня репозитория запусти:

```bash
bash scripts/check.sh
```

Скрипт проверяет увеличение счётчика, сохранение данных после пересоздания контейнеров и поведение приложения при остановке и повторном запуске Redis. Для другого порта задай `BASE_URL`, например `BASE_URL=http://127.0.0.1:8081 bash scripts/check.sh`. Результаты ручных проверок находятся в [REPORT.md](REPORT.md).

Чтобы остановить сервисы с сохранением данных, выполни `docker compose down`.
