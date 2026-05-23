# ПТТ — Персональный таск-трекер

Курсовая работа по дисциплине «Базы данных».

**Стек:** React 18 + Vite + TypeScript · Python 3.12 + FastAPI · PostgreSQL 16 · Docker Compose (3 контейнера).

## Возможности

- **Задачи** — темы, теги, дедлайны, приоритеты, подзадачи, просрочка (триггер БД), учёт времени / Pomodoro
- **Дневник** — mood/energy, FTS-поиск (`fn_search_diary`)
- **Привычки** — паттерны поведения, расписание, streaks (`fn_calculate_streak`)
- **Календарь** — заливка дней по прогрессу, праздники РФ, heatmap года
- **Статистика** — разрезы по темам/неделям, корреляция настроения (Recharts)
- **Цели** — прогресс через `fn_goal_progress`
- **Import/Export** — JSON (процедуры `sp_export/import_user_data`), CSV задач

Бизнес-логика расчётов — в PostgreSQL: 18 таблиц, view, функции, процедуры, триггеры, индексы, FTS.

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
├── backend/                 # FastAPI, SQLAlchemy, APScheduler, Alembic
│   ├── app/
│   │   ├── api/v1/          # 12 роутеров REST API
│   │   ├── models/          # ORM (18 таблиц)
│   │   └── schemas/         # Pydantic DTO
│   ├── tests/               # pytest (55 интеграционных тестов)
│   └── alembic/
├── frontend/                # React SPA + nginx (prod)
│   ├── src/
│   │   ├── api/             # типизированный HTTP-клиент
│   │   ├── pages/           # 9 экранов
│   │   └── components/
│   └── nginx.conf           # прокси /api/ → backend
├── db/
│   ├── init/                # DDL: extensions → tables → functions → triggers → seed
│   └── tests/smoke.sql      # smoke-тесты SQL-объектов
├── docs/
│   └── DEPLOY.md            # инструкция развёртывания (приложение Ж)
├── docker-compose.yml
├── .env.example
├── README.md
└── ТЗ.md                    # ТЗ по ГОСТ 34.602-89 / 19.201-78
```

## Тесты

```powershell
# Backend API (55 passed)
docker compose exec backend pytest

# SQL smoke (функции, view, триггеры)
docker cp db/tests/smoke.sql ptt-db:/tmp/smoke.sql
docker exec ptt-db psql -U ptt -d ptt -f /tmp/smoke.sql
```

## Разработка

### Frontend (hot-reload)

```powershell
cd frontend
npm install
npm run dev    # http://localhost:5173, proxy /api → :8000
```

### Backend

API-документация генерируется автоматически: `/docs`, `/redoc`.

Конфигурация — `backend/app/config.py`, переменные из `.env`.

## Резервное копирование

```powershell
mkdir backups
docker exec -t ptt-db pg_dump -U ptt -F c -d ptt > "backups/backup_$(Get-Date -Format yyyy-MM-dd).dump"
```

Восстановление:

```powershell
docker exec -i ptt-db pg_restore -U ptt -d ptt --clean --if-exists < backups/backup_DATE.dump
```

## Документация

- [ТЗ.md](./ТЗ.md) — полное техническое задание
- [docs/DEPLOY.md](./docs/DEPLOY.md) — развёртывание, troubleshooting, dev-режим
- OpenAPI — http://localhost:8000/docs
