"""DTO пользовательских настроек."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class AppSettingBase(BaseModel):
    key: str = Field(min_length=1, max_length=100)
    value: Any


class AppSettingUpsert(AppSettingBase):
    pass


class AppSettingRead(AppSettingBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
