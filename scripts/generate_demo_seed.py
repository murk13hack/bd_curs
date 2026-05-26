#!/usr/bin/env python3
"""Генератор db/demo/seed_demo.sql — объёмный демо-набор для всех возможностей ПТТ."""

from __future__ import annotations

from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "db" / "demo" / "seed_demo.sql"

HEADER = r"""-- =============================================================================
-- Демонстрационный набор данных ПТТ (все возможности приложения).
-- Не трогает базовый seed 09-seed.sql. Регистр ID — app_settings._demo_dataset.
-- Устойчив к частичным данным пользователя: upsert там, где есть UNIQUE.
--
-- Запуск: scripts/demo-data.sh seed
-- Удаление: scripts/demo-data.sh wipe
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_uid       BIGINT := 1;
    v_reg       JSONB  := jsonb_build_object(
        'version', 1,
        'loaded_at', to_jsonb(now()),
        'topics', '[]'::jsonb,
        'tags', '[]'::jsonb,
        'recurring_rules', '[]'::jsonb,
        'tasks', '[]'::jsonb,
        'behavior_patterns', '[]'::jsonb,
        'diary_entries', '[]'::jsonb,
        'goals', '[]'::jsonb,
        'holidays', '[]'::jsonb,
        'pattern_day_sessions', '[]'::jsonb
    );
    v_id        BIGINT;
    v_opt       BIGINT;
    v_opt_fail  BIGINT;
    v_opt_ok    BIGINT;
    v_parent    BIGINT;
    v_rule      BIGINT;
    v_pattern   BIGINT;
    v_sess      BIGINT;
    v_step1     BIGINT;
    v_step2     BIGINT;
    v_step3     BIGINT;
    v_task      BIGINT;
    v_topic     BIGINT;
    v_topic_work BIGINT;
    v_topic_study BIGINT;
    v_topic_health BIGINT;
    v_topic_habit BIGINT;
    v_tag       BIGINT;
    v_goal      BIGINT;
    v_entry     BIGINT;
    i           INT;
    j           INT;
    d           DATE;
    v_day       DATE;
    v_ts        TIMESTAMPTZ;
    v_mood      SMALLINT;
    v_energy    SMALLINT;
    v_topics    BIGINT[];
    v_tags      BIGINT[];
    v_tasks_pool BIGINT[] := ARRAY[]::BIGINT[];
BEGIN
    IF EXISTS (SELECT 1 FROM app_settings WHERE user_id = 1 AND key = '_demo_dataset') THEN
        RAISE EXCEPTION 'Демо-данные уже загружены. Сначала выполните: scripts/demo-data.sh wipe';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM users WHERE id = v_uid) THEN
        RAISE EXCEPTION 'Пользователь id=1 не найден. Запустите init/09-seed.sql';
    END IF;

    SELECT id INTO v_topic_work   FROM topics WHERE user_id = v_uid AND name = 'Работа';
    SELECT id INTO v_topic_study  FROM topics WHERE user_id = v_uid AND name = 'Учёба';
    SELECT id INTO v_topic_health FROM topics WHERE user_id = v_uid AND name = 'Здоровье';
    SELECT id INTO v_topic_habit  FROM topics WHERE user_id = v_uid AND name = 'Привычки';

    IF v_topic_work IS NULL OR v_topic_study IS NULL THEN
        RAISE EXCEPTION 'Базовые темы не найдены — выполните db/init/09-seed.sql';
    END IF;

    -- ---------- дополнительные темы и теги -----------------------------------
"""

FOOTER = r"""
    -- ---------- сохранение реестра ----------------------------------------
    INSERT INTO app_settings (user_id, key, value)
    VALUES (v_uid, '_demo_dataset', v_reg)
    ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value;

    RAISE NOTICE 'Демо-набор загружен: тем=% тег=% задач=% паттернов=% дневник=% целей=%',
        jsonb_array_length(v_reg->'topics'),
        jsonb_array_length(v_reg->'tags'),
        jsonb_array_length(v_reg->'tasks'),
        jsonb_array_length(v_reg->'behavior_patterns'),
        jsonb_array_length(v_reg->'diary_entries'),
        jsonb_array_length(v_reg->'goals');
END $$;

CALL sp_recalc_calendar_cache();

COMMIT;

\echo '=== DEMO DATA SEEDED ==='
"""

TOPICS = [
    ("Демо: Курсовая PostgreSQL", "#2563EB"),
    ("Демо: Pet-проект", "#7C3AED"),
    ("Демо: Экзамены", "#DC2626"),
    ("Демо: Дом и быт", "#059669"),
]

