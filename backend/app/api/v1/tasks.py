"""CRUD задач + complete/reopen + subtasks + журнал времени."""

from __future__ import annotations

from datetime import date
from typing import Literal

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import delete, func, or_, select, text
from sqlalchemy.exc import IntegrityError

from app.api.v1.deps import SessionDep, UserIdDep
from app.models import RecurringRule, Tag, Task, TaskTag, TaskTimeLog
from app.schemas.common import TaskPriority, TaskStatus
from app.schemas.recurring_rule import RecurringRuleCreate, RecurringRuleRead, RecurringRuleUpdate
from app.schemas.task import (
    TaskCreate,
    TaskRead,
    TaskUpdate,
    TaskView,
    TimeLogCreate,
    TimeLogRead,
)

router = APIRouter(prefix="/tasks", tags=["tasks"])

_ACTIVE = ("pending", "in_progress", "overdue")
_COMPLETED = ("done",)


def _ilike_pattern(q: str) -> str:
    escaped = q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


def _to_read(task: Task) -> TaskRead:
    return TaskRead(
        id=task.id,
        topic_id=task.topic_id,
        title=task.title,
        description=task.description,
        priority=task.priority,
        start_at=task.start_at,
        deadline=task.deadline,
        planned_minutes=task.planned_minutes,
        parent_task_id=task.parent_task_id,
        status=task.status,
        completed_at=task.completed_at,
        is_archived=task.is_archived,
        recurring_rule_id=task.recurring_rule_id,
        created_at=task.created_at,
        updated_at=task.updated_at,
        tag_ids=[link.tag_id for link in task.tag_links],
    )


@router.get("", response_model=list[TaskRead], summary="Список задач с фильтрами")
async def list_tasks(
    session: SessionDep,
    user_id: UserIdDep,
    view: TaskView = Query(default="all", description="active | completed | all"),
    status_: TaskStatus | None = Query(default=None, alias="status"),
    topic_id: int | None = None,
    priority: TaskPriority | None = None,
    archived: bool | None = None,
    q: str | None = Query(default=None, description="Полнотекстовый поиск (russian)"),
    parent_id: int | None = None,
    roots_only: bool = Query(default=True, description="Только корневые задачи (без подзадач)"),
    has_deadline: bool | None = None,
    deadline_on: date | None = Query(default=None, description="Задачи с дедлайном в этот день (YYYY-MM-DD)"),
    limit: int = Query(default=200, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
) -> list[TaskRead]:
    stmt = select(Task).where(Task.user_id == user_id)
    if view == "active":
        stmt = stmt.where(Task.status.in_(_ACTIVE))
    elif view == "completed":
        stmt = stmt.where(Task.status.in_(_COMPLETED))
    if status_ is not None:
        stmt = stmt.where(Task.status == status_)
    if topic_id is not None:
        stmt = stmt.where(Task.topic_id == topic_id)
    if priority is not None:
        stmt = stmt.where(Task.priority == priority)
    if archived is not None:
        stmt = stmt.where(Task.is_archived == archived)
    if parent_id is not None:
        stmt = stmt.where(Task.parent_task_id == parent_id)
    elif roots_only:
        stmt = stmt.where(Task.parent_task_id.is_(None))
    if has_deadline is True:
        stmt = stmt.where(Task.deadline.is_not(None))
    if has_deadline is False:
        stmt = stmt.where(Task.deadline.is_(None))
    if deadline_on is not None:
        stmt = stmt.where(func.date(Task.deadline) == deadline_on)
    if q:
        q = q.strip()
        if q:
            pattern = _ilike_pattern(q)
            stmt = stmt.where(
                or_(
                    text(
                        "to_tsvector('russian', coalesce(tasks.title,'') "
                        "|| ' ' || coalesce(tasks.description,'')) "
                        "@@ plainto_tsquery('russian', :q)"
                    ).bindparams(q=q),
                    Task.title.ilike(pattern, escape="\\"),
                    Task.description.ilike(pattern, escape="\\"),
                )
            )
    if view == "completed":
        stmt = stmt.order_by(
            Task.completed_at.desc().nullslast(),
            Task.updated_at.desc(),
        )
    else:
        stmt = stmt.order_by(
            Task.start_at.is_(None),
            Task.start_at.asc(),
            Task.deadline.is_(None),
            Task.deadline.asc(),
            Task.priority.desc(),
            Task.created_at.desc(),
        )
    stmt = stmt.limit(limit).offset(offset)

    res = await session.execute(stmt)
    return [_to_read(t) for t in res.scalars()]


@router.post(
    "", response_model=TaskRead, status_code=status.HTTP_201_CREATED, summary="Создать задачу"
)
async def create_task(payload: TaskCreate, session: SessionDep, user_id: UserIdDep) -> TaskRead:
    rule_id: int | None = None
    if payload.recurring is not None:
        rule = RecurringRule(
            frequency=payload.recurring.frequency,
            params=payload.recurring.params,
            is_active=payload.recurring.is_active,
        )
        session.add(rule)
        await session.flush()
        rule_id = rule.id

    task = Task(
        user_id=user_id,
        topic_id=payload.topic_id,
        parent_task_id=payload.parent_task_id,
        recurring_rule_id=rule_id,
        title=payload.title,
        description=payload.description,
        priority=payload.priority,
        start_at=payload.start_at,
        deadline=payload.deadline,
        planned_minutes=payload.planned_minutes,
    )
    session.add(task)
    try:
        await session.flush()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc.orig)) from exc

    if payload.tag_ids:
        await _replace_tags(session, task.id, user_id, payload.tag_ids)

    await session.commit()
    await session.refresh(task, attribute_names=["tag_links"])
    return _to_read(task)


