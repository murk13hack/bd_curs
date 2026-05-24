-- =============================================================================
-- 03 — Таблицы и декларативные констрейнты.
-- 18 таблиц по ТЗ.md (раздел 4.3.1.2, приложение В.2).
-- =============================================================================

-- ---------- 1. users ------------------------------------------------------

CREATE TABLE users (
    id            BIGSERIAL PRIMARY KEY,
    username      TEXT        NOT NULL UNIQUE,
    password_hash TEXT,
    timezone      TEXT        NOT NULL DEFAULT 'Europe/Moscow',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE users IS 'Пользователи системы. В одно-пользовательском режиме — одна запись.';

-- ---------- 2. topics -----------------------------------------------------

CREATE TABLE topics (
    id      BIGSERIAL PRIMARY KEY,
    user_id BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name    TEXT        NOT NULL,
    color   hex_color   NOT NULL DEFAULT '#3B82F6',
    CONSTRAINT topics_user_name_uniq UNIQUE (user_id, name),
    CONSTRAINT topics_name_not_empty CHECK (length(btrim(name)) > 0)
);
COMMENT ON TABLE topics IS 'Темы (категории) задач и паттернов.';

-- ---------- 3. tags -------------------------------------------------------

CREATE TABLE tags (
    id      BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name    TEXT   NOT NULL,
    CONSTRAINT tags_user_name_uniq UNIQUE (user_id, name),
    CONSTRAINT tags_name_not_empty CHECK (length(btrim(name)) > 0)
);
COMMENT ON TABLE tags IS 'Универсальные теги для задач и записей дневника.';

-- ---------- 4. recurring_rules -------------------------------------------

CREATE TABLE recurring_rules (
    id          BIGSERIAL PRIMARY KEY,
    frequency   recurrence_freq_enum NOT NULL,
    params      JSONB                NOT NULL DEFAULT '{}'::jsonb,
    next_run_at TIMESTAMPTZ,
    is_active   BOOLEAN              NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ          NOT NULL DEFAULT now()
);
COMMENT ON TABLE recurring_rules IS 'Правила повторения задач. params — JSONB с полями weekly_mask, monthly_day, custom_cron и т.д.';

-- ---------- 5. tasks ------------------------------------------------------

CREATE TABLE tasks (
    id                BIGSERIAL PRIMARY KEY,
    user_id           BIGINT             NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    topic_id          BIGINT             NOT NULL REFERENCES topics(id) ON DELETE RESTRICT,
    parent_task_id    BIGINT REFERENCES tasks(id)             ON DELETE SET NULL,
    recurring_rule_id BIGINT REFERENCES recurring_rules(id)   ON DELETE SET NULL,
    title             TEXT               NOT NULL,
    description       TEXT,
    status            task_status_enum   NOT NULL DEFAULT 'pending',
    priority          task_priority_enum NOT NULL DEFAULT 'medium',
    start_at          TIMESTAMPTZ,
    deadline          TIMESTAMPTZ,
    planned_minutes   positive_int,
    completed_at      TIMESTAMPTZ,
    is_archived       BOOLEAN            NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ        NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ        NOT NULL DEFAULT now(),
    CONSTRAINT tasks_title_not_empty CHECK (length(btrim(title)) > 0),
    CONSTRAINT tasks_deadline_after_created CHECK (deadline IS NULL OR deadline > created_at),
    CONSTRAINT tasks_start_before_deadline CHECK (
        start_at IS NULL OR deadline IS NULL OR start_at < deadline
    ),
    CONSTRAINT tasks_start_after_created CHECK (start_at IS NULL OR start_at >= created_at),
    CONSTRAINT tasks_completed_after_created CHECK (completed_at IS NULL OR completed_at >= created_at),
    CONSTRAINT tasks_no_self_parent CHECK (parent_task_id IS NULL OR parent_task_id <> id)
);
COMMENT ON TABLE tasks IS 'Задачи. Поддерживается иерархия (parent_task_id) и привязка к правилу повторения.';
COMMENT ON COLUMN tasks.start_at IS 'Не раньше какого момента задачу имеет смысл начинать (начало окна выполнения).';
COMMENT ON COLUMN tasks.deadline IS 'Крайний срок окончания (конец окна выполнения).';
COMMENT ON COLUMN tasks.planned_minutes IS 'Плановая оценка трудозатрат в минутах, не длительность интервала start_at–deadline.';

-- ---------- 6. task_tags --------------------------------------------------

CREATE TABLE task_tags (
    task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    tag_id  BIGINT NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
    PRIMARY KEY (task_id, tag_id)
);
COMMENT ON TABLE task_tags IS 'Связка M:N задача-тег.';

-- ---------- 7. task_time_logs --------------------------------------------

CREATE TABLE task_time_logs (
    id               BIGSERIAL PRIMARY KEY,
    task_id          BIGINT      NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id          BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    started_at       TIMESTAMPTZ NOT NULL,
    ended_at         TIMESTAMPTZ NOT NULL,
    duration_seconds INTEGER GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (ended_at - started_at))::INT
    ) STORED,
    is_pomodoro      BOOLEAN     NOT NULL DEFAULT FALSE,
    note             TEXT,
    CONSTRAINT task_time_logs_ended_after_started CHECK (ended_at > started_at),
    CONSTRAINT task_time_logs_no_overlap EXCLUDE USING gist (
        user_id WITH =,
        tstzrange(started_at, ended_at, '[)') WITH &&
    )
);
COMMENT ON TABLE task_time_logs IS 'Журнал отрезков времени по задачам. Exclusion-констрейнт исключает наложения интервалов.';

