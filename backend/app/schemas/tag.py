"""DTO для тегов."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class TagBase(BaseModel):
    name: str = Field(min_length=1, max_length=100)


class TagCreate(TagBase):
    pass


class TagUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)


class TagRead(TagBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
