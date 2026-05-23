"""Конфигурация бэкенда (Pydantic Settings)."""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Глобальные настройки приложения."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "ПТТ — Персональный таск-трекер"
    app_version: str = "0.1.0"
    api_prefix: str = "/api/v1"

    database_url: str = Field(
        default="postgresql+asyncpg://ptt:ptt@db:5432/ptt",
        description="Async DSN для SQLAlchemy",
    )

    cors_origins: str = Field(
        default="*",
        description="CSV список origin'ов или '*'",
    )

    tz: str = Field(default="Europe/Moscow")

    default_user_id: int = Field(
        default=1,
        description="ID единственного пользователя в одно-пользовательском режиме",
    )

    scheduler_enabled: bool = True

    @property
    def cors_origins_list(self) -> list[str]:
        raw = self.cors_origins.strip()
        if not raw or raw == "*":
            return ["*"]
        return [o.strip() for o in raw.split(",") if o.strip()]

    @property
    def sync_database_url(self) -> str:
        """Sync-вариант URL для Alembic."""
        return self.database_url.replace("+asyncpg", "+psycopg")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
