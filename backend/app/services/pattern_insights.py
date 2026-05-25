"""Агрегация «Картины» паттерна: календарь, ветки, время суток, дневник."""

from __future__ import annotations

import math
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta, timezone
from typing import Literal
from zoneinfo import ZoneInfo

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import (
    BehaviorPattern,
    DiaryEntry,
    PatternDaySession,
    PatternLog,
    PatternMarker,
    PatternResponseOption,
    PatternStep,
)
from app.schemas.pattern import (
    PatternChoiceStat,
    PatternDayCell,
    PatternDiaryCorrelation,
    PatternDiaryMoodBucket,
    PatternHourStat,
    PatternInsightsRead,
    PatternPathStat,
    PatternTimeBucketStat,
)

TimeFilter = Literal["all", "morning", "day", "evening", "night"]

TIME_BUCKET_LABELS: dict[str, str] = {
    "all": "Весь день",
    "morning": "Утро (5–11)",
    "day": "День (11–17)",
    "evening": "Вечер (17–23)",
    "night": "Ночь (23–5)",
}

MOOD_BUCKET_LABELS = {
    "low": "Настроение 1–2",
    "mid": "Настроение 3",
    "high": "Настроение 4–5",
}


def _time_bucket(hour: int) -> str:
    if 5 <= hour < 11:
        return "morning"
    if 11 <= hour < 17:
        return "day"
    if 17 <= hour < 23:
        return "evening"
    return "night"


async def _user_tz(session: AsyncSession, user_id: int) -> ZoneInfo:
    res = await session.execute(
        text("SELECT timezone FROM users WHERE id = :uid").bindparams(uid=user_id)
    )
    tz_name = res.scalar_one_or_none() or "Europe/Moscow"
    try:
        return ZoneInfo(tz_name)
    except Exception:
        return ZoneInfo("Europe/Moscow")


def _local_hour(dt: datetime, tz: ZoneInfo) -> int:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(tz).hour


def _in_time_filter(dt: datetime, time_filter: TimeFilter, tz: ZoneInfo) -> bool:
    if time_filter == "all":
        return True
    return _time_bucket(_local_hour(dt, tz)) == time_filter


async def _is_scheduled(session: AsyncSession, pattern_id: int, day: date) -> bool:
    res = await session.execute(
        text("SELECT fn_pattern_is_scheduled(:p, :d)").bindparams(p=pattern_id, d=day)
    )
    return bool(res.scalar())


async def _has_answer(session: AsyncSession, pattern_id: int, day: date) -> bool:
    res = await session.execute(
        text("SELECT fn_pattern_day_has_answer(:p, :d)").bindparams(p=pattern_id, d=day)
    )
    return bool(res.scalar())


async def _day_success(session: AsyncSession, pattern_id: int, day: date) -> bool:
    res = await session.execute(
        text("SELECT fn_pattern_day_success(:p, :d)").bindparams(p=pattern_id, d=day)
    )
    return bool(res.scalar())


async def _build_calendar_batch(
    session: AsyncSession,
    pattern: BehaviorPattern,
    start: date,
    today: date,
    sessions: dict[date, PatternDaySession],
) -> list[PatternDayCell]:
    if pattern.pattern_mode == "scenario":
        out: list[PatternDayCell] = []
        d = start
        while d <= today:
            out.append(await _calendar_cell(session, pattern, d, today, sessions))
            d += timedelta(days=1)
        return out

    res = await session.execute(
        text(
            """
            SELECT d.day::date AS day,
                   fn_pattern_is_scheduled(:pid, d.day::date) AS scheduled,
                   fn_pattern_day_has_answer(:pid, d.day::date) AS has_answer,
                   fn_pattern_day_success(:pid, d.day::date) AS success
              FROM generate_series(:start, :end, '1 day'::interval) AS d(day)
            """
        ).bindparams(pid=pattern.id, start=start, end=today)
    )
    cells: list[PatternDayCell] = []
    for row in res.all():
        day: date = row[0]
        scheduled, has_answer, success = bool(row[1]), bool(row[2]), bool(row[3])
        if not scheduled:
            cells.append(PatternDayCell(day=day.isoformat(), status="not_scheduled"))
            continue
        if pattern.pattern_mode == "markers":
            if not has_answer:
                status = "success" if day < today else "pending"
            else:
                status = "success" if success else "failure"
        elif not has_answer:
            status = "missed" if day < today else "pending"
        else:
            status = "success" if success else "failure"
        cells.append(PatternDayCell(day=day.isoformat(), status=status))
    return cells


