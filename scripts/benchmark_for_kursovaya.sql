-- =============================================================================
-- Бенчмарк для курсовой (таблица 9, рисунки 11–13).
-- Формат вывода: EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) — удобно копировать в чат.
--
-- Рекомендуемый запуск (из корня репозитория, Linux):
--   ./scripts/benchmark_run_for_kursovaya.sh
--   ./scripts/benchmark_run_for_kursovaya.sh 10000
--
-- Вручную:
--   docker cp scripts/benchmark_load_tasks.sql ptt-db:/tmp/
--   docker cp scripts/benchmark_seed_diary.sql ptt-db:/tmp/
--   docker cp scripts/benchmark_for_kursovaya.sql ptt-db:/tmp/
--   docker exec ptt-db psql -U ptt -d ptt -v count=10000 -f /tmp/benchmark_load_tasks.sql
--   docker exec ptt-db psql -U ptt -d ptt -f /tmp/benchmark_seed_diary.sql
--   docker exec ptt-db psql -U ptt -d ptt -f /tmp/benchmark_for_kursovaya.sql \
--     > docs/benchmark_explain_out.txt 2>&1
--
-- Пришлите ассистенту файл docs/benchmark_explain_out.txt целиком
-- (или фрагменты между MARKER_START и MARKER_END).
-- =============================================================================

\set ON_ERROR_STOP on
\pset footer off
\timing on

\set user_id 1
\set year 2025
\set month 5

\echo ''
\echo '==================== MARKER_START ===================='
\echo ''

-- ---------------------------------------------------------------------------
-- 0. Объёмы данных (должно быть tasks ~10000+, diary ~500+ для S2)
-- ---------------------------------------------------------------------------
\echo '=== META: объёмы после нагрузки ==='
SELECT 'tasks_user_1' AS metric, COUNT(*)::text AS value
  FROM tasks WHERE user_id = :user_id
UNION ALL
SELECT 'tasks_bench_titles', COUNT(*)::text
  FROM tasks WHERE user_id = :user_id AND title LIKE 'Bench #%'
UNION ALL
SELECT 'diary_user_1', COUNT(*)::text
  FROM diary_entries WHERE user_id = :user_id
UNION ALL
SELECT 'pattern_logs', COUNT(*)::text
  FROM pattern_logs pl
  JOIN behavior_patterns bp ON bp.id = pl.pattern_id
 WHERE bp.user_id = :user_id
UNION ALL
SELECT 'behavior_patterns', COUNT(*)::text
  FROM behavior_patterns WHERE user_id = :user_id;

\echo ''
\echo 'Если tasks_user_1 < 1000 — сначала выполните benchmark_load_tasks.sql (см. benchmark_run_for_kursovaya.sh).'
\echo ''

-- ---------------------------------------------------------------------------
-- 0b. Минимальный паттерн для Q4 (только если у user_id=1 нет паттернов)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    v_pid BIGINT;
    v_opt_ok BIGINT;
    v_topic BIGINT;
    g INT;
BEGIN
    IF EXISTS (SELECT 1 FROM behavior_patterns WHERE user_id = 1) THEN
        RAISE NOTICE 'Q4: используем существующий behavior_patterns (demo/seed).';
        RETURN;
    END IF;

    SELECT id INTO v_topic FROM topics WHERE user_id = 1 ORDER BY id LIMIT 1;
    IF v_topic IS NULL THEN
        INSERT INTO topics (user_id, name, color) VALUES (1, 'Бенчмарк', '#3B82F6')
        RETURNING id INTO v_topic;
    END IF;

    INSERT INTO behavior_patterns (user_id, topic_id, title, pattern_type, is_boolean, pattern_mode)
    VALUES (1, v_topic, 'Bench streak', 'positive', TRUE, 'habit')
    RETURNING id INTO v_pid;

    INSERT INTO pattern_response_options (pattern_id, label, is_success, sort_order)
    VALUES (v_pid, 'Да', TRUE, 0), (v_pid, 'Нет', FALSE, 1)
    RETURNING id INTO v_opt_ok;

    SELECT id INTO v_opt_ok FROM pattern_response_options
     WHERE pattern_id = v_pid AND is_success = TRUE LIMIT 1;

    INSERT INTO pattern_schedules (pattern_id, time_of_day, dow_mask)
    VALUES (v_pid, time '09:00', 127);

    FOR g IN 1..90 LOOP
        INSERT INTO pattern_logs (pattern_id, response_option_id, scheduled_at, answered_at, status)
        VALUES (
            v_pid,
            v_opt_ok,
            (current_date - g) + time '09:00',
            (current_date - g) + time '09:15',
            'answered'
        );
    END LOOP;

    RAISE NOTICE 'Q4: создан bench-паттерн id=% с 90 answered logs.', v_pid;
