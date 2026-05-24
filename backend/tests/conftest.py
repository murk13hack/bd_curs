"""Общие фикстуры pytest для интеграционных тестов backend.

Стратегия:
- используем реальную БД из docker-compose;
- перед каждым тестом TRUNCATE «грязных» таблиц + reseed справочников;
- HTTP-клиент создаётся через httpx.AsyncClient + ASGITransport,
  который вызывает FastAPI-приложение в этом же процессе.
"""

from __future__ import annotations

from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.config import get_settings
from app.db import SessionLocal, engine
from app.main import app

settings = get_settings()

# Таблицы, которые очищаются перед каждым тестом.
# Используем TRUNCATE ... CASCADE, поэтому достаточно перечислить «верхние» сущности:
TABLES_TO_RESET = [
    "task_time_logs",
    "task_tags",
    "tasks",
    "recurring_rules",
    "diary_tags",
    "diary_entries",
    "pattern_step_answers",
    "pattern_day_sessions",
    "pattern_markers",
    "pattern_steps",
    "pattern_logs",
    "pattern_schedules",
    "pattern_response_options",
    "behavior_patterns",
    "goal_links",
    "goals",
    "audit_log",
    "topics",
    "tags",
    "app_settings",
]

SEED_TOPICS = [
    ("Работа", "#3B82F6"),
    ("Учёба", "#8B5CF6"),
    ("Здоровье", "#10B981"),
    ("Личное", "#F59E0B"),
    ("Привычки", "#EC4899"),
    ("Прочее", "#6B7280"),
]

SEED_TAGS = ["важное", "срочное", "идея", "обучение", "спорт"]

SEED_SETTINGS: list[tuple[str, str]] = [
    ("theme", '"system"'),
    ("first_day_of_week", "1"),
    ("pomodoro_minutes", "25"),
    ("pomodoro_short_break", "5"),
    ("pomodoro_long_break", "15"),
    (
        "do_not_disturb",
        '{"enabled": false, "from": "22:00", "to": "08:00"}',
    ),
]


@pytest_asyncio.fixture(autouse=True)
async def _clean_db() -> AsyncIterator[None]:
    """Очищает динамические таблицы и заново сеет справочники перед каждым тестом."""
    async with engine.begin() as conn:
        await conn.execute(
            text(
                "TRUNCATE TABLE "
                + ", ".join(TABLES_TO_RESET)
                + " RESTART IDENTITY CASCADE"
            )
        )
        for name, color in SEED_TOPICS:
            await conn.execute(
                text(
                    "INSERT INTO topics (user_id, name, color) "
                    "VALUES (:uid, :n, :c) ON CONFLICT DO NOTHING"
                ).bindparams(uid=settings.default_user_id, n=name, c=color)
            )
        for tag in SEED_TAGS:
            await conn.execute(
                text(
                    "INSERT INTO tags (user_id, name) VALUES (:uid, :n) "
                    "ON CONFLICT DO NOTHING"
                ).bindparams(uid=settings.default_user_id, n=tag)
            )
        for key, value_json in SEED_SETTINGS:
            await conn.execute(
                text(
                    "INSERT INTO app_settings (user_id, key, value) "
                    "VALUES (:uid, :k, CAST(:v AS jsonb)) ON CONFLICT DO NOTHING"
                ).bindparams(uid=settings.default_user_id, k=key, v=value_json)
            )
    yield


@pytest_asyncio.fixture
async def client() -> AsyncIterator[AsyncClient]:
    """HTTP-клиент, ходит в FastAPI-приложение через ASGI-транспорт."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest_asyncio.fixture
async def topic_id(client: AsyncClient) -> int:
    """ID темы «Работа» из seed."""
    resp = await client.get("/api/v1/topics")
    assert resp.status_code == 200, resp.text
    for t in resp.json():
        if t["name"] == "Работа":
            return t["id"]
    raise AssertionError("seed topic 'Работа' not found")


@pytest_asyncio.fixture
async def tag_id(client: AsyncClient) -> int:
    resp = await client.get("/api/v1/tags")
    for t in resp.json():
        if t["name"] == "важное":
            return t["id"]
    raise AssertionError("seed tag not found")


@pytest.fixture(scope="session", autouse=True)
def _disable_scheduler():
    """Не запускаем APScheduler в тестах."""
    settings.scheduler_enabled = False
    yield


async def db_exec(sql: str, **params) -> None:
    """Выполнить произвольный SQL внутри теста (например, ускорить дату completed_at)."""
    async with SessionLocal() as session:
        await session.execute(text(sql).bindparams(**params))
        await session.commit()
