"""DTO для задач, журналов времени и связки с тегами."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.common import TaskPriority, TaskStatus
from app.schemas.recurring_rule import RecurringRuleCreate

TaskView = Literal["active", "completed", "all"]


def _validate_task_window(
    start_at: datetime | None, deadline: datetime | None
) -> None:
    if start_at is not None and deadline is not None and start_at >= deadline:
        raise ValueError("start_at must be earlier than deadline")


class TaskBase(BaseModel):
    topic_id: int
    title: str = Field(min_length=1, max_length=500)
    description: str | None = None
    priority: TaskPriority = "medium"
    start_at: datetime | None = None
    deadline: datetime | None = None
    planned_minutes: int | None = Field(default=None, gt=0)
    parent_task_id: int | None = None


class TaskCreate(TaskBase):
    tag_ids: list[int] = Field(default_factory=list)
    recurring: RecurringRuleCreate | None = None

    @model_validator(mode="after")
    def _validate_window(self) -> "TaskCreate":
        _validate_task_window(self.start_at, self.deadline)
        return self


class TaskUpdate(BaseModel):
    topic_id: int | None = None
    title: str | None = Field(default=None, min_length=1, max_length=500)
    description: str | None = None
    priority: TaskPriority | None = None
    status: TaskStatus | None = None
    start_at: datetime | None = None
    deadline: datetime | None = None
    planned_minutes: int | None = Field(default=None, gt=0)
    is_archived: bool | None = None
    tag_ids: list[int] | None = None

    @model_validator(mode="after")
    def _validate_window(self) -> "TaskUpdate":
        _validate_task_window(self.start_at, self.deadline)
        return self


class TaskRead(TaskBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    status: TaskStatus
    completed_at: datetime | None
    is_archived: bool
    recurring_rule_id: int | None
    created_at: datetime
    updated_at: datetime
    tag_ids: list[int] = Field(default_factory=list)


class TimeLogCreate(BaseModel):
    started_at: datetime
    ended_at: datetime
    is_pomodoro: bool = False
    note: str | None = None

    @model_validator(mode="after")
    def _validate(self) -> "TimeLogCreate":
        if self.ended_at <= self.started_at:
            raise ValueError("ended_at must be greater than started_at")
        return self


class TimeLogRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    task_id: int
    started_at: datetime
    ended_at: datetime
    duration_seconds: int
    is_pomodoro: bool
    note: str | None
