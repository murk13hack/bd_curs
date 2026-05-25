-- =============================================================================
-- 06 — Представления (VIEW и MATERIALIZED VIEW).
-- См. ТЗ.md, раздел 4.3.1.6.
-- =============================================================================

-- Календарь месяца: fn_get_calendar_stats (API /calendar/{y}/{m}).

-- ---------- 1. v_task_topic_breakdown ------------------------------------

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

DROP VIEW IF EXISTS v_pattern_streaks;
CREATE VIEW v_pattern_streaks AS
SELECT
    bp.id            AS pattern_id,
    bp.user_id,
    bp.title,
    bp.pattern_type,
    bp.pattern_mode,
    fn_calculate_streak(bp.id)     AS current_streak,
    fn_calculate_max_streak(bp.id) AS max_streak,
    CASE WHEN bp.pattern_type = 'negative'
         THEN fn_calculate_anti_streak(bp.id)
         ELSE 0
    END                            AS anti_streak,
    cd.scheduled_days              AS scheduled_days_30d,
    cd.success_days                AS success_days_30d,
    cd.clean_rate                  AS clean_rate_30d,
    cd.clean_rate                  AS success_rate_30d
  FROM behavior_patterns bp
  CROSS JOIN LATERAL fn_pattern_clean_days_30d(bp.id) cd;

COMMENT ON VIEW v_pattern_streaks
    IS 'Серии: current/max — успешные дни; anti_streak — подряд срывов (negative).';

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

-- ---------- 5b. OLAP daily facts + holistic + task priority ------------

CREATE OR REPLACE VIEW v_olap_daily_facts AS
WITH activity_days AS (
    SELECT user_id, day FROM (
        SELECT user_id, deadline::date AS day
          FROM tasks WHERE deadline IS NOT NULL
        UNION
        SELECT user_id, entry_date AS day FROM diary_entries
        UNION
        SELECT bp.user_id, date_trunc('day', pl.scheduled_at)::date AS day
          FROM pattern_logs pl
          JOIN behavior_patterns bp ON bp.id = pl.pattern_id
         WHERE pl.status = 'answered'
        UNION
        SELECT bp.user_id, pm.occurred_at::date AS day
          FROM pattern_markers pm
          JOIN behavior_patterns bp ON bp.id = pm.pattern_id
        UNION
        SELECT bp.user_id, pds.session_date AS day
          FROM pattern_day_sessions pds
          JOIN behavior_patterns bp ON bp.id = pds.pattern_id
        UNION
        SELECT user_id, started_at::date AS day FROM task_time_logs
    ) u
),
task_m AS (
    SELECT user_id, deadline::date AS day,
           COUNT(*)::INT                                              AS tasks_total,
           COUNT(*) FILTER (WHERE status = 'done')::INT               AS tasks_done,
           COUNT(*) FILTER (WHERE status = 'overdue')::INT              AS tasks_overdue,
           COUNT(*) FILTER (WHERE status = 'in_progress')::INT        AS tasks_in_progress,
           COUNT(*) FILTER (WHERE status = 'pending')::INT            AS tasks_pending
      FROM tasks WHERE deadline IS NOT NULL
     GROUP BY user_id, deadline::date
),
time_m AS (
    SELECT user_id, started_at::date AS day,
           COALESCE(SUM(duration_seconds), 0)::INT / 60                 AS minutes_logged,
           COALESCE(SUM(duration_seconds) FILTER (WHERE is_pomodoro), 0)::INT / 60 AS pomodoro_minutes,
           COUNT(*)::INT                                                AS time_log_count
      FROM task_time_logs
     GROUP BY user_id, started_at::date
),
diary_m AS (
    SELECT user_id, entry_date AS day,
           mood, energy, 1 AS diary_entries
      FROM diary_entries
),
marker_m AS (
    SELECT bp.user_id, pm.occurred_at::date AS day,
           COUNT(*)::INT AS marker_events,
           COUNT(*) FILTER (WHERE NOT o.is_success)::INT AS marker_bad_events
      FROM pattern_markers pm
      JOIN behavior_patterns bp ON bp.id = pm.pattern_id
      JOIN pattern_response_options o ON o.id = pm.marker_option_id
     GROUP BY bp.user_id, pm.occurred_at::date
)
SELECT
    ad.user_id,
    ad.day,
    EXTRACT(ISODOW FROM ad.day)::INT AS dow,
    COALESCE(tm.tasks_total, 0)         AS tasks_total,
    COALESCE(tm.tasks_done, 0)          AS tasks_done,
    COALESCE(tm.tasks_overdue, 0)       AS tasks_overdue,
    COALESCE(tm.tasks_in_progress, 0)   AS tasks_in_progress,
    COALESCE(tm.tasks_pending, 0)       AS tasks_pending,
    COALESCE(tlm.minutes_logged, 0)     AS minutes_logged,
    COALESCE(tlm.pomodoro_minutes, 0)   AS pomodoro_minutes,
    COALESCE(tlm.time_log_count, 0)     AS time_log_count,
    COALESCE(dm.diary_entries, 0)       AS diary_entries,
    dm.mood,
    dm.energy,
    CASE
        WHEN dm.mood IS NULL THEN 'none'
        WHEN dm.mood <= 2 THEN 'low'
        WHEN dm.mood = 3 THEN 'mid'
        ELSE 'high'
    END AS mood_bucket,
    CASE
        WHEN dm.energy IS NULL THEN 'none'
        WHEN dm.energy <= 2 THEN 'low'
        WHEN dm.energy = 3 THEN 'mid'
        ELSE 'high'
    END AS energy_bucket,
    (
        SELECT COUNT(*)::INT FROM behavior_patterns bp
         WHERE bp.user_id = ad.user_id AND fn_pattern_is_scheduled(bp.id, ad.day)
    ) AS patterns_scheduled,
    (
        SELECT COUNT(*)::INT FROM behavior_patterns bp
         WHERE bp.user_id = ad.user_id
           AND fn_pattern_is_scheduled(bp.id, ad.day)
           AND fn_pattern_day_success(bp.id, ad.day)
    ) AS patterns_success,
    (
        SELECT COUNT(*)::INT FROM behavior_patterns bp
         WHERE bp.user_id = ad.user_id AND fn_pattern_day_has_answer(bp.id, ad.day)
    ) AS patterns_answered,
    COALESCE(mm.marker_events, 0)     AS marker_events,
    COALESCE(mm.marker_bad_events, 0) AS marker_bad_events,
    (
        COALESCE(tm.tasks_total, 0)
        + COALESCE(dm.diary_entries, 0)
        + COALESCE((
            SELECT COUNT(*)::INT FROM behavior_patterns bp
             WHERE bp.user_id = ad.user_id AND fn_pattern_day_has_answer(bp.id, ad.day)
        ), 0)
    )::INT AS activity_score
  FROM activity_days ad
  LEFT JOIN task_m tm ON tm.user_id = ad.user_id AND tm.day = ad.day
  LEFT JOIN time_m tlm ON tlm.user_id = ad.user_id AND tlm.day = ad.day
  LEFT JOIN diary_m dm ON dm.user_id = ad.user_id AND dm.day = ad.day
  LEFT JOIN marker_m mm ON mm.user_id = ad.user_id AND mm.day = ad.day;

