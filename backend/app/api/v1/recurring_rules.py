"""CRUD правил повторения задач."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError

from app.api.v1.deps import SessionDep, UserIdDep
from app.models import RecurringRule, Task
from app.schemas.recurring_rule import RecurringRuleCreate, RecurringRuleRead, RecurringRuleUpdate

router = APIRouter(prefix="/recurring-rules", tags=["recurring-rules"])


class RecurringRuleSummary(RecurringRuleRead):
    task_count: int


async def _get_user_rule(session: SessionDep, user_id: int, rule_id: int) -> RecurringRule:
    res = await session.execute(
        select(RecurringRule)
        .join(Task, Task.recurring_rule_id == RecurringRule.id)
        .where(RecurringRule.id == rule_id, Task.user_id == user_id)
        .limit(1)
    )
    rule = res.scalar_one_or_none()
    if rule is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Правило повторения не найдено")
    return rule


async def _recalc_next_run(session: SessionDep, rule_id: int) -> None:
    await session.execute(
        text(
            """
            UPDATE recurring_rules
               SET next_run_at = fn_next_recurring_date(:rid, current_date)::timestamptz
             WHERE id = :rid AND is_active = TRUE
            """
        ).bindparams(rid=rule_id)
    )


@router.get("", response_model=list[RecurringRuleSummary], summary="Правила повторения пользователя")
async def list_recurring_rules(session: SessionDep, user_id: UserIdDep) -> list[RecurringRuleSummary]:
    res = await session.execute(
        select(
            RecurringRule,
            func.count(Task.id.distinct()).label("task_count"),
        )
        .join(Task, Task.recurring_rule_id == RecurringRule.id)
        .where(Task.user_id == user_id)
        .group_by(RecurringRule.id)
        .order_by(RecurringRule.id.desc())
    )
    out: list[RecurringRuleSummary] = []
    for rule, task_count in res.all():
        data = RecurringRuleRead.model_validate(rule).model_dump()
        out.append(RecurringRuleSummary(**data, task_count=int(task_count)))
    return out


@router.get("/{rule_id}", response_model=RecurringRuleRead, summary="Получить правило")
async def get_recurring_rule(
    rule_id: int, session: SessionDep, user_id: UserIdDep
) -> RecurringRule:
    return await _get_user_rule(session, user_id, rule_id)


@router.patch("/{rule_id}", response_model=RecurringRuleRead, summary="Обновить правило")
async def update_recurring_rule(
    rule_id: int,
    payload: RecurringRuleUpdate,
    session: SessionDep,
    user_id: UserIdDep,
) -> RecurringRule:
    rule = await _get_user_rule(session, user_id, rule_id)
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(rule, k, v)
    try:
        await session.flush()
        await _recalc_next_run(session, rule.id)
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc.orig)) from exc
    await session.refresh(rule)
    return rule


@router.delete(
    "/{rule_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Отключить правило",
)
async def deactivate_recurring_rule(
    rule_id: int, session: SessionDep, user_id: UserIdDep
) -> None:
    rule = await _get_user_rule(session, user_id, rule_id)
    rule.is_active = False
    rule.next_run_at = None
    await session.commit()
