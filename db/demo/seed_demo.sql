-- =============================================================================
-- Демонстрационный набор данных ПТТ (все возможности приложения).
-- Не трогает базовый seed 09-seed.sql. Регистр ID — app_settings._demo_dataset.
--
-- Запуск: scripts/demo-data.ps1 seed  |  scripts/demo-data.sh seed
-- Удаление: scripts/demo-data.ps1 wipe
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
    d           DATE;
    v_day       DATE;
    v_ts        TIMESTAMPTZ;
    v_mood      SMALLINT;
    v_energy    SMALLINT;
    v_status    task_status_enum;
    v_prio      task_priority_enum;
    v_topics    BIGINT[];
    v_tags      BIGINT[];
    v_tasks_pool BIGINT[] := ARRAY[]::BIGINT[];
BEGIN
    IF EXISTS (SELECT 1 FROM app_settings WHERE user_id = 1 AND key = '_demo_dataset') THEN
        RAISE EXCEPTION 'Демо-данные уже загружены. Сначала выполните wipe: scripts/demo-data.ps1 wipe';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM users WHERE id = v_uid) THEN
        RAISE EXCEPTION 'Пользователь id=1 не найден. Запустите init/09-seed.sql';
    END IF;

    SELECT id INTO v_topic_work   FROM topics WHERE user_id = v_uid AND name = 'Работа';
    SELECT id INTO v_topic_study  FROM topics WHERE user_id = v_uid AND name = 'Учёба';
    SELECT id INTO v_topic_health FROM topics WHERE user_id = v_uid AND name = 'Здоровье';
    SELECT id INTO v_topic_habit  FROM topics WHERE user_id = v_uid AND name = 'Привычки';

    -- ---------- дополнительные темы и теги -----------------------------------

    INSERT INTO topics (user_id, name, color) VALUES (1, 'Демо: Курсовая PostgreSQL', '#2563EB')
    RETURNING id INTO v_topic;
    v_reg := jsonb_set(v_reg, '{topics}', (v_reg->'topics') || to_jsonb(v_topic));

    INSERT INTO topics (user_id, name, color) VALUES (1, 'Демо: Pet-проект', '#7C3AED')
    RETURNING id INTO v_topic;
    v_reg := jsonb_set(v_reg, '{topics}', (v_reg->'topics') || to_jsonb(v_topic));

    INSERT INTO topics (user_id, name, color) VALUES (1, 'Демо: Экзамены', '#DC2626')
    RETURNING id INTO v_topic;
    v_reg := jsonb_set(v_reg, '{topics}', (v_reg->'topics') || to_jsonb(v_topic));

    INSERT INTO topics (user_id, name, color) VALUES (1, 'Демо: Дом и быт', '#059669')
    RETURNING id INTO v_topic;
    v_reg := jsonb_set(v_reg, '{topics}', (v_reg->'topics') || to_jsonb(v_topic));
    v_topics := ARRAY[v_topic_work, v_topic_study, v_topic_health, v_topic_habit];
    SELECT array_agg(id ORDER BY id) INTO v_topics
      FROM topics WHERE user_id = v_uid AND name LIKE 'Демо:%';
    v_topics := v_topics || ARRAY[v_topic_work, v_topic_study, v_topic_health, v_topic_habit];

    INSERT INTO tags (user_id, name) VALUES (v_uid, 'демо-срочное')
    ON CONFLICT (user_id, name) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_tag;
    v_reg := jsonb_set(v_reg, '{tags}', (v_reg->'tags') || to_jsonb(v_tag));

    INSERT INTO tags (user_id, name) VALUES (v_uid, 'демо-идея')
    ON CONFLICT (user_id, name) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_tag;
    v_reg := jsonb_set(v_reg, '{tags}', (v_reg->'tags') || to_jsonb(v_tag));

    INSERT INTO tags (user_id, name) VALUES (v_uid, 'демо-review')
    ON CONFLICT (user_id, name) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_tag;
    v_reg := jsonb_set(v_reg, '{tags}', (v_reg->'tags') || to_jsonb(v_tag));

    INSERT INTO tags (user_id, name) VALUES (v_uid, 'демо-backlog')
    ON CONFLICT (user_id, name) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_tag;
    v_reg := jsonb_set(v_reg, '{tags}', (v_reg->'tags') || to_jsonb(v_tag));

    INSERT INTO tags (user_id, name) VALUES (v_uid, 'демо-meeting')
    ON CONFLICT (user_id, name) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_tag;
    v_reg := jsonb_set(v_reg, '{tags}', (v_reg->'tags') || to_jsonb(v_tag));

    INSERT INTO tags (user_id, name) VALUES (v_uid, 'демо-focus')
    ON CONFLICT (user_id, name) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_tag;
    v_reg := jsonb_set(v_reg, '{tags}', (v_reg->'tags') || to_jsonb(v_tag));

    INSERT INTO tags (user_id, name) VALUES (v_uid, 'демо-deep-work')
    ON CONFLICT (user_id, name) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_tag;
    v_reg := jsonb_set(v_reg, '{tags}', (v_reg->'tags') || to_jsonb(v_tag));

    INSERT INTO tags (user_id, name) VALUES (v_uid, 'демо-блокер')
    ON CONFLICT (user_id, name) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_tag;
    v_reg := jsonb_set(v_reg, '{tags}', (v_reg->'tags') || to_jsonb(v_tag));

    SELECT array_agg(id ORDER BY id) INTO v_tags
      FROM tags WHERE user_id = v_uid AND name LIKE 'демо-%';

    -- ---------- пользовательские праздники ----------------------------------
    INSERT INTO holidays (holiday_date, name, is_official)
    VALUES (make_date(EXTRACT(YEAR FROM current_date)::INT, 6, 1), 'Демо: день защиты курсовой', FALSE)
    RETURNING id INTO v_id;
    v_reg := jsonb_set(v_reg, '{holidays}', (v_reg->'holidays') || to_jsonb(v_id));

    INSERT INTO holidays (holiday_date, name, is_official)
    VALUES (make_date(EXTRACT(YEAR FROM current_date)::INT, 12, 20), 'Демо: сдача сессии', FALSE)
    RETURNING id INTO v_id;
    v_reg := jsonb_set(v_reg, '{holidays}', (v_reg->'holidays') || to_jsonb(v_id));

    -- ---------- задачи (разные статусы, приоритеты, окна) -------------------

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (0 % array_length(v_topics, 1))], '[демо] Подготовить презентацию по OLAP',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'high'::task_priority_enum, 'pending'::task_status_enum,
        now() - 1 * INTERVAL '1 day' + TIME '09:00', now() + 2 * INTERVAL '1 day' + TIME '18:00',
        30, FALSE, now() - 1 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO task_tags (task_id, tag_id)
    SELECT v_task, t FROM unnest(v_tags[1:LEAST(3, array_length(v_tags,1))]) AS t
    ON CONFLICT DO NOTHING;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (1 % array_length(v_topics, 1))], '[демо] Написать главу 3 отчёта',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'urgent'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 3 * INTERVAL '1 day' + TIME '18:00',
        45, FALSE, now() - 2 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (2 % array_length(v_topics, 1))], '[демо] Ревью миграций 007–014',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 4 * INTERVAL '1 day' + TIME '18:00',
        60, FALSE, now() - 3 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (3 % array_length(v_topics, 1))], '[демо] Настроить CI для pytest',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'low'::task_priority_enum, 'pending'::task_status_enum,
        now() - 8 * INTERVAL '1 day' + TIME '09:00', now() - 6 * INTERVAL '1 day' + TIME '18:00',
        75, FALSE, now() - 15 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (4 % array_length(v_topics, 1))], '[демо] Протестировать экспорт JSON',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() - 3 * INTERVAL '1 day' + TIME '18:00',
        90, FALSE, now() - 16 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;

    INSERT INTO task_tags (task_id, tag_id)
    SELECT v_task, t FROM unnest(v_tags[1:LEAST(3, array_length(v_tags,1))]) AS t
    ON CONFLICT DO NOTHING;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (5 % array_length(v_topics, 1))], '[демо] Сверить view статистики',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'high'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 2 * INTERVAL '1 day' + TIME '18:00',
        105, FALSE, now() - 6 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (6 % array_length(v_topics, 1))], '[демо] Обновить DEPLOY.md',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'low'::task_priority_enum, 'pending'::task_status_enum,
        now() - 3 * INTERVAL '1 day' + TIME '09:00', now() + 7 * INTERVAL '1 day' + TIME '18:00',
        120, FALSE, now() - 7 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'cancelled'::task_status_enum
     WHERE id = v_task;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (7 % array_length(v_topics, 1))], '[демо] Созвон с научруком',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'urgent'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 4 * INTERVAL '1 day' + TIME '18:00',
        135, FALSE, now() - 8 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (8 % array_length(v_topics, 1))], '[демо] Подготовить демо-данные',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'high'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 5 * INTERVAL '1 day' + TIME '18:00',
        30, FALSE, now() - 9 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO task_tags (task_id, tag_id)
    SELECT v_task, t FROM unnest(v_tags[1:LEAST(3, array_length(v_tags,1))]) AS t
    ON CONFLICT DO NOTHING;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (9 % array_length(v_topics, 1))], '[демо] Рефакторинг API patterns',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        now() - 2 * INTERVAL '1 day' + TIME '09:00', now() + 6 * INTERVAL '1 day' + TIME '18:00',
        45, FALSE, now() - 10 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (10 % array_length(v_topics, 1))], '[демо] Проверить Pomodoro-таймер',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'low'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() - 5 * INTERVAL '1 day' + TIME '18:00',
        60, FALSE, now() - 22 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (11 % array_length(v_topics, 1))], '[демо] Аудит триггеров overdue',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'high'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 3 * INTERVAL '1 day' + TIME '18:00',
        75, FALSE, now() - 12 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (12 % array_length(v_topics, 1))], '[демо] Документировать сценарии',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        now() - 5 * INTERVAL '1 day' + TIME '09:00', now() - 3 * INTERVAL '1 day' + TIME '18:00',
        90, FALSE, now() - 24 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;

    INSERT INTO task_tags (task_id, tag_id)
    SELECT v_task, t FROM unnest(v_tags[1:LEAST(3, array_length(v_tags,1))]) AS t
    ON CONFLICT DO NOTHING;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (13 % array_length(v_topics, 1))], '[демо] Исправить XSS в diary search',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'urgent'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() - 4 * INTERVAL '1 day' + TIME '18:00',
        105, FALSE, now() - 25 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (14 % array_length(v_topics, 1))], '[демо] Календарь: heatmap',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 6 * INTERVAL '1 day' + TIME '18:00',
        120, FALSE, now() - 15 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (15 % array_length(v_topics, 1))], '[демо] Цели: прогресс-бары',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'low'::task_priority_enum, 'pending'::task_status_enum,
        now() - 4 * INTERVAL '1 day' + TIME '09:00', now() + 2 * INTERVAL '1 day' + TIME '18:00',
        135, FALSE, now() - 16 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (16 % array_length(v_topics, 1))], '[демо] Маркеры: insights',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 3 * INTERVAL '1 day' + TIME '18:00',
        30, FALSE, now() - 17 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO task_tags (task_id, tag_id)
    SELECT v_task, t FROM unnest(v_tags[1:LEAST(3, array_length(v_tags,1))]) AS t
    ON CONFLICT DO NOTHING;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (17 % array_length(v_topics, 1))], '[демо] Повторяющиеся задачи spawn',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'high'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 4 * INTERVAL '1 day' + TIME '18:00',
        45, FALSE, now() - 18 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (18 % array_length(v_topics, 1))], '[демо] Подзадачи: чеклист релиза',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'urgent'::task_priority_enum, 'pending'::task_status_enum,
        now() - 3 * INTERVAL '1 day' + TIME '09:00', now() + 5 * INTERVAL '1 day' + TIME '18:00',
        60, FALSE, now() - 19 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (19 % array_length(v_topics, 1))], '[демо] Архив: старые задачи',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'low'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() - 6 * INTERVAL '1 day' + TIME '18:00',
        75, TRUE, now() - 31 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (20 % array_length(v_topics, 1))], '[демо] Просрочка: отчёт',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'urgent'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 2 * INTERVAL '1 day' + TIME '18:00',
        90, FALSE, now() - 21 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO task_tags (task_id, tag_id)
    SELECT v_task, t FROM unnest(v_tags[1:LEAST(3, array_length(v_tags,1))]) AS t
    ON CONFLICT DO NOTHING;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (21 % array_length(v_topics, 1))], '[демо] Учёба: лабораторная №5',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'high'::task_priority_enum, 'pending'::task_status_enum,
        now() - 2 * INTERVAL '1 day' + TIME '09:00', now() + 3 * INTERVAL '1 day' + TIME '18:00',
        105, FALSE, now() - 22 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (22 % array_length(v_topics, 1))], '[демо] Здоровье: пробежка 5 км',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() - 5 * INTERVAL '1 day' + TIME '18:00',
        120, FALSE, now() - 34 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (23 % array_length(v_topics, 1))], '[демо] Привычка: чтение 30 мин',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'low'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 5 * INTERVAL '1 day' + TIME '18:00',
        135, FALSE, now() - 24 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (24 % array_length(v_topics, 1))], '[демо] Личное: подарок',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        now() - 1 * INTERVAL '1 day' + TIME '09:00', now() + 6 * INTERVAL '1 day' + TIME '18:00',
        30, FALSE, now() - 25 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO task_tags (task_id, tag_id)
    SELECT v_task, t FROM unnest(v_tags[1:LEAST(3, array_length(v_tags,1))]) AS t
    ON CONFLICT DO NOTHING;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (25 % array_length(v_topics, 1))], '[демо] Бэкенд: scheduler test',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'high'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() - 4 * INTERVAL '1 day' + TIME '18:00',
        45, FALSE, now() - 37 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (26 % array_length(v_topics, 1))], '[демо] Фронт: dashboard KPI',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 3 * INTERVAL '1 day' + TIME '18:00',
        60, FALSE, now() - 27 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (27 % array_length(v_topics, 1))], '[демо] DB: smoke.sql расширить',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'low'::task_priority_enum, 'pending'::task_status_enum,
        now() - 4 * INTERVAL '1 day' + TIME '09:00', now() + 4 * INTERVAL '1 day' + TIME '18:00',
        75, FALSE, now() - 28 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (28 % array_length(v_topics, 1))], '[демо] Import merge idempotent',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() - 3 * INTERVAL '1 day' + TIME '18:00',
        90, FALSE, now() - 40 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;

    INSERT INTO task_tags (task_id, tag_id)
    SELECT v_task, t FROM unnest(v_tags[1:LEAST(3, array_length(v_tags,1))]) AS t
    ON CONFLICT DO NOTHING;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (29 % array_length(v_topics, 1))], '[демо] Restore full backup',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'high'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 7 * INTERVAL '1 day' + TIME '18:00',
        105, FALSE, now() - 30 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'cancelled'::task_status_enum
     WHERE id = v_task;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (30 % array_length(v_topics, 1))], '[демо] Overlap time logs',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'low'::task_priority_enum, 'pending'::task_status_enum,
        now() - 7 * INTERVAL '1 day' + TIME '09:00', now() - 5 * INTERVAL '1 day' + TIME '18:00',
        120, FALSE, now() - 42 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (31 % array_length(v_topics, 1))], '[демо] start_at окно выполнения',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 3 * INTERVAL '1 day' + TIME '18:00',
        135, FALSE, now() - 32 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (32 % array_length(v_topics, 1))], '[демо] planned_minutes оценка',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'high'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 4 * INTERVAL '1 day' + TIME '18:00',
        30, FALSE, now() - 33 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO task_tags (task_id, tag_id)
    SELECT v_task, t FROM unnest(v_tags[1:LEAST(3, array_length(v_tags,1))]) AS t
    ON CONFLICT DO NOTHING;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (33 % array_length(v_topics, 1))], '[демо] Теги: комбинации',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'low'::task_priority_enum, 'pending'::task_status_enum,
        now() - 2 * INTERVAL '1 day' + TIME '09:00', now() + 5 * INTERVAL '1 day' + TIME '18:00',
        45, FALSE, now() - 34 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (34 % array_length(v_topics, 1))], '[демо] FTS дневник PostgreSQL',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() - 5 * INTERVAL '1 day' + TIME '18:00',
        60, FALSE, now() - 46 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (35 % array_length(v_topics, 1))], '[демо] Weekly summary chart',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'high'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 2 * INTERVAL '1 day' + TIME '18:00',
        75, FALSE, now() - 36 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (36 % array_length(v_topics, 1))], '[демо] Topic breakdown pie',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        now() - 1 * INTERVAL '1 day' + TIME '09:00', now() + 3 * INTERVAL '1 day' + TIME '18:00',
        90, FALSE, now() - 37 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO task_tags (task_id, tag_id)
    SELECT v_task, t FROM unnest(v_tags[1:LEAST(3, array_length(v_tags,1))]) AS t
    ON CONFLICT DO NOTHING;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (37 % array_length(v_topics, 1))], '[демо] Pattern streaks 30d',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'low'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() - 4 * INTERVAL '1 day' + TIME '18:00',
        105, FALSE, now() - 49 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    UPDATE tasks SET status = 'done'::task_status_enum,
        completed_at = deadline + INTERVAL '2 hours'
     WHERE id = v_task;

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (38 % array_length(v_topics, 1))], '[демо] Scenario top paths',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'medium'::task_priority_enum, 'pending'::task_status_enum,
        NULL, now() + 5 * INTERVAL '1 day' + TIME '18:00',
        120, FALSE, now() - 39 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (
        user_id, topic_id, title, description, priority, status,
        start_at, deadline, planned_minutes, is_archived, created_at
    ) VALUES (
        v_uid, v_topics[1 + (39 % array_length(v_topics, 1))], '[демо] Markers hourly chart',
        'Автоматически сгенерированная демо-задача для тестирования UI и статистики.',
        'high'::task_priority_enum, 'pending'::task_status_enum,
        now() - 4 * INTERVAL '1 day' + TIME '09:00', now() + 6 * INTERVAL '1 day' + TIME '18:00',
        135, FALSE, now() - 40 * INTERVAL '1 day'
    ) RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    INSERT INTO tasks (user_id, topic_id, title, deadline, planned_minutes, created_at)
    VALUES (v_uid, v_topic_work, '[демо] OVERDUE: сдано с опозданием',
            now() - INTERVAL '2 days', 45, now() - INTERVAL '5 days')
    RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);
    UPDATE tasks SET status = 'done', completed_at = now() - INTERVAL '1 day' WHERE id = v_task;

    -- подзадачи
    SELECT id INTO v_parent FROM tasks WHERE title = '[демо] Подзадачи: чеклист релиза' LIMIT 1;
    FOR i IN 1..6 LOOP
        INSERT INTO tasks (user_id, topic_id, parent_task_id, title, priority, status, planned_minutes, created_at)
        VALUES (v_uid, v_topic_work, v_parent,
                format('[демо] Подзадача %%s/6', i),
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

    INSERT INTO recurring_rules (frequency, params, next_run_at, is_active)
    VALUES ('daily'::recurrence_freq_enum, '{}'::jsonb, current_date + INTERVAL '1 day', TRUE)
    RETURNING id INTO v_rule;
    v_reg := jsonb_set(v_reg, '{recurring_rules}', (v_reg->'recurring_rules') || to_jsonb(v_rule));
    UPDATE recurring_rules SET next_run_at = fn_next_recurring_date(v_rule, current_date) WHERE id = v_rule;

    INSERT INTO tasks (user_id, topic_id, recurring_rule_id, title, priority, deadline, planned_minutes)
    VALUES (v_uid, v_topic_work, v_rule, '[демо] Ежедневный stand-up', 'medium'::task_priority_enum,
            current_date::timestamptz + TIME '17:00', 25)
    RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    -- порождённые экземпляры
    INSERT INTO tasks (user_id, topic_id, recurring_rule_id, title, priority, status, deadline, planned_minutes, created_at, completed_at)
    VALUES (v_uid, v_topic_work, v_rule, '[демо] Ежедневный stand-up (экземпляр -7д)', 'medium', 'done',
            (current_date - 7)::timestamptz + TIME '17:00', 25,
            (current_date - 8)::timestamptz, (current_date - 6)::timestamptz + TIME '18:00')
    RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));

    INSERT INTO recurring_rules (frequency, params, next_run_at, is_active)
    VALUES ('weekly'::recurrence_freq_enum, '{"weekly_mask": 31}'::jsonb, current_date + INTERVAL '1 day', TRUE)
    RETURNING id INTO v_rule;
    v_reg := jsonb_set(v_reg, '{recurring_rules}', (v_reg->'recurring_rules') || to_jsonb(v_rule));
    UPDATE recurring_rules SET next_run_at = fn_next_recurring_date(v_rule, current_date) WHERE id = v_rule;

    INSERT INTO tasks (user_id, topic_id, recurring_rule_id, title, priority, deadline, planned_minutes)
    VALUES (v_uid, v_topic_work, v_rule, '[демо] Еженедельный review (Пн–Пт)', 'medium'::task_priority_enum,
            current_date::timestamptz + TIME '17:00', 25)
    RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    -- порождённые экземпляры
    INSERT INTO tasks (user_id, topic_id, recurring_rule_id, title, priority, status, deadline, planned_minutes, created_at, completed_at)
    VALUES (v_uid, v_topic_work, v_rule, '[демо] Еженедельный review (Пн–Пт) (экземпляр -7д)', 'medium', 'done',
            (current_date - 7)::timestamptz + TIME '17:00', 25,
            (current_date - 8)::timestamptz, (current_date - 6)::timestamptz + TIME '18:00')
    RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));

    INSERT INTO recurring_rules (frequency, params, next_run_at, is_active)
    VALUES ('monthly'::recurrence_freq_enum, '{"monthly_day": 1}'::jsonb, current_date + INTERVAL '1 day', TRUE)
    RETURNING id INTO v_rule;
    v_reg := jsonb_set(v_reg, '{recurring_rules}', (v_reg->'recurring_rules') || to_jsonb(v_rule));
    UPDATE recurring_rules SET next_run_at = fn_next_recurring_date(v_rule, current_date) WHERE id = v_rule;

    INSERT INTO tasks (user_id, topic_id, recurring_rule_id, title, priority, deadline, planned_minutes)
    VALUES (v_uid, v_topic_work, v_rule, '[демо] Ежемесячный backup', 'medium'::task_priority_enum,
            current_date::timestamptz + TIME '17:00', 25)
    RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    -- порождённые экземпляры
    INSERT INTO tasks (user_id, topic_id, recurring_rule_id, title, priority, status, deadline, planned_minutes, created_at, completed_at)
    VALUES (v_uid, v_topic_work, v_rule, '[демо] Ежемесячный backup (экземпляр -7д)', 'medium', 'done',
            (current_date - 7)::timestamptz + TIME '17:00', 25,
            (current_date - 8)::timestamptz, (current_date - 6)::timestamptz + TIME '18:00')
    RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));

    INSERT INTO recurring_rules (frequency, params, next_run_at, is_active)
    VALUES ('custom'::recurrence_freq_enum, '{"interval_days": 3}'::jsonb, current_date + INTERVAL '1 day', TRUE)
    RETURNING id INTO v_rule;
    v_reg := jsonb_set(v_reg, '{recurring_rules}', (v_reg->'recurring_rules') || to_jsonb(v_rule));
    UPDATE recurring_rules SET next_run_at = fn_next_recurring_date(v_rule, current_date) WHERE id = v_rule;

    INSERT INTO tasks (user_id, topic_id, recurring_rule_id, title, priority, deadline, planned_minutes)
    VALUES (v_uid, v_topic_work, v_rule, '[демо] Каждые 3 дня: ревью демо-данных', 'medium'::task_priority_enum,
            current_date::timestamptz + TIME '17:00', 25)
    RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));
    v_tasks_pool := array_append(v_tasks_pool, v_task);

    -- порождённые экземпляры
    INSERT INTO tasks (user_id, topic_id, recurring_rule_id, title, priority, status, deadline, planned_minutes, created_at, completed_at)
    VALUES (v_uid, v_topic_work, v_rule, '[демо] Каждые 3 дня: ревью демо-данных (экземпляр -7д)', 'medium', 'done',
            (current_date - 7)::timestamptz + TIME '17:00', 25,
            (current_date - 8)::timestamptz, (current_date - 6)::timestamptz + TIME '18:00')
    RETURNING id INTO v_task;
    v_reg := jsonb_set(v_reg, '{tasks}', (v_reg->'tasks') || to_jsonb(v_task));

    -- ---------- журнал времени (обычный + pomodoro, пересечения) ------------
    FOR i IN 1..150 LOOP
        v_task := v_tasks_pool[1 + ((i - 1) % array_length(v_tasks_pool, 1))];
        v_ts := now() - ((i % 90) || ' days')::interval - ((i % 8) || ' hours')::interval;
        INSERT INTO task_time_logs (task_id, user_id, started_at, ended_at, is_pomodoro, note)
        VALUES (
            v_task, v_uid,
            v_ts,
            v_ts + (CASE WHEN i % 5 = 0 THEN INTERVAL '25 minutes' ELSE INTERVAL '45 minutes' END),
            (i % 5 = 0),
            CASE WHEN i % 7 = 0 THEN 'Pomodoro-сессия' ELSE NULL END
        );
        -- намеренное пересечение интервалов (миграция 012)
        IF i % 23 = 0 THEN
            INSERT INTO task_time_logs (task_id, user_id, started_at, ended_at, is_pomodoro)
            VALUES (v_task, v_uid, v_ts + INTERVAL '10 minutes', v_ts + INTERVAL '50 minutes', FALSE);
        END IF;
    END LOOP;

    -- ---------- дневник (~80 дней из 90) ------------------------------------

    d := current_date - 89;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сегодня работал над курсовой по PostgreSQL: view, процедуры, триггеры. Запись #1: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (0 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 0 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((0 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 88;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Плотный день: задачи, Pomodoro, паттерны habit и markers. Запись #2: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (1 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 1 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((1 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 87;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Энергии мало, но закрыл несколько демо-задач и записал время. Запись #3: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (2 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 2 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((2 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 86;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Изучал OLAP-срезы и материализованные представления v_overdue_tasks. Запись #4: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (3 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 3 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((3 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 85;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сценарий дня прошёл — отметил триггеры и исход в pattern insights. Запись #5: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (4 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 4 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((4 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 84;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Отличное настроение: streak по зарядке вырос, дневник заполнен. Запись #6: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (5 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 5 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((5 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 82;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Планировал неделю: повторяющиеся задачи и цели на месяц. Запись #8: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (7 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 7 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((7 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 81;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Тестировал import/export JSON — merge и restore отработали корректно. Запись #9: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (8 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 8 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((8 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 80;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Календарь показывает плотные дни — много task_time_logs и diary. Запись #10: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (9 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 9 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((9 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 79;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сегодня работал над курсовой по PostgreSQL: view, процедуры, триггеры. Запись #11: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (10 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 10 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((10 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 78;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Плотный день: задачи, Pomodoro, паттерны habit и markers. Запись #12: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (11 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 11 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((11 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 77;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Энергии мало, но закрыл несколько демо-задач и записал время. Запись #13: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (12 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 12 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((12 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 75;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сценарий дня прошёл — отметил триггеры и исход в pattern insights. Запись #15: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (14 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 14 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((14 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 74;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Отличное настроение: streak по зарядке вырос, дневник заполнен. Запись #16: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (15 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 15 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((15 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 73;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Стресс на работе, но удержался — markers показывают один эпизод тяги. Запись #17: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (16 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 16 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((16 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 72;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Планировал неделю: повторяющиеся задачи и цели на месяц. Запись #18: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (17 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 17 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((17 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 71;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Тестировал import/export JSON — merge и restore отработали корректно. Запись #19: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (18 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 18 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((18 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 70;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Календарь показывает плотные дни — много task_time_logs и diary. Запись #20: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (19 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 19 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((19 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 68;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Плотный день: задачи, Pomodoro, паттерны habit и markers. Запись #22: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (21 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 21 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((21 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 67;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Энергии мало, но закрыл несколько демо-задач и записал время. Запись #23: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (22 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 22 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((22 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 66;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Изучал OLAP-срезы и материализованные представления v_overdue_tasks. Запись #24: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (23 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 23 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((23 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 65;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сценарий дня прошёл — отметил триггеры и исход в pattern insights. Запись #25: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (24 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 24 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((24 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 64;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Отличное настроение: streak по зарядке вырос, дневник заполнен. Запись #26: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (25 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 25 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((25 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 63;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Стресс на работе, но удержался — markers показывают один эпизод тяги. Запись #27: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (26 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 26 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((26 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 61;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Тестировал import/export JSON — merge и restore отработали корректно. Запись #29: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (28 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 28 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((28 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 60;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Календарь показывает плотные дни — много task_time_logs и diary. Запись #30: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (29 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 29 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((29 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 59;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сегодня работал над курсовой по PostgreSQL: view, процедуры, триггеры. Запись #31: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (30 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 30 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((30 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 58;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Плотный день: задачи, Pomodoro, паттерны habit и markers. Запись #32: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (31 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 31 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((31 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 57;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Энергии мало, но закрыл несколько демо-задач и записал время. Запись #33: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (32 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 32 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((32 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 56;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Изучал OLAP-срезы и материализованные представления v_overdue_tasks. Запись #34: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (33 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 33 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((33 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 54;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Отличное настроение: streak по зарядке вырос, дневник заполнен. Запись #36: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (35 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 35 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((35 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 53;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Стресс на работе, но удержался — markers показывают один эпизод тяги. Запись #37: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (36 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 36 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((36 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 52;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Планировал неделю: повторяющиеся задачи и цели на месяц. Запись #38: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (37 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 37 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((37 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 51;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Тестировал import/export JSON — merge и restore отработали корректно. Запись #39: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (38 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 38 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((38 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 50;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Календарь показывает плотные дни — много task_time_logs и diary. Запись #40: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (39 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 39 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((39 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 49;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сегодня работал над курсовой по PostgreSQL: view, процедуры, триггеры. Запись #41: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (40 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 40 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((40 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 47;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Энергии мало, но закрыл несколько демо-задач и записал время. Запись #43: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (42 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 42 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((42 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 46;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Изучал OLAP-срезы и материализованные представления v_overdue_tasks. Запись #44: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (43 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 43 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((43 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 45;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сценарий дня прошёл — отметил триггеры и исход в pattern insights. Запись #45: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (44 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 44 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((44 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 44;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Отличное настроение: streak по зарядке вырос, дневник заполнен. Запись #46: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (45 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 45 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((45 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 43;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Стресс на работе, но удержался — markers показывают один эпизод тяги. Запись #47: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (46 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 46 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((46 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 42;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Планировал неделю: повторяющиеся задачи и цели на месяц. Запись #48: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (47 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 47 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((47 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 40;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Календарь показывает плотные дни — много task_time_logs и diary. Запись #50: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (49 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 49 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((49 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 39;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сегодня работал над курсовой по PostgreSQL: view, процедуры, триггеры. Запись #51: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (50 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 50 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((50 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 38;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Плотный день: задачи, Pomodoro, паттерны habit и markers. Запись #52: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (51 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 51 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((51 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 37;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Энергии мало, но закрыл несколько демо-задач и записал время. Запись #53: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (52 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 52 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((52 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 36;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Изучал OLAP-срезы и материализованные представления v_overdue_tasks. Запись #54: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (53 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 53 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((53 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 35;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сценарий дня прошёл — отметил триггеры и исход в pattern insights. Запись #55: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (54 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 54 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((54 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 33;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Стресс на работе, но удержался — markers показывают один эпизод тяги. Запись #57: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (56 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 56 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((56 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 32;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Планировал неделю: повторяющиеся задачи и цели на месяц. Запись #58: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (57 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 57 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((57 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 31;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Тестировал import/export JSON — merge и restore отработали корректно. Запись #59: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (58 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 58 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((58 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 30;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Календарь показывает плотные дни — много task_time_logs и diary. Запись #60: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (59 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 59 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((59 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 29;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сегодня работал над курсовой по PostgreSQL: view, процедуры, триггеры. Запись #61: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (60 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 60 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((60 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 28;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Плотный день: задачи, Pomodoro, паттерны habit и markers. Запись #62: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (61 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 61 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((61 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 26;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Изучал OLAP-срезы и материализованные представления v_overdue_tasks. Запись #64: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (63 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 63 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((63 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 25;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сценарий дня прошёл — отметил триггеры и исход в pattern insights. Запись #65: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (64 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 64 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((64 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 24;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Отличное настроение: streak по зарядке вырос, дневник заполнен. Запись #66: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (65 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 65 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((65 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 23;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Стресс на работе, но удержался — markers показывают один эпизод тяги. Запись #67: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (66 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 66 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((66 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 22;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Планировал неделю: повторяющиеся задачи и цели на месяц. Запись #68: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (67 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 67 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((67 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 21;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Тестировал import/export JSON — merge и restore отработали корректно. Запись #69: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (68 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 68 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((68 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 19;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сегодня работал над курсовой по PostgreSQL: view, процедуры, триггеры. Запись #71: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (70 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 70 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((70 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 18;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Плотный день: задачи, Pomodoro, паттерны habit и markers. Запись #72: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (71 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 71 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((71 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 17;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Энергии мало, но закрыл несколько демо-задач и записал время. Запись #73: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (72 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 72 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((72 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 16;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Изучал OLAP-срезы и материализованные представления v_overdue_tasks. Запись #74: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (73 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 73 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((73 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 15;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сценарий дня прошёл — отметил триггеры и исход в pattern insights. Запись #75: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (74 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 74 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((74 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 14;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Отличное настроение: streak по зарядке вырос, дневник заполнен. Запись #76: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (75 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 75 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((75 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 12;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Планировал неделю: повторяющиеся задачи и цели на месяц. Запись #78: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (77 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 77 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((77 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 11;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Тестировал import/export JSON — merge и restore отработали корректно. Запись #79: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (78 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 78 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((78 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 10;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Календарь показывает плотные дни — много task_time_logs и diary. Запись #80: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (79 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 79 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((79 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 9;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сегодня работал над курсовой по PostgreSQL: view, процедуры, триггеры. Запись #81: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (80 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 80 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((80 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 8;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Плотный день: задачи, Pomodoro, паттерны habit и markers. Запись #82: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (81 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 81 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((81 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 7;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Энергии мало, но закрыл несколько демо-задач и записал время. Запись #83: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (82 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 82 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((82 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 5;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Сценарий дня прошёл — отметил триггеры и исход в pattern insights. Запись #85: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (84 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 84 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((84 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 4;
    v_mood := 1; v_energy := 3;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Отличное настроение: streak по зарядке вырос, дневник заполнен. Запись #86: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (85 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 85 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((85 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 3;
    v_mood := 2; v_energy := 4;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Стресс на работе, но удержался — markers показывают один эпизод тяги. Запись #87: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (86 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 86 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((86 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 2;
    v_mood := 3; v_energy := 5;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Планировал неделю: повторяющиеся задачи и цели на месяц. Запись #88: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (87 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 87 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((87 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 1;
    v_mood := 4; v_energy := 1;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Тестировал import/export JSON — merge и restore отработали корректно. Запись #89: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (88 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 88 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((88 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    d := current_date - 0;
    v_mood := 5; v_energy := 2;
    INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
    VALUES (v_uid, d, 'Календарь показывает плотные дни — много task_time_logs и diary. Запись #90: PostgreSQL FTS, mood/energy, теги.',
            v_mood, v_energy)
    RETURNING id INTO v_entry;
    v_reg := jsonb_set(v_reg, '{diary_entries}', (v_reg->'diary_entries') || to_jsonb(v_entry));
    IF v_tags IS NOT NULL AND array_length(v_tags, 1) >= 2 THEN
        INSERT INTO diary_tags (entry_id, tag_id)
        VALUES (v_entry, v_tags[1 + (89 % array_length(v_tags, 1))])
        ON CONFLICT DO NOTHING;
        IF 89 % 3 = 0 THEN
            INSERT INTO diary_tags (entry_id, tag_id)
            VALUES (v_entry, v_tags[1 + ((89 + 1) % array_length(v_tags, 1))])
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    -- ---------- паттерны HABIT ------------------------------------------------
    INSERT INTO behavior_patterns (user_id, topic_id, title, description, pattern_type, is_boolean, pattern_mode, auto_create_task)
    VALUES (v_uid, v_topic_habit, '[демо] Утренняя зарядка', 'Positive boolean habit', 'positive', TRUE, 'habit', FALSE)
    RETURNING id INTO v_pattern;
    v_reg := jsonb_set(v_reg, '{behavior_patterns}', (v_reg->'behavior_patterns') || to_jsonb(v_pattern));
    INSERT INTO pattern_response_options (pattern_id, label, is_success, sort_order) VALUES
        (v_pattern, 'Сделал', TRUE, 0), (v_pattern, 'Не сделал', FALSE, 1);
    INSERT INTO pattern_schedules (pattern_id, time_of_day, dow_mask) VALUES (v_pattern, '07:30', 127);
    SELECT id INTO v_opt_ok FROM pattern_response_options WHERE pattern_id = v_pattern AND is_success;
    SELECT id INTO v_opt_fail FROM pattern_response_options WHERE pattern_id = v_pattern AND NOT is_success;
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
        v_day := current_date - i;
        CALL sp_log_pattern_response(v_pattern, v_opt_ok, v_day::timestamptz);
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

    -- ---------- паттерны SCENARIO ---------------------------------------------

    INSERT INTO behavior_patterns (user_id, title, pattern_type, pattern_mode, guide_intro)
    VALUES (v_uid, '[демо] Сценарий: день продуктивности', 'positive', 'scenario',
            'Пошаговый сценарий для демонстрации insights и top_paths.')
    RETURNING id INTO v_pattern;
    v_reg := jsonb_set(v_reg, '{behavior_patterns}', (v_reg->'behavior_patterns') || to_jsonb(v_pattern));

    INSERT INTO pattern_steps (pattern_id, sort_order, title, step_kind, step_role, choices) VALUES
        (v_pattern, 0, 'Контекст утра', 'note', 'context', '[]'::jsonb)
    RETURNING id INTO v_step1;
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
        ON CONFLICT (pattern_id, session_date) DO NOTHING
        RETURNING id INTO v_sess;
        IF v_sess IS NOT NULL AND i % 6 <> 0 THEN
            v_reg := jsonb_set(v_reg, '{pattern_day_sessions}', (v_reg->'pattern_day_sessions') || to_jsonb(v_sess));
            INSERT INTO pattern_step_answers (session_id, step_id, note_text) VALUES (v_sess, v_step1, 'Демо-заметка');
            INSERT INTO pattern_step_answers (session_id, step_id, choice_id)
            VALUES (v_sess, v_step2, CASE WHEN i % 3 = 0 THEN 'meet' ELSE 'code' END);
            IF i % 9 <> 0 THEN
                INSERT INTO pattern_step_answers (session_id, step_id, choice_id)
                VALUES (v_sess, v_step3, CASE WHEN i % 5 = 0 THEN 'bad' ELSE 'great' END);
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
        RETURNING id INTO v_sess;
        v_reg := jsonb_set(v_reg, '{pattern_day_sessions}', (v_reg->'pattern_day_sessions') || to_jsonb(v_sess));
        INSERT INTO pattern_step_answers (session_id, step_id, choice_id) VALUES (v_sess, v_step1, 'stress');
        INSERT INTO pattern_step_answers (session_id, step_id, choice_id)
        VALUES (v_sess, v_step2, CASE WHEN i % 3 = 0 THEN 'slip' ELSE 'clean' END);
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
            INSERT INTO pattern_marker_day_closures (pattern_id, closure_date) VALUES (v_pattern, v_day);
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

    -- goal_links
    INSERT INTO goal_links (goal_id, target_type, target_id)
    SELECT v_goal, 'task', id FROM tasks WHERE title LIKE '[демо]%' LIMIT 5;
    INSERT INTO goal_links (goal_id, target_type, target_id)
    SELECT v_goal, 'pattern', id FROM behavior_patterns WHERE title LIKE '[демо]%' LIMIT 3;
    SELECT (v_reg->'goals'->>1)::bigint INTO v_id
      FROM (SELECT 1) x
     WHERE jsonb_array_length(v_reg->'goals') > 1;
    IF v_id IS NOT NULL AND jsonb_array_length(v_reg->'behavior_patterns') > 0 THEN
        INSERT INTO goal_links (goal_id, target_type, target_id)
        VALUES (v_id, 'pattern', (v_reg->'behavior_patterns'->>0)::bigint);
    END IF;

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
