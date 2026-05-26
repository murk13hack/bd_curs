#!/usr/bin/env bash
# Накатывание / удаление демонстрационного набора данных ПТТ.
set -euo pipefail

ACTION="${1:-seed}"
CONTAINER="${CONTAINER:-ptt-db}"
USER="${POSTGRES_USER:-ptt}"
DATABASE="${POSTGRES_DB:-ptt}"
FORCE="${FORCE:-0}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEMO_DIR="$ROOT/db/demo"

if [[ -f "$ROOT/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "$ROOT/.env"
  set +a
  USER="${POSTGRES_USER:-$USER}"
  DATABASE="${POSTGRES_DB:-$DATABASE}"
fi

run_sql() {
  local file="$1"
  echo "Running $(basename "$file") ..."
  docker cp "$file" "${CONTAINER}:/tmp/$(basename "$file")"
  docker exec "$CONTAINER" psql -U "$USER" -d "$DATABASE" -v ON_ERROR_STOP=1 \
    -f "/tmp/$(basename "$file")"
}

ensure_db_ready() {
  if ! docker inspect "$CONTAINER" &>/dev/null; then
    echo "Контейнер $CONTAINER не найден. Запустите: docker compose up -d" >&2
    exit 1
  fi
  if ! docker exec "$CONTAINER" pg_isready -U "$USER" -d "$DATABASE" &>/dev/null; then
    echo "PostgreSQL не готов в $CONTAINER" >&2
    exit 1
  fi
}

ensure_migration_015() {
  local mig="$ROOT/db/migrations/015_auto_task_created_at.sql"
  if [[ -f "$mig" ]]; then
    echo ">>> патч триггера auto_create_task (015, идемпотентно)"
    docker cp "$mig" "${CONTAINER}:/tmp/015_auto_task_created_at.sql"
    docker exec "$CONTAINER" psql -U "$USER" -d "$DATABASE" -v ON_ERROR_STOP=1 \
      -f /tmp/015_auto_task_created_at.sql
  fi
}

demo_status() {
  docker exec "$CONTAINER" psql -U "$USER" -d "$DATABASE" -t -A -c \
    "SELECT CASE WHEN EXISTS (SELECT 1 FROM app_settings WHERE user_id=1 AND key='_demo_dataset') THEN 'loaded' ELSE 'empty' END;"
}

print_summary() {
  echo ""
  echo "=== Сводка демо-данных ==="
  docker exec "$CONTAINER" psql -U "$USER" -d "$DATABASE" -c \
    "SELECT value->>'loaded_at' AS loaded_at,
            jsonb_array_length(value->'tasks') AS tasks,
            jsonb_array_length(value->'behavior_patterns') AS patterns,
            jsonb_array_length(value->'diary_entries') AS diary,
            jsonb_array_length(value->'goals') AS goals
       FROM app_settings WHERE user_id=1 AND key='_demo_dataset';"
  docker exec "$CONTAINER" psql -U "$USER" -d "$DATABASE" -c \
    "SELECT COUNT(*) AS demo_tasks_visible FROM tasks WHERE user_id=1 AND title LIKE '[демо]%';"
  echo ""
  echo "UI: http://localhost:${FRONTEND_PORT:-80}/"
  echo "API: curl -s http://localhost:${FRONTEND_PORT:-80}/api/v1/ping"
}

ensure_db_ready

case "$ACTION" in
  status)
    state="$(demo_status)"
    if [[ "$state" == "loaded" ]]; then
      print_summary
    else
      echo "Demo dataset: not loaded."
      docker exec "$CONTAINER" psql -U "$USER" -d "$DATABASE" -c \
        "SELECT COUNT(*) AS orphan_demo_tasks FROM tasks WHERE user_id=1 AND title LIKE '[демо]%';"
    fi
    ;;
  wipe)
    run_sql "$DEMO_DIR/wipe_demo.sql"
    echo "Demo data removed."
    ;;
  seed)
    ensure_migration_015
    state="$(demo_status)"
    if [[ "$state" == "loaded" ]]; then
      if [[ "$FORCE" == "1" ]]; then
        echo "Demo already loaded; FORCE=1: wiping first..."
        run_sql "$DEMO_DIR/wipe_demo.sql"
      else
        echo "Demo data already loaded. Run: $0 wipe  OR  FORCE=1 $0 seed" >&2
        exit 1
      fi
    fi
    run_sql "$DEMO_DIR/seed_demo.sql"
    print_summary
    echo "Demo data loaded OK."
    ;;
  *)
    echo "Usage: $0 {seed|wipe|status}" >&2
    exit 1
    ;;
esac
