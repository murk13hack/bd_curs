"""CRUD тем."""

from __future__ import annotations

from httpx import AsyncClient


async def test_seed_topics_present(client: AsyncClient) -> None:
    r = await client.get("/api/v1/topics")
    assert r.status_code == 200
    names = {t["name"] for t in r.json()}
    assert {"Работа", "Учёба", "Здоровье", "Личное", "Привычки", "Прочее"} <= names


async def test_create_topic(client: AsyncClient) -> None:
    r = await client.post(
        "/api/v1/topics", json={"name": "Тестовая", "color": "#123456"}
    )
    assert r.status_code == 201
    body = r.json()
    assert body["name"] == "Тестовая"
    assert body["color"] == "#123456"
    assert "id" in body


async def test_create_topic_duplicate_returns_409(client: AsyncClient) -> None:
    r = await client.post("/api/v1/topics", json={"name": "Работа"})
    assert r.status_code == 409


async def test_create_topic_invalid_color(client: AsyncClient) -> None:
    r = await client.post(
        "/api/v1/topics", json={"name": "X", "color": "blue"}
    )
    assert r.status_code == 422


async def test_update_topic(client: AsyncClient, topic_id: int) -> None:
    r = await client.patch(
        f"/api/v1/topics/{topic_id}", json={"color": "#000000"}
    )
    assert r.status_code == 200
    assert r.json()["color"] == "#000000"


async def test_delete_topic(client: AsyncClient) -> None:
    created = (
        await client.post("/api/v1/topics", json={"name": "Ddel"})
    ).json()
    r = await client.delete(f"/api/v1/topics/{created['id']}")
    assert r.status_code == 204
    listing = (await client.get("/api/v1/topics")).json()
    assert all(t["id"] != created["id"] for t in listing)


async def test_delete_topic_in_use_409(
    client: AsyncClient, topic_id: int
) -> None:
    """Удаление темы, к которой привязана задача, должно вернуть 409."""
    await client.post(
        "/api/v1/tasks", json={"topic_id": topic_id, "title": "guard"}
    )
    r = await client.delete(f"/api/v1/topics/{topic_id}")
    assert r.status_code == 409
