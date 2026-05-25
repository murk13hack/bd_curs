"""DTO правил повторения."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.common import RecurrenceFreq


class RecurringRuleBase(BaseModel):
    frequency: RecurrenceFreq
    params: dict[str, Any] = Field(default_factory=dict)
    is_active: bool = True

    @model_validator(mode="after")
    def _validate_params(self) -> "RecurringRuleBase":
        if self.frequency == "weekly" and "weekly_mask" not in self.params:
            self.params = {**self.params, "weekly_mask": 127}
        if self.frequency == "monthly" and "monthly_day" not in self.params:
            self.params = {**self.params, "monthly_day": 1}
        if self.frequency == "custom":
            days = int(self.params.get("interval_days", 1))
            if days < 1:
                raise ValueError("params.interval_days must be >= 1 for custom frequency")
            self.params = {**self.params, "interval_days": days}
        return self


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
