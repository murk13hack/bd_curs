-- =============================================================================
-- УСТАРЕВШИЙ КОРОТКИЙ СКРИПТ (без Q2a/Q2b и без подготовки данных).
--
-- Для курсовой используйте полный прогон:
--   ./scripts/benchmark_run_for_kursovaya.sh
--   или scripts/benchmark_for_kursovaya.sql (см. комментарии в файле).
-- =============================================================================

\timing on
\set user_id 1
\set year 2025
\set month 5

\echo '========== Q1 Calendar month (fn_get_calendar_stats) =========='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM fn_get_calendar_stats(:user_id, :year, :month);

\echo '========== Q2 Diary FTS (fn_search_diary) =========='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM fn_search_diary(:user_id, 'продуктивность', 50);

\echo '========== Q3 Task list by topic+status (idx_tasks_topic_status) =========='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id, title, status, deadline
  FROM tasks
 WHERE user_id = :user_id
   AND topic_id = (SELECT id FROM topics WHERE user_id = :user_id LIMIT 1)
   AND status = 'pending'
 ORDER BY deadline NULLS LAST
 LIMIT 200;

\echo '========== Q4 Pattern streak (fn_calculate_streak) =========='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT fn_calculate_streak(
    (SELECT id FROM behavior_patterns WHERE user_id = :user_id LIMIT 1)
);

\echo '========== Q5 OLAP slice (v_olap_daily_facts + week) =========='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    date_trunc('week', day)::date AS week,
    SUM(tasks_total) AS tasks_total,
    SUM(tasks_done) AS tasks_done,
    ROUND(AVG(mood)::numeric, 2) AS avg_mood_week
  FROM v_olap_daily_facts
 WHERE user_id = :user_id
   AND day BETWEEN '2025-01-01' AND '2025-12-31'
 GROUP BY 1
 ORDER BY 1;

\echo '========== Q6 Tasks FTS (idx_tasks_search_gin) =========='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id, title
  FROM tasks
 WHERE user_id = :user_id
   AND to_tsvector('russian', coalesce(title,'') || ' ' || coalesce(description,''))
       @@ plainto_tsquery('russian', 'bench')
 LIMIT 50;