-- ---------- 8. diary_entries ---------------------------------------------

CREATE TABLE diary_entries (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entry_date  DATE        NOT NULL,
    content     TEXT        NOT NULL,
    content_tsv TSVECTOR,
    mood        mood_score,
    energy      mood_score,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT diary_entries_user_date_uniq UNIQUE (user_id, entry_date),
    CONSTRAINT diary_entries_content_not_empty CHECK (length(btrim(content)) > 0)
);
COMMENT ON TABLE diary_entries IS 'Записи дневника, одна запись в день на пользователя. content_tsv обновляется триггером.';

-- ---------- 9. diary_tags -------------------------------------------------

CREATE TABLE diary_tags (
    entry_id BIGINT NOT NULL REFERENCES diary_entries(id) ON DELETE CASCADE,
    tag_id   BIGINT NOT NULL REFERENCES tags(id)          ON DELETE CASCADE,
    PRIMARY KEY (entry_id, tag_id)
);
COMMENT ON TABLE diary_tags IS 'Связка M:N запись дневника — тег.';

-- ---------- 10. behavior_patterns ----------------------------------------

CREATE TABLE behavior_patterns (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT             NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    topic_id         BIGINT REFERENCES topics(id) ON DELETE RESTRICT,
    title            TEXT               NOT NULL,
    description      TEXT,
    pattern_type     pattern_type_enum  NOT NULL DEFAULT 'positive',
    is_boolean       BOOLEAN            NOT NULL DEFAULT FALSE,
    auto_create_task BOOLEAN            NOT NULL DEFAULT FALSE,
    pattern_mode     pattern_mode_enum NOT NULL DEFAULT 'habit',
    guide_intro      TEXT,
    created_at       TIMESTAMPTZ        NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ        NOT NULL DEFAULT now(),
    CONSTRAINT behavior_patterns_title_not_empty CHECK (length(btrim(title)) > 0)
);
COMMENT ON TABLE behavior_patterns IS 'Паттерны поведения. is_boolean=true — два варианта Y/N (создаются автоматически).';

-- ---------- 11. pattern_response_options ---------------------------------

CREATE TABLE pattern_response_options (
    id         BIGSERIAL PRIMARY KEY,
    pattern_id BIGINT  NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    label      TEXT    NOT NULL,
    is_success BOOLEAN NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT pattern_response_options_label_not_empty CHECK (length(btrim(label)) > 0)
);
COMMENT ON TABLE pattern_response_options IS 'Варианты ответа на паттерн. is_success — учитывается ли ответ как успешный.';

-- ---------- 12. pattern_schedules ----------------------------------------

CREATE TABLE pattern_schedules (
    id           BIGSERIAL PRIMARY KEY,
    pattern_id   BIGINT   NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    time_of_day  TIME     NOT NULL,
    dow_mask     SMALLINT NOT NULL DEFAULT 127,
    day_of_month SMALLINT,
    CONSTRAINT pattern_schedules_dow_mask_valid CHECK (dow_mask BETWEEN 0 AND 127),
    CONSTRAINT pattern_schedules_dom_valid     CHECK (day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31)
);
COMMENT ON TABLE pattern_schedules  IS 'Расписания уведомлений по паттернам.';
COMMENT ON COLUMN pattern_schedules.dow_mask IS 'Битовая маска дней недели: 1=Mon, 2=Tue, 4=Wed, 8=Thu, 16=Fri, 32=Sat, 64=Sun. 127 = ежедневно.';

-- ---------- 13. pattern_logs ---------------------------------------------

CREATE TABLE pattern_logs (
    id                  BIGSERIAL PRIMARY KEY,
    pattern_id          BIGINT NOT NULL REFERENCES behavior_patterns(id)        ON DELETE CASCADE,
    response_option_id  BIGINT          REFERENCES pattern_response_options(id) ON DELETE SET NULL,
    scheduled_at        TIMESTAMPTZ NOT NULL,
    answered_at         TIMESTAMPTZ,
    status              pattern_log_status_enum NOT NULL DEFAULT 'pending',
    CONSTRAINT pattern_logs_answered_consistency CHECK (
        (status = 'answered' AND response_option_id IS NOT NULL AND answered_at IS NOT NULL)
        OR status <> 'answered'
    )
);
COMMENT ON TABLE pattern_logs IS 'Журнал откликов по паттернам (режим habit).';

-- ---------- 13a. pattern_steps (scenario) --------------------------------

