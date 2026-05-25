-- Fix habit pending logs, markers empty-day semantics, scenario streak/calendar, anti_streak.

-- ---------- sp_ensure_habit_logs_for_day ---------------------------------

CREATE OR REPLACE PROCEDURE sp_ensure_habit_logs_for_day(p_day DATE DEFAULT current_date)
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_ts TIMESTAMPTZ;
BEGIN
    FOR r IN
        SELECT bp.id AS pattern_id
          FROM behavior_patterns bp
         WHERE bp.pattern_mode = 'habit'
           AND fn_pattern_is_scheduled(bp.id, p_day)
    LOOP
        IF EXISTS (
            SELECT 1 FROM pattern_logs pl
             WHERE pl.pattern_id = r.pattern_id
               AND date_trunc('day', pl.scheduled_at)::date = p_day
        ) THEN
            CONTINUE;
        END IF;

        SELECT (p_day::timestamp + COALESCE(
                    (SELECT min(s.time_of_day)
                       FROM pattern_schedules s
                      WHERE s.pattern_id = r.pattern_id),
                    TIME '12:00:00'
                )) AT TIME ZONE 'UTC'
          INTO v_ts;

        INSERT INTO pattern_logs (pattern_id, scheduled_at, status)
        VALUES (r.pattern_id, v_ts, 'pending');
    END LOOP;
END;
$$;
COMMENT ON PROCEDURE sp_ensure_habit_logs_for_day(DATE)
    IS 'Создать pending-запись habit на день по расписанию (для sp_close_overdue_pattern_logs).';

-- ---------- fn_pattern_day_has_answer / fn_pattern_day_success ------------

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
             WHERE s.pattern_id = p_pattern_id
               AND s.session_date = p_day
               AND s.status = 'completed'
        );
    END IF;
    IF v_mode = 'markers' THEN
        RETURN EXISTS (
            SELECT 1 FROM pattern_markers pm
             WHERE pm.pattern_id = p_pattern_id
               AND pm.occurred_at::date = p_day
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
    IF v_mode = 'markers' THEN
        IF NOT EXISTS (
            SELECT 1 FROM pattern_markers pm
             WHERE pm.pattern_id = p_pattern_id
               AND pm.occurred_at::date = p_day
        ) THEN
            RETURN FALSE;
        END IF;
        RETURN NOT EXISTS (
            SELECT 1
              FROM pattern_markers pm
              JOIN pattern_response_options o ON o.id = pm.marker_option_id
             WHERE pm.pattern_id = p_pattern_id
               AND pm.occurred_at::date = p_day
               AND o.is_success = FALSE
        );
    END IF;
    SELECT bool_or(
               pl.status = 'answered'
               AND COALESCE(
                   (SELECT is_success FROM pattern_response_options o
                     WHERE o.id = pl.response_option_id), FALSE)
           ) INTO v_ok
      FROM pattern_logs pl
     WHERE pl.pattern_id = p_pattern_id
       AND date_trunc('day', pl.scheduled_at)::date = p_day;
    RETURN COALESCE(v_ok, FALSE);
END;
$$;

-- ---------- fn_pattern_day_is_failure (для anti_streak) --------------------

CREATE OR REPLACE FUNCTION fn_pattern_day_is_failure(p_pattern_id BIGINT, p_day DATE)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_mode pattern_mode_enum;
BEGIN
    SELECT pattern_mode INTO v_mode FROM behavior_patterns WHERE id = p_pattern_id;
    IF NOT fn_pattern_is_scheduled(p_pattern_id, p_day) THEN
        RETURN FALSE;
    END IF;
    IF v_mode = 'scenario' THEN
        RETURN EXISTS (
            SELECT 1 FROM pattern_day_sessions s
             WHERE s.pattern_id = p_pattern_id
               AND s.session_date = p_day
               AND s.status = 'completed'
               AND COALESCE(s.outcome_success, FALSE) = FALSE
        );
    END IF;
    IF v_mode = 'markers' THEN
        RETURN EXISTS (
            SELECT 1
              FROM pattern_markers pm
              JOIN pattern_response_options o ON o.id = pm.marker_option_id
             WHERE pm.pattern_id = p_pattern_id
               AND pm.occurred_at::date = p_day
               AND o.is_success = FALSE
        );
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM pattern_logs pl
         WHERE pl.pattern_id = p_pattern_id
           AND date_trunc('day', pl.scheduled_at)::date = p_day
           AND (
               pl.status = 'missed'
               OR (
                   pl.status = 'answered'
                   AND NOT COALESCE(
                       (SELECT is_success FROM pattern_response_options o
                         WHERE o.id = pl.response_option_id),
                       FALSE
                   )
               )
           )
    );
