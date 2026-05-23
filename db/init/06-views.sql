-- =============================================================================
-- 06 — Представления (VIEW и MATERIALIZED VIEW).
-- См. ТЗ.md, раздел 4.3.1.6.
-- =============================================================================

-- ---------- 1. v_calendar_day_stats --------------------------------------

CREATE OR REPLACE VIEW v_calendar_day_stats AS
WITH agg AS (
    SELECT
        t.user_id,
        t.deadline::date AS day,
        COUNT(*)                                       AS total,
        COUNT(*) FILTER (WHERE t.status = 'done')      AS done
      FROM tasks t
     WHERE t.deadline IS NOT NULL
     GROUP BY t.user_id, t.deadline::date
)
SELECT
    a.user_id,
    a.day,
    a.total::INT,
    a.done::INT,
    CASE WHEN a.total = 0 THEN 0
         ELSE ROUND(100.0 * a.done / a.total, 2)
    END AS ratio,
    fn_day_color(
        CASE WHEN a.total = 0 THEN 0
             ELSE 100.0 * a.done / a.total
        END
    ) AS color,
    h.holiday_date IS NOT NULL AS is_holiday,
    h.name AS holiday_name,
    EXISTS (
        SELECT 1 FROM diary_entries de
         WHERE de.user_id = a.user_id AND de.entry_date = a.day
    ) AS has_diary
  FROM agg a
  LEFT JOIN holidays h ON h.holiday_date = a.day;

COMMENT ON VIEW v_calendar_day_stats
    IS 'Прогресс по дням: total/done/ratio/color, признак праздника и наличия записи дневника.';

-- ---------- 2. v_task_topic_breakdown ------------------------------------

CREATE OR REPLACE VIEW v_task_topic_breakdown AS
SELECT
    t.user_id,
    t.topic_id,
    tp.name AS topic_name,
    COUNT(*)                                                          AS total,
    COUNT(*) FILTER (WHERE t.status = 'done')                         AS done,
    COUNT(*) FILTER (WHERE t.status = 'overdue')                      AS overdue,
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE t.status = 'done') / COUNT(*), 2)
    END                                                               AS completion_rate,
    AVG(t.planned_minutes)::INT                                       AS avg_planned_minutes,
    AVG(EXTRACT(EPOCH FROM (t.completed_at - t.deadline)) / 60.0)
        FILTER (WHERE t.status = 'overdue')::NUMERIC(10,2)            AS avg_overdue_minutes
  FROM tasks t
  JOIN topics tp ON tp.id = t.topic_id
 GROUP BY t.user_id, t.topic_id, tp.name;

COMMENT ON VIEW v_task_topic_breakdown
    IS 'Агрегаты по темам: total, done, overdue, % выполнения, среднее плановое, средняя просрочка.';

-- ---------- 3. v_pattern_streaks -----------------------------------------

CREATE OR REPLACE VIEW v_pattern_streaks AS
SELECT
    bp.id            AS pattern_id,
    bp.user_id,
    bp.title,
    bp.pattern_type,
    fn_calculate_streak(bp.id)        AS current_streak,
    fn_calculate_max_streak(bp.id)    AS max_streak,
    CASE WHEN bp.pattern_type = 'negative'
         THEN fn_calculate_anti_streak(bp.id)
         ELSE 0
    END                               AS anti_streak,
    (
        SELECT COUNT(*)::INT FROM pattern_logs pl
         WHERE pl.pattern_id = bp.id
           AND pl.scheduled_at >= now() - INTERVAL '30 days'
    )                                 AS logs_30d,
    (
        SELECT
            CASE WHEN COUNT(*) = 0 THEN 0
                 ELSE ROUND(100.0 * COUNT(*) FILTER (
                        WHERE pl.status = 'answered'
                          AND COALESCE(
                              (SELECT is_success FROM pattern_response_options o WHERE o.id = pl.response_option_id),
                              FALSE
                          )
                      ) / COUNT(*), 2)
            END
          FROM pattern_logs pl
         WHERE pl.pattern_id = bp.id
           AND pl.scheduled_at >= now() - INTERVAL '30 days'
    )                                 AS success_rate_30d
  FROM behavior_patterns bp;

