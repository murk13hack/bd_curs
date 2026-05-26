"""Преобразование IntegrityError PostgreSQL в понятные HTTP-ответы."""

from __future__ import annotations

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError

_CONSTRAINT_MESSAGES: dict[str, tuple[int, str]] = {
    "tasks_start_before_deadline": (
        status.HTTP_400_BAD_REQUEST,
        "Дата начала должна быть раньше дедлайна",
    ),
    "tasks_deadline_after_created": (
        status.HTTP_400_BAD_REQUEST,
        "Дедлайн должен быть позже момента создания задачи",
    ),
    "tasks_title_not_empty": (
        status.HTTP_400_BAD_REQUEST,
        "Название задачи не может быть пустым",
    ),
    "topics_user_name_uniq": (
        status.HTTP_409_CONFLICT,
        "Тема с таким названием уже существует",
    ),
    "tags_user_name_uniq": (
        status.HTTP_409_CONFLICT,
        "Тег с таким названием уже существует",
    ),
    "diary_entries_user_date_uniq": (
        status.HTTP_409_CONFLICT,
        "Запись дневника на эту дату уже существует",
    ),
    "task_time_logs_ended_after_started": (
        status.HTTP_400_BAD_REQUEST,
        "Время окончания должно быть позже начала",
    ),
}


def integrity_error_to_http(
    exc: IntegrityError,
    *,
    fallback: str = "Некорректные данные",
    fallback_status: int = status.HTTP_400_BAD_REQUEST,
) -> HTTPException:
    raw = str(exc.orig) if exc.orig else str(exc)
    for name, (code, message) in _CONSTRAINT_MESSAGES.items():
        if name in raw:
            return HTTPException(code, message)
    if "foreign key" in raw.lower() or "violates foreign key" in raw.lower():
        return HTTPException(status.HTTP_404_NOT_FOUND, "Связанная запись не найдена")
    if "unique" in raw.lower() or "duplicate key" in raw.lower():
        return HTTPException(status.HTTP_409_CONFLICT, "Такая запись уже существует")
    return HTTPException(fallback_status, fallback)
