"""CRUD праздников."""

from __future__ import annotations

from httpx import AsyncClient


async def test_holidays_2026_seed(client: AsyncClient) -> None:
    r = await client.get("/api/v1/holidays?year=2026")
    assert r.status_code == 200
    items = r.json()
    assert any(it["holiday_date"] == "2026-01-01" for it in items)
    assert any(it["holiday_date"] == "2026-05-09" for it in items)


async def test_create_update_delete_holiday(client: AsyncClient) -> None:
    payload = {
        "holiday_date": "2030-04-30",
        "name": "Тестовый",
        "is_official": False,
    }
    r = await client.post("/api/v1/holidays", json=payload)
    assert r.status_code == 201
    new_id = r.json()["id"]

    r = await client.patch(
        f"/api/v1/holidays/{new_id}",
        json={"name": "Обновлено", "is_official": True},
    )
    assert r.status_code == 200
    assert r.json()["name"] == "Обновлено"

    r = await client.delete(f"/api/v1/holidays/{new_id}")
    assert r.status_code == 204


async def test_holiday_duplicate_409(client: AsyncClient) -> None:
    r = await client.post(
        "/api/v1/holidays",
        json={"holiday_date": "2026-01-01", "name": "Dup", "is_official": True},
    )
    assert r.status_code == 409
