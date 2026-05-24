"""OLAP-запросы поверх v_olap_daily_facts (whitelist dimensions/measures)."""

from __future__ import annotations

from datetime import date, timedelta
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

DIMENSION_SQL: dict[str, str] = {
    "day": "day",
    "week": "date_trunc('week', day)::date",
    "month": "date_trunc('month', day)::date",
    "weekday": "dow",
    "mood_bucket": "mood_bucket",
    "energy_bucket": "energy_bucket",
}

DIMENSION_LABELS: dict[str, str] = {
    "day": "День",
    "week": "Неделя",
    "month": "Месяц",
    "weekday": "День недели",
    "mood_bucket": "Настроение",
    "energy_bucket": "Энергия",
}

WEEKDAY_LABELS = {1: "Пн", 2: "Вт", 3: "Ср", 4: "Чт", 5: "Пт", 6: "Сб", 7: "Вс"}

MOOD_LABELS = {"none": "—", "low": "1–2", "mid": "3", "high": "4–5"}

MEASURE_SQL: dict[str, str] = {
    "tasks_total": "SUM(tasks_total)",
    "tasks_done": "SUM(tasks_done)",
    "tasks_overdue": "SUM(tasks_overdue)",
    "completion_rate": (
        "CASE WHEN SUM(tasks_total) = 0 THEN 0 "
        "ELSE ROUND(100.0 * SUM(tasks_done) / SUM(tasks_total), 2) END"
    ),
    "minutes_logged": "SUM(minutes_logged)",
    "pomodoro_minutes": "SUM(pomodoro_minutes)",
    "diary_entries": "SUM(diary_entries)",
    "avg_mood": "ROUND(AVG(mood)::numeric, 2)",
    "avg_energy": "ROUND(AVG(energy)::numeric, 2)",
    "patterns_scheduled": "SUM(patterns_scheduled)",
    "patterns_success": "SUM(patterns_success)",
    "pattern_clean_rate": (
        "CASE WHEN SUM(patterns_scheduled) = 0 THEN 0 "
        "ELSE ROUND(100.0 * SUM(patterns_success) / SUM(patterns_scheduled), 2) END"
    ),
    "marker_events": "SUM(marker_events)",
    "marker_bad_events": "SUM(marker_bad_events)",
    "activity_score": "SUM(activity_score)",
    "active_days": "COUNT(DISTINCT day)",
}

MEASURE_LABELS: dict[str, str] = {
    "tasks_total": "Задач всего",
    "tasks_done": "Задач выполнено",
    "tasks_overdue": "Просрочено",
    "completion_rate": "% выполнения задач",
    "minutes_logged": "Минут учтено",
    "pomodoro_minutes": "Минут Pomodoro",
    "diary_entries": "Записей дневника",
    "avg_mood": "Среднее настроение",
    "avg_energy": "Средняя энергия",
    "patterns_scheduled": "Паттернов по расписанию",
    "patterns_success": "Успешных дней паттернов",
    "pattern_clean_rate": "% чистых дней паттернов",
    "marker_events": "Отметок (markers)",
    "marker_bad_events": "Негативных отметок",
    "activity_score": "Суммарная активность",
    "active_days": "Активных дней",
}


def olap_meta() -> dict[str, Any]:
    return {
        "dimensions": [
            {"id": k, "label": DIMENSION_LABELS[k]} for k in DIMENSION_SQL
        ],
        "measures": [{"id": k, "label": MEASURE_LABELS[k]} for k in MEASURE_SQL],
    }


def _format_dim_value(dim: str, val: Any) -> str:
    if val is None:
        return "—"
    if dim == "weekday":
        return WEEKDAY_LABELS.get(int(val), str(val))
    if dim == "mood_bucket":
        return MOOD_LABELS.get(str(val), str(val))
    if dim == "energy_bucket":
        return MOOD_LABELS.get(str(val), str(val))
    return str(val)


