

-- ===== 00-readme.sql =====

-- =============================================================================
-- РџРўРў. РљР°С‚Р°Р»РѕРі РёРЅРёС†РёР°Р»РёР·Р°С†РёРѕРЅРЅС‹С… СЃРєСЂРёРїС‚РѕРІ Р‘Р”.
--
-- Р¤Р°Р№Р»С‹ РёР· СЌС‚РѕРіРѕ РєР°С‚Р°Р»РѕРіР° РІС‹РїРѕР»РЅСЏСЋС‚СЃСЏ РѕР±СЂР°Р·РѕРј postgres:16-alpine РїСЂРё РџР•Р Р’РћРњ
-- Р·Р°РїСѓСЃРєРµ РєРѕРЅС‚РµР№РЅРµСЂР° РІ РђР›Р¤РђР’РРўРќРћРњ РїРѕСЂСЏРґРєРµ РёРјС‘РЅ. РџРѕСЃР»Рµ СЃРѕР·РґР°РЅРёСЏ С‚РѕРјР° (volume
-- pgdata) РїРѕРІС‚РѕСЂРЅРѕ СЃРєСЂРёРїС‚С‹ РЅРµ Р·Р°РїСѓСЃРєР°СЋС‚СЃСЏ.
--
-- РџР»Р°РЅ РЅР°РїРѕР»РЅРµРЅРёСЏ РєР°С‚Р°Р»РѕРіР° СЃРѕРіР»Р°СЃРЅРѕ РўР— (СЂР°Р·РґРµР» 4.3.1, РїСЂРёР»РѕР¶РµРЅРёРµ Р’):
--   01-extensions.sql   -- CREATE EXTENSION pg_trgm, btree_gist
--   02-types.sql        -- CREATE TYPE / CREATE DOMAIN
--   03-tables.sql       -- CREATE TABLE + РєРѕРЅСЃС‚СЂРµР№РЅС‚С‹
--   04-indexes.sql      -- CREATE INDEX (B-tree, GIN, BRIN, partial, exclusion)
--   05-functions.sql    -- CREATE FUNCTION
--   06-views.sql        -- CREATE VIEW / MATERIALIZED VIEW
--   07-procedures.sql   -- CREATE PROCEDURE
--   08-triggers.sql     -- CREATE TRIGGER
--   09-seed.sql         -- РЅР°РїРѕР»РЅРµРЅРёРµ СЃРїСЂР°РІРѕС‡РЅРёРєРѕРІ (topics, holidays, ...)
--
-- РљРѕРјР°РЅРґР° РїСЂРёРјРµРЅРµРЅРёСЏ РІСЂСѓС‡РЅСѓСЋ (РµСЃР»Рё volume СѓР¶Рµ СЃСѓС‰РµСЃС‚РІРѕРІР°Р»):
--   docker compose exec db psql -U $POSTGRES_USER -d $POSTGRES_DB -f /docker-entrypoint-initdb.d/<file>.sql
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'PTT init scripts placeholder loaded at %', now();
END $$;


-- ===== 01-extensions.sql =====

-- =============================================================================
-- 01 вЂ” Р Р°СЃС€РёСЂРµРЅРёСЏ PostgreSQL.
--
-- РСЃРїРѕР»СЊР·СѓСЋС‚СЃСЏ:
--   pg_trgm    вЂ” РЅРµС‡С‘С‚РєРёР№ РїРѕРёСЃРє/С‚СЂРёРіСЂР°РјРјРЅС‹Рµ РёРЅРґРµРєСЃС‹ РїРѕ С‚РµРіР°Рј Рё С‚РµРјР°Рј;
--   btree_gist вЂ” РїРѕРґРґРµСЂР¶РєР° EXCLUSION-РєРѕРЅСЃС‚СЂРµР№РЅС‚РѕРІ РІРјРµСЃС‚Рµ СЃ gist (СЃРј. 03);
--   unaccent   вЂ” РїРѕРёСЃРє Р±РµР· РґРёР°РєСЂРёС‚РёРєРё (РІСЃРїРѕРјРѕРіР°С‚РµР»СЊРЅР°СЏ РґР»СЏ FTS).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS unaccent;

DO $$
BEGIN
    RAISE NOTICE 'PTT 01-extensions: pg_trgm, btree_gist, unaccent installed';
END $$;


-- ===== 02-types.sql =====

-- =============================================================================
-- 02 вЂ” РџРѕР»СЊР·РѕРІР°С‚РµР»СЊСЃРєРёРµ С‚РёРїС‹ РґР°РЅРЅС‹С…: РїРµСЂРµС‡РёСЃР»РµРЅРёСЏ (ENUM) Рё РґРѕРјРµРЅРЅС‹Рµ (DOMAIN).
-- РЎРј. РўР—.md, СЂР°Р·РґРµР» 4.3.1.3.
-- =============================================================================

-- ---------- ENUM ----------------------------------------------------------

CREATE TYPE task_status_enum AS ENUM (
    'pending',      -- Р·Р°РїР»Р°РЅРёСЂРѕРІР°РЅР°, РЅРµ РЅР°С‡Р°С‚Р°
    'in_progress',  -- РІ СЂР°Р±РѕС‚Рµ
    'done',         -- СѓСЃРїРµС€РЅРѕ Р·Р°РІРµСЂС€РµРЅР°
    'overdue',      -- РїСЂРѕСЃСЂРѕС‡РµРЅР° (РІС‹СЃС‚Р°РІР»СЏРµС‚СЃСЏ С‚СЂРёРіРіРµСЂРѕРј trg_task_overdue_check)
    'cancelled'     -- РѕС‚РјРµРЅРµРЅР° РїРѕР»СЊР·РѕРІР°С‚РµР»РµРј
);
COMMENT ON TYPE task_status_enum IS 'РЎС‚Р°С‚СѓСЃ Р·Р°РґР°С‡Рё. РџРµСЂРµС…РѕРґС‹: pending в†’ in_progress в†’ done; pending в†’ cancelled; done в†’ overdue (С‚СЂРёРіРіРµСЂ).';

CREATE TYPE task_priority_enum AS ENUM (
    'low',
    'medium',
    'high',
    'urgent'
);
COMMENT ON TYPE task_priority_enum IS 'РџСЂРёРѕСЂРёС‚РµС‚ Р·Р°РґР°С‡Рё.';

CREATE TYPE pattern_type_enum AS ENUM (
    'positive',  -- С„РѕСЂРјРёСЂРѕРІР°РЅРёРµ РїСЂРёРІС‹С‡РєРё (Р·Р°СЂСЏРґРєР°, С‡С‚РµРЅРёРµ, ...)
    'negative'   -- РѕС‚РєР°Р· РѕС‚ РїСЂРёРІС‹С‡РєРё (РєСѓСЂРµРЅРёРµ, СЃРѕС†. СЃРµС‚Рё, ...)
);
COMMENT ON TYPE pattern_type_enum IS 'РўРёРї РїР°С‚С‚РµСЂРЅР° РїРѕРІРµРґРµРЅРёСЏ.';

CREATE TYPE pattern_log_status_enum AS ENUM (
    'pending',   -- РѕР¶РёРґР°РµРј РѕС‚РІРµС‚Р° РїРѕР»СЊР·РѕРІР°С‚РµР»СЏ
    'answered',  -- РѕС‚РІРµС‚ РїРѕР»СѓС‡РµРЅ
    'missed'     -- РїСЂРѕРїСѓС‰РµРЅ (Р·Р°РєСЂС‹С‚ sp_close_overdue_pattern_logs)
);
COMMENT ON TYPE pattern_log_status_enum IS 'РЎС‚Р°С‚СѓСЃ Р·Р°РїРёСЃРё Р¶СѓСЂРЅР°Р»Р° РѕС‚РєР»РёРєРѕРІ РЅР° РїР°С‚С‚РµСЂРЅ.';

CREATE TYPE pattern_mode_enum AS ENUM (
    'habit',     -- Р±С‹СЃС‚СЂС‹Р№ С‡РµРєР»РёСЃС‚ (СЃРґРµР»Р°Р» / СѓРґРµСЂР¶Р°Р»СЃСЏ)
    'scenario',  -- РїРѕС€Р°РіРѕРІС‹Р№ СЃС†РµРЅР°СЂРёР№ РґРЅСЏ
    'markers'    -- С‚РѕС‡РµС‡РЅС‹Рµ РѕС‚РјРµС‚РєРё (P3)
);
COMMENT ON TYPE pattern_mode_enum IS 'Р РµР¶РёРј РїР°С‚С‚РµСЂРЅР° РїРѕРІРµРґРµРЅРёСЏ.';

CREATE TYPE pattern_step_kind_enum AS ENUM (
    'check', 'single_choice', 'note'
);
COMMENT ON TYPE pattern_step_kind_enum IS 'РўРёРї С€Р°РіР° СЃС†РµРЅР°СЂРёСЏ.';

CREATE TYPE pattern_step_role_enum AS ENUM (
    'context', 'trigger', 'choice', 'action', 'outcome'
);
COMMENT ON TYPE pattern_step_role_enum IS 'Р РѕР»СЊ С€Р°РіР° РІ СЃС†РµРЅР°СЂРёРё (РґР»СЏ Р°РЅР°Р»РёС‚РёРєРё).';

CREATE TYPE pattern_session_status_enum AS ENUM (
    'in_progress', 'completed', 'abandoned'
);
COMMENT ON TYPE pattern_session_status_enum IS 'РЎС‚Р°С‚СѓСЃ РїСЂРѕС…РѕР¶РґРµРЅРёСЏ СЃС†РµРЅР°СЂРёСЏ Р·Р° РґРµРЅСЊ.';

CREATE TYPE recurrence_freq_enum AS ENUM (
    'daily',
    'weekly',
    'monthly',
    'custom'
);
COMMENT ON TYPE recurrence_freq_enum IS 'Р§Р°СЃС‚РѕС‚Р° РїРѕРІС‚РѕСЂРµРЅРёСЏ. custom: params.interval_days (РєР°Р¶РґС‹Рµ N РґРЅРµР№, N>=1).';

CREATE TYPE audit_action_enum AS ENUM (
    'insert',
    'update',
    'delete'
);
COMMENT ON TYPE audit_action_enum IS 'Р”РµР№СЃС‚РІРёРµ РІ Р¶СѓСЂРЅР°Р»Рµ Р°СѓРґРёС‚Р°.';

-- ---------- DOMAIN --------------------------------------------------------

CREATE DOMAIN mood_score AS SMALLINT
    CHECK (VALUE IS NULL OR (VALUE BETWEEN 1 AND 5));
COMMENT ON DOMAIN mood_score IS 'РЁРєР°Р»Р° 1..5 РґР»СЏ РЅР°СЃС‚СЂРѕРµРЅРёСЏ Рё СѓСЂРѕРІРЅСЏ СЌРЅРµСЂРіРёРё.';

CREATE DOMAIN percentage AS NUMERIC(5,2)
    CHECK (VALUE IS NULL OR (VALUE BETWEEN 0 AND 100));
COMMENT ON DOMAIN percentage IS 'РџСЂРѕС†РµРЅС‚РЅРѕРµ Р·РЅР°С‡РµРЅРёРµ РІ РґРёР°РїР°Р·РѕРЅРµ 0..100.';

CREATE DOMAIN positive_int AS INTEGER
    CHECK (VALUE IS NULL OR VALUE > 0);
COMMENT ON DOMAIN positive_int IS 'РЎС‚СЂРѕРіРѕ РїРѕР»РѕР¶РёС‚РµР»СЊРЅРѕРµ С†РµР»РѕРµ С‡РёСЃР»Рѕ.';

CREATE DOMAIN hex_color AS CHAR(7)
    CHECK (VALUE ~ '^#[0-9A-Fa-f]{6}$');
COMMENT ON DOMAIN hex_color IS 'HEX-С†РІРµС‚ РІ С„РѕСЂРјР°С‚Рµ #RRGGBB.';

DO $$
BEGIN
    RAISE NOTICE 'PTT 02-types: ENUM and DOMAIN types created';
END $$;


-- ===== 03-tables.sql =====

-- =============================================================================
-- 03 вЂ” РўР°Р±Р»РёС†С‹ Рё РґРµРєР»Р°СЂР°С‚РёРІРЅС‹Рµ РєРѕРЅСЃС‚СЂРµР№РЅС‚С‹.
-- 23 С‚Р°Р±Р»РёС†С‹: 18 Р±Р°Р·РѕРІС‹С… РїРѕ РўР— + 5 РґР»СЏ СЂРµР¶РёРјРѕРІ РїР°С‚С‚РµСЂРЅРѕРІ (scenario/markers).
-- =============================================================================

-- ---------- 1. users ------------------------------------------------------

