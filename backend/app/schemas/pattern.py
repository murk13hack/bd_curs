"""DTO паттернов поведения."""

from __future__ import annotations

from datetime import datetime, time

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import PatternLogStatus, PatternType


class PatternResponseOptionBase(BaseModel):
    label: str = Field(min_length=1, max_length=100)
    is_success: bool
    sort_order: int = 0


class PatternResponseOptionCreate(PatternResponseOptionBase):
    pass


class PatternResponseOptionRead(PatternResponseOptionBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


class PatternScheduleBase(BaseModel):
    time_of_day: time
    dow_mask: int = Field(default=127, ge=0, le=127)
    day_of_month: int | None = Field(default=None, ge=1, le=31)


class PatternScheduleCreate(PatternScheduleBase):
    pass


class PatternScheduleRead(PatternScheduleBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


class PatternBase(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    pattern_type: PatternType = "positive"
    is_boolean: bool = False
    auto_create_task: bool = False
    topic_id: int | None = None


class PatternCreate(PatternBase):
    options: list[PatternResponseOptionCreate] = Field(default_factory=list)
    schedules: list[PatternScheduleCreate] = Field(default_factory=list)


class PatternUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    pattern_type: PatternType | None = None
    is_boolean: bool | None = None
    auto_create_task: bool | None = None
    topic_id: int | None = None


class PatternRead(PatternBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    updated_at: datetime
    options: list[PatternResponseOptionRead] = Field(default_factory=list)
    schedules: list[PatternScheduleRead] = Field(default_factory=list)


class PatternLogResponse(BaseModel):
    response_option_id: int
    scheduled_at: datetime | None = None


class PatternLogRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    pattern_id: int
    response_option_id: int | None
    scheduled_at: datetime
    answered_at: datetime | None
    status: PatternLogStatus


class PatternStreakRead(BaseModel):
    pattern_id: int
    title: str
    pattern_type: PatternType
    current_streak: int
    max_streak: int
    anti_streak: int
    logs_30d: int
    success_rate_30d: float