async def _calendar_cell(
    session: AsyncSession,
    pattern: BehaviorPattern,
    day: date,
    today: date,
    sessions: dict[date, PatternDaySession],
) -> PatternDayCell:
    if not await _is_scheduled(session, pattern.id, day):
        return PatternDayCell(day=day.isoformat(), status="not_scheduled")

    if pattern.pattern_mode == "scenario":
        sess = sessions.get(day)
        if sess is None:
            return PatternDayCell(
                day=day.isoformat(),
                status="missed" if day < today else "pending",
            )
        if sess.status == "in_progress":
            return PatternDayCell(day=day.isoformat(), status="in_progress")
        if sess.status != "completed":
            return PatternDayCell(
                day=day.isoformat(),
                status="missed" if day < today else "pending",
            )
        return PatternDayCell(
            day=day.isoformat(),
            status="success" if sess.outcome_success else "failure",
        )

    if pattern.pattern_mode == "markers":
        if not await _has_answer(session, pattern.id, day):
            return PatternDayCell(
                day=day.isoformat(),
                status="missed" if day < today else "pending",
            )
        if await _day_success(session, pattern.id, day):
            return PatternDayCell(day=day.isoformat(), status="success")
        return PatternDayCell(day=day.isoformat(), status="failure")

    if not await _has_answer(session, pattern.id, day):
        return PatternDayCell(
            day=day.isoformat(),
            status="missed" if day < today else "pending",
        )
    return PatternDayCell(
        day=day.isoformat(),
        status="success" if await _day_success(session, pattern.id, day) else "failure",
    )


def _choice_label(step: PatternStep | None, choice_id: str) -> str:
    if step is None:
        return choice_id
    for raw in step.choices or []:
        cid = raw.get("id") if isinstance(raw, dict) else None
        if cid == choice_id:
            return str(raw.get("label", choice_id))
    return choice_id


def _choice_is_success(step: PatternStep | None, choice_id: str) -> bool | None:
    if step is None:
        return None
    for raw in step.choices or []:
        cid = raw.get("id") if isinstance(raw, dict) else None
        if cid == choice_id:
            return bool(raw.get("is_success", False))
    return None


def _session_event_time(sess: PatternDaySession) -> datetime | None:
    if sess.completed_at:
        return sess.completed_at
    if sess.answers:
        return max(a.answered_at for a in sess.answers)
    return sess.started_at


def _build_time_stats(
    events: list[tuple[datetime, bool]],
    tz: ZoneInfo,
) -> list[PatternTimeBucketStat]:
    buckets: dict[str, list[bool]] = {k: [] for k in ("morning", "day", "evening", "night")}
    for dt, is_bad in events:
        buckets[_time_bucket(_local_hour(dt, tz))].append(is_bad)

    stats: list[PatternTimeBucketStat] = []
    for key in ("morning", "day", "evening", "night"):
        items = buckets[key]
        if not items:
            continue
        failures = sum(1 for bad in items if bad)
        stats.append(
            PatternTimeBucketStat(
                bucket=key,
                label=TIME_BUCKET_LABELS[key],
                total_events=len(items),
                failure_count=failures,
                failure_pct=round(100 * failures / len(items), 1),
            )
        )
    return stats


def _pearson(xs: list[float], ys: list[float]) -> float | None:
    n = len(xs)
    if n < 3:
        return None
    mx = sum(xs) / n
    my = sum(ys) / n
    num = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    den_x = math.sqrt(sum((x - mx) ** 2 for x in xs))
    den_y = math.sqrt(sum((y - my) ** 2 for y in ys))
    if den_x == 0 or den_y == 0:
        return None
    return round(num / (den_x * den_y), 2)


