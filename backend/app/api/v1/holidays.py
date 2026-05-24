"""CRUD праздников (общий справочник)."""

from __future__ import annotations

from datetime import date

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.api.v1.deps import SessionDep, UserIdDep
from app.models import Holiday
from app.schemas.holiday import HolidayCreate, HolidayRead, HolidayUpdate

router = APIRouter(prefix="/holidays", tags=["holidays"])


@router.get("", response_model=list[HolidayRead], summary="Список праздников")
async def list_holidays(
    session: SessionDep,
    year: int | None = Query(default=None, ge=1900, le=2100),
) -> list[Holiday]:
    stmt = select(Holiday).order_by(Holiday.holiday_date)
    if year is not None:
        stmt = stmt.where(
            Holiday.holiday_date >= date(year, 1, 1),
            Holiday.holiday_date <= date(year, 12, 31),
        )
    res = await session.execute(stmt)
    return list(res.scalars())


@router.post(
    "",
    response_model=HolidayRead,
    status_code=status.HTTP_201_CREATED,
    summary="Добавить праздник",
)
async def create_holiday(
    payload: HolidayCreate, session: SessionDep, _user_id: UserIdDep
) -> Holiday:
    holiday = Holiday(**payload.model_dump())
    session.add(holiday)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Уже есть на эту дату") from exc
    await session.refresh(holiday)
    return holiday


@router.patch("/{holiday_id}", response_model=HolidayRead, summary="Обновить праздник")
async def update_holiday(
    holiday_id: int, payload: HolidayUpdate, session: SessionDep, _user_id: UserIdDep
) -> Holiday:
    holiday = await _get(session, holiday_id)
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(holiday, k, v)
    await session.commit()
    await session.refresh(holiday)
    return holiday


@router.delete(
    "/{holiday_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Удалить праздник",
)
async def delete_holiday(holiday_id: int, session: SessionDep, _user_id: UserIdDep) -> None:
    holiday = await _get(session, holiday_id)
    await session.delete(holiday)
    await session.commit()


async def _get(session: SessionDep, holiday_id: int) -> Holiday:
    res = await session.execute(select(Holiday).where(Holiday.id == holiday_id))
    holiday = res.scalar_one_or_none()
    if holiday is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Праздник не найден")
    return holiday
