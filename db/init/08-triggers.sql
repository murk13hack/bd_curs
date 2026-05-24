-- =============================================================================
-- 08 — Триггеры.
-- См. ТЗ.md, раздел 4.3.1.9.
-- Триггеры реализованы парами «функция-обработчик + CREATE TRIGGER».
-- =============================================================================

-- ---------- 1. trg_set_updated_at (общий обработчик) ---------------------

CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tasks_updated_at              BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_diary_entries_updated_at      BEFORE UPDATE ON diary_entries
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_behavior_patterns_updated_at  BEFORE UPDATE ON behavior_patterns
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_goals_updated_at              BEFORE UPDATE ON goals
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

COMMENT ON FUNCTION fn_set_updated_at() IS 'Обработчик BEFORE UPDATE для поддержания updated_at.';

-- ---------- 2. trg_task_set_completed_at ---------------------------------

CREATE OR REPLACE FUNCTION fn_task_set_completed_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status
       AND NEW.status = 'done'
       AND NEW.completed_at IS NULL THEN
        NEW.completed_at := now();
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_task_set_completed_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION fn_task_set_completed_at();

COMMENT ON FUNCTION fn_task_set_completed_at()
    IS 'Автоматически проставляет completed_at = now() при переходе статуса в done.';

-- ---------- 3. trg_task_overdue_check ------------------------------------

CREATE OR REPLACE FUNCTION fn_task_overdue_check()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'done'
       AND NEW.completed_at IS NOT NULL
       AND NEW.deadline    IS NOT NULL
       AND NEW.planned_minutes IS NOT NULL
       AND NEW.completed_at > NEW.deadline THEN
        NEW.status := 'overdue';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_task_overdue_check
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION fn_task_overdue_check();

COMMENT ON FUNCTION fn_task_overdue_check()
    IS 'Если задача завершена позже дедлайна и был указан плановый период — статус overdue.';

-- ---------- 4. trg_diary_tsv_update --------------------------------------

CREATE OR REPLACE FUNCTION fn_diary_tsv_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.content_tsv := to_tsvector('russian', coalesce(NEW.content, ''));
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_diary_tsv_update
    BEFORE INSERT OR UPDATE OF content ON diary_entries
    FOR EACH ROW
    EXECUTE FUNCTION fn_diary_tsv_update();

COMMENT ON FUNCTION fn_diary_tsv_update()
    IS 'Поддержка content_tsv = to_tsvector(russian, content).';

-- ---------- 5. trg_audit_changes (общий обработчик) ----------------------

CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_action audit_action_enum;
    v_user   BIGINT;
    v_row_id BIGINT;
    v_diff   JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_action := 'insert';
        v_row_id := (row_to_json(NEW)::jsonb ->> 'id')::BIGINT;
        v_user   := (row_to_json(NEW)::jsonb ->> 'user_id')::BIGINT;
        v_diff   := jsonb_build_object('new', to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        v_action := 'update';
        v_row_id := (row_to_json(NEW)::jsonb ->> 'id')::BIGINT;
        v_user   := (row_to_json(NEW)::jsonb ->> 'user_id')::BIGINT;
        v_diff   := jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW));
    ELSE
        v_action := 'delete';
        v_row_id := (row_to_json(OLD)::jsonb ->> 'id')::BIGINT;
        v_user   := (row_to_json(OLD)::jsonb ->> 'user_id')::BIGINT;
        v_diff   := jsonb_build_object('old', to_jsonb(OLD));
    END IF;

    INSERT INTO audit_log (user_id, table_name, row_id, action, diff)
    VALUES (v_user, TG_TABLE_NAME, v_row_id, v_action, v_diff);

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_audit_tasks
    AFTER INSERT OR UPDATE OR DELETE ON tasks
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_diary
    AFTER INSERT OR UPDATE OR DELETE ON diary_entries
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_patterns
    AFTER INSERT OR UPDATE OR DELETE ON behavior_patterns
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_goals
    AFTER INSERT OR UPDATE OR DELETE ON goals
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_pattern_logs
    AFTER INSERT OR UPDATE OR DELETE ON pattern_logs
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

COMMENT ON FUNCTION fn_audit_log()
    IS 'Универсальный обработчик AFTER INSERT/UPDATE/DELETE для записи изменений в audit_log.';

-- ---------- 6. trg_pattern_streak_recalc ---------------------------------

