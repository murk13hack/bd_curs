"""Календарь: месяц + heatmap."""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from httpx import AsyncClient


async def test_calendar_month_has_31_days_with_holiday(client: AsyncClient) -> None:
    r = await client.get("/api/v1/calendar/2026/1")
    assert r.status_code == 200
    days = r.json()
    assert len(days) == 31
    holidays = [d for d in days if d["is_holiday"]]
    assert any(d["day"] == "2026-01-01" for d in holidays)


async def test_calendar_progress_paints_day(
    client: AsyncClient, topic_id: int
) -> None:
    """Создаём задачу с дедлайном → выполняем → день должен покраситься."""
    deadline = (datetime.now(tz=timezone.utc) + timedelta(hours=1)).isoformat()
    created = (
        await client.post(
            "/api/v1/tasks",
            json={
                "topic_id": topic_id,
                "title": "today task",
                "deadline": deadline,
            },
        )
    ).json()
    await client.post(f"/api/v1/tasks/{created['id']}/complete")

    today = date.today()
    r = await client.get(f"/api/v1/calendar/{today.year}/{today.month}")
    days = {d["day"]: d for d in r.json()}
    cell = days[today.isoformat()]
    assert cell["total"] >= 1
    assert cell["done"] >= 1
    assert cell["color"] != "#e5e7eb"


async def test_heatmap_aggregates(
    client: AsyncClient, topic_id: int
) -> None:
    today = date.today().isoformat()
    await client.post(
        "/api/v1/diary",
        json={"entry_date": today, "content": "test"},
    )
    deadline = (datetime.now(tz=timezone.utc) + timedelta(hours=2)).isoformat()
    await client.post(
        "/api/v1/tasks",
        json={"topic_id": topic_id, "title": "x", "deadline": deadline},
    )
    r = await client.get(
        "/api/v1/calendar/heatmap",
        params={"from": today, "to": today},
    )
    assert r.status_code == 200
    body = r.json()
    assert len(body) == 1
    assert body[0]["activity"] >= 2