CREATE TABLE users (
    id            BIGSERIAL PRIMARY KEY,
    username      TEXT        NOT NULL UNIQUE,
    password_hash TEXT,
    timezone      TEXT        NOT NULL DEFAULT 'Europe/Moscow',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE users IS 'РџРѕР»СЊР·РѕРІР°С‚РµР»Рё СЃРёСЃС‚РµРјС‹. Р’ РѕРґРЅРѕ-РїРѕР»СЊР·РѕРІР°С‚РµР»СЊСЃРєРѕРј СЂРµР¶РёРјРµ вЂ” РѕРґРЅР° Р·Р°РїРёСЃСЊ.';

-- ---------- 2. topics -----------------------------------------------------

CREATE TABLE topics (
    id      BIGSERIAL PRIMARY KEY,
    user_id BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name    TEXT        NOT NULL,
    color   hex_color   NOT NULL DEFAULT '#3B82F6',
    CONSTRAINT topics_user_name_uniq UNIQUE (user_id, name),
    CONSTRAINT topics_name_not_empty CHECK (length(btrim(name)) > 0)
);
COMMENT ON TABLE topics IS 'РўРµРјС‹ (РєР°С‚РµРіРѕСЂРёРё) Р·Р°РґР°С‡ Рё РїР°С‚С‚РµСЂРЅРѕРІ.';

-- ---------- 3. tags -------------------------------------------------------

CREATE TABLE tags (
    id      BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name    TEXT   NOT NULL,
    CONSTRAINT tags_user_name_uniq UNIQUE (user_id, name),
    CONSTRAINT tags_name_not_empty CHECK (length(btrim(name)) > 0)
);
COMMENT ON TABLE tags IS 'РЈРЅРёРІРµСЂСЃР°Р»СЊРЅС‹Рµ С‚РµРіРё РґР»СЏ Р·Р°РґР°С‡ Рё Р·Р°РїРёСЃРµР№ РґРЅРµРІРЅРёРєР°.';

-- ---------- 4. recurring_rules -------------------------------------------

CREATE TABLE recurring_rules (
    id          BIGSERIAL PRIMARY KEY,
    frequency   recurrence_freq_enum NOT NULL,
    params      JSONB                NOT NULL DEFAULT '{}'::jsonb,
    next_run_at TIMESTAMPTZ,
    is_active   BOOLEAN              NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ          NOT NULL DEFAULT now()
);
COMMENT ON TABLE recurring_rules IS 'РџСЂР°РІРёР»Р° РїРѕРІС‚РѕСЂРµРЅРёСЏ Р·Р°РґР°С‡. params вЂ” JSONB СЃ РїРѕР»СЏРјРё weekly_mask, monthly_day, custom_cron Рё С‚.Рґ.';

-- ---------- 5. tasks ------------------------------------------------------

CREATE TABLE tasks (
    id                BIGSERIAL PRIMARY KEY,
    user_id           BIGINT             NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    topic_id          BIGINT             NOT NULL REFERENCES topics(id) ON DELETE RESTRICT,
    parent_task_id    BIGINT REFERENCES tasks(id)             ON DELETE SET NULL,
    recurring_rule_id BIGINT REFERENCES recurring_rules(id)   ON DELETE SET NULL,
    title             TEXT               NOT NULL,
    description       TEXT,
    status            task_status_enum   NOT NULL DEFAULT 'pending',
    priority          task_priority_enum NOT NULL DEFAULT 'medium',
    start_at          TIMESTAMPTZ,
    deadline          TIMESTAMPTZ,
    planned_minutes   positive_int,
    completed_at      TIMESTAMPTZ,
    is_archived       BOOLEAN            NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ        NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ        NOT NULL DEFAULT now(),
    CONSTRAINT tasks_title_not_empty CHECK (length(btrim(title)) > 0),
    CONSTRAINT tasks_deadline_after_created CHECK (deadline IS NULL OR deadline > created_at),
    CONSTRAINT tasks_start_before_deadline CHECK (
        start_at IS NULL OR deadline IS NULL OR start_at < deadline
    ),
    CONSTRAINT tasks_completed_after_created CHECK (completed_at IS NULL OR completed_at >= created_at),
    CONSTRAINT tasks_no_self_parent CHECK (parent_task_id IS NULL OR parent_task_id <> id)
);
COMMENT ON TABLE tasks IS 'Р—Р°РґР°С‡Рё. РџРѕРґРґРµСЂР¶РёРІР°РµС‚СЃСЏ РёРµСЂР°СЂС…РёСЏ (parent_task_id) Рё РїСЂРёРІСЏР·РєР° Рє РїСЂР°РІРёР»Сѓ РїРѕРІС‚РѕСЂРµРЅРёСЏ.';
COMMENT ON COLUMN tasks.start_at IS 'РќРµ СЂР°РЅСЊС€Рµ РєР°РєРѕРіРѕ РјРѕРјРµРЅС‚Р° Р·Р°РґР°С‡Сѓ РёРјРµРµС‚ СЃРјС‹СЃР» РЅР°С‡РёРЅР°С‚СЊ (РЅР°С‡Р°Р»Рѕ РѕРєРЅР° РІС‹РїРѕР»РЅРµРЅРёСЏ).';
COMMENT ON COLUMN tasks.deadline IS 'РљСЂР°Р№РЅРёР№ СЃСЂРѕРє РѕРєРѕРЅС‡Р°РЅРёСЏ (РєРѕРЅРµС† РѕРєРЅР° РІС‹РїРѕР»РЅРµРЅРёСЏ).';
COMMENT ON COLUMN tasks.planned_minutes IS 'РџР»Р°РЅРѕРІР°СЏ РѕС†РµРЅРєР° С‚СЂСѓРґРѕР·Р°С‚СЂР°С‚ РІ РјРёРЅСѓС‚Р°С…, РЅРµ РґР»РёС‚РµР»СЊРЅРѕСЃС‚СЊ РёРЅС‚РµСЂРІР°Р»Р° start_atвЂ“deadline.';

-- ---------- 6. task_tags --------------------------------------------------

CREATE TABLE task_tags (
    task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    tag_id  BIGINT NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
    PRIMARY KEY (task_id, tag_id)
);
COMMENT ON TABLE task_tags IS 'РЎРІСЏР·РєР° M:N Р·Р°РґР°С‡Р°-С‚РµРі.';

-- ---------- 7. task_time_logs --------------------------------------------

CREATE TABLE task_time_logs (
    id               BIGSERIAL PRIMARY KEY,
    task_id          BIGINT      NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id          BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    started_at       TIMESTAMPTZ NOT NULL,
    ended_at         TIMESTAMPTZ NOT NULL,
    duration_seconds INTEGER GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (ended_at - started_at))::INT
    ) STORED,
    is_pomodoro      BOOLEAN     NOT NULL DEFAULT FALSE,
    note             TEXT,
    CONSTRAINT task_time_logs_ended_after_started CHECK (ended_at > started_at)
);
COMMENT ON TABLE task_time_logs IS 'Р–СѓСЂРЅР°Р» РѕС‚СЂРµР·РєРѕРІ РІСЂРµРјРµРЅРё РїРѕ Р·Р°РґР°С‡Р°Рј. РџРµСЂРµСЃРµС‡РµРЅРёСЏ РёРЅС‚РµСЂРІР°Р»РѕРІ Сѓ РѕРґРЅРѕРіРѕ РїРѕР»СЊР·РѕРІР°С‚РµР»СЏ РґРѕРїСѓСЃС‚РёРјС‹ (exclusion СЃРЅСЏС‚ РјРёРіСЂР°С†РёРµР№ 012).';

-- ---------- 8. diary_entries ---------------------------------------------

CREATE TABLE diary_entries (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entry_date  DATE        NOT NULL,
    content     TEXT        NOT NULL,
    content_tsv TSVECTOR,
    mood        mood_score,
    energy      mood_score,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT diary_entries_user_date_uniq UNIQUE (user_id, entry_date),
    CONSTRAINT diary_entries_content_not_empty CHECK (length(btrim(content)) > 0)
);
COMMENT ON TABLE diary_entries IS 'Р—Р°РїРёСЃРё РґРЅРµРІРЅРёРєР°, РѕРґРЅР° Р·Р°РїРёСЃСЊ РІ РґРµРЅСЊ РЅР° РїРѕР»СЊР·РѕРІР°С‚РµР»СЏ. content_tsv РѕР±РЅРѕРІР»СЏРµС‚СЃСЏ С‚СЂРёРіРіРµСЂРѕРј.';

-- ---------- 9. diary_tags -------------------------------------------------

CREATE TABLE diary_tags (
    entry_id BIGINT NOT NULL REFERENCES diary_entries(id) ON DELETE CASCADE,
    tag_id   BIGINT NOT NULL REFERENCES tags(id)          ON DELETE CASCADE,
    PRIMARY KEY (entry_id, tag_id)
);
COMMENT ON TABLE diary_tags IS 'РЎРІСЏР·РєР° M:N Р·Р°РїРёСЃСЊ РґРЅРµРІРЅРёРєР° вЂ” С‚РµРі.';

-- ---------- 10. behavior_patterns ----------------------------------------

CREATE TABLE behavior_patterns (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT             NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    topic_id         BIGINT REFERENCES topics(id) ON DELETE RESTRICT,
    title            TEXT               NOT NULL,
    description      TEXT,
    pattern_type     pattern_type_enum  NOT NULL DEFAULT 'positive',
    is_boolean       BOOLEAN            NOT NULL DEFAULT FALSE,
    auto_create_task BOOLEAN            NOT NULL DEFAULT FALSE,
    pattern_mode     pattern_mode_enum NOT NULL DEFAULT 'habit',
    guide_intro      TEXT,
    created_at       TIMESTAMPTZ        NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ        NOT NULL DEFAULT now(),
    CONSTRAINT behavior_patterns_title_not_empty CHECK (length(btrim(title)) > 0)
);
COMMENT ON TABLE behavior_patterns IS 'РџР°С‚С‚РµСЂРЅС‹ РїРѕРІРµРґРµРЅРёСЏ. is_boolean=true вЂ” РґРІР° РІР°СЂРёР°РЅС‚Р° Y/N (СЃРѕР·РґР°СЋС‚СЃСЏ Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРё).';

-- ---------- 11. pattern_response_options ---------------------------------

CREATE TABLE pattern_response_options (
    id         BIGSERIAL PRIMARY KEY,
    pattern_id BIGINT  NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    label      TEXT    NOT NULL,
    is_success BOOLEAN NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT pattern_response_options_label_not_empty CHECK (length(btrim(label)) > 0)
);
COMMENT ON TABLE pattern_response_options IS 'Р’Р°СЂРёР°РЅС‚С‹ РѕС‚РІРµС‚Р° РЅР° РїР°С‚С‚РµСЂРЅ. is_success вЂ” СѓС‡РёС‚С‹РІР°РµС‚СЃСЏ Р»Рё РѕС‚РІРµС‚ РєР°Рє СѓСЃРїРµС€РЅС‹Р№.';

-- ---------- 12. pattern_schedules ----------------------------------------

CREATE TABLE pattern_schedules (
    id           BIGSERIAL PRIMARY KEY,
    pattern_id   BIGINT   NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    time_of_day  TIME     NOT NULL,
    dow_mask     SMALLINT NOT NULL DEFAULT 127,
    day_of_month SMALLINT,
    CONSTRAINT pattern_schedules_dow_mask_valid CHECK (dow_mask BETWEEN 0 AND 127),
    CONSTRAINT pattern_schedules_dom_valid     CHECK (day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31)
);
COMMENT ON TABLE pattern_schedules  IS 'Р Р°СЃРїРёСЃР°РЅРёСЏ СѓРІРµРґРѕРјР»РµРЅРёР№ РїРѕ РїР°С‚С‚РµСЂРЅР°Рј.';
COMMENT ON COLUMN pattern_schedules.dow_mask IS 'Р‘РёС‚РѕРІР°СЏ РјР°СЃРєР° РґРЅРµР№ РЅРµРґРµР»Рё: 1=Mon, 2=Tue, 4=Wed, 8=Thu, 16=Fri, 32=Sat, 64=Sun. 127 = РµР¶РµРґРЅРµРІРЅРѕ.';

-- ---------- 13. pattern_logs ---------------------------------------------

CREATE TABLE pattern_logs (
    id                  BIGSERIAL PRIMARY KEY,
    pattern_id          BIGINT NOT NULL REFERENCES behavior_patterns(id)        ON DELETE CASCADE,
    response_option_id  BIGINT          REFERENCES pattern_response_options(id) ON DELETE SET NULL,
    scheduled_at        TIMESTAMPTZ NOT NULL,
    answered_at         TIMESTAMPTZ,
    status              pattern_log_status_enum NOT NULL DEFAULT 'pending',
    CONSTRAINT pattern_logs_answered_consistency CHECK (
        (status = 'answered' AND response_option_id IS NOT NULL AND answered_at IS NOT NULL)
        OR status <> 'answered'
    )
);
COMMENT ON TABLE pattern_logs IS 'Р–СѓСЂРЅР°Р» РѕС‚РєР»РёРєРѕРІ РїРѕ РїР°С‚С‚РµСЂРЅР°Рј (СЂРµР¶РёРј habit).';

