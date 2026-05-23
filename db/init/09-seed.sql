-- =============================================================================
-- 09 — Наполнение справочников и создание единственного пользователя.
-- =============================================================================

-- ---------- пользователь --------------------------------------------------

INSERT INTO users (id, username, timezone)
VALUES (1, 'me', 'Europe/Moscow')
ON CONFLICT (id) DO NOTHING;

-- Сдвигаем sequence, чтобы будущие insert-ы не конфликтовали.
SELECT setval(pg_get_serial_sequence('users', 'id'),
              GREATEST((SELECT COALESCE(MAX(id), 0) FROM users), 1), TRUE);

-- ---------- темы по умолчанию --------------------------------------------

INSERT INTO topics (user_id, name, color) VALUES
    (1, 'Работа',    '#3B82F6'),
    (1, 'Учёба',     '#8B5CF6'),
    (1, 'Здоровье',  '#10B981'),
    (1, 'Личное',    '#F59E0B'),
    (1, 'Привычки',  '#EC4899'),
    (1, 'Прочее',    '#6B7280')
ON CONFLICT (user_id, name) DO NOTHING;

-- ---------- демо-теги -----------------------------------------------------

INSERT INTO tags (user_id, name) VALUES
    (1, 'важное'),
    (1, 'срочное'),
    (1, 'идея'),
    (1, 'обучение'),
    (1, 'спорт')
ON CONFLICT (user_id, name) DO NOTHING;

-- ---------- праздники РФ на 2026 -----------------------------------------

INSERT INTO holidays (holiday_date, name, is_official) VALUES
    ('2026-01-01', 'Новый год',                                TRUE),
    ('2026-01-02', 'Новогодние каникулы',                      TRUE),
    ('2026-01-03', 'Новогодние каникулы',                      TRUE),
    ('2026-01-04', 'Новогодние каникулы',                      TRUE),
    ('2026-01-05', 'Новогодние каникулы',                      TRUE),
    ('2026-01-06', 'Новогодние каникулы',                      TRUE),
    ('2026-01-07', 'Рождество Христово',                       TRUE),
    ('2026-01-08', 'Новогодние каникулы',                      TRUE),
    ('2026-02-23', 'День защитника Отечества',                 TRUE),
    ('2026-03-08', 'Международный женский день',               TRUE),
    ('2026-05-01', 'Праздник Весны и Труда',                   TRUE),
    ('2026-05-09', 'День Победы',                              TRUE),
    ('2026-06-12', 'День России',                              TRUE),
    ('2026-11-04', 'День народного единства',                  TRUE)
ON CONFLICT (holiday_date) DO NOTHING;

-- ---------- настройки по умолчанию ---------------------------------------

INSERT INTO app_settings (user_id, key, value) VALUES
    (1, 'theme',                  '"system"'::jsonb),
    (1, 'first_day_of_week',      '1'::jsonb),
    (1, 'pomodoro_minutes',       '25'::jsonb),
    (1, 'pomodoro_short_break',   '5'::jsonb),
    (1, 'pomodoro_long_break',    '15'::jsonb),
    (1, 'do_not_disturb',         '{"enabled": false, "from": "22:00", "to": "08:00"}'::jsonb)
ON CONFLICT (user_id, key) DO NOTHING;

DO $$
BEGIN
    RAISE NOTICE 'PTT 09-seed: user(me), topics, tags, holidays, settings populated';
END $$;
