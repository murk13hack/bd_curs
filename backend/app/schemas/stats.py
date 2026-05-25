"""DTO статистики и OLAP."""

from __future__ import annotations

from datetime import date
from typing import Any

from pydantic import BaseModel, Field


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


class HolisticCorrelationWeek(BaseModel):
    week_start: date
    avg_mood: float | None
    avg_energy: float | None
    avg_task_rate: float | None
    avg_pattern_clean_rate: float | None
    avg_minutes: float | None
    corr_mood_tasks: float | None
    corr_mood_patterns: float | None
    corr_energy_tasks: float | None
    days_count: int


class MoodBucketStat(BaseModel):
    bucket: str
    label: str
    days: int
    avg_task_rate: float | None
    avg_pattern_rate: float | None


class DiaryScatterDay(BaseModel):
    day: str
    mood: float
    energy: float | None
    task_rate: float | None
    pattern_rate: float | None


class DiaryInsights(BaseModel):
    date_from: str
    date_to: str
    diary_days: int
    corr_mood_tasks: float | None
    corr_mood_patterns: float | None
    corr_energy_tasks: float | None
    corr_mood_energy: float | None
    corr_mood_tasks_same_day: float | None
    same_day_diary_task_days: int
    mood_buckets: list[MoodBucketStat]
    insights: list[str]
    scatter_days: list[DiaryScatterDay]
    weeks: list[HolisticCorrelationWeek]


class WeeklySummary(BaseModel):
    week_start: date
    tasks_total: int
    tasks_done: int
    tasks_overdue: int
    minutes_logged: int
    diary_entries: int
    avg_mood: float | None = None
    avg_energy: float | None = None
    patterns_scheduled: int = 0
    patterns_success: int = 0
    marker_events: int = 0
    marker_bad_events: int = 0


class TopicTimeBreakdown(BaseModel):
    topic_id: int
    topic_name: str
    minutes: int
    pomodoro_minutes: int


class PriorityBreakdown(BaseModel):
    priority: str
    total: int
    done: int
    overdue: int
    completion_rate: float


class PatternStatsRow(BaseModel):
    pattern_id: int
    title: str
    pattern_type: str
    pattern_mode: str
    current_streak: int
    max_streak: int
    scheduled_days_30d: int
    success_days_30d: int
    clean_rate_30d: float


class StatsOverview(BaseModel):
    days: int
    date_from: str
    date_to: str
    tasks_total: int
    tasks_done: int
    tasks_overdue: int
    task_completion_rate: float
    minutes_logged: int
    pomodoro_minutes: int
    diary_entries: int
    avg_mood: float | None
    avg_energy: float | None
    patterns_scheduled: int
    patterns_success: int
    pattern_clean_rate: float
    marker_events: int
    marker_bad_events: int
    activity_score: int
    active_days: int


class OlapQuery(BaseModel):
    dimensions: list[str] = Field(default_factory=list, max_length=3)
    measures: list[str] = Field(min_length=1, max_length=12)
    date_from: date | None = None
    date_to: date | None = None
    filters: dict[str, str] = Field(default_factory=dict)


class OlapResult(BaseModel):
    date_from: str
    date_to: str
    dimensions: list[str]
    measures: list[str]
    rows: list[dict[str, Any]]


class OlapMetaItem(BaseModel):
    id: str
    label: str
    hint: str | None = None
    max_period_days: int | None = None
    unit: str | None = None


class OlapMeta(BaseModel):
    dimensions: list[OlapMetaItem]
    measures: list[OlapMetaItem]
    help: str = ""
