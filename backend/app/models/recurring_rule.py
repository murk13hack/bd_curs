"""Модель правила повторения задач."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, BigInteger, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base
from app.models.enums import RecurrenceFreqEnum


class RecurringRule(Base):
    __tablename__ = "recurring_rules"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    frequency: Mapped[str] = mapped_column(RecurrenceFreqEnum, nullable=False)
    params: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict, server_default="{}")
    next_run_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
