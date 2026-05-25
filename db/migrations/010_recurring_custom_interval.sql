-- custom: повтор каждые N дней (params.interval_days, по умолчанию 1).

CREATE OR REPLACE FUNCTION fn_next_recurring_date(
    p_rule_id BIGINT,
    p_from    DATE
) RETURNS DATE
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_freq  recurrence_freq_enum;
    v_params JSONB;
    v_dom    INT;
    v_mask   INT;
    v_d      DATE;
    v_dow    INT;
BEGIN
    SELECT frequency, params INTO v_freq, v_params
      FROM recurring_rules WHERE id = p_rule_id AND is_active = TRUE;
    IF v_freq IS NULL THEN
        RETURN NULL;
    END IF;

    IF v_freq = 'daily' THEN
        RETURN p_from + 1;
    ELSIF v_freq = 'weekly' THEN
        v_mask := COALESCE((v_params->>'weekly_mask')::INT, 127);
        v_d := p_from + 1;
        FOR i IN 0..6 LOOP
            v_dow := EXTRACT(isodow FROM v_d)::INT - 1;
            IF (v_mask & (1 << v_dow)) <> 0 THEN
                RETURN v_d;
            END IF;
            v_d := v_d + 1;
        END LOOP;
        RETURN p_from + 7;
    ELSIF v_freq = 'monthly' THEN
        v_dom := COALESCE((v_params->>'monthly_day')::INT, EXTRACT(day FROM p_from)::INT);
        v_d := (date_trunc('month', p_from) + INTERVAL '1 month')::date
               + (v_dom - 1) * INTERVAL '1 day';
        RETURN v_d::date;
    ELSIF v_freq = 'custom' THEN
        RETURN p_from + GREATEST(COALESCE((v_params->>'interval_days')::INT, 1), 1);
    ELSE
        RETURN NULL;
    END IF;
END;
$$;

COMMENT ON FUNCTION fn_next_recurring_date(BIGINT, DATE)
    IS 'Следующая дата повторения: daily/weekly/monthly/custom (params.interval_days).';
