-- P3: режим markers + SQL для серий без «одного ответа в день».
-- docker cp db/migrations/003_pattern_markers.sql ptt-db:/tmp/ && docker exec ptt-db psql -U ptt -d ptt -f /tmp/003_pattern_markers.sql

CREATE TABLE IF NOT EXISTS pattern_markers (
    id               BIGSERIAL PRIMARY KEY,
    pattern_id       BIGINT      NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    marker_option_id BIGINT      NOT NULL REFERENCES pattern_response_options(id) ON DELETE CASCADE,
    occurred_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    note             TEXT
);
CREATE INDEX IF NOT EXISTS idx_pattern_markers_pattern_occurred
    ON pattern_markers (pattern_id, occurred_at DESC);
COMMENT ON TABLE pattern_markers IS 'Точечные отметки эпизодов (режим markers). Много записей в день.';

-- ---------- fn_pattern_day_has_answer / fn_pattern_day_success ----------

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
         WHERE pattern_id = p_pattern_id AND session_date = p_day AND status = 'completed';
        RETURN COALESCE(v_ok, FALSE);
    END IF;
    IF v_mode = 'markers' THEN
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

-- ---------- fn_calculate_streak (markers: день без «плохих» меток) --------

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

CREATE OR REPLACE FUNCTION fn_calculate_max_streak(p_pattern_id BIGINT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_max   INT := 0;
    v_cur   INT := 0;
    d       DATE;
    v_end   DATE := current_date;
    v_start DATE := current_date - 3650;
    v_mode  pattern_mode_enum;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM behavior_patterns WHERE id = p_pattern_id) THEN
        RETURN 0;
    END IF;
    SELECT pattern_mode INTO v_mode FROM behavior_patterns WHERE id = p_pattern_id;

    d := v_start;
    WHILE d <= v_end LOOP
        IF fn_pattern_is_scheduled(p_pattern_id, d) THEN
            IF v_mode = 'markers' THEN
                IF fn_pattern_day_success(p_pattern_id, d) THEN
                    v_cur := v_cur + 1;
                    IF v_cur > v_max THEN v_max := v_cur; END IF;
                ELSE
                    v_cur := 0;
                END IF;
            ELSIF fn_pattern_day_has_answer(p_pattern_id, d)
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
    v_mode  pattern_mode_enum;
BEGIN
    SELECT pattern_mode INTO v_mode FROM behavior_patterns WHERE id = p_pattern_id;

    d := current_date - 29;
    WHILE d <= current_date LOOP
        IF fn_pattern_is_scheduled(p_pattern_id, d) THEN
            v_sched := v_sched + 1;
            IF v_mode = 'markers' THEN
                IF fn_pattern_day_success(p_pattern_id, d) THEN
                    v_succ := v_succ + 1;
                END IF;
            ELSIF fn_pattern_day_has_answer(p_pattern_id, d)
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
