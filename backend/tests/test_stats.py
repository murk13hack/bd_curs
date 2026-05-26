"""Статистика."""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from httpx import AsyncClient


async def test_topics_breakdown_period(client: AsyncClient, topic_id: int) -> None:
    today = date.today()
    r = await client.get(
        "/api/v1/stats/topics",
        params={"from": today.isoformat(), "to": today.isoformat()},
    )
    assert r.status_code == 200


async def test_holistic_period(client: AsyncClient, topic_id: int) -> None:
    await client.post(
        "/api/v1/diary",
        json={"entry_date": date.today().isoformat(), "content": "h", "mood": 3, "energy": 3},
    )
    r = await client.get("/api/v1/stats/holistic", params={"days": 30})
    assert r.status_code == 200


async def test_olap_invalid_measure(client: AsyncClient) -> None:
    r = await client.post(
        "/api/v1/stats/olap",
        json={"dimensions": ["week"], "measures": ["not_a_measure"]},
    )
    assert r.status_code == 400


async def test_olap_invalid_filter(client: AsyncClient) -> None:
    r = await client.post(
        "/api/v1/stats/olap",
        json={
            "dimensions": ["week"],
            "measures": ["completion_rate"],
            "filters": {"mood_bucket": "invalid"},
        },
    )
    assert r.status_code == 400


async def test_olap_day_dimension_long_period(client: AsyncClient) -> None:
    today = date.today()
    from_d = today - timedelta(days=60)
    r = await client.post(
        "/api/v1/stats/olap",
        json={
            "dimensions": ["day"],
            "measures": ["completion_rate"],
            "date_from": from_d.isoformat(),
            "date_to": today.isoformat(),
        },
    )
    assert r.status_code == 400


async def test_olap_mood_bucket_filter(
    client: AsyncClient, topic_id: int
) -> None:
    await client.post(
        "/api/v1/diary",
        json={
            "entry_date": date.today().isoformat(),
            "content": "high mood",
            "mood": 5,
            "energy": 4,
        },
    )
    r = await client.post(
        "/api/v1/stats/olap",
        json={
            "dimensions": ["mood_bucket"],
            "measures": ["completion_rate", "diary_entries"],
            "filters": {"mood_bucket": "high"},
        },
    )
    assert r.status_code == 200
    rows = r.json()["rows"]
    assert len(rows) >= 1
    assert rows[0]["dimensions"]["mood_bucket"] == "high"


async def test_diary_insights(client: AsyncClient, topic_id: int) -> None:
    today = date.today().isoformat()
    deadline = (datetime.now(tz=timezone.utc) + timedelta(hours=2)).isoformat()
    await client.post(
        "/api/v1/diary",
        json={"entry_date": today, "content": "insight", "mood": 4, "energy": 4},
    )
    await client.post(
        "/api/v1/tasks",
        json={"topic_id": topic_id, "title": "corr task", "deadline": deadline},
    )
    r = await client.get("/api/v1/stats/diary-insights", params={"days": 30})
    assert r.status_code == 200
    body = r.json()
    assert body["diary_days"] >= 1
    assert "insights" in body and len(body["insights"]) >= 1
    assert "mood_buckets" in body
    assert "scatter_days" in body


async def test_topics_breakdown(client: AsyncClient, topic_id: int) -> None:
    deadline = (datetime.now(tz=timezone.utc) + timedelta(hours=1)).isoformat()
    for _ in range(3):
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "x", "deadline": deadline},
        )
    listing = (
        await client.get("/api/v1/tasks", params={"topic_id": topic_id})
    ).json()
    await client.post(f"/api/v1/tasks/{listing[0]['id']}/complete")

    r = await client.get("/api/v1/stats/topics")
    assert r.status_code == 200
    items = r.json()
    row = next(it for it in items if it["topic_id"] == topic_id)
    assert row["total"] == 3
    assert row["done"] == 1
    assert 30 <= row["completion_rate"] <= 35


