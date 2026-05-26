"""Правила повторения задач."""

from __future__ import annotations

from httpx import AsyncClient


async def test_create_task_with_weekly_recurring(client: AsyncClient, topic_id: int) -> None:
    r = await client.post(
        "/api/v1/tasks",
        json={
            "topic_id": topic_id,
            "title": "weekly standup",
            "recurring": {
                "frequency": "weekly",
                "params": {"weekly_mask": 31},
                "is_active": True,
            },
        },
    )
    assert r.status_code == 201
    task = r.json()
    assert task["recurring_rule_id"] is not None

    rule = (await client.get(f"/api/v1/tasks/{task['id']}/recurring")).json()
    assert rule["frequency"] == "weekly"
    assert rule["params"]["weekly_mask"] == 31


async def test_attach_and_update_recurring(client: AsyncClient, topic_id: int) -> None:
    task = (
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "plain task"},
        )
    ).json()
    r = await client.post(
        f"/api/v1/tasks/{task['id']}/recurring",
        json={"frequency": "daily", "params": {}, "is_active": True},
    )
    assert r.status_code == 201
    assert r.json()["frequency"] == "daily"

    r = await client.patch(
        f"/api/v1/tasks/{task['id']}/recurring",
        json={"frequency": "monthly", "params": {"monthly_day": 15}},
    )
    assert r.status_code == 200
    assert r.json()["frequency"] == "monthly"
    assert r.json()["params"]["monthly_day"] == 15


async def test_detach_recurring_clears_task_link(
    client: AsyncClient, topic_id: int
) -> None:
    task = (
        await client.post(
            "/api/v1/tasks",
            json={
                "topic_id": topic_id,
                "title": "recurring detach",
                "recurring": {"frequency": "daily", "params": {}, "is_active": True},
            },
        )
    ).json()
    assert task["recurring_rule_id"] is not None
    r = await client.delete(f"/api/v1/tasks/{task['id']}/recurring")
    assert r.status_code == 204
    updated = (await client.get(f"/api/v1/tasks/{task['id']}")).json()
    assert updated["recurring_rule_id"] is None


async def test_detach_recurring(client: AsyncClient, topic_id: int) -> None:
    task = (
        await client.post(
            "/api/v1/tasks",
            json={
                "topic_id": topic_id,
                "title": "temp recurring",
                "recurring": {"frequency": "daily", "params": {}, "is_active": True},
            },
        )
    ).json()
    r = await client.delete(f"/api/v1/tasks/{task['id']}/recurring")
    assert r.status_code == 204

    rule = (
        await client.get(f"/api/v1/recurring-rules/{task['recurring_rule_id']}")
    ).json()
    assert rule["is_active"] is False


async def test_recurring_not_on_subtask(client: AsyncClient, topic_id: int) -> None:
    parent = (
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "parent"},
        )
    ).json()
    child = (
        await client.post(
            "/api/v1/tasks",
            json={
                "topic_id": topic_id,
                "title": "child",
                "parent_task_id": parent["id"],
            },
        )
    ).json()
    r = await client.post(
        f"/api/v1/tasks/{child['id']}/recurring",
        json={"frequency": "daily", "params": {}, "is_active": True},
    )
    assert r.status_code == 400


async def test_list_recurring_rules(client: AsyncClient, topic_id: int) -> None:
    await client.post(
        "/api/v1/tasks",
        json={
            "topic_id": topic_id,
            "title": "listed recurring",
            "recurring": {"frequency": "daily", "params": {}, "is_active": True},
        },
    )
    r = await client.get("/api/v1/recurring-rules")
    assert r.status_code == 200
    assert len(r.json()) >= 1
