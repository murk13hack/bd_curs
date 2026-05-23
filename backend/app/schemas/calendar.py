"""DTO календаря."""

from __future__ import annotations

from datetime import date

from pydantic import BaseModel


class CalendarDay(BaseModel):
    day: date
    total: int
    done: int
    ratio: float
    color: str
    is_holiday: bool
    holiday_name: str | None
    has_diary: bool


class HeatmapPoint(BaseModel):
    day: date
    activity: int