END $$;

ANALYZE tasks;
ANALYZE diary_entries;
ANALYZE behavior_patterns;
ANALYZE pattern_logs;

-- ---------------------------------------------------------------------------
-- Q1 — календарь месяца (лимит ТЗ: 250 мс при до 10 000 задач)
-- ---------------------------------------------------------------------------
\echo ''
\echo '========== Q1 | fn_get_calendar_stats | лимит ТЗ 250 ms =========='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM fn_get_calendar_stats(:user_id, :year, :month);

-- ---------------------------------------------------------------------------
-- Q3 — список задач по topic + status (idx_tasks_topic_status)
-- ---------------------------------------------------------------------------
\echo ''
\echo '========== Q3 | tasks topic_id + status | idx_tasks_topic_status =========='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id, title, status, deadline
  FROM tasks
 WHERE user_id = :user_id
   AND topic_id = (SELECT id FROM topics WHERE user_id = :user_id LIMIT 1)
   AND status = 'pending'
 ORDER BY deadline NULLS LAST
 LIMIT 200;

-- ---------------------------------------------------------------------------
-- Q4 — серия паттерна (idx_pattern_logs_pattern_date)
-- ---------------------------------------------------------------------------
\echo ''
\echo '========== Q4 | fn_calculate_streak | idx_pattern_logs_pattern_date =========='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT fn_calculate_streak(
    (SELECT id FROM behavior_patterns WHERE user_id = :user_id ORDER BY id LIMIT 1)
) AS streak;

-- ---------------------------------------------------------------------------
-- Q5 — OLAP-срез по неделям (v_olap_daily_facts)
-- ---------------------------------------------------------------------------
\echo ''
\echo '========== Q5 | OLAP v_olap_daily_facts by week =========='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    date_trunc('week', day)::date AS week,
    SUM(tasks_total) AS tasks_total,
    SUM(tasks_done) AS tasks_done,
    ROUND(AVG(avg_mood)::numeric, 2) AS avg_mood
  FROM v_olap_daily_facts
 WHERE user_id = :user_id
   AND day BETWEEN '2025-01-01' AND '2025-12-31'
 GROUP BY 1
 ORDER BY 1;

-- ---------------------------------------------------------------------------
-- Q6 — FTS по задачам (idx_tasks_search_gin), слово «bench» в заголовках
-- ---------------------------------------------------------------------------
\echo ''
\echo '========== Q6 | FTS tasks | idx_tasks_search_gin =========='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id, title
  FROM tasks
 WHERE user_id = :user_id
   AND to_tsvector('russian', coalesce(title,'') || ' ' || coalesce(description,''))
       @@ plainto_tsquery('russian', 'bench')
 LIMIT 50;

-- ---------------------------------------------------------------------------
-- Q2a — FTS дневника БЕЗ GIN (ожидается Seq Scan, медленнее)
-- ---------------------------------------------------------------------------
\echo ''
\echo '========== Q2a | fn_search_diary БЕЗ idx_diary_fts_gin =========='
DROP INDEX IF EXISTS idx_diary_fts_gin;
ANALYZE diary_entries;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM fn_search_diary(:user_id, 'продуктивность', 50);

-- ---------------------------------------------------------------------------
-- Q2b — FTS дневника С GIN (ожидается Bitmap Index Scan)
-- ---------------------------------------------------------------------------
\echo ''
\echo '========== Q2b | fn_search_diary С idx_diary_fts_gin =========='
CREATE INDEX IF NOT EXISTS idx_diary_fts_gin
    ON diary_entries USING gin (content_tsv);
ANALYZE diary_entries;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM fn_search_diary(:user_id, 'продуктивность', 50);

-- ---------------------------------------------------------------------------
-- Сводка для таблицы 9 (скопируйте строки ниже в чат)
-- ---------------------------------------------------------------------------
\echo ''
\echo '=== META: итог (скопируйте в чат вместе с планами выше) ==='
SELECT 'dataset' AS k, 'S2' AS v
UNION ALL SELECT 'tasks', COUNT(*)::text FROM tasks WHERE user_id = :user_id
UNION ALL SELECT 'diary', COUNT(*)::text FROM diary_entries WHERE user_id = :user_id
UNION ALL SELECT 'bench_tasks', COUNT(*)::text FROM tasks WHERE user_id = :user_id AND title LIKE 'Bench #%';

\echo ''
\echo 'Для таблицы 9 из каждого блока Q* возьмите:'
\echo '  - строку "Execution Time: X ms" (в конце плана)'
\echo '  - узел: Index Scan / Bitmap Index Scan / Seq Scan / HashAggregate'
\echo '  - сумму "shared read=" по плану (buffers)'
\echo ''
\echo '==================== MARKER_END ===================='
