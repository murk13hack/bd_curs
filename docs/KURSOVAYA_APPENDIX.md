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

Получение листингов: `./scripts/benchmark_run_for_kursovaya.sh 10000` → `docs/benchmark_explain_out.txt`.

#### Рисунок 11 — План `fn_get_calendar_stats` (Q1, набор S2)

```text
Merge Left Join  (cost=510.53..9104.87 ... actual time=5.352..5.564 rows=31)
  Buffers: shared hit=463 read=5
  -> GroupAggregate  Group Key: ((t.deadline)::date)  (actual time=2.190..2.253)
        -> Seq Scan on tasks t
              Filter: user_id = 1 AND deadline::date в диапазоне мая 2025
              Rows Removed by Filter: 9632
Execution Time: 5.816 ms
```

*Подпись: Рисунок 11 — План выполнения `fn_get_calendar_stats` при ~10 000 задач.*

#### Рисунок 12 — Планы FTS дневника (до/после GIN)

```text
-- Q2a (без idx_diary_fts_gin), 578 записей
Seq Scan on diary_entries
  Filter: content_tsv @@ 'продуктивн' AND user_id = 1
Execution Time: 1.102 ms

-- Q2b (индекс восстановлен) — тот же Seq Scan, 1.064 ms
```

*Подпись: Рисунок 12 — `fn_search_diary` на S2; при малом объёме планировщик не переключается на GIN (см. гл. 10).*

#### Рисунок 13 — План выборки задач по индексу (Q3)

```text
Limit  (actual time=1.052..1.070 rows=200)
  -> Bitmap Heap Scan on tasks
        Recheck Cond: (topic_id = $0) AND (status = 'pending')
        -> Bitmap Index Scan on idx_tasks_topic_status
              Index Cond: (topic_id = $0) AND (status = 'pending')
Execution Time: 1.120 ms
```

*Подпись: Рисунок 13 — План фильтра задач по `idx_tasks_topic_status`.*

Результаты сводятся в **таблицу 9** основного текста (глава 10).

---

**Конец приложений**
