"""Модели паттернов поведения."""

from __future__ import annotations

from datetime import datetime, time

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    SmallInteger,
    Text,
    Time,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base
from app.models.enums import PatternLogStatusEnum, PatternTypeEnum


class BehaviorPattern(Base):
    __tablename__ = "behavior_patterns"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    topic_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("topics.id", ondelete="RESTRICT"), nullable=True
    )
    title: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    pattern_type: Mapped[str] = mapped_column(PatternTypeEnum, nullable=False, default="positive")
    is_boolean: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    auto_create_task: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    options: Mapped[list["PatternResponseOption"]] = relationship(
        "PatternResponseOption",
        back_populates="pattern",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="PatternResponseOption.sort_order",
    )
    schedules: Mapped[list["PatternSchedule"]] = relationship(
        "PatternSchedule",
        back_populates="pattern",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class PatternResponseOption(Base):
    __tablename__ = "pattern_response_options"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    pattern_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("behavior_patterns.id", ondelete="CASCADE"), nullable=False
    )
    label: Mapped[str] = mapped_column(Text, nullable=False)
    is_success: Mapped[bool] = mapped_column(Boolean, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    pattern: Mapped["BehaviorPattern"] = relationship("BehaviorPattern", back_populates="options")


class PatternSchedule(Base):
    __tablename__ = "pattern_schedules"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    pattern_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("behavior_patterns.id", ondelete="CASCADE"), nullable=False
    )
    time_of_day: Mapped[time] = mapped_column(Time, nullable=False)
    dow_mask: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=127)
    day_of_month: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)

    pattern: Mapped["BehaviorPattern"] = relationship("BehaviorPattern", back_populates="schedules")


class PatternLog(Base):
    __tablename__ = "pattern_logs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    pattern_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("behavior_patterns.id", ondelete="CASCADE"), nullable=False
    )
    response_option_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("pattern_response_options.id", ondelete="SET NULL"), nullable=True
    )
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    answered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    status: Mapped[str] = mapped_column(PatternLogStatusEnum, nullable=False, default="pending")
