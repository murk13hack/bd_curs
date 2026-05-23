"""Сервисные эндпоинты."""

from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import text

from app.api.v1.deps import SessionDep

router = APIRouter(tags=["service"])


@router.get("/ping", summary="Echo")
async def ping() -> dict[str, bool]:
    return {"pong": True}


@router.get("/db-ping", summary="Проверка соединения с БД")
async def db_ping(session: SessionDep) -> dict[str, str]:
    res = await session.execute(text("SELECT version()"))
    version = res.scalar_one()
    return {"db": "ok", "version": version}
