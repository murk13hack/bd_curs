# Alembic

Alembic управляет схемой ORM-таблиц поверх БД, создаваемой init-скриптами в
`db/init/`. Объекты БД (VIEW, FUNCTION, PROCEDURE, TRIGGER, MATERIALIZED VIEW)
живут в init-скриптах и в Alembic не описываются.

## Команды

Контейнер `backend` запускается из директории `/app`, где лежит `alembic.ini`.

```bash
docker compose exec backend alembic current
docker compose exec backend alembic history
docker compose exec backend alembic revision -m "add some column" --autogenerate
docker compose exec backend alembic upgrade head
docker compose exec backend alembic downgrade -1
```

## Базовое состояние

Так как первая инициализация выполнена через `docker-entrypoint-initdb.d/`,
ORM-таблицы уже соответствуют моделям. При первом autogenerate Alembic должен
показать пустой diff. Если позже потребуется ALTER — добавьте миграцию обычным
порядком.
