"""Календарь: данные по месяцу + годовой heatmap."""

from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Path, Query
from sqlalchemy import text

from app.api.v1.deps import SessionDep, UserIdDep
from app.schemas.calendar import CalendarDay, HeatmapPoint

router = APIRouter(prefix="/calendar", tags=["calendar"])


@router.get(
    "/{year}/{month}",
    response_model=list[CalendarDay],
    summary="Календарь на месяц (fn_get_calendar_stats)",
)
async def calendar_month(
    session: SessionDep,
    user_id: UserIdDep,
    year: int = Path(ge=1970, le=2100),
    month: int = Path(ge=1, le=12),
) -> list[CalendarDay]:
    res = await session.execute(
        text(
            "SELECT day, total, done, ratio, color, is_holiday, holiday_name, has_diary "
            "FROM fn_get_calendar_stats(:uid, :y, :m)"
        ).bindparams(uid=user_id, y=year, m=month)
    )
    return [
        CalendarDay(
            day=r[0],
            total=r[1],
            done=r[2],
            ratio=float(r[3]),
            color=r[4],
            is_holiday=r[5],
            holiday_name=r[6],
            has_diary=r[7],
        )
        for r in res
    ]


@router.get(
    "/heatmap",
    response_model=list[HeatmapPoint],
    summary="Тепловая карта активности (v_year_heatmap)",
)
async def heatmap(
    session: SessionDep,
    user_id: UserIdDep,
    from_: date = Query(alias="from"),
    to: date = Query(),
) -> list[HeatmapPoint]:
    res = await session.execute(
        text(
            "SELECT day, activity FROM v_year_heatmap "
            "WHERE user_id = :uid AND day BETWEEN :f AND :t "
            "ORDER BY day"
        ).bindparams(uid=user_id, f=from_, t=to)
    )
    return [HeatmapPoint(day=r[0], activity=r[1]) for r in res]
