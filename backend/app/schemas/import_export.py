"""DTO импорта/экспорта."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class ExportPayload(BaseModel):
    data: dict[str, Any]


class ImportPayload(BaseModel):
    data: dict[str, Any]
    mode: Literal["merge", "restore"] = Field(
        default="merge",
        description="merge — справочники; restore — полная замена данных пользователя",
    )
