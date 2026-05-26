"""CRUD целей + связи + прогресс."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload

from app.api.v1.deps import SessionDep, UserIdDep
from app.models import Goal, GoalLink, Task
from app.models.pattern import BehaviorPattern
from app.schemas.goal import (
    GoalCreate,
    GoalLinkBase,
    GoalLinkDetail,
    GoalLinkRead,
    GoalProgress,
    GoalRead,
    GoalUpdate,
)

router = APIRouter(prefix="/goals", tags=["goals"])


def _to_read(goal: Goal) -> GoalRead:
    return GoalRead(
        id=goal.id,
        title=goal.title,
        description=goal.description,
        deadline=goal.deadline,
        target_value=goal.target_value,
        is_completed=goal.is_completed,
        completed_at=goal.completed_at,
        created_at=goal.created_at,
        updated_at=goal.updated_at,
        links=[GoalLinkRead(target_type=link.target_type, target_id=link.target_id) for link in goal.links],
    )


@router.get("", response_model=list[GoalRead], summary="Список целей")
async def list_goals(session: SessionDep, user_id: UserIdDep) -> list[GoalRead]:
    res = await session.execute(
        select(Goal).where(Goal.user_id == user_id).order_by(Goal.created_at.desc())
    )
    return [_to_read(g) for g in res.scalars()]


@router.post(
    "",
    response_model=GoalRead,
    status_code=status.HTTP_201_CREATED,
    summary="Создать цель",
)
async def create_goal(
    payload: GoalCreate, session: SessionDep, user_id: UserIdDep
) -> GoalRead:
    goal = Goal(
        user_id=user_id,
        title=payload.title,
        description=payload.description,
        deadline=payload.deadline,
        target_value=payload.target_value,
    )
    session.add(goal)
    await session.flush()
    for link in payload.links:
        await _validate_link_target(session, user_id, link.target_type, link.target_id)
    for link in payload.links:
        session.add(
            GoalLink(
                goal_id=goal.id,
                target_type=link.target_type,
                target_id=link.target_id,
            )
        )
    await session.commit()
    return _to_read(await _reload(session, goal.id))


@router.get("/{goal_id}", response_model=GoalRead, summary="Получить цель")
async def get_goal(
    goal_id: int, session: SessionDep, user_id: UserIdDep
) -> GoalRead:
    return _to_read(await _get(session, goal_id, user_id))


@router.patch("/{goal_id}", response_model=GoalRead, summary="Обновить цель")
async def update_goal(
    goal_id: int,
    payload: GoalUpdate,
    session: SessionDep,
    user_id: UserIdDep,
) -> GoalRead:
    goal = await _get(session, goal_id, user_id)
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(goal, k, v)
    await session.commit()
    return _to_read(await _reload(session, goal_id))


@router.delete(
    "/{goal_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Удалить цель",
)
async def delete_goal(goal_id: int, session: SessionDep, user_id: UserIdDep) -> None:
    goal = await _get(session, goal_id, user_id)
    await session.delete(goal)
    await session.commit()


@router.post(
    "/{goal_id}/links",
    response_model=GoalLinkRead,
    status_code=status.HTTP_201_CREATED,
    summary="Привязать цель к задаче/паттерну",
)
async def add_link(
    goal_id: int,
    payload: GoalLinkBase,
    session: SessionDep,
    user_id: UserIdDep,
) -> GoalLinkRead:
    await _get(session, goal_id, user_id)
    await _validate_link_target(session, user_id, payload.target_type, payload.target_id)
    link = GoalLink(
        goal_id=goal_id, target_type=payload.target_type, target_id=payload.target_id
    )
    session.add(link)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Связь уже существует") from exc
    return GoalLinkRead(target_type=link.target_type, target_id=link.target_id)


@router.delete(
    "/{goal_id}/links",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Удалить привязку",
)
async def remove_link(
    goal_id: int,
    target_type: str,
    target_id: int,
    session: SessionDep,
    user_id: UserIdDep,
) -> None:
    await _get(session, goal_id, user_id)
    res = await session.execute(
        select(GoalLink).where(
            GoalLink.goal_id == goal_id,
            GoalLink.target_type == target_type,
            GoalLink.target_id == target_id,
        )
    )
    link = res.scalar_one_or_none()
    if link is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Привязка не найдена")
    await session.delete(link)
    await session.commit()


@router.get(
    "/{goal_id}/progress",
    response_model=GoalProgress,
    summary="% выполнения цели (fn_goal_progress) + детализация связей",
)
async def progress(
    goal_id: int, session: SessionDep, user_id: UserIdDep
) -> GoalProgress:
    goal = await _get(session, goal_id, user_id)
    res = await session.execute(
        text("SELECT fn_goal_progress(:gid)").bindparams(gid=goal_id)
    )
    progress_pct = float(res.scalar_one() or 0)
    done_units = int(round(progress_pct * goal.target_value / 100)) if goal.target_value else 0

    link_details: list[GoalLinkDetail] = []
    for link in goal.links:
        if link.target_type == "task":
            t_res = await session.execute(
                text(
                    "SELECT title, status FROM tasks WHERE id = :id AND user_id = :uid"
                ).bindparams(id=link.target_id, uid=user_id)
            )
            row = t_res.first()
            if row is None:
                continue
            contributed = row[1] == "done"
            link_details.append(
                GoalLinkDetail(
                    target_type="task",
                    target_id=link.target_id,
                    title=row[0],
                    contributed=contributed,
                    detail="Выполнена" if contributed else "Не выполнена",
                )
            )
        else:
            p_res = await session.execute(
                text(
                    "SELECT title, pattern_mode FROM behavior_patterns "
                    "WHERE id = :id AND user_id = :uid"
                ).bindparams(id=link.target_id, uid=user_id)
            )
            prow = p_res.first()
            if prow is None:
                continue
            cnt_res = await session.execute(
                text(
                    "SELECT COUNT(DISTINCT day)::INT FROM ("
                    "  SELECT date_trunc('day', pl.scheduled_at)::date AS day "
                    "    FROM pattern_logs pl "
                    "    JOIN pattern_response_options ro ON ro.id = pl.response_option_id "
                    "   WHERE pl.pattern_id = :pid AND pl.status = 'answered' AND ro.is_success = TRUE "
                    "  UNION "
                    "  SELECT d.day::date AS day "
                    "    FROM generate_series(current_date - 3650, current_date, '1 day') AS d(day) "
                    "   WHERE fn_pattern_is_scheduled(:pid, d.day::date) "
                    "     AND fn_pattern_day_success(:pid, d.day::date) "
                    "     AND EXISTS (SELECT 1 FROM behavior_patterns bp WHERE bp.id = :pid AND bp.pattern_mode = 'markers') "
                    "  UNION "
                    "  SELECT s.session_date AS day "
                    "    FROM pattern_day_sessions s "
                    "   WHERE s.pattern_id = :pid AND s.status = 'completed' AND s.outcome_success = TRUE "
                    ") x"
                ).bindparams(pid=link.target_id)
            )
            days = int(cnt_res.scalar_one() or 0)
            mode_label = {"habit": "привычка", "markers": "точки", "scenario": "сценарий"}.get(
                prow[1], "паттерн"
            )
            link_details.append(
                GoalLinkDetail(
                    target_type="pattern",
                    target_id=link.target_id,
                    title=prow[0],
                    contributed=days > 0,
                    detail=f"{days} успешных дней ({mode_label})",
                )
            )

    return GoalProgress(
        goal_id=goal_id,
        progress=progress_pct,
        done_units=done_units,
        target_value=goal.target_value,
        remaining_units=max(0, goal.target_value - done_units),
        links=link_details,
    )


async def _validate_link_target(
    session: SessionDep, user_id: int, target_type: str, target_id: int
) -> None:
    if target_type == "task":
        res = await session.execute(
            select(Task.id).where(Task.id == target_id, Task.user_id == user_id)
        )
        if res.scalar_one_or_none() is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Задача не найдена")
    elif target_type == "pattern":
        res = await session.execute(
            select(BehaviorPattern.id).where(
                BehaviorPattern.id == target_id, BehaviorPattern.user_id == user_id
            )
        )
        if res.scalar_one_or_none() is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Паттерн не найден")
    else:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Неверный тип связи")


async def _get(session: SessionDep, goal_id: int, user_id: int) -> Goal:
    res = await session.execute(
        select(Goal).where(Goal.id == goal_id, Goal.user_id == user_id)
    )
    goal = res.scalar_one_or_none()
    if goal is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Цель не найдена")
    return goal


async def _reload(session: SessionDep, goal_id: int) -> Goal:
    """Перечитать цель целиком вместе со связями после COMMIT.

    После коммита триггеры могут поменять completed_at/updated_at, поэтому
    перезагружаем объект полностью, чтобы вернуть свежие данные.
    """
    session.expire_all()
    res = await session.execute(
        select(Goal).options(selectinload(Goal.links)).where(Goal.id == goal_id)
    )
    return res.scalar_one()
