"""Модели целей."""

from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class Goal(Base):
    __tablename__ = "goals"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    title: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    deadline: Mapped[date | None] = mapped_column(Date, nullable=True)
    target_value: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    is_completed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    links: Mapped[list["GoalLink"]] = relationship(
        "GoalLink", back_populates="goal", cascade="all, delete-orphan", lazy="selectin"
    )


class GoalLink(Base):
    __tablename__ = "goal_links"

    goal_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("goals.id", ondelete="CASCADE"), primary_key=True
    )
    target_type: Mapped[str] = mapped_column(String, primary_key=True)
    target_id: Mapped[int] = mapped_column(BigInteger, primary_key=True)

    goal: Mapped["Goal"] = relationship("Goal", back_populates="links")
