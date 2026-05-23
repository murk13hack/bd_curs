# ПТТ — Персональный таск-трекер

Курсовая работа по дисциплине «Базы данных».

Стек: **React 18 + Vite** (фронтенд) · **Python 3.12 + FastAPI** (бэкенд) · **PostgreSQL 16** (БД).
Развёртывание — три контейнера через **Docker Compose**.

## Быстрый старт

```bash
cp .env.example .env
docker compose up -d --build
```

После старта будут доступны:

- фронтенд: <http://localhost>
- API:      <http://localhost:8000/api/v1>
- Swagger:  <http://localhost:8000/docs>
- ReDoc:    <http://localhost:8000/redoc>
- health:   <http://localhost:8000/health>

Проверить состояние контейнеров:

```bash
docker compose ps
docker compose logs -f
```

Остановка / удаление:

```bash
docker compose stop          # остановить, данные сохранить
docker compose down          # удалить контейнеры, volume сохранить
docker compose down -v       # снести и данные (необратимо)
```

## Структура репозитория

```
bd_curs/
├── backend/                 # FastAPI + SQLAlchemy + asyncpg
│   ├── app/
│   │   └── main.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .dockerignore
├── frontend/                # React 18 + Vite + nginx (prod)
│   ├── src/
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── index.html
│   ├── package.json
│   ├── tsconfig.json
│   ├── vite.config.ts
│   ├── nginx.conf
│   ├── Dockerfile
│   └── .dockerignore
├── db/
│   └── init/                # SQL-скрипты, выполняются Postgres-образом
│       └── 00-readme.sql    #   при первом запуске в алфавитном порядке
├── docker-compose.yml
├── .env.example
├── .gitignore
├── README.md
└── ТЗ.md                    # техническое задание (ГОСТ 34.602-89 / 19.201-78)
```

## Резервное копирование БД

```bash
mkdir -p backups
docker exec -t ptt-db pg_dump -U ptt -F c -d ptt > "backups/backup_$(date +%F).dump"
```

Восстановление:

```bash
docker exec -i ptt-db pg_restore -U ptt -d ptt --clean --if-exists < backups/backup_<DATE>.dump
```

## Документация

- Полное техническое задание — [ТЗ.md](./ТЗ.md)
- API-документация генерируется FastAPI автоматически (`/docs`, `/redoc`)