COMMENT ON VIEW v_pattern_streaks
    IS 'Текущая/максимальная/анти-серия по каждому паттерну + % успешных откликов за 30 дней.';

-- ---------- 4. v_overdue_tasks (MATERIALIZED) ----------------------------

CREATE MATERIALIZED VIEW v_overdue_tasks AS
SELECT
    t.id,
    t.user_id,
    t.topic_id,
    t.title,
    t.priority,
    t.deadline,
    t.completed_at,
    EXTRACT(EPOCH FROM (COALESCE(t.completed_at, now()) - t.deadline)) / 60.0 AS overdue_minutes
  FROM tasks t
 WHERE t.status = 'overdue'
WITH NO DATA;

CREATE UNIQUE INDEX v_overdue_tasks_pk ON v_overdue_tasks (id);
CREATE INDEX        v_overdue_tasks_user ON v_overdue_tasks (user_id, deadline);

COMMENT ON MATERIALIZED VIEW v_overdue_tasks
    IS 'Список просроченных задач. Обновляется sp_recalc_calendar_cache.';

-- ---------- 5. v_mood_productivity_correlation ---------------------------

CREATE OR REPLACE VIEW v_mood_productivity_correlation AS
WITH days AS (
    SELECT
        de.user_id,
        de.entry_date AS day,
        de.mood,
        de.energy
      FROM diary_entries de
),
task_day AS (
    SELECT
        t.user_id,
        t.deadline::date AS day,
        CASE WHEN COUNT(*) = 0 THEN NULL
             ELSE 100.0 * COUNT(*) FILTER (WHERE t.status = 'done') / COUNT(*)
        END AS rate
      FROM tasks t
     WHERE t.deadline IS NOT NULL
     GROUP BY t.user_id, t.deadline::date
),
joined AS (
    SELECT d.user_id, d.day, d.mood, d.energy, td.rate
      FROM days d
      JOIN task_day td ON td.user_id = d.user_id AND td.day = d.day
)
SELECT
    user_id,
    date_trunc('week', day)::date           AS week_start,
    AVG(mood)::NUMERIC(4,2)                 AS avg_mood,
    AVG(energy)::NUMERIC(4,2)               AS avg_energy,
    AVG(rate)::NUMERIC(5,2)                 AS avg_completion_rate,
    corr(mood::numeric, rate)               AS corr_mood_rate,
    corr(energy::numeric, rate)             AS corr_energy_rate,
    COUNT(*)                                AS days_count
  FROM joined
 GROUP BY user_id, date_trunc('week', day);

COMMENT ON VIEW v_mood_productivity_correlation
    IS 'По неделям: средние mood/energy, % выполнения, корреляции Пирсона.';

-- ---------- 6. v_weekly_summary ------------------------------------------

CREATE OR REPLACE VIEW v_weekly_summary AS
WITH task_week AS (
    SELECT
        t.user_id,
        date_trunc('week', t.deadline)::date AS week_start,
        COUNT(*)                                       AS tasks_total,
        COUNT(*) FILTER (WHERE t.status = 'done')      AS tasks_done,
        COUNT(*) FILTER (WHERE t.status = 'overdue')   AS tasks_overdue
      FROM tasks t
     WHERE t.deadline IS NOT NULL
     GROUP BY t.user_id, date_trunc('week', t.deadline)::date
),
time_week AS (
    SELECT
        ttl.user_id,
        date_trunc('week', ttl.started_at)::date AS week_start,
        SUM(ttl.duration_seconds) / 60 AS minutes_logged
      FROM task_time_logs ttl
     GROUP BY ttl.user_id, date_trunc('week', ttl.started_at)::date
),
diary_week AS (
    SELECT
        de.user_id,
        date_trunc('week', de.entry_date)::date AS week_start,
        COUNT(*) AS diary_entries
      FROM diary_entries de
     GROUP BY de.user_id, date_trunc('week', de.entry_date)::date
)
SELECT
    tw.user_id,
    tw.week_start,
    tw.tasks_total,
    tw.tasks_done,
    tw.tasks_overdue,
    COALESCE(time_week.minutes_logged, 0)::INT AS minutes_logged,
    COALESCE(diary_week.diary_entries, 0)      AS diary_entries
  FROM task_week tw
  LEFT JOIN time_week  ON time_week.user_id  = tw.user_id AND time_week.week_start  = tw.week_start
  LEFT JOIN diary_week ON diary_week.user_id = tw.user_id AND diary_week.week_start = tw.week_start;

