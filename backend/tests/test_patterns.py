"""Паттерны: CRUD options/schedules + responses + streaks."""

from __future__ import annotations

from datetime import datetime, timezone

from httpx import AsyncClient


async def _create_boolean_pattern(client: AsyncClient) -> dict:
    r = await client.post(
        "/api/v1/patterns",
        json={
            "title": "Зарядка",
            "pattern_type": "positive",
            "is_boolean": True,
        },
    )
    assert r.status_code == 201, r.text
    return r.json()


async def test_create_boolean_creates_default_options(client: AsyncClient) -> None:
    p = await _create_boolean_pattern(client)
    labels = sorted(o["label"] for o in p["options"])
    assert labels == ["Не сделал", "Сделал"]
    success_flags = {o["label"]: o["is_success"] for o in p["options"]}
    assert success_flags["Сделал"] is True
    assert success_flags["Не сделал"] is False


async def test_negative_boolean_default_options(client: AsyncClient) -> None:
    r = await client.post(
        "/api/v1/patterns",
        json={
            "title": "Курение",
            "pattern_type": "negative",
            "is_boolean": True,
        },
    )
    assert r.status_code == 201
    p = r.json()
    labels = sorted(o["label"] for o in p["options"])
    assert labels == ["0 раз", "1 раз", "2+ раз"]
    success = {o["label"]: o["is_success"] for o in p["options"]}
    assert success["0 раз"] is True
    assert success["1 раз"] is False
    assert success["2+ раз"] is False


async def test_add_schedule_and_option(client: AsyncClient) -> None:
    p = await _create_boolean_pattern(client)
    r = await client.post(
        f"/api/v1/patterns/{p['id']}/schedules",
        json={"time_of_day": "08:00:00", "dow_mask": 31},
    )
    assert r.status_code == 201
    r = await client.post(
        f"/api/v1/patterns/{p['id']}/options",
        json={"label": "Скипнул", "is_success": False, "sort_order": 2},
    )
    assert r.status_code == 201

    fetched = (await client.get(f"/api/v1/patterns/{p['id']}")).json()
    assert any(s["dow_mask"] == 31 for s in fetched["schedules"])
    assert any(o["label"] == "Скипнул" for o in fetched["options"])


async def test_log_response_and_streak(client: AsyncClient) -> None:
    p = await _create_boolean_pattern(client)
    success_id = next(o["id"] for o in p["options"] if o["is_success"])

    r = await client.post(
        f"/api/v1/patterns/{p['id']}/responses",
        json={
            "response_option_id": success_id,
            "scheduled_at": datetime.now(tz=timezone.utc).isoformat(),
        },
    )
    assert r.status_code == 204

    r = await client.get(f"/api/v1/patterns/{p['id']}/streak")
    assert r.status_code == 200
    body = r.json()
    assert body["current_streak"] >= 1


async def test_streaks_view(client: AsyncClient) -> None:
    p = await _create_boolean_pattern(client)
    success_id = next(o["id"] for o in p["options"] if o["is_success"])
    await client.post(
        f"/api/v1/patterns/{p['id']}/responses",
        json={"response_option_id": success_id},
    )
    r = await client.get("/api/v1/patterns/streaks/all")
    assert r.status_code == 200
    rows = r.json()
    assert len(rows) == 1
    assert rows[0]["pattern_id"] == p["id"]
    assert rows[0]["scheduled_days_30d"] >= 0
    assert rows[0]["clean_rate_30d"] >= 0


async def test_delete_pattern_cascades(client: AsyncClient) -> None:
    p = await _create_boolean_pattern(client)
    r = await client.delete(f"/api/v1/patterns/{p['id']}")
    assert r.status_code == 204
    r = await client.get(f"/api/v1/patterns/{p['id']}")
    assert r.status_code == 404


async def test_negative_habit_streak_correct(client: AsyncClient) -> None:
    """0 раз = успех серии, 1 раз = срыв (без двойной инверсии)."""
    p = (
        await client.post(
            "/api/v1/patterns",
            json={
                "title": "Курение",
                "pattern_type": "negative",
                "pattern_mode": "habit",
                "is_boolean": True,
            },
        )
    ).json()
    opt = {o["label"]: o["id"] for o in p["options"]}
    await client.post(
        f"/api/v1/patterns/{p['id']}/responses",
        json={"response_option_id": opt["0 раз"]},
    )
    streak = (await client.get(f"/api/v1/patterns/{p['id']}/streak")).json()
    assert streak["current_streak"] >= 1

    await client.post(
        f"/api/v1/patterns/{p['id']}/responses",
        json={"response_option_id": opt["1 раз"]},
    )
    streak2 = (await client.get(f"/api/v1/patterns/{p['id']}/streak")).json()
    assert streak2["current_streak"] == 0


