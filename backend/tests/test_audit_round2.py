"""Audit round 2: PATCH guard, cancel/start, import modes."""

from __future__ import annotations

from httpx import AsyncClient


async def test_patch_status_done_rejected(client: AsyncClient, topic_id: int) -> None:
    task = (
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "no patch done"},
        )
    ).json()
    r = await client.patch(f"/api/v1/tasks/{task['id']}", json={"status": "done"})
    assert r.status_code == 400


async def test_task_start_and_cancel(client: AsyncClient, topic_id: int) -> None:
    task = (
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "flow"},
        )
    ).json()
    r = await client.post(f"/api/v1/tasks/{task['id']}/start")
    assert r.status_code == 200
    assert r.json()["status"] == "in_progress"

    r = await client.post(f"/api/v1/tasks/{task['id']}/cancel")
    assert r.status_code == 200
    assert r.json()["status"] == "cancelled"


async def test_import_merge_mode(client: AsyncClient) -> None:
    r = await client.post(
        "/api/v1/import/json",
        json={"data": {"topics": [{"name": "MergeTopic", "color": "#AABBCC"}]}, "mode": "merge"},
    )
    assert r.status_code == 202
    assert r.json()["mode"] == "merge"


async def test_tasks_roots_only_excludes_subtasks(client: AsyncClient, topic_id: int) -> None:
    parent = (
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "parent"},
        )
    ).json()
    child = (
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "child", "parent_task_id": parent["id"]},
        )
    ).json()
    r = await client.get("/api/v1/tasks", params={"roots_only": True, "view": "all"})
    ids = [t["id"] for t in r.json()]
    assert parent["id"] in ids
    assert child["id"] not in ids
