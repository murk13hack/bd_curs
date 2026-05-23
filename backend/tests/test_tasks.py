"""Задачи: CRUD, complete, subtasks, time-logs."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from httpx import AsyncClient

from tests.conftest import db_exec


async def test_create_minimal(client: AsyncClient, topic_id: int) -> None:
    r = await client.post(
        "/api/v1/tasks", json={"topic_id": topic_id, "title": "buy bread"}
    )
    assert r.status_code == 201
    body = r.json()
    assert body["status"] == "pending"
    assert body["priority"] == "medium"
    assert body["title"] == "buy bread"


async def test_create_with_tags_and_filter(
    client: AsyncClient, topic_id: int, tag_id: int
) -> None:
    payload = {
        "topic_id": topic_id,
        "title": "tagged",
        "priority": "high",
        "tag_ids": [tag_id],
    }
    r = await client.post("/api/v1/tasks", json=payload)
    assert r.status_code == 201
    assert r.json()["tag_ids"] == [tag_id]

    r = await client.get(
        "/api/v1/tasks", params={"priority": "high", "topic_id": topic_id}
    )
    assert r.status_code == 200
    rows = r.json()
    assert len(rows) == 1
    assert rows[0]["title"] == "tagged"


async def test_list_filter_by_q(client: AsyncClient, topic_id: int) -> None:
    await client.post("/api/v1/tasks", json={"topic_id": topic_id, "title": "купить хлеб"})
    await client.post("/api/v1/tasks", json={"topic_id": topic_id, "title": "помыть посуду"})
    r = await client.get("/api/v1/tasks", params={"q": "хлеб"})
    assert r.status_code == 200
    titles = [t["title"] for t in r.json()]
    assert titles == ["купить хлеб"]


async def test_complete_pending_task(client: AsyncClient, topic_id: int) -> None:
    created = (
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "complete me"},
        )
    ).json()
    r = await client.post(f"/api/v1/tasks/{created['id']}/complete")
    assert r.status_code == 200
    assert r.json()["status"] == "done"
    assert r.json()["completed_at"] is not None


async def test_complete_late_triggers_overdue(
    client: AsyncClient, topic_id: int
) -> None:
    """Проверяем триггер trg_task_overdue_check: задача с дедлайном и planned_minutes,
    выполненная ПОСЛЕ дедлайна, должна получить статус overdue."""
    deadline = (datetime.now(tz=timezone.utc) + timedelta(seconds=2)).isoformat()
    created = (
        await client.post(
            "/api/v1/tasks",
            json={
                "topic_id": topic_id,
                "title": "overdue case",
                "deadline": deadline,
                "planned_minutes": 5,
            },
        )
    ).json()
    # Сдвигаем и created_at, и deadline в прошлое, сохраняя инвариант
    # «deadline > created_at» из CHECK constraint.
    await db_exec(
        "UPDATE tasks "
        "SET created_at = now() - INTERVAL '2 hours', "
        "    deadline   = now() - INTERVAL '1 hour' "
        "WHERE id = :id",
        id=created["id"],
    )
    r = await client.post(f"/api/v1/tasks/{created['id']}/complete")
    assert r.status_code == 200
    assert r.json()["status"] == "overdue"


async def test_patch_task(client: AsyncClient, topic_id: int) -> None:
    created = (
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "old"},
        )
    ).json()
    r = await client.patch(
        f"/api/v1/tasks/{created['id']}",
        json={"title": "new", "priority": "urgent"},
    )
    assert r.status_code == 200
    assert r.json()["title"] == "new"
    assert r.json()["priority"] == "urgent"


async def test_subtasks(client: AsyncClient, topic_id: int) -> None:
    parent = (
        await client.post(
            "/api/v1/tasks", json={"topic_id": topic_id, "title": "parent"}
        )
    ).json()
    for i in range(3):
        await client.post(
            "/api/v1/tasks",
            json={
                "topic_id": topic_id,
                "title": f"child {i}",
                "parent_task_id": parent["id"],
            },
        )
    r = await client.get(f"/api/v1/tasks/{parent['id']}/subtasks")
    assert r.status_code == 200
    assert len(r.json()) == 3


async def test_time_logs_ok_then_overlap_409(
    client: AsyncClient, topic_id: int
) -> None:
    task = (
        await client.post(
            "/api/v1/tasks", json={"topic_id": topic_id, "title": "tracked"}
        )
    ).json()
    base = datetime.now(tz=timezone.utc).replace(microsecond=0)
    log_a = {
        "started_at": base.isoformat(),
        "ended_at": (base + timedelta(minutes=25)).isoformat(),
        "is_pomodoro": True,
    }
    r = await client.post(
        f"/api/v1/tasks/{task['id']}/time-logs", json=log_a
    )
    assert r.status_code == 201
    assert r.json()["duration_seconds"] == 25 * 60

    overlap = {
        "started_at": (base + timedelta(minutes=10)).isoformat(),
        "ended_at": (base + timedelta(minutes=40)).isoformat(),
    }
    r = await client.post(
        f"/api/v1/tasks/{task['id']}/time-logs", json=overlap
    )
    assert r.status_code == 409


async def test_delete_task(client: AsyncClient, topic_id: int) -> None:
    created = (
        await client.post(
            "/api/v1/tasks", json={"topic_id": topic_id, "title": "del"}
        )
    ).json()
    r = await client.delete(f"/api/v1/tasks/{created['id']}")
    assert r.status_code == 204
    r = await client.get(f"/api/v1/tasks/{created['id']}")
    assert r.status_code == 404