async def test_scenario_session_flow(client: AsyncClient) -> None:
    created = (
        await client.post(
            "/api/v1/patterns",
            json={
                "title": "Test scenario",
                "pattern_type": "negative",
                "pattern_mode": "scenario",
                "steps": [
                    {
                        "title": "Outcome",
                        "step_kind": "single_choice",
                        "step_role": "outcome",
                        "marks_success": True,
                        "choices": [
                            {"id": "ok", "label": "Clean", "is_success": True},
                            {"id": "bad", "label": "Smoked", "is_success": False},
                        ],
                    },
                ],
            },
        )
    ).json()
    pid = created["id"]
    step_id = created["steps"][0]["id"]

    sess = (await client.post(f"/api/v1/patterns/{pid}/sessions/today")).json()
    await client.patch(
        f"/api/v1/patterns/{pid}/sessions/{sess['id']}/steps/{step_id}",
        json={"choice_id": "ok"},
    )
    done = (
        await client.post(f"/api/v1/patterns/{pid}/sessions/{sess['id']}/complete")
    ).json()
    assert done["status"] == "completed"
    assert done["outcome_success"] is True

    streak = (await client.get(f"/api/v1/patterns/{pid}/streak")).json()
    assert streak["current_streak"] >= 1


async def test_pattern_insights_habit(client: AsyncClient) -> None:
    p = await _create_boolean_pattern(client)
    success_id = next(o["id"] for o in p["options"] if o["is_success"])
    await client.post(
        f"/api/v1/patterns/{p['id']}/responses",
        json={"response_option_id": success_id},
    )
    r = await client.get(f"/api/v1/patterns/{p['id']}/insights?days=7")
    assert r.status_code == 200
    body = r.json()
    assert body["pattern_id"] == p["id"]
    assert len(body["calendar"]) == 7
    assert body["success_days"] >= 1
    assert "diary_correlation" in body
    assert "time_of_day_stats" in body


async def test_markers_flow(client: AsyncClient) -> None:
    created = (
        await client.post(
            "/api/v1/patterns",
            json={
                "title": "Craving markers",
                "pattern_type": "negative",
                "pattern_mode": "markers",
            },
        )
    ).json()
    pid = created["id"]
    assert len(created["options"]) >= 2
    bad_id = next(o["id"] for o in created["options"] if not o["is_success"])

    r = await client.post(
        f"/api/v1/patterns/{pid}/markers",
        json={"marker_option_id": bad_id},
    )
    assert r.status_code == 201
    assert r.json()["label"]

    today = (await client.get(f"/api/v1/patterns/{pid}/today")).json()
    assert today["markers_today_count"] == 1
    assert today["is_success_today"] is False

    streak = (await client.get(f"/api/v1/patterns/{pid}/streak")).json()
    assert streak["current_streak"] == 0

    ins = (await client.get(f"/api/v1/patterns/{pid}/insights?days=7")).json()
    assert ins["hourly_counts"]
    assert len(ins["calendar"]) == 7


async def test_pattern_insights_scenario(client: AsyncClient) -> None:
    created = (
        await client.post(
            "/api/v1/patterns",
            json={
                "title": "Insights scenario",
                "pattern_type": "negative",
                "pattern_mode": "scenario",
                "steps": [
                    {
                        "title": "Trigger",
                        "step_kind": "single_choice",
                        "step_role": "trigger",
                        "choices": [
                            {"id": "stress", "label": "Stress", "is_success": False},
                            {"id": "calm", "label": "Calm", "is_success": True},
                        ],
                    },
                    {
                        "title": "Outcome",
                        "step_kind": "single_choice",
                        "step_role": "outcome",
                        "marks_success": True,
                        "choices": [
                            {"id": "ok", "label": "Clean", "is_success": True},
                            {"id": "bad", "label": "Smoked", "is_success": False},
                        ],
                    },
                ],
            },
        )
    ).json()
    pid = created["id"]
    steps = {s["title"]: s["id"] for s in created["steps"]}

    sess = (await client.post(f"/api/v1/patterns/{pid}/sessions/today")).json()
    await client.patch(
        f"/api/v1/patterns/{pid}/sessions/{sess['id']}/steps/{steps['Trigger']}",
        json={"choice_id": "stress"},
    )
    await client.patch(
        f"/api/v1/patterns/{pid}/sessions/{sess['id']}/steps/{steps['Outcome']}",
        json={"choice_id": "bad"},
    )
    await client.post(f"/api/v1/patterns/{pid}/sessions/{sess['id']}/complete")

    r = await client.get(f"/api/v1/patterns/{pid}/insights?days=30")
    assert r.status_code == 200
    body = r.json()
    assert body["success_days"] == 0
    assert len(body["choice_breakdown"]) >= 2
    assert any(p["path"] for p in body["top_paths"])
    assert isinstance(body["insights"], list)


