-- Разрешить планировать start_at раньше created_at.
-- Иначе задача с "Начать не раньше: 00:02" может падать,
-- если создана в 00:02:35 (секунды в created_at > секунд в start_at).
ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_start_after_created;

