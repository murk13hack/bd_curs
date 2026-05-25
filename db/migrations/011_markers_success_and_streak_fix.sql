-- Исправление: пустой день markers ≠ успех; серия только при эпизоде или «день без эпизодов».
-- Заменяет устаревшую логику «NOT EXISTS (плохих меток)» без учёта пустого дня.

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
             WHERE pm.pattern_id = p_pattern_id AND pm.occurred_at::date = p_day
        ) OR EXISTS (
            SELECT 1 FROM pattern_marker_day_closures c
             WHERE c.pattern_id = p_pattern_id AND c.closure_date = p_day
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
        IF EXISTS (
            SELECT 1
              FROM pattern_markers pm
              JOIN pattern_response_options o ON o.id = pm.marker_option_id
             WHERE pm.pattern_id = p_pattern_id
               AND pm.occurred_at::date = p_day
               AND o.is_success = FALSE
        ) THEN
            RETURN FALSE;
        END IF;
        IF EXISTS (
            SELECT 1 FROM pattern_markers pm
             WHERE pm.pattern_id = p_pattern_id AND pm.occurred_at::date = p_day
        ) THEN
            RETURN TRUE;
        END IF;
        RETURN EXISTS (
            SELECT 1 FROM pattern_marker_day_closures c
             WHERE c.pattern_id = p_pattern_id AND c.closure_date = p_day
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

        IF NOT fn_pattern_day_has_answer(p_pattern_id, v_day) THEN
            IF v_day = current_date THEN
                v_day := v_day - 1;
                IF v_day < current_date - 3650 THEN EXIT; END IF;
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

CREATE OR REPLACE FUNCTION fn_pattern_clean_days_30d(p_pattern_id BIGINT)
RETURNS TABLE(scheduled_days INT, success_days INT, clean_rate NUMERIC)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_sched INT := 0;
    v_succ  INT := 0;
    d       DATE := current_date - 29;
    v_mode  pattern_mode_enum;
BEGIN
    SELECT pattern_mode INTO v_mode FROM behavior_patterns WHERE id = p_pattern_id;

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
