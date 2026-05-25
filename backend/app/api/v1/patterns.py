"""CRUD паттернов поведения + habit/scenario + серии."""

from __future__ import annotations

from datetime import date, datetime, timezone

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import delete, select, text
from sqlalchemy.orm import selectinload

from app.api.v1.deps import SessionDep, UserIdDep
from app.models import (
    BehaviorPattern,
    PatternDaySession,
    PatternLog,
    PatternMarker,
    PatternMarkerDayClosure,
    PatternResponseOption,
    PatternSchedule,
    PatternStep,
    PatternStepAnswer,
)
from app.schemas.pattern import (
    PatternCreate,
    PatternInsightsRead,
    PatternLogRead,
    PatternLogResponse,
    PatternMarkerRead,
    PatternMarkerWrite,
    PatternRead,
    PatternResponseOptionCreate,
    PatternResponseOptionRead,
    PatternScheduleCreate,
    PatternScheduleRead,
    PatternScheduleUpdate,
    PatternSessionRead,
    PatternStepAnswerRead,
    PatternStepAnswerWrite,
    PatternStepCreate,
    PatternStepRead,
    PatternStepsReplace,
    PatternStreakRead,
    PatternTodayRead,
    PatternUpdate,
)

from app.services.pattern_insights import build_pattern_insights

router = APIRouter(prefix="/patterns", tags=["patterns"])

DEFAULT_MARKER_OPTIONS_NEGATIVE = [
    ("Тяга", False, 0),
    ("Срыв", False, 1),
    ("Справился", True, 2),
    ("Стресс", False, 3),
]
DEFAULT_MARKER_OPTIONS_POSITIVE = [
    ("Сделал", True, 0),
    ("Пропустил", False, 1),
]


def _to_read(p: BehaviorPattern) -> PatternRead:
    return PatternRead(
        id=p.id,
        title=p.title,
        description=p.description,
        pattern_type=p.pattern_type,
        pattern_mode=p.pattern_mode,
        guide_intro=p.guide_intro,
        is_boolean=p.is_boolean,
        auto_create_task=p.auto_create_task,
        topic_id=p.topic_id,
        created_at=p.created_at,
        updated_at=p.updated_at,
        options=[PatternResponseOptionRead.model_validate(o) for o in p.options],
        schedules=[PatternScheduleRead.model_validate(s) for s in p.schedules],
        steps=[PatternStepRead.model_validate(s) for s in p.steps],
    )


def _session_read(
    sess: PatternDaySession, required_count: int
) -> PatternSessionRead:
    return PatternSessionRead(
        id=sess.id,
        pattern_id=sess.pattern_id,
        session_date=sess.session_date.isoformat(),
        status=sess.status,
        outcome_success=sess.outcome_success,
        started_at=sess.started_at,
        completed_at=sess.completed_at,
        answers=[
            PatternStepAnswerRead(
                step_id=a.step_id,
                choice_id=a.choice_id,
                checked=a.checked,
                note_text=a.note_text,
                answered_at=a.answered_at,
            )
            for a in sess.answers
        ],
        answered_count=len(sess.answers),
        required_count=required_count,
    )


