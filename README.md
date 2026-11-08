# Счётчик в Docker

## Запуск через Docker Compose

```bash
cp .env.example .env
docker compose up -d --build --wait
```

В `.env` можно изменить `HOST_PORT` (по умолчанию `8080`) и `GREETING` (приветствие). Compose запускает приложение и Redis. На хосте доступен только порт приложения, а Redis сохраняет счётчик в томе `redis-data`.

```bash
curl -fsS http://127.0.0.1:8080/
curl -fsS -X POST http://127.0.0.1:8080/increment
```

Первый запрос показывает значение счётчика, второй увеличивает его на единицу. Если изменил `HOST_PORT`, подставь этот порт в адрес.

## Запуск одного контейнера с SQLite

```bash
docker build -t counter-app:1 .
docker run --rm -d --name counter-app \
  -p 127.0.0.1:8080:8000 \
  -e GREETING="Привет из Docker!" counter-app:1
```

Запускай этот вариант при свободном порте 8080. Для остановки выполни `docker stop counter-app`.

## Проверка

Из корня репозитория запусти `bash scripts/check.sh`. Если порт отличается от 8080, передай адрес, например `BASE_URL=http://127.0.0.1:8081 bash scripts/check.sh`. Результаты ручной проверки есть в [REPORT.md](REPORT.md).

Чтобы остановить Compose и сохранить данные, выполни `docker compose down`.
