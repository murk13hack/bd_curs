"""Цели: CRUD + links + progress."""

from __future__ import annotations

from httpx import AsyncClient


async def test_create_goal_deadline_datetime_coerced(client: AsyncClient) -> None:
    r = await client.post(
        "/api/v1/goals",
        json={
            "title": "dated goal",
            "target_value": 1,
            "deadline": "2003-02-01T22:01:00.000Z",
        },
    )
    assert r.status_code == 201
    assert r.json()["deadline"] == "2003-02-01"


async def test_create_goal_with_links(
    client: AsyncClient, topic_id: int
) -> None:
    task = (
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "for goal"},
        )
    ).json()

    r = await client.post(
        "/api/v1/goals",
        json={
            "title": "Big goal",
            "target_value": 5,
            "links": [{"target_type": "task", "target_id": task["id"]}],
        },
    )
    assert r.status_code == 201
    body = r.json()
    assert body["target_value"] == 5
    assert body["is_completed"] is False
    assert len(body["links"]) == 1


async def test_goal_progress(client: AsyncClient, topic_id: int) -> None:
    tasks = []
    for _ in range(2):
        tasks.append(
            (
                await client.post(
                    "/api/v1/tasks",
                    json={"topic_id": topic_id, "title": "g"},
                )
            ).json()
        )
    goal = (
        await client.post(
            "/api/v1/goals",
            json={
                "title": "two-step",
                "target_value": 2,
                "links": [
                    {"target_type": "task", "target_id": tasks[0]["id"]},
                    {"target_type": "task", "target_id": tasks[1]["id"]},
                ],
            },
        )
    ).json()
    r = await client.get(f"/api/v1/goals/{goal['id']}/progress")
    assert r.status_code == 200
    body = r.json()
    assert body["progress"] == 0
    assert body["done_units"] == 0
    assert body["target_value"] == 2
    assert body["remaining_units"] == 2
    assert len(body["links"]) == 2

    await client.post(f"/api/v1/tasks/{tasks[0]['id']}/complete")
    r = await client.get(f"/api/v1/goals/{goal['id']}/progress")
    body = r.json()
    assert body["progress"] == 50.0
    assert body["done_units"] == 1
    assert body["remaining_units"] == 1


async def test_complete_goal_sets_completed_at(client: AsyncClient) -> None:
    goal = (
        await client.post(
            "/api/v1/goals", json={"title": "manual finish", "target_value": 1}
        )
    ).json()
    r = await client.patch(
        f"/api/v1/goals/{goal['id']}", json={"is_completed": True}
    )
    assert r.status_code == 200
    body = r.json()
    assert body["is_completed"] is True
    assert body["completed_at"] is not None


async def test_add_remove_link(client: AsyncClient, topic_id: int) -> None:
    task = (
        await client.post(
            "/api/v1/tasks", json={"topic_id": topic_id, "title": "linked"}
        )
    ).json()
    goal = (
        await client.post(
            "/api/v1/goals", json={"title": "later", "target_value": 1}
        )
    ).json()
    r = await client.post(
        f"/api/v1/goals/{goal['id']}/links",
        json={"target_type": "task", "target_id": task["id"]},
    )
    assert r.status_code == 201

    r = await client.delete(
        f"/api/v1/goals/{goal['id']}/links",
        params={"target_type": "task", "target_id": task["id"]},
    )
    assert r.status_code == 204

    r = await client.delete(
        f"/api/v1/goals/{goal['id']}/links",
        params={"target_type": "task", "target_id": task["id"]},
    )
    assert r.status_code == 404
