"""Статистика: OLAP, обзор, разрезы по темам/времени/паттернам."""

from __future__ import annotations

from datetime import date

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import text

from app.api.v1.deps import SessionDep, UserIdDep
from app.schemas.stats import (
    CorrelationWeek,
    HolisticCorrelationWeek,
    OlapMeta,
    OlapQuery,
    OlapResult,
    PatternStatsRow,
    PriorityBreakdown,
    StatsOverview,
    TopicBreakdown,
    TopicTimeBreakdown,
    WeeklySummary,
)
from app.services.olap import fetch_overview, olap_meta, run_olap_query

router = APIRouter(prefix="/stats", tags=["stats"])


@router.get("/meta", response_model=OlapMeta, summary="OLAP: доступные измерения и меры")
async def stats_meta() -> OlapMeta:
    meta = olap_meta()
    return OlapMeta(**meta)


@router.get("/overview", response_model=StatsOverview, summary="KPI за период")
async def overview(
    session: SessionDep,
    user_id: UserIdDep,
    days: int = Query(default=30, ge=7, le=365),
) -> StatsOverview:
    data = await fetch_overview(session, user_id, days)
    return StatsOverview(**data)


@router.post("/olap", response_model=OlapResult, summary="OLAP-срез (GROUP BY)")
async def olap_query(
    payload: OlapQuery,
    session: SessionDep,
    user_id: UserIdDep,
) -> OlapResult:
    try:
        result = await run_olap_query(
            session,
            user_id,
            payload.dimensions,
            payload.measures,
            payload.date_from,
            payload.date_to,
            payload.filters,
        )
    except ValueError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e)) from e
    return OlapResult(**result)


@router.get("/topics", response_model=list[TopicBreakdown])
async def topics_breakdown(
    session: SessionDep, user_id: UserIdDep
) -> list[TopicBreakdown]:
    res = await session.execute(
        text(
            "SELECT topic_id, topic_name, total, done, overdue, completion_rate,"
            " avg_planned_minutes, avg_overdue_minutes "
            "FROM v_task_topic_breakdown WHERE user_id = :uid ORDER BY total DESC"
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


@router.get("/priorities", response_model=list[PriorityBreakdown])
async def priority_breakdown(
    session: SessionDep, user_id: UserIdDep
) -> list[PriorityBreakdown]:
    res = await session.execute(
        text(
            "SELECT priority, total, done, overdue, completion_rate "
            "FROM v_stats_task_priority WHERE user_id = :uid"
        ).bindparams(uid=user_id)
    )
    return [
        PriorityBreakdown(
            priority=r[0],
            total=r[1],
            done=r[2],
            overdue=r[3],
            completion_rate=float(r[4] or 0),
        )
        for r in res
    ]


@router.get("/patterns", response_model=list[PatternStatsRow])
async def patterns_breakdown(
    session: SessionDep, user_id: UserIdDep
) -> list[PatternStatsRow]:
    res = await session.execute(
        text(
            "SELECT pattern_id, title, pattern_type, pattern_mode,"
            " current_streak, max_streak, scheduled_days_30d, success_days_30d, clean_rate_30d "
            "FROM v_pattern_streaks WHERE user_id = :uid ORDER BY clean_rate_30d DESC"
        ).bindparams(uid=user_id)
    )
    return [
        PatternStatsRow(
            pattern_id=r[0],
            title=r[1],
            pattern_type=r[2],
            pattern_mode=r[3],
            current_streak=r[4],
            max_streak=r[5],
            scheduled_days_30d=r[6],
            success_days_30d=r[7],
            clean_rate_30d=float(r[8] or 0),
        )
        for r in res
    ]


@router.get("/time-distribution", response_model=list[TopicTimeBreakdown])
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


@router.get("/correlation", response_model=list[CorrelationWeek])
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


@router.get("/holistic", response_model=list[HolisticCorrelationWeek])
async def holistic_correlation(
    session: SessionDep,
    user_id: UserIdDep,
    from_: date | None = Query(default=None, alias="from"),
    to: date | None = None,
) -> list[HolisticCorrelationWeek]:
    sql = (
        "SELECT week_start, avg_mood, avg_energy, avg_task_rate, avg_pattern_clean_rate,"
        " avg_minutes, corr_mood_tasks, corr_mood_patterns, corr_energy_tasks, days_count "
        "FROM v_mood_holistic_correlation WHERE user_id = :uid"
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
        HolisticCorrelationWeek(
            week_start=r[0],
            avg_mood=float(r[1]) if r[1] is not None else None,
            avg_energy=float(r[2]) if r[2] is not None else None,
            avg_task_rate=float(r[3]) if r[3] is not None else None,
            avg_pattern_clean_rate=float(r[4]) if r[4] is not None else None,
            avg_minutes=float(r[5]) if r[5] is not None else None,
            corr_mood_tasks=float(r[6]) if r[6] is not None else None,
            corr_mood_patterns=float(r[7]) if r[7] is not None else None,
            corr_energy_tasks=float(r[8]) if r[8] is not None else None,
            days_count=r[9],
        )
        for r in res
    ]


@router.get("/weekly", response_model=list[WeeklySummary])
async def weekly(
    session: SessionDep,
    user_id: UserIdDep,
    from_: date | None = Query(default=None, alias="from"),
    to: date | None = None,
    limit: int = Query(default=12, ge=1, le=104),
) -> list[WeeklySummary]:
    sql = (
        "SELECT week_start, tasks_total, tasks_done, tasks_overdue,"
        " minutes_logged, diary_entries, avg_mood, avg_energy,"
        " patterns_scheduled, patterns_success, marker_events, marker_bad_events "
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
            avg_mood=float(r[6]) if r[6] is not None else None,
            avg_energy=float(r[7]) if r[7] is not None else None,
            patterns_scheduled=r[8] or 0,
            patterns_success=r[9] or 0,
            marker_events=r[10] or 0,
            marker_bad_events=r[11] or 0,
        )
        for r in res
    ]


@router.get("/completion-rate")
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
