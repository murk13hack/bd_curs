-- =============================================================================
-- Наполнение tasks для испытаний (10 000 / 100 000 строк).
--   docker cp scripts/benchmark_load_tasks.sql ptt-db:/tmp/
--   docker exec ptt-db psql -U ptt -d ptt -v count=10000 -f /tmp/benchmark_load_tasks.sql
-- =============================================================================

\set ON_ERROR_STOP on
\if :{?count}
\else
\set count 10000
\endif

INSERT INTO topics (user_id, name, color)
SELECT 1, 'Бенчмарк', '#3B82F6'
 WHERE NOT EXISTS (SELECT 1 FROM topics WHERE user_id = 1);

INSERT INTO tasks (
    user_id, topic_id, title, description, status, priority,
    deadline, planned_minutes, created_at
)
SELECT
    1,
    (SELECT id FROM topics WHERE user_id = 1 ORDER BY id LIMIT 1),
    'Bench #' || g,
    'Load test for EXPLAIN',
    (ARRAY['pending','in_progress','done','overdue'])[1 + (g % 4)],
    (ARRAY['low','medium','high','urgent']::task_priority_enum[])[1 + (g % 4)],
    (date '2024-01-01' + (g % 730))::timestamptz + time '18:00',
    30 + (g % 90),
    (date '2024-01-01' + (g % 730))::timestamptz
FROM generate_series(1, :count) AS g;

ANALYZE tasks;

SELECT COUNT(*) AS tasks_for_user_1 FROM tasks WHERE user_id = 1;