COMMENT ON VIEW v_olap_daily_facts IS
    'OLAP-факты: grain user×day. Задачи, время, дневник, паттерны, метки.';

CREATE OR REPLACE VIEW v_mood_holistic_correlation AS
WITH base AS (
    SELECT
        f.user_id,
        f.day,
        f.mood,
        f.energy,
        CASE WHEN f.tasks_total = 0 THEN NULL
             ELSE 100.0 * f.tasks_done / f.tasks_total END AS task_rate,
        CASE WHEN f.patterns_scheduled = 0 THEN NULL
             ELSE 100.0 * f.patterns_success / f.patterns_scheduled END AS pattern_clean_rate,
        f.minutes_logged,
        f.marker_bad_events
      FROM v_olap_daily_facts f
     WHERE f.mood IS NOT NULL
)
SELECT
    user_id,
    date_trunc('week', day)::date AS week_start,
    AVG(mood)::NUMERIC(4,2)       AS avg_mood,
    AVG(energy)::NUMERIC(4,2)     AS avg_energy,
    AVG(task_rate)::NUMERIC(5,2)  AS avg_task_rate,
    AVG(pattern_clean_rate)::NUMERIC(5,2) AS avg_pattern_clean_rate,
    AVG(minutes_logged)::NUMERIC(8,2) AS avg_minutes,
    corr(mood::numeric, task_rate) AS corr_mood_tasks,
    corr(mood::numeric, pattern_clean_rate) AS corr_mood_patterns,
    corr(energy::numeric, task_rate) AS corr_energy_tasks,
    COUNT(*) AS days_count
  FROM base
 GROUP BY user_id, date_trunc('week', day);

COMMENT ON VIEW v_mood_holistic_correlation IS
    'Недельная корреляция: настроение/энергия ↔ задачи и паттерны.';

