-- Audit fixes: goal progress (markers/scenario), export completeness, index sync.
-- docker cp db/migrations/005_audit_fixes.sql ptt-db:/tmp/ && docker exec ptt-db psql -U ptt -d ptt -f /tmp/005_audit_fixes.sql

CREATE INDEX IF NOT EXISTS idx_pattern_steps_pattern ON pattern_steps (pattern_id);

-- ---------- fn_goal_progress: all pattern modes ----------------------------

CREATE OR REPLACE FUNCTION fn_goal_progress(p_goal_id BIGINT)
RETURNS percentage
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_target INT;
    v_done   INT := 0;
    v_pattern_days INT := 0;
    v_since  DATE;
BEGIN
    SELECT target_value, created_at::date INTO v_target, v_since FROM goals WHERE id = p_goal_id;
    IF v_target IS NULL OR v_target = 0 THEN
        RETURN 0::percentage;
    END IF;

    SELECT COUNT(*) INTO v_done
      FROM goal_links gl
      JOIN tasks t ON gl.target_type = 'task' AND t.id = gl.target_id
     WHERE gl.goal_id = p_goal_id
       AND t.status = 'done';

    SELECT COUNT(DISTINCT day)::INT INTO v_pattern_days
      FROM (
        SELECT date_trunc('day', pl.scheduled_at)::date AS day
          FROM goal_links gl
          JOIN behavior_patterns bp ON bp.id = gl.target_id AND bp.pattern_mode = 'habit'
          JOIN pattern_logs pl ON pl.pattern_id = gl.target_id
          JOIN pattern_response_options ro ON ro.id = pl.response_option_id
         WHERE gl.goal_id = p_goal_id
           AND gl.target_type = 'pattern'
           AND pl.status = 'answered'
           AND ro.is_success = TRUE
           AND pl.scheduled_at::date >= v_since
        UNION
        SELECT d.day::date AS day
          FROM goal_links gl
          JOIN behavior_patterns bp ON bp.id = gl.target_id AND bp.pattern_mode = 'markers'
          CROSS JOIN generate_series(v_since, current_date, '1 day') AS d(day)
         WHERE gl.goal_id = p_goal_id
           AND gl.target_type = 'pattern'
           AND fn_pattern_is_scheduled(gl.target_id, d.day::date)
           AND fn_pattern_day_success(gl.target_id, d.day::date)
        UNION
        SELECT s.session_date AS day
          FROM goal_links gl
          JOIN behavior_patterns bp ON bp.id = gl.target_id AND bp.pattern_mode = 'scenario'
          JOIN pattern_day_sessions s ON s.pattern_id = gl.target_id
         WHERE gl.goal_id = p_goal_id
           AND gl.target_type = 'pattern'
           AND s.status = 'completed'
           AND s.outcome_success = TRUE
           AND s.session_date >= v_since
      ) contrib;

    v_done := v_done + COALESCE(v_pattern_days, 0);
    RETURN LEAST(100, ROUND(100.0 * v_done / v_target, 2))::percentage;
END;
$$;

COMMENT ON FUNCTION fn_goal_progress(BIGINT)
    IS 'Прогресс цели: задачи done + успешные дни habit/markers/scenario.';

-- ---------- sp_export_user_data: modern pattern entities -------------------

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
