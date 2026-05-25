-- =============================================================================
-- 02 — Пользовательские типы данных: перечисления (ENUM) и доменные (DOMAIN).
-- См. ТЗ.md, раздел 4.3.1.3.
-- =============================================================================

-- ---------- ENUM ----------------------------------------------------------

CREATE TYPE task_status_enum AS ENUM (
    'pending',      -- запланирована, не начата
    'in_progress',  -- в работе
    'done',         -- успешно завершена
    'overdue',      -- просрочена (выставляется триггером trg_task_overdue_check)
    'cancelled'     -- отменена пользователем
);
COMMENT ON TYPE task_status_enum IS 'Статус задачи. Переходы: pending → in_progress → done; pending → cancelled; done → overdue (триггер).';

CREATE TYPE task_priority_enum AS ENUM (
    'low',
    'medium',
    'high',
    'urgent'
);
COMMENT ON TYPE task_priority_enum IS 'Приоритет задачи.';

CREATE TYPE pattern_type_enum AS ENUM (
    'positive',  -- формирование привычки (зарядка, чтение, ...)
    'negative'   -- отказ от привычки (курение, соц. сети, ...)
);
COMMENT ON TYPE pattern_type_enum IS 'Тип паттерна поведения.';

CREATE TYPE pattern_log_status_enum AS ENUM (
    'pending',   -- ожидаем ответа пользователя
    'answered',  -- ответ получен
    'missed'     -- пропущен (закрыт sp_close_overdue_pattern_logs)
);
COMMENT ON TYPE pattern_log_status_enum IS 'Статус записи журнала откликов на паттерн.';

CREATE TYPE pattern_mode_enum AS ENUM (
    'habit',     -- быстрый чеклист (сделал / удержался)
    'scenario',  -- пошаговый сценарий дня
    'markers'    -- точечные отметки (P3)
);
COMMENT ON TYPE pattern_mode_enum IS 'Режим паттерна поведения.';

CREATE TYPE pattern_step_kind_enum AS ENUM (
    'check', 'single_choice', 'note'
);
COMMENT ON TYPE pattern_step_kind_enum IS 'Тип шага сценария.';

CREATE TYPE pattern_step_role_enum AS ENUM (
    'context', 'trigger', 'choice', 'action', 'outcome'
);
COMMENT ON TYPE pattern_step_role_enum IS 'Роль шага в сценарии (для аналитики).';

CREATE TYPE pattern_session_status_enum AS ENUM (
    'in_progress', 'completed', 'abandoned'
);
COMMENT ON TYPE pattern_session_status_enum IS 'Статус прохождения сценария за день.';

CREATE TYPE recurrence_freq_enum AS ENUM (
    'daily',
    'weekly',
    'monthly',
    'custom'
);
COMMENT ON TYPE recurrence_freq_enum IS 'Частота повторения. custom: params.interval_days (каждые N дней, N>=1).';

CREATE TYPE audit_action_enum AS ENUM (
    'insert',
    'update',
    'delete'
);
COMMENT ON TYPE audit_action_enum IS 'Действие в журнале аудита.';

-- ---------- DOMAIN --------------------------------------------------------

CREATE DOMAIN mood_score AS SMALLINT
    CHECK (VALUE IS NULL OR (VALUE BETWEEN 1 AND 5));
COMMENT ON DOMAIN mood_score IS 'Шкала 1..5 для настроения и уровня энергии.';

CREATE DOMAIN percentage AS NUMERIC(5,2)
    CHECK (VALUE IS NULL OR (VALUE BETWEEN 0 AND 100));
COMMENT ON DOMAIN percentage IS 'Процентное значение в диапазоне 0..100.';

CREATE DOMAIN positive_int AS INTEGER
    CHECK (VALUE IS NULL OR VALUE > 0);
COMMENT ON DOMAIN positive_int IS 'Строго положительное целое число.';

CREATE DOMAIN hex_color AS CHAR(7)
    CHECK (VALUE ~ '^#[0-9A-Fa-f]{6}$');
COMMENT ON DOMAIN hex_color IS 'HEX-цвет в формате #RRGGBB.';

DO $$
BEGIN
    RAISE NOTICE 'PTT 02-types: 6 ENUM + 4 DOMAIN created';
END $$;