TAGS = [
    "демо-срочное",
    "демо-идея",
    "демо-review",
    "демо-backlog",
    "демо-meeting",
    "демо-focus",
    "демо-deep-work",
    "демо-блокер",
]

TASK_TITLES = [
    ("[демо] Подготовить презентацию по OLAP", "high", "pending"),
    ("[демо] Написать главу 3 отчёта", "urgent", "in_progress"),
    ("[демо] Ревью миграций 007–014", "medium", "pending"),
    ("[демо] Настроить CI для pytest", "low", "done"),
    ("[демо] Протестировать экспорт JSON", "medium", "done"),
    ("[демо] Сверить view статистики", "high", "pending"),
    ("[демо] Обновить DEPLOY.md", "low", "cancelled"),
    ("[демо] Созвон с научруком", "urgent", "pending"),
    ("[демо] Подготовить демо-данные", "high", "in_progress"),
    ("[демо] Рефакторинг API patterns", "medium", "pending"),
    ("[демо] Проверить Pomodoro-таймер", "low", "done"),
    ("[демо] Аудит триггеров overdue", "high", "pending"),
    ("[демо] Документировать сценарии", "medium", "done"),
    ("[демо] Исправить XSS in diary search", "urgent", "done"),
    ("[демо] Календарь: heatmap", "medium", "pending"),
    ("[демо] Цели: прогресс-бары", "low", "in_progress"),
    ("[демо] Маркеры: insights", "medium", "pending"),
    ("[демо] Повторяющиеся задачи spawn", "high", "pending"),
    ("[демо] Подзадачи: чеклист релиза", "urgent", "pending"),
    ("[демо] Архив: старые задачи", "low", "done"),
    ("[демо] Просрочка: отчёт", "urgent", "pending"),
    ("[демо] Учёба: лабораторная №5", "high", "in_progress"),
    ("[демо] Здоровье: пробежка 5 км", "medium", "done"),
    ("[демо] Привычка: чтение 30 мин", "low", "pending"),
    ("[демо] Личное: подарок", "medium", "pending"),
    ("[демо] Бэкенд: scheduler test", "high", "done"),
    ("[демо] Фронт: dashboard KPI", "medium", "in_progress"),
    ("[демо] DB: smoke.sql расширить", "low", "pending"),
    ("[демо] Import merge idempotent", "medium", "done"),
    ("[демо] Restore full backup", "high", "cancelled"),
    ("[демо] Overlap time logs", "low", "done"),
    ("[демо] start_at окно выполнения", "medium", "pending"),
    ("[демо] planned_minutes оценка", "high", "pending"),
    ("[демо] Теги: комбинации", "low", "in_progress"),
    ("[демо] FTS дневник PostgreSQL", "medium", "done"),
    ("[демо] Weekly summary chart", "high", "pending"),
    ("[демо] Topic breakdown pie", "medium", "pending"),
    ("[демо] Pattern streaks 30d", "low", "done"),
    ("[демо] Scenario top paths", "medium", "in_progress"),
    ("[демо] Markers hourly chart", "high", "pending"),
]

DIARY_SNIPPETS = [
    "Сегодня работал над курсовой по PostgreSQL: view, процедуры, триггеры.",
    "Плотный день: задачи, Pomodoro, паттерны habit и markers.",
    "Энергии мало, но закрыл несколько демо-задач и записал время.",
    "Изучал OLAP-срезы и материализованные представления v_overdue_tasks.",
    "Сценарий дня прошёл — отметил триггеры и исход в pattern insights.",
    "Отличное настроение: streak по зарядке вырос, дневник заполнен.",
    "Стресс на работе, но удержался — markers показывают один эпизод тяги.",
    "Планировал неделю: повторяющиеся задачи и цели на месяц.",
    "Тестировал import/export JSON — merge и restore отработали корректно.",
    "Календарь показывает плотные дни — много task_time_logs и diary.",
]


def q(s: str) -> str:
    return s.replace("'", "''")


