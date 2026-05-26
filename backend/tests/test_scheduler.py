"""Smoke-тесты APScheduler job functions."""

from __future__ import annotations

from app.scheduler import (
    _archive_old_audit,
    _close_overdue_pattern_logs,
    _ensure_habit_logs_today,
    _recalc_calendar_cache,
    _spawn_recurring_tasks,
)


async def test_scheduler_jobs_run() -> None:
    await _spawn_recurring_tasks()
    await _ensure_habit_logs_today()
    await _close_overdue_pattern_logs()
    await _recalc_calendar_cache()
    await _archive_old_audit()
