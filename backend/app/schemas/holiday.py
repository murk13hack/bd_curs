"""DTO для праздников."""

from __future__ import annotations

from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class HolidayBase(BaseModel):
    holiday_date: date
    name: str = Field(min_length=1, max_length=200)
    is_official: bool = True


class HolidayCreate(HolidayBase):
    pass


class HolidayUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    is_official: bool | None = None


class HolidayRead(HolidayBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
