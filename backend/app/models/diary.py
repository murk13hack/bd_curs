"""Модели дневника."""

from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Date,
    DateTime,
    ForeignKey,
    SmallInteger,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class DiaryEntry(Base):
    __tablename__ = "diary_entries"
    __table_args__ = (
        UniqueConstraint("user_id", "entry_date", name="uq_diary_entries_user_id_entry_date"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    entry_date: Mapped[date] = mapped_column(Date, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    mood: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    energy: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    tag_links: Mapped[list["DiaryTag"]] = relationship(
        "DiaryTag", back_populates="entry", cascade="all, delete-orphan", lazy="selectin"
    )


class DiaryTag(Base):
    __tablename__ = "diary_tags"

    entry_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("diary_entries.id", ondelete="CASCADE"), primary_key=True
    )
    tag_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("tags.id", ondelete="CASCADE"), primary_key=True
    )

    entry: Mapped["DiaryEntry"] = relationship("DiaryEntry", back_populates="tag_links")
