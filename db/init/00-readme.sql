-- =============================================================================
-- ПТТ. Каталог инициализационных скриптов БД.
--
-- Файлы из этого каталога выполняются образом postgres:16-alpine при ПЕРВОМ
-- запуске контейнера в АЛФАВИТНОМ порядке имён. После создания тома (volume
-- pgdata) повторно скрипты не запускаются.
--
-- План наполнения каталога согласно ТЗ (раздел 4.3.1, приложение В):
--   01-extensions.sql   -- CREATE EXTENSION pg_trgm, btree_gist
--   02-types.sql        -- CREATE TYPE / CREATE DOMAIN
--   03-tables.sql       -- CREATE TABLE + констрейнты
--   04-indexes.sql      -- CREATE INDEX (B-tree, GIN, BRIN, partial, exclusion)
--   05-functions.sql    -- CREATE FUNCTION
--   06-views.sql        -- CREATE VIEW / MATERIALIZED VIEW
--   07-procedures.sql   -- CREATE PROCEDURE
--   08-triggers.sql     -- CREATE TRIGGER
--   09-seed.sql         -- наполнение справочников (topics, holidays, ...)
--
-- Команда применения вручную (если volume уже существовал):
--   docker compose exec db psql -U $POSTGRES_USER -d $POSTGRES_DB -f /docker-entrypoint-initdb.d/<file>.sql
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'PTT init scripts placeholder loaded at %', now();
END $$;
