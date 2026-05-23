-- =============================================================================
-- 07 — Хранимые процедуры (CREATE PROCEDURE).
-- См. ТЗ.md, раздел 4.3.1.8.
-- =============================================================================

-- ---------- 1. sp_complete_task ------------------------------------------

CREATE OR REPLACE PROCEDURE sp_complete_task(p_task_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE tasks
       SET status       = 'done',
           completed_at = COALESCE(completed_at, now()),
           updated_at   = now()
     WHERE id = p_task_id
       AND status NOT IN ('done', 'cancelled');
    -- Триггер trg_task_overdue_check выставит 'overdue' при нарушении дедлайна.
    IF NOT FOUND THEN
        RAISE NOTICE 'sp_complete_task: задача % уже выполнена/отменена или не найдена', p_task_id;
    END IF;
END;
$$;
COMMENT ON PROCEDURE sp_complete_task(BIGINT)
    IS 'Атомарно отметить задачу выполненной с проставлением completed_at = now().';

-- ---------- 2. sp_log_pattern_response -----------------------------------

CREATE OR REPLACE PROCEDURE sp_log_pattern_response(
    p_pattern_id         BIGINT,
    p_response_option_id BIGINT,
    p_scheduled_at       TIMESTAMPTZ DEFAULT now()
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing_id BIGINT;
BEGIN
    -- Если для этого pattern_id+scheduled_at уже есть pending — обновим, иначе вставим.
    SELECT id INTO v_existing_id
      FROM pattern_logs
     WHERE pattern_id = p_pattern_id
       AND date_trunc('minute', scheduled_at) = date_trunc('minute', p_scheduled_at)
     LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
        UPDATE pattern_logs
           SET response_option_id = p_response_option_id,
               answered_at        = now(),
               status             = 'answered'
         WHERE id = v_existing_id;
    ELSE
        INSERT INTO pattern_logs (pattern_id, response_option_id, scheduled_at, answered_at, status)
        VALUES (p_pattern_id, p_response_option_id, p_scheduled_at, now(), 'answered');
    END IF;
END;
$$;
COMMENT ON PROCEDURE sp_log_pattern_response(BIGINT, BIGINT, TIMESTAMPTZ)
    IS 'Зафиксировать ответ пользователя на паттерн. Обновляет pending или вставляет новую запись.';

-- ---------- 3. sp_spawn_recurring_tasks ----------------------------------

CREATE OR REPLACE PROCEDURE sp_spawn_recurring_tasks(p_date DATE DEFAULT current_date)
LANGUAGE plpgsql
AS $$
DECLARE
    rec  RECORD;
    v_next DATE;
BEGIN
    -- Для каждого активного правила, чей next_run_at <= p_date, создаём экземпляр-задачу
    -- путём копирования последней связанной задачи (её title/description/topic_id).
    FOR rec IN
        SELECT rr.id        AS rule_id,
               rr.next_run_at,
               (
                   SELECT t.id FROM tasks t
                    WHERE t.recurring_rule_id = rr.id
                    ORDER BY t.created_at DESC LIMIT 1
               ) AS source_task_id
          FROM recurring_rules rr
         WHERE rr.is_active = TRUE
           AND (rr.next_run_at IS NULL OR rr.next_run_at::date <= p_date)
    LOOP
        IF rec.source_task_id IS NOT NULL THEN
            INSERT INTO tasks (
                user_id, topic_id, recurring_rule_id,
                title, description, priority,
                deadline, planned_minutes
            )
            SELECT
                user_id, topic_id, rec.rule_id,
                title, description, priority,
                p_date::timestamptz + INTERVAL '23 hours 59 minutes', planned_minutes
              FROM tasks WHERE id = rec.source_task_id;
        END IF;
        v_next := fn_next_recurring_date(rec.rule_id, p_date);
        UPDATE recurring_rules SET next_run_at = v_next WHERE id = rec.rule_id;
    END LOOP;
END;
$$;
COMMENT ON PROCEDURE sp_spawn_recurring_tasks(DATE)
    IS 'Породить экземпляры повторяющихся задач на дату.';

-- ---------- 4. sp_close_overdue_pattern_logs -----------------------------

CREATE OR REPLACE PROCEDURE sp_close_overdue_pattern_logs(
    p_now TIMESTAMPTZ DEFAULT now()
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE pattern_logs
       SET status = 'missed'
     WHERE status = 'pending'
       AND scheduled_at < p_now - INTERVAL '12 hours';
END;
$$;
COMMENT ON PROCEDURE sp_close_overdue_pattern_logs(TIMESTAMPTZ)
    IS 'Перевести просроченные ожидания ответа в статус missed.';

-- ---------- 5. sp_archive_old_audit --------------------------------------

CREATE OR REPLACE PROCEDURE sp_archive_old_audit(p_keep_days INT DEFAULT 365)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM audit_log
     WHERE changed_at < now() - (p_keep_days || ' days')::interval;
END;
$$;
COMMENT ON PROCEDURE sp_archive_old_audit(INT)
    IS 'Удалить записи журнала аудита старше N дней.';

-- ---------- 6. sp_recalc_calendar_cache ----------------------------------

CREATE OR REPLACE PROCEDURE sp_recalc_calendar_cache()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW v_overdue_tasks;
END;
$$;
COMMENT ON PROCEDURE sp_recalc_calendar_cache()
    IS 'Пересчитать материализованное представление просрочек.';

-- ---------- 7. sp_export_user_data ---------------------------------------

CREATE OR REPLACE PROCEDURE sp_export_user_data(
    p_user_id BIGINT,
    INOUT p_json JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    p_json := jsonb_build_object(
        'schema_version', 1,
        'exported_at',    now(),
        'user',           (SELECT to_jsonb(u) FROM users u WHERE u.id = p_user_id),
        'topics',         COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM topics  x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'tags',           COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM tags    x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'tasks',          COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM tasks   x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'task_tags',      COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM task_tags x
                                      JOIN tasks t ON t.id = x.task_id
                                     WHERE t.user_id = p_user_id), '[]'::jsonb),
        'task_time_logs', COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM task_time_logs x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'diary_entries',  COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM diary_entries  x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'patterns',       COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM behavior_patterns x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'pattern_options',COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_response_options x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_schedules', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_schedules x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_logs',   COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_logs x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'goals',          COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM goals x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'goal_links',     COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM goal_links x
                                      JOIN goals g ON g.id = x.goal_id
                                     WHERE g.user_id = p_user_id), '[]'::jsonb),
        'app_settings',   COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM app_settings x WHERE x.user_id = p_user_id), '[]'::jsonb)
    );
