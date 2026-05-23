"""Модель праздника."""

from __future__ import annotations

from datetime import date

from sqlalchemy import BigInteger, Boolean, Date, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Holiday(Base):
    __tablename__ = "holidays"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    holiday_date: Mapped[date] = mapped_column(Date, nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    is_official: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
