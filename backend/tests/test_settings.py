"""Пользовательские настройки."""

from __future__ import annotations

from httpx import AsyncClient


async def test_seed_settings_listed(client: AsyncClient) -> None:
    r = await client.get("/api/v1/settings")
    assert r.status_code == 200
    keys = {item["key"] for item in r.json()}
    assert {"theme", "first_day_of_week", "pomodoro_minutes"} <= keys


async def test_get_setting(client: AsyncClient) -> None:
    r = await client.get("/api/v1/settings/theme")
    assert r.status_code == 200
    assert r.json()["value"] == "system"


async def test_upsert_and_delete_setting(client: AsyncClient) -> None:
    r = await client.put(
        "/api/v1/settings/custom_key",
        json={"key": "custom_key", "value": {"x": 1, "y": [2, 3]}},
    )
    assert r.status_code == 200
    assert r.json()["value"] == {"x": 1, "y": [2, 3]}

    r = await client.put(
        "/api/v1/settings/custom_key",
        json={"key": "custom_key", "value": "updated"},
    )
    assert r.status_code == 200
    assert r.json()["value"] == "updated"

    r = await client.delete("/api/v1/settings/custom_key")
    assert r.status_code == 204
    r = await client.get("/api/v1/settings/custom_key")
    assert r.status_code == 404


async def test_upsert_key_mismatch(client: AsyncClient) -> None:
    r = await client.put(
        "/api/v1/settings/theme",
        json={"key": "other", "value": "dark"},
    )
    assert r.status_code == 400
