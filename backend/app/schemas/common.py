"""Общие константы/типы."""

from __future__ import annotations

from typing import Literal

TaskStatus = Literal["pending", "in_progress", "done", "overdue", "cancelled"]
TaskPriority = Literal["low", "medium", "high", "urgent"]
PatternType = Literal["positive", "negative"]
PatternMode = Literal["habit", "scenario", "markers"]
PatternStepKind = Literal["check", "single_choice", "note"]
PatternStepRole = Literal["context", "trigger", "choice", "action", "outcome"]
PatternSessionStatus = Literal["in_progress", "completed", "abandoned"]
PatternLogStatus = Literal["pending", "answered", "missed"]
RecurrenceFreq = Literal["daily", "weekly", "monthly", "custom"]
GoalLinkTarget = Literal["task", "pattern"]
