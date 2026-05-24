"""SQLAlchemy ORM модели соответствуют 18 таблицам из db/init/03-tables.sql."""

from app.models.base import Base
from app.models.user import User
from app.models.topic import Topic
from app.models.tag import Tag
from app.models.recurring_rule import RecurringRule
from app.models.task import Task, TaskTag, TaskTimeLog
from app.models.diary import DiaryEntry, DiaryTag
from app.models.pattern import (
    BehaviorPattern,
    PatternDaySession,
    PatternLog,
    PatternResponseOption,
    PatternSchedule,
    PatternMarker,
    PatternStep,
    PatternStepAnswer,
)
from app.models.goal import Goal, GoalLink
from app.models.holiday import Holiday
from app.models.app_setting import AppSetting

__all__ = [
    "Base",
    "User",
    "Topic",
    "Tag",
    "RecurringRule",
    "Task",
    "TaskTag",
    "TaskTimeLog",
    "DiaryEntry",
    "DiaryTag",
    "BehaviorPattern",
    "PatternResponseOption",
    "PatternSchedule",
    "PatternStep",
    "PatternDaySession",
    "PatternStepAnswer",
    "PatternMarker",
    "PatternLog",
    "Goal",
    "GoalLink",
    "Holiday",
    "AppSetting",
]
