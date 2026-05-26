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

run_sql() {
  local file="$1"
  echo "Running $(basename "$file") ..."
  docker cp "$file" "${CONTAINER}:/tmp/$(basename "$file")"
  docker exec "$CONTAINER" psql -U "$USER" -d "$DATABASE" -v ON_ERROR_STOP=1 \
    -f "/tmp/$(basename "$file")"
}

demo_status() {
  docker exec "$CONTAINER" psql -U "$USER" -d "$DATABASE" -t -A -c \
    "SELECT CASE WHEN EXISTS (SELECT 1 FROM app_settings WHERE user_id=1 AND key='_demo_dataset') THEN 'loaded' ELSE 'empty' END;"
}

case "$ACTION" in
  status)
    state="$(demo_status)"
    if [[ "$state" == "loaded" ]]; then
      docker exec "$CONTAINER" psql -U "$USER" -d "$DATABASE" -c \
        "SELECT value->>'loaded_at' AS loaded_at, jsonb_array_length(value->'tasks') AS tasks, jsonb_array_length(value->'behavior_patterns') AS patterns, jsonb_array_length(value->'diary_entries') AS diary FROM app_settings WHERE user_id=1 AND key='_demo_dataset';"
    else
      echo "Demo dataset: not loaded."
    fi
    ;;
  wipe)
    run_sql "$DEMO_DIR/wipe_demo.sql"
    echo "Demo data removed."
    ;;
  seed)
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
    echo "Demo data loaded."
    ;;
  *)
    echo "Usage: $0 {seed|wipe|status}" >&2
    exit 1
    ;;
esac
