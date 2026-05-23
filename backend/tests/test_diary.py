"""Дневник: CRUD + FTS-поиск через fn_search_diary."""

from __future__ import annotations

from datetime import date

from httpx import AsyncClient


async def test_create_and_get_by_date(client: AsyncClient) -> None:
    today = date.today().isoformat()
    r = await client.post(
        "/api/v1/diary",
        json={"entry_date": today, "content": "first day", "mood": 4, "energy": 3},
    )
    assert r.status_code == 201
    body = r.json()
    assert body["mood"] == 4

    r = await client.get(f"/api/v1/diary/by-date/{today}")
    assert r.status_code == 200
    assert r.json()["content"] == "first day"


async def test_duplicate_date_409(client: AsyncClient) -> None:
    today = date.today().isoformat()
    r1 = await client.post(
        "/api/v1/diary", json={"entry_date": today, "content": "a"}
    )
    assert r1.status_code == 201
    r2 = await client.post(
        "/api/v1/diary", json={"entry_date": today, "content": "b"}
    )
    assert r2.status_code == 409


async def test_update_entry(client: AsyncClient) -> None:
    today = date.today().isoformat()
    created = (
        await client.post(
            "/api/v1/diary", json={"entry_date": today, "content": "draft"}
        )
    ).json()
    r = await client.patch(
        f"/api/v1/diary/{created['id']}",
        json={"content": "updated", "mood": 5},
    )
    assert r.status_code == 200
    assert r.json()["content"] == "updated"
    assert r.json()["mood"] == 5


async def test_search_fts(client: AsyncClient) -> None:
    today = date.today().isoformat()
    await client.post(
        "/api/v1/diary",
        json={
            "entry_date": today,
            "content": "Сегодня изучал PostgreSQL и индексы",
        },
    )
    r = await client.get("/api/v1/diary/search", params={"q": "PostgreSQL"})
    assert r.status_code == 200
    hits = r.json()
    assert len(hits) == 1
    assert "PostgreSQL" in hits[0]["snippet"] or "<<" in hits[0]["snippet"]


async def test_list_filter_by_date(client: AsyncClient) -> None:
    await client.post(
        "/api/v1/diary", json={"entry_date": "2026-01-01", "content": "ny"}
    )
    await client.post(
        "/api/v1/diary", json={"entry_date": "2026-02-01", "content": "feb"}
    )
    r = await client.get(
        "/api/v1/diary", params={"from": "2026-01-15", "to": "2026-02-28"}
    )
    assert r.status_code == 200
    dates = [e["entry_date"] for e in r.json()]
    assert dates == ["2026-02-01"]


async def test_delete_entry(client: AsyncClient) -> None:
    today = date.today().isoformat()
    created = (
        await client.post(
            "/api/v1/diary", json={"entry_date": today, "content": "x"}
        )
    ).json()
    r = await client.delete(f"/api/v1/diary/{created['id']}")
    assert r.status_code == 204
    r = await client.get(f"/api/v1/diary/by-date/{today}")
    assert r.status_code == 404
