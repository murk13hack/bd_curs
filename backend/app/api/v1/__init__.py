"""Регистрация всех роутеров /api/v1/*."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.v1 import (
    calendar,
    diary,
    goals,
    holidays,
    import_export,
    patterns,
    recurring_rules,
    service,
    settings,
    stats,
    tags,
    tasks,
    topics,
)

api_router = APIRouter()
api_router.include_router(service.router)
api_router.include_router(topics.router)
api_router.include_router(tags.router)
api_router.include_router(holidays.router)
api_router.include_router(settings.router)
api_router.include_router(tasks.router)
api_router.include_router(recurring_rules.router)
api_router.include_router(diary.router)
api_router.include_router(patterns.router)
api_router.include_router(calendar.router)
api_router.include_router(stats.router)
api_router.include_router(goals.router)
api_router.include_router(import_export.router)
