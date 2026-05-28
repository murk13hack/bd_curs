# ПРИЛОЖЕНИЯ

## к пояснительной записке «ПТТ» (КР-БД-2026-ПТТ)

> **Нумерация:** рисунки **1–10** размещаются в **основном тексте** ([KURSOVAYA_BD.md](./KURSOVAYA_BD.md), заглушки `[Вставить PNG]`). Рисунки **11–14** — в этом файле (планы EXPLAIN, развёртывание). Полный перечень: [KURSOVAYA_FIGURES.md](./KURSOVAYA_FIGURES.md).

---

## Приложение А. Исходники диаграмм (без дублирования текста)

Каталог [`docs/diagrams/`](./diagrams/), справочник нотаций: [NOTATION.md](./diagrams/NOTATION.md).

| Рисунок | Файл-исходник |
|---------|---------------|
| 1 | `01-er-full.mmd` |
| 2 | `02-architecture.mmd` |
| 3 | `03-bpmn-complete-task.bpmn` |
| 4 | `04-bpmn-pattern-habit.bpmn` |
| 5 | `05-state-task.puml` |
| 6 | `06-state-pattern-log.puml` |
| 7 | `07-activity-daily.puml` |
| 8 | `08-sequence-calendar.mmd` |

*Рисунки 9–10 вставляются в главу 9 основного текста (OLAP).*

---

## Приложение Б. Схема развёртывания

См. [DEPLOY.md](./DEPLOY.md), [ТЗ.md](../ТЗ.md).

#### Рисунок 14 — Схема развёртывания Docker Compose

```
┌──────────────────────────────────────────────────────────────┐
│  [ ВСТАВИТЬ: схема контейнеров db / backend / frontend ]     │
│  Подпись: Рисунок 14 — Развёртывание системы ПТТ (Compose)   │
└──────────────────────────────────────────────────────────────┘
```

---

## Приложение В. Перечень REST API

OpenAPI 3.1: `http://localhost:8000/docs` после `docker compose up -d`.

---

## Приложение Г. Скриншоты интерфейса

| Экран | Связь с БД (для подписи) |
|-------|--------------------------|
| Задачи | `tasks`, `sp_complete_task` |
| Дневник | `diary_entries`, `fn_search_diary` |
| Паттерны | `pattern_*` по режиму |
| Календарь | `fn_get_calendar_stats` |
| Статистика / OLAP | `v_olap_daily_facts`, `POST /stats/olap` |
| Цели | `goals`, `fn_goal_progress` |

*(Скриншоты вставляются по требованию кафедры; рисунок 10 — OLAP — в глава 9 текста.)*

---

## Приложение Д. Программный код базы данных

| Артефакт | Путь |
|----------|------|
| **Полный init DDL** | [`appendix/PTT_database_init.sql`](./appendix/PTT_database_init.sql) |
| Пофайлово | `db/init/01`…`09` |
| Миграции | `db/migrations/001`…`015` |

### Д.1. Расширения

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS unaccent;
```

### Д.2. Типы (фрагмент)

```sql
CREATE TYPE task_status_enum AS ENUM (
    'pending', 'in_progress', 'done', 'overdue', 'cancelled'
);
CREATE TYPE pattern_mode_enum AS ENUM ('habit', 'scenario', 'markers');
CREATE DOMAIN mood_score AS SMALLINT
    CHECK (VALUE IS NULL OR (VALUE BETWEEN 1 AND 5));
```

### Д.3. Таблица `tasks` (фрагмент)

```sql
CREATE TABLE tasks (
    id                BIGSERIAL PRIMARY KEY,
    user_id           BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    topic_id          BIGINT NOT NULL REFERENCES topics(id) ON DELETE RESTRICT,
    title             TEXT NOT NULL,
    status            task_status_enum NOT NULL DEFAULT 'pending',
    deadline          TIMESTAMPTZ,
    planned_minutes   positive_int,
    completed_at      TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### Д.4. `sp_complete_task`

```sql
CREATE OR REPLACE PROCEDURE sp_complete_task(p_task_id BIGINT)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tasks
       SET status = 'done',
           completed_at = COALESCE(completed_at, now()),
           updated_at = now()
     WHERE id = p_task_id
       AND status NOT IN ('done', 'cancelled');
END;
$$;
```

### Д.5. Триггер просрочки

```sql
CREATE TRIGGER trg_task_overdue_check
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION fn_task_overdue_check();
```

### Д.6. Полный листинг

См. файл **`PTT_database_init.sql`** (~114 КБ) — для печати шрифтом Courier New 10 pt или отдельный электронный носитель.

---

## Приложение Е. Планы выполнения запросов (EXPLAIN)

Получение листингов:

```powershell
docker cp scripts/benchmark_load_tasks.sql ptt-db:/tmp/
docker exec ptt-db psql -U ptt -d ptt -v count=10000 -f /tmp/benchmark_load_tasks.sql
docker cp scripts/benchmark_explain.sql ptt-db:/tmp/
docker exec ptt-db psql -U ptt -d ptt -f /tmp/benchmark_explain.sql > explain_out.txt
```

Сравнение GIN (Q2): `DROP INDEX idx_diary_fts_gin` → прогон → `CREATE INDEX` из `04-indexes.sql` → повтор.

#### Рисунок 11 — План `fn_get_calendar_stats`

```
┌──────────────────────────────────────────────────────────────┐
│  [ ВСТАВИТЬ: фрагмент explain_out.txt, запрос Q1 ]           │
│  Подпись: Рисунок 11 — План выполнения календаря месяца      │
└──────────────────────────────────────────────────────────────┘
```

#### Рисунок 12 — Планы FTS дневника (до/после GIN)

```
┌──────────────────────────────────────────────────────────────┐
│  [ ВСТАВИТЬ: Q2a Seq Scan и Q2b Bitmap Index Scan ]          │
│  Подпись: Рисунок 12 — Влияние индекса idx_diary_fts_gin     │
└──────────────────────────────────────────────────────────────┘
```

#### Рисунок 13 — План выборки задач по индексу

```
┌──────────────────────────────────────────────────────────────┐
│  [ ВСТАВИТЬ: Q3, Index Scan idx_tasks_topic_status ]          │
│  Подпись: Рисунок 13 — План фильтра задач по теме и статусу  │
└──────────────────────────────────────────────────────────────┘
```

Результаты сводятся в **таблицу 9** основного текста (глава 10).

---

**Конец приложений**