COMMENT ON VIEW v_weekly_summary
    IS 'Сводка за неделю: задачи, минуты Pomodoro, записи дневника.';

-- ---------- 7. v_year_heatmap --------------------------------------------

CREATE OR REPLACE VIEW v_year_heatmap AS
SELECT
    user_id,
    day,
    SUM(activity)::INT AS activity
  FROM (
    SELECT user_id, deadline::date AS day, 1 AS activity
      FROM tasks WHERE deadline IS NOT NULL
    UNION ALL
    SELECT user_id, entry_date AS day, 1 AS activity
      FROM diary_entries
    UNION ALL
    SELECT bp.user_id, date_trunc('day', pl.scheduled_at)::date AS day, 1 AS activity
      FROM pattern_logs pl
      JOIN behavior_patterns bp ON bp.id = pl.pattern_id
  ) u
 GROUP BY user_id, day;

COMMENT ON VIEW v_year_heatmap
    IS 'Тепловая карта активности за год: задачи + дневник + паттерны.';

-- ---------- 8. v_goal_progress -------------------------------------------

CREATE OR REPLACE VIEW v_goal_progress AS
SELECT
    g.id          AS goal_id,
    g.user_id,
    g.title,
    g.deadline,
    g.target_value,
    g.is_completed,
    fn_goal_progress(g.id) AS progress
  FROM goals g;

COMMENT ON VIEW v_goal_progress
    IS 'Текущий процент выполнения каждой цели.';

-- ---------- 9. v_task_subtree_progress (рекурсивный CTE) ----------------

CREATE OR REPLACE VIEW v_task_subtree_progress AS
WITH RECURSIVE tree AS (
    SELECT id, parent_task_id, status,
           id AS root_id
      FROM tasks
     WHERE parent_task_id IS NULL
    UNION ALL
    SELECT t.id, t.parent_task_id, t.status,
           tr.root_id
      FROM tasks t
      JOIN tree tr ON tr.id = t.parent_task_id
)
SELECT
    root_id AS task_id,
    COUNT(*) - 1                                AS subtask_total,
    COUNT(*) FILTER (WHERE status = 'done') - CASE
        WHEN MAX(CASE WHEN id = root_id AND status = 'done' THEN 1 ELSE 0 END) = 1 THEN 1
        ELSE 0
    END                                          AS subtask_done,
    CASE
        WHEN COUNT(*) - 1 = 0 THEN
            CASE WHEN MAX(CASE WHEN id = root_id AND status = 'done' THEN 1 ELSE 0 END) = 1 THEN 100 ELSE 0 END
        ELSE
            ROUND(
                100.0 * (COUNT(*) FILTER (WHERE status = 'done')
                  - CASE WHEN MAX(CASE WHEN id = root_id AND status = 'done' THEN 1 ELSE 0 END) = 1 THEN 1 ELSE 0 END)
                / (COUNT(*) - 1), 2
            )
    END                                          AS progress
  FROM tree
 GROUP BY root_id;

COMMENT ON VIEW v_task_subtree_progress
    IS 'Прогресс корневой задачи на основе её подзадач (рекурсивный CTE).';

-- ---------- 10. v_topic_time_distribution --------------------------------

CREATE OR REPLACE VIEW v_topic_time_distribution AS
SELECT
    t.user_id,
    t.topic_id,
    tp.name AS topic_name,
    COALESCE(SUM(ttl.duration_seconds), 0) / 60 AS minutes,
    COALESCE(SUM(ttl.duration_seconds) FILTER (WHERE ttl.is_pomodoro), 0) / 60 AS pomodoro_minutes
  FROM tasks t
  JOIN topics tp ON tp.id = t.topic_id
  LEFT JOIN task_time_logs ttl ON ttl.task_id = t.id
 GROUP BY t.user_id, t.topic_id, tp.name;

COMMENT ON VIEW v_topic_time_distribution
    IS 'Распределение фактического времени по темам (всё время и отдельно Pomodoro).';

DO $$
BEGIN
    RAISE NOTICE 'PTT 06-views: 10 views (incl. 1 materialized) created';
END $$;
