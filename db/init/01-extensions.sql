-- =============================================================================
-- 01 — Расширения PostgreSQL.
--
-- Используются:
--   pg_trgm    — нечёткий поиск/триграммные индексы по тегам и темам;
--   btree_gist — поддержка EXCLUSION-констрейнтов вместе с gist (см. 03);
--   unaccent   — поиск без диакритики (вспомогательная для FTS).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS unaccent;

DO $$
BEGIN
    RAISE NOTICE 'PTT 01-extensions: pg_trgm, btree_gist, unaccent installed';
END $$;