-- ---------- 13a. pattern_steps (scenario) --------------------------------

CREATE TABLE pattern_steps (
    id            BIGSERIAL PRIMARY KEY,
    pattern_id    BIGINT NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    sort_order    INTEGER NOT NULL DEFAULT 0,
    title         TEXT NOT NULL,
    hint          TEXT,
    step_kind     pattern_step_kind_enum NOT NULL DEFAULT 'single_choice',
    step_role     pattern_step_role_enum NOT NULL DEFAULT 'context',
    is_required   BOOLEAN NOT NULL DEFAULT TRUE,
    marks_success BOOLEAN NOT NULL DEFAULT FALSE,
    choices       JSONB NOT NULL DEFAULT '[]'::jsonb,
    CONSTRAINT pattern_steps_title_not_empty CHECK (length(btrim(title)) > 0)
);
COMMENT ON TABLE pattern_steps IS 'РЁР°РіРё СЃС†РµРЅР°СЂРёСЏ (СЂРµР¶РёРј scenario). choices: [{id,label,is_success}]';

-- ---------- 13b. pattern_day_sessions ------------------------------------

CREATE TABLE pattern_day_sessions (
    id              BIGSERIAL PRIMARY KEY,
    pattern_id      BIGINT NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    session_date    DATE NOT NULL,
    status          pattern_session_status_enum NOT NULL DEFAULT 'in_progress',
    outcome_success BOOLEAN,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    CONSTRAINT pattern_day_sessions_uniq UNIQUE (pattern_id, session_date)
);
COMMENT ON TABLE pattern_day_sessions IS 'РЎРµСЃСЃРёСЏ РїСЂРѕС…РѕР¶РґРµРЅРёСЏ СЃС†РµРЅР°СЂРёСЏ Р·Р° РєР°Р»РµРЅРґР°СЂРЅС‹Р№ РґРµРЅСЊ.';

-- ---------- 13c. pattern_step_answers ------------------------------------

CREATE TABLE pattern_step_answers (
    id          BIGSERIAL PRIMARY KEY,
    session_id  BIGINT NOT NULL REFERENCES pattern_day_sessions(id) ON DELETE CASCADE,
    step_id     BIGINT NOT NULL REFERENCES pattern_steps(id) ON DELETE CASCADE,
    choice_id   TEXT,
    checked     BOOLEAN,
    note_text   TEXT,
    answered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pattern_step_answers_uniq UNIQUE (session_id, step_id)
);
COMMENT ON TABLE pattern_step_answers IS 'РћС‚РІРµС‚С‹ РЅР° С€Р°РіРё СЃС†РµРЅР°СЂРёСЏ РІ СЂР°РјРєР°С… СЃРµСЃСЃРёРё.';

-- ---------- 13d. pattern_markers (markers mode) --------------------------

CREATE TABLE pattern_markers (
    id               BIGSERIAL PRIMARY KEY,
    pattern_id       BIGINT      NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    marker_option_id BIGINT      NOT NULL REFERENCES pattern_response_options(id) ON DELETE CASCADE,
    occurred_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    note             TEXT
);
CREATE INDEX idx_pattern_markers_pattern_occurred ON pattern_markers (pattern_id, occurred_at DESC);
COMMENT ON TABLE pattern_markers IS 'РўРѕС‡РµС‡РЅС‹Рµ РѕС‚РјРµС‚РєРё СЌРїРёР·РѕРґРѕРІ (СЂРµР¶РёРј markers). РњРЅРѕРіРѕ Р·Р°РїРёСЃРµР№ РІ РґРµРЅСЊ.';

-- ---------- 13e. pattern_marker_day_closures ------------------------------

CREATE TABLE pattern_marker_day_closures (
    id           BIGSERIAL PRIMARY KEY,
    pattern_id   BIGINT NOT NULL REFERENCES behavior_patterns(id) ON DELETE CASCADE,
    closure_date DATE NOT NULL,
    declared_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pattern_marker_day_closures_uniq UNIQUE (pattern_id, closure_date)
);
COMMENT ON TABLE pattern_marker_day_closures IS 'РЇРІРЅРѕ: Р·Р° РґРµРЅСЊ РЅРµ Р±С‹Р»Рѕ СЌРїРёР·РѕРґРѕРІ (markers).';

-- ---------- 14. goals -----------------------------------------------------

CREATE TABLE goals (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title        TEXT         NOT NULL,
    description  TEXT,
    deadline     DATE,
    target_value positive_int NOT NULL DEFAULT 1,
    is_completed BOOLEAN      NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT goals_title_not_empty CHECK (length(btrim(title)) > 0),
    CONSTRAINT goals_completed_consistency CHECK (
        (is_completed = TRUE  AND completed_at IS NOT NULL) OR
        (is_completed = FALSE AND completed_at IS NULL)
    )
);
COMMENT ON TABLE goals IS 'Р”РѕР»РіРѕСЃСЂРѕС‡РЅС‹Рµ С†РµР»Рё.';

-- ---------- 15. goal_links -----------------------------------------------

CREATE TABLE goal_links (
    goal_id     BIGINT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    target_type TEXT   NOT NULL CHECK (target_type IN ('task','pattern')),
    target_id   BIGINT NOT NULL,
    PRIMARY KEY (goal_id, target_type, target_id)
);
COMMENT ON TABLE goal_links IS 'РџСЂРёРІСЏР·РєР° С†РµР»Рё Рє Р·Р°РґР°С‡Р°Рј/РїР°С‚С‚РµСЂРЅР°Рј. target_type РѕРїСЂРµРґРµР»СЏРµС‚, РІ РєР°РєСѓСЋ С‚Р°Р±Р»РёС†Сѓ СЃРјРѕС‚СЂРёС‚ target_id.';

-- ---------- 16. holidays --------------------------------------------------

CREATE TABLE holidays (
    id           BIGSERIAL PRIMARY KEY,
    holiday_date DATE NOT NULL UNIQUE,
    name         TEXT NOT NULL,
    is_official  BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT holidays_name_not_empty CHECK (length(btrim(name)) > 0)
);
COMMENT ON TABLE holidays IS 'Р“РѕСЃСѓРґР°СЂСЃС‚РІРµРЅРЅС‹Рµ Рё РїРѕР»СЊР·РѕРІР°С‚РµР»СЊСЃРєРёРµ РїСЂР°Р·РґРЅРёРєРё. is_official=false вЂ” СЃРѕР±СЃС‚РІРµРЅРЅС‹Рµ РїР°РјСЏС‚РЅС‹Рµ РґР°С‚С‹.';

-- ---------- 17. audit_log -------------------------------------------------

