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

-- ---------- 2. fn_calculate_streak ---------------------------------------

CREATE OR REPLACE FUNCTION fn_calculate_streak(p_pattern_id BIGINT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_type   pattern_type_enum;
    v_streak INT  := 0;
    v_day    DATE;
    v_ok     BOOLEAN;
BEGIN
    SELECT pattern_type INTO v_type FROM behavior_patterns WHERE id = p_pattern_id;
    IF v_type IS NULL THEN
        RETURN 0;
    END IF;

    -- Серия = длина непрерывной последовательности успешных дней, заканчивающейся
    -- сегодня или вчера. Идём назад по дням и останавливаемся при первой неудаче.
    v_day := current_date;
    LOOP
        SELECT
            CASE WHEN v_type = 'positive' THEN day_success ELSE NOT day_success END
          INTO v_ok
          FROM (
            SELECT bool_or(
                       status = 'answered'
                       AND COALESCE(
                           (SELECT is_success FROM pattern_response_options o
                             WHERE o.id = pl.response_option_id),
                           FALSE
                       )
                   ) AS day_success
              FROM pattern_logs pl
             WHERE pattern_id = p_pattern_id
               AND date_trunc('day', scheduled_at)::date = v_day
          ) sub;

        IF v_ok IS NULL THEN
            -- В этот день записей нет. Допускаем «дыру» только для текущего дня
            -- (на текущий день расписание ещё могло не сработать).
            IF v_day = current_date THEN
                v_day := v_day - 1;
                CONTINUE;
            ELSE
                EXIT;
            END IF;
        END IF;

        IF v_ok THEN
            v_streak := v_streak + 1;
            v_day    := v_day - 1;
        ELSE
            EXIT;
        END IF;
    END LOOP;

    RETURN v_streak;
END;
$$;
COMMENT ON FUNCTION fn_calculate_streak(BIGINT)
    IS 'Текущая серия успешных дней по паттерну. Учитывает positive/negative.';

-- ---------- 3. fn_calculate_max_streak -----------------------------------

CREATE OR REPLACE FUNCTION fn_calculate_max_streak(p_pattern_id BIGINT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_type   pattern_type_enum;
    v_max_streak INT := 0;
BEGIN
    SELECT pattern_type INTO v_type FROM behavior_patterns WHERE id = p_pattern_id;
    IF v_type IS NULL THEN
        RETURN 0;
    END IF;

    WITH days AS (
        SELECT DISTINCT date_trunc('day', scheduled_at)::date AS d,
               bool_or(
                   status = 'answered' AND COALESCE(
                       (SELECT is_success FROM pattern_response_options o
                         WHERE o.id = pl.response_option_id),
                       FALSE
                   )
               ) AS day_success
          FROM pattern_logs pl
         WHERE pattern_id = p_pattern_id
         GROUP BY date_trunc('day', scheduled_at)::date
    ),
    days_norm AS (
        SELECT d,
               CASE WHEN v_type = 'positive' THEN day_success ELSE NOT day_success END AS ok
          FROM days
    ),
    grp AS (
        SELECT d, ok,
               d - (ROW_NUMBER() OVER (PARTITION BY ok ORDER BY d))::INT AS grp_key
          FROM days_norm
         WHERE ok = TRUE
    )
    SELECT COALESCE(MAX(cnt), 0) INTO v_max_streak
      FROM (
        SELECT COUNT(*) AS cnt FROM grp GROUP BY grp_key
      ) sub;

    RETURN v_max_streak;
END;
$$;
COMMENT ON FUNCTION fn_calculate_max_streak(BIGINT)
    IS 'Максимальная серия успешных дней в истории паттерна (оконные функции).';

-- ---------- 4. fn_calculate_anti_streak ----------------------------------

CREATE OR REPLACE FUNCTION fn_calculate_anti_streak(p_pattern_id BIGINT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_type pattern_type_enum;
    v_streak INT := 0;
BEGIN
    SELECT pattern_type INTO v_type FROM behavior_patterns WHERE id = p_pattern_id;
    IF v_type IS NULL OR v_type <> 'negative' THEN
        RETURN 0;
    END IF;

    -- Для negative-паттерна «анти-серия» — длина непрерывной серии дней БЕЗ срыва,
    -- то есть совпадает с fn_calculate_streak; вынесено отдельной функцией для семантики.
    RETURN fn_calculate_streak(p_pattern_id);
END;
$$;
COMMENT ON FUNCTION fn_calculate_anti_streak(BIGINT)
    IS 'Длина анти-серии (дней без срыва) для negative-паттерна.';

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

-- ---------- 7. fn_mood_productivity_corr ---------------------------------

CREATE OR REPLACE FUNCTION fn_mood_productivity_corr(
    p_user_id BIGINT,
    p_from    DATE,
    p_to      DATE
) RETURNS NUMERIC
LANGUAGE sql
STABLE
AS $$
    WITH days AS (
        SELECT d::date AS day FROM generate_series(p_from, p_to, '1 day') d
    ),
    daily AS (
        SELECT
            days.day,
            (SELECT mood   FROM diary_entries de
              WHERE de.user_id = p_user_id AND de.entry_date = days.day) AS mood,
            (
                SELECT CASE
                    WHEN COUNT(*) = 0 THEN NULL
                    ELSE 100.0 * COUNT(*) FILTER (WHERE status = 'done') / COUNT(*)
                END
                  FROM tasks t
                 WHERE t.user_id = p_user_id
                   AND t.deadline IS NOT NULL
                   AND t.deadline::date = days.day
            ) AS rate
          FROM days
    )
    SELECT corr(mood::numeric, rate)
      FROM daily
     WHERE mood IS NOT NULL AND rate IS NOT NULL;
$$;
COMMENT ON FUNCTION fn_mood_productivity_corr(BIGINT, DATE, DATE)
    IS 'Коэффициент корреляции Пирсона между настроением (дневник) и долей выполненных задач.';

-- ---------- 8. fn_goal_progress ------------------------------------------

CREATE OR REPLACE FUNCTION fn_goal_progress(p_goal_id BIGINT)
RETURNS percentage
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_target INT;
    v_done   INT := 0;
BEGIN
    SELECT target_value INTO v_target FROM goals WHERE id = p_goal_id;
    IF v_target IS NULL OR v_target = 0 THEN
        RETURN 0::percentage;
    END IF;

    -- Для tasks учитываем выполненные.
    SELECT COUNT(*) INTO v_done
      FROM goal_links gl
      JOIN tasks t ON gl.target_type = 'task' AND t.id = gl.target_id
     WHERE gl.goal_id = p_goal_id
       AND t.status = 'done';

    -- Для patterns учитываем выполненные дни (answered + success).
    v_done := v_done + COALESCE(
        (
            SELECT COUNT(DISTINCT date_trunc('day', pl.scheduled_at)::date)
              FROM goal_links gl
              JOIN pattern_logs pl ON gl.target_type = 'pattern' AND pl.pattern_id = gl.target_id
              JOIN pattern_response_options ro ON ro.id = pl.response_option_id
             WHERE gl.goal_id = p_goal_id
               AND pl.status = 'answered'
               AND ro.is_success = TRUE
        ),
        0
    );

    RETURN LEAST(100, ROUND(100.0 * v_done / v_target, 2))::percentage;
END;
$$;
COMMENT ON FUNCTION fn_goal_progress(BIGINT)
    IS 'Процент выполнения цели на основании привязанных задач и паттернов.';

-- ---------- 9. fn_next_recurring_date ------------------------------------

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
    ELSE
        -- custom: пока заглушка — следующий день.
        RETURN p_from + 1;
    END IF;
END;
$$;
COMMENT ON FUNCTION fn_next_recurring_date(BIGINT, DATE)
    IS 'Следующая дата повторения по правилу.';

-- ---------- 10. fn_topic_time_breakdown ----------------------------------

CREATE OR REPLACE FUNCTION fn_topic_time_breakdown(
    p_user_id BIGINT,
    p_from    DATE,
    p_to      DATE
) RETURNS TABLE (
    topic_id   BIGINT,
    topic_name TEXT,
    minutes    INT,
    share      NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    WITH agg AS (
        SELECT t.topic_id,
               COALESCE(SUM(ttl.duration_seconds), 0) / 60 AS minutes
          FROM tasks t
          LEFT JOIN task_time_logs ttl
                 ON ttl.task_id = t.id
                AND ttl.started_at::date BETWEEN p_from AND p_to
         WHERE t.user_id = p_user_id
         GROUP BY t.topic_id
    ),
    total AS (
        SELECT COALESCE(SUM(minutes), 0) AS sum_min FROM agg
    )
    SELECT a.topic_id,
           tp.name,
           a.minutes::INT,
           CASE WHEN total.sum_min = 0 THEN 0
                ELSE ROUND(100.0 * a.minutes / total.sum_min, 2)
           END AS share
      FROM agg a
      JOIN topics tp ON tp.id = a.topic_id
      CROSS JOIN total
     ORDER BY a.minutes DESC;
$$;
COMMENT ON FUNCTION fn_topic_time_breakdown(BIGINT, DATE, DATE)
    IS 'Распределение фактического времени по темам за период.';

-- ---------- 11. fn_get_calendar_stats ------------------------------------

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
    RAISE NOTICE 'PTT 05-functions: 11 functions created';
END $$;
