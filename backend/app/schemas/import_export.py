"""DTO импорта/экспорта."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel


class ExportPayload(BaseModel):
    data: dict[str, Any]


class ImportPayload(BaseModel):
    data: dict[str, Any]