CREATE TABLE audit_log (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT REFERENCES users(id) ON DELETE SET NULL,
    table_name TEXT  NOT NULL,
    row_id     BIGINT,
    action     audit_action_enum NOT NULL,
    diff       JSONB,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE audit_log IS 'Р–СѓСЂРЅР°Р» РёР·РјРµРЅРµРЅРёР№ РєР»СЋС‡РµРІС‹С… С‚Р°Р±Р»РёС†. Р—Р°РїРѕР»РЅСЏРµС‚СЃСЏ С‚СЂРёРіРіРµСЂРѕРј trg_audit_changes.';

-- ---------- 18. app_settings ---------------------------------------------

CREATE TABLE app_settings (
    id      BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key     TEXT   NOT NULL,
    value   JSONB  NOT NULL,
    CONSTRAINT app_settings_user_key_uniq UNIQUE (user_id, key),
    CONSTRAINT app_settings_key_not_empty CHECK (length(btrim(key)) > 0)
);
COMMENT ON TABLE app_settings IS 'РџРѕР»СЊР·РѕРІР°С‚РµР»СЊСЃРєРёРµ РЅР°СЃС‚СЂРѕР№РєРё РІ РІРёРґРµ key/value.';

DO $$
BEGIN
    RAISE NOTICE 'PTT 03-tables: 23 tables created';
END $$;


-- ===== 04-indexes.sql =====

-- =============================================================================
-- 04 вЂ” РРЅРґРµРєСЃС‹.
-- РЎРј. РўР—.md, СЂР°Р·РґРµР» 4.3.1.5.
-- РўРёРїС‹ РёРЅРґРµРєСЃРѕРІ: B-tree, СЃРѕСЃС‚Р°РІРЅС‹Рµ, partial, GIN (FTS), BRIN (Р¶СѓСЂРЅР°Р»С‹).
-- =============================================================================

-- ---------- tasks ---------------------------------------------------------

CREATE INDEX idx_tasks_deadline
    ON tasks (deadline)
    WHERE deadline IS NOT NULL;
COMMENT ON INDEX idx_tasks_deadline IS 'РЎРѕСЂС‚РёСЂРѕРІРєР°/С„РёР»СЊС‚СЂ В«Р±Р»РёР¶Р°Р№С€РёРµ Р·Р°РґР°С‡РёВ».';

CREATE INDEX idx_tasks_start_at
    ON tasks (start_at)
    WHERE start_at IS NOT NULL;
COMMENT ON INDEX idx_tasks_start_at IS 'Р¤РёР»СЊС‚СЂ Р·Р°РґР°С‡ РїРѕ РЅР°С‡Р°Р»Сѓ РѕРєРЅР° РІС‹РїРѕР»РЅРµРЅРёСЏ.';

CREATE INDEX idx_tasks_topic_status
    ON tasks (topic_id, status);
COMMENT ON INDEX idx_tasks_topic_status IS 'Р“СЂСѓРїРїРёСЂРѕРІРєР° Р·Р°РґР°С‡ РїРѕ С‚РµРјР°Рј СЃ С„РёР»СЊС‚СЂРѕРј РїРѕ СЃС‚Р°С‚СѓСЃСѓ.';

CREATE INDEX idx_tasks_user_completed_at
    ON tasks (user_id, completed_at)
    WHERE completed_at IS NOT NULL;
COMMENT ON INDEX idx_tasks_user_completed_at IS 'РљР°Р»РµРЅРґР°СЂСЊ Рё СЂР°СЃС‡С‘С‚ СЃРµСЂРёР№ РІС‹РїРѕР»РЅРµРЅРёСЏ.';

CREATE INDEX idx_tasks_overdue_partial
    ON tasks (deadline)
    WHERE status = 'overdue';
COMMENT ON INDEX idx_tasks_overdue_partial IS 'РЈР·РєР°СЏ РІС‹Р±РѕСЂРєР° РїСЂРѕСЃСЂРѕС‡РµРЅРЅС‹С… Р·Р°РґР°С‡.';

CREATE INDEX idx_tasks_parent
    ON tasks (parent_task_id)
    WHERE parent_task_id IS NOT NULL;
COMMENT ON INDEX idx_tasks_parent IS 'РџРѕРёСЃРє РїРѕРґР·Р°РґР°С‡ РїРѕ СЂРѕРґРёС‚РµР»СЋ (СЂРµРєСѓСЂСЃРёРІРЅС‹Р№ CTE РІ v_task_subtree_progress).';

CREATE INDEX idx_tasks_recurring
    ON tasks (recurring_rule_id)
    WHERE recurring_rule_id IS NOT NULL;
COMMENT ON INDEX idx_tasks_recurring IS 'РџРѕРёСЃРє СЌРєР·РµРјРїР»СЏСЂРѕРІ РїРѕРІС‚РѕСЂСЏСЋС‰РµР№СЃСЏ Р·Р°РґР°С‡Рё.';

CREATE INDEX idx_tasks_search_gin
    ON tasks
    USING gin (to_tsvector('russian', coalesce(title, '') || ' ' || coalesce(description, '')));
COMMENT ON INDEX idx_tasks_search_gin IS 'РџРѕР»РЅРѕС‚РµРєСЃС‚РѕРІС‹Р№ РїРѕРёСЃРє РїРѕ Р·Р°РґР°С‡Р°Рј (СЂСѓСЃСЃРєРёР№ СЃР»РѕРІР°СЂСЊ).';

-- ---------- task_tags / task_time_logs -----------------------------------

CREATE INDEX idx_task_tags_tag
    ON task_tags (tag_id, task_id);
COMMENT ON INDEX idx_task_tags_tag IS 'РџРѕРёСЃРє Р·Р°РґР°С‡ РїРѕ С‚РµРіСѓ.';

CREATE INDEX idx_task_time_logs_task
    ON task_time_logs (task_id, started_at DESC);
COMMENT ON INDEX idx_task_time_logs_task IS 'Р–СѓСЂРЅР°Р» РІСЂРµРјРµРЅРё РїРѕ Р·Р°РґР°С‡Рµ РІ РѕР±СЂР°С‚РЅРѕРј С…СЂРѕРЅРѕР»РѕРіРёС‡РµСЃРєРѕРј РїРѕСЂСЏРґРєРµ.';

-- ---------- diary_entries / diary_tags -----------------------------------

CREATE INDEX idx_diary_fts_gin
    ON diary_entries USING gin (content_tsv);
COMMENT ON INDEX idx_diary_fts_gin IS 'РџРѕР»РЅРѕС‚РµРєСЃС‚РѕРІС‹Р№ РїРѕРёСЃРє РїРѕ РґРЅРµРІРЅРёРєСѓ.';

CREATE INDEX idx_diary_tags_tag
    ON diary_tags (tag_id, entry_id);
COMMENT ON INDEX idx_diary_tags_tag IS 'РџРѕРёСЃРє Р·Р°РїРёСЃРµР№ РґРЅРµРІРЅРёРєР° РїРѕ С‚РµРіСѓ.';

-- ---------- pattern_logs -------------------------------------------------

CREATE INDEX idx_pattern_logs_brin
    ON pattern_logs USING brin (scheduled_at);
COMMENT ON INDEX idx_pattern_logs_brin IS 'BRIN-РёРЅРґРµРєСЃ РґР»СЏ Р±РѕР»СЊС€РѕР№ С‚Р°Р±Р»РёС†С‹ Р¶СѓСЂРЅР°Р»Р° РїРѕ РІСЂРµРјРµРЅРё (СЂР°СЃС‚С‘С‚ РїРѕСЃР»РµРґРѕРІР°С‚РµР»СЊРЅРѕ).';

CREATE INDEX idx_pattern_logs_pattern_date
    ON pattern_logs (pattern_id, scheduled_at DESC);
COMMENT ON INDEX idx_pattern_logs_pattern_date IS 'Р Р°СЃС‡С‘С‚ С‚РµРєСѓС‰РµР№ СЃРµСЂРёРё (РІС‹Р±РѕСЂРєР° РїРѕСЃР»РµРґРЅРёС… N).';

CREATE INDEX idx_pattern_logs_pending
    ON pattern_logs (scheduled_at)
    WHERE status = 'pending';
COMMENT ON INDEX idx_pattern_logs_pending IS 'Р‘С‹СЃС‚СЂС‹Р№ РїРѕРёСЃРє РѕР¶РёРґР°СЋС‰РёС… РѕС‚РІРµС‚Р° Р·Р°РїРёСЃРµР№ (РґР»СЏ sp_close_overdue_pattern_logs).';

-- ---------- pattern_steps / pattern_markers ------------------------------

CREATE INDEX idx_pattern_steps_pattern ON pattern_steps (pattern_id);
COMMENT ON INDEX idx_pattern_steps_pattern IS 'РЁР°РіРё СЃС†РµРЅР°СЂРёСЏ РїРѕ РїР°С‚С‚РµСЂРЅСѓ.';

-- ---------- audit_log ----------------------------------------------------

CREATE INDEX idx_audit_log_brin
    ON audit_log USING brin (changed_at);
COMMENT ON INDEX idx_audit_log_brin IS 'BRIN-РёРЅРґРµРєСЃ РґР»СЏ Р±РѕР»СЊС€РѕРіРѕ Р¶СѓСЂРЅР°Р»Р° Р°СѓРґРёС‚Р°.';

CREATE INDEX idx_audit_log_table_row
    ON audit_log (table_name, row_id);
COMMENT ON INDEX idx_audit_log_table_row IS 'РџРѕРёСЃРє РёСЃС‚РѕСЂРёРё РёР·РјРµРЅРµРЅРёР№ РєРѕРЅРєСЂРµС‚РЅРѕР№ СЃС‚СЂРѕРєРё.';

-- ---------- goals --------------------------------------------------------

CREATE INDEX idx_goals_deadline_active
    ON goals (deadline)
    WHERE is_completed = FALSE;
COMMENT ON INDEX idx_goals_deadline_active IS 'РЎРїРёСЃРѕРє Р°РєС‚РёРІРЅС‹С… С†РµР»РµР№.';

-- ---------- recurring_rules ----------------------------------------------

CREATE INDEX idx_recurring_rules_next_run
    ON recurring_rules (next_run_at)
    WHERE is_active = TRUE;
COMMENT ON INDEX idx_recurring_rules_next_run IS 'РџР»Р°РЅРёСЂРѕРІС‰РёРє РїРѕРІС‚РѕСЂСЏСЋС‰РёС…СЃСЏ Р·Р°РґР°С‡.';

-- ---------- С‚СЂРёРіСЂР°РјРјРЅС‹Рµ РёРЅРґРµРєСЃС‹ РґР»СЏ РЅРµС‡С‘С‚РєРѕРіРѕ РїРѕРёСЃРєР° РїРѕ СЃРїСЂР°РІРѕС‡РЅРёРєР°Рј -----

CREATE INDEX idx_topics_name_trgm
    ON topics USING gin (name gin_trgm_ops);
COMMENT ON INDEX idx_topics_name_trgm IS 'РќРµС‡С‘С‚РєРёР№ РїРѕРёСЃРє С‚РµРј (autocomplete).';

CREATE INDEX idx_tags_name_trgm
    ON tags USING gin (name gin_trgm_ops);
COMMENT ON INDEX idx_tags_name_trgm IS 'РќРµС‡С‘С‚РєРёР№ РїРѕРёСЃРє С‚РµРіРѕРІ.';

DO $$
BEGIN
    RAISE NOTICE 'PTT 04-indexes: indexes created';
END $$;


-- ===== 05-functions.sql =====

-- =============================================================================
-- 05 вЂ” Р¤СѓРЅРєС†РёРё.
-- РЎРј. РўР—.md, СЂР°Р·РґРµР» 4.3.1.7. Р Р°Р·РјРµС‰РµРЅС‹ РґРѕ РїСЂРµРґСЃС‚Р°РІР»РµРЅРёР№, С‚.Рє. РЅРµРєРѕС‚РѕСЂС‹Рµ view
-- РёСЃРїРѕР»СЊР·СѓСЋС‚ С„СѓРЅРєС†РёРё (РЅР°РїСЂРёРјРµСЂ, fn_day_color).
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
    -- Р›РёРЅРµР№РЅР°СЏ РёРЅС‚РµСЂРїРѕР»СЏС†РёСЏ РјРµР¶РґСѓ #E5E7EB (СЃРµСЂС‹Р№, 0%) Рё #16A34A (РЅР°СЃС‹С‰. Р·РµР»С‘РЅС‹Р№, 100%).
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
    IS 'HEX-С†РІРµС‚ РґР»СЏ РґРЅСЏ РІ РєР°Р»РµРЅРґР°СЂРµ (РіСЂР°РґРёРµРЅС‚ СЃРµСЂС‹Р№ в†’ Р·РµР»С‘РЅС‹Р№ РїРѕ РїСЂРѕС†РµРЅС‚Сѓ РІС‹РїРѕР»РЅРµРЅРёСЏ).';

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
    IS 'РўРµРєСѓС‰Р°СЏ СЃРµСЂРёСЏ СѓСЃРїРµС€РЅС‹С… РґРЅРµР№. is_success РЅР° РѕРїС†РёСЏС… СѓР¶Рµ Р·Р°РґР°С‘С‚ СЃРµРјР°РЅС‚РёРєСѓ РґР»СЏ negative.';

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
    IS 'РњР°РєСЃРёРјР°Р»СЊРЅР°СЏ СЃРµСЂРёСЏ СѓСЃРїРµС€РЅС‹С… РґРЅРµР№ РІ РёСЃС‚РѕСЂРёРё РїР°С‚С‚РµСЂРЅР°.';

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
    IS 'Р”РµРЅСЊ СЃ Р·Р°С„РёРєСЃРёСЂРѕРІР°РЅРЅС‹Рј СЃСЂС‹РІРѕРј/РїСЂРѕРїСѓСЃРєРѕРј (РґР»СЏ anti_streak).';

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
    IS 'РўРµРєСѓС‰Р°СЏ СЃРµСЂРёСЏ РїРѕРґСЂСЏРґ РёРґСѓС‰РёС… РґРЅРµР№ СЃРѕ СЃСЂС‹РІРѕРј/РїСЂРѕРїСѓСЃРєРѕРј (negative).';

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
    IS 'РџСЂРѕС†РµРЅС‚ РІС‹РїРѕР»РЅРµРЅРёСЏ Р·Р°РґР°С‡ Р·Р° РїРµСЂРёРѕРґ СЃ РѕРїС†РёРѕРЅР°Р»СЊРЅРѕР№ С„РёР»СЊС‚СЂР°С†РёРµР№ РїРѕ С‚РµРјРµ.';

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
    IS 'РџРѕР»РЅРѕС‚РµРєСЃС‚РѕРІС‹Р№ РїРѕРёСЃРє РїРѕ РґРЅРµРІРЅРёРєСѓ СЃ РїРѕРґСЃРІРµС‚РєРѕР№ СЃРѕРІРїР°РґРµРЅРёР№.';

-- РљРѕСЂСЂРµР»СЏС†РёСЏ РЅР°СЃС‚СЂРѕРµРЅРёСЏ: v_mood_productivity_correlation (API GET /stats/correlation).

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

    -- Р”Р»СЏ tasks СѓС‡РёС‚С‹РІР°РµРј РІС‹РїРѕР»РЅРµРЅРЅС‹Рµ.
    SELECT COUNT(*) INTO v_done
      FROM goal_links gl
      JOIN tasks t ON gl.target_type = 'task' AND t.id = gl.target_id
     WHERE gl.goal_id = p_goal_id
       AND t.status = 'done';

    -- Р”Р»СЏ patterns: habit + markers + scenario (С‡РµСЂРµР· fn_pattern_day_success / sessions).
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
    IS 'РџСЂРѕРіСЂРµСЃСЃ С†РµР»Рё: Р·Р°РґР°С‡Рё done + СѓСЃРїРµС€РЅС‹Рµ РґРЅРё habit/markers/scenario.';

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
            -- isodow: 1=Mon..7=Sun; РїСЂРµРѕР±СЂР°Р·СѓРµРј РІ bit position 0..6
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
    IS 'РЎР»РµРґСѓСЋС‰Р°СЏ РґР°С‚Р° РїРѕРІС‚РѕСЂРµРЅРёСЏ: daily/weekly/monthly/custom (params.interval_days).';

-- Р’СЂРµРјСЏ РїРѕ С‚РµРјР°Рј: v_topic_time_distribution (API GET /stats/time-distribution).

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
    IS 'Р”Р°РЅРЅС‹Рµ РґР»СЏ РѕС‚СЂРёСЃРѕРІРєРё РјРµСЃСЏС†Р° РєР°Р»РµРЅРґР°СЂСЏ.';

DO $$
BEGIN
    RAISE NOTICE 'PTT 05-functions: business functions created';
END $$;


-- ===== 06-views.sql =====

-- =============================================================================
-- 06 вЂ” РџСЂРµРґСЃС‚Р°РІР»РµРЅРёСЏ (VIEW Рё MATERIALIZED VIEW).
-- РЎРј. РўР—.md, СЂР°Р·РґРµР» 4.3.1.6.
-- =============================================================================

-- РљР°Р»РµРЅРґР°СЂСЊ РјРµСЃСЏС†Р°: fn_get_calendar_stats (API /calendar/{y}/{m}).

-- ---------- 1. v_task_topic_breakdown ------------------------------------

CREATE OR REPLACE VIEW v_task_topic_breakdown AS
SELECT
    t.user_id,
    t.topic_id,
    tp.name AS topic_name,
    COUNT(*)                                                          AS total,
    COUNT(*) FILTER (WHERE t.status = 'done')                         AS done,
    COUNT(*) FILTER (WHERE t.status = 'overdue')                      AS overdue,
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE t.status = 'done') / COUNT(*), 2)
    END                                                               AS completion_rate,
    AVG(t.planned_minutes)::INT                                       AS avg_planned_minutes,
    AVG(EXTRACT(EPOCH FROM (t.completed_at - t.deadline)) / 60.0)
        FILTER (WHERE t.status = 'overdue')::NUMERIC(10,2)            AS avg_overdue_minutes
  FROM tasks t
  JOIN topics tp ON tp.id = t.topic_id
 GROUP BY t.user_id, t.topic_id, tp.name;

COMMENT ON VIEW v_task_topic_breakdown
    IS 'РђРіСЂРµРіР°С‚С‹ РїРѕ С‚РµРјР°Рј: total, done, overdue, % РІС‹РїРѕР»РЅРµРЅРёСЏ, СЃСЂРµРґРЅРµРµ РїР»Р°РЅРѕРІРѕРµ, СЃСЂРµРґРЅСЏСЏ РїСЂРѕСЃСЂРѕС‡РєР°.';

-- ---------- 3. v_pattern_streaks -----------------------------------------

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
    IS 'РЎРµСЂРёРё: current/max вЂ” СѓСЃРїРµС€РЅС‹Рµ РґРЅРё; anti_streak вЂ” РїРѕРґСЂСЏРґ СЃСЂС‹РІРѕРІ (negative).';

