"""Импорт/экспорт."""

from __future__ import annotations

from httpx import AsyncClient


async def test_export_json_contains_topics(client: AsyncClient) -> None:
    r = await client.get("/api/v1/export/json")
    assert r.status_code == 200
    data = r.json()["data"]
    assert data["schema_version"] == 1
    names = {t["name"] for t in data["topics"]}
    assert "Работа" in names


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
