"""Сервисные эндпоинты."""

from __future__ import annotations

from httpx import AsyncClient


async def test_health(client: AsyncClient) -> None:
    r = await client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


async def test_ping(client: AsyncClient) -> None:
    r = await client.get("/api/v1/ping")
    assert r.status_code == 200
    assert r.json() == {"pong": True}


async def test_db_ping(client: AsyncClient) -> None:
    r = await client.get("/api/v1/db-ping")
    assert r.status_code == 200
    body = r.json()
    assert body["db"] == "ok"
    assert "PostgreSQL" in body["version"]
