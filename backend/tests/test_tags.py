"""CRUD тегов."""

from __future__ import annotations

from httpx import AsyncClient


async def test_seed_tags(client: AsyncClient) -> None:
    r = await client.get("/api/v1/tags")
    assert r.status_code == 200
    names = {t["name"] for t in r.json()}
    assert {"важное", "срочное", "идея", "обучение", "спорт"} <= names


async def test_create_tag_and_duplicate(client: AsyncClient) -> None:
    r = await client.post("/api/v1/tags", json={"name": "newtag"})
    assert r.status_code == 201
    r2 = await client.post("/api/v1/tags", json={"name": "newtag"})
    assert r2.status_code == 409


async def test_rename_and_delete_tag(client: AsyncClient) -> None:
    created = (await client.post("/api/v1/tags", json={"name": "old"})).json()
    r = await client.patch(
        f"/api/v1/tags/{created['id']}", json={"name": "renamed"}
    )
    assert r.status_code == 200
    assert r.json()["name"] == "renamed"
    r = await client.delete(f"/api/v1/tags/{created['id']}")
    assert r.status_code == 204
    listing = (await client.get("/api/v1/tags")).json()
    assert all(t["id"] != created["id"] for t in listing)


async def test_get_missing_tag_404(client: AsyncClient) -> None:
    r = await client.patch("/api/v1/tags/99999", json={"name": "x"})
    assert r.status_code == 404
