-- Разрешить пересекающиеся интервалы учёта времени (разные задачи, параллельный фокус).
ALTER TABLE task_time_logs DROP CONSTRAINT IF EXISTS task_time_logs_no_overlap;

COMMENT ON TABLE task_time_logs IS
  'Журнал отрезков времени по задачам. Пересечения интервалов у одного пользователя допустимы.';
