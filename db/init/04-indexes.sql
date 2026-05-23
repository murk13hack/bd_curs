-- =============================================================================
-- 04 — Индексы.
-- См. ТЗ.md, раздел 4.3.1.5.
-- Типы индексов: B-tree, составные, partial, GIN (FTS), BRIN (журналы).
-- =============================================================================

-- ---------- tasks ---------------------------------------------------------

CREATE INDEX idx_tasks_deadline
    ON tasks (deadline)
    WHERE deadline IS NOT NULL;
COMMENT ON INDEX idx_tasks_deadline IS 'Сортировка/фильтр «ближайшие задачи».';

CREATE INDEX idx_tasks_topic_status
    ON tasks (topic_id, status);
COMMENT ON INDEX idx_tasks_topic_status IS 'Группировка задач по темам с фильтром по статусу.';

CREATE INDEX idx_tasks_user_completed_at
    ON tasks (user_id, completed_at)
    WHERE completed_at IS NOT NULL;
COMMENT ON INDEX idx_tasks_user_completed_at IS 'Календарь и расчёт серий выполнения.';

CREATE INDEX idx_tasks_overdue_partial
    ON tasks (deadline)
    WHERE status = 'overdue';
COMMENT ON INDEX idx_tasks_overdue_partial IS 'Узкая выборка просроченных задач.';

CREATE INDEX idx_tasks_parent
    ON tasks (parent_task_id)
    WHERE parent_task_id IS NOT NULL;
COMMENT ON INDEX idx_tasks_parent IS 'Поиск подзадач по родителю (рекурсивный CTE в v_task_subtree_progress).';

CREATE INDEX idx_tasks_recurring
    ON tasks (recurring_rule_id)
    WHERE recurring_rule_id IS NOT NULL;
COMMENT ON INDEX idx_tasks_recurring IS 'Поиск экземпляров повторяющейся задачи.';

CREATE INDEX idx_tasks_search_gin
    ON tasks
    USING gin (to_tsvector('russian', coalesce(title, '') || ' ' || coalesce(description, '')));
COMMENT ON INDEX idx_tasks_search_gin IS 'Полнотекстовый поиск по задачам (русский словарь).';

-- ---------- task_tags / task_time_logs -----------------------------------

CREATE INDEX idx_task_tags_tag
    ON task_tags (tag_id, task_id);
COMMENT ON INDEX idx_task_tags_tag IS 'Поиск задач по тегу.';

CREATE INDEX idx_task_time_logs_task
    ON task_time_logs (task_id, started_at DESC);
COMMENT ON INDEX idx_task_time_logs_task IS 'Журнал времени по задаче в обратном хронологическом порядке.';

-- ---------- diary_entries / diary_tags -----------------------------------

CREATE INDEX idx_diary_fts_gin
    ON diary_entries USING gin (content_tsv);
COMMENT ON INDEX idx_diary_fts_gin IS 'Полнотекстовый поиск по дневнику.';

CREATE INDEX idx_diary_tags_tag
    ON diary_tags (tag_id, entry_id);
COMMENT ON INDEX idx_diary_tags_tag IS 'Поиск записей дневника по тегу.';

-- ---------- pattern_logs -------------------------------------------------

CREATE INDEX idx_pattern_logs_brin
    ON pattern_logs USING brin (scheduled_at);
COMMENT ON INDEX idx_pattern_logs_brin IS 'BRIN-индекс для большой таблицы журнала по времени (растёт последовательно).';

CREATE INDEX idx_pattern_logs_pattern_date
    ON pattern_logs (pattern_id, scheduled_at DESC);
COMMENT ON INDEX idx_pattern_logs_pattern_date IS 'Расчёт текущей серии (выборка последних N).';

CREATE INDEX idx_pattern_logs_pending
    ON pattern_logs (scheduled_at)
    WHERE status = 'pending';
COMMENT ON INDEX idx_pattern_logs_pending IS 'Быстрый поиск ожидающих ответа записей (для sp_close_overdue_pattern_logs).';

-- ---------- audit_log ----------------------------------------------------

CREATE INDEX idx_audit_log_brin
    ON audit_log USING brin (changed_at);
COMMENT ON INDEX idx_audit_log_brin IS 'BRIN-индекс для большого журнала аудита.';

CREATE INDEX idx_audit_log_table_row
    ON audit_log (table_name, row_id);
COMMENT ON INDEX idx_audit_log_table_row IS 'Поиск истории изменений конкретной строки.';

-- ---------- goals --------------------------------------------------------

CREATE INDEX idx_goals_deadline_active
    ON goals (deadline)
    WHERE is_completed = FALSE;
COMMENT ON INDEX idx_goals_deadline_active IS 'Список активных целей.';

-- ---------- recurring_rules ----------------------------------------------

CREATE INDEX idx_recurring_rules_next_run
    ON recurring_rules (next_run_at)
    WHERE is_active = TRUE;
COMMENT ON INDEX idx_recurring_rules_next_run IS 'Планировщик повторяющихся задач.';

-- ---------- триграммные индексы для нечёткого поиска по справочникам -----

CREATE INDEX idx_topics_name_trgm
    ON topics USING gin (name gin_trgm_ops);
COMMENT ON INDEX idx_topics_name_trgm IS 'Нечёткий поиск тем (autocomplete).';

CREATE INDEX idx_tags_name_trgm
    ON tags USING gin (name gin_trgm_ops);
COMMENT ON INDEX idx_tags_name_trgm IS 'Нечёткий поиск тегов.';

DO $$
BEGIN
    RAISE NOTICE 'PTT 04-indexes: indexes created';
END $$;