async def _build_diary_correlation(
    session: AsyncSession,
    user_id: int,
    calendar: list[PatternDayCell],
    start: date,
    today: date,
) -> PatternDiaryCorrelation:
    res = await session.execute(
        select(DiaryEntry).where(
            DiaryEntry.user_id == user_id,
            DiaryEntry.entry_date >= start,
            DiaryEntry.entry_date <= today,
        )
    )
    entries = {e.entry_date: e for e in res.scalars()}

    agg: dict[str, dict] = {
        k: {"days": 0, "clean": 0, "energy_sum": 0, "energy_n": 0}
        for k in MOOD_BUCKET_LABELS
    }
    mood_points: list[tuple[float, float]] = []

    for cell in calendar:
        if cell.status == "not_scheduled":
            continue
        day = date.fromisoformat(cell.day)
        entry = entries.get(day)
        if entry is None or entry.mood is None:
            continue
        if entry.mood <= 2:
            key = "low"
        elif entry.mood == 3:
            key = "mid"
        else:
            key = "high"
        agg[key]["days"] += 1
        if cell.status == "success":
            agg[key]["clean"] += 1
        if entry.energy is not None:
            agg[key]["energy_sum"] += entry.energy
            agg[key]["energy_n"] += 1
        mood_points.append((float(entry.mood), 1.0 if cell.status == "success" else 0.0))

    buckets = [
        PatternDiaryMoodBucket(
            mood_range=key,
            label=MOOD_BUCKET_LABELS[key],
            days=data["days"],
            clean_days=data["clean"],
            clean_rate=round(100 * data["clean"] / data["days"], 1) if data["days"] else 0.0,
            avg_energy=round(data["energy_sum"] / data["energy_n"], 1)
            if data["energy_n"]
            else None,
        )
        for key, data in agg.items()
        if data["days"] > 0
    ]

    corr = _pearson([p[0] for p in mood_points], [p[1] for p in mood_points]) if mood_points else None
    insight: str | None = None
    low = next((b for b in buckets if b.mood_range == "low"), None)
    high = next((b for b in buckets if b.mood_range == "high"), None)
    if low and high and low.days >= 2 and high.days >= 2:
        if high.clean_rate - low.clean_rate >= 15:
            insight = (
                f"При настроении 4–5 чистых дней {high.clean_rate}%, "
                f"при 1–2 — {low.clean_rate}%."
            )
        elif low.clean_rate < high.clean_rate:
            insight = (
                f"Низкое настроение совпадает с меньшей долей успешных дней "
                f"({low.clean_rate}% vs {high.clean_rate}%)."
            )
    elif corr is not None and abs(corr) >= 0.35:
        word = "выше" if corr > 0 else "ниже"
        insight = f"Корреляция настроения и успешных дней: {corr:.2f} (чем выше настроение, тем {word} доля чистых дней)."

    return PatternDiaryCorrelation(
        mood_buckets=buckets,
        corr_mood_clean=corr,
        insight=insight,
    )


def _build_insight_notes(
    pattern: BehaviorPattern,
    calendar: list[PatternDayCell],
    choice_stats: list[PatternChoiceStat],
    failure_sessions: list[PatternDaySession],
    steps_by_id: dict[int, PatternStep],
    time_filter: TimeFilter,
    time_stats: list[PatternTimeBucketStat],
    marker_events: list[tuple[datetime, bool]],
    tz: ZoneInfo,
) -> list[str]:
    notes: list[str] = []
    prefix = ""
    if time_filter != "all":
        prefix = f"[{TIME_BUCKET_LABELS[time_filter]}] "

    scheduled = [c for c in calendar if c.status != "not_scheduled"]
    if not scheduled:
        return notes

    success_n = sum(1 for c in scheduled if c.status == "success")
    fail_n = sum(1 for c in scheduled if c.status == "failure")
    answered = success_n + fail_n
    if answered and time_filter == "all":
        rate = round(100 * success_n / answered)
        notes.append(
            f"{prefix}За период: {rate}% запланированных дней с ответом — "
            f"{'успешные' if pattern.pattern_type == 'positive' else 'чистые'}."
        )

    if failure_sessions and pattern.pattern_mode == "scenario":
        pre_outcome: Counter[tuple[int, str]] = Counter()
        for sess in failure_sessions:
            for ans in sess.answers:
                if not ans.choice_id:
                    continue
                step = steps_by_id.get(ans.step_id)
                if step is None:
                    continue
                if step.step_role in ("choice", "trigger") or step.step_kind == "single_choice":
                    if _choice_is_success(step, ans.choice_id) is False:
                        pre_outcome[(ans.step_id, ans.choice_id)] += 1
        if pre_outcome:
            (step_id, choice_id), cnt = pre_outcome.most_common(1)[0]
            step = steps_by_id.get(step_id)
            label = _choice_label(step, choice_id)
            pct = round(100 * cnt / len(failure_sessions))
            title = step.title if step else "шаг"
            notes.append(f"{prefix}{pct}% срывов — после «{label}» на шаге «{title}».")

    if time_stats:
        worst = max(time_stats, key=lambda s: s.failure_pct)
        if worst.failure_count >= 2 and worst.failure_pct >= 40:
            notes.append(
                f"{prefix}{worst.failure_pct}% событий-срывов приходится на {worst.label.lower()} "
                f"({worst.failure_count} из {worst.total_events})."
            )

    if pattern.pattern_mode == "markers" and marker_events:
        bad = [e for e in marker_events if e[1]]
        if bad:
            by_bucket: Counter[str] = Counter()
            for dt, _ in bad:
                by_bucket[_time_bucket(_local_hour(dt, tz))] += 1
            bucket, cnt = by_bucket.most_common(1)[0]
            pct = round(100 * cnt / len(bad))
            notes.append(
                f"{prefix}{pct}% негативных отметок — в {TIME_BUCKET_LABELS[bucket].lower()}."
            )

    if fail_n >= 3 and time_filter == "all":
        wd_fail = sum(
            1
            for c in calendar
            if c.status == "failure" and date.fromisoformat(c.day).weekday() < 5
        )
        we_fail = fail_n - wd_fail
        if we_fail > wd_fail and we_fail >= 2:
            notes.append("Чаще срывы в выходные — проверьте расписание напоминаний.")
        elif wd_fail > we_fail * 1.5 and wd_fail >= 2:
            notes.append("Больше срывов в будни — возможно, стрессовые триггеры в рабочие дни.")

    if pattern.pattern_mode == "habit" and choice_stats:
        bad = [c for c in choice_stats if c.is_success is False and c.count > 0]
        if bad:
            top = max(bad, key=lambda c: c.count)
            if answered:
                pct = round(100 * top.count / answered)
                notes.append(f"{prefix}Частый ответ при срыве: «{top.label}» ({pct}% дней с ответом).")

    return notes


