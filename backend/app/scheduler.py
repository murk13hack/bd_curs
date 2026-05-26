"""Фоновый планировщик: вызовы хранимых процедур по расписанию."""

from __future__ import annotations

import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger
from sqlalchemy import text

from app.config import get_settings
from app.db import session_scope

logger = logging.getLogger("ptt.scheduler")
_scheduler: AsyncIOScheduler | None = None


async def _spawn_recurring_tasks() -> None:
    async with session_scope() as session:
        await session.execute(text("CALL sp_spawn_recurring_tasks(current_date)"))
    logger.info("sp_spawn_recurring_tasks executed")


async def _ensure_habit_logs_today() -> None:
    async with session_scope() as session:
        await session.execute(text("CALL sp_ensure_habit_logs_for_day(current_date)"))
    logger.info("sp_ensure_habit_logs_for_day executed")


async def _close_overdue_pattern_logs() -> None:
    async with session_scope() as session:
        await session.execute(text("CALL sp_close_overdue_pattern_logs(now())"))
    logger.info("sp_close_overdue_pattern_logs executed")


async def _recalc_calendar_cache() -> None:
    async with session_scope() as session:
        await session.execute(text("CALL sp_recalc_calendar_cache()"))
    logger.info("sp_recalc_calendar_cache executed")


async def _archive_old_audit() -> None:
    async with session_scope() as session:
        await session.execute(text("CALL sp_archive_old_audit(365)"))
    logger.info("sp_archive_old_audit executed")


def start_scheduler() -> None:
    global _scheduler
    settings = get_settings()
    if not settings.scheduler_enabled or _scheduler is not None:
        return

    sch = AsyncIOScheduler(timezone=settings.tz)
    sch.add_job(
        _spawn_recurring_tasks,
        CronTrigger(hour=0, minute=5),
        id="spawn_recurring_tasks",
        replace_existing=True,
    )
    sch.add_job(
        _ensure_habit_logs_today,
        CronTrigger(hour=0, minute=10),
        id="ensure_habit_logs_today",
        replace_existing=True,
    )
    sch.add_job(
        _close_overdue_pattern_logs,
        IntervalTrigger(hours=1),
        id="close_overdue_pattern_logs",
        replace_existing=True,
    )
    sch.add_job(
        _recalc_calendar_cache,
        IntervalTrigger(minutes=10),
        id="recalc_calendar_cache",
        replace_existing=True,
    )
    sch.add_job(
        _archive_old_audit,
        CronTrigger(day_of_week="sun", hour=3, minute=0),
        id="archive_old_audit",
        replace_existing=True,
    )
    sch.start()
    _scheduler = sch
    logger.info("APScheduler started with %d jobs", len(sch.get_jobs()))


def stop_scheduler() -> None:
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
        logger.info("APScheduler stopped")
