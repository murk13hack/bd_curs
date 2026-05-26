"""Общие преобразования дат/времени для Pydantic DTO."""

from __future__ import annotations

from datetime import date, datetime, time, timezone
from typing import Any


def coerce_optional_date(value: Any) -> date | None:
    """Принимает YYYY-MM-DD или ISO datetime (обрезает до даты)."""
    if value is None or value == "":
        return None
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, str):
        raw = value.strip()
        if not raw:
            return None
        if "T" in raw:
            raw = raw.split("T", 1)[0]
        return date.fromisoformat(raw)
    raise TypeError("ожидается дата YYYY-MM-DD")


def coerce_optional_datetime(value: Any) -> datetime | None:
    """Принимает ISO datetime, date или YYYY-MM-DD."""
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value
    if isinstance(value, date) and not isinstance(value, datetime):
        return datetime.combine(value, time.min, tzinfo=timezone.utc)
    if isinstance(value, str):
        raw = value.strip()
        if not raw:
            return None
        if "T" in raw or " " in raw:
            norm = raw.replace("Z", "+00:00")
            return datetime.fromisoformat(norm)
        d = date.fromisoformat(raw)
        return datetime.combine(d, time.min, tzinfo=timezone.utc)
    raise TypeError("ожидается дата/время ISO")
