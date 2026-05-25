"""DTO целей."""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import GoalLinkTarget


def _coerce_optional_date(value: Any) -> date | None:
    """Принимает YYYY-MM-DD или ISO datetime (обрезает до даты)."""
    if value is None or value == '':
        return None
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, str):
        raw = value.strip()
        if 'T' in raw:
            raw = raw.split('T', 1)[0]
        return date.fromisoformat(raw)
    raise TypeError('deadline должен быть датой YYYY-MM-DD')


class GoalLinkBase(BaseModel):
    target_type: GoalLinkTarget
    target_id: int


class GoalLinkRead(GoalLinkBase):
    model_config = ConfigDict(from_attributes=True)


class GoalBase(BaseModel):
    title: str = Field(min_length=1, max_length=300)
    description: str | None = None
    deadline: date | None = None
    target_value: int = Field(default=1, gt=0)

    @field_validator('deadline', mode='before')
    @classmethod
    def parse_deadline(cls, value: Any) -> date | None:
        return _coerce_optional_date(value)


class GoalCreate(GoalBase):
    links: list[GoalLinkBase] = Field(default_factory=list)


class GoalUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=300)
    description: str | None = None
    deadline: date | None = None
    target_value: int | None = Field(default=None, gt=0)
    is_completed: bool | None = None

    @field_validator('deadline', mode='before')
    @classmethod
    def parse_deadline(cls, value: Any) -> date | None:
        return _coerce_optional_date(value)


class GoalRead(GoalBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    is_completed: bool
    completed_at: datetime | None
    created_at: datetime
    updated_at: datetime
    links: list[GoalLinkRead] = Field(default_factory=list)


class GoalProgress(BaseModel):
    goal_id: int
    progress: float
    done_units: int
    target_value: int
    remaining_units: int
    links: list["GoalLinkDetail"] = Field(default_factory=list)


class GoalLinkDetail(BaseModel):
    target_type: GoalLinkTarget
    target_id: int
    title: str
    contributed: bool
    detail: str | None = None
