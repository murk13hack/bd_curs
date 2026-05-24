-- Remaining fixes: recurring dedup, auto_create on response, export recurring_rules.
-- docker cp db/migrations/006_remaining_fixes.sql ptt-db:/tmp/ && docker exec ptt-db psql -U ptt -d ptt -f /tmp/006_remaining_fixes.sql

CREATE OR REPLACE PROCEDURE sp_export_user_data(
    p_user_id BIGINT,
    INOUT p_json JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    p_json := jsonb_build_object(
        'schema_version', 2,
        'exported_at',    now(),
        'user',           (SELECT to_jsonb(u) FROM users u WHERE u.id = p_user_id),
        'topics',         COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM topics  x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'tags',           COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM tags    x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'recurring_rules', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM recurring_rules x
                                     WHERE x.id IN (
                                         SELECT DISTINCT t.recurring_rule_id FROM tasks t
                                          WHERE t.user_id = p_user_id AND t.recurring_rule_id IS NOT NULL
                                     )), '[]'::jsonb),
        'tasks',          COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM tasks   x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'task_tags',      COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM task_tags x
                                      JOIN tasks t ON t.id = x.task_id
                                     WHERE t.user_id = p_user_id), '[]'::jsonb),
        'task_time_logs', COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM task_time_logs x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'diary_entries',  COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM diary_entries  x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'diary_tags',     COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM diary_tags x
                                      JOIN diary_entries de ON de.id = x.entry_id
                                     WHERE de.user_id = p_user_id), '[]'::jsonb),
        'patterns',       COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM behavior_patterns x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'pattern_options',COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_response_options x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_schedules', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_schedules x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_steps',  COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_steps x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_logs',   COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_logs x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_markers', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_markers x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_day_sessions', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_day_sessions x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_step_answers', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_step_answers x
                                      JOIN pattern_day_sessions s ON s.id = x.session_id
                                      JOIN behavior_patterns bp ON bp.id = s.pattern_id
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

CREATE OR REPLACE PROCEDURE sp_spawn_recurring_tasks(p_date DATE DEFAULT current_date)
LANGUAGE plpgsql
AS $$
DECLARE
    rec  RECORD;
    v_next DATE;
BEGIN
    FOR rec IN
        SELECT rr.id AS rule_id,
               (
                   SELECT t.id FROM tasks t
                    WHERE t.recurring_rule_id = rr.id
                    ORDER BY t.created_at DESC LIMIT 1
               ) AS source_task_id
          FROM recurring_rules rr
         WHERE rr.is_active = TRUE
           AND (rr.next_run_at IS NULL OR rr.next_run_at::date <= p_date)
    LOOP
        IF rec.source_task_id IS NOT NULL
           AND NOT EXISTS (
               SELECT 1 FROM tasks t
                WHERE t.recurring_rule_id = rec.rule_id
                  AND t.status IN ('pending', 'in_progress', 'overdue')
           ) THEN
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