END;
$$;
COMMENT ON PROCEDURE sp_export_user_data(BIGINT, JSONB)
    IS 'Экспорт всех данных пользователя в один JSONB-документ.';

-- ---------- 8. sp_import_user_data ---------------------------------------

CREATE OR REPLACE PROCEDURE sp_import_user_data(
    p_user_id BIGINT,
    p_json    JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_topic JSONB;
    v_tag   JSONB;
BEGIN
    -- Идемпотентная вставка по натуральным ключам (имя темы/тега в рамках пользователя).
    FOR v_topic IN SELECT * FROM jsonb_array_elements(COALESCE(p_json->'topics', '[]'::jsonb)) LOOP
        INSERT INTO topics (user_id, name, color)
        VALUES (p_user_id, v_topic->>'name', COALESCE((v_topic->>'color')::hex_color, '#3B82F6'))
        ON CONFLICT (user_id, name) DO UPDATE
           SET color = EXCLUDED.color;
    END LOOP;

    FOR v_tag IN SELECT * FROM jsonb_array_elements(COALESCE(p_json->'tags', '[]'::jsonb)) LOOP
        INSERT INTO tags (user_id, name)
        VALUES (p_user_id, v_tag->>'name')
        ON CONFLICT (user_id, name) DO NOTHING;
    END LOOP;

    -- Полная реализация остальных таблиц — задача расширения. На этой стадии
    -- импортируются справочники, остальные сущности через REST API.
END;
$$;
COMMENT ON PROCEDURE sp_import_user_data(BIGINT, JSONB)
    IS 'Идемпотентный импорт справочников из JSON-документа.';

DO $$
BEGIN
    RAISE NOTICE 'PTT 07-procedures: 8 procedures created';
END $$;
