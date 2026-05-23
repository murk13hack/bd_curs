"""CRUD паттернов поведения + журнал откликов + серии."""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select, text

from app.api.v1.deps import SessionDep, UserIdDep
from app.models import (
    BehaviorPattern,
    PatternLog,
    PatternResponseOption,
    PatternSchedule,
)
from app.schemas.pattern import (
    PatternCreate,
    PatternLogRead,
    PatternLogResponse,
    PatternRead,
    PatternResponseOptionCreate,
    PatternResponseOptionRead,
    PatternScheduleCreate,
    PatternScheduleRead,
    PatternStreakRead,
    PatternUpdate,
)

router = APIRouter(prefix="/patterns", tags=["patterns"])


def _to_read(p: BehaviorPattern) -> PatternRead:
    return PatternRead(
        id=p.id,
        title=p.title,
        description=p.description,
        pattern_type=p.pattern_type,
        is_boolean=p.is_boolean,
        auto_create_task=p.auto_create_task,
        topic_id=p.topic_id,
        created_at=p.created_at,
        updated_at=p.updated_at,
        options=[PatternResponseOptionRead.model_validate(o) for o in p.options],
        schedules=[PatternScheduleRead.model_validate(s) for s in p.schedules],
    )


@router.get("", response_model=list[PatternRead], summary="Список паттернов")
async def list_patterns(session: SessionDep, user_id: UserIdDep) -> list[PatternRead]:
    res = await session.execute(
        select(BehaviorPattern)
        .where(BehaviorPattern.user_id == user_id)
        .order_by(BehaviorPattern.created_at.desc())
    )
    return [_to_read(p) for p in res.scalars()]


@router.post(
    "",
    response_model=PatternRead,
    status_code=status.HTTP_201_CREATED,
    summary="Создать паттерн",
)
async def create_pattern(
    payload: PatternCreate, session: SessionDep, user_id: UserIdDep
) -> PatternRead:
    pattern = BehaviorPattern(
        user_id=user_id,
        topic_id=payload.topic_id,
        title=payload.title,
        description=payload.description,
        pattern_type=payload.pattern_type,
        is_boolean=payload.is_boolean,
        auto_create_task=payload.auto_create_task,
    )
    session.add(pattern)
    await session.flush()

    options = payload.options
    if not options and payload.is_boolean:
        options = [
            PatternResponseOptionCreate(label="Сделал", is_success=True, sort_order=0),
            PatternResponseOptionCreate(
                label="Не сделал", is_success=False, sort_order=1
            ),
        ]
    for opt in options:
        session.add(PatternResponseOption(pattern_id=pattern.id, **opt.model_dump()))
    for sch in payload.schedules:
        session.add(PatternSchedule(pattern_id=pattern.id, **sch.model_dump()))

    await session.commit()
    await session.refresh(pattern, attribute_names=["options", "schedules"])
    return _to_read(pattern)


@router.get("/{pattern_id}", response_model=PatternRead, summary="Получить паттерн")
async def get_pattern(
    pattern_id: int, session: SessionDep, user_id: UserIdDep
) -> PatternRead:
    return _to_read(await _get(session, pattern_id, user_id))


@router.patch("/{pattern_id}", response_model=PatternRead, summary="Обновить паттерн")
async def update_pattern(
    pattern_id: int,
    payload: PatternUpdate,
    session: SessionDep,
    user_id: UserIdDep,
) -> PatternRead:
    pattern = await _get(session, pattern_id, user_id)
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(pattern, k, v)
    await session.commit()
    await session.refresh(pattern, attribute_names=["options", "schedules"])
    return _to_read(pattern)


@router.delete(
    "/{pattern_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Удалить паттерн",
)
async def delete_pattern(
    pattern_id: int, session: SessionDep, user_id: UserIdDep
) -> None:
    pattern = await _get(session, pattern_id, user_id)
    await session.delete(pattern)
    await session.commit()


# ---------- options & schedules -------------------------------------------