-- ---------- 4. v_overdue_tasks (MATERIALIZED) ----------------------------

CREATE MATERIALIZED VIEW v_overdue_tasks AS
SELECT
    t.id,
    t.user_id,
    t.topic_id,
    t.title,
    t.priority,
    t.deadline,
    t.completed_at,
    EXTRACT(EPOCH FROM (COALESCE(t.completed_at, now()) - t.deadline)) / 60.0 AS overdue_minutes
  FROM tasks t
 WHERE t.status = 'overdue'
WITH NO DATA;

CREATE UNIQUE INDEX v_overdue_tasks_pk ON v_overdue_tasks (id);
CREATE INDEX        v_overdue_tasks_user ON v_overdue_tasks (user_id, deadline);

COMMENT ON MATERIALIZED VIEW v_overdue_tasks
    IS 'РЎРїРёСЃРѕРє РїСЂРѕСЃСЂРѕС‡РµРЅРЅС‹С… Р·Р°РґР°С‡. РћР±РЅРѕРІР»СЏРµС‚СЃСЏ sp_recalc_calendar_cache.';

-- ---------- 5. v_mood_productivity_correlation ---------------------------

CREATE OR REPLACE VIEW v_mood_productivity_correlation AS
WITH days AS (
    SELECT
        de.user_id,
        de.entry_date AS day,
        de.mood,
        de.energy
      FROM diary_entries de
),
task_day AS (
    SELECT
        t.user_id,
        t.deadline::date AS day,
        CASE WHEN COUNT(*) = 0 THEN NULL
             ELSE 100.0 * COUNT(*) FILTER (WHERE t.status = 'done') / COUNT(*)
        END AS rate
      FROM tasks t
     WHERE t.deadline IS NOT NULL
     GROUP BY t.user_id, t.deadline::date
),
joined AS (
    SELECT d.user_id, d.day, d.mood, d.energy, td.rate
      FROM days d
      JOIN task_day td ON td.user_id = d.user_id AND td.day = d.day
)
SELECT
    user_id,
    date_trunc('week', day)::date           AS week_start,
    AVG(mood)::NUMERIC(4,2)                 AS avg_mood,
    AVG(energy)::NUMERIC(4,2)               AS avg_energy,
    AVG(rate)::NUMERIC(5,2)                 AS avg_completion_rate,
    corr(mood::numeric, rate)               AS corr_mood_rate,
    corr(energy::numeric, rate)             AS corr_energy_rate,
    COUNT(*)                                AS days_count
  FROM joined
 GROUP BY user_id, date_trunc('week', day);

COMMENT ON VIEW v_mood_productivity_correlation
    IS 'РџРѕ РЅРµРґРµР»СЏРј: СЃСЂРµРґРЅРёРµ mood/energy, % РІС‹РїРѕР»РЅРµРЅРёСЏ, РєРѕСЂСЂРµР»СЏС†РёРё РџРёСЂСЃРѕРЅР°.';

-- ---------- 5b. OLAP daily facts + holistic + task priority ------------

CREATE OR REPLACE VIEW v_olap_daily_facts AS
WITH activity_days AS (
    SELECT user_id, day FROM (
        SELECT user_id, deadline::date AS day
          FROM tasks WHERE deadline IS NOT NULL
        UNION
        SELECT user_id, entry_date AS day FROM diary_entries
        UNION
        SELECT bp.user_id, date_trunc('day', pl.scheduled_at)::date AS day
          FROM pattern_logs pl
          JOIN behavior_patterns bp ON bp.id = pl.pattern_id
         WHERE pl.status = 'answered'
        UNION
        SELECT bp.user_id, pm.occurred_at::date AS day
          FROM pattern_markers pm
          JOIN behavior_patterns bp ON bp.id = pm.pattern_id
        UNION
        SELECT bp.user_id, pds.session_date AS day
          FROM pattern_day_sessions pds
          JOIN behavior_patterns bp ON bp.id = pds.pattern_id
        UNION
        SELECT user_id, started_at::date AS day FROM task_time_logs
    ) u
),
task_m AS (
    SELECT user_id, deadline::date AS day,
           COUNT(*)::INT                                              AS tasks_total,
           COUNT(*) FILTER (WHERE status = 'done')::INT               AS tasks_done,
           COUNT(*) FILTER (WHERE status = 'overdue')::INT              AS tasks_overdue,
           COUNT(*) FILTER (WHERE status = 'in_progress')::INT        AS tasks_in_progress,
           COUNT(*) FILTER (WHERE status = 'pending')::INT            AS tasks_pending
      FROM tasks WHERE deadline IS NOT NULL
     GROUP BY user_id, deadline::date
),
time_m AS (
    SELECT user_id, started_at::date AS day,
           COALESCE(SUM(duration_seconds), 0)::INT / 60                 AS minutes_logged,
           COALESCE(SUM(duration_seconds) FILTER (WHERE is_pomodoro), 0)::INT / 60 AS pomodoro_minutes,
           COUNT(*)::INT                                                AS time_log_count
      FROM task_time_logs
     GROUP BY user_id, started_at::date
),
diary_m AS (
    SELECT user_id, entry_date AS day,
           mood, energy, 1 AS diary_entries
      FROM diary_entries
),
marker_m AS (
    SELECT bp.user_id, pm.occurred_at::date AS day,
           COUNT(*)::INT AS marker_events,
           COUNT(*) FILTER (WHERE NOT o.is_success)::INT AS marker_bad_events
      FROM pattern_markers pm
      JOIN behavior_patterns bp ON bp.id = pm.pattern_id
      JOIN pattern_response_options o ON o.id = pm.marker_option_id
     GROUP BY bp.user_id, pm.occurred_at::date
)
SELECT
    ad.user_id,
    ad.day,
    EXTRACT(ISODOW FROM ad.day)::INT AS dow,
    COALESCE(tm.tasks_total, 0)         AS tasks_total,
    COALESCE(tm.tasks_done, 0)          AS tasks_done,
    COALESCE(tm.tasks_overdue, 0)       AS tasks_overdue,
    COALESCE(tm.tasks_in_progress, 0)   AS tasks_in_progress,
    COALESCE(tm.tasks_pending, 0)       AS tasks_pending,
    COALESCE(tlm.minutes_logged, 0)     AS minutes_logged,
    COALESCE(tlm.pomodoro_minutes, 0)   AS pomodoro_minutes,
    COALESCE(tlm.time_log_count, 0)     AS time_log_count,
    COALESCE(dm.diary_entries, 0)       AS diary_entries,
    dm.mood,
    dm.energy,
    CASE
        WHEN dm.mood IS NULL THEN 'none'
        WHEN dm.mood <= 2 THEN 'low'
        WHEN dm.mood = 3 THEN 'mid'
        ELSE 'high'
    END AS mood_bucket,
    CASE
        WHEN dm.energy IS NULL THEN 'none'
        WHEN dm.energy <= 2 THEN 'low'
        WHEN dm.energy = 3 THEN 'mid'
        ELSE 'high'
    END AS energy_bucket,
    (
        SELECT COUNT(*)::INT FROM behavior_patterns bp
         WHERE bp.user_id = ad.user_id AND fn_pattern_is_scheduled(bp.id, ad.day)
    ) AS patterns_scheduled,
    (
        SELECT COUNT(*)::INT FROM behavior_patterns bp
         WHERE bp.user_id = ad.user_id
           AND fn_pattern_is_scheduled(bp.id, ad.day)
           AND fn_pattern_day_success(bp.id, ad.day)
    ) AS patterns_success,
    (
        SELECT COUNT(*)::INT FROM behavior_patterns bp
         WHERE bp.user_id = ad.user_id AND fn_pattern_day_has_answer(bp.id, ad.day)
    ) AS patterns_answered,
    COALESCE(mm.marker_events, 0)     AS marker_events,
    COALESCE(mm.marker_bad_events, 0) AS marker_bad_events,
    (
        COALESCE(tm.tasks_total, 0)
        + COALESCE(dm.diary_entries, 0)
        + COALESCE((
            SELECT COUNT(*)::INT FROM behavior_patterns bp
             WHERE bp.user_id = ad.user_id AND fn_pattern_day_has_answer(bp.id, ad.day)
        ), 0)
    )::INT AS activity_score
  FROM activity_days ad
  LEFT JOIN task_m tm ON tm.user_id = ad.user_id AND tm.day = ad.day
  LEFT JOIN time_m tlm ON tlm.user_id = ad.user_id AND tlm.day = ad.day
  LEFT JOIN diary_m dm ON dm.user_id = ad.user_id AND dm.day = ad.day
  LEFT JOIN marker_m mm ON mm.user_id = ad.user_id AND mm.day = ad.day;

COMMENT ON VIEW v_olap_daily_facts IS
    'OLAP-С„Р°РєС‚С‹: grain userГ—day. Р—Р°РґР°С‡Рё, РІСЂРµРјСЏ, РґРЅРµРІРЅРёРє, РїР°С‚С‚РµСЂРЅС‹, РјРµС‚РєРё.';

CREATE OR REPLACE VIEW v_mood_holistic_correlation AS
WITH base AS (
    SELECT
        f.user_id,
        f.day,
        f.mood,
        f.energy,
        CASE WHEN f.tasks_total = 0 THEN NULL
             ELSE 100.0 * f.tasks_done / f.tasks_total END AS task_rate,
        CASE WHEN f.patterns_scheduled = 0 THEN NULL
             ELSE 100.0 * f.patterns_success / f.patterns_scheduled END AS pattern_clean_rate,
        f.minutes_logged,
        f.marker_bad_events
      FROM v_olap_daily_facts f
     WHERE f.mood IS NOT NULL
)
SELECT
    user_id,
    date_trunc('week', day)::date AS week_start,
    AVG(mood)::NUMERIC(4,2)       AS avg_mood,
    AVG(energy)::NUMERIC(4,2)     AS avg_energy,
    AVG(task_rate)::NUMERIC(5,2)  AS avg_task_rate,
    AVG(pattern_clean_rate)::NUMERIC(5,2) AS avg_pattern_clean_rate,
    AVG(minutes_logged)::NUMERIC(8,2) AS avg_minutes,
    corr(mood::numeric, task_rate) AS corr_mood_tasks,
    corr(mood::numeric, pattern_clean_rate) AS corr_mood_patterns,
    corr(energy::numeric, task_rate) AS corr_energy_tasks,
    COUNT(*) AS days_count
  FROM base
 GROUP BY user_id, date_trunc('week', day);

COMMENT ON VIEW v_mood_holistic_correlation IS
    'РќРµРґРµР»СЊРЅР°СЏ РєРѕСЂСЂРµР»СЏС†РёСЏ: РЅР°СЃС‚СЂРѕРµРЅРёРµ/СЌРЅРµСЂРіРёСЏ в†” Р·Р°РґР°С‡Рё Рё РїР°С‚С‚РµСЂРЅС‹.';

CREATE OR REPLACE VIEW v_stats_task_priority AS
SELECT
    t.user_id,
    t.priority,
    COUNT(*)::INT AS total,
    COUNT(*) FILTER (WHERE t.status = 'done')::INT AS done,
    COUNT(*) FILTER (WHERE t.status = 'overdue')::INT AS overdue,
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE t.status = 'done') / COUNT(*), 2)
    END AS completion_rate
  FROM tasks t
 GROUP BY t.user_id, t.priority;

-- ---------- 6. v_weekly_summary ------------------------------------------

