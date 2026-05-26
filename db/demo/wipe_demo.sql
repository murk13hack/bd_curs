-- =============================================================================
-- Удаление демонстрационного набора данных ПТТ.
-- Удаляются только сущности, зарегистрированные в app_settings._demo_dataset.
-- Базовый seed (09-seed.sql: темы «Работа», теги, праздники РФ) не затрагивается.
--
-- Запуск: scripts/demo-data.ps1 wipe  |  scripts/demo-data.sh wipe
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_reg   JSONB;
    v_cnt   INT;
BEGIN
    SELECT value INTO v_reg
      FROM app_settings
     WHERE user_id = 1 AND key = '_demo_dataset';

    IF v_reg IS NULL THEN
        RAISE NOTICE 'Демо-данные не загружены (ключ _demo_dataset отсутствует). Нечего удалять.';
        RETURN;
    END IF;

    RAISE NOTICE 'Удаление демо-набора v% от %...',
        v_reg->>'version', v_reg->>'loaded_at';

    -- Сессии сценариев (ответы удалятся CASCADE)
    DELETE FROM pattern_day_sessions
     WHERE id IN (
         SELECT (jsonb_array_elements_text(v_reg->'pattern_day_sessions'))::BIGINT
     );
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    RAISE NOTICE '  pattern_day_sessions: %', v_cnt;

    -- Журнал времени по демо-задачам
    DELETE FROM task_time_logs
     WHERE task_id IN (
         SELECT (jsonb_array_elements_text(v_reg->'tasks'))::BIGINT
     );
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    RAISE NOTICE '  task_time_logs: %', v_cnt;

    -- Подзадачи, затем родительские (FK parent_task_id SET NULL, но порядок безопаснее)
    DELETE FROM tasks
     WHERE id IN (
         SELECT (jsonb_array_elements_text(v_reg->'tasks'))::BIGINT
     )
       AND parent_task_id IS NOT NULL;
    DELETE FROM tasks
     WHERE id IN (
         SELECT (jsonb_array_elements_text(v_reg->'tasks'))::BIGINT
     );
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    RAISE NOTICE '  tasks: %', v_cnt;

    -- Правила повторения (задачи уже удалены)
    DELETE FROM recurring_rules
     WHERE id IN (
         SELECT (jsonb_array_elements_text(v_reg->'recurring_rules'))::BIGINT
     );
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    RAISE NOTICE '  recurring_rules: %', v_cnt;

    -- Паттерны (logs, steps, markers, closures, options, schedules — CASCADE)
    DELETE FROM behavior_patterns
     WHERE id IN (
         SELECT (jsonb_array_elements_text(v_reg->'behavior_patterns'))::BIGINT
     );
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    RAISE NOTICE '  behavior_patterns: %', v_cnt;

    -- Дневник (diary_tags CASCADE)
    DELETE FROM diary_entries
     WHERE id IN (
         SELECT (jsonb_array_elements_text(v_reg->'diary_entries'))::BIGINT
     );
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    RAISE NOTICE '  diary_entries: %', v_cnt;

    -- Цели (goal_links CASCADE)
    DELETE FROM goals
     WHERE id IN (
         SELECT (jsonb_array_elements_text(v_reg->'goals'))::BIGINT
     );
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    RAISE NOTICE '  goals: %', v_cnt;

    -- Демо-теги и темы
    DELETE FROM tags
     WHERE id IN (
         SELECT (jsonb_array_elements_text(v_reg->'tags'))::BIGINT
     );
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    RAISE NOTICE '  tags: %', v_cnt;

    DELETE FROM topics
     WHERE id IN (
         SELECT (jsonb_array_elements_text(v_reg->'topics'))::BIGINT
     );
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    RAISE NOTICE '  topics: %', v_cnt;

    -- Пользовательские (неофициальные) праздники
    DELETE FROM holidays
     WHERE id IN (
         SELECT (jsonb_array_elements_text(v_reg->'holidays'))::BIGINT
     );
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    RAISE NOTICE '  holidays: %', v_cnt;

    DELETE FROM app_settings WHERE user_id = 1 AND key = '_demo_dataset';

    RAISE NOTICE 'Демо-набор удалён.';
END $$;

CALL sp_recalc_calendar_cache();

COMMIT;

\echo '=== DEMO DATA WIPED ==='
