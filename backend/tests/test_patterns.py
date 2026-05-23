"""Паттерны: CRUD options/schedules + responses + streaks."""

from __future__ import annotations

from datetime import datetime, timezone

from httpx import AsyncClient


async def _create_boolean_pattern(client: AsyncClient) -> dict:
    r = await client.post(
        "/api/v1/patterns",
        json={
            "title": "Зарядка",
            "pattern_type": "positive",
            "is_boolean": True,
        },
    )
    assert r.status_code == 201, r.text
    return r.json()


async def test_create_boolean_creates_default_options(client: AsyncClient) -> None:
    p = await _create_boolean_pattern(client)
    labels = sorted(o["label"] for o in p["options"])
    assert labels == ["Не сделал", "Сделал"]
    success_flags = {o["label"]: o["is_success"] for o in p["options"]}
    assert success_flags["Сделал"] is True
    assert success_flags["Не сделал"] is False


async def test_add_schedule_and_option(client: AsyncClient) -> None:
    p = await _create_boolean_pattern(client)
    r = await client.post(
        f"/api/v1/patterns/{p['id']}/schedules",
        json={"time_of_day": "08:00:00", "dow_mask": 31},
    )
    assert r.status_code == 201
    r = await client.post(
        f"/api/v1/patterns/{p['id']}/options",
        json={"label": "Скипнул", "is_success": False, "sort_order": 2},
    )
    assert r.status_code == 201

    fetched = (await client.get(f"/api/v1/patterns/{p['id']}")).json()
    assert any(s["dow_mask"] == 31 for s in fetched["schedules"])
    assert any(o["label"] == "Скипнул" for o in fetched["options"])


async def test_log_response_and_streak(client: AsyncClient) -> None:
    p = await _create_boolean_pattern(client)
    success_id = next(o["id"] for o in p["options"] if o["is_success"])

    r = await client.post(
        f"/api/v1/patterns/{p['id']}/responses",
        json={
            "response_option_id": success_id,
            "scheduled_at": datetime.now(tz=timezone.utc).isoformat(),
        },
    )
    assert r.status_code == 204

    r = await client.get(f"/api/v1/patterns/{p['id']}/streak")
    assert r.status_code == 200
    body = r.json()
    assert body["current_streak"] >= 1


async def test_streaks_view(client: AsyncClient) -> None:
    p = await _create_boolean_pattern(client)
    success_id = next(o["id"] for o in p["options"] if o["is_success"])
    await client.post(
        f"/api/v1/patterns/{p['id']}/responses",
        json={"response_option_id": success_id},
    )
    r = await client.get("/api/v1/patterns/streaks/all")
    assert r.status_code == 200
    rows = r.json()
    assert len(rows) == 1
    assert rows[0]["pattern_id"] == p["id"]
    assert rows[0]["success_rate_30d"] >= 0


async def test_delete_pattern_cascades(client: AsyncClient) -> None:
    p = await _create_boolean_pattern(client)
    r = await client.delete(f"/api/v1/patterns/{p['id']}")
    assert r.status_code == 204
    r = await client.get(f"/api/v1/patterns/{p['id']}")
    assert r.status_code == 404