DROP VIEW IF EXISTS v_weekly_summary;
CREATE VIEW v_weekly_summary AS
WITH task_week AS (
    SELECT
        t.user_id,
        date_trunc('week', t.deadline)::date AS week_start,
        COUNT(*)                                       AS tasks_total,
        COUNT(*) FILTER (WHERE t.status = 'done')      AS tasks_done,
        COUNT(*) FILTER (WHERE t.status = 'overdue')   AS tasks_overdue
      FROM tasks t
     WHERE t.deadline IS NOT NULL
     GROUP BY t.user_id, date_trunc('week', t.deadline)::date
),
time_week AS (
    SELECT
        ttl.user_id,
        date_trunc('week', ttl.started_at)::date AS week_start,
        SUM(ttl.duration_seconds) / 60 AS minutes_logged
      FROM task_time_logs ttl
     GROUP BY ttl.user_id, date_trunc('week', ttl.started_at)::date
),
diary_week AS (
    SELECT
        de.user_id,
        date_trunc('week', de.entry_date)::date AS week_start,
        COUNT(*) AS diary_entries,
        AVG(de.mood)::NUMERIC(4,2) AS avg_mood,
        AVG(de.energy)::NUMERIC(4,2) AS avg_energy
      FROM diary_entries de
     GROUP BY de.user_id, date_trunc('week', de.entry_date)::date
),
pattern_week AS (
    SELECT
        user_id,
        date_trunc('week', day)::date AS week_start,
        SUM(patterns_scheduled)::INT AS patterns_scheduled,
        SUM(patterns_success)::INT AS patterns_success,
        SUM(marker_events)::INT AS marker_events,
        SUM(marker_bad_events)::INT AS marker_bad_events
      FROM v_olap_daily_facts
     GROUP BY user_id, date_trunc('week', day)::date
),
weeks AS (
    SELECT user_id, week_start FROM task_week
    UNION
    SELECT user_id, week_start FROM time_week
    UNION
    SELECT user_id, week_start FROM diary_week
    UNION
    SELECT user_id, week_start FROM pattern_week
)
SELECT
    w.user_id,
    w.week_start,
    COALESCE(tw.tasks_total, 0)::INT AS tasks_total,
    COALESCE(tw.tasks_done, 0)::INT AS tasks_done,
    COALESCE(tw.tasks_overdue, 0)::INT AS tasks_overdue,
    COALESCE(time_week.minutes_logged, 0)::INT AS minutes_logged,
    COALESCE(diary_week.diary_entries, 0)::INT AS diary_entries,
    diary_week.avg_mood,
    diary_week.avg_energy,
    COALESCE(pw.patterns_scheduled, 0)::INT AS patterns_scheduled,
    COALESCE(pw.patterns_success, 0)::INT AS patterns_success,
    COALESCE(pw.marker_events, 0)::INT AS marker_events,
    COALESCE(pw.marker_bad_events, 0)::INT AS marker_bad_events
  FROM weeks w
  LEFT JOIN task_week tw ON tw.user_id = w.user_id AND tw.week_start = w.week_start
  LEFT JOIN time_week ON time_week.user_id = w.user_id AND time_week.week_start = w.week_start
  LEFT JOIN diary_week ON diary_week.user_id = w.user_id AND diary_week.week_start = w.week_start
  LEFT JOIN pattern_week pw ON pw.user_id = w.user_id AND pw.week_start = w.week_start;

COMMENT ON VIEW v_weekly_summary
    IS 'РЎРІРѕРґРєР° Р·Р° РЅРµРґРµР»СЋ: Р·Р°РґР°С‡Рё, РІСЂРµРјСЏ, РґРЅРµРІРЅРёРє, РїР°С‚С‚РµСЂРЅС‹, markers.';

-- ---------- 7. v_year_heatmap --------------------------------------------

CREATE OR REPLACE VIEW v_year_heatmap AS
SELECT user_id, day, SUM(activity)::INT AS activity
  FROM (
    SELECT user_id, deadline::date AS day, 1 AS activity FROM tasks WHERE deadline IS NOT NULL
    UNION ALL
    SELECT user_id, entry_date AS day, 1 FROM diary_entries
    UNION ALL
    SELECT bp.user_id, date_trunc('day', pl.scheduled_at)::date AS day, 1
      FROM pattern_logs pl JOIN behavior_patterns bp ON bp.id = pl.pattern_id
    UNION ALL
    SELECT bp.user_id, pm.occurred_at::date AS day, 1
      FROM pattern_markers pm JOIN behavior_patterns bp ON bp.id = pm.pattern_id
    UNION ALL
    SELECT bp.user_id, pds.session_date AS day, 1
      FROM pattern_day_sessions pds JOIN behavior_patterns bp ON bp.id = pds.pattern_id
    UNION ALL
    SELECT user_id, started_at::date AS day, 1 FROM task_time_logs
  ) u
 GROUP BY user_id, day;

COMMENT ON VIEW v_year_heatmap
    IS 'РўРµРїР»РѕРІР°СЏ РєР°СЂС‚Р° Р°РєС‚РёРІРЅРѕСЃС‚Рё: Р·Р°РґР°С‡Рё, РґРЅРµРІРЅРёРє, РїР°С‚С‚РµСЂРЅС‹, РјРµС‚РєРё, СЃРµСЃСЃРёРё, РІСЂРµРјСЏ.';

-- РџСЂРѕРіСЂРµСЃСЃ С†РµР»РµР№: fn_goal_progress (API GET /goals/{id}/progress).

-- ---------- 8. v_task_subtree_progress (СЂРµРєСѓСЂСЃРёРІРЅС‹Р№ CTE) -----------------

CREATE OR REPLACE VIEW v_task_subtree_progress AS
WITH RECURSIVE tree AS (
    SELECT id, parent_task_id, status,
           id AS root_id
      FROM tasks
     WHERE parent_task_id IS NULL
    UNION ALL
    SELECT t.id, t.parent_task_id, t.status,
           tr.root_id
      FROM tasks t
      JOIN tree tr ON tr.id = t.parent_task_id
)
SELECT
    root_id AS task_id,
    COUNT(*) - 1                                AS subtask_total,
    COUNT(*) FILTER (WHERE status = 'done') - CASE
        WHEN MAX(CASE WHEN id = root_id AND status = 'done' THEN 1 ELSE 0 END) = 1 THEN 1
        ELSE 0
    END                                          AS subtask_done,
    CASE
        WHEN COUNT(*) - 1 = 0 THEN
            CASE WHEN MAX(CASE WHEN id = root_id AND status = 'done' THEN 1 ELSE 0 END) = 1 THEN 100 ELSE 0 END
        ELSE
            ROUND(
                100.0 * (COUNT(*) FILTER (WHERE status = 'done')
                  - CASE WHEN MAX(CASE WHEN id = root_id AND status = 'done' THEN 1 ELSE 0 END) = 1 THEN 1 ELSE 0 END)
                / (COUNT(*) - 1), 2
            )
    END                                          AS progress
  FROM tree
 GROUP BY root_id;

COMMENT ON VIEW v_task_subtree_progress
    IS 'РџСЂРѕРіСЂРµСЃСЃ РєРѕСЂРЅРµРІРѕР№ Р·Р°РґР°С‡Рё РЅР° РѕСЃРЅРѕРІРµ РµС‘ РїРѕРґР·Р°РґР°С‡ (СЂРµРєСѓСЂСЃРёРІРЅС‹Р№ CTE).';

-- ---------- 9. v_topic_time_distribution ---------------------------------

CREATE OR REPLACE VIEW v_topic_time_distribution AS
SELECT
    t.user_id,
    t.topic_id,
    tp.name AS topic_name,
    COALESCE(SUM(ttl.duration_seconds), 0) / 60 AS minutes,
    COALESCE(SUM(ttl.duration_seconds) FILTER (WHERE ttl.is_pomodoro), 0) / 60 AS pomodoro_minutes
  FROM tasks t
  JOIN topics tp ON tp.id = t.topic_id
  LEFT JOIN task_time_logs ttl ON ttl.task_id = t.id
 GROUP BY t.user_id, t.topic_id, tp.name;

COMMENT ON VIEW v_topic_time_distribution
    IS 'Р Р°СЃРїСЂРµРґРµР»РµРЅРёРµ С„Р°РєС‚РёС‡РµСЃРєРѕРіРѕ РІСЂРµРјРµРЅРё РїРѕ С‚РµРјР°Рј (РІСЃС‘ РІСЂРµРјСЏ Рё РѕС‚РґРµР»СЊРЅРѕ Pomodoro).';

DO $$
BEGIN
    RAISE NOTICE 'PTT 06-views: 11 views (incl. 1 materialized) created';
END $$;


-- ===== 07-procedures.sql =====

-- =============================================================================
-- 07 вЂ” РҐСЂР°РЅРёРјС‹Рµ РїСЂРѕС†РµРґСѓСЂС‹ (CREATE PROCEDURE).
-- РЎРј. РўР—.md, СЂР°Р·РґРµР» 4.3.1.8.
-- =============================================================================

-- ---------- 1. sp_complete_task ------------------------------------------

