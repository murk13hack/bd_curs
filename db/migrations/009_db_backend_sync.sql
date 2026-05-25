-- Синхронизация схемы с backend/frontend: экспорт closures, удаление дублей.
-- docker cp db/migrations/009_db_backend_sync.sql ptt-db:/tmp/ &&
--   docker exec ptt-db psql -U ptt -d ptt -f /tmp/009_db_backend_sync.sql

-- ---------- Удалить объекты-дубли (API использует другие) ------------------

DROP VIEW IF EXISTS v_goal_progress;
DROP VIEW IF EXISTS v_calendar_day_stats;
DROP FUNCTION IF EXISTS fn_mood_productivity_corr(BIGINT, DATE, DATE);
DROP FUNCTION IF EXISTS fn_topic_time_breakdown(BIGINT, DATE, DATE);

-- ---------- sp_export_user_data: pattern_marker_day_closures ---------------

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
        'pattern_marker_day_closures', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_marker_day_closures x
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

COMMENT ON PROCEDURE sp_export_user_data(BIGINT, JSONB)
    IS 'Экспорт всех данных пользователя в JSONB (включая pattern_marker_day_closures).';
