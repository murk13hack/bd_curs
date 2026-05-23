"""DTO статистики."""

from __future__ import annotations

from datetime import date

from pydantic import BaseModel


class TopicBreakdown(BaseModel):
    topic_id: int
    topic_name: str
    total: int
    done: int
    overdue: int
    completion_rate: float
    avg_planned_minutes: int | None = None
    avg_overdue_minutes: float | None = None


class CorrelationWeek(BaseModel):
    week_start: date
    avg_mood: float | None
    avg_energy: float | None
    avg_completion_rate: float | None
    corr_mood_rate: float | None
    corr_energy_rate: float | None
    days_count: int


class WeeklySummary(BaseModel):
    week_start: date
    tasks_total: int
    tasks_done: int
    tasks_overdue: int
    minutes_logged: int
    diary_entries: int


class TopicTimeBreakdown(BaseModel):
    topic_id: int
    topic_name: str
    minutes: int
    pomodoro_minutes: int
