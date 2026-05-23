"""Общие зависимости роутеров."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.db import get_session


async def current_user_id() -> int:
    """В одно-пользовательском режиме всегда возвращает default_user_id."""
    return get_settings().default_user_id


SessionDep = Annotated[AsyncSession, Depends(get_session)]
UserIdDep = Annotated[int, Depends(current_user_id)]