async def build_pattern_insights(
    session: AsyncSession,
    pattern: BehaviorPattern,
    days: int,
    user_id: int,
    time_filter: TimeFilter = "all",
) -> PatternInsightsRead:
    today = date.today()
    start = today - timedelta(days=days - 1)
    user_tz = await _user_tz(session, user_id)
    steps_by_id = {s.id: s for s in pattern.steps}
    step_order = sorted(pattern.steps, key=lambda s: s.sort_order)

    sessions: dict[date, PatternDaySession] = {}
    completed_sessions: list[PatternDaySession] = []
    if pattern.pattern_mode == "scenario":
        res = await session.execute(
            select(PatternDaySession)
            .options(selectinload(PatternDaySession.answers))
            .where(
                PatternDaySession.pattern_id == pattern.id,
                PatternDaySession.session_date >= start,
                PatternDaySession.session_date <= today,
            )
        )
        for sess in res.scalars():
            sessions[sess.session_date] = sess
            if sess.status == "completed":
                completed_sessions.append(sess)

    calendar = await _build_calendar_batch(session, pattern, start, today, sessions)

    scheduled_days = sum(1 for c in calendar if c.status != "not_scheduled")
    success_days = sum(1 for c in calendar if c.status == "success")
    clean_rate = round(success_days / scheduled_days, 4) if scheduled_days else 0.0

    choice_stats: list[PatternChoiceStat] = []
    top_paths: list[PatternPathStat] = []
    hourly: Counter[int] = Counter()
    hourly_bad: Counter[int] = Counter()
    time_events: list[tuple[datetime, bool]] = []
    marker_events: list[tuple[datetime, bool]] = []
    failure_sessions: list[PatternDaySession] = []

    if pattern.pattern_mode == "habit":
        start_dt = datetime.combine(start, datetime.min.time()).replace(tzinfo=timezone.utc)
        res = await session.execute(
            select(PatternLog, PatternResponseOption)
            .join(
                PatternResponseOption,
                PatternResponseOption.id == PatternLog.response_option_id,
            )
            .where(
                PatternLog.pattern_id == pattern.id,
                PatternLog.status == "answered",
                PatternLog.scheduled_at >= start_dt,
            )
        )
        counts: Counter[tuple[int, str, str, bool]] = Counter()
        for log, opt in res.all():
            ts = log.answered_at or log.scheduled_at
            if not _in_time_filter(ts, time_filter, user_tz):
                continue
            day = log.scheduled_at.date()
            if day < start or day > today:
                continue
            counts[(0, "Ответ дня", opt.label, opt.is_success)] += 1
            time_events.append((ts, not opt.is_success))
        total = sum(counts.values()) or 1
        for (_, step_title, label, is_success), cnt in counts.most_common():
            choice_stats.append(
                PatternChoiceStat(
                    step_id=0,
                    step_title=step_title,
                    choice_id=label,
                    label=label,
                    count=cnt,
                    pct=round(100 * cnt / total, 1),
                    is_success=is_success,
                )
            )

    elif pattern.pattern_mode == "markers":
        start_dt = datetime.combine(start, datetime.min.time()).replace(tzinfo=timezone.utc)
        res = await session.execute(
            select(PatternMarker, PatternResponseOption)
            .join(
                PatternResponseOption,
                PatternResponseOption.id == PatternMarker.marker_option_id,
            )
            .where(
                PatternMarker.pattern_id == pattern.id,
                PatternMarker.occurred_at >= start_dt,
            )
            .order_by(PatternMarker.occurred_at.desc())
        )
        counts: Counter[tuple[str, bool]] = Counter()
        for marker, opt in res.all():
            if not _in_time_filter(marker.occurred_at, time_filter, user_tz):
                continue
            h = _local_hour(marker.occurred_at, user_tz)
            hourly[h] += 1
            is_bad = not opt.is_success
            if is_bad:
                hourly_bad[h] += 1
            marker_events.append((marker.occurred_at, is_bad))
            time_events.append((marker.occurred_at, is_bad))
            counts[(opt.label, opt.is_success)] += 1
        total = sum(counts.values()) or 1
        for (label, is_success), cnt in counts.most_common():
            choice_stats.append(
                PatternChoiceStat(
                    step_id=0,
                    step_title="Отметки",
                    choice_id=label,
                    label=label,
                    count=cnt,
                    pct=round(100 * cnt / total, 1),
                    is_success=is_success,
                )
            )

    else:
        filtered_completed = []
        for sess in completed_sessions:
            ts = _session_event_time(sess)
            if ts is None:
                continue
            if not _in_time_filter(ts, time_filter, user_tz):
                continue
            filtered_completed.append(sess)
            is_fail = not bool(sess.outcome_success)
            time_events.append((ts, is_fail))

        failure_sessions = [s for s in filtered_completed if not s.outcome_success]
        choice_counts: Counter[tuple[int, str]] = Counter()
        path_counts: Counter[tuple[str, bool]] = Counter()

        for sess in filtered_completed:
            parts: list[str] = []
            for step in step_order:
                if step.step_kind != "single_choice":
                    continue
                ans = next((a for a in sess.answers if a.step_id == step.id), None)
                if ans and ans.choice_id:
                    label = _choice_label(step, ans.choice_id)
                    parts.append(label)
                    choice_counts[(step.id, ans.choice_id)] += 1
            if parts:
                path = " → ".join(parts)
                path_counts[(path, bool(sess.outcome_success))] += 1

        per_step_total: dict[int, int] = defaultdict(int)
        for (step_id, _), cnt in choice_counts.items():
            per_step_total[step_id] += cnt

        for (step_id, choice_id), cnt in choice_counts.most_common():
            step = steps_by_id.get(step_id)
            total = per_step_total[step_id] or 1
            choice_stats.append(
                PatternChoiceStat(
                    step_id=step_id,
                    step_title=step.title if step else f"Шаг {step_id}",
                    choice_id=choice_id,
                    label=_choice_label(step, choice_id),
                    count=cnt,
                    pct=round(100 * cnt / total, 1),
                    is_success=_choice_is_success(step, choice_id),
                )
            )

        total_paths = sum(path_counts.values()) or 1
        for (path, is_success), cnt in path_counts.most_common(5):
            top_paths.append(
                PatternPathStat(
                    path=path,
                    count=cnt,
                    pct=round(100 * cnt / total_paths, 1),
                    is_success=is_success,
                )
            )

    hourly_counts = [
        PatternHourStat(hour=h, count=hourly[h], bad_count=hourly_bad[h])
        for h in sorted(hourly.keys())
    ]
    time_of_day_stats = _build_time_stats(time_events, user_tz)
    diary_correlation = await _build_diary_correlation(
        session, user_id, calendar, start, today
    )
    if diary_correlation.insight:
        pass  # appended below via notes merge

    insights = _build_insight_notes(
        pattern,
        calendar,
        choice_stats,
        failure_sessions,
        steps_by_id,
        time_filter,
        time_of_day_stats,
        marker_events,
        user_tz,
    )
    if diary_correlation.insight:
        insights.append(diary_correlation.insight)

    return PatternInsightsRead(
        pattern_id=pattern.id,
        days=days,
        time_filter=time_filter,
        scheduled_days=scheduled_days,
        success_days=success_days,
        clean_rate=clean_rate,
        calendar=calendar,
        choice_breakdown=choice_stats,
        top_paths=top_paths,
        hourly_counts=hourly_counts,
        time_of_day_stats=time_of_day_stats,
        diary_correlation=diary_correlation,
        insights=insights,
    )
