#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"

fail() {
  printf 'Ошибка: %s\n' "$*" >&2
  exit 1
}

count_from_json() {
  printf '%s' "$1" | sed -n 's/.*"count": *\([0-9][0-9]*\).*/\1/p'
}

http_code() {
  curl -sS -o /dev/null -w '%{http_code}' "$1"
}

wait_until_ready() {
  local attempt
  for attempt in {1..30}; do
    if [[ "$(http_code "$BASE_URL/readyz" 2>/dev/null || true)" == "200" ]]; then
      return 0
    fi
    sleep 1
  done
  fail "приложение не стало доступно по адресу $BASE_URL"
}

assert_code() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  [[ "$actual" == "$expected" ]] || fail "$label: ожидался HTTP $expected, получен $actual"
}

trap 'docker compose start redis >/dev/null 2>&1 || true' EXIT

printf 'Запускаю сервисы Compose...\n'
docker compose up -d --build
wait_until_ready

initial_json="$(curl -fsS "$BASE_URL/")"
case "$initial_json" in
  *'"storage": "redis"'*) ;;
  *) fail "приложение не использует Redis: $initial_json" ;;
esac
initial_count="$(count_from_json "$initial_json")"
[[ -n "$initial_count" ]] || fail "не удалось прочитать начальное значение счётчика: $initial_json"

increment_json="$(curl -fsS -X POST "$BASE_URL/increment")"
increment_count="$(count_from_json "$increment_json")"
expected_count=$((initial_count + 1))
[[ "$increment_count" == "$expected_count" ]] || fail "после увеличения ожидалось $expected_count, получено ${increment_count:-значение отсутствует}"
printf 'Счётчик увеличился: %s -> %s\n' "$initial_count" "$increment_count"

printf 'Пересоздаю контейнеры для проверки сохранения данных...\n'
docker compose down
docker compose up -d
wait_until_ready
persisted_json="$(curl -fsS "$BASE_URL/")"
persisted_count="$(count_from_json "$persisted_json")"
[[ "$persisted_count" == "$increment_count" ]] || fail "после пересоздания ожидалось $increment_count, получено ${persisted_count:-значение отсутствует}"
printf 'После пересоздания счётчик сохранил значение %s\n' "$persisted_count"

printf 'Останавливаю Redis и проверяю коды HTTP...\n'
docker compose stop redis
assert_code 200 "$(http_code "$BASE_URL/healthz")" '/healthz при остановленном Redis'
assert_code 503 "$(http_code "$BASE_URL/readyz")" '/readyz при остановленном Redis'
assert_code 503 "$(http_code "$BASE_URL/")" 'GET / при остановленном Redis'
assert_code 503 "$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$BASE_URL/increment")" 'POST /increment при остановленном Redis'
printf 'Коды совпали: /healthz — 200, остальные запросы — 503\n'

printf 'Запускаю Redis и проверяю восстановление...\n'
docker compose start redis
wait_until_ready
recovered_json="$(curl -fsS "$BASE_URL/")"
recovered_count="$(count_from_json "$recovered_json")"
[[ "$recovered_count" == "$persisted_count" ]] || fail "после восстановления Redis ожидалось $persisted_count, получено ${recovered_count:-значение отсутствует}"
final_json="$(curl -fsS -X POST "$BASE_URL/increment")"
final_count="$(count_from_json "$final_json")"
expected_final=$((persisted_count + 1))
[[ "$final_count" == "$expected_final" ]] || fail "после увеличения счётчика ожидалось $expected_final, получено ${final_count:-значение отсутствует}"
printf 'Redis снова доступен. Счётчик: %s -> %s\n' "$persisted_count" "$final_count"
printf 'Все проверки прошли.\n'
