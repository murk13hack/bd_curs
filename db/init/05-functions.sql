-- =============================================================================
-- 05 — Функции.
-- См. ТЗ.md, раздел 4.3.1.7. Размещены до представлений, т.к. некоторые view
-- используют функции (например, fn_day_color).
-- =============================================================================

-- ---------- 1. fn_day_color ----------------------------------------------

CREATE OR REPLACE FUNCTION fn_day_color(p_ratio NUMERIC)
RETURNS hex_color
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    r INT;
    g INT;
    b INT;
    ratio NUMERIC;
BEGIN
    -- Линейная интерполяция между #E5E7EB (серый, 0%) и #16A34A (насыщ. зелёный, 100%).
    ratio := COALESCE(p_ratio, 0);
    IF ratio < 0   THEN ratio := 0;   END IF;
    IF ratio > 100 THEN ratio := 100; END IF;
    r := round(229 + (22  - 229) * ratio / 100);
    g := round(231 + (163 - 231) * ratio / 100);
    b := round(235 + (74  - 235) * ratio / 100);
    RETURN format(
        '#%s%s%s',
        lpad(to_hex(r), 2, '0'),
        lpad(to_hex(g), 2, '0'),
        lpad(to_hex(b), 2, '0')
    )::hex_color;
END;
$$;
COMMENT ON FUNCTION fn_day_color(NUMERIC)
    IS 'HEX-цвет для дня в календаре (градиент серый → зелёный по проценту выполнения).';

-- ---------- 2. fn_pattern_is_scheduled -----------------------------------

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
    IF v_cnt = 0 THEN RETURN TRUE; END IF;
    v_dow_bit := 1 << (EXTRACT(ISODOW FROM p_day)::INT - 1);
    RETURN EXISTS (
        SELECT 1 FROM pattern_schedules s
         WHERE s.pattern_id = p_pattern_id
           AND (s.dow_mask & v_dow_bit) > 0
           AND (s.day_of_month IS NULL OR s.day_of_month = EXTRACT(DAY FROM p_day)::INT)
    );
END;
$$;

-- ---------- 3. fn_pattern_day_has_answer / fn_pattern_day_success --------

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
         WHERE pattern_id = p_pattern_id AND session_date = p_day AND status = 'completed';
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

-- ---------- 4. fn_calculate_streak ---------------------------------------

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
COMMENT ON FUNCTION fn_calculate_streak(BIGINT)
    IS 'Текущая серия успешных дней. is_success на опциях уже задаёт семантику для negative.';

-- ---------- 5. fn_calculate_max_streak -----------------------------------

CREATE OR REPLACE FUNCTION fn_calculate_max_streak(p_pattern_id BIGINT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_max INT := 0;
    v_cur INT := 0;
    d     DATE := current_date - 3650;
    v_mode pattern_mode_enum;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM behavior_patterns WHERE id = p_pattern_id) THEN
        RETURN 0;
    END IF;
    SELECT pattern_mode INTO v_mode FROM behavior_patterns WHERE id = p_pattern_id;

    WHILE d <= current_date LOOP
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
COMMENT ON FUNCTION fn_calculate_max_streak(BIGINT)
    IS 'Максимальная серия успешных дней в истории паттерна.';

-- ---------- 6. fn_pattern_clean_days_30d ---------------------------------

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

-- ---------- 7. fn_pattern_day_is_failure -----------------------------------

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

-- ---------- 8. fn_calculate_anti_streak ----------------------------------

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

-- ---------- 5. fn_completion_rate ----------------------------------------

CREATE OR REPLACE FUNCTION fn_completion_rate(
    p_user_id  BIGINT,
    p_from     DATE,
    p_to       DATE,
    p_topic_id BIGINT DEFAULT NULL
) RETURNS percentage
LANGUAGE sql
STABLE
AS $$
    SELECT CASE
        WHEN COUNT(*) = 0 THEN 0::percentage
        ELSE ROUND(
            100.0 * COUNT(*) FILTER (WHERE status = 'done') / COUNT(*),
            2
        )::percentage
    END
      FROM tasks t
     WHERE t.user_id = p_user_id
       AND t.deadline IS NOT NULL
       AND t.deadline::date BETWEEN p_from AND p_to
       AND (p_topic_id IS NULL OR t.topic_id = p_topic_id);
$$;
COMMENT ON FUNCTION fn_completion_rate(BIGINT, DATE, DATE, BIGINT)
    IS 'Процент выполнения задач за период с опциональной фильтрацией по теме.';

-- ---------- 6. fn_search_diary -------------------------------------------

CREATE OR REPLACE FUNCTION fn_search_diary(
    p_user_id BIGINT,
    p_query   TEXT,
    p_limit   INT DEFAULT 50
) RETURNS TABLE (
    entry_id   BIGINT,
    entry_date DATE,
    rank       REAL,
    snippet    TEXT
)
LANGUAGE sql
STABLE
AS $$
    SELECT id,
           entry_date,
           ts_rank(content_tsv, plainto_tsquery('russian', p_query)) AS rank,
           ts_headline(
               'russian',
               content,
               plainto_tsquery('russian', p_query),
               'StartSel=<<,StopSel=>>,MaxFragments=2,MinWords=3,MaxWords=15'
           ) AS snippet
      FROM diary_entries
     WHERE user_id = p_user_id
       AND content_tsv @@ plainto_tsquery('russian', p_query)
     ORDER BY rank DESC, entry_date DESC
     LIMIT GREATEST(COALESCE(p_limit, 50), 1);
$$;
COMMENT ON FUNCTION fn_search_diary(BIGINT, TEXT, INT)
    IS 'Полнотекстовый поиск по дневнику с подсветкой совпадений.';

-- Корреляция настроения: v_mood_productivity_correlation (API GET /stats/correlation).

