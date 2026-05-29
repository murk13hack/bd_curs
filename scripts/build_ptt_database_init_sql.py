#!/usr/bin/env python3
"""Собрать docs/appendix/PTT_database_init.sql из db/init/*.sql (UTF-8)."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INIT_DIR = ROOT / "db" / "init"
OUT = ROOT / "docs" / "appendix" / "PTT_database_init.sql"


def main() -> None:
    header = """-- =============================================================================
-- ПТТ. Сводный SQL-скрипт инициализации базы данных
--
-- Собран автоматически из каталога db/init/ (01..09) в кодировке UTF-8.
-- Пересборка: python scripts/build_ptt_database_init_sql.py
--
-- Применение на пустой БД:
--   psql -U <user> -d <db> -f PTT_database_init.sql
-- =============================================================================

"""
    chunks = [header]
    for path in sorted(INIT_DIR.glob("*.sql")):
        chunks.append(f"\n-- ===== {path.name} =====\n\n")
        text = path.read_text(encoding="utf-8")
        chunks.append(text)
        if not text.endswith("\n"):
            chunks.append("\n")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("".join(chunks), encoding="utf-8", newline="\n")
    print(f"Written {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
