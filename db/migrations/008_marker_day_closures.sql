-- Явное закрытие дня без эпизодов (режим markers).

CREATE TABLE IF NOT EXISTS pattern_marker_day_closures (
    id           BIGSERIAL PRIMARY KEY,
    pattern_id   BIGINT NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    closure_date DATE NOT NULL,
    declared_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pattern_marker_day_closures_uniq UNIQUE (pattern_id, closure_date)
);
COMMENT ON TABLE pattern_marker_day_closures IS 'Пользователь зафиксировал: за день не было эпизодов (markers).';

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
    v_has_bad BOOLEAN;
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
        SELECT EXISTS (
            SELECT 1
              FROM pattern_markers pm
              JOIN pattern_response_options o ON o.id = pm.marker_option_id
             WHERE pm.pattern_id = p_pattern_id
               AND pm.occurred_at::date = p_day
               AND o.is_success = FALSE
        ) INTO v_has_bad;
        IF v_has_bad THEN
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
