-- Миграция для существующих БД (volume уже инициализирован).
-- Применение: docker exec -i ptt-db psql -U ptt -d ptt -f /tmp/001_add_task_start_at.sql

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS start_at TIMESTAMPTZ;

ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_start_before_deadline;
ALTER TABLE tasks ADD CONSTRAINT tasks_start_before_deadline CHECK (
    start_at IS NULL OR deadline IS NULL OR start_at < deadline
);

ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_start_after_created;
ALTER TABLE tasks ADD CONSTRAINT tasks_start_after_created CHECK (
    start_at IS NULL OR start_at >= created_at
);

COMMENT ON COLUMN tasks.start_at IS 'Не раньше какого момента задачу имеет смысл начинать (начало окна выполнения).';
COMMENT ON COLUMN tasks.deadline IS 'Крайний срок окончания (конец окна выполнения).';
COMMENT ON COLUMN tasks.planned_minutes IS 'Плановая оценка трудозатрат в минутах, не длительность интервала start_at–deadline.';

CREATE INDEX IF NOT EXISTS idx_tasks_start_at ON tasks (start_at) WHERE start_at IS NOT NULL;

CREATE OR REPLACE PROCEDURE sp_reopen_task(p_task_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE tasks
       SET status       = 'in_progress',
           completed_at = NULL,
           updated_at   = now()
     WHERE id = p_task_id
       AND status IN ('done', 'overdue');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'sp_reopen_task: задача % не найдена или не в статусе done/overdue', p_task_id;
    END IF;
END;
$$;
