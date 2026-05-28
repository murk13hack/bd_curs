#!/usr/bin/env python3
"""Рисунки 9 и 14 — PNG без mermaid (Pillow)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "diagrams" / "png"


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for n in ("arial.ttf", "segoeui.ttf", "calibri.ttf"):
        try:
            return ImageFont.truetype(n, size)
        except OSError:
            continue
    return ImageFont.load_default()


def draw_box(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int, int, int],
    title: str,
    lines: list[str],
    fill: str = "#f8fafc",
    outline: str = "#1e293b",
) -> None:
    draw.rounded_rectangle(xy, radius=8, fill=fill, outline=outline, width=2)
    x0, y0, x1, y1 = xy
    f_t = font(14)
    f_b = font(11)
    draw.text((x0 + 10, y0 + 8), title, fill="#0f172a", font=f_t)
    y = y0 + 32
    for line in lines:
        draw.text((x0 + 10, y), line, fill="#334155", font=f_b)
        y += 16


def olap_star(path: Path) -> None:
    w, h = 1600, 1100
    img = Image.new("RGB", (w, h), "white")
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2 - 40

    sources: list[tuple[tuple[int, int, int, int], str, list[str]]] = [
        ((cx - 420, cy - 220, cx - 220, cy - 120), "tasks", ["deadline::date", "tasks_total, tasks_done"]),
        ((cx + 220, cy - 220, cx + 420, cy - 120), "diary_entries", ["mood, energy", "mood_bucket"]),
        ((cx - 480, cy + 120, cx - 280, cy + 220), "pattern_logs", ["слоты habit", "scheduled / success"]),
        ((cx + 300, cy + 120, cx + 500, cy + 220), "pattern_markers", ["эпизоды markers"]),
        ((cx - 80, cy + 280, cx + 120, cy + 380), "pattern_day_sessions", ["сценарий за день"]),
        ((cx + 380, cy - 20, cx + 580, cy + 80), "task_time_logs", ["minutes_logged", "pomodoro_minutes"]),
    ]
    for rect, title, lines in sources:
        draw_box(draw, rect, title, lines)

    fact = (cx - 200, cy - 70, cx + 200, cy + 90)
    draw_box(
        draw,
        fact,
        "v_olap_daily_facts",
        ["Зерно: пользователь × день", "центр звезды"],
        fill="#dcfce7",
        outline="#166534",
    )

    fc = ((fact[0] + fact[2]) // 2, (fact[1] + fact[3]) // 2)
    for rect, _title, _lines in sources:
        bc = ((rect[0] + rect[2]) // 2, (rect[1] + rect[3]) // 2)
        draw.line([bc, fc], fill="#64748b", width=2)

    draw_box(
        draw,
        (cx - 180, cy + 360, cx + 180, cy + 450),
        "Измерения при срезе",
        ["week, month, weekday, day", "фильтры mood/energy_bucket"],
        fill="#eff6ff",
    )
    draw.line([(fc[0], fact[3]), (cx, cy + 360)], fill="#64748b", width=2)

    draw.text(
        (40, 30),
        "Рисунок 9 — Зерно OLAP и источники фактов (схема «звезда»)",
        fill="#0f172a",
        font=font(18),
    )
    img.save(path, "PNG")
    print(f"OK {path}")


def deploy_compose(path: Path) -> None:
    w, h = 1400, 900
    img = Image.new("RGB", (w, h), "white")
    draw = ImageDraw.Draw(img)
    draw.text(
        (40, 30),
        "Рисунок 14 — Развёртывание системы ПТТ (Docker Compose)",
        fill="#0f172a",
        font=font(18),
    )

    user = (80, 120, 260, 200)
    draw.ellipse(user, fill="#e0e7ff", outline="#3730a3", width=2)
    draw.text((user[0] + 55, user[1] + 28), "Пользователь", fill="#1e1b4b", font=font(13))

    fe = (420, 280, 620, 380)
    be = (420, 420, 620, 520)
    db = (420, 560, 620, 700)
    vol = (680, 600, 900, 680)

    draw_box(draw, fe, "frontend", ["React + nginx", "порт :80"])
    draw_box(draw, be, "backend", ["FastAPI", "порт :8000"])
    draw_box(
        draw,
        db,
        "db",
        ["PostgreSQL 16", "порт :5432"],
        fill="#fef3c7",
        outline="#b45309",
    )
    draw_box(draw, vol, "volume pgdata", ["/var/lib/postgresql/data"], fill="#f1f5f9")

    draw.text((300, 250), "сеть ptt-net", fill="#64748b", font=font(12))
    draw.rectangle((350, 260, 660, 720), outline="#94a3b8", width=2)

    draw.line([(user[2], (user[1] + user[3]) // 2), (fe[0], (fe[1] + fe[3]) // 2)], fill="#334155", width=2)
    draw.polygon(
        [(fe[0] - 8, (fe[1] + fe[3]) // 2 - 5), (fe[0], (fe[1] + fe[3]) // 2), (fe[0] - 8, (fe[1] + fe[3]) // 2 + 5)],
        fill="#334155",
    )
    draw.text((280, 230), "HTTP", fill="#334155", font=font(11))

    for a, b, label, yoff in [
        (fe, be, "REST /api/v1", 0),
        (be, db, "TCP 5432", 0),
    ]:
        draw.line(
            [((a[0] + a[2]) // 2, a[3]), ((b[0] + b[2]) // 2, b[1])],
            fill="#334155",
            width=2,
        )
        draw.text(((a[0] + a[2]) // 2 + 10, (a[3] + b[1]) // 2 + yoff), label, fill="#334155", font=font(11))

    draw.line([(db[2], (db[1] + db[3]) // 2), (vol[0], (vol[1] + vol[3]) // 2)], fill="#64748b", width=2)

    draw_box(
        draw,
        (680, 280, 1050, 360),
        "db/init → docker-entrypoint-initdb.d",
        ["скрипты при первом запуске контейнера db"],
        fill="#f8fafc",
    )
    draw.line([(db[2], db[1] + 20), (865, 360)], fill="#94a3b8", width=1)

    img.save(path, "PNG")
    print(f"OK {path}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    olap_star(OUT / "09-olap-star.png")
    deploy_compose(OUT / "14-deploy-compose.png")


if __name__ == "__main__":
    main()
