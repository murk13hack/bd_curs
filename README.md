# ПТТ — Персональный таск-трекер

Курсовая работа по дисциплине «Базы данных».

**Стек:** React 18 + Vite + TypeScript · Python 3.12 + FastAPI · PostgreSQL 16 · Docker Compose (3 контейнера).

## Возможности

- **Задачи** — темы, теги, дедлайны, приоритеты, подзадачи, просрочка (триггер БД), учёт времени / Pomodoro (до 10 параллельных таймеров)
- **Дневник** — mood/energy, FTS-поиск (`fn_search_diary`), календарь и лента записей
- **Паттерны** — три режима: **привычки (habit)**, **сценарий (scenario)**, **точки (markers)**; расписание, streaks, уведомления
- **Календарь** — заливка дней по прогрессу, праздники РФ, heatmap года
- **Статистика** — KPI, разрезы по темам/неделям, «Связи показателей», OLAP-срезы (Recharts)
- **Цели** — прогресс через `fn_goal_progress`, привязка к задачам и паттернам
- **Import/Export** — JSON: экспорт полный; импорт merge (темы/теги) или restore (все сущности); CSV задач

Бизнес-логика расчётов — в PostgreSQL: **23 таблицы** (18 базовых по ТЗ + 5 для режимов паттернов), views, функции, процедуры, триггеры, индексы, FTS.

## Быстрый старт

```powershell
Copy-Item .env.example .env
# отредактируйте POSTGRES_PASSWORD в .env
docker compose up -d --build
```

| Сервис | URL |
|---|---|
| UI | http://localhost |
| API | http://localhost:8000/api/v1 |
| Swagger | http://localhost:8000/docs |
| Health | http://localhost:8000/health |

```powershell
docker compose ps          # все healthy
docker compose logs -f     # логи
docker compose stop        # остановить
docker compose down -v     # удалить всё (данные БД тоже!)
```

Подробная инструкция: **[docs/DEPLOY.md](./docs/DEPLOY.md)**.

## Структура репозитория

```
bd_curs/
├── backend/                 # FastAPI, SQLAlchemy, APScheduler
│   ├── app/
│   │   ├── api/v1/          # REST API
│   │   ├── models/          # ORM (22 модели / 23 таблицы)
│   │   └── schemas/         # Pydantic DTO
│   └── tests/               # pytest (~100 интеграционных тестов)
├── frontend/                # React SPA + nginx (prod)
├── db/
│   ├── init/                # DDL: extensions → tables → functions → triggers → seed
│   └── migrations/          # 007–014 для существующих volume
├── docs/                    # KURSOVAYA_BD.md, KURSOVAYA_APPENDIX.md, diagrams/, DEPLOY, …
├── docker-compose.yml
└── ТЗ.md
```

## Бенчмарк для курсовой (EXPLAIN)

```powershell
docker cp scripts/benchmark_load_tasks.sql ptt-db:/tmp/
docker exec ptt-db psql -U ptt -d ptt -v count=10000 -f /tmp/benchmark_load_tasks.sql
docker cp scripts/benchmark_explain.sql ptt-db:/tmp/
docker exec ptt-db psql -U ptt -d ptt -f /tmp/benchmark_explain.sql > explain_out.txt
```

См. главу 10 в [docs/KURSOVAYA_BD.md](./docs/KURSOVAYA_BD.md).

## Тесты

```powershell
# Backend API
docker compose exec backend pytest

# SQL smoke (функции, view, триггеры)
docker cp db/tests/smoke.sql ptt-db:/tmp/smoke.sql
docker exec ptt-db psql -U ptt -d ptt -v ON_ERROR_STOP=1 -f /tmp/smoke.sql
```

## Разработка

### Frontend (hot-reload)

```powershell
cd frontend
npm install
npm run dev    # http://localhost:5173, proxy /api → :8000
npm run build  # production build
```

### Backend

API-документация: `/docs`, `/redoc`. Конфигурация — `backend/app/config.py`, переменные из `.env`.

## Документация

- [ТЗ.md](./ТЗ.md) — техническое задание
- [docs/DEPLOY.md](./docs/DEPLOY.md) — развёртывание, миграции 007–014, troubleshooting
- [docs/DB_SYNC.md](./docs/DB_SYNC.md) — соответствие таблиц, функций, view и API
- [docs/STATS.md](./docs/STATS.md) — логика статистики
- [docs/OLAP.md](./docs/OLAP.md) — OLAP-срезы
- [docs/PATTERNS_SCENARIO.md](./docs/PATTERNS_SCENARIO.md) — режим «Сценарий»
- [docs/DEMO_DATA.md](./docs/DEMO_DATA.md) — объёмный демо-набор для скриншотов и проверки всех функций
- [docs/PRE_FREEZE_FIXES.md](./docs/PRE_FREEZE_FIXES.md) — чеклист аудита перед защитой
- OpenAPI — http://localhost:8000/docs

## Резервное копирование

```powershell
mkdir backups
docker exec -t ptt-db pg_dump -U ptt -F c -d ptt > "backups/backup_$(Get-Date -Format yyyy-MM-dd).dump"
```

Восстановление:

```powershell
docker exec -i ptt-db pg_restore -U ptt -d ptt --clean --if-exists < backups/backup_DATE.dump
```