@router.post(
    "/{pattern_id}/options",
    response_model=PatternResponseOptionRead,
    status_code=status.HTTP_201_CREATED,
    summary="Добавить вариант ответа",
)
async def add_option(
    pattern_id: int,
    payload: PatternResponseOptionCreate,
    session: SessionDep,
    user_id: UserIdDep,
) -> PatternResponseOption:
    await _get(session, pattern_id, user_id)
    opt = PatternResponseOption(pattern_id=pattern_id, **payload.model_dump())
    session.add(opt)
    await session.commit()
    await session.refresh(opt)
    return opt


@router.post(
    "/{pattern_id}/schedules",
    response_model=PatternScheduleRead,
    status_code=status.HTTP_201_CREATED,
    summary="Добавить расписание",
)
async def add_schedule(
    pattern_id: int,
    payload: PatternScheduleCreate,
    session: SessionDep,
    user_id: UserIdDep,
) -> PatternSchedule:
    await _get(session, pattern_id, user_id)
    sch = PatternSchedule(pattern_id=pattern_id, **payload.model_dump())
    session.add(sch)
    await session.commit()
    await session.refresh(sch)
    return sch


# ---------- responses (sp_log_pattern_response) ---------------------------


@router.post(
    "/{pattern_id}/responses",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Зафиксировать ответ пользователя (sp_log_pattern_response)",
)
async def log_response(
    pattern_id: int,
    payload: PatternLogResponse,
    session: SessionDep,
    user_id: UserIdDep,
) -> None:
    await _get(session, pattern_id, user_id)
    await session.execute(
        text(
            "CALL sp_log_pattern_response(:pid, :oid, :ts)"
        ).bindparams(
            pid=pattern_id,
            oid=payload.response_option_id,
            ts=payload.scheduled_at or datetime.now(tz=timezone.utc),
        )
    )
    await session.commit()


@router.get(
    "/{pattern_id}/logs",
    response_model=list[PatternLogRead],
    summary="История откликов",
)
async def list_logs(
    pattern_id: int,
    session: SessionDep,
    user_id: UserIdDep,
    limit: int = Query(default=100, ge=1, le=500),
) -> list[PatternLog]:
    await _get(session, pattern_id, user_id)
    res = await session.execute(
        select(PatternLog)
        .where(PatternLog.pattern_id == pattern_id)
        .order_by(PatternLog.scheduled_at.desc())
        .limit(limit)
    )
    return list(res.scalars())


# ---------- streaks (v_pattern_streaks) -----------------------------------


@router.get(
    "/streaks/all",
    response_model=list[PatternStreakRead],
    summary="Серии по всем паттернам (v_pattern_streaks)",
)
async def streaks_all(session: SessionDep, user_id: UserIdDep) -> list[PatternStreakRead]:
    res = await session.execute(
        text(
            "SELECT pattern_id, title, pattern_type, current_streak, max_streak,"
            " anti_streak, logs_30d, COALESCE(success_rate_30d, 0) "
            "FROM v_pattern_streaks WHERE user_id = :uid"
        ).bindparams(uid=user_id)
    )
    return [
        PatternStreakRead(
            pattern_id=r[0],
            title=r[1],
            pattern_type=r[2],
            current_streak=r[3],
            max_streak=r[4],
            anti_streak=r[5],
            logs_30d=r[6],
            success_rate_30d=float(r[7]),
        )
        for r in res
    ]


@router.get(
    "/{pattern_id}/streak",
    summary="Текущая серия (fn_calculate_streak)",
)
async def get_streak(
    pattern_id: int, session: SessionDep, user_id: UserIdDep
) -> dict:
    await _get(session, pattern_id, user_id)
    res = await session.execute(
        text(
            "SELECT fn_calculate_streak(:p) AS current,"
            " fn_calculate_max_streak(:p) AS max,"
            " fn_calculate_anti_streak(:p) AS anti"
        ).bindparams(p=pattern_id)
    )
    row = res.one()
    return {"current_streak": row[0], "max_streak": row[1], "anti_streak": row[2]}


# ---------- helpers -------------------------------------------------------


async def _get(
    session: SessionDep, pattern_id: int, user_id: int
) -> BehaviorPattern:
    res = await session.execute(
        select(BehaviorPattern).where(
            BehaviorPattern.id == pattern_id, BehaviorPattern.user_id == user_id
        )
    )
    pattern = res.scalar_one_or_none()
    if pattern is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Паттерн не найден")
    return pattern