async def test_completion_rate(client: AsyncClient, topic_id: int) -> None:
    deadline = (datetime.now(tz=timezone.utc) + timedelta(hours=1)).isoformat()
    for _ in range(2):
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "y", "deadline": deadline},
        )
    listing = (await client.get("/api/v1/tasks")).json()
    await client.post(f"/api/v1/tasks/{listing[0]['id']}/complete")

    today = date.today()
    r = await client.get(
        "/api/v1/stats/completion-rate",
        params={"from": today.isoformat(), "to": today.isoformat()},
    )
    assert r.status_code == 200
    rate = r.json()["rate"]
    assert 49 <= rate <= 51  # 1/2 = 50%


async def test_weekly_summary_smoke(client: AsyncClient, topic_id: int) -> None:
    deadline = (datetime.now(tz=timezone.utc) + timedelta(hours=1)).isoformat()
    await client.post(
        "/api/v1/tasks",
        json={"topic_id": topic_id, "title": "x", "deadline": deadline},
    )
    r = await client.get("/api/v1/stats/weekly")
    assert r.status_code == 200
    rows = r.json()
    assert any(row["tasks_total"] >= 1 for row in rows)


async def test_time_distribution_with_pomodoro(
    client: AsyncClient, topic_id: int
) -> None:
    task = (
        await client.post(
            "/api/v1/tasks",
            json={"topic_id": topic_id, "title": "with pomodoro"},
        )
    ).json()
    base = datetime.now(tz=timezone.utc).replace(microsecond=0)
    await client.post(
        f"/api/v1/tasks/{task['id']}/time-logs",
        json={
            "started_at": base.isoformat(),
            "ended_at": (base + timedelta(minutes=25)).isoformat(),
            "is_pomodoro": True,
        },
    )
    r = await client.get("/api/v1/stats/time-distribution")
    assert r.status_code == 200
    row = next(it for it in r.json() if it["topic_id"] == topic_id)
    assert row["minutes"] >= 25
    assert row["pomodoro_minutes"] >= 25


async def test_priorities_breakdown(client: AsyncClient, topic_id: int) -> None:
    deadline = (datetime.now(tz=timezone.utc) + timedelta(hours=1)).isoformat()
    await client.post(
        "/api/v1/tasks",
        json={"topic_id": topic_id, "title": "prio", "priority": "high", "deadline": deadline},
    )
    r = await client.get("/api/v1/stats/priorities", params={"days": 30})
    assert r.status_code == 200
    rows = r.json()
    assert any(row["priority"] == "high" for row in rows)


async def test_stats_overview_and_olap(client: AsyncClient, topic_id: int) -> None:
    deadline = (datetime.now(tz=timezone.utc) + timedelta(hours=1)).isoformat()
    await client.post(
        "/api/v1/tasks",
        json={"topic_id": topic_id, "title": "olap task", "deadline": deadline},
    )
    await client.post(
        "/api/v1/diary",
        json={"entry_date": date.today().isoformat(), "content": "stats", "mood": 4, "energy": 3},
    )

    r = await client.get("/api/v1/stats/overview", params={"days": 30})
    assert r.status_code == 200
    body = r.json()
    assert body["tasks_total"] >= 1
    assert "pattern_clean_rate" in body

    r = await client.get("/api/v1/stats/meta")
    assert r.status_code == 200
    assert len(r.json()["dimensions"]) >= 4

    r = await client.post(
        "/api/v1/stats/olap",
        json={
            "dimensions": ["weekday"],
            "measures": ["tasks_total", "completion_rate", "avg_mood"],
        },
    )
    assert r.status_code == 200
    olap = r.json()
    assert "rows" in olap
    assert olap["measures"] == ["tasks_total", "completion_rate", "avg_mood"]

    r = await client.get("/api/v1/stats/holistic")
    assert r.status_code == 200

    r = await client.get("/api/v1/stats/meta")
    meta = r.json()
    assert meta.get("help")
    assert any(d["id"] == "week" for d in meta["dimensions"])

    r = await client.get("/api/v1/stats/patterns")
    assert r.status_code == 200
    stats_rows = r.json()
    r2 = await client.get("/api/v1/patterns/streaks/all")
    assert r2.status_code == 200
    streak_rows = r2.json()
    assert len(stats_rows) == len(streak_rows)
    if stats_rows:
        assert stats_rows[0]["pattern_mode"] in ("habit", "scenario", "markers")
