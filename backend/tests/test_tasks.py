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


async def test_create_task_start_and_deadline_iso(
    client: AsyncClient, topic_id: int
) -> None:
    r = await client.post(
        "/api/v1/tasks",
        json={
            "topic_id": topic_id,
            "title": "dated task",
            "start_at": "2003-02-01T20:00:00.000Z",
            "deadline": "2003-02-01T22:01:00.000Z",
        },
    )
    assert r.status_code == 201
    body = r.json()
    assert body["start_at"] is not None
    assert body["deadline"] is not None


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

    r = await client.get("/api/v1/tasks", params={"q": "хле"})
    assert r.status_code == 200
    titles = [t["title"] for t in r.json()]
    assert titles == ["купить хлеб"]

    r = await client.get("/api/v1/tasks", params={"q": "посуд"})
    assert r.status_code == 200
    titles = [t["title"] for t in r.json()]
    assert titles == ["помыть посуду"]


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


async def test_time_logs_overlap_allowed(
    client: AsyncClient, topic_id: int
) -> None:
    task_a = (
        await client.post(
            "/api/v1/tasks", json={"topic_id": topic_id, "title": "tracked A"}
        )
    ).json()
    task_b = (
        await client.post(
            "/api/v1/tasks", json={"topic_id": topic_id, "title": "tracked B"}
        )
    ).json()
    base = datetime.now(tz=timezone.utc).replace(microsecond=0)
    log_a = {
        "started_at": base.isoformat(),
        "ended_at": (base + timedelta(minutes=25)).isoformat(),
        "is_pomodoro": True,
    }
    r = await client.post(f"/api/v1/tasks/{task_a['id']}/time-logs", json=log_a)
    assert r.status_code == 201

    overlap = {
        "started_at": (base + timedelta(minutes=10)).isoformat(),
        "ended_at": (base + timedelta(minutes=40)).isoformat(),
        "is_pomodoro": True,
    }
    r = await client.post(f"/api/v1/tasks/{task_b['id']}/time-logs", json=overlap)
    assert r.status_code == 201


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


async def test_create_with_start_at(client: AsyncClient, topic_id: int) -> None:
    start = datetime.now(tz=timezone.utc) + timedelta(hours=1)
    deadline = start + timedelta(hours=2)
    r = await client.post(
        "/api/v1/tasks",
        json={
            "topic_id": topic_id,
            "title": "scheduled",
            "start_at": start.isoformat(),
            "deadline": deadline.isoformat(),
        },
    )
    assert r.status_code == 201
    body = r.json()
    assert body["start_at"] is not None
    assert body["deadline"] is not None


async def test_start_at_after_deadline_422(client: AsyncClient, topic_id: int) -> None:
    start = datetime.now(tz=timezone.utc) + timedelta(days=2)
    deadline = datetime.now(tz=timezone.utc) + timedelta(days=1)
    r = await client.post(
        "/api/v1/tasks",
        json={
            "topic_id": topic_id,
            "title": "bad window",
            "start_at": start.isoformat(),
            "deadline": deadline.isoformat(),
        },
    )
    assert r.status_code == 422


async def test_list_view_active_and_completed(
    client: AsyncClient, topic_id: int
) -> None:
    pending = (
        await client.post(
            "/api/v1/tasks", json={"topic_id": topic_id, "title": "active one"}
        )
    ).json()
    done = (
        await client.post(
            "/api/v1/tasks", json={"topic_id": topic_id, "title": "done one"}
        )
    ).json()
    await client.post(f"/api/v1/tasks/{done['id']}/complete")

    active = (await client.get("/api/v1/tasks", params={"view": "active"})).json()
    completed = (
        await client.get("/api/v1/tasks", params={"view": "completed"})
    ).json()
    active_ids = {t["id"] for t in active}
    completed_ids = {t["id"] for t in completed}
    assert pending["id"] in active_ids
    assert done["id"] in completed_ids
    assert pending["id"] not in completed_ids
    assert done["id"] not in active_ids


async def test_reopen_completed_task(client: AsyncClient, topic_id: int) -> None:
    created = (
        await client.post(
            "/api/v1/tasks", json={"topic_id": topic_id, "title": "reopen me"}
        )
    ).json()
    await client.post(f"/api/v1/tasks/{created['id']}/complete")
    r = await client.post(f"/api/v1/tasks/{created['id']}/reopen")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "in_progress"
    assert body["completed_at"] is None
