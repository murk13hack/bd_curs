#!/usr/bin/env bash
# Прогон бенчмарков EXPLAIN и генерация docs/benchmark_results.md (таблица 9 курсовой).
#
# Использование (из корня репозитория):
#   ./scripts/benchmark_report.sh
#   ./scripts/benchmark_report.sh --count 10000
#   ./scripts/benchmark_report.sh --skip-load
#   COUNT=100000 ./scripts/benchmark_report.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONTAINER="${CONTAINER:-ptt-db}"
COUNT="${COUNT:-10000}"
SKIP_LOAD=0
NO_DIARY_SEED=0
SKIP_Q2_COMPARE=0

usage() {
  cat <<'EOF'
Usage: ./scripts/benchmark_report.sh [options]

  --count N          число bench-задач (default: 10000)
  --skip-load        не загружать tasks (уже есть данные)
  --no-diary-seed    не дополнять diary_entries для FTS
  --skip-q2-compare  один прогон Q2 без drop/create GIN
  --container NAME   docker-контейнер (default: ptt-db)
  -h, --help         справка

Требуется: docker, python3, docker compose up -d, файл .env

Результат: docs/benchmark_results.md  (отправить блок «Таблица 9» в чат)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --count) COUNT="$2"; shift 2 ;;
    --skip-load) SKIP_LOAD=1; shift ;;
    --no-diary-seed) NO_DIARY_SEED=1; shift ;;
    --skip-q2-compare) SKIP_Q2_COMPARE=1; shift ;;
    --container) CONTAINER="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -f "$ROOT/.env" ]]; then
  echo "Файл .env не найден. Выполните: cp .env.example .env" >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
source "$ROOT/.env"
set +a

if ! docker inspect "$CONTAINER" &>/dev/null; then
  echo "Контейнер $CONTAINER не найден. Запустите: docker compose up -d" >&2
  exit 1
fi

running="$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || echo false)"
if [[ "$running" != "true" ]]; then
  echo "Контейнер $CONTAINER не запущен (или перезапускается)." >&2
  echo "Проверьте: docker compose ps && docker compose logs db" >&2
  exit 1
fi

PY=""
for cmd in python3 python py; do
  if command -v "$cmd" &>/dev/null; then
    PY="$cmd"
    break
  fi
done

if [[ -z "$PY" ]]; then
  echo "Python 3 не найден (нужен python3 для разбора EXPLAIN JSON)." >&2
  exit 1
fi

ARGS=( "$ROOT/scripts/benchmark_report.py" "--count" "$COUNT" "--container" "$CONTAINER" )
[[ "$SKIP_LOAD" -eq 1 ]] && ARGS+=( --skip-load )
[[ "$NO_DIARY_SEED" -eq 1 ]] && ARGS+=( --no-diary-seed )
[[ "$SKIP_Q2_COMPARE" -eq 1 ]] && ARGS+=( --skip-q2-compare )

echo "==> benchmark_report: container=$CONTAINER count=$COUNT"
exec "$PY" "${ARGS[@]}"