@router.get("/{task_id}", response_model=TaskRead, summary="Получить задачу")
async def get_task(task_id: int, session: SessionDep, user_id: UserIdDep) -> TaskRead:
    return _to_read(await _get(session, task_id, user_id))


@router.patch("/{task_id}", response_model=TaskRead, summary="Обновить задачу")
async def update_task(
    task_id: int, payload: TaskUpdate, session: SessionDep, user_id: UserIdDep
) -> TaskRead:
    task = await _get(session, task_id, user_id)
    data = payload.model_dump(exclude_unset=True, exclude={"tag_ids"})
    if data.get("status") in ("done", "overdue"):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Используйте POST /complete для завершения задачи",
        )
    for k, v in data.items():
        setattr(task, k, v)

    if payload.tag_ids is not None:
        await _replace_tags(session, task.id, user_id, payload.tag_ids)

    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc.orig)) from exc

    await session.refresh(task, attribute_names=["tag_links"])
    return _to_read(task)


@router.delete(
    "/{task_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Удалить задачу",
)
async def delete_task(task_id: int, session: SessionDep, user_id: UserIdDep) -> None:
    task = await _get(session, task_id, user_id)
    await session.delete(task)
    await session.commit()


@router.post("/{task_id}/complete", response_model=TaskRead, summary="Отметить выполненной")
async def complete_task(task_id: int, session: SessionDep, user_id: UserIdDep) -> TaskRead:
    task = await _get(session, task_id, user_id)
    await session.execute(text("CALL sp_complete_task(:id)").bindparams(id=task.id))
    await session.commit()
    session.expire_all()
    refreshed = await _get(session, task_id, user_id)
    return _to_read(refreshed)


@router.post("/{task_id}/reopen", response_model=TaskRead, summary="Вернуть в работу")
async def reopen_task(task_id: int, session: SessionDep, user_id: UserIdDep) -> TaskRead:
    await _get(session, task_id, user_id)
    try:
        await session.execute(text("CALL sp_reopen_task(:id)").bindparams(id=task_id))
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc.orig)) from exc
    session.expire_all()
    refreshed = await _get(session, task_id, user_id)
    return _to_read(refreshed)


@router.post("/{task_id}/cancel", response_model=TaskRead, summary="Отменить задачу")
async def cancel_task(task_id: int, session: SessionDep, user_id: UserIdDep) -> TaskRead:
    task = await _get(session, task_id, user_id)
    if task.status == "done":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Выполненную задачу нельзя отменить")
    task.status = "cancelled"
    await session.commit()
    await session.refresh(task, attribute_names=["tag_links"])
    return _to_read(task)


@router.post("/{task_id}/start", response_model=TaskRead, summary="Взять в работу")
async def start_task(task_id: int, session: SessionDep, user_id: UserIdDep) -> TaskRead:
    task = await _get(session, task_id, user_id)
    if task.status not in ("pending", "overdue"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Задача не может быть начата")
    task.status = "in_progress"
    await session.commit()
    await session.refresh(task, attribute_names=["tag_links"])
    return _to_read(task)


@router.get(
    "/{task_id}/subtasks", response_model=list[TaskRead], summary="Подзадачи"
)
async def list_subtasks(
    task_id: int, session: SessionDep, user_id: UserIdDep
) -> list[TaskRead]:
    await _get(session, task_id, user_id)
    res = await session.execute(
        select(Task)
        .where(Task.parent_task_id == task_id, Task.user_id == user_id)
        .order_by(Task.created_at.asc())
    )
    return [_to_read(t) for t in res.scalars()]


async def _recalc_recurring_next_run(session: SessionDep, rule_id: int) -> None:
    await session.execute(
        text(
            """
            UPDATE recurring_rules
               SET next_run_at = fn_next_recurring_date(:rid, current_date)::timestamptz
             WHERE id = :rid AND is_active = TRUE
            """
        ).bindparams(rid=rule_id)
    )


@router.get(
    "/{task_id}/recurring",
    response_model=RecurringRuleRead,
    summary="Правило повторения задачи",
)
async def get_task_recurring(
    task_id: int, session: SessionDep, user_id: UserIdDep
) -> RecurringRule:
    task = await _get(session, task_id, user_id)
    if task.recurring_rule_id is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "У задачи нет повторения")
    res = await session.execute(
        select(RecurringRule).where(RecurringRule.id == task.recurring_rule_id)
    )
    rule = res.scalar_one_or_none()
    if rule is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Правило повторения не найдено")
    return rule


