"""Импорт/экспорт через хранимые процедуры sp_export_user_data / sp_import_user_data."""

from __future__ import annotations

import csv
import io

from fastapi import APIRouter, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select, text

from app.api.v1.deps import SessionDep, UserIdDep
from app.models import Task, Topic
from app.schemas.import_export import ExportPayload, ImportPayload

router = APIRouter(tags=["import-export"])


@router.get(
    "/export/json",
    response_model=ExportPayload,
    summary="Экспорт данных пользователя (sp_export_user_data)",
)
async def export_json(session: SessionDep, user_id: UserIdDep) -> ExportPayload:
    res = await session.execute(
        text("CALL sp_export_user_data(:uid, NULL::jsonb)").bindparams(uid=user_id)
    )
    row = res.first()
    return ExportPayload(data=row[0] if row and row[0] else {})


@router.post(
    "/import/json",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Импорт данных (sp_import_user_data)",
)
async def import_json(
    payload: ImportPayload, session: SessionDep, user_id: UserIdDep
) -> dict[str, str]:
    await session.execute(
        text("CALL sp_import_user_data(:uid, CAST(:doc AS jsonb))").bindparams(
            uid=user_id, doc=__import__("json").dumps(payload.data)
        )
    )
    await session.commit()
    return {"status": "imported"}


@router.get(
    "/export/csv/tasks",
    summary="Экспорт задач в CSV",
)
async def export_tasks_csv(session: SessionDep, user_id: UserIdDep) -> StreamingResponse:
    res = await session.execute(
        select(Task, Topic.name)
        .join(Topic, Task.topic_id == Topic.id)
        .where(Task.user_id == user_id)
        .order_by(Task.created_at.desc())
    )

    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(
        [
            "id",
            "title",
            "description",
            "topic",
            "status",
            "priority",
            "deadline",
            "completed_at",
            "planned_minutes",
            "is_archived",
            "created_at",
        ]
    )
    for row in res:
        task: Task = row[0]
        topic_name: str = row[1]
        writer.writerow(
            [
                task.id,
                task.title,
                (task.description or "").replace("\n", " "),
                topic_name,
                task.status,
                task.priority,
                task.deadline.isoformat() if task.deadline else "",
                task.completed_at.isoformat() if task.completed_at else "",
                task.planned_minutes or "",
                task.is_archived,
                task.created_at.isoformat(),
            ]
        )

    buf.seek(0)
    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": "attachment; filename=tasks.csv"},
    )
