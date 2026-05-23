"""DTO дневника."""

from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class DiaryEntryBase(BaseModel):
    entry_date: date
    content: str = Field(min_length=1)
    mood: int | None = Field(default=None, ge=1, le=5)
    energy: int | None = Field(default=None, ge=1, le=5)


class DiaryEntryCreate(DiaryEntryBase):
    tag_ids: list[int] = Field(default_factory=list)


class DiaryEntryUpdate(BaseModel):
    content: str | None = Field(default=None, min_length=1)
    mood: int | None = Field(default=None, ge=1, le=5)
    energy: int | None = Field(default=None, ge=1, le=5)
    tag_ids: list[int] | None = None


class DiaryEntryRead(DiaryEntryBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    updated_at: datetime
    tag_ids: list[int] = Field(default_factory=list)


class DiarySearchHit(BaseModel):
    entry_id: int
    entry_date: date
    rank: float
    snippet: str
