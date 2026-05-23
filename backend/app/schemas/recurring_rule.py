"""DTO правил повторения."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import RecurrenceFreq


class RecurringRuleBase(BaseModel):
    frequency: RecurrenceFreq
    params: dict[str, Any] = Field(default_factory=dict)
    is_active: bool = True


class RecurringRuleCreate(RecurringRuleBase):
    pass


class RecurringRuleUpdate(BaseModel):
    frequency: RecurrenceFreq | None = None
    params: dict[str, Any] | None = None
    is_active: bool | None = None


class RecurringRuleRead(RecurringRuleBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    next_run_at: datetime | None = None
    created_at: datetime
