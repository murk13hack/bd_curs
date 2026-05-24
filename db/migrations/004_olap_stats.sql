-- OLAP: единая таблица фактов по дням + расширенная корреляция.
-- docker cp db/migrations/004_olap_stats.sql ptt-db:/tmp/ && docker exec ptt-db psql -U ptt -d ptt -f /tmp/004_olap_stats.sql

-- ---------- v_olap_daily_facts (grain: user × day) -----------------------

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

-- ---------- v_mood_holistic_correlation (tasks + patterns + diary) -------

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

-- ---------- v_stats_task_priority ----------------------------------------

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

-- ---------- extend v_weekly_summary with patterns ------------------------

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

-- ---------- update heatmap to include markers/sessions -----------------

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