CREATE OR REPLACE VIEW v_stats_task_priority AS
SELECT
    t.user_id,
    t.priority,
    COUNT(*)::INT AS total,
    COUNT(*) FILTER (WHERE t.status = 'done')::INT AS done,
    COUNT(*) FILTER (WHERE t.status = 'overdue')::INT AS overdue,
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE t.status = 'done') / COUNT(*), 2)
    END AS completion_rate
  FROM tasks t
 GROUP BY t.user_id, t.priority;

-- ---------- 6. v_weekly_summary ------------------------------------------

DROP VIEW IF EXISTS v_weekly_summary;
CREATE VIEW v_weekly_summary AS
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
        COUNT(*) AS diary_entries,
        AVG(de.mood)::NUMERIC(4,2) AS avg_mood,
        AVG(de.energy)::NUMERIC(4,2) AS avg_energy
      FROM diary_entries de
     GROUP BY de.user_id, date_trunc('week', de.entry_date)::date
),
pattern_week AS (
    SELECT
        user_id,
        date_trunc('week', day)::date AS week_start,
        SUM(patterns_scheduled)::INT AS patterns_scheduled,
        SUM(patterns_success)::INT AS patterns_success,
        SUM(marker_events)::INT AS marker_events,
        SUM(marker_bad_events)::INT AS marker_bad_events
      FROM v_olap_daily_facts
     GROUP BY user_id, date_trunc('week', day)::date
),
weeks AS (
    SELECT user_id, week_start FROM task_week
    UNION
    SELECT user_id, week_start FROM time_week
    UNION
    SELECT user_id, week_start FROM diary_week
    UNION
    SELECT user_id, week_start FROM pattern_week
)
SELECT
    w.user_id,
    w.week_start,
    COALESCE(tw.tasks_total, 0)::INT AS tasks_total,
    COALESCE(tw.tasks_done, 0)::INT AS tasks_done,
    COALESCE(tw.tasks_overdue, 0)::INT AS tasks_overdue,
    COALESCE(time_week.minutes_logged, 0)::INT AS minutes_logged,
    COALESCE(diary_week.diary_entries, 0)::INT AS diary_entries,
    diary_week.avg_mood,
    diary_week.avg_energy,
    COALESCE(pw.patterns_scheduled, 0)::INT AS patterns_scheduled,
    COALESCE(pw.patterns_success, 0)::INT AS patterns_success,
    COALESCE(pw.marker_events, 0)::INT AS marker_events,
    COALESCE(pw.marker_bad_events, 0)::INT AS marker_bad_events
  FROM weeks w
  LEFT JOIN task_week tw ON tw.user_id = w.user_id AND tw.week_start = w.week_start
  LEFT JOIN time_week ON time_week.user_id = w.user_id AND time_week.week_start = w.week_start
  LEFT JOIN diary_week ON diary_week.user_id = w.user_id AND diary_week.week_start = w.week_start
  LEFT JOIN pattern_week pw ON pw.user_id = w.user_id AND pw.week_start = w.week_start;

COMMENT ON VIEW v_weekly_summary
    IS 'Сводка за неделю: задачи, время, дневник, паттерны, markers.';

-- ---------- 7. v_year_heatmap --------------------------------------------

CREATE OR REPLACE VIEW v_year_heatmap AS
SELECT user_id, day, SUM(activity)::INT AS activity
  FROM (
    SELECT user_id, deadline::date AS day, 1 AS activity FROM tasks WHERE deadline IS NOT NULL
    UNION ALL
    SELECT user_id, entry_date AS day, 1 FROM diary_entries
    UNION ALL
    SELECT bp.user_id, date_trunc('day', pl.scheduled_at)::date AS day, 1
      FROM pattern_logs pl JOIN behavior_patterns bp ON bp.id = pl.pattern_id
    UNION ALL
    SELECT bp.user_id, pm.occurred_at::date AS day, 1
      FROM pattern_markers pm JOIN behavior_patterns bp ON bp.id = pm.pattern_id
    UNION ALL
    SELECT bp.user_id, pds.session_date AS day, 1
      FROM pattern_day_sessions pds JOIN behavior_patterns bp ON bp.id = pds.pattern_id
    UNION ALL
    SELECT user_id, started_at::date AS day, 1 FROM task_time_logs
  ) u
 GROUP BY user_id, day;

COMMENT ON VIEW v_year_heatmap
    IS 'Тепловая карта активности: задачи, дневник, паттерны, метки, сессии, время.';

-- Прогресс целей: fn_goal_progress (API GET /goals/{id}/progress).

-- ---------- 8. v_task_subtree_progress (рекурсивный CTE) -----------------

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

-- ---------- 9. v_topic_time_distribution ---------------------------------

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
    RAISE NOTICE 'PTT 06-views: 11 views (incl. 1 materialized) created';
END $$;
