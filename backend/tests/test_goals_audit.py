"""Тест прогресса цели с паттерном markers."""

from __future__ import annotations

from httpx import AsyncClient


async def test_goal_progress_with_markers_pattern(client: AsyncClient) -> None:
    pattern = (
        await client.post(
            "/api/v1/patterns",
            json={
                "title": "Goal marker",
                "pattern_type": "negative",
                "pattern_mode": "markers",
                "schedules": [{"time_of_day": "09:00:00", "dow_mask": 127}],
            },
        )
    ).json()

    goal = (
        await client.post(
            "/api/v1/goals",
            json={
                "title": "Clean days",
                "target_value": 3,
                "links": [{"target_type": "pattern", "target_id": pattern["id"]}],
            },
        )
    ).json()

    r = await client.get(f"/api/v1/goals/{goal['id']}/progress")
    assert r.status_code == 200
    body = r.json()
    assert body["progress"] >= 0
    assert any(l["target_type"] == "pattern" for l in body["links"])


async def test_tasks_deadline_on_filter(client: AsyncClient, topic_id: int) -> None:
    from datetime import datetime, timedelta, timezone

    day = (datetime.now(tz=timezone.utc) + timedelta(days=2)).date().isoformat()
    deadline = f"{day}T18:00:00+00:00"
    task = (
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "dated", "deadline": deadline},
        )
    ).json()

    r = await client.get("/api/v1/tasks", params={"deadline_on": day})
    assert r.status_code == 200
    ids = [t["id"] for t in r.json()]
    assert task["id"] in ids


async def test_add_goal_link_invalid_target(client: AsyncClient) -> None:
    goal = (
        await client.post("/api/v1/goals", json={"title": "x", "target_value": 1})
    ).json()
    r = await client.post(
        f"/api/v1/goals/{goal['id']}/links",
        json={"target_type": "task", "target_id": 999999},
    )
    assert r.status_code == 404
