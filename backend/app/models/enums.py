"""Описание ENUM-типов PostgreSQL (создаются 02-types.sql)."""

from __future__ import annotations

from sqlalchemy.dialects.postgresql import ENUM

TaskStatusEnum = ENUM(
    "pending",
    "in_progress",
    "done",
    "overdue",
    "cancelled",
    name="task_status_enum",
    create_type=False,
)

TaskPriorityEnum = ENUM(
    "low",
    "medium",
    "high",
    "urgent",
    name="task_priority_enum",
    create_type=False,
)

PatternTypeEnum = ENUM(
    "positive",
    "negative",
    name="pattern_type_enum",
    create_type=False,
)

PatternLogStatusEnum = ENUM(
    "pending",
    "answered",
    "missed",
    name="pattern_log_status_enum",
    create_type=False,
)

RecurrenceFreqEnum = ENUM(
    "daily",
    "weekly",
    "monthly",
    "custom",
    name="recurrence_freq_enum",
    create_type=False,
)