CREATE TABLE pattern_steps (
    id            BIGSERIAL PRIMARY KEY,
    pattern_id    BIGINT NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    sort_order    INTEGER NOT NULL DEFAULT 0,
    title         TEXT NOT NULL,
    hint          TEXT,
    step_kind     pattern_step_kind_enum NOT NULL DEFAULT 'single_choice',
    step_role     pattern_step_role_enum NOT NULL DEFAULT 'context',
    is_required   BOOLEAN NOT NULL DEFAULT TRUE,
    marks_success BOOLEAN NOT NULL DEFAULT FALSE,
    choices       JSONB NOT NULL DEFAULT '[]'::jsonb,
    CONSTRAINT pattern_steps_title_not_empty CHECK (length(btrim(title)) > 0)
);
COMMENT ON TABLE pattern_steps IS 'Шаги сценария (режим scenario). choices: [{id,label,is_success}]';

-- ---------- 13b. pattern_day_sessions ------------------------------------

CREATE TABLE pattern_day_sessions (
    id              BIGSERIAL PRIMARY KEY,
    pattern_id      BIGINT NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    session_date    DATE NOT NULL,
    status          pattern_session_status_enum NOT NULL DEFAULT 'in_progress',
    outcome_success BOOLEAN,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    CONSTRAINT pattern_day_sessions_uniq UNIQUE (pattern_id, session_date)
);
COMMENT ON TABLE pattern_day_sessions IS 'Сессия прохождения сценария за календарный день.';

-- ---------- 13c. pattern_step_answers ------------------------------------

CREATE TABLE pattern_step_answers (
    id          BIGSERIAL PRIMARY KEY,
    session_id  BIGINT NOT NULL REFERENCES pattern_day_sessions(id) ON DELETE CASCADE,
    step_id     BIGINT NOT NULL REFERENCES pattern_steps(id) ON DELETE CASCADE,
    choice_id   TEXT,
    checked     BOOLEAN,
    note_text   TEXT,
    answered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pattern_step_answers_uniq UNIQUE (session_id, step_id)
);
COMMENT ON TABLE pattern_step_answers IS 'Ответы на шаги сценария в рамках сессии.';

-- ---------- 13d. pattern_markers (markers mode) --------------------------

CREATE TABLE pattern_markers (
    id               BIGSERIAL PRIMARY KEY,
    pattern_id       BIGINT      NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    marker_option_id BIGINT      NOT NULL REFERENCES pattern_response_options(id) ON DELETE CASCADE,
    occurred_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    note             TEXT
);
CREATE INDEX idx_pattern_markers_pattern_occurred ON pattern_markers (pattern_id, occurred_at DESC);
COMMENT ON TABLE pattern_markers IS 'Точечные отметки эпизодов (режим markers). Много записей в день.';

-- ---------- 14. goals -----------------------------------------------------

CREATE TABLE goals (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title        TEXT         NOT NULL,
    description  TEXT,
    deadline     DATE,
    target_value positive_int NOT NULL DEFAULT 1,
    is_completed BOOLEAN      NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT goals_title_not_empty CHECK (length(btrim(title)) > 0),
    CONSTRAINT goals_completed_consistency CHECK (
        (is_completed = TRUE  AND completed_at IS NOT NULL) OR
        (is_completed = FALSE AND completed_at IS NULL)
    )
);
COMMENT ON TABLE goals IS 'Долгосрочные цели.';

-- ---------- 15. goal_links -----------------------------------------------

CREATE TABLE goal_links (
    goal_id     BIGINT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    target_type TEXT   NOT NULL CHECK (target_type IN ('task','pattern')),
    target_id   BIGINT NOT NULL,
    PRIMARY KEY (goal_id, target_type, target_id)
);
COMMENT ON TABLE goal_links IS 'Привязка цели к задачам/паттернам. target_type определяет, в какую таблицу смотрит target_id.';

-- ---------- 16. holidays --------------------------------------------------

CREATE TABLE holidays (
    id           BIGSERIAL PRIMARY KEY,
    holiday_date DATE NOT NULL UNIQUE,
    name         TEXT NOT NULL,
    is_official  BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT holidays_name_not_empty CHECK (length(btrim(name)) > 0)
);
COMMENT ON TABLE holidays IS 'Государственные и пользовательские праздники. is_official=false — собственные памятные даты.';

-- ---------- 17. audit_log -------------------------------------------------

CREATE TABLE audit_log (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT REFERENCES users(id) ON DELETE SET NULL,
    table_name TEXT  NOT NULL,
    row_id     BIGINT,
    action     audit_action_enum NOT NULL,
    diff       JSONB,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE audit_log IS 'Журнал изменений ключевых таблиц. Заполняется триггером trg_audit_changes.';

-- ---------- 18. app_settings ---------------------------------------------

CREATE TABLE app_settings (
    id      BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key     TEXT   NOT NULL,
    value   JSONB  NOT NULL,
    CONSTRAINT app_settings_user_key_uniq UNIQUE (user_id, key),
    CONSTRAINT app_settings_key_not_empty CHECK (length(btrim(key)) > 0)
);
COMMENT ON TABLE app_settings IS 'Пользовательские настройки в виде key/value.';

DO $$
BEGIN
    RAISE NOTICE 'PTT 03-tables: 18 tables created';
END $$;
