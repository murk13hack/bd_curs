"""Статистика: разбивки по темам/времени, корреляции, недели."""

from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Query
from sqlalchemy import text

from app.api.v1.deps import SessionDep, UserIdDep
from app.schemas.stats import (
    CorrelationWeek,
    TopicBreakdown,
    TopicTimeBreakdown,
    WeeklySummary,
)

router = APIRouter(prefix="/stats", tags=["stats"])


@router.get(
    "/topics",
    response_model=list[TopicBreakdown],
    summary="Разрез задач по темам (v_task_topic_breakdown)",
)
async def topics_breakdown(
    session: SessionDep, user_id: UserIdDep
) -> list[TopicBreakdown]:
    res = await session.execute(
        text(
            "SELECT topic_id, topic_name, total, done, overdue, completion_rate,"
            " avg_planned_minutes, avg_overdue_minutes "
            "FROM v_task_topic_breakdown WHERE user_id = :uid "
            "ORDER BY total DESC"
        ).bindparams(uid=user_id)
    )
    return [
        TopicBreakdown(
            topic_id=r[0],
            topic_name=r[1],
            total=r[2],
            done=r[3],
            overdue=r[4],
            completion_rate=float(r[5]) if r[5] is not None else 0.0,
            avg_planned_minutes=r[6],
            avg_overdue_minutes=float(r[7]) if r[7] is not None else None,
        )
        for r in res
    ]


@router.get(
    "/time-distribution",
    response_model=list[TopicTimeBreakdown],
    summary="Распределение времени по темам (v_topic_time_distribution)",
)
async def time_distribution(
    session: SessionDep, user_id: UserIdDep
) -> list[TopicTimeBreakdown]:
    res = await session.execute(
        text(
            "SELECT topic_id, topic_name, minutes, pomodoro_minutes "
            "FROM v_topic_time_distribution WHERE user_id = :uid ORDER BY minutes DESC"
        ).bindparams(uid=user_id)
    )
    return [
        TopicTimeBreakdown(
            topic_id=r[0],
            topic_name=r[1],
            minutes=int(r[2]),
            pomodoro_minutes=int(r[3]),
        )
        for r in res
    ]


@router.get(
    "/correlation",
    response_model=list[CorrelationWeek],
    summary="Mood/energy ↔ продуктивность по неделям (v_mood_productivity_correlation)",
)
async def correlation(
    session: SessionDep,
    user_id: UserIdDep,
    from_: date | None = Query(default=None, alias="from"),
    to: date | None = None,
) -> list[CorrelationWeek]:
    sql = (
        "SELECT week_start, avg_mood, avg_energy, avg_completion_rate,"
        " corr_mood_rate, corr_energy_rate, days_count "
        "FROM v_mood_productivity_correlation WHERE user_id = :uid"
    )
    params: dict = {"uid": user_id}
    if from_ is not None:
        sql += " AND week_start >= :f"
        params["f"] = from_
    if to is not None:
        sql += " AND week_start <= :t"
        params["t"] = to
    sql += " ORDER BY week_start"

    res = await session.execute(text(sql).bindparams(**params))
    return [
        CorrelationWeek(
            week_start=r[0],
            avg_mood=float(r[1]) if r[1] is not None else None,
            avg_energy=float(r[2]) if r[2] is not None else None,
            avg_completion_rate=float(r[3]) if r[3] is not None else None,
            corr_mood_rate=float(r[4]) if r[4] is not None else None,
            corr_energy_rate=float(r[5]) if r[5] is not None else None,
            days_count=r[6],
        )
        for r in res
    ]


@router.get(
    "/weekly",
    response_model=list[WeeklySummary],
    summary="Недельная сводка (v_weekly_summary)",
)
async def weekly(
    session: SessionDep,
    user_id: UserIdDep,
    from_: date | None = Query(default=None, alias="from"),
    to: date | None = None,
    limit: int = Query(default=12, ge=1, le=104),
) -> list[WeeklySummary]:
    sql = (
        "SELECT week_start, tasks_total, tasks_done, tasks_overdue,"
        " minutes_logged, diary_entries "
        "FROM v_weekly_summary WHERE user_id = :uid"
    )
    params: dict = {"uid": user_id}
    if from_ is not None:
        sql += " AND week_start >= :f"
        params["f"] = from_
    if to is not None:
        sql += " AND week_start <= :t"
        params["t"] = to
    sql += " ORDER BY week_start DESC LIMIT :lim"
    params["lim"] = limit

    res = await session.execute(text(sql).bindparams(**params))
    return [
        WeeklySummary(
            week_start=r[0],
            tasks_total=r[1],
            tasks_done=r[2],
            tasks_overdue=r[3],
            minutes_logged=int(r[4]),
            diary_entries=r[5],
        )
        for r in res
    ]


@router.get(
    "/completion-rate",
    summary="% выполнения задач за период (fn_completion_rate)",
)
async def completion_rate(
    session: SessionDep,
    user_id: UserIdDep,
    from_: date = Query(alias="from"),
    to: date = Query(),
    topic_id: int | None = None,
) -> dict:
    res = await session.execute(
        text("SELECT fn_completion_rate(:uid, :f, :t, :tp)").bindparams(
            uid=user_id, f=from_, t=to, tp=topic_id
        )
    )
    val = res.scalar_one()
    return {"from": from_, "to": to, "topic_id": topic_id, "rate": float(val or 0)}
