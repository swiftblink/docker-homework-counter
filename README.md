# Docker homework: counter service

The supplied application in `app/` is unchanged. It serves a JSON counter over HTTP.

## Configuration

Copy `.env.example` to `.env`, then adjust these Compose settings if needed:

| Variable | Default | Purpose |
| --- | --- | --- |
| `HOST_PORT` | `8080` | Port on the local computer |
| `GREETING` | `Hello from Compose!` | Greeting returned by the app |

The app listens on port `8000` inside its container. In the final Compose setup it uses Redis at `redis://redis:6379/0`; Redis is reachable by its Compose service name, `redis`. Only the app's port is published on the host.

## Level: one container (4 points)

From the project root:

```bash
docker build -t counter-app:1 .
docker run -d --name counter-app \
  -p 127.0.0.1:8080:8000 \
  -e GREETING='Hello from Docker!' \
  counter-app:1
```

The app defaults to SQLite at `/data/counter.db`. Without a mounted volume, deleting this container deletes its database with it.

```bash
curl -fsS http://127.0.0.1:8080/
curl -fsS -X POST http://127.0.0.1:8080/increment
curl -fsS http://127.0.0.1:8080/readyz
docker logs counter-app
```

`GET /` reads the counter; `POST /increment` increases it. Stop and remove this one-off container before starting Compose:

```bash
docker stop counter-app
docker rm counter-app
```

## Level: Compose with SQLite volume (6 points)

For the SQLite variant, the Compose settings are:

```yaml
services:
  app:
    build: .
    ports:
      - "127.0.0.1:${HOST_PORT:-8080}:8000"
    environment:
      PORT: "8000"
      GREETING: "${GREETING:-Hello from Compose!}"
      STORAGE: "sqlite"
      DATA_FILE: "/data/counter.db"
    volumes:
      - counter-data:/data

volumes:
  counter-data:
```

Compose automatically reads `.env` for `${...}` substitutions; `.env.example` is a template and must be copied first.

```bash
cp .env.example .env
docker compose up -d --build
docker compose ps
curl -fsS http://127.0.0.1:8080/
curl -fsS -X POST http://127.0.0.1:8080/increment
docker compose down
docker compose up -d
curl -fsS http://127.0.0.1:8080/
```

The value should survive because the named volume remains after ordinary `docker compose down`. Do not add `--volumes` when checking persistence.

## Level: separate Redis service (8–10 points)

The included `compose.yaml` is the final Redis setup. It runs `app` and `redis`, sets `STORAGE=redis` and `REDIS_URL=redis://redis:6379/0`, stores Redis data in the named `redis-data` volume at `/data`, enables Redis AOF persistence, and defines healthchecks for both services.

```bash
cp .env.example .env
docker compose config
docker compose up -d --build
docker compose ps
curl -fsS http://127.0.0.1:8080/
curl -fsS -X POST http://127.0.0.1:8080/increment
curl -fsS http://127.0.0.1:8080/readyz
```

To confirm Redis data survives container recreation, record the current `count`, then run:

```bash
docker compose down
docker compose up -d
curl -fsS http://127.0.0.1:8080/
```

The count should be unchanged. `docker compose down --volumes` deletes the Redis volume and its data; do not use it for this check.

To verify behavior while Redis is unavailable and after it returns:

```bash
docker compose stop redis
curl -i http://127.0.0.1:8080/healthz
curl -i http://127.0.0.1:8080/readyz
curl -i http://127.0.0.1:8080/
curl -i -X POST http://127.0.0.1:8080/increment
docker compose start redis
docker compose ps
curl -fsS http://127.0.0.1:8080/readyz
curl -fsS http://127.0.0.1:8080/
curl -fsS -X POST http://127.0.0.1:8080/increment
```

While Redis is stopped, `/healthz` should return `200`, and `/readyz`, `GET /`, and `POST /increment` should return `503`. After Redis is healthy, readiness should return `200`, the previous count should be present, and the next increment should add one.

## Automated check (10 points)

The script `scripts/check.sh` checks Redis-backed counter increments, persistence across Compose recreation, availability responses during Redis downtime, and recovery afterwards. Run it from the project root:

```bash
chmod +x scripts/check.sh
./scripts/check.sh
```

It requires Bash, Docker Compose, and `curl`. Set `BASE_URL` if the app uses a non-default host port, for example `BASE_URL=http://127.0.0.1:8081 ./scripts/check.sh`.

## Cleanup

```bash
docker compose down
```

This stops and removes the Compose containers and network while preserving the named volume. To permanently delete the saved counter too, use `docker compose down --volumes`.
