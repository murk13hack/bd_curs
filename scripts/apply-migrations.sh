#!/usr/bin/env bash
# Применить SQL-миграции к уже существующей БД (volume pgdata).
# На чистой установке (первый docker compose up) миграции не нужны — init уже актуален.
#
# Использование:
#   ./scripts/apply-migrations.sh              # миграции 007–014 (рекомендуется)
#   ./scripts/apply-migrations.sh --all        # все db/migrations/*.sql по порядку
#   ./scripts/apply-migrations.sh --from 009   # с 009 и выше

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONTAINER="${PTT_DB_CONTAINER:-ptt-db}"
PGUSER="${POSTGRES_USER:-ptt}"
PGDB="${POSTGRES_DB:-ptt}"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env
  set +a
  PGUSER="${POSTGRES_USER:-$PGUSER}"
  PGDB="${POSTGRES_DB:-$PGDB}"
fi

MODE="recent"
FROM_VER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) MODE="all" ;;
    --from)
      MODE="from"
      FROM_VER="${2:?укажите номер, например 009}"
      shift
      ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 1 ;;
  esac
  shift
done

if ! docker inspect "$CONTAINER" &>/dev/null; then
  echo "Контейнер $CONTAINER не найден. Сначала: docker compose up -d" >&2
  exit 1
fi

if ! docker exec "$CONTAINER" pg_isready -U "$PGUSER" -d "$PGDB" &>/dev/null; then
  echo "PostgreSQL в $CONTAINER не готов (pg_isready)." >&2
  exit 1
fi

mapfile -t ALL_FILES < <(find db/migrations -maxdepth 1 -name '*.sql' | sort)

pick_files() {
  local f base num
  for f in "${ALL_FILES[@]}"; do
    base="$(basename "$f")"
    num="${base%%_*}"
    case "$MODE" in
      all) echo "$f" ;;
      recent)
        [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 7 )) && echo "$f"
        ;;
      from)
        [[ "$num" =~ ^[0-9]+$ ]] && (( num >= FROM_VER )) && echo "$f"
        ;;
    esac
  done
}

FILES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && FILES+=("$line")
done < <(pick_files)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Нет файлов миграций для режима $MODE" >&2
  exit 1
fi

echo "=== Миграции БД (контейнер: $CONTAINER, БД: $PGDB) ==="
echo "Файлов: ${#FILES[@]}"
echo ""

for f in "${FILES[@]}"; do
  name="$(basename "$f")"
  echo ">>> $name"
  docker cp "$f" "${CONTAINER}:/tmp/${name}"
  docker exec "$CONTAINER" psql -U "$PGUSER" -d "$PGDB" -v ON_ERROR_STOP=1 -f "/tmp/${name}"
  docker exec "$CONTAINER" rm -f "/tmp/${name}" 2>/dev/null || true
  echo ""
done

echo "=== Готово: ${#FILES[@]} миграций применено ==="
echo "Проверка (опционально):"
echo "  docker compose exec backend pytest tests/test_patterns.py tests/test_stats.py -q"
echo "  docker cp db/tests/smoke.sql ${CONTAINER}:/tmp/smoke.sql"
echo "  docker exec ${CONTAINER} psql -U ${PGUSER} -d ${PGDB} -v ON_ERROR_STOP=1 -f /tmp/smoke.sql"
