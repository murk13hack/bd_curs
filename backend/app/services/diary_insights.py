"""Сводка «Дневник и связи» для статистики."""

from __future__ import annotations

from datetime import date
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

MOOD_BUCKET_LABELS = {
    "low": "Настроение 1–2",
    "mid": "Настроение 3",
    "high": "Настроение 4–5",
}


def _interpret_corr(value: float | None, x: str, y: str) -> str | None:
    if value is None:
        return None
    r = round(value, 2)
    if abs(r) < 0.2:
        return (
            f"Связь «{x}» и «{y}» за период слабая (r={r}): "
            "показатели почти не двигаются вместе или мало разных дней."
        )
    strength = "заметная" if abs(r) >= 0.45 else "умеренная"
    if r > 0:
        return (
            f"{strength.capitalize()} положительная связь «{x}» ↔ «{y}» (r={r}): "
            "в дни с более высоким первым показателем второй тоже выше."
        )
    return (
        f"{strength.capitalize()} отрицательная связь «{x}» ↔ «{y}» (r={r}): "
        "при росте одного второй чаще ниже."
    )


def _bucket_insight(buckets: list[dict[str, Any]]) -> str | None:
    by_key = {b["bucket"]: b for b in buckets}
    low = by_key.get("low")
    high = by_key.get("high")
    if not low or not high or low["days"] < 2 or high["days"] < 2:
        return None
    lt = low.get("avg_task_rate")
    ht = high.get("avg_task_rate")
    if lt is not None and ht is not None and ht - lt >= 12:
        return (
            f"В дни с настроением 4–5 выполнено {ht:.0f}% задач (среднее), "
            f"с настроением 1–2 — {lt:.0f}%."
        )
    lp = low.get("avg_pattern_rate")
    hp = high.get("avg_pattern_rate")
    if lp is not None and hp is not None and hp - lp >= 12:
        return (
            f"При настроении 4–5 «чистых» дней паттернов {hp:.0f}%, "
            f"при 1–2 — {lp:.0f}%."
        )
    return None