-- ---------- 7. fn_goal_progress ------------------------------------------

CREATE OR REPLACE FUNCTION fn_goal_progress(p_goal_id BIGINT)
RETURNS percentage
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_target INT;
    v_done   INT := 0;
    v_since  DATE;
BEGIN
    SELECT target_value, created_at::date INTO v_target, v_since FROM goals WHERE id = p_goal_id;
    IF v_target IS NULL OR v_target = 0 THEN
        RETURN 0::percentage;
    END IF;

    -- Для tasks учитываем выполненные.
    SELECT COUNT(*) INTO v_done
      FROM goal_links gl
      JOIN tasks t ON gl.target_type = 'task' AND t.id = gl.target_id
     WHERE gl.goal_id = p_goal_id
       AND t.status = 'done';

    -- Для patterns: habit + markers + scenario (через fn_pattern_day_success / sessions).
    v_done := v_done + COALESCE(
        (
            SELECT COUNT(DISTINCT day)::INT FROM (
                SELECT date_trunc('day', pl.scheduled_at)::date AS day
                  FROM goal_links gl
                  JOIN behavior_patterns bp ON bp.id = gl.target_id AND bp.pattern_mode = 'habit'
                  JOIN pattern_logs pl ON pl.pattern_id = gl.target_id
                  JOIN pattern_response_options ro ON ro.id = pl.response_option_id
                 WHERE gl.goal_id = p_goal_id
                   AND gl.target_type = 'pattern'
                   AND pl.status = 'answered'
                   AND ro.is_success = TRUE
                   AND pl.scheduled_at::date >= v_since
                UNION
                SELECT d.day::date AS day
                  FROM goal_links gl
                  JOIN behavior_patterns bp ON bp.id = gl.target_id AND bp.pattern_mode = 'markers'
                  CROSS JOIN generate_series(v_since, current_date, '1 day') AS d(day)
                 WHERE gl.goal_id = p_goal_id
                   AND gl.target_type = 'pattern'
                   AND fn_pattern_is_scheduled(gl.target_id, d.day::date)
                   AND fn_pattern_day_success(gl.target_id, d.day::date)
                UNION
                SELECT s.session_date AS day
                  FROM goal_links gl
                  JOIN behavior_patterns bp ON bp.id = gl.target_id AND bp.pattern_mode = 'scenario'
                  JOIN pattern_day_sessions s ON s.pattern_id = gl.target_id
                 WHERE gl.goal_id = p_goal_id
                   AND gl.target_type = 'pattern'
                   AND s.status = 'completed'
                   AND s.outcome_success = TRUE
                   AND s.session_date >= v_since
            ) contrib
        ),
        0
    );

    RETURN LEAST(100, ROUND(100.0 * v_done / v_target, 2))::percentage;
END;
$$;
COMMENT ON FUNCTION fn_goal_progress(BIGINT)
    IS 'Прогресс цели: задачи done + успешные дни habit/markers/scenario.';

-- ---------- 8. fn_next_recurring_date ------------------------------------

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
            -- isodow: 1=Mon..7=Sun; преобразуем в bit position 0..6
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

-- Время по темам: v_topic_time_distribution (API GET /stats/time-distribution).

-- ---------- 9. fn_get_calendar_stats -------------------------------------

CREATE OR REPLACE FUNCTION fn_get_calendar_stats(
    p_user_id BIGINT,
    p_year    INT,
    p_month   INT
) RETURNS TABLE (
    day          DATE,
    total        INT,
    done         INT,
    ratio        NUMERIC,
    color        hex_color,
    is_holiday   BOOLEAN,
    holiday_name TEXT,
    has_diary    BOOLEAN
)
LANGUAGE sql
STABLE
AS $$
    WITH range AS (
        SELECT make_date(p_year, p_month, 1) AS m_start,
               (make_date(p_year, p_month, 1) + INTERVAL '1 month - 1 day')::date AS m_end
    ),
    days AS (
        SELECT d::date AS day
          FROM range, generate_series(range.m_start, range.m_end, '1 day') d
    ),
    task_agg AS (
        SELECT t.deadline::date AS day,
               COUNT(*)                                       AS total,
               COUNT(*) FILTER (WHERE t.status = 'done')      AS done
          FROM tasks t
         WHERE t.user_id = p_user_id
           AND t.deadline IS NOT NULL
           AND t.deadline::date BETWEEN (SELECT m_start FROM range)
                                    AND (SELECT m_end   FROM range)
         GROUP BY t.deadline::date
    )
    SELECT
        d.day,
        COALESCE(ta.total, 0)::INT AS total,
        COALESCE(ta.done,  0)::INT AS done,
        CASE WHEN COALESCE(ta.total, 0) = 0 THEN 0
             ELSE ROUND(100.0 * ta.done / ta.total, 2)
        END AS ratio,
        fn_day_color(
            CASE WHEN COALESCE(ta.total, 0) = 0 THEN 0
                 ELSE 100.0 * ta.done / ta.total
            END
        ) AS color,
        h.holiday_date IS NOT NULL AS is_holiday,
        h.name AS holiday_name,
        EXISTS (
            SELECT 1 FROM diary_entries de
             WHERE de.user_id = p_user_id AND de.entry_date = d.day
        ) AS has_diary
      FROM days d
      LEFT JOIN task_agg ta ON ta.day = d.day
      LEFT JOIN holidays  h ON h.holiday_date = d.day
     ORDER BY d.day;
$$;
COMMENT ON FUNCTION fn_get_calendar_stats(BIGINT, INT, INT)
    IS 'Данные для отрисовки месяца календаря.';

DO $$
BEGIN
    RAISE NOTICE 'PTT 05-functions: 9 functions created';
END $$;