def _compute_outcome(
    steps: list[PatternStep], answers: dict[int, PatternStepAnswer]
) -> bool | None:
    outcome = next(
        (s for s in steps if s.marks_success or s.step_role == "outcome"),
        None,
    )
    if outcome is None:
        return None
    ans = answers.get(outcome.id)
    if ans is None:
        return None
    if outcome.step_kind == "note":
        return False
    if outcome.step_kind == "check":
        return bool(ans.checked)
    if outcome.step_kind == "single_choice" and ans.choice_id:
        for raw in outcome.choices or []:
            cid = raw.get("id") if isinstance(raw, dict) else None
            if cid == ans.choice_id:
                return bool(raw.get("is_success", False))
    return None


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
        pattern_mode=payload.pattern_mode,
        guide_intro=payload.guide_intro,
        is_boolean=payload.is_boolean,
        auto_create_task=payload.auto_create_task,
    )
    session.add(pattern)
    await session.flush()

    if payload.pattern_mode == "habit":
        options = payload.options
        if not options and payload.is_boolean:
            if payload.pattern_type == "negative":
                options = [
                    PatternResponseOptionCreate(label="0 раз", is_success=True, sort_order=0),
                    PatternResponseOptionCreate(label="1 раз", is_success=False, sort_order=1),
                    PatternResponseOptionCreate(label="2+ раз", is_success=False, sort_order=2),
                ]
            else:
                options = [
                    PatternResponseOptionCreate(label="Сделал", is_success=True, sort_order=0),
                    PatternResponseOptionCreate(label="Не сделал", is_success=False, sort_order=1),
                ]
        for opt in options:
            session.add(PatternResponseOption(pattern_id=pattern.id, **opt.model_dump()))

    if payload.pattern_mode == "markers":
        options = payload.options
        if not options:
            preset = (
                DEFAULT_MARKER_OPTIONS_NEGATIVE
                if payload.pattern_type == "negative"
                else DEFAULT_MARKER_OPTIONS_POSITIVE
            )
            options = [
                PatternResponseOptionCreate(label=l, is_success=s, sort_order=o)
                for l, s, o in preset
            ]
        for opt in options:
            session.add(PatternResponseOption(pattern_id=pattern.id, **opt.model_dump()))

    if payload.pattern_mode == "scenario":
        if not payload.steps:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Сценарий должен содержать шаги")
        for i, step in enumerate(payload.steps):
            data = step.model_dump()
            data["sort_order"] = step.sort_order if step.sort_order else i
            data["choices"] = [c.model_dump() for c in step.choices]
            session.add(PatternStep(pattern_id=pattern.id, **data))

    for sch in payload.schedules:
        session.add(PatternSchedule(pattern_id=pattern.id, **sch.model_dump()))

    await session.commit()
    return _to_read(await _reload(session, pattern.id))


@router.get("/streaks/all", response_model=list[PatternStreakRead], summary="Серии")
async def streaks_all(session: SessionDep, user_id: UserIdDep) -> list[PatternStreakRead]:
    res = await session.execute(
        text(
            "SELECT pattern_id, title, pattern_type, pattern_mode::text,"
            " current_streak, max_streak, anti_streak,"
            " scheduled_days_30d, success_days_30d, COALESCE(clean_rate_30d, 0),"
            " COALESCE(success_rate_30d, 0) "
            "FROM v_pattern_streaks WHERE user_id = :uid"
        ).bindparams(uid=user_id)
    )
    return [
        PatternStreakRead(
            pattern_id=r[0],
            title=r[1],
            pattern_type=r[2],
            pattern_mode=r[3],
            current_streak=r[4],
            max_streak=r[5],
            anti_streak=r[6],
            scheduled_days_30d=r[7],
            success_days_30d=r[8],
            clean_rate_30d=float(r[9]),
            success_rate_30d=float(r[10]),
        )
        for r in res
    ]


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
    return _to_read(await _reload(session, pattern_id))


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


# ---------- habit options (legacy) ----------------------------------------


