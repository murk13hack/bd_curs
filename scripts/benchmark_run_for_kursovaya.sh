#!/usr/bin/env bash
# Один прогон бенчмарка для курсовой → docs/benchmark_explain_out.txt
# Использование (из корня репозитория):
#   chmod +x scripts/benchmark_run_for_kursovaya.sh
#   ./scripts/benchmark_run_for_kursovaya.sh
#   ./scripts/benchmark_run_for_kursovaya.sh 10000
#
# Пришлите ассистенту: docs/benchmark_explain_out.txt

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONTAINER="${CONTAINER:-ptt-db}"
COUNT="${1:-${COUNT:-10000}}"
OUT="${OUT:-$ROOT/docs/benchmark_explain_out.txt}"

if [[ ! -f "$ROOT/.env" ]]; then
  echo "Файл .env не найден. Выполните: cp .env.example .env" >&2
  exit 1
fi

running="$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || echo false)"
if [[ "$running" != "true" ]]; then
  echo "Контейнер $CONTAINER не запущен. Выполните: docker compose up -d" >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
source "$ROOT/.env"
set +a
PGUSER="${POSTGRES_USER:-ptt}"
PGDB="${POSTGRES_DB:-ptt}"

echo "==> Загрузка $COUNT bench-задач..."
docker cp "$ROOT/scripts/benchmark_load_tasks.sql" "$CONTAINER:/tmp/benchmark_load_tasks.sql"
docker exec "$CONTAINER" psql -U "$PGUSER" -d "$PGDB" -v ON_ERROR_STOP=1 -c \
  "DELETE FROM tasks WHERE user_id = 1 AND title LIKE 'Bench #%';"
docker exec "$CONTAINER" psql -U "$PGUSER" -d "$PGDB" -v ON_ERROR_STOP=1 -v count="$COUNT" \
  -f /tmp/benchmark_load_tasks.sql

echo "==> Seed дневника (500 записей, слово «продуктивность»)..."
docker cp "$ROOT/scripts/benchmark_seed_diary.sql" "$CONTAINER:/tmp/benchmark_seed_diary.sql"
docker exec "$CONTAINER" psql -U "$PGUSER" -d "$PGDB" -v ON_ERROR_STOP=1 \
  -f /tmp/benchmark_seed_diary.sql

echo "==> EXPLAIN (Q1–Q6, Q2a/Q2b) → $OUT"
mkdir -p "$(dirname "$OUT")"
docker cp "$ROOT/scripts/benchmark_for_kursovaya.sql" "$CONTAINER:/tmp/benchmark_for_kursovaya.sql"
docker exec "$CONTAINER" psql -U "$PGUSER" -d "$PGDB" -v ON_ERROR_STOP=1 \
  -f /tmp/benchmark_for_kursovaya.sql >"$OUT" 2>&1

echo ""
echo "Готово: $OUT"
echo "Отправьте этот файл в чат (или блок между MARKER_START и MARKER_END)."