CREATE OR REPLACE PROCEDURE sp_complete_task(p_task_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE tasks
       SET status       = 'done',
           completed_at = COALESCE(completed_at, now()),
           updated_at   = now()
     WHERE id = p_task_id
       AND status NOT IN ('done', 'cancelled');
    -- РўСЂРёРіРіРµСЂ trg_task_overdue_check РІС‹СЃС‚Р°РІРёС‚ 'overdue' РїСЂРё РЅР°СЂСѓС€РµРЅРёРё РґРµРґР»Р°Р№РЅР°.
    IF NOT FOUND THEN
        RAISE NOTICE 'sp_complete_task: Р·Р°РґР°С‡Р° % СѓР¶Рµ РІС‹РїРѕР»РЅРµРЅР°/РѕС‚РјРµРЅРµРЅР° РёР»Рё РЅРµ РЅР°Р№РґРµРЅР°', p_task_id;
    END IF;
END;
$$;
COMMENT ON PROCEDURE sp_complete_task(BIGINT)
    IS 'РђС‚РѕРјР°СЂРЅРѕ РѕС‚РјРµС‚РёС‚СЊ Р·Р°РґР°С‡Сѓ РІС‹РїРѕР»РЅРµРЅРЅРѕР№ СЃ РїСЂРѕСЃС‚Р°РІР»РµРЅРёРµРј completed_at = now().';

-- ---------- 1b. sp_reopen_task -------------------------------------------

CREATE OR REPLACE PROCEDURE sp_reopen_task(p_task_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE tasks
       SET status       = 'in_progress',
           completed_at = NULL,
           updated_at   = now()
     WHERE id = p_task_id
       AND status IN ('done', 'overdue');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'sp_reopen_task: Р·Р°РґР°С‡Р° % РЅРµ РЅР°Р№РґРµРЅР° РёР»Рё РЅРµ РІ СЃС‚Р°С‚СѓСЃРµ done/overdue', p_task_id;
    END IF;
END;
$$;
COMMENT ON PROCEDURE sp_reopen_task(BIGINT)
    IS 'Р’РµСЂРЅСѓС‚СЊ РІС‹РїРѕР»РЅРµРЅРЅСѓСЋ/РїСЂРѕСЃСЂРѕС‡РµРЅРЅСѓСЋ Р·Р°РґР°С‡Сѓ РІ СЂР°Р±РѕС‚Сѓ, СЃР±СЂРѕСЃРёРІ completed_at.';

-- ---------- 2. sp_log_pattern_response -----------------------------------

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
COMMENT ON PROCEDURE sp_log_pattern_response(BIGINT, BIGINT, TIMESTAMPTZ)
    IS 'Р—Р°С„РёРєСЃРёСЂРѕРІР°С‚СЊ РѕС‚РІРµС‚ РїРѕР»СЊР·РѕРІР°С‚РµР»СЏ РЅР° РїР°С‚С‚РµСЂРЅ. РћР±РЅРѕРІР»СЏРµС‚ pending РёР»Рё РІСЃС‚Р°РІР»СЏРµС‚ РЅРѕРІСѓСЋ Р·Р°РїРёСЃСЊ.';

-- ---------- 3. sp_spawn_recurring_tasks ----------------------------------

CREATE OR REPLACE PROCEDURE sp_spawn_recurring_tasks(p_date DATE DEFAULT current_date)
LANGUAGE plpgsql
AS $$
DECLARE
    rec  RECORD;
    v_next DATE;
BEGIN
    -- Р”Р»СЏ РєР°Р¶РґРѕРіРѕ Р°РєС‚РёРІРЅРѕРіРѕ РїСЂР°РІРёР»Р°, С‡РµР№ next_run_at <= p_date, СЃРѕР·РґР°С‘Рј СЌРєР·РµРјРїР»СЏСЂ-Р·Р°РґР°С‡Сѓ
    -- РїСѓС‚С‘Рј РєРѕРїРёСЂРѕРІР°РЅРёСЏ РїРѕСЃР»РµРґРЅРµР№ СЃРІСЏР·Р°РЅРЅРѕР№ Р·Р°РґР°С‡Рё (РµС‘ title/description/topic_id).
    FOR rec IN
        SELECT rr.id AS rule_id,
               (
                   SELECT t.id FROM tasks t
                    WHERE t.recurring_rule_id = rr.id
                    ORDER BY t.created_at DESC LIMIT 1
               ) AS source_task_id
          FROM recurring_rules rr
         WHERE rr.is_active = TRUE
           AND (rr.next_run_at IS NULL OR rr.next_run_at::date <= p_date)
    LOOP
        IF rec.source_task_id IS NOT NULL
           AND NOT EXISTS (
               SELECT 1 FROM tasks t
                WHERE t.recurring_rule_id = rec.rule_id
                  AND t.status IN ('pending', 'in_progress', 'overdue')
           ) THEN
            INSERT INTO tasks (
                user_id, topic_id, recurring_rule_id,
                title, description, priority,
                deadline, planned_minutes
            )
            SELECT
                user_id, topic_id, rec.rule_id,
                title, description, priority,
                p_date::timestamptz + INTERVAL '23 hours 59 minutes', planned_minutes
              FROM tasks WHERE id = rec.source_task_id;
        END IF;
        v_next := fn_next_recurring_date(rec.rule_id, p_date);
        UPDATE recurring_rules SET next_run_at = v_next WHERE id = rec.rule_id;
    END LOOP;
END;
$$;
COMMENT ON PROCEDURE sp_spawn_recurring_tasks(DATE)
    IS 'РџРѕСЂРѕРґРёС‚СЊ СЌРєР·РµРјРїР»СЏСЂС‹ РїРѕРІС‚РѕСЂСЏСЋС‰РёС…СЃСЏ Р·Р°РґР°С‡ РЅР° РґР°С‚Сѓ.';

-- ---------- 4. sp_close_overdue_pattern_logs -----------------------------

CREATE OR REPLACE PROCEDURE sp_close_overdue_pattern_logs(
    p_now TIMESTAMPTZ DEFAULT now()
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE pattern_logs
       SET status = 'missed'
     WHERE status = 'pending'
       AND scheduled_at < p_now - INTERVAL '12 hours';
END;
$$;
COMMENT ON PROCEDURE sp_close_overdue_pattern_logs(TIMESTAMPTZ)
    IS 'РџРµСЂРµРІРµСЃС‚Рё РїСЂРѕСЃСЂРѕС‡РµРЅРЅС‹Рµ РѕР¶РёРґР°РЅРёСЏ РѕС‚РІРµС‚Р° РІ СЃС‚Р°С‚СѓСЃ missed.';

-- ---------- 4b. sp_ensure_habit_logs_for_day ------------------------------

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
    IS 'РЎРѕР·РґР°С‚СЊ pending-Р·Р°РїРёСЃСЊ habit РЅР° РґРµРЅСЊ РїРѕ СЂР°СЃРїРёСЃР°РЅРёСЋ (РґР»СЏ sp_close_overdue_pattern_logs).';

-- ---------- 5. sp_archive_old_audit --------------------------------------

CREATE OR REPLACE PROCEDURE sp_archive_old_audit(p_keep_days INT DEFAULT 365)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM audit_log
     WHERE changed_at < now() - (p_keep_days || ' days')::interval;
END;
$$;
COMMENT ON PROCEDURE sp_archive_old_audit(INT)
    IS 'РЈРґР°Р»РёС‚СЊ Р·Р°РїРёСЃРё Р¶СѓСЂРЅР°Р»Р° Р°СѓРґРёС‚Р° СЃС‚Р°СЂС€Рµ N РґРЅРµР№.';

-- ---------- 6. sp_recalc_calendar_cache ----------------------------------

CREATE OR REPLACE PROCEDURE sp_recalc_calendar_cache()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW v_overdue_tasks;
END;
$$;
COMMENT ON PROCEDURE sp_recalc_calendar_cache()
    IS 'РџРµСЂРµСЃС‡РёС‚Р°С‚СЊ РјР°С‚РµСЂРёР°Р»РёР·РѕРІР°РЅРЅРѕРµ РїСЂРµРґСЃС‚Р°РІР»РµРЅРёРµ РїСЂРѕСЃСЂРѕС‡РµРє.';

-- ---------- 7. sp_export_user_data ---------------------------------------

CREATE OR REPLACE PROCEDURE sp_export_user_data(
    p_user_id BIGINT,
    INOUT p_json JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    p_json := jsonb_build_object(
        'schema_version', 2,
        'exported_at',    now(),
        'user',           (SELECT to_jsonb(u) FROM users u WHERE u.id = p_user_id),
        'topics',         COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM topics  x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'tags',           COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM tags    x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'recurring_rules', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM recurring_rules x
                                     WHERE x.id IN (
                                         SELECT DISTINCT t.recurring_rule_id FROM tasks t
                                          WHERE t.user_id = p_user_id AND t.recurring_rule_id IS NOT NULL
                                     )), '[]'::jsonb),
        'tasks',          COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM tasks   x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'task_tags',      COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM task_tags x
                                      JOIN tasks t ON t.id = x.task_id
                                     WHERE t.user_id = p_user_id), '[]'::jsonb),
        'task_time_logs', COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM task_time_logs x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'diary_entries',  COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM diary_entries  x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'diary_tags',     COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM diary_tags x
                                      JOIN diary_entries de ON de.id = x.entry_id
                                     WHERE de.user_id = p_user_id), '[]'::jsonb),
        'patterns',       COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM behavior_patterns x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'pattern_options',COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_response_options x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_schedules', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_schedules x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_steps',  COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_steps x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_logs',   COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_logs x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_markers', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_markers x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_marker_day_closures', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_marker_day_closures x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_day_sessions', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_day_sessions x
                                      JOIN behavior_patterns bp ON bp.id = x.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'pattern_step_answers', COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM pattern_step_answers x
                                      JOIN pattern_day_sessions s ON s.id = x.session_id
                                      JOIN behavior_patterns bp ON bp.id = s.pattern_id
                                     WHERE bp.user_id = p_user_id), '[]'::jsonb),
        'goals',          COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM goals x WHERE x.user_id = p_user_id), '[]'::jsonb),
        'goal_links',     COALESCE((SELECT jsonb_agg(to_jsonb(x))
                                      FROM goal_links x
                                      JOIN goals g ON g.id = x.goal_id
                                     WHERE g.user_id = p_user_id), '[]'::jsonb),
        'app_settings',   COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM app_settings x WHERE x.user_id = p_user_id), '[]'::jsonb)
    );
END;
$$;
COMMENT ON PROCEDURE sp_export_user_data(BIGINT, JSONB)
    IS 'Р­РєСЃРїРѕСЂС‚ РІСЃРµС… РґР°РЅРЅС‹С… РїРѕР»СЊР·РѕРІР°С‚РµР»СЏ РІ РѕРґРёРЅ JSONB-РґРѕРєСѓРјРµРЅС‚.';

-- ---------- 8. sp_import_user_data ---------------------------------------

CREATE OR REPLACE PROCEDURE sp_import_user_data(
    p_user_id BIGINT,
    p_json    JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_topic JSONB;
    v_tag   JSONB;
BEGIN
    -- РРґРµРјРїРѕС‚РµРЅС‚РЅР°СЏ РІСЃС‚Р°РІРєР° РїРѕ РЅР°С‚СѓСЂР°Р»СЊРЅС‹Рј РєР»СЋС‡Р°Рј (РёРјСЏ С‚РµРјС‹/С‚РµРіР° РІ СЂР°РјРєР°С… РїРѕР»СЊР·РѕРІР°С‚РµР»СЏ).
    FOR v_topic IN SELECT * FROM jsonb_array_elements(COALESCE(p_json->'topics', '[]'::jsonb)) LOOP
        INSERT INTO topics (user_id, name, color)
        VALUES (p_user_id, v_topic->>'name', COALESCE((v_topic->>'color')::hex_color, '#3B82F6'))
        ON CONFLICT (user_id, name) DO UPDATE
           SET color = EXCLUDED.color;
    END LOOP;

    FOR v_tag IN SELECT * FROM jsonb_array_elements(COALESCE(p_json->'tags', '[]'::jsonb)) LOOP
        INSERT INTO tags (user_id, name)
        VALUES (p_user_id, v_tag->>'name')
        ON CONFLICT (user_id, name) DO NOTHING;
    END LOOP;

    -- РџРѕР»РЅР°СЏ СЂРµР°Р»РёР·Р°С†РёСЏ РѕСЃС‚Р°Р»СЊРЅС‹С… С‚Р°Р±Р»РёС† вЂ” Р·Р°РґР°С‡Р° СЂР°СЃС€РёСЂРµРЅРёСЏ. РќР° СЌС‚РѕР№ СЃС‚Р°РґРёРё
    -- РёРјРїРѕСЂС‚РёСЂСѓСЋС‚СЃСЏ СЃРїСЂР°РІРѕС‡РЅРёРєРё, РѕСЃС‚Р°Р»СЊРЅС‹Рµ СЃСѓС‰РЅРѕСЃС‚Рё С‡РµСЂРµР· REST API.
END;
$$;
COMMENT ON PROCEDURE sp_import_user_data(BIGINT, JSONB)
    IS 'РРґРµРјРїРѕС‚РµРЅС‚РЅС‹Р№ РёРјРїРѕСЂС‚ СЃРїСЂР°РІРѕС‡РЅРёРєРѕРІ РёР· JSON-РґРѕРєСѓРјРµРЅС‚Р°.';

DO $$
BEGIN
    RAISE NOTICE 'PTT 07-procedures: stored procedures created';
END $$;


-- ===== 08-triggers.sql =====

-- =============================================================================
-- 08 вЂ” РўСЂРёРіРіРµСЂС‹.
-- РЎРј. РўР—.md, СЂР°Р·РґРµР» 4.3.1.9.
-- РўСЂРёРіРіРµСЂС‹ СЂРµР°Р»РёР·РѕРІР°РЅС‹ РїР°СЂР°РјРё В«С„СѓРЅРєС†РёСЏ-РѕР±СЂР°Р±РѕС‚С‡РёРє + CREATE TRIGGERВ».
-- =============================================================================

-- ---------- 1. trg_set_updated_at (РѕР±С‰РёР№ РѕР±СЂР°Р±РѕС‚С‡РёРє) ---------------------

CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tasks_updated_at              BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_diary_entries_updated_at      BEFORE UPDATE ON diary_entries
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_behavior_patterns_updated_at  BEFORE UPDATE ON behavior_patterns
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_goals_updated_at              BEFORE UPDATE ON goals
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

COMMENT ON FUNCTION fn_set_updated_at() IS 'РћР±СЂР°Р±РѕС‚С‡РёРє BEFORE UPDATE РґР»СЏ РїРѕРґРґРµСЂР¶Р°РЅРёСЏ updated_at.';

-- ---------- 2. trg_task_set_completed_at ---------------------------------

CREATE OR REPLACE FUNCTION fn_task_set_completed_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status
       AND NEW.status = 'done'
       AND NEW.completed_at IS NULL THEN
        NEW.completed_at := now();
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_task_set_completed_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION fn_task_set_completed_at();

COMMENT ON FUNCTION fn_task_set_completed_at()
    IS 'РђРІС‚РѕРјР°С‚РёС‡РµСЃРєРё РїСЂРѕСЃС‚Р°РІР»СЏРµС‚ completed_at = now() РїСЂРё РїРµСЂРµС…РѕРґРµ СЃС‚Р°С‚СѓСЃР° РІ done.';

-- ---------- 3. trg_task_overdue_check ------------------------------------

CREATE OR REPLACE FUNCTION fn_task_overdue_check()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'done'
       AND NEW.completed_at IS NOT NULL
       AND NEW.deadline    IS NOT NULL
       AND NEW.planned_minutes IS NOT NULL
       AND NEW.completed_at > NEW.deadline THEN
        NEW.status := 'overdue';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_task_overdue_check
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION fn_task_overdue_check();

COMMENT ON FUNCTION fn_task_overdue_check()
    IS 'Р•СЃР»Рё Р·Р°РґР°С‡Р° Р·Р°РІРµСЂС€РµРЅР° РїРѕР·Р¶Рµ РґРµРґР»Р°Р№РЅР° Рё Р±С‹Р» СѓРєР°Р·Р°РЅ РїР»Р°РЅРѕРІС‹Р№ РїРµСЂРёРѕРґ вЂ” СЃС‚Р°С‚СѓСЃ overdue.';

-- ---------- 4. trg_diary_tsv_update --------------------------------------

CREATE OR REPLACE FUNCTION fn_diary_tsv_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.content_tsv := to_tsvector('russian', coalesce(NEW.content, ''));
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_diary_tsv_update
    BEFORE INSERT OR UPDATE OF content ON diary_entries
    FOR EACH ROW
    EXECUTE FUNCTION fn_diary_tsv_update();

COMMENT ON FUNCTION fn_diary_tsv_update()
    IS 'РџРѕРґРґРµСЂР¶РєР° content_tsv = to_tsvector(russian, content).';

-- ---------- 5. trg_audit_changes (РѕР±С‰РёР№ РѕР±СЂР°Р±РѕС‚С‡РёРє) ----------------------

CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_action audit_action_enum;
    v_user   BIGINT;
    v_row_id BIGINT;
    v_diff   JSONB;
    v_row    JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_action := 'insert';
        v_row := to_jsonb(NEW);
        v_row_id := (v_row ->> 'id')::BIGINT;
        v_user   := (v_row ->> 'user_id')::BIGINT;
        v_diff   := jsonb_build_object('new', v_row);
    ELSIF TG_OP = 'UPDATE' THEN
        v_action := 'update';
        v_row := to_jsonb(NEW);
        v_row_id := (v_row ->> 'id')::BIGINT;
        v_user   := (v_row ->> 'user_id')::BIGINT;
        v_diff   := jsonb_build_object('old', to_jsonb(OLD), 'new', v_row);
    ELSE
        v_action := 'delete';
        v_row := to_jsonb(OLD);
        v_row_id := (v_row ->> 'id')::BIGINT;
        v_user   := (v_row ->> 'user_id')::BIGINT;
        v_diff   := jsonb_build_object('old', v_row);
    END IF;

    IF v_user IS NULL
       AND TG_TABLE_NAME IN ('pattern_logs', 'pattern_markers', 'pattern_marker_day_closures') THEN
        SELECT bp.user_id INTO v_user
          FROM behavior_patterns bp
         WHERE bp.id = (v_row ->> 'pattern_id')::BIGINT;
    END IF;

    INSERT INTO audit_log (user_id, table_name, row_id, action, diff)
    VALUES (v_user, TG_TABLE_NAME, v_row_id, v_action, v_diff);

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_audit_tasks
    AFTER INSERT OR UPDATE OR DELETE ON tasks
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_diary
    AFTER INSERT OR UPDATE OR DELETE ON diary_entries
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_patterns
    AFTER INSERT OR UPDATE OR DELETE ON behavior_patterns
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_goals
    AFTER INSERT OR UPDATE OR DELETE ON goals
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_pattern_logs
    AFTER INSERT OR UPDATE OR DELETE ON pattern_logs
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

COMMENT ON FUNCTION fn_audit_log()
    IS 'РЈРЅРёРІРµСЂСЃР°Р»СЊРЅС‹Р№ РѕР±СЂР°Р±РѕС‚С‡РёРє AFTER INSERT/UPDATE/DELETE РґР»СЏ Р·Р°РїРёСЃРё РёР·РјРµРЅРµРЅРёР№ РІ audit_log.';

-- ---------- 6. trg_recurring_spawn_on_complete ---------------------------

CREATE OR REPLACE FUNCTION fn_recurring_spawn_on_complete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_next DATE;
BEGIN
    IF NEW.status = 'done'
       AND OLD.status IS DISTINCT FROM NEW.status
       AND NEW.recurring_rule_id IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM tasks
             WHERE recurring_rule_id = NEW.recurring_rule_id
               AND status IN ('pending', 'in_progress', 'overdue')
        ) THEN
            RETURN NEW;
        END IF;
        v_next := fn_next_recurring_date(NEW.recurring_rule_id, current_date);
        IF v_next IS NOT NULL THEN
            INSERT INTO tasks (
                user_id, topic_id, recurring_rule_id,
                title, description, priority,
                deadline, planned_minutes
            )
            VALUES (
                NEW.user_id, NEW.topic_id, NEW.recurring_rule_id,
                NEW.title, NEW.description, NEW.priority,
                v_next::timestamptz + INTERVAL '23 hours 59 minutes', NEW.planned_minutes
            );
            UPDATE recurring_rules SET next_run_at = v_next WHERE id = NEW.recurring_rule_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_recurring_spawn_on_complete
    AFTER UPDATE OF status ON tasks
    FOR EACH ROW EXECUTE FUNCTION fn_recurring_spawn_on_complete();

