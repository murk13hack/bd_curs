#!/usr/bin/env bash
# Обновление ПТТ на Fedora (или любом Linux с Docker Compose v2).
#
#   chmod +x scripts/deploy-fedora.sh scripts/apply-migrations.sh
#   ./scripts/deploy-fedora.sh
#
# Опции:
#   --skip-pull     не делать git pull
#   --skip-migrate  не применять миграции (только пересборка контейнеров)
#   --fresh         предупреждение: для новой БД миграции не нужны

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SKIP_PULL=0
SKIP_MIGRATE=0
FRESH_HINT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-pull) SKIP_PULL=1 ;;
    --skip-migrate) SKIP_MIGRATE=1 ;;
    --fresh) FRESH_HINT=1 ;;
    -h|--help)
      grep '^#' "$0" | head -20 | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 1 ;;
  esac
  shift
done

if [[ ! -f .env ]]; then
  echo "Нет .env — скопируйте: cp .env.example .env && отредактируйте POSTGRES_PASSWORD" >&2
  exit 1
fi

if ! command -v docker &>/dev/null; then
  echo "Docker не установлен. Fedora: sudo dnf install docker docker-compose-plugin" >&2
  exit 1
fi

if ! docker compose version &>/dev/null; then
  echo "Нужен Docker Compose v2 (docker compose)." >&2
  exit 1
fi

echo "=== ПТТ: обновление ==="

if [[ $SKIP_PULL -eq 0 ]] && git rev-parse --is-inside-work-tree &>/dev/null; then
  echo ">>> git pull"
  git pull origin main || git pull
fi

echo ">>> docker compose up -d --build"
docker compose up -d --build

echo ">>> ожидание healthy БД"
for i in {1..30}; do
  if docker inspect ptt-db --format '{{.State.Health.Status}}' 2>/dev/null | grep -q healthy; then
    break
  fi
  sleep 2
done

if [[ $FRESH_HINT -eq 1 ]]; then
  echo ""
  echo "Режим --fresh: если volume pgdata создан впервые, миграции 007–013 НЕ нужны."
  echo "Пропускаем apply-migrations.sh"
  SKIP_MIGRATE=1
fi

if [[ $SKIP_MIGRATE -eq 0 ]]; then
  echo ""
  echo ">>> миграции (только для существующей БД; повторный прогон обычно безопасен)"
  bash scripts/apply-migrations.sh
else
  echo ">>> миграции пропущены (--skip-migrate или --fresh)"
fi

echo ""
echo "=== Сервисы ==="
docker compose ps

echo ""
echo "Откройте: http://localhost (или порт из FRONTEND_PORT в .env)"
echo "API ping:  curl -s http://localhost/api/v1/ping"