@router.post(
    "/{pattern_id}/options",
    response_model=PatternResponseOptionRead,
    status_code=status.HTTP_201_CREATED,
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


# ---------- schedules -----------------------------------------------------


@router.post(
    "/{pattern_id}/schedules",
    response_model=PatternScheduleRead,
    status_code=status.HTTP_201_CREATED,
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


@router.patch("/{pattern_id}/schedules/{schedule_id}", response_model=PatternScheduleRead)
async def update_schedule(
    pattern_id: int,
    schedule_id: int,
    payload: PatternScheduleUpdate,
    session: SessionDep,
    user_id: UserIdDep,
) -> PatternSchedule:
    await _get(session, pattern_id, user_id)
    res = await session.execute(
        select(PatternSchedule).where(
            PatternSchedule.id == schedule_id,
            PatternSchedule.pattern_id == pattern_id,
        )
    )
    sch = res.scalar_one_or_none()
    if sch is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Расписание не найдено")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(sch, k, v)
    await session.commit()
    await session.refresh(sch)
    return sch


@router.delete(
    "/{pattern_id}/schedules/{schedule_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
async def delete_schedule(
    pattern_id: int,
    schedule_id: int,
    session: SessionDep,
    user_id: UserIdDep,
) -> None:
    await _get(session, pattern_id, user_id)
    res = await session.execute(
        select(PatternSchedule).where(
            PatternSchedule.id == schedule_id,
            PatternSchedule.pattern_id == pattern_id,
        )
    )
    sch = res.scalar_one_or_none()
    if sch is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Расписание не найдено")
    await session.delete(sch)
    await session.commit()


# ---------- habit responses -----------------------------------------------


@router.post("/{pattern_id}/responses", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def log_response(
    pattern_id: int,
    payload: PatternLogResponse,
    session: SessionDep,
    user_id: UserIdDep,
) -> None:
    pattern = await _get(session, pattern_id, user_id)
    if pattern.pattern_mode != "habit":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Ответ habit только для режима habit")
    ts = payload.scheduled_at or datetime.now(tz=timezone.utc)
    await session.execute(
        text("CALL sp_log_pattern_response(:pid, :oid, :ts)").bindparams(
            pid=pattern_id, oid=payload.response_option_id, ts=ts
        )
    )
    await session.commit()


@router.get("/{pattern_id}/today", response_model=PatternTodayRead)
async def pattern_today(
    pattern_id: int, session: SessionDep, user_id: UserIdDep
) -> PatternTodayRead:
    pattern = await _get(session, pattern_id, user_id)
    today = date.today()
    weekday_bit = 1 << today.weekday()
    is_scheduled = (
        any(
            (sch.dow_mask & weekday_bit)
            and (sch.day_of_month is None or sch.day_of_month == today.day)
            for sch in pattern.schedules
        )
        if pattern.schedules
        else True
    )

    if pattern.pattern_mode == "scenario":
        res = await session.execute(
            select(PatternDaySession).where(
                PatternDaySession.pattern_id == pattern_id,
                PatternDaySession.session_date == today,
            )
        )
        sess = res.scalar_one_or_none()
        if not is_scheduled:
            st = "not_scheduled"
            can = False
        elif sess is None:
            st = "pending"
            can = True
        elif sess.status == "completed":
            st = "completed"
            can = False
        else:
            st = "in_progress"
            can = True
        return PatternTodayRead(
            pattern_id=pattern_id,
            day=today.isoformat(),
            is_scheduled_today=is_scheduled,
            status=st,
            can_respond=can,
            is_success_today=sess.outcome_success if sess and sess.status == "completed" else None,
        )

    if pattern.pattern_mode == "markers":
        start_dt = datetime.combine(today, datetime.min.time()).replace(tzinfo=timezone.utc)
        res = await session.execute(
            select(PatternMarker, PatternResponseOption)
            .join(
                PatternResponseOption,
                PatternResponseOption.id == PatternMarker.marker_option_id,
            )
            .where(
                PatternMarker.pattern_id == pattern_id,
                PatternMarker.occurred_at >= start_dt,
            )
            .order_by(PatternMarker.occurred_at.desc())
        )
        rows = res.all()
        closure_res = await session.execute(
            select(PatternMarkerDayClosure).where(
                PatternMarkerDayClosure.pattern_id == pattern_id,
                PatternMarkerDayClosure.closure_date == today,
            )
        )
        declared_clean = closure_res.scalar_one_or_none() is not None
        has_bad = any(not opt.is_success for _, opt in rows)
        if not is_scheduled:
            st, can = "not_scheduled", False
        elif declared_clean and not rows:
            st, can = "answered", False
        elif not rows:
            st, can = "pending", True
        else:
            st, can = "answered", True
        last = rows[0] if rows else None
        if not is_scheduled:
            success_today = None
        elif has_bad:
            success_today = False
        elif rows or declared_clean:
            success_today = True
        else:
            success_today = None
        return PatternTodayRead(
            pattern_id=pattern_id,
            day=today.isoformat(),
            is_scheduled_today=is_scheduled,
            status=st,
            can_respond=can,
            is_success_today=success_today,
            markers_today_count=len(rows),
            last_marker_label=last[1].label if last else None,
            last_marker_at=last[0].occurred_at if last else None,
            day_declared_clean=declared_clean,
        )

    if pattern.pattern_mode == "habit" and is_scheduled:
        await session.execute(
            text("CALL sp_ensure_habit_logs_for_day(:d)").bindparams(d=today)
        )
        await session.commit()

    res = await session.execute(
        text(
            "SELECT pl.status, pl.response_option_id, ro.label, ro.is_success "
            "FROM pattern_logs pl "
            "LEFT JOIN pattern_response_options ro ON ro.id = pl.response_option_id "
            "WHERE pl.pattern_id = :pid "
            "  AND date_trunc('day', pl.scheduled_at)::date = CURRENT_DATE "
            "ORDER BY pl.answered_at DESC NULLS LAST, pl.id DESC LIMIT 1"
        ).bindparams(pid=pattern_id)
    )
    row = res.first()
    if not is_scheduled:
        status_str, can_respond = "not_scheduled", False
    elif row is None:
        status_str, can_respond = "pending", True
    elif row[0] == "answered":
        status_str, can_respond = "answered", True
    elif row[0] == "missed":
        status_str, can_respond = "missed", False
    else:
        status_str, can_respond = "pending", True

    return PatternTodayRead(
        pattern_id=pattern_id,
        day=today.isoformat(),
        is_scheduled_today=is_scheduled,
        status=status_str,
        can_respond=can_respond,
        response_option_id=row[1] if row else None,
        response_label=row[2] if row else None,
        is_success_today=row[3] if row and row[0] == "answered" else None,
        log_status=row[0] if row else None,
    )


@router.get("/{pattern_id}/logs", response_model=list[PatternLogRead])
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


# ---------- scenario steps ------------------------------------------------


@router.put("/{pattern_id}/steps", response_model=list[PatternStepRead])
async def replace_steps(
    pattern_id: int,
    payload: PatternStepsReplace,
    session: SessionDep,
    user_id: UserIdDep,
) -> list[PatternStepRead]:
    pattern = await _get(session, pattern_id, user_id)
    if pattern.pattern_mode != "scenario":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Шаги только для scenario")
    if not payload.steps:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Нужен хотя бы один шаг")
    await session.execute(delete(PatternStep).where(PatternStep.pattern_id == pattern_id))
    for i, step in enumerate(payload.steps):
        data = step.model_dump()
        data["sort_order"] = step.sort_order if step.sort_order else i
        data["choices"] = [c.model_dump() for c in step.choices]
        session.add(PatternStep(pattern_id=pattern_id, **data))
    await session.commit()
    pattern = await _reload(session, pattern_id)
    return [PatternStepRead.model_validate(s) for s in pattern.steps]


# ---------- scenario sessions ---------------------------------------------


@router.get("/{pattern_id}/sessions/today", response_model=PatternSessionRead)
async def get_session_today(
    pattern_id: int, session: SessionDep, user_id: UserIdDep
) -> PatternSessionRead:
    pattern = await _get(session, pattern_id, user_id)
    if pattern.pattern_mode != "scenario":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Сессии только для scenario")
    today = date.today()
    required = sum(1 for s in pattern.steps if s.is_required)
    res = await session.execute(
        select(PatternDaySession)
        .options(selectinload(PatternDaySession.answers))
        .where(
            PatternDaySession.pattern_id == pattern_id,
            PatternDaySession.session_date == today,
        )
    )
    sess = res.scalar_one_or_none()
    if sess is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Сессия на сегодня не начата")
    return _session_read(sess, required)


@router.post(
    "/{pattern_id}/sessions/today",
    response_model=PatternSessionRead,
    status_code=status.HTTP_201_CREATED,
)
async def start_session_today(
    pattern_id: int, session: SessionDep, user_id: UserIdDep
) -> PatternSessionRead:
    pattern = await _get(session, pattern_id, user_id)
    if pattern.pattern_mode != "scenario":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Сессии только для scenario")
    today = date.today()
    required = sum(1 for s in pattern.steps if s.is_required)
    res = await session.execute(
        select(PatternDaySession)
        .options(selectinload(PatternDaySession.answers))
        .where(
            PatternDaySession.pattern_id == pattern_id,
            PatternDaySession.session_date == today,
        )
    )
    sess = res.scalar_one_or_none()
    if sess is None:
        sess = PatternDaySession(pattern_id=pattern_id, session_date=today)
        session.add(sess)
        await session.commit()
        await session.refresh(sess, attribute_names=["answers"])
    return _session_read(sess, required)


@router.patch(
    "/{pattern_id}/sessions/{session_id}/steps/{step_id}",
    response_model=PatternSessionRead,
)
async def answer_step(
    pattern_id: int,
    session_id: int,
    step_id: int,
    payload: PatternStepAnswerWrite,
    session: SessionDep,
    user_id: UserIdDep,
) -> PatternSessionRead:
    pattern = await _get(session, pattern_id, user_id)
    step = next((s for s in pattern.steps if s.id == step_id), None)
    if step is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Шаг не найден")

    res = await session.execute(
        select(PatternDaySession)
        .options(selectinload(PatternDaySession.answers))
        .where(
            PatternDaySession.id == session_id,
            PatternDaySession.pattern_id == pattern_id,
        )
    )
    sess = res.scalar_one_or_none()
    if sess is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Сессия не найдена")
    if sess.status == "completed":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Сессия уже завершена")

    existing = next((a for a in sess.answers if a.step_id == step_id), None)
    if existing:
        existing.choice_id = payload.choice_id
        existing.checked = payload.checked
        existing.note_text = payload.note_text
        existing.answered_at = datetime.now(tz=timezone.utc)
    else:
        session.add(
            PatternStepAnswer(
                session_id=session_id,
                step_id=step_id,
                choice_id=payload.choice_id,
                checked=payload.checked,
                note_text=payload.note_text,
            )
        )
    await session.commit()
    sess = (
        await session.execute(
            select(PatternDaySession)
            .options(selectinload(PatternDaySession.answers))
            .where(PatternDaySession.id == session_id)
        )
    ).scalar_one()
    required = sum(1 for s in pattern.steps if s.is_required)
    return _session_read(sess, required)


@router.post("/{pattern_id}/sessions/{session_id}/complete", response_model=PatternSessionRead)
async def complete_session(
    pattern_id: int,
    session_id: int,
    session: SessionDep,
    user_id: UserIdDep,
) -> PatternSessionRead:
    pattern = await _get(session, pattern_id, user_id)
    res = await session.execute(
        select(PatternDaySession)
        .options(selectinload(PatternDaySession.answers))
        .where(
            PatternDaySession.id == session_id,
            PatternDaySession.pattern_id == pattern_id,
        )
    )
    sess = res.scalar_one_or_none()
    if sess is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Сессия не найдена")

    answers = {a.step_id: a for a in sess.answers}
    missing = [
        s.title
        for s in pattern.steps
        if s.is_required and s.id not in answers
    ]
    if missing:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Не заполнены обязательные шаги: {', '.join(missing)}",
        )

    outcome = _compute_outcome(pattern.steps, answers)
    sess.outcome_success = outcome
    sess.status = "completed"
    sess.completed_at = datetime.now(tz=timezone.utc)
    await session.commit()
    required = sum(1 for s in pattern.steps if s.is_required)
    return _session_read(sess, required)


@router.get("/{pattern_id}/markers", response_model=list[PatternMarkerRead])
async def list_markers(
    pattern_id: int,
    session: SessionDep,
    user_id: UserIdDep,
    limit: int = Query(default=50, ge=1, le=200),
) -> list[PatternMarkerRead]:
    pattern = await _get(session, pattern_id, user_id)
    if pattern.pattern_mode != "markers":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Метки только для режима markers")
    res = await session.execute(
        select(PatternMarker, PatternResponseOption)
        .join(
            PatternResponseOption,
            PatternResponseOption.id == PatternMarker.marker_option_id,
        )
        .where(PatternMarker.pattern_id == pattern_id)
        .order_by(PatternMarker.occurred_at.desc())
        .limit(limit)
    )
    return [
        PatternMarkerRead(
            id=m.id,
            pattern_id=m.pattern_id,
            marker_option_id=m.marker_option_id,
            label=o.label,
            is_success=o.is_success,
            occurred_at=m.occurred_at,
            note=m.note,
        )
        for m, o in res.all()
    ]


@router.post(
    "/{pattern_id}/markers",
    response_model=PatternMarkerRead,
    status_code=status.HTTP_201_CREATED,
)
async def add_marker(
    pattern_id: int,
    payload: PatternMarkerWrite,
    session: SessionDep,
    user_id: UserIdDep,
) -> PatternMarkerRead:
    pattern = await _get(session, pattern_id, user_id)
    if pattern.pattern_mode != "markers":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Метки только для режима markers")
    opt = next((o for o in pattern.options if o.id == payload.marker_option_id), None)
    if opt is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Метка не найдена")
    occurred = payload.occurred_at or datetime.now(tz=timezone.utc)
    marker = PatternMarker(
        pattern_id=pattern_id,
        marker_option_id=payload.marker_option_id,
        occurred_at=occurred,
        note=payload.note,
    )
    session.add(marker)
    await session.execute(
        delete(PatternMarkerDayClosure).where(
            PatternMarkerDayClosure.pattern_id == pattern_id,
            PatternMarkerDayClosure.closure_date == occurred.date(),
        )
    )
    await session.commit()
    await session.refresh(marker)
    return PatternMarkerRead(
        id=marker.id,
        pattern_id=marker.pattern_id,
        marker_option_id=marker.marker_option_id,
        label=opt.label,
        is_success=opt.is_success,
        occurred_at=marker.occurred_at,
        note=marker.note,
    )


@router.post(
    "/{pattern_id}/markers/declare-clean-day",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
async def declare_clean_day(
    pattern_id: int,
    session: SessionDep,
    user_id: UserIdDep,
) -> None:
    pattern = await _get(session, pattern_id, user_id)
    if pattern.pattern_mode != "markers":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Только для режима markers")
    today = date.today()
    has_bad = await session.execute(
        select(PatternMarker.id)
        .join(
            PatternResponseOption,
            PatternResponseOption.id == PatternMarker.marker_option_id,
        )
        .where(
            PatternMarker.pattern_id == pattern_id,
            PatternMarker.occurred_at >= datetime.combine(today, datetime.min.time()).replace(
                tzinfo=timezone.utc
            ),
            PatternResponseOption.is_success.is_(False),
        )
        .limit(1)
    )
    if has_bad.scalar_one_or_none() is not None:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Нельзя закрыть день: уже есть негативные отметки",
        )
    existing = await session.execute(
        select(PatternMarkerDayClosure).where(
            PatternMarkerDayClosure.pattern_id == pattern_id,
            PatternMarkerDayClosure.closure_date == today,
        )
    )
    if existing.scalar_one_or_none() is None:
        session.add(PatternMarkerDayClosure(pattern_id=pattern_id, closure_date=today))
    await session.commit()


@router.delete(
    "/{pattern_id}/markers/declare-clean-day",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
async def undeclare_clean_day(
    pattern_id: int,
    session: SessionDep,
    user_id: UserIdDep,
) -> None:
    pattern = await _get(session, pattern_id, user_id)
    if pattern.pattern_mode != "markers":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Только для режима markers")
    today = date.today()
    await session.execute(
        delete(PatternMarkerDayClosure).where(
            PatternMarkerDayClosure.pattern_id == pattern_id,
            PatternMarkerDayClosure.closure_date == today,
        )
    )
    await session.commit()


@router.delete(
    "/{pattern_id}/markers/{marker_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
async def delete_marker(
    pattern_id: int,
    marker_id: int,
    session: SessionDep,
    user_id: UserIdDep,
) -> None:
    pattern = await _get(session, pattern_id, user_id)
    if pattern.pattern_mode != "markers":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Метки только для режима markers")
    res = await session.execute(
        select(PatternMarker).where(
            PatternMarker.id == marker_id,
            PatternMarker.pattern_id == pattern_id,
        )
    )
    marker = res.scalar_one_or_none()
    if marker is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Запись не найдена")
    await session.delete(marker)
    await session.commit()


@router.get("/{pattern_id}/insights", response_model=PatternInsightsRead)
async def pattern_insights(
    pattern_id: int,
    session: SessionDep,
    user_id: UserIdDep,
    days: int = Query(default=30, ge=7, le=90),
    time_filter: str = Query(default="all", pattern="^(all|morning|day|evening|night)$"),
) -> PatternInsightsRead:
    pattern = await _get(session, pattern_id, user_id)
    res = await session.execute(
        select(BehaviorPattern)
        .options(selectinload(BehaviorPattern.steps))
        .where(BehaviorPattern.id == pattern_id)
    )
    pattern = res.scalar_one()
    return await build_pattern_insights(session, pattern, days, user_id, time_filter)  # type: ignore[arg-type]


@router.get("/{pattern_id}/streak")
async def get_streak(
    pattern_id: int, session: SessionDep, user_id: UserIdDep
) -> dict:
    await _get(session, pattern_id, user_id)
    res = await session.execute(
        text(
            "SELECT fn_calculate_streak(:p), fn_calculate_max_streak(:p),"
            " fn_calculate_anti_streak(:p)"
        ).bindparams(p=pattern_id)
    )
    row = res.one()
    return {"current_streak": row[0], "max_streak": row[1], "anti_streak": row[2]}


async def _get(session: SessionDep, pattern_id: int, user_id: int) -> BehaviorPattern:
    res = await session.execute(
        select(BehaviorPattern).where(
            BehaviorPattern.id == pattern_id,
            BehaviorPattern.user_id == user_id,
        )
    )
    pattern = res.scalar_one_or_none()
    if pattern is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Паттерн не найден")
    return pattern


async def _reload(session: SessionDep, pattern_id: int) -> BehaviorPattern:
    session.expire_all()
    res = await session.execute(
        select(BehaviorPattern).where(BehaviorPattern.id == pattern_id)
    )
    return res.scalar_one()
