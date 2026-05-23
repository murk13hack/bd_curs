"""FastAPI-приложение «Персональный таск-трекер» (ПТТ).

Бэкенд является тонким слоем над PostgreSQL: маршрутизация HTTP, валидация,
делегирование вычислений в БД (см. ТЗ, раздел 4.3.1). На текущей стадии — каркас
с health-check и заглушкой /api/v1/ping; дальнейшие модули добавляются в
``app/api`` по мере реализации подсистем (задачи, дневник, паттерны, статистика).
"""

from __future__ import annotations

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

API_PREFIX = "/api/v1"

app = FastAPI(
    title="ПТТ — Персональный таск-трекер",
    version="0.1.0",
    description="REST API системы ПТТ. См. ТЗ.md.",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

cors_origins = [
    o.strip() for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip()
] or ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["service"], summary="Liveness/readiness probe")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get(f"{API_PREFIX}/ping", tags=["service"], summary="Echo")
async def ping() -> dict[str, bool]:
    return {"pong": True}
