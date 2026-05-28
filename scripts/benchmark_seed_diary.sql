-- Дополнение дневника для FTS-бенчмарка (слово «продуктивность» в тексте).
\set ON_ERROR_STOP on

INSERT INTO diary_entries (user_id, entry_date, content, mood, energy)
SELECT
    1,
    (date '2020-01-01' + g)::date,
    'Bench diary #' || g || '. Запись о продуктивности, настроении и планах на день. PostgreSQL FTS.',
    1 + (g % 5),
    1 + ((g + 2) % 5)
FROM generate_series(1, 500) AS g
ON CONFLICT (user_id, entry_date) DO UPDATE
    SET content = EXCLUDED.content,
        mood = EXCLUDED.mood,
        energy = EXCLUDED.energy;

ANALYZE diary_entries;

SELECT COUNT(*) AS diary_entries_user_1 FROM diary_entries WHERE user_id = 1;
