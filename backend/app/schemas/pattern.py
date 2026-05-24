"""DTO паттернов поведения."""

from __future__ import annotations

from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import (
    PatternLogStatus,
    PatternMode,
    PatternSessionStatus,
    PatternStepKind,
    PatternStepRole,
    PatternType,
)


class StepChoice(BaseModel):
    id: str
    label: str
    is_success: bool = False


class PatternResponseOptionBase(BaseModel):
    label: str = Field(min_length=1, max_length=100)
    is_success: bool
    sort_order: int = 0


class PatternResponseOptionCreate(PatternResponseOptionBase):
    pass


class PatternResponseOptionRead(PatternResponseOptionBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


class PatternScheduleBase(BaseModel):
    time_of_day: time
    dow_mask: int = Field(default=127, ge=0, le=127)
    day_of_month: int | None = Field(default=None, ge=1, le=31)


class PatternScheduleCreate(PatternScheduleBase):
    pass


class PatternScheduleUpdate(BaseModel):
    time_of_day: time | None = None
    dow_mask: int | None = Field(default=None, ge=0, le=127)
    day_of_month: int | None = Field(default=None, ge=1, le=31)


class PatternScheduleRead(PatternScheduleBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


class PatternStepBase(BaseModel):
    title: str = Field(min_length=1, max_length=300)
    hint: str | None = None
    step_kind: PatternStepKind = "single_choice"
    step_role: PatternStepRole = "context"
    is_required: bool = True
    marks_success: bool = False
    choices: list[StepChoice] = Field(default_factory=list)
    sort_order: int = 0


class PatternStepCreate(PatternStepBase):
    pass


class PatternStepRead(PatternStepBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    pattern_id: int


class PatternBase(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    pattern_type: PatternType = "positive"
    pattern_mode: PatternMode = "habit"
    guide_intro: str | None = None
    is_boolean: bool = False
    auto_create_task: bool = False
    topic_id: int | None = None


class PatternCreate(PatternBase):
    options: list[PatternResponseOptionCreate] = Field(default_factory=list)
    schedules: list[PatternScheduleCreate] = Field(default_factory=list)
    steps: list[PatternStepCreate] = Field(default_factory=list)


class PatternUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    guide_intro: str | None = None
    auto_create_task: bool | None = None
    topic_id: int | None = None


class PatternRead(PatternBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    updated_at: datetime
    options: list[PatternResponseOptionRead] = Field(default_factory=list)
    schedules: list[PatternScheduleRead] = Field(default_factory=list)
    steps: list[PatternStepRead] = Field(default_factory=list)


class PatternLogResponse(BaseModel):
    response_option_id: int
    scheduled_at: datetime | None = None


class PatternLogRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    pattern_id: int
    response_option_id: int | None
    scheduled_at: datetime
    answered_at: datetime | None
    status: PatternLogStatus


class PatternStreakRead(BaseModel):
    pattern_id: int
    title: str
    pattern_type: PatternType
    pattern_mode: PatternMode = "habit"
    current_streak: int
    max_streak: int
    anti_streak: int
    scheduled_days_30d: int = 0
    success_days_30d: int = 0
    clean_rate_30d: float = 0.0
    success_rate_30d: float = 0.0


class PatternTodayRead(BaseModel):
    pattern_id: int
    day: str
    is_scheduled_today: bool
    status: str
    can_respond: bool
    response_option_id: int | None = None
    response_label: str | None = None
    is_success_today: bool | None = None
    log_status: PatternLogStatus | None = None
    markers_today_count: int = 0
    last_marker_label: str | None = None
    last_marker_at: datetime | None = None


class PatternMarkerWrite(BaseModel):
    marker_option_id: int
    occurred_at: datetime | None = None
    note: str | None = None


class PatternMarkerRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    pattern_id: int
    marker_option_id: int
    label: str
    is_success: bool
    occurred_at: datetime
    note: str | None = None


class PatternStepAnswerRead(BaseModel):
    step_id: int
    choice_id: str | None = None
    checked: bool | None = None
    note_text: str | None = None
    answered_at: datetime


class PatternSessionRead(BaseModel):
    id: int
    pattern_id: int
    session_date: str
    status: PatternSessionStatus
    outcome_success: bool | None = None
    started_at: datetime
    completed_at: datetime | None = None
    answers: list[PatternStepAnswerRead] = Field(default_factory=list)
    answered_count: int = 0
    required_count: int = 0


class PatternStepAnswerWrite(BaseModel):
    choice_id: str | None = None
    checked: bool | None = None
    note_text: str | None = None


class PatternStepsReplace(BaseModel):
    steps: list[PatternStepCreate]


class PatternDayCell(BaseModel):
    day: str
    status: str


class PatternChoiceStat(BaseModel):
    step_id: int
    step_title: str
    choice_id: str
    label: str
    count: int
    pct: float
    is_success: bool | None = None


class PatternPathStat(BaseModel):
    path: str
    count: int
    pct: float
    is_success: bool


class PatternHourStat(BaseModel):
    hour: int
    count: int
    bad_count: int = 0


class PatternTimeBucketStat(BaseModel):
    bucket: str
    label: str
    total_events: int
    failure_count: int
    failure_pct: float


class PatternDiaryMoodBucket(BaseModel):
    mood_range: str
    label: str
    days: int
    clean_days: int
    clean_rate: float
    avg_energy: float | None = None


class PatternDiaryCorrelation(BaseModel):
    mood_buckets: list[PatternDiaryMoodBucket] = Field(default_factory=list)
    corr_mood_clean: float | None = None
    insight: str | None = None


class PatternInsightsRead(BaseModel):
    pattern_id: int
    days: int
    time_filter: str = "all"
    scheduled_days: int
    success_days: int
    clean_rate: float
    calendar: list[PatternDayCell]
    choice_breakdown: list[PatternChoiceStat] = Field(default_factory=list)
    top_paths: list[PatternPathStat] = Field(default_factory=list)
    hourly_counts: list[PatternHourStat] = Field(default_factory=list)
    time_of_day_stats: list[PatternTimeBucketStat] = Field(default_factory=list)
    diary_correlation: PatternDiaryCorrelation | None = None
    insights: list[str] = Field(default_factory=list)
