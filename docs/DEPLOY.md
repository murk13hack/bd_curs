# Инструкция по развёртыванию ПТТ

> Приложение Ж к [ТЗ.md](../ТЗ.md). Краткая версия — в [README.md](../README.md).

## Требования

| Компонент | Минимум |
|---|---|
| ОС | Windows 10/11, macOS, Linux |
| RAM | 8 ГБ |
| Диск | 5 ГБ свободно |
| Docker | Docker Desktop 24+ или Docker Engine + Compose v2 |
| Браузер | Chrome / Firefox / Edge (актуальная версия) |

Node.js и Python на хосте **не обязательны** — всё собирается внутри Docker.

## 1. Установка Docker (Windows)

1. Скачать [Docker Desktop](https://www.docker.com/products/docker-desktop/).
2. Установить с опцией **Use WSL 2 instead of Hyper-V**.
3. Перезагрузить компьютер, дождаться зелёного значка Docker в трее.
4. Проверить в PowerShell:

```powershell
docker --version
docker compose version
```

## 2. Получение проекта

```powershell
git clone <url-репозитория> bd_curs
cd bd_curs
```

Или распаковать архив с исходниками и перейти в каталог `bd_curs`.

## 3. Конфигурация

```powershell
Copy-Item .env.example .env
```

Откройте `.env` и **обязательно** смените `POSTGRES_PASSWORD` на надёжный пароль.

Остальные переменные по умолчанию подходят для локального запуска:

| Переменная | Назначение | По умолчанию |
|---|---|---|
| `POSTGRES_DB` | Имя БД | `ptt` |
| `POSTGRES_USER` | Пользователь БД | `ptt` |
| `BACKEND_PORT` | Порт API на хосте | `8000` |
| `FRONTEND_PORT` | Порт UI на хосте | `80` |
| `VITE_API_URL` | Base URL API во фронте | `/api/v1` |
| `CORS_ORIGINS` | Разрешённые origin'ы | localhost |
| `TZ` | Часовой пояс | `Europe/Moscow` |

## 4. Сборка и запуск

```powershell
docker compose up -d --build
```

При **первом** запуске:

1. Скачиваются образы `postgres:16-alpine`, `node:20-alpine`, `python:3.12-slim`, `nginx:1.27-alpine`.
2. Собираются `ptt-backend` и `ptt-frontend`.
3. Контейнер `ptt-db` выполняет SQL-скрипты из `db/init/` (таблицы, view, функции, процедуры, триггеры, seed).

Проверка состояния:

```powershell
docker compose ps
```

Все три сервиса должны быть `running`, `db` и `backend`/`frontend` — `healthy`.

## 5. Открытие приложения

| URL | Назначение |
|---|---|
| http://localhost | Веб-интерфейс (React SPA) |
| http://localhost/api/v1/ping | Проверка API |
| http://localhost:8000/docs | Swagger UI |
| http://localhost:8000/redoc | ReDoc |
| http://localhost:8000/health | Healthcheck бэкенда |

Через nginx фронтенд проксирует `/api/` на бэкенд — отдельно настраивать CORS в браузере не нужно.

## 6. Логи и диагностика

```powershell
# все сервисы
docker compose logs -f

# один сервис
docker compose logs -f backend
docker compose logs -f db
```

Если `ptt-db` не стартует — смотрите логи init-скриптов:

```powershell
docker compose logs db | Select-String -Pattern "ERROR|FATAL"
```

## 7. Тестирование

### Backend (pytest, 55 тестов)

```powershell
docker compose exec backend pytest
```

### БД (smoke SQL)

```powershell
docker cp db/tests/smoke.sql ptt-db:/tmp/smoke.sql
docker exec ptt-db psql -U ptt -d ptt -f /tmp/smoke.sql
```

## 8. Резервное копирование

```powershell
New-Item -ItemType Directory -Force -Path backups
docker exec -t ptt-db pg_dump -U ptt -F c -d ptt > "backups/backup_$(Get-Date -Format yyyy-MM-dd).dump"
```

Рекомендуется настроить ежедневный запуск через Планировщик заданий Windows (03:00).

## 9. Восстановление из дампа

```powershell
docker exec -i ptt-db pg_restore -U ptt -d ptt --clean --if-exists < backups/backup_YYYY-MM-DD.dump
```

## 10. Остановка

```powershell
docker compose stop          # остановить, данные сохранить
docker compose down          # удалить контейнеры, volume сохранить
docker compose down -v       # удалить всё включая данные БД (необратимо!)
```

## 11. Обновление версии

```powershell
git pull
docker compose up -d --build
```

### База уже была развёрнута раньше (есть volume `pgdata`)

Скрипты из `db/init/` **не выполняются повторно**. После `git pull` примените миграции по порядку:

```powershell
$migrations = @(
  "007_pattern_logic_fixes.sql",
  "008_marker_day_closures.sql",
  "009_db_backend_sync.sql",
  "010_recurring_custom_interval.sql",
  "011_markers_success_and_streak_fix.sql"
)
foreach ($f in $migrations) {
  docker cp "db/migrations/$f" ptt-db:/tmp/$f
  docker exec ptt-db psql -U ptt -d ptt -v ON_ERROR_STOP=1 -f "/tmp/$f"
}
```

Linux / Fedora (рекомендуется):

```bash
chmod +x scripts/deploy-fedora.sh scripts/apply-migrations.sh
./scripts/deploy-fedora.sh          # git pull + build + миграции 007–011
# только миграции:
./scripts/apply-migrations.sh
```

Ручной цикл (без скрипта):

```bash
for f in \
  007_pattern_logic_fixes.sql \
  008_marker_day_closures.sql \
  009_db_backend_sync.sql \
  010_recurring_custom_interval.sql \
  011_markers_success_and_streak_fix.sql
do
  echo ">>> $f"
  docker cp "db/migrations/$f" ptt-db:/tmp/"$f"
  docker exec ptt-db psql -U ptt -d ptt -v ON_ERROR_STOP=1 -f "/tmp/$f"
done
```

**Обновления только UI/статистики** (без изменений в `db/migrations/`) — достаточно `git pull` и `docker compose up -d --build`, миграции не нужны.

Проверка:

```powershell
docker compose exec backend pytest tests/test_import_export.py tests/test_patterns.py -q
docker cp db/tests/smoke.sql ptt-db:/tmp/smoke.sql
docker exec ptt-db psql -U ptt -d ptt -v ON_ERROR_STOP=1 -f /tmp/smoke.sql
```

Подробная карта объектов БД ↔ API: [DB_SYNC.md](./DB_SYNC.md).

### Чистая установка на новой машине

1. `git clone git@github.com:murk13hack/bd_curs.git` (или HTTPS-URL репозитория).
2. `cd bd_curs`, `Copy-Item .env.example .env`, сменить `POSTGRES_PASSWORD`.
3. `docker compose up -d --build` — init-скрипты создадут схему **уже с актуальной логикой** (миграции 007–011 влиты в `db/init/`).
4. Миграции из `db/migrations/` **не нужны**, если volume создаётся впервые.
5. Открыть http://localhost, проверить `/api/v1/ping`.

Если нужен гарантированно чистый стенд: `docker compose down -v` перед шагом 3 (удалит все данные).

## 12. Локальная разработка (без пересборки фронта)

### Backend hot-reload

Смонтируйте код в контейнер или запускайте uvicorn локально с `DATABASE_URL` на `localhost:5432` (проброс порта БД).

### Frontend (Vite dev-server)

```powershell
cd frontend
npm install
npm run dev
```

Откройте http://localhost:5173 — Vite проксирует `/api` на `localhost:8000`.
Убедитесь, что в `.env` в `CORS_ORIGINS` есть `http://localhost:5173`.

## 13. Устранение неполадок

| Симптом | Решение |
|---|---|
| `db unhealthy` | `docker compose logs db` — ошибка в SQL init; при необходимости `docker compose down -v` и пересоздать |
| Фронт не видит API | Проверить `docker compose ps`, nginx прокси в `frontend/nginx.conf` |
| Медленная сборка на OneDrive | Перенести проект в локальную папку (`Documents`, не синхронизируемую) |
| Порт 80 занят | В `.env` задать `FRONTEND_PORT=8080`, открыть http://localhost:8080 |

## Архитектура контейнеров

```
┌─────────────┐     /api/*      ┌─────────────┐     SQL      ┌─────────────┐
│  frontend   │ ──────────────► │   backend   │ ───────────► │     db      │
│ nginx :80   │                 │ FastAPI :8000│             │ Postgres :5432│
└─────────────┘                 └─────────────┘              └─────────────┘
     ▲ host :80                      ▲ host :8000
```

Внутренние имена Docker-сети: `frontend`, `backend`, `db`.
