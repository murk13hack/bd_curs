"""Импорт/экспорт."""

from __future__ import annotations

from httpx import AsyncClient


async def test_export_json_contains_topics(client: AsyncClient) -> None:
    r = await client.get("/api/v1/export/json")
    assert r.status_code == 200
    data = r.json()["data"]
    assert data["schema_version"] == 2
    names = {t["name"] for t in data["topics"]}
    assert "Работа" in names
    assert "pattern_steps" in data
    assert "pattern_markers" in data
    assert "pattern_marker_day_closures" in data
    assert "recurring_rules" in data


async def test_import_restore_replaces_data(client: AsyncClient) -> None:
    export = (await client.get("/api/v1/export/json")).json()["data"]
    await client.post(
        "/api/v1/import/json",
        json={
            "data": {"topics": [{"name": "ToBeWipedOnRestore", "color": "#000000"}]},
            "mode": "merge",
        },
    )
    export["topics"] = list(export.get("topics") or [])
    export["topics"].append({"id": 99999, "name": "RestoreOnlyTopic", "color": "#FF00FF"})
    export["schema_version"] = 2

    r = await client.post(
        "/api/v1/import/json",
        json={"data": export, "mode": "restore"},
    )
    assert r.status_code == 202
    assert r.json()["mode"] == "restore"

    topics = (await client.get("/api/v1/topics")).json()
    names = {t["name"] for t in topics}
    assert "RestoreOnlyTopic" in names
    assert "ToBeWipedOnRestore" not in names


async def test_import_restore_patterns_and_tasks(client: AsyncClient, topic_id: int) -> None:
    await client.post(
        "/api/v1/patterns",
        json={
            "title": "RestorePattern",
            "pattern_type": "positive",
            "is_boolean": True,
        },
    )
    await client.post(
        "/api/v1/tasks",
        json={
            "topic_id": topic_id,
            "title": "RestoreRecurringTask",
            "recurring": {
                "frequency": "weekly",
                "params": {"weekly_mask": 127},
                "is_active": True,
            },
        },
    )

    export = (await client.get("/api/v1/export/json")).json()["data"]
    await client.post(
        "/api/v1/import/json",
        json={
            "data": {"topics": [{"name": "WipeMarker", "color": "#111111"}]},
            "mode": "merge",
        },
    )

    r = await client.post(
        "/api/v1/import/json",
        json={"data": export, "mode": "restore"},
    )
    assert r.status_code == 202

    patterns = (await client.get("/api/v1/patterns")).json()
    assert any(p["title"] == "RestorePattern" for p in patterns)

    tasks = (await client.get("/api/v1/tasks", params={"view": "all", "limit": 500})).json()
    restored = next(t for t in tasks if t["title"] == "RestoreRecurringTask")
    assert restored["recurring_rule_id"] is not None

    rule = (await client.get(f"/api/v1/tasks/{restored['id']}/recurring")).json()
    assert rule["frequency"] == "weekly"

    topics = (await client.get("/api/v1/topics")).json()
    assert not any(t["name"] == "WipeMarker" for t in topics)


async def test_import_json_idempotent_topics(client: AsyncClient) -> None:
    payload = {
        "data": {
            "topics": [
                {"name": "Импорт-1", "color": "#AABBCC"},
                {"name": "Импорт-2", "color": "#112233"},
            ],
            "tags": [{"name": "imp-tag"}],
        }
    }
    r = await client.post("/api/v1/import/json", json=payload)
    assert r.status_code == 202

    listing = (await client.get("/api/v1/topics")).json()
    assert {"Импорт-1", "Импорт-2"} <= {t["name"] for t in listing}

    # повторный импорт не должен ломаться
    r = await client.post("/api/v1/import/json", json=payload)
    assert r.status_code == 202


async def test_import_restore_marker_day_closures(client: AsyncClient) -> None:
    created = await client.post(
        "/api/v1/patterns",
        json={
            "title": "RestoreClosurePattern",
            "pattern_type": "negative",
            "pattern_mode": "markers",
            "schedules": [{"time_of_day": "12:00:00", "dow_mask": 127}],
        },
    )
    assert created.status_code == 201
    pid = created.json()["id"]

    r = await client.post(f"/api/v1/patterns/{pid}/markers/declare-clean-day")
    assert r.status_code == 204

    export = (await client.get("/api/v1/export/json")).json()["data"]
    closures = export.get("pattern_marker_day_closures") or []
    assert any(c["pattern_id"] == pid for c in closures)

    await client.post(
        "/api/v1/import/json",
        json={"data": {"topics": [{"name": "WipeBeforeRestore", "color": "#000000"}]}, "mode": "merge"},
    )

    restore = await client.post(
        "/api/v1/import/json",
        json={"data": export, "mode": "restore"},
    )
    assert restore.status_code == 202

    today = await client.get(f"/api/v1/patterns/{pid}/today")
    assert today.status_code == 200
    body = today.json()
    assert body["day_declared_clean"] is True
    assert body["is_success_today"] is True


async def test_recurring_custom_interval_days(client: AsyncClient, topic_id: int) -> None:
    task = await client.post(
        "/api/v1/tasks",
        json={
            "topic_id": topic_id,
            "title": "CustomIntervalTask",
            "recurring": {
                "frequency": "custom",
                "params": {"interval_days": 3},
                "is_active": True,
            },
        },
    )
    assert task.status_code == 201
    tid = task.json()["id"]
    rule = (await client.get(f"/api/v1/tasks/{tid}/recurring")).json()
    assert rule["frequency"] == "custom"
    assert rule["params"]["interval_days"] == 3


async def test_export_tasks_csv(client: AsyncClient, topic_id: int) -> None:
    await client.post(
        "/api/v1/tasks", json={"topic_id": topic_id, "title": "csv-row"}
    )
    r = await client.get("/api/v1/export/csv/tasks")
    assert r.status_code == 200
    body = r.text
    header = body.splitlines()[0]
    assert header.startswith("id,title")
    assert "csv-row" in body
