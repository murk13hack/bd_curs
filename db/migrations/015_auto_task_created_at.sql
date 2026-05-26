-- 015: auto_create_task — created_at не позже deadline (логи habit за прошлые дни).

CREATE OR REPLACE FUNCTION fn_pattern_to_task_on_response()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_pattern behavior_patterns%ROWTYPE;
    v_day     DATE;
    v_start   TIMESTAMPTZ;
    v_end     TIMESTAMPTZ;
BEGIN
    IF NEW.status <> 'answered' THEN
        RETURN NEW;
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.status = 'answered' THEN
        RETURN NEW;
    END IF;
    SELECT * INTO v_pattern FROM behavior_patterns WHERE id = NEW.pattern_id;
    IF NOT COALESCE(v_pattern.auto_create_task, FALSE) THEN
        RETURN NEW;
    END IF;
    v_day := date_trunc('day', NEW.scheduled_at)::date;
    v_start := v_day::timestamptz + TIME '00:05:00';
    v_end   := v_day::timestamptz + TIME '23:59:00';
    IF NOT EXISTS (
        SELECT 1 FROM tasks t
         WHERE t.user_id = v_pattern.user_id
           AND t.title = v_pattern.title
           AND t.deadline IS NOT NULL
           AND t.deadline::date = v_day
    ) THEN
        INSERT INTO tasks (user_id, topic_id, title, description, priority, deadline, created_at)
        VALUES (
            v_pattern.user_id,
            COALESCE(v_pattern.topic_id, (SELECT id FROM topics WHERE user_id = v_pattern.user_id LIMIT 1)),
            v_pattern.title,
            'Авто-задача из паттерна #' || v_pattern.id,
            'medium',
            v_end,
            v_start
        );
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_pattern_to_task_on_response()
    IS 'auto_create_task: создаёт задачу при ответе habit (1 раз в день). created_at = начало дня ответа.';
