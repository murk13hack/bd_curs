"""CRUD целей + связи + прогресс."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select, text
from sqlalchemy.orm import selectinload

from app.api.v1.deps import SessionDep, UserIdDep
from app.models import Goal, GoalLink
from app.schemas.goal import (
    GoalCreate,
    GoalLinkBase,
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
    link = GoalLink(
        goal_id=goal_id, target_type=payload.target_type, target_id=payload.target_id
    )
    session.add(link)
    await session.commit()
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
    summary="% выполнения цели (fn_goal_progress)",
)
async def progress(
    goal_id: int, session: SessionDep, user_id: UserIdDep
) -> GoalProgress:
    await _get(session, goal_id, user_id)
    res = await session.execute(
        text("SELECT fn_goal_progress(:gid)").bindparams(gid=goal_id)
    )
    return GoalProgress(goal_id=goal_id, progress=float(res.scalar_one() or 0))


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
