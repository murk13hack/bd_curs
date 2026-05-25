"""Импорт данных пользователя: merge (справочники) или restore (полное восстановление)."""

from __future__ import annotations

import json
from typing import Any, Literal

from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

ImportMode = Literal["merge", "restore"]

_RESTORE_ORDER: list[tuple[str, str]] = [
    ("topics", "topics"),
    ("tags", "tags"),
    ("recurring_rules", "recurring_rules"),
    ("behavior_patterns", "patterns"),
    ("pattern_response_options", "pattern_options"),
    ("pattern_schedules", "pattern_schedules"),
    ("pattern_steps", "pattern_steps"),
    ("tasks", "tasks"),
    ("task_tags", "task_tags"),
    ("task_time_logs", "task_time_logs"),
    ("diary_entries", "diary_entries"),
    ("diary_tags", "diary_tags"),
    ("goals", "goals"),
    ("goal_links", "goal_links"),
    ("pattern_logs", "pattern_logs"),
    ("pattern_markers", "pattern_markers"),
    ("pattern_marker_day_closures", "pattern_marker_day_closures"),
    ("pattern_day_sessions", "pattern_day_sessions"),
    ("pattern_step_answers", "pattern_step_answers"),
    ("app_settings", "app_settings"),
]

_USER_ID_TABLES = frozenset(
    {
        "topics",
        "tags",
        "behavior_patterns",
        "tasks",
        "task_time_logs",
        "diary_entries",
        "goals",
        "app_settings",
    }
)


async def import_user_data(
    session: AsyncSession, user_id: int, data: dict[str, Any], mode: ImportMode = "merge"
) -> dict[str, str]:
    if mode == "merge":
        await session.execute(
            text("CALL sp_import_user_data(:uid, CAST(:doc AS jsonb))").bindparams(
                uid=user_id, doc=json.dumps(data)
            )
        )
        return {"status": "merged", "mode": mode}

    version = int(data.get("schema_version") or 0)
    if version < 2:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Для полного восстановления нужен export schema_version >= 2",
        )

    await _wipe_user_data(session, user_id)
    for table, key in _RESTORE_ORDER:
        rows = data.get(key, [])
        if not rows:
            continue
        payload = []
        for row in rows:
            item = dict(row)
            if table in _USER_ID_TABLES:
                item["user_id"] = user_id
            payload.append(item)
        await session.execute(
            text(
                f"""
                INSERT INTO {table}
                SELECT r.*
                  FROM json_populate_recordset(NULL::{table}, CAST(:rows AS json)) AS r
                """
            ).bindparams(rows=json.dumps(payload))
        )
    await _reset_sequences(session)
    return {"status": "restored", "mode": mode}


_WIPE_SQL = [
    """
    DELETE FROM pattern_step_answers WHERE session_id IN (
        SELECT s.id FROM pattern_day_sessions s
        JOIN behavior_patterns bp ON bp.id = s.pattern_id WHERE bp.user_id = :uid
    )
    """,
    """
    DELETE FROM pattern_day_sessions WHERE pattern_id IN (
        SELECT id FROM behavior_patterns WHERE user_id = :uid
    )
    """,
    """
    DELETE FROM pattern_marker_day_closures WHERE pattern_id IN (
        SELECT id FROM behavior_patterns WHERE user_id = :uid
    )
    """,
    """
    DELETE FROM pattern_markers WHERE pattern_id IN (
        SELECT id FROM behavior_patterns WHERE user_id = :uid
    )
    """,
    """
    DELETE FROM pattern_logs WHERE pattern_id IN (
        SELECT id FROM behavior_patterns WHERE user_id = :uid
    )
    """,
    """
    DELETE FROM pattern_steps WHERE pattern_id IN (
        SELECT id FROM behavior_patterns WHERE user_id = :uid
    )
    """,
    """
    DELETE FROM pattern_schedules WHERE pattern_id IN (
        SELECT id FROM behavior_patterns WHERE user_id = :uid
    )
    """,
    """
    DELETE FROM pattern_response_options WHERE pattern_id IN (
        SELECT id FROM behavior_patterns WHERE user_id = :uid
    )
    """,
    "DELETE FROM goal_links WHERE goal_id IN (SELECT id FROM goals WHERE user_id = :uid)",
    "DELETE FROM goals WHERE user_id = :uid",
    """
    DELETE FROM diary_tags WHERE entry_id IN (
        SELECT id FROM diary_entries WHERE user_id = :uid
    )
    """,
    "DELETE FROM diary_entries WHERE user_id = :uid",
    "DELETE FROM task_time_logs WHERE user_id = :uid",
    "DELETE FROM task_tags WHERE task_id IN (SELECT id FROM tasks WHERE user_id = :uid)",
    """
    DELETE FROM recurring_rules WHERE id IN (
        SELECT recurring_rule_id FROM tasks
         WHERE user_id = :uid AND recurring_rule_id IS NOT NULL
    )
    """,
    "DELETE FROM tasks WHERE user_id = :uid",
    "DELETE FROM behavior_patterns WHERE user_id = :uid",
    "DELETE FROM app_settings WHERE user_id = :uid",
    "DELETE FROM tags WHERE user_id = :uid",
    "DELETE FROM topics WHERE user_id = :uid",
]


async def _wipe_user_data(session: AsyncSession, user_id: int) -> None:
    for stmt in _WIPE_SQL:
        await session.execute(text(stmt).bindparams(uid=user_id))


async def _reset_sequences(session: AsyncSession) -> None:
    for table in (
        "topics",
        "tags",
        "recurring_rules",
        "behavior_patterns",
        "pattern_response_options",
        "pattern_schedules",
        "pattern_steps",
        "tasks",
        "task_time_logs",
        "diary_entries",
        "goals",
        "pattern_logs",
        "pattern_markers",
        "pattern_marker_day_closures",
        "pattern_day_sessions",
        "pattern_step_answers",
        "app_settings",
    ):
        await session.execute(
            text(
                f"""
                SELECT setval(
                    pg_get_serial_sequence('{table}', 'id'),
                    GREATEST(COALESCE((SELECT MAX(id) FROM {table}), 1), 1)
                )
                WHERE pg_get_serial_sequence('{table}', 'id') IS NOT NULL
                """
            )
        )