def task_dates_sql(idx: int, status: str) -> tuple[str, str, str, str]:
    """Return (created_at, start_at, deadline, completed_update_sql) obeying all task CHECKs."""
    has_window = idx % 3 == 0
    if status == "done":
        created_days = idx + 12
        deadline_days = 3 + (idx % 4)
        start_days = deadline_days + 2 if has_window else None
        created = f"now() - {created_days} * INTERVAL '1 day'"
        deadline = f"now() - {deadline_days} * INTERVAL '1 day' + TIME '18:00'"
        start = (
            f"now() - {start_days} * INTERVAL '1 day' + TIME '09:00'"
            if start_days is not None
            else "NULL"
        )
        completed = """
    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;"""
    elif status == "cancelled":
        created_days = idx + 1
        created = f"now() - {created_days} * INTERVAL '1 day'"
        start = (
            f"now() - {(idx % 4) + 1} * INTERVAL '1 day' + TIME '09:00'"
            if has_window
            else "NULL"
        )
        deadline = "now() + 7 * INTERVAL '1 day' + TIME '18:00'"
        completed = """
    UPDATE tasks SET status = 'cancelled'::task_status_enum
     WHERE id = v_task;"""
    else:
        created_days = idx + 1
        created = f"now() - {created_days} * INTERVAL '1 day'"
        start = (
            f"now() - {(idx % 4) + 1} * INTERVAL '1 day' + TIME '09:00'"
            if has_window
            else "NULL"
        )
        deadline = f"now() + {2 + (idx % 5)} * INTERVAL '1 day' + TIME '18:00'"
        completed = ""
    return created, start, deadline, completed


