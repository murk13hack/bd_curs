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
      grep '^#' "$0" | head -24 | sed 's/^# \{0,1\}//'
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

# shellcheck disable=SC1091
set -a
source .env
set +a

if [[ -z "${POSTGRES_PASSWORD:-}" || "${POSTGRES_PASSWORD}" == "change_me_to_strong_password" ]]; then
  echo "Задайте надёжный POSTGRES_PASSWORD в .env (не оставляйте change_me_to_strong_password)." >&2
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

print_diagnostics() {
  echo ""
  echo "=== Диагностика (скопируйте вывод при обращении за помощью) ==="
  docker compose ps -a 2>/dev/null || true
  echo ""
  echo "--- db (последние 40 строк) ---"
  docker compose logs db --tail 40 2>/dev/null || true
  echo ""
  echo "--- backend (последние 60 строк) ---"
  docker compose logs backend --tail 60 2>/dev/null || true
  echo ""
  if docker inspect ptt-db &>/dev/null; then
    echo "db health: $(docker inspect ptt-db --format '{{.State.Health.Status}}' 2>/dev/null || echo 'n/a')"
  fi
  if docker inspect ptt-backend &>/dev/null; then
    echo "backend health: $(docker inspect ptt-backend --format '{{.State.Health.Status}}' 2>/dev/null || echo 'n/a')"
  fi
  echo ""
  echo "Частые причины на Fedora:"
  echo "  1) POSTGRES_PASSWORD в .env не совпадает с уже созданным volume → docker compose down -v && docker compose up -d --build"
  echo "  2) Порт 80 занят → в .env FRONTEND_PORT=8080"
  echo "  3) Docker без прав → sudo usermod -aG docker \$USER && newgrp docker"
  echo "  4) Медленная первая сборка → подождите и: docker compose up -d && docker compose logs -f backend"
}

wait_healthy() {
  local name="$1"
  local max_attempts="${2:-45}"
  local i status run_status

  for (( i = 1; i <= max_attempts; i++ )); do
    if ! docker inspect "$name" &>/dev/null; then
      echo "  $name: ещё не создан ($i/$max_attempts)..."
      sleep 2
      continue
    fi
    run_status="$(docker inspect "$name" --format '{{.State.Status}}' 2>/dev/null || echo missing)"
    if [[ "$run_status" == "exited" || "$run_status" == "dead" ]]; then
      echo "  $name: контейнер остановлен ($run_status)" >&2
      return 1
    fi
    status="$(docker inspect "$name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || echo missing)"
    if [[ "$status" == "healthy" ]]; then
      echo "  $name: healthy"
      return 0
    fi
    echo "  $name: $status ($i/$max_attempts)..."
    sleep 2
  done
  echo "  таймаут ожидания $name" >&2
  return 1
}

echo "=== ПТТ: обновление ==="

if [[ $SKIP_PULL -eq 0 ]] && git rev-parse --is-inside-work-tree &>/dev/null; then
  echo ">>> git pull"
  git pull origin main || git pull
fi

echo ">>> docker compose up -d --build"
if ! docker compose up -d --build; then
  print_diagnostics
  exit 1
fi

echo ">>> ожидание healthy: db"
if ! wait_healthy ptt-db 45; then
  print_diagnostics
  exit 1
fi

echo ">>> ожидание healthy: backend"
if ! wait_healthy ptt-backend 60; then
  print_diagnostics
  exit 1
fi

# frontend поднимется после backend; необязательно ждать для миграций
docker compose up -d frontend 2>/dev/null || true

if [[ $FRESH_HINT -eq 1 ]]; then
  echo ""
  echo "Режим --fresh: если volume pgdata создан впервые, миграции 007–014 НЕ нужны."
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
echo "Откройте: http://localhost:${FRONTEND_PORT:-80}"
echo "API ping:  curl -s http://localhost:${FRONTEND_PORT:-80}/api/v1/ping"