CREATE OR REPLACE FUNCTION fn_pattern_streak_touch()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Простейший «touch»: триггер срабатывает, чтобы инвалидировать любые кешированные
    -- стрики. Реальный пересчёт делается функциями fn_calculate_streak/* по запросу.
    -- В MVP здесь nop, но триггер оставлен для будущего инкрементального кеширования.
    PERFORM 1;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pattern_streak_recalc
    AFTER INSERT OR UPDATE OF status ON pattern_logs
    FOR EACH ROW EXECUTE FUNCTION fn_pattern_streak_touch();

COMMENT ON FUNCTION fn_pattern_streak_touch()
    IS 'Точка расширения для инкрементального пересчёта серий паттернов.';

-- ---------- 7. trg_recurring_spawn_on_complete ---------------------------

CREATE OR REPLACE FUNCTION fn_recurring_spawn_on_complete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_next DATE;
BEGIN
    IF NEW.status = 'done'
       AND OLD.status IS DISTINCT FROM NEW.status
       AND NEW.recurring_rule_id IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM tasks
             WHERE recurring_rule_id = NEW.recurring_rule_id
               AND status IN ('pending', 'in_progress', 'overdue')
        ) THEN
            RETURN NEW;
        END IF;
        v_next := fn_next_recurring_date(NEW.recurring_rule_id, current_date);
        IF v_next IS NOT NULL THEN
            INSERT INTO tasks (
                user_id, topic_id, recurring_rule_id,
                title, description, priority,
                deadline, planned_minutes
            )
            VALUES (
                NEW.user_id, NEW.topic_id, NEW.recurring_rule_id,
                NEW.title, NEW.description, NEW.priority,
                v_next::timestamptz + INTERVAL '23 hours 59 minutes', NEW.planned_minutes
            );
            UPDATE recurring_rules SET next_run_at = v_next WHERE id = NEW.recurring_rule_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_recurring_spawn_on_complete
    AFTER UPDATE OF status ON tasks
    FOR EACH ROW EXECUTE FUNCTION fn_recurring_spawn_on_complete();

COMMENT ON FUNCTION fn_recurring_spawn_on_complete()
    IS 'При завершении повторяющейся задачи порождает следующий экземпляр.';

-- ---------- 8. trg_tag_user_match (защита от пересечения данных) ---------

CREATE OR REPLACE FUNCTION fn_tag_user_match_for_task()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_task_user BIGINT;
    v_tag_user  BIGINT;
BEGIN
    SELECT user_id INTO v_task_user FROM tasks WHERE id = NEW.task_id;
    SELECT user_id INTO v_tag_user  FROM tags  WHERE id = NEW.tag_id;
    IF v_task_user IS DISTINCT FROM v_tag_user THEN
        RAISE EXCEPTION 'tag and task belong to different users';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_tag_user_match_for_diary()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_entry_user BIGINT;
    v_tag_user   BIGINT;
BEGIN
    SELECT user_id INTO v_entry_user FROM diary_entries WHERE id = NEW.entry_id;
    SELECT user_id INTO v_tag_user   FROM tags          WHERE id = NEW.tag_id;
    IF v_entry_user IS DISTINCT FROM v_tag_user THEN
        RAISE EXCEPTION 'tag and diary entry belong to different users';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tag_user_match_task
    BEFORE INSERT ON task_tags
    FOR EACH ROW EXECUTE FUNCTION fn_tag_user_match_for_task();

CREATE TRIGGER trg_tag_user_match_diary
    BEFORE INSERT ON diary_tags
    FOR EACH ROW EXECUTE FUNCTION fn_tag_user_match_for_diary();

-- ---------- 9. trg_goal_completed ----------------------------------------

CREATE OR REPLACE FUNCTION fn_goal_check_completion()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.is_completed = TRUE AND NEW.completed_at IS NULL THEN
        NEW.completed_at := now();
    ELSIF NEW.is_completed = FALSE THEN
        NEW.completed_at := NULL;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_goal_completed
    BEFORE UPDATE OF is_completed ON goals
    FOR EACH ROW EXECUTE FUNCTION fn_goal_check_completion();

COMMENT ON FUNCTION fn_goal_check_completion()
    IS 'Поддерживает консистентность is_completed/completed_at цели.';

-- ---------- 10. trg_pattern_to_task_on_response --------------------------

DROP TRIGGER IF EXISTS trg_pattern_to_task ON pattern_schedules;
DROP FUNCTION IF EXISTS fn_pattern_to_task();

CREATE OR REPLACE FUNCTION fn_pattern_to_task_on_response()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_pattern behavior_patterns%ROWTYPE;
    v_day     DATE;
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
    IF NOT EXISTS (
        SELECT 1 FROM tasks t
         WHERE t.user_id = v_pattern.user_id
           AND t.title = v_pattern.title
           AND t.deadline IS NOT NULL
           AND t.deadline::date = v_day
    ) THEN
        INSERT INTO tasks (user_id, topic_id, title, description, priority, deadline)
        VALUES (
            v_pattern.user_id,
            COALESCE(v_pattern.topic_id, (SELECT id FROM topics WHERE user_id = v_pattern.user_id LIMIT 1)),
            v_pattern.title,
            'Авто-задача из паттерна #' || v_pattern.id,
            'medium',
            v_day::timestamptz + INTERVAL '23 hours 59 minutes'
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pattern_to_task_on_response
    AFTER INSERT OR UPDATE OF status ON pattern_logs
    FOR EACH ROW EXECUTE FUNCTION fn_pattern_to_task_on_response();

COMMENT ON FUNCTION fn_pattern_to_task_on_response()
    IS 'auto_create_task: создаёт задачу при ответе habit (1 раз в день).';

DO $$
BEGIN
    RAISE NOTICE 'PTT 08-triggers: triggers created';
END $$;
