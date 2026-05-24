-- P0+P1: habit metrics fix, pattern_mode, scenario steps/sessions.
-- docker cp db/migrations/002_patterns_v1.sql ptt-db:/tmp/ && docker exec ptt-db psql -U ptt -d ptt -f /tmp/002_patterns_v1.sql

-- ---------- types ----------
DO $$ BEGIN
    CREATE TYPE pattern_mode_enum AS ENUM ('habit', 'scenario', 'markers');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE pattern_step_kind_enum AS ENUM ('check', 'single_choice', 'note');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE pattern_step_role_enum AS ENUM ('context', 'trigger', 'choice', 'action', 'outcome');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE pattern_session_status_enum AS ENUM ('in_progress', 'completed', 'abandoned');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------- behavior_patterns extensions ----------
ALTER TABLE behavior_patterns
    ADD COLUMN IF NOT EXISTS pattern_mode pattern_mode_enum NOT NULL DEFAULT 'habit';

ALTER TABLE behavior_patterns
    ADD COLUMN IF NOT EXISTS guide_intro TEXT;

-- ---------- scenario tables ----------
CREATE TABLE IF NOT EXISTS pattern_steps (
    id           BIGSERIAL PRIMARY KEY,
    pattern_id   BIGINT NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    sort_order   INTEGER NOT NULL DEFAULT 0,
    title        TEXT NOT NULL,
    hint         TEXT,
    step_kind    pattern_step_kind_enum NOT NULL DEFAULT 'single_choice',
    step_role    pattern_step_role_enum NOT NULL DEFAULT 'context',
    is_required  BOOLEAN NOT NULL DEFAULT TRUE,
    marks_success BOOLEAN NOT NULL DEFAULT FALSE,
    choices      JSONB NOT NULL DEFAULT '[]'::jsonb,
    CONSTRAINT pattern_steps_title_not_empty CHECK (length(btrim(title)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_pattern_steps_pattern ON pattern_steps (pattern_id, sort_order);

CREATE TABLE IF NOT EXISTS pattern_day_sessions (
    id              BIGSERIAL PRIMARY KEY,
    pattern_id      BIGINT NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    session_date    DATE NOT NULL,
    status          pattern_session_status_enum NOT NULL DEFAULT 'in_progress',
    outcome_success BOOLEAN,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    CONSTRAINT pattern_day_sessions_uniq UNIQUE (pattern_id, session_date)
);

CREATE TABLE IF NOT EXISTS pattern_step_answers (
    id           BIGSERIAL PRIMARY KEY,
    session_id   BIGINT NOT NULL REFERENCES pattern_day_sessions(id) ON DELETE CASCADE,
    step_id      BIGINT NOT NULL REFERENCES pattern_steps(id) ON DELETE CASCADE,
    choice_id    TEXT,
    checked      BOOLEAN,
    note_text    TEXT,
    answered_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pattern_step_answers_uniq UNIQUE (session_id, step_id)
);

-- ---------- helpers ----------
CREATE OR REPLACE FUNCTION fn_pattern_is_scheduled(p_pattern_id BIGINT, p_day DATE)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_cnt INT;
    v_dow_bit INT;
BEGIN
    SELECT COUNT(*)::INT INTO v_cnt FROM pattern_schedules WHERE pattern_id = p_pattern_id;
    IF v_cnt = 0 THEN
        RETURN TRUE;
    END IF;
    v_dow_bit := 1 << (EXTRACT(ISODOW FROM p_day)::INT - 1);
    RETURN EXISTS (
        SELECT 1 FROM pattern_schedules s
         WHERE s.pattern_id = p_pattern_id
           AND (s.dow_mask & v_dow_bit) > 0
           AND (s.day_of_month IS NULL OR s.day_of_month = EXTRACT(DAY FROM p_day)::INT)
    );
END;
$$;

CREATE OR REPLACE FUNCTION fn_pattern_day_has_answer(p_pattern_id BIGINT, p_day DATE)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_mode pattern_mode_enum;
BEGIN
    SELECT pattern_mode INTO v_mode FROM behavior_patterns WHERE id = p_pattern_id;
    IF v_mode = 'scenario' THEN
        RETURN EXISTS (
            SELECT 1 FROM pattern_day_sessions s
             WHERE s.pattern_id = p_pattern_id AND s.session_date = p_day
               AND s.status IN ('in_progress', 'completed')
        );
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM pattern_logs pl
         WHERE pl.pattern_id = p_pattern_id
           AND date_trunc('day', pl.scheduled_at)::date = p_day
           AND pl.status = 'answered'
    );
END;
$$;

CREATE OR REPLACE FUNCTION fn_pattern_day_success(p_pattern_id BIGINT, p_day DATE)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_mode pattern_mode_enum;
    v_ok   BOOLEAN;
BEGIN
    SELECT pattern_mode INTO v_mode FROM behavior_patterns WHERE id = p_pattern_id;
    IF v_mode = 'scenario' THEN
        SELECT outcome_success INTO v_ok
          FROM pattern_day_sessions
         WHERE pattern_id = p_pattern_id
           AND session_date = p_day
           AND status = 'completed';
        RETURN COALESCE(v_ok, FALSE);
    END IF;
    SELECT bool_or(
               pl.status = 'answered'
               AND COALESCE(
                   (SELECT is_success FROM pattern_response_options o
                     WHERE o.id = pl.response_option_id),
                   FALSE
               )
           )
      INTO v_ok
      FROM pattern_logs pl
     WHERE pl.pattern_id = p_pattern_id
       AND date_trunc('day', pl.scheduled_at)::date = p_day;
    RETURN COALESCE(v_ok, FALSE);
END;
$$;

-- ---------- streak (P0 fix: no NOT for negative) ----------
CREATE OR REPLACE FUNCTION fn_calculate_streak(p_pattern_id BIGINT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_streak INT := 0;
    v_day    DATE := current_date;
    v_sched  BOOLEAN;
    v_answer BOOLEAN;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM behavior_patterns WHERE id = p_pattern_id) THEN
        RETURN 0;
    END IF;

    LOOP
        v_sched := fn_pattern_is_scheduled(p_pattern_id, v_day);
        IF NOT v_sched THEN
            v_day := v_day - 1;
            IF v_day < current_date - 3650 THEN EXIT; END IF;
            CONTINUE;
        END IF;

        v_answer := fn_pattern_day_has_answer(p_pattern_id, v_day);
        IF NOT v_answer THEN
            IF v_day = current_date THEN
                v_day := v_day - 1;
                CONTINUE;
            ELSE
                EXIT;
            END IF;
        END IF;

        IF fn_pattern_day_success(p_pattern_id, v_day) THEN
            v_streak := v_streak + 1;
            v_day := v_day - 1;
        ELSE
            EXIT;
        END IF;

        IF v_day < current_date - 3650 THEN EXIT; END IF;
    END LOOP;

    RETURN v_streak;
END;
$$;

CREATE OR REPLACE FUNCTION fn_calculate_max_streak(p_pattern_id BIGINT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_max INT := 0;
    v_cur INT := 0;
    d     DATE;
    v_end DATE := current_date;
    v_start DATE := current_date - 3650;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM behavior_patterns WHERE id = p_pattern_id) THEN
        RETURN 0;
    END IF;

    d := v_start;
    WHILE d <= v_end LOOP
        IF fn_pattern_is_scheduled(p_pattern_id, d) THEN
            IF fn_pattern_day_has_answer(p_pattern_id, d)
               AND fn_pattern_day_success(p_pattern_id, d) THEN
                v_cur := v_cur + 1;
                IF v_cur > v_max THEN v_max := v_cur; END IF;
            ELSIF fn_pattern_day_has_answer(p_pattern_id, d) OR d < current_date THEN
                v_cur := 0;
            END IF;
        END IF;
        d := d + 1;
    END LOOP;

    RETURN v_max;
END;
$$;

CREATE OR REPLACE FUNCTION fn_pattern_clean_days_30d(p_pattern_id BIGINT)
RETURNS TABLE(scheduled_days INT, success_days INT, clean_rate NUMERIC)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_sched INT := 0;
    v_succ  INT := 0;
    d       DATE;
BEGIN
    d := current_date - 29;
    WHILE d <= current_date LOOP
        IF fn_pattern_is_scheduled(p_pattern_id, d) THEN
            v_sched := v_sched + 1;
            IF fn_pattern_day_has_answer(p_pattern_id, d)
               AND fn_pattern_day_success(p_pattern_id, d) THEN
                v_succ := v_succ + 1;
            END IF;
        END IF;
        d := d + 1;
    END LOOP;

    scheduled_days := v_sched;
    success_days := v_succ;
    clean_rate := CASE WHEN v_sched = 0 THEN 0
                       ELSE ROUND(100.0 * v_succ / v_sched, 2) END;
    RETURN NEXT;
END;
$$;

-- ---------- view ----------
DROP VIEW IF EXISTS v_pattern_streaks;
CREATE VIEW v_pattern_streaks AS
SELECT
    bp.id            AS pattern_id,
    bp.user_id,
    bp.title,
    bp.pattern_type,
    bp.pattern_mode,
    fn_calculate_streak(bp.id)     AS current_streak,
    fn_calculate_max_streak(bp.id) AS max_streak,
    CASE WHEN bp.pattern_type = 'negative'
         THEN fn_calculate_streak(bp.id)
         ELSE 0
    END                            AS anti_streak,
    cd.scheduled_days              AS scheduled_days_30d,
    cd.success_days                AS success_days_30d,
    cd.clean_rate                  AS clean_rate_30d,
    cd.clean_rate                  AS success_rate_30d
  FROM behavior_patterns bp
  CROSS JOIN LATERAL fn_pattern_clean_days_30d(bp.id) cd;

-- ---------- sp_log fix (upsert by day) ----------
CREATE OR REPLACE PROCEDURE sp_log_pattern_response(
    p_pattern_id         BIGINT,
    p_response_option_id BIGINT,
    p_scheduled_at       TIMESTAMPTZ DEFAULT now()
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing_id BIGINT;
    v_day         DATE := date_trunc('day', p_scheduled_at)::date;
BEGIN
    SELECT id INTO v_existing_id
      FROM pattern_logs
     WHERE pattern_id = p_pattern_id
       AND date_trunc('day', scheduled_at)::date = v_day
     ORDER BY id DESC
     LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
        UPDATE pattern_logs
           SET response_option_id = p_response_option_id,
               answered_at        = now(),
               status             = 'answered',
               scheduled_at       = v_day::timestamptz
         WHERE id = v_existing_id;
    ELSE
        INSERT INTO pattern_logs (pattern_id, response_option_id, scheduled_at, answered_at, status)
        VALUES (p_pattern_id, p_response_option_id, v_day::timestamptz, now(), 'answered');
    END IF;
END;
$$;