async def test_markers_declare_clean_day(client: AsyncClient) -> None:
    p = (
        await client.post(
            "/api/v1/patterns",
            json={
                "title": "Markers clean",
                "pattern_type": "negative",
                "pattern_mode": "markers",
            },
        )
    ).json()
    pid = p["id"]
    r = await client.post(f"/api/v1/patterns/{pid}/markers/declare-clean-day")
    assert r.status_code == 204
    today = (await client.get(f"/api/v1/patterns/{pid}/today")).json()
    assert today["day_declared_clean"] is True
    assert today["is_success_today"] is True
    streak = (await client.get(f"/api/v1/patterns/{pid}/streak")).json()
    assert streak["current_streak"] >= 1


async def test_markers_streak_after_positive_episode(client: AsyncClient) -> None:
    p = (
        await client.post(
            "/api/v1/patterns",
            json={
                "title": "Markers one good",
                "pattern_type": "negative",
                "pattern_mode": "markers",
            },
        )
    ).json()
    pid = p["id"]
    good = next(o for o in p["options"] if o["is_success"])
    await client.post(
        f"/api/v1/patterns/{pid}/markers",
        json={"marker_option_id": good["id"]},
    )
    streak = (await client.get(f"/api/v1/patterns/{pid}/streak")).json()
    assert streak["current_streak"] == 1
    assert streak["success_days_30d"] <= 2
    assert streak["scheduled_days_30d"] >= 1


async def test_markers_empty_day_not_success(client: AsyncClient) -> None:
    p = (
        await client.post(
            "/api/v1/patterns",
            json={
                "title": "Markers empty",
                "pattern_type": "negative",
                "pattern_mode": "markers",
            },
        )
    ).json()
    today = (await client.get(f"/api/v1/patterns/{p['id']}/today")).json()
    assert today["markers_today_count"] == 0
    assert today["is_success_today"] is None

    streak = (await client.get(f"/api/v1/patterns/{p['id']}/streak")).json()
    assert streak["current_streak"] == 0


async def test_scenario_in_progress_today_status(client: AsyncClient) -> None:
    created = (
        await client.post(
            "/api/v1/patterns",
            json={
                "title": "In progress scenario",
                "pattern_type": "negative",
                "pattern_mode": "scenario",
                "steps": [
                    {
                        "title": "Outcome",
                        "step_kind": "single_choice",
                        "step_role": "outcome",
                        "marks_success": True,
                        "choices": [
                            {"id": "ok", "label": "Clean", "is_success": True},
                        ],
                    },
                ],
            },
        )
    ).json()
    pid = created["id"]
    await client.post(f"/api/v1/patterns/{pid}/sessions/today")
    today = (await client.get(f"/api/v1/patterns/{pid}/today")).json()
    assert today["status"] == "in_progress"
    assert today["is_success_today"] is None
    streak = (await client.get(f"/api/v1/patterns/{pid}/streak")).json()
    assert streak["current_streak"] == 0


async def test_pattern_today_endpoint(client: AsyncClient) -> None:
    p = await _create_boolean_pattern(client)
    r = await client.get(f"/api/v1/patterns/{p['id']}/today")
    assert r.status_code == 200
    body = r.json()
    assert body["pattern_id"] == p["id"]
    assert body["is_scheduled_today"] is True
    assert body["status"] == "pending"
    assert body["can_respond"] is True
    assert body.get("log_status") == "pending"

    success_id = next(o["id"] for o in p["options"] if o["is_success"])
    await client.post(
        f"/api/v1/patterns/{p['id']}/responses",
        json={
            "response_option_id": success_id,
            "scheduled_at": datetime.now(tz=timezone.utc).isoformat(),
        },
    )
    r = await client.get(f"/api/v1/patterns/{p['id']}/today")
    body = r.json()
    assert body["status"] == "answered"
    assert body["response_label"] == "Сделал"
    assert body["is_success_today"] is True