COMMENT ON FUNCTION fn_recurring_spawn_on_complete()
    IS 'РџСЂРё Р·Р°РІРµСЂС€РµРЅРёРё РїРѕРІС‚РѕСЂСЏСЋС‰РµР№СЃСЏ Р·Р°РґР°С‡Рё РїРѕСЂРѕР¶РґР°РµС‚ СЃР»РµРґСѓСЋС‰РёР№ СЌРєР·РµРјРїР»СЏСЂ.';

-- ---------- 8. trg_tag_user_match (Р·Р°С‰РёС‚Р° РѕС‚ РїРµСЂРµСЃРµС‡РµРЅРёСЏ РґР°РЅРЅС‹С…) ---------

CREATE OR REPLACE FUNCTION fn_tag_user_match_for_task()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_task_user BIGINT;
    v_tag_user  BIGINT;
BEGIN
    SELECT user_id INTO v_task_user FROM tasks WHERE id = NEW.task_id;
    SELECT user_id INTO v_tag_user  FROM tags  WHERE id = NEW.tag_id;
    IF v_task_user IS DISTINCT FROM v_tag_user THEN
        RAISE EXCEPTION 'tag and task belong to different users';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_tag_user_match_for_diary()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_entry_user BIGINT;
    v_tag_user   BIGINT;
BEGIN
    SELECT user_id INTO v_entry_user FROM diary_entries WHERE id = NEW.entry_id;
    SELECT user_id INTO v_tag_user   FROM tags          WHERE id = NEW.tag_id;
    IF v_entry_user IS DISTINCT FROM v_tag_user THEN
        RAISE EXCEPTION 'tag and diary entry belong to different users';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tag_user_match_task
    BEFORE INSERT ON task_tags
    FOR EACH ROW EXECUTE FUNCTION fn_tag_user_match_for_task();

CREATE TRIGGER trg_tag_user_match_diary
    BEFORE INSERT ON diary_tags
    FOR EACH ROW EXECUTE FUNCTION fn_tag_user_match_for_diary();

-- ---------- 9. trg_goal_completed ----------------------------------------

CREATE OR REPLACE FUNCTION fn_goal_check_completion()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.is_completed = TRUE AND NEW.completed_at IS NULL THEN
        NEW.completed_at := now();
    ELSIF NEW.is_completed = FALSE THEN
        NEW.completed_at := NULL;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_goal_completed
    BEFORE UPDATE OF is_completed ON goals
    FOR EACH ROW EXECUTE FUNCTION fn_goal_check_completion();

COMMENT ON FUNCTION fn_goal_check_completion()
    IS 'РџРѕРґРґРµСЂР¶РёРІР°РµС‚ РєРѕРЅСЃРёСЃС‚РµРЅС‚РЅРѕСЃС‚СЊ is_completed/completed_at С†РµР»Рё.';

-- ---------- 10. trg_pattern_to_task_on_response --------------------------

DROP TRIGGER IF EXISTS trg_pattern_to_task ON pattern_schedules;
DROP FUNCTION IF EXISTS fn_pattern_to_task();

CREATE OR REPLACE FUNCTION fn_pattern_to_task_on_response()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_pattern behavior_patterns%ROWTYPE;
    v_day     DATE;
BEGIN
    IF NEW.status <> 'answered' THEN
        RETURN NEW;
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.status = 'answered' THEN
        RETURN NEW;
    END IF;
    SELECT * INTO v_pattern FROM behavior_patterns WHERE id = NEW.pattern_id;
    IF NOT COALESCE(v_pattern.auto_create_task, FALSE) THEN
        RETURN NEW;
    END IF;
    v_day := date_trunc('day', NEW.scheduled_at)::date;
    IF NOT EXISTS (
        SELECT 1 FROM tasks t
         WHERE t.user_id = v_pattern.user_id
           AND t.title = v_pattern.title
           AND t.deadline IS NOT NULL
           AND t.deadline::date = v_day
    ) THEN
        INSERT INTO tasks (user_id, topic_id, title, description, priority, deadline, created_at)
        VALUES (
            v_pattern.user_id,
            COALESCE(v_pattern.topic_id, (SELECT id FROM topics WHERE user_id = v_pattern.user_id LIMIT 1)),
            v_pattern.title,
            'РђРІС‚Рѕ-Р·Р°РґР°С‡Р° РёР· РїР°С‚С‚РµСЂРЅР° #' || v_pattern.id,
            'medium',
            v_day::timestamptz + TIME '23:59:00',
            v_day::timestamptz + TIME '00:05:00'
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pattern_to_task_on_response
    AFTER INSERT OR UPDATE OF status ON pattern_logs
    FOR EACH ROW EXECUTE FUNCTION fn_pattern_to_task_on_response();

COMMENT ON FUNCTION fn_pattern_to_task_on_response()
    IS 'auto_create_task: СЃРѕР·РґР°С‘С‚ Р·Р°РґР°С‡Сѓ РїСЂРё РѕС‚РІРµС‚Рµ habit (1 СЂР°Р· РІ РґРµРЅСЊ).';

DO $$
BEGIN
    RAISE NOTICE 'PTT 08-triggers: triggers created';
END $$;


-- ===== 09-seed.sql =====

-- =============================================================================
-- 09 вЂ” РќР°РїРѕР»РЅРµРЅРёРµ СЃРїСЂР°РІРѕС‡РЅРёРєРѕРІ Рё СЃРѕР·РґР°РЅРёРµ РµРґРёРЅСЃС‚РІРµРЅРЅРѕРіРѕ РїРѕР»СЊР·РѕРІР°С‚РµР»СЏ.
-- =============================================================================

-- ---------- РїРѕР»СЊР·РѕРІР°С‚РµР»СЊ --------------------------------------------------

INSERT INTO users (id, username, timezone)
VALUES (1, 'me', 'Europe/Moscow')
ON CONFLICT (id) DO NOTHING;

-- РЎРґРІРёРіР°РµРј sequence, С‡С‚РѕР±С‹ Р±СѓРґСѓС‰РёРµ insert-С‹ РЅРµ РєРѕРЅС„Р»РёРєС‚РѕРІР°Р»Рё.
SELECT setval(pg_get_serial_sequence('users', 'id'),
              GREATEST((SELECT COALESCE(MAX(id), 0) FROM users), 1), TRUE);

-- ---------- С‚РµРјС‹ РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ --------------------------------------------

INSERT INTO topics (user_id, name, color) VALUES
    (1, 'Р Р°Р±РѕС‚Р°',    '#3B82F6'),
    (1, 'РЈС‡С‘Р±Р°',     '#8B5CF6'),
    (1, 'Р—РґРѕСЂРѕРІСЊРµ',  '#10B981'),
    (1, 'Р›РёС‡РЅРѕРµ',    '#F59E0B'),
    (1, 'РџСЂРёРІС‹С‡РєРё',  '#EC4899'),
    (1, 'РџСЂРѕС‡РµРµ',    '#6B7280')
ON CONFLICT (user_id, name) DO NOTHING;

-- ---------- РґРµРјРѕ-С‚РµРіРё -----------------------------------------------------

INSERT INTO tags (user_id, name) VALUES
    (1, 'РІР°Р¶РЅРѕРµ'),
    (1, 'СЃСЂРѕС‡РЅРѕРµ'),
    (1, 'РёРґРµСЏ'),
    (1, 'РѕР±СѓС‡РµРЅРёРµ'),
    (1, 'СЃРїРѕСЂС‚')
ON CONFLICT (user_id, name) DO NOTHING;

-- ---------- РїСЂР°Р·РґРЅРёРєРё Р Р¤ РЅР° 2026 -----------------------------------------

INSERT INTO holidays (holiday_date, name, is_official) VALUES
    ('2026-01-01', 'РќРѕРІС‹Р№ РіРѕРґ',                                TRUE),
    ('2026-01-02', 'РќРѕРІРѕРіРѕРґРЅРёРµ РєР°РЅРёРєСѓР»С‹',                      TRUE),
    ('2026-01-03', 'РќРѕРІРѕРіРѕРґРЅРёРµ РєР°РЅРёРєСѓР»С‹',                      TRUE),
    ('2026-01-04', 'РќРѕРІРѕРіРѕРґРЅРёРµ РєР°РЅРёРєСѓР»С‹',                      TRUE),
    ('2026-01-05', 'РќРѕРІРѕРіРѕРґРЅРёРµ РєР°РЅРёРєСѓР»С‹',                      TRUE),
    ('2026-01-06', 'РќРѕРІРѕРіРѕРґРЅРёРµ РєР°РЅРёРєСѓР»С‹',                      TRUE),
    ('2026-01-07', 'Р РѕР¶РґРµСЃС‚РІРѕ РҐСЂРёСЃС‚РѕРІРѕ',                       TRUE),
    ('2026-01-08', 'РќРѕРІРѕРіРѕРґРЅРёРµ РєР°РЅРёРєСѓР»С‹',                      TRUE),
    ('2026-02-23', 'Р”РµРЅСЊ Р·Р°С‰РёС‚РЅРёРєР° РћС‚РµС‡РµСЃС‚РІР°',                 TRUE),
    ('2026-03-08', 'РњРµР¶РґСѓРЅР°СЂРѕРґРЅС‹Р№ Р¶РµРЅСЃРєРёР№ РґРµРЅСЊ',               TRUE),
    ('2026-05-01', 'РџСЂР°Р·РґРЅРёРє Р’РµСЃРЅС‹ Рё РўСЂСѓРґР°',                   TRUE),
    ('2026-05-09', 'Р”РµРЅСЊ РџРѕР±РµРґС‹',                              TRUE),
    ('2026-06-12', 'Р”РµРЅСЊ Р РѕСЃСЃРёРё',                              TRUE),
    ('2026-11-04', 'Р”РµРЅСЊ РЅР°СЂРѕРґРЅРѕРіРѕ РµРґРёРЅСЃС‚РІР°',                  TRUE)
ON CONFLICT (holiday_date) DO NOTHING;

-- ---------- РЅР°СЃС‚СЂРѕР№РєРё РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ ---------------------------------------

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