def main() -> None:
    lines: list[str] = [HEADER]

    for name, color in TOPICS:
        lines.append(
            f"""
    INSERT INTO topics (user_id, name, color) VALUES (v_uid, '{q(name)}', '{color}')
    ON CONFLICT (user_id, name) DO UPDATE SET color = EXCLUDED.color
    RETURNING id INTO v_topic;
    v_reg := jsonb_set(v_reg, '{{topics}}', (v_reg->'topics') || to_jsonb(v_topic));
"""
        )

    lines.append(
        """
    SELECT array_agg(id ORDER BY id) INTO v_topics
      FROM topics WHERE user_id = v_uid AND name LIKE 'Демо:%';
    v_topics := COALESCE(v_topics, ARRAY[]::BIGINT[])
              || ARRAY[v_topic_work, v_topic_study, v_topic_health, v_topic_habit];
"""
    )

    for tag in TAGS:
        lines.append(
            f"""
    INSERT INTO tags (user_id, name) VALUES (v_uid, '{q(tag)}')
    ON CONFLICT (user_id, name) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_tag;
    v_reg := jsonb_set(v_reg, '{{tags}}', (v_reg->'tags') || to_jsonb(v_tag));
"""
        )

    lines.append(
        """
    SELECT array_agg(id ORDER BY id) INTO v_tags
      FROM tags WHERE user_id = v_uid AND name LIKE 'демо-%';

    -- ---------- пользовательские праздники ----------------------------------
    INSERT INTO holidays (holiday_date, name, is_official)
    VALUES (make_date(EXTRACT(YEAR FROM current_date)::INT, 6, 15), 'Демо: день защиты курсовой', FALSE)
    ON CONFLICT (holiday_date) DO UPDATE
        SET name = EXCLUDED.name, is_official = EXCLUDED.is_official
    RETURNING id INTO v_id;
    IF v_id IS NULL THEN
        SELECT id INTO v_id FROM holidays
         WHERE holiday_date = make_date(EXTRACT(YEAR FROM current_date)::INT, 6, 15);
    END IF;
    v_reg := jsonb_set(v_reg, '{holidays}', (v_reg->'holidays') || to_jsonb(v_id));

    INSERT INTO holidays (holiday_date, name, is_official)
    VALUES (make_date(EXTRACT(YEAR FROM current_date)::INT, 12, 20), 'Демо: сдача сессии', FALSE)
    ON CONFLICT (holiday_date) DO UPDATE
        SET name = EXCLUDED.name, is_official = EXCLUDED.is_official
    RETURNING id INTO v_id;
    IF v_id IS NULL THEN
        SELECT id INTO v_id FROM holidays
         WHERE holiday_date = make_date(EXTRACT(YEAR FROM current_date)::INT, 12, 20);
    END IF;
    v_reg := jsonb_set(v_reg, '{holidays}', (v_reg->'holidays') || to_jsonb(v_id));

    -- ---------- задачи (разные статусы, приоритеты, окна) -------------------
"""
    )

    for idx, (title, prio, status) in enumerate(TASK_TITLES):
        topic_var = f"v_topics[1 + ({idx} % array_length(v_topics, 1))]"
        planned = 30 + (idx % 8) * 15
        archived = "TRUE" if "Архив" in title else "FALSE"
        created, start_at, deadline, completed_sql = task_dates_sql(idx, status)

        lines.append(
            f"""
    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, {topic_var}, '{q(title)}',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        '{prio}'::task_priority_enum, 'pending'::task_status_enum,
        {start_at}, {deadline},
        {planned}, {archived}, {created}
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{{tasks}}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);
"""
        )
        if completed_sql:
            lines.append(completed_sql)
        if idx % 4 == 0:
            lines.append(
                """
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 1 THEN
        INSERT INTO task_tags (task_id, tag_id)
        SELECT v_task, t FROM unnest(v_tags[1:LEAST(3, array_length(v_tags,1))]) AS t
        ON CONFLICT DO NOTHING;
    END IF;
"""
            )

    lines.append(
        """
    -- overdue (триггер trg_task_overdue_check)
    INSERT INTO tasks (user_id, topic_id, title, deadline, planned_minutes, created_at)
    VALUES (v_uid, v_topic_work, '[демо] OVERDUE: сдано с опозданием',
            now() - INTERVAL '2 days' + TIME '18:00', 45, now() - INTERVAL '5 days')
    RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);
    UPDATE tasks SET status = 'done', completed_at = now() - INTERVAL '1 day' WHERE id = v_task;

    -- подзадачи
    SELECT id INTO v_parent FROM tasks WHERE title = '[демо] Подзадачи: чеклист релиза' LIMIT 1;
    FOR i IN 1..6 LOOP
        INSERT INTO tasks (user_id, topic_id, parent_task_id, title, priority, status, planned_minutes, created_at)
        VALUES (v_uid, v_topic_work, v_parent,
                format('[демо] Подзадача %s/6', i),
                CASE WHEN i <= 2 THEN 'urgent'::task_priority_enum ELSE 'medium'::task_priority_enum END,
                'pending'::task_status_enum,
                20, now() - (i + 5) * INTERVAL '1 day')
        RETURNING id INTO v_task;
        v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
        IF i <= 3 THEN
            UPDATE tasks SET status = 'done'::task_status_enum,
                completed_at = created_at + INTERVAL '2 hours'
             WHERE id = v_task;
        END IF;
    END LOOP;

    -- ---------- повторяющиеся задачи ----------------------------------------
"""
    )

    recurring_specs = [
        ("daily", "{}", "[демо] Ежедневный stand-up"),
        ("weekly", '{"weekly_mask": 31}', "[демо] Еженедельный review (Пн–Пт)"),
        ("monthly", '{"monthly_day": 1}', "[демо] Ежемесячный backup"),
        ("custom", '{"interval_days": 3}', "[демо] Каждые 3 дня: ревью демо-данных"),
    ]
    for freq, params, title in recurring_specs:
        lines.append(
            f"""
    INSERT INTO recurring_rules (frequency, params, next_run_at, is_active)
    VALUES ('{freq}'::recurrence_freq_enum, '{params}'::jsonb, current_date + INTERVAL '1 day', TRUE)
    RETURNING id INTO v_rule;
    v_reg := jsonb_set(v_reg, '{{recurring_rules}}', (v_reg->'recurring_rules') || to_jsonb(v_rule));
    UPDATE recurring_rules SET next_run_at = fn_next_recurring_date(v_rule, current_date) WHERE id = v_rule;

    INSERT INTO tasks (user_id, topic_id, recurring_rule_id, title, priority, deadline, planned_minutes, created_at)
    VALUES (v_uid, v_topic_work, v_rule, '{q(title)}', 'medium'::task_priority_enum,
            (current_date + 2)::timestamptz + TIME '17:00', 25, now() - INTERVAL '1 day')
    RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{{tasks}}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (user_id, topic_id, recurring_rule_id, title, priority, status, deadline, planned_minutes, created_at, completed_at)
    VALUES (v_uid, v_topic_work, v_rule, '{q(title)} (экземпляр -7д)', 'medium', 'done',
            (current_date - 7)::timestamptz + TIME '17:00', 25,
            (current_date - 8)::timestamptz, (current_date - 6)::timestamptz + TIME '18:00')
    RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{{tasks}}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);
"""
        )

    lines.append(
        """
    -- ---------- журнал времени (обычный + pomodoro, пересечения) ------------
    IF array_length(v_tasks_pool, 1) IS NOT NULL THEN
        FOR i IN 1..150 LOOP
            v_task := v_tasks_pool[1 + ((i - 1) % array_length(v_tasks_pool, 1))];
            v_ts := now() - ((i % 90) || ' days')::interval - ((i % 8) || ' hours')::interval;
            INSERT INTO task_time_logs (task_id, user_id, started_at, ended_at, is_pomodoro, note)
            VALUES (
                v_task, v_uid, v_ts,
                v_ts + (CASE WHEN i % 5 = 0 THEN INTERVAL '25 minutes' ELSE INTERVAL '45 minutes' END),
                (i % 5 = 0),
                CASE WHEN i % 7 = 0 THEN 'Pomodoro-сессия' ELSE NULL END
            );
            IF i % 23 = 0 THEN
                INSERT INTO task_time_logs (task_id, user_id, started_at, ended_at, is_pomodoro)
                VALUES (v_task, v_uid, v_ts + INTERVAL '10 minutes', v_ts + INTERVAL '50 minutes', FALSE);
            END IF;
        END LOOP;
    END IF;

    -- ---------- дневник (~77 записей за 90 дней) ----------------------------
"""
    )

    diary_day = 0
    for day_offset in range(90):
        if day_offset % 7 == 6:
            continue
        diary_day += 1
        snippet = DIARY_SNIPPETS[day_offset % len(DIARY_SNIPPETS)]
        mood = (day_offset % 5) + 1
        energy = ((day_offset + 2) % 5) + 1
        lines.append(
            f"""
    d := current_date - {89 - day_offset};
    v_mood := {mood}; v_energy := {energy};
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, '[демо-дневник] {q(snippet)} Запись #{diary_day}: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    ON CONFLICT (user_id, entry_date) DO UPDATE
        SET content = EXCLUDED.content, mood = EXCLUDED.mood, energy = EXCLUDED.energy, updated_at = now()
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{{diary_entries}}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 1 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + ({day_offset} % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF {day_offset} % 3 = 0 AND array_length(v_tags, 1) >= 2 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + (({day_offset} + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;
"""
        )

    lines.append(
        """
    -- ---------- паттерны HABIT ------------------------------------------------
    INSERT INTO behavior_patterns (user_id, topic_id, title, description, pattern_type, is_boolean, pattern_mode, auto_create_task)
    VALUES (v_uid, v_topic_habit, '[демо] Утренняя зарядка', 'Positive boolean habit', 'positive', TRUE, 'habit', FALSE)
    RETURNING id INTO v_pattern;
    v_reg := jsonb_set(v_reg, '{behavior_patterns}', (v_reg->'behavior_patterns') || to_jsonb(v_pattern));
    INSERT INTO pattern_response_options (pattern_id, label, is_success, sort_order) VALUES
        (v_pattern, 'Сделал', TRUE, 0), (v_pattern, 'Не сделал', FALSE, 1);
    INSERT INTO pattern_schedules (pattern_id, time_of_day, dow_mask) VALUES (v_pattern, '07:30', 127);
    SELECT id INTO v_opt_ok FROM pattern_response_options WHERE pattern_id = v_pattern AND is_success LIMIT 1;
    FOR i IN 0..59 LOOP
        v_day := current_date - i;
        IF i % 7 = 0 THEN
            INSERT INTO pattern_logs (pattern_id, scheduled_at, status)
            VALUES (v_pattern, v_day::timestamptz, 'missed');
        ELSIF i % 11 = 0 THEN
            INSERT INTO pattern_logs (pattern_id, scheduled_at, status)
            VALUES (v_pattern, v_day::timestamptz, 'pending');
        ELSE
            CALL sp_log_pattern_response(v_pattern, v_opt_ok, v_day::timestamptz);
        END IF;
    END LOOP;

    INSERT INTO behavior_patterns (user_id, topic_id, title, pattern_type, is_boolean, pattern_mode)
    VALUES (v_uid, v_topic_health, '[демо] Курение (negative boolean)', 'negative', TRUE, 'habit')
    RETURNING id INTO v_pattern;
    v_reg := jsonb_set(v_reg, '{behavior_patterns}', (v_reg->'behavior_patterns') || to_jsonb(v_pattern));
    INSERT INTO pattern_response_options (pattern_id, label, is_success, sort_order) VALUES
        (v_pattern, '0 раз', TRUE, 0), (v_pattern, '1 раз', FALSE, 1), (v_pattern, '2+ раз', FALSE, 2);
    INSERT INTO pattern_schedules (pattern_id, time_of_day, dow_mask) VALUES (v_pattern, '20:00', 127);
    SELECT id INTO v_opt_ok FROM pattern_response_options WHERE pattern_id = v_pattern AND label = '0 раз';
    FOR i IN 0..44 LOOP
        CALL sp_log_pattern_response(v_pattern, v_opt_ok, (current_date - i)::timestamptz);
    END LOOP;

    INSERT INTO behavior_patterns (user_id, title, pattern_type, is_boolean, pattern_mode, auto_create_task)
    VALUES (v_uid, '[демо] Медитация (multi-option)', 'positive', FALSE, 'habit', TRUE)
    RETURNING id INTO v_pattern;
    v_reg := jsonb_set(v_reg, '{behavior_patterns}', (v_reg->'behavior_patterns') || to_jsonb(v_pattern));
    INSERT INTO pattern_response_options (pattern_id, label, is_success, sort_order) VALUES
        (v_pattern, '10+ мин', TRUE, 0), (v_pattern, '5 мин', TRUE, 1),
        (v_pattern, 'Пропустил', FALSE, 2), (v_pattern, 'Забыл', FALSE, 3);
    INSERT INTO pattern_schedules (pattern_id, time_of_day, dow_mask) VALUES (v_pattern, '21:00', 62);
    SELECT id INTO v_opt_ok FROM pattern_response_options WHERE pattern_id = v_pattern AND label = '10+ мин';
    FOR i IN 0..34 LOOP
        IF i % 5 <> 0 THEN
            CALL sp_log_pattern_response(v_pattern, v_opt_ok, (current_date - i)::timestamptz);
        END IF;
    END LOOP;
    FOR v_task IN
        SELECT id FROM tasks
         WHERE user_id = v_uid
           AND title = '[демо] Медитация (multi-option)'
           AND description LIKE 'Авто-задача из паттерна%'
    LOOP
        v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
        v_tasks_pool := array_append(v_tasks_pool, v_task);
    END LOOP;

    -- ---------- паттерны SCENARIO ---------------------------------------------
    INSERT INTO behavior_patterns (user_id, title, pattern_type, pattern_mode, guide_intro)
    VALUES (v_uid, '[демо] Сценарий: день продуктивности', 'positive', 'scenario',
            'Пошаговый сценарий для демонстрации insights и top_paths.')
    RETURNING id INTO v_pattern;
    v_reg := jsonb_set(v_reg, '{behavior_patterns}', (v_reg->'behavior_patterns') || to_jsonb(v_pattern));

    INSERT INTO pattern_steps (pattern_id, sort_order, title, step_kind, step_role, choices) VALUES
        (v_pattern, 0, 'Контекст утра', 'note', 'context', '[]'::jsonb) RETURNING id INTO v_step1;
    INSERT INTO pattern_steps (pattern_id, sort_order, title, step_kind, step_role, choices) VALUES
        (v_pattern, 1, 'Главный фокус', 'single_choice', 'choice',
         '[{"id":"code","label":"Код","is_success":true},{"id":"docs","label":"Документы","is_success":true},{"id":"meet","label":"Созвоны","is_success":false}]'::jsonb)
    RETURNING id INTO v_step2;
    INSERT INTO pattern_steps (pattern_id, sort_order, title, step_kind, step_role, marks_success, choices) VALUES
        (v_pattern, 2, 'Итог дня', 'single_choice', 'outcome', TRUE,
         '[{"id":"great","label":"Отлично","is_success":true},{"id":"ok","label":"Нормально","is_success":true},{"id":"bad","label":"Плохо","is_success":false}]'::jsonb)
    RETURNING id INTO v_step3;

    FOR i IN 0..24 LOOP
        v_day := current_date - i;
        INSERT INTO pattern_day_sessions (pattern_id, session_date, status, outcome_success, started_at, completed_at)
        VALUES (
            v_pattern, v_day,
            CASE WHEN i % 6 = 0 THEN 'in_progress'::pattern_session_status_enum
                 WHEN i % 9 = 0 THEN 'abandoned'::pattern_session_status_enum
                 ELSE 'completed'::pattern_session_status_enum END,
            (i % 4 <> 0),
            v_day::timestamptz + TIME '09:00',
            CASE WHEN i % 6 = 0 THEN NULL ELSE v_day::timestamptz + TIME '21:00' END
        )
        ON CONFLICT (pattern_id, session_date) DO UPDATE SET status = EXCLUDED.status
        RETURNING id INTO v_sess;
        IF v_sess IS NULL THEN
            SELECT id INTO v_sess FROM pattern_day_sessions
             WHERE pattern_id = v_pattern AND session_date = v_day;
        END IF;
        IF v_sess IS NOT NULL AND i % 6 <> 0 THEN
            v_reg := jsonb_set(v_reg, '{pattern_day_sessions}', (v_reg->'pattern_day_sessions') || to_jsonb(v_sess));
            INSERT INTO pattern_step_answers (session_id, step_id, note_text)
            VALUES (v_sess, v_step1, 'Демо-заметка')
            ON CONFLICT (session_id, step_id) DO UPDATE SET note_text = EXCLUDED.note_text;
            INSERT INTO pattern_step_answers (session_id, step_id, choice_id)
            VALUES (v_sess, v_step2, CASE WHEN i % 3 = 0 THEN 'meet' ELSE 'code' END)
            ON CONFLICT (session_id, step_id) DO UPDATE SET choice_id = EXCLUDED.choice_id;
            IF i % 9 <> 0 THEN
                INSERT INTO pattern_step_answers (session_id, step_id, choice_id)
                VALUES (v_sess, v_step3, CASE WHEN i % 5 = 0 THEN 'bad' ELSE 'great' END)
                ON CONFLICT (session_id, step_id) DO UPDATE SET choice_id = EXCLUDED.choice_id;
            END IF;
        END IF;
    END LOOP;

    INSERT INTO behavior_patterns (user_id, title, pattern_type, pattern_mode)
    VALUES (v_uid, '[демо] Сценарий: триггеры стресса', 'negative', 'scenario')
    RETURNING id INTO v_pattern;
    v_reg := jsonb_set(v_reg, '{behavior_patterns}', (v_reg->'behavior_patterns') || to_jsonb(v_pattern));
    INSERT INTO pattern_steps (pattern_id, sort_order, title, step_kind, step_role, choices) VALUES
        (v_pattern, 0, 'Триггер', 'single_choice', 'trigger',
         '[{"id":"stress","label":"Стресс","is_success":false},{"id":"calm","label":"Спокойствие","is_success":true}]'::jsonb)
    RETURNING id INTO v_step1;
    INSERT INTO pattern_steps (pattern_id, sort_order, title, step_kind, step_role, marks_success, choices) VALUES
        (v_pattern, 1, 'Исход', 'single_choice', 'outcome', TRUE,
         '[{"id":"clean","label":"Удержался","is_success":true},{"id":"slip","label":"Срыв","is_success":false}]'::jsonb)
    RETURNING id INTO v_step2;
    FOR i IN 0..14 LOOP
        v_day := current_date - i;
        INSERT INTO pattern_day_sessions (pattern_id, session_date, status, outcome_success, completed_at)
        VALUES (v_pattern, v_day, 'completed', (i % 3 <> 0), v_day::timestamptz + TIME '22:00')
        ON CONFLICT (pattern_id, session_date) DO UPDATE SET status = EXCLUDED.status
        RETURNING id INTO v_sess;
        IF v_sess IS NULL THEN
            SELECT id INTO v_sess FROM pattern_day_sessions
             WHERE pattern_id = v_pattern AND session_date = v_day;
        END IF;
        v_reg := jsonb_set(v_reg, '{pattern_day_sessions}', (v_reg->'pattern_day_sessions') || to_jsonb(v_sess));
        INSERT INTO pattern_step_answers (session_id, step_id, choice_id) VALUES (v_sess, v_step1, 'stress')
        ON CONFLICT (session_id, step_id) DO UPDATE SET choice_id = EXCLUDED.choice_id;
        INSERT INTO pattern_step_answers (session_id, step_id, choice_id)
        VALUES (v_sess, v_step2, CASE WHEN i % 3 = 0 THEN 'slip' ELSE 'clean' END)
        ON CONFLICT (session_id, step_id) DO UPDATE SET choice_id = EXCLUDED.choice_id;
    END LOOP;

    -- ---------- паттерны MARKERS ----------------------------------------------
    INSERT INTO behavior_patterns (user_id, title, pattern_type, pattern_mode)
    VALUES (v_uid, '[демо] Markers: тяга к соцсетям', 'negative', 'markers')
    RETURNING id INTO v_pattern;
    v_reg := jsonb_set(v_reg, '{behavior_patterns}', (v_reg->'behavior_patterns') || to_jsonb(v_pattern));
    INSERT INTO pattern_response_options (pattern_id, label, is_success, sort_order) VALUES
        (v_pattern, 'Тяга', FALSE, 0), (v_pattern, 'Срыв', FALSE, 1),
        (v_pattern, 'Справился', TRUE, 2), (v_pattern, 'Стресс', FALSE, 3);
    SELECT id INTO v_opt_fail FROM pattern_response_options WHERE pattern_id = v_pattern AND label = 'Тяга';
    SELECT id INTO v_opt_ok FROM pattern_response_options WHERE pattern_id = v_pattern AND label = 'Справился';
    FOR i IN 0..89 LOOP
        v_day := current_date - i;
        IF i % 11 = 0 THEN
            INSERT INTO pattern_marker_day_closures (pattern_id, closure_date)
            VALUES (v_pattern, v_day) ON CONFLICT (pattern_id, closure_date) DO NOTHING;
        ELSIF i % 7 = 0 THEN
            FOR j IN 1..(1 + (i % 4)) LOOP
                INSERT INTO pattern_markers (pattern_id, marker_option_id, occurred_at, note)
                VALUES (v_pattern, v_opt_fail, v_day::timestamptz + (j * INTERVAL '2 hours'), 'Демо-эпизод');
            END LOOP;
        ELSIF i % 5 = 0 THEN
            INSERT INTO pattern_markers (pattern_id, marker_option_id, occurred_at)
            VALUES (v_pattern, v_opt_ok, v_day::timestamptz + TIME '15:00');
        END IF;
    END LOOP;

    INSERT INTO behavior_patterns (user_id, topic_id, title, pattern_type, pattern_mode)
    VALUES (v_uid, v_topic_habit, '[демо] Markers: полезные привычки', 'positive', 'markers')
    RETURNING id INTO v_pattern;
    v_reg := jsonb_set(v_reg, '{behavior_patterns}', (v_reg->'behavior_patterns') || to_jsonb(v_pattern));
    INSERT INTO pattern_response_options (pattern_id, label, is_success, sort_order) VALUES
        (v_pattern, 'Сделал', TRUE, 0), (v_pattern, 'Пропустил', FALSE, 1);
    SELECT id INTO v_opt_ok FROM pattern_response_options WHERE pattern_id = v_pattern AND is_success;
    FOR i IN 0..30 LOOP
        INSERT INTO pattern_markers (pattern_id, marker_option_id, occurred_at)
        VALUES (v_pattern, v_opt_ok, (current_date - (i % 20))::timestamptz + (i % 12 || ' hours')::interval);
    END LOOP;

    -- ---------- цели и связи --------------------------------------------------
    INSERT INTO goals (user_id, title, description, deadline, target_value, is_completed, completed_at)
    VALUES (v_uid, '[демо] Защитить курсовую', 'Цель с привязкой к задачам и паттернам',
            current_date + 60, 10, FALSE, NULL)
    RETURNING id INTO v_goal;
    v_reg := jsonb_set(v_reg, '{goals}', (v_reg->'goals') || to_jsonb(v_goal));

    INSERT INTO goals (user_id, title, deadline, target_value)
    VALUES (v_uid, '[демо] 30 дней зарядки', current_date + 30, 30)
    RETURNING id INTO v_id;
    v_reg := jsonb_set(v_reg, '{goals}', (v_reg->'goals') || to_jsonb(v_id));

    INSERT INTO goals (user_id, title, target_value, is_completed, completed_at)
    VALUES (v_uid, '[демо] Закрыть backlog (выполнено)', 5, TRUE, now() - INTERVAL '3 days')
    RETURNING id INTO v_id;
    v_reg := jsonb_set(v_reg, '{goals}', (v_reg->'goals') || to_jsonb(v_id));

    INSERT INTO goals (user_id, title, description, deadline, target_value)
    VALUES (v_uid, '[демо] OLAP-отчёт для преподавателя', 'Статистика и insights', current_date + 14, 8)
    RETURNING id INTO v_id;
    v_reg := jsonb_set(v_reg, '{goals}', (v_reg->'goals') || to_jsonb(v_id));

    INSERT INTO goals (user_id, title, target_value)
    VALUES (v_uid, '[демо] Pomodoro 100 сессий', 100)
    RETURNING id INTO v_id;
    v_reg := jsonb_set(v_reg, '{goals}', (v_reg->'goals') || to_jsonb(v_id));

    INSERT INTO goal_links (goal_id, target_type, target_id)
    SELECT v_goal, 'task', id FROM tasks WHERE title LIKE '[демо]%' LIMIT 5
    ON CONFLICT DO NOTHING;
    INSERT INTO goal_links (goal_id, target_type, target_id)
    SELECT v_goal, 'pattern', id FROM behavior_patterns WHERE title LIKE '[демо]%' LIMIT 3
    ON CONFLICT DO NOTHING;
    SELECT (v_reg->'goals'->>1)::bigint INTO v_id
     WHERE jsonb_array_length(v_reg->'goals') > 1;
    IF v_id IS NOT NULL AND jsonb_array_length(v_reg->'behavior_patterns') > 0 THEN
        INSERT INTO goal_links (goal_id, target_type, target_id)
        VALUES (v_id, 'pattern', (v_reg->'behavior_patterns'->>0)::bigint)
        ON CONFLICT DO NOTHING;
    END IF;
"""
    )

    lines.append(FOOTER)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("".join(lines), encoding="utf-8")
    print(f"Written {OUT} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
