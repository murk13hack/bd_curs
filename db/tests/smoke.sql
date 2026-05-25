-- =============================================================================
-- Smoke-тесты схемы БД ПТТ.
-- Запуск:
--   docker cp db/tests/smoke.sql ptt-db:/tmp/smoke.sql
--   docker compose exec -T db psql -U ptt -d ptt -v ON_ERROR_STOP=1 -f /tmp/smoke.sql
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ---------- 1. Метаданные: проверка наличия объектов ---------------------

DO $$
DECLARE
    v_tables    INT; v_views     INT; v_matviews INT;
    v_funcs     INT; v_procs     INT; v_triggers INT;
    v_indexes   INT;
BEGIN
    SELECT COUNT(*) INTO v_tables    FROM information_schema.tables
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
    SELECT COUNT(*) INTO v_views     FROM information_schema.views
        WHERE table_schema = 'public';
    SELECT COUNT(*) INTO v_matviews  FROM pg_matviews
        WHERE schemaname = 'public';
    SELECT COUNT(*) INTO v_funcs     FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.prokind = 'f';
    SELECT COUNT(*) INTO v_procs     FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.prokind = 'p';
    SELECT COUNT(*) INTO v_triggers  FROM information_schema.triggers
        WHERE trigger_schema = 'public';
    SELECT COUNT(*) INTO v_indexes   FROM pg_indexes
        WHERE schemaname = 'public';

    RAISE NOTICE 'TABLES=%, VIEWS=%, MATVIEWS=%, FUNCS=%, PROCS=%, TRIGGERS=%, INDEXES=%',
                 v_tables, v_views, v_matviews, v_funcs, v_procs, v_triggers, v_indexes;

    ASSERT v_tables   >= 18, 'Tables expected >= 18';
    ASSERT v_views    >=  9, 'Views (regular) expected >= 9';
    ASSERT v_matviews >=  1, 'Materialized views expected >= 1';
    ASSERT v_funcs    >=  9, 'Functions expected >= 9';
    ASSERT v_procs    >=  8, 'Procedures expected >= 8';
    ASSERT v_triggers >= 10, 'Triggers expected >= 10';
END $$;

-- ---------- 2. Базовые insert-ы и работа триггера просрочки --------------

INSERT INTO tasks (user_id, topic_id, title, deadline, planned_minutes)
VALUES (1,
        (SELECT id FROM topics WHERE user_id = 1 AND name = 'Работа'),
        'smoke: задача-просрочка',
        now() + INTERVAL '1 minute',
        30);

UPDATE tasks
   SET completed_at = now() + INTERVAL '2 minutes',
       status       = 'done'
 WHERE title = 'smoke: задача-просрочка';

DO $$
DECLARE v_status task_status_enum;
BEGIN
    SELECT status INTO v_status FROM tasks WHERE title = 'smoke: задача-просрочка';
    RAISE NOTICE 'smoke task final status = %', v_status;
    ASSERT v_status = 'overdue', 'trg_task_overdue_check did not fire';
END $$;

-- ---------- 3. Дневник + полнотекстовый поиск ----------------------------

INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
VALUES (1, current_date, 'Сегодня прекрасный день, я учился базам данных и PostgreSQL', 5, 4)
ON CONFLICT (user_id, entry_date) DO UPDATE
   SET content = EXCLUDED.content,
       mood    = EXCLUDED.mood,
       energy  = EXCLUDED.energy;

DO $$
DECLARE v_found INT;
BEGIN
    SELECT COUNT(*) INTO v_found
      FROM fn_search_diary(1, 'PostgreSQL');
    RAISE NOTICE 'diary FTS: found % entries by query "PostgreSQL"', v_found;
    ASSERT v_found >= 1, 'fn_search_diary returned no rows for "PostgreSQL"';
END $$;

-- ---------- 4. Календарь -------------------------------------------------

DO $$
DECLARE v_rows INT;
BEGIN
    SELECT COUNT(*) INTO v_rows FROM fn_get_calendar_stats(
        1, EXTRACT(year FROM current_date)::INT, EXTRACT(month FROM current_date)::INT
    );
    RAISE NOTICE 'fn_get_calendar_stats returned % rows for current month', v_rows;
    ASSERT v_rows BETWEEN 28 AND 31, 'calendar must have 28..31 days';
END $$;

-- ---------- 5. Паттерн + серия ------------------------------------------

INSERT INTO behavior_patterns (user_id, title, pattern_type, is_boolean)
VALUES (1, 'smoke: зарядка', 'positive', TRUE);

WITH p AS (
    SELECT id FROM behavior_patterns WHERE title = 'smoke: зарядка'
)
INSERT INTO pattern_response_options (pattern_id, label, is_success, sort_order)
SELECT p.id, 'Сделал', TRUE, 0 FROM p
UNION ALL
SELECT p.id, 'Не сделал', FALSE, 1 FROM p;

DO $$
DECLARE
    v_pattern BIGINT;
    v_option  BIGINT;
    v_streak  INT;
BEGIN
    SELECT id INTO v_pattern FROM behavior_patterns WHERE title = 'smoke: зарядка';
    SELECT id INTO v_option
      FROM pattern_response_options
     WHERE pattern_id = v_pattern AND is_success = TRUE LIMIT 1;

    CALL sp_log_pattern_response(v_pattern, v_option, now());

    v_streak := fn_calculate_streak(v_pattern);
    RAISE NOTICE 'smoke pattern streak = %', v_streak;
    ASSERT v_streak >= 1, 'streak must be at least 1';
END $$;

-- ---------- 6. Audit log -------------------------------------------------

DO $$
DECLARE v_rows INT;
BEGIN
    SELECT COUNT(*) INTO v_rows FROM audit_log WHERE table_name = 'tasks';
    RAISE NOTICE 'audit_log rows for tasks = %', v_rows;
    ASSERT v_rows >= 2, 'audit_log must contain insert+update for the smoke task';
END $$;

-- ---------- 7. Чистка тестовых данных и материализованное представление --

DELETE FROM pattern_logs
 WHERE pattern_id IN (SELECT id FROM behavior_patterns WHERE title = 'smoke: зарядка');
DELETE FROM pattern_response_options
 WHERE pattern_id IN (SELECT id FROM behavior_patterns WHERE title = 'smoke: зарядка');
DELETE FROM behavior_patterns WHERE title = 'smoke: зарядка';
DELETE FROM diary_entries WHERE user_id = 1 AND entry_date = current_date;
DELETE FROM tasks WHERE title = 'smoke: задача-просрочка';

CALL sp_recalc_calendar_cache();

ROLLBACK;

\echo '=== SMOKE TESTS PASSED ==='