async def run_olap_query(
    session: AsyncSession,
    user_id: int,
    dimensions: list[str],
    measures: list[str],
    date_from: date | None,
    date_to: date | None,
    filters: dict[str, str],
) -> dict[str, Any]:
    if not measures:
        raise ValueError("Нужна хотя бы одна мера")
    for d in dimensions:
        if d not in DIMENSION_SQL:
            raise ValueError(f"Неизвестное измерение: {d}")
    for m in measures:
        if m not in MEASURE_SQL:
            raise ValueError(f"Неизвестная мера: {m}")

    if date_to is None:
        date_to = date.today()
    if date_from is None:
        date_from = date_to - timedelta(days=89)

    select_dims = []
    group_dims = []
    for i, dim in enumerate(dimensions):
        alias = f"d{i}"
        expr = DIMENSION_SQL[dim]
        select_dims.append(f"{expr} AS {alias}")
        group_dims.append(expr)

    select_measures = [f"{MEASURE_SQL[m]} AS {m}" for m in measures]

    sql = (
        "SELECT "
        + ", ".join(select_dims + select_measures)
        + " FROM v_olap_daily_facts WHERE user_id = :uid"
        + " AND day >= :df AND day <= :dt"
    )
    params: dict[str, Any] = {"uid": user_id, "df": date_from, "dt": date_to}

    for key, val in filters.items():
        if key in ("mood_bucket", "energy_bucket") and val:
            sql += f" AND {key} = :f_{key}"
            params[f"f_{key}"] = val

    if group_dims:
        sql += " GROUP BY " + ", ".join(group_dims)
        sql += " ORDER BY " + ", ".join(f"d{i}" for i in range(len(dimensions)))

    res = await session.execute(text(sql).bindparams(**params))
    rows = []
    for row in res.fetchall():
        item: dict[str, Any] = {"dimensions": {}, "measures": {}}
        col = 0
        for dim in dimensions:
            raw = row[col]
            item["dimensions"][dim] = raw.isoformat() if hasattr(raw, "isoformat") else raw
            item["dimensions"][f"{dim}_label"] = _format_dim_value(dim, raw)
            col += 1
        for m in measures:
            val = row[col]
            item["measures"][m] = float(val) if val is not None else None
            col += 1
        rows.append(item)

    return {
        "date_from": date_from.isoformat(),
        "date_to": date_to.isoformat(),
        "dimensions": dimensions,
        "measures": measures,
        "rows": rows,
    }


async def fetch_overview(session: AsyncSession, user_id: int, days: int) -> dict[str, Any]:
    date_to = date.today()
    date_from = date_to - timedelta(days=days - 1)
    res = await session.execute(
        text(
            """
            SELECT
                COALESCE(SUM(tasks_total), 0)::INT,
                COALESCE(SUM(tasks_done), 0)::INT,
                COALESCE(SUM(tasks_overdue), 0)::INT,
                CASE WHEN SUM(tasks_total) = 0 THEN 0
                     ELSE ROUND(100.0 * SUM(tasks_done) / SUM(tasks_total), 2) END,
                COALESCE(SUM(minutes_logged), 0)::INT,
                COALESCE(SUM(pomodoro_minutes), 0)::INT,
                COALESCE(SUM(diary_entries), 0)::INT,
                ROUND(AVG(mood)::numeric, 2),
                ROUND(AVG(energy)::numeric, 2),
                COALESCE(SUM(patterns_scheduled), 0)::INT,
                COALESCE(SUM(patterns_success), 0)::INT,
                CASE WHEN SUM(patterns_scheduled) = 0 THEN 0
                     ELSE ROUND(100.0 * SUM(patterns_success) / SUM(patterns_scheduled), 2) END,
                COALESCE(SUM(marker_events), 0)::INT,
                COALESCE(SUM(marker_bad_events), 0)::INT,
                COALESCE(SUM(activity_score), 0)::INT,
                COUNT(DISTINCT day)::INT
            FROM v_olap_daily_facts
            WHERE user_id = :uid AND day >= :df AND day <= :dt
            """
        ).bindparams(uid=user_id, df=date_from, dt=date_to)
    )
    r = res.one()
    return {
        "days": days,
        "date_from": date_from.isoformat(),
        "date_to": date_to.isoformat(),
        "tasks_total": r[0],
        "tasks_done": r[1],
        "tasks_overdue": r[2],
        "task_completion_rate": float(r[3] or 0),
        "minutes_logged": r[4],
        "pomodoro_minutes": r[5],
        "diary_entries": r[6],
        "avg_mood": float(r[7]) if r[7] is not None else None,
        "avg_energy": float(r[8]) if r[8] is not None else None,
        "patterns_scheduled": r[9],
        "patterns_success": r[10],
        "pattern_clean_rate": float(r[11] or 0),
        "marker_events": r[12],
        "marker_bad_events": r[13],
        "activity_score": r[14],
        "active_days": r[15],
    }
