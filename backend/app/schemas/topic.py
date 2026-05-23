"""DTO для тем."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class TopicBase(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    color: str = Field(default="#3B82F6", pattern=r"^#[0-9A-Fa-f]{6}$")


class TopicCreate(TopicBase):
    pass


class TopicUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")


class TopicRead(TopicBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