@router.post(
    "/{task_id}/recurring",
    response_model=RecurringRuleRead,
    status_code=status.HTTP_201_CREATED,
    summary="Привязать повторение к задаче",
)
async def attach_task_recurring(
    task_id: int,
    payload: RecurringRuleCreate,
    session: SessionDep,
    user_id: UserIdDep,
) -> RecurringRule:
    task = await _get(session, task_id, user_id)
    if task.parent_task_id is not None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Подзадача не может повторяться")
    if task.recurring_rule_id is not None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Повторение уже настроено")
    rule = RecurringRule(
        frequency=payload.frequency,
        params=payload.params,
        is_active=payload.is_active,
    )
    session.add(rule)
    await session.flush()
    task.recurring_rule_id = rule.id
    await _recalc_recurring_next_run(session, rule.id)
    await session.commit()
    await session.refresh(rule)
    return rule


@router.patch(
    "/{task_id}/recurring",
    response_model=RecurringRuleRead,
    summary="Обновить повторение задачи",
)
async def update_task_recurring(
    task_id: int,
    payload: RecurringRuleUpdate,
    session: SessionDep,
    user_id: UserIdDep,
) -> RecurringRule:
    task = await _get(session, task_id, user_id)
    if task.recurring_rule_id is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "У задачи нет повторения")
    res = await session.execute(
        select(RecurringRule).where(RecurringRule.id == task.recurring_rule_id)
    )
    rule = res.scalar_one()
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(rule, k, v)
    await session.flush()
    await _recalc_recurring_next_run(session, rule.id)
    await session.commit()
    await session.refresh(rule)
    return rule


@router.delete(
    "/{task_id}/recurring",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Отключить повторение задачи",
)
async def detach_task_recurring(
    task_id: int, session: SessionDep, user_id: UserIdDep
) -> None:
    task = await _get(session, task_id, user_id)
    if task.recurring_rule_id is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "У задачи нет повторения")
    res = await session.execute(
        select(RecurringRule).where(RecurringRule.id == task.recurring_rule_id)
    )
    rule = res.scalar_one()
    rule.is_active = False
    rule.next_run_at = None
    await session.commit()


# ---------- журнал времени ------------------------------------------------


@router.get(
    "/{task_id}/time-logs",
    response_model=list[TimeLogRead],
    summary="Журнал времени по задаче",
)
async def list_time_logs(
    task_id: int, session: SessionDep, user_id: UserIdDep
) -> list[TaskTimeLog]:
    await _get(session, task_id, user_id)
    res = await session.execute(
        select(TaskTimeLog)
        .where(TaskTimeLog.task_id == task_id)
        .order_by(TaskTimeLog.started_at.desc())
    )
    return list(res.scalars())


@router.post(
    "/{task_id}/time-logs",
    response_model=TimeLogRead,
    status_code=status.HTTP_201_CREATED,
    summary="Добавить запись времени",
)
async def add_time_log(
    task_id: int, payload: TimeLogCreate, session: SessionDep, user_id: UserIdDep
) -> TaskTimeLog:
    await _get(session, task_id, user_id)
    log = TaskTimeLog(
        task_id=task_id,
        user_id=user_id,
        started_at=payload.started_at,
        ended_at=payload.ended_at,
        is_pomodoro=payload.is_pomodoro,
        note=payload.note,
    )
    session.add(log)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Интервал пересекается с существующей записью времени",
        ) from exc
    await session.refresh(log)
    return log


@router.delete(
    "/{task_id}/time-logs/{log_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Удалить запись времени",
)
async def delete_time_log(
    task_id: int, log_id: int, session: SessionDep, user_id: UserIdDep
) -> None:
    await _get(session, task_id, user_id)
    res = await session.execute(
        select(TaskTimeLog).where(
            TaskTimeLog.id == log_id, TaskTimeLog.task_id == task_id
        )
    )
    log = res.scalar_one_or_none()
    if log is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Запись не найдена")
    await session.delete(log)
    await session.commit()


async def _get(session: SessionDep, task_id: int, user_id: int) -> Task:
    res = await session.execute(
        select(Task).where(Task.id == task_id, Task.user_id == user_id)
    )
    task = res.scalar_one_or_none()
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Задача не найдена")
    return task


async def _replace_tags(
    session: SessionDep, task_id: int, user_id: int, tag_ids: list[int]
) -> None:
    if tag_ids:
        ok = await session.execute(
            select(Tag.id).where(Tag.id.in_(tag_ids), Tag.user_id == user_id)
        )
        valid_ids = {row[0] for row in ok.all()}
        if valid_ids != set(tag_ids):
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST, "Один или несколько тегов не найдены"
            )

    await session.execute(delete(TaskTag).where(TaskTag.task_id == task_id))
    for tid in tag_ids:
        session.add(TaskTag(task_id=task_id, tag_id=tid))