END;
$$;
COMMENT ON FUNCTION fn_pattern_day_is_failure(BIGINT, DATE)
    IS 'День с зафиксированным срывом/пропуском (для anti_streak).';

-- ---------- fn_calculate_streak ------------------------------------------

CREATE OR REPLACE FUNCTION fn_calculate_streak(p_pattern_id BIGINT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_streak INT := 0;
    v_day    DATE := current_date;
    v_mode   pattern_mode_enum;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM behavior_patterns WHERE id = p_pattern_id) THEN
        RETURN 0;
    END IF;
    SELECT pattern_mode INTO v_mode FROM behavior_patterns WHERE id = p_pattern_id;

    LOOP
        IF NOT fn_pattern_is_scheduled(p_pattern_id, v_day) THEN
            v_day := v_day - 1;
            IF v_day < current_date - 3650 THEN EXIT; END IF;
            CONTINUE;
        END IF;

        IF v_mode = 'habit' AND v_day = current_date THEN
            IF EXISTS (
                SELECT 1 FROM pattern_logs pl
                 WHERE pl.pattern_id = p_pattern_id
                   AND date_trunc('day', pl.scheduled_at)::date = v_day
                   AND pl.status = 'pending'
            ) AND NOT EXISTS (
                SELECT 1 FROM pattern_logs pl
                 WHERE pl.pattern_id = p_pattern_id
                   AND date_trunc('day', pl.scheduled_at)::date = v_day
                   AND pl.status = 'answered'
            ) THEN
                v_day := v_day - 1;
                IF v_day < current_date - 3650 THEN EXIT; END IF;
                CONTINUE;
            END IF;
        END IF;

        IF v_mode = 'scenario' AND v_day = current_date THEN
            IF EXISTS (
                SELECT 1 FROM pattern_day_sessions s
                 WHERE s.pattern_id = p_pattern_id
                   AND s.session_date = v_day
                   AND s.status = 'in_progress'
            ) AND NOT EXISTS (
                SELECT 1 FROM pattern_day_sessions s
                 WHERE s.pattern_id = p_pattern_id
                   AND s.session_date = v_day
                   AND s.status = 'completed'
            ) THEN
                v_day := v_day - 1;
                IF v_day < current_date - 3650 THEN EXIT; END IF;
                CONTINUE;
            END IF;
        END IF;

        IF v_mode <> 'markers' THEN
            IF NOT fn_pattern_day_has_answer(p_pattern_id, v_day) THEN
                IF v_day = current_date THEN
                    v_day := v_day - 1;
                    CONTINUE;
                ELSE
                    EXIT;
                END IF;
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

-- ---------- fn_calculate_anti_streak ---------------------------------------

CREATE OR REPLACE FUNCTION fn_calculate_anti_streak(p_pattern_id BIGINT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_type pattern_type_enum;
    v_streak INT := 0;
    v_day    DATE := current_date;
BEGIN
    SELECT pattern_type INTO v_type FROM behavior_patterns WHERE id = p_pattern_id;
    IF v_type IS NULL OR v_type <> 'negative' THEN
        RETURN 0;
    END IF;

    LOOP
        IF NOT fn_pattern_is_scheduled(p_pattern_id, v_day) THEN
            v_day := v_day - 1;
            IF v_day < current_date - 3650 THEN EXIT; END IF;
            CONTINUE;
        END IF;

        IF v_day = current_date AND NOT fn_pattern_day_is_failure(p_pattern_id, v_day) THEN
            v_day := v_day - 1;
            IF v_day < current_date - 3650 THEN EXIT; END IF;
            CONTINUE;
        END IF;

        IF fn_pattern_day_is_failure(p_pattern_id, v_day) THEN
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
COMMENT ON FUNCTION fn_calculate_anti_streak(BIGINT)
    IS 'Текущая серия подряд идущих дней со срывом/пропуском (negative).';

-- ---------- v_pattern_streaks ----------------------------------------------

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
         THEN fn_calculate_anti_streak(bp.id)
         ELSE 0
    END                            AS anti_streak,
    cd.scheduled_days              AS scheduled_days_30d,
    cd.success_days                AS success_days_30d,
    cd.clean_rate                  AS clean_rate_30d,
    cd.clean_rate                  AS success_rate_30d
  FROM behavior_patterns bp
  CROSS JOIN LATERAL fn_pattern_clean_days_30d(bp.id) cd;

COMMENT ON VIEW v_pattern_streaks
    IS 'Серии: current/max — успешные дни; anti_streak — подряд срывов (negative).';
