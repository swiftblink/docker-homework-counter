#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
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
  fail "app did not become ready at $BASE_URL"
}

assert_code() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  [[ "$actual" == "$expected" ]] || fail "$label: expected HTTP $expected, got $actual"
}

trap 'docker compose start redis >/dev/null 2>&1 || true' EXIT

printf 'Starting Compose services...\n'
docker compose up -d --build
wait_until_ready

initial_json="$(curl -fsS "$BASE_URL/")"
case "$initial_json" in
  *'"storage": "redis"'*) ;;
  *) fail "app is not reporting Redis storage: $initial_json" ;;
esac
initial_count="$(count_from_json "$initial_json")"
[[ -n "$initial_count" ]] || fail "could not read initial count: $initial_json"

increment_json="$(curl -fsS -X POST "$BASE_URL/increment")"
increment_count="$(count_from_json "$increment_json")"
expected_count=$((initial_count + 1))
[[ "$increment_count" == "$expected_count" ]] || fail "increment expected $expected_count, got ${increment_count:-no count}"
printf 'PASS: increment %s -> %s\n' "$initial_count" "$increment_count"

printf 'Recreating Compose services to check persistence...\n'
docker compose down
docker compose up -d
wait_until_ready
persisted_json="$(curl -fsS "$BASE_URL/")"
persisted_count="$(count_from_json "$persisted_json")"
[[ "$persisted_count" == "$increment_count" ]] || fail "after recreation expected $increment_count, got ${persisted_count:-no count}"
printf 'PASS: count %s survived Compose recreation\n' "$persisted_count"

printf 'Stopping Redis and checking expected HTTP statuses...\n'
docker compose stop redis
assert_code 200 "$(http_code "$BASE_URL/healthz")" '/healthz while Redis is stopped'
assert_code 503 "$(http_code "$BASE_URL/readyz")" '/readyz while Redis is stopped'
assert_code 503 "$(http_code "$BASE_URL/")" 'GET / while Redis is stopped'
assert_code 503 "$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$BASE_URL/increment")" 'POST /increment while Redis is stopped'
printf 'PASS: healthz=200; readyz, GET /, and POST /increment=503\n'

printf 'Restarting Redis and checking recovery...\n'
docker compose start redis
wait_until_ready
recovered_json="$(curl -fsS "$BASE_URL/")"
recovered_count="$(count_from_json "$recovered_json")"
[[ "$recovered_count" == "$persisted_count" ]] || fail "after Redis recovery expected $persisted_count, got ${recovered_count:-no count}"
final_json="$(curl -fsS -X POST "$BASE_URL/increment")"
final_count="$(count_from_json "$final_json")"
expected_final=$((persisted_count + 1))
[[ "$final_count" == "$expected_final" ]] || fail "after recovery increment expected $expected_final, got ${final_count:-no count}"
printf 'PASS: Redis recovered; count %s -> %s\n' "$persisted_count" "$final_count"
printf 'All checks passed.\n'