async def fetch_diary_insights(
    session: AsyncSession,
    user_id: int,
    date_from: date,
    date_to: date,
) -> dict[str, Any]:
    period_sql = text(
        "SELECT "
        " COUNT(*) FILTER (WHERE mood IS NOT NULL)::INT AS diary_days,"
        " corr(mood::numeric,"
        "   CASE WHEN tasks_total > 0 THEN 100.0 * tasks_done / tasks_total END)"
        "   AS corr_mood_tasks,"
        " corr(mood::numeric,"
        "   CASE WHEN patterns_scheduled > 0"
        "     THEN 100.0 * patterns_success / patterns_scheduled END)"
        "   AS corr_mood_patterns,"
        " corr(energy::numeric,"
        "   CASE WHEN tasks_total > 0 THEN 100.0 * tasks_done / tasks_total END)"
        "   AS corr_energy_tasks,"
        " corr(mood::numeric, energy::numeric) AS corr_mood_energy "
        "FROM v_olap_daily_facts "
        "WHERE user_id = :uid AND day BETWEEN :f AND :t AND mood IS NOT NULL"
    )
    period_row = (
        await session.execute(
            period_sql.bindparams(uid=user_id, f=date_from, t=date_to)
        )
    ).one()

    bucket_sql = text(
        "SELECT "
        " CASE WHEN mood <= 2 THEN 'low' WHEN mood = 3 THEN 'mid' ELSE 'high' END"
        "   AS bucket,"
        " COUNT(*)::INT AS days,"
        " AVG(CASE WHEN tasks_total > 0"
        "     THEN 100.0 * tasks_done / tasks_total END)::NUMERIC(5,2)"
        "   AS avg_task_rate,"
        " AVG(CASE WHEN patterns_scheduled > 0"
        "     THEN 100.0 * patterns_success / patterns_scheduled END)::NUMERIC(5,2)"
        "   AS avg_pattern_rate "
        "FROM v_olap_daily_facts "
        "WHERE user_id = :uid AND day BETWEEN :f AND :t AND mood IS NOT NULL "
        "GROUP BY 1 ORDER BY 1"
    )
    bucket_rows = (
        await session.execute(
            bucket_sql.bindparams(uid=user_id, f=date_from, t=date_to)
        )
    ).all()

    scatter_sql = text(
        "SELECT day, mood, energy,"
        " CASE WHEN tasks_total > 0 THEN 100.0 * tasks_done / tasks_total END,"
        " CASE WHEN patterns_scheduled > 0"
        "   THEN 100.0 * patterns_success / patterns_scheduled END "
        "FROM v_olap_daily_facts "
        "WHERE user_id = :uid AND day BETWEEN :f AND :t AND mood IS NOT NULL "
        "ORDER BY day"
    )
    scatter_rows = (
        await session.execute(
            scatter_sql.bindparams(uid=user_id, f=date_from, t=date_to)
        )
    ).all()

    weeks_sql = text(
        "SELECT week_start, avg_mood, avg_energy, avg_task_rate,"
        " avg_pattern_clean_rate, avg_minutes,"
        " corr_mood_tasks, corr_mood_patterns, corr_energy_tasks, days_count "
        "FROM v_mood_holistic_correlation "
        "WHERE user_id = :uid AND week_start >= :f AND week_start <= :t "
        "ORDER BY week_start"
    )
    week_rows = (
        await session.execute(
            weeks_sql.bindparams(uid=user_id, f=date_from, t=date_to)
        )
    ).all()

    strict_sql = text(
        "SELECT corr(mood::numeric, rate) AS corr_mood_tasks_strict,"
        " COUNT(*)::INT AS strict_days "
        "FROM ("
        "  SELECT de.mood, td.rate "
        "  FROM diary_entries de "
        "  JOIN ("
        "    SELECT user_id, deadline::date AS day,"
        "      CASE WHEN COUNT(*) = 0 THEN NULL"
        "        ELSE 100.0 * COUNT(*) FILTER (WHERE status = 'done') / COUNT(*)"
        "      END AS rate "
        "    FROM tasks WHERE deadline IS NOT NULL "
        "    GROUP BY user_id, deadline::date"
        "  ) td ON td.user_id = de.user_id AND td.day = de.entry_date "
        "  WHERE de.user_id = :uid"
        "    AND de.entry_date BETWEEN :f AND :t"
        "    AND de.mood IS NOT NULL"
        ") j"
    )
    strict_row = (
        await session.execute(
            strict_sql.bindparams(uid=user_id, f=date_from, t=date_to)
        )
    ).one()

    def _f(v: Any) -> float | None:
        return float(v) if v is not None else None

    diary_days = int(period_row[0] or 0)
    corr_mood_tasks = _f(period_row[1])
    corr_mood_patterns = _f(period_row[2])
    corr_energy_tasks = _f(period_row[3])
    corr_mood_energy = _f(period_row[4])
    strict_corr = _f(strict_row[0])
    strict_days = int(strict_row[1] or 0)

    buckets = [
        {
            "bucket": r[0],
            "label": MOOD_BUCKET_LABELS.get(r[0], r[0]),
            "days": r[1],
            "avg_task_rate": _f(r[2]),
            "avg_pattern_rate": _f(r[3]),
        }
        for r in bucket_rows
    ]

    insights: list[str] = []
    if diary_days < 3:
        insights.append(
            f"За период только {diary_days} дн. с настроением в дневнике — "
            "для связей нужно 5–7+ записей в разные дни."
        )
    else:
        for line in (
            _interpret_corr(corr_mood_tasks, "настроение", "% задач"),
            _interpret_corr(corr_mood_patterns, "настроение", "% паттернов"),
            _interpret_corr(corr_energy_tasks, "энергия", "% задач"),
            _interpret_corr(corr_mood_energy, "настроение", "энергия"),
        ):
            if line:
                insights.append(line)
        bucket_line = _bucket_insight(buckets)
        if bucket_line:
            insights.append(bucket_line)
        if strict_days >= 3 and strict_corr is not None:
            insights.append(
                "Уточнение: в дни с записью дневника и задачами с дедлайном в тот же день "
                f"корреляция настроение↔выполнение r={strict_corr:.2f} "
                f"({strict_days} дн.)."
            )

    if not insights:
        insights.append(
            "Ведите дневник (настроение/энергия) и отмечайте задачи и паттерны — "
            "тогда появятся выводы о связях."
        )

    return {
        "date_from": date_from.isoformat(),
        "date_to": date_to.isoformat(),
        "diary_days": diary_days,
        "corr_mood_tasks": corr_mood_tasks,
        "corr_mood_patterns": corr_mood_patterns,
        "corr_energy_tasks": corr_energy_tasks,
        "corr_mood_energy": corr_mood_energy,
        "corr_mood_tasks_same_day": strict_corr,
        "same_day_diary_task_days": strict_days,
        "mood_buckets": buckets,
        "insights": insights,
        "scatter_days": [
            {
                "day": r[0].isoformat(),
                "mood": float(r[1]),
                "energy": float(r[2]) if r[2] is not None else None,
                "task_rate": _f(r[3]),
                "pattern_rate": _f(r[4]),
            }
            for r in scatter_rows
        ],
        "weeks": [
            {
                "week_start": r[0],
                "avg_mood": _f(r[1]),
                "avg_energy": _f(r[2]),
                "avg_task_rate": _f(r[3]),
                "avg_pattern_clean_rate": _f(r[4]),
                "avg_minutes": _f(r[5]),
                "corr_mood_tasks": _f(r[6]),
                "corr_mood_patterns": _f(r[7]),
                "corr_energy_tasks": _f(r[8]),
                "days_count": r[9],
            }
            for r in week_rows
        ],
    }
