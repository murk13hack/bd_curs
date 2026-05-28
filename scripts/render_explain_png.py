#!/usr/bin/env python3
"""Рисунки 11–13: EXPLAIN из benchmark_explain_out.txt → PNG (моноширинный текст)."""
from __future__ import annotations

import re
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as e:
    raise SystemExit("pip install pillow") from e

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "docs" / "benchmark_explain_out.txt"
OUT = ROOT / "docs" / "diagrams" / "png"

JOBS: list[tuple[str, list[tuple[str, str | None]]]] = [
    ("11-explain-q1-calendar.png", [(r"========== Q1 \|", r"========== Q3 \|")]),
    (
        "12-explain-q2a-q2b-diary.png",
        [
            (r"========== Q2a \|", r"========== Q2b \|"),
            (r"========== Q2b \|", None),
        ],
    ),
    ("13-explain-q3-tasks-index.png", [(r"========== Q3 \|", r"========== Q4 \|")]),
]

FONT_SIZE = 13
LINE_SPACING = 4
PAD = 24
MAX_WIDTH = 1400


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in ("cour.ttf", "courbd.ttf", "Consolas.ttf", "lucon.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def extract_block(text: str, start_pat: str, end_pat: str | None) -> str:
    m = re.search(start_pat, text)
    if not m:
        raise ValueError(f"Не найден блок: {start_pat}")
    start = m.start()
    if end_pat:
        m2 = re.search(end_pat, text[m.end() :])
        end = m.end() + m2.start() if m2 else len(text)
    else:
        end = len(text)
    return text[start:end].strip()


def wrap_line(draw: ImageDraw.ImageDraw, line: str, font, max_px: int) -> list[str]:
    if not line.strip():
        return [""]
    words = line.split(" ")
    lines: list[str] = []
    cur = ""
    for w in words:
        test = f"{cur} {w}".strip()
        if draw.textlength(test, font=font) <= max_px:
            cur = test
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines or [""]


def render_text_png(text: str, path: Path) -> None:
    font = load_font(FONT_SIZE)
    dummy = Image.new("RGB", (1, 1))
    draw = ImageDraw.Draw(dummy)
    max_text = MAX_WIDTH - 2 * PAD
    wrapped: list[str] = []
    for raw in text.splitlines():
        wrapped.extend(wrap_line(draw, raw.replace("\t", "    "), font, max_text))

    line_h = FONT_SIZE + LINE_SPACING
    h = PAD * 2 + line_h * len(wrapped)
    w = MAX_WIDTH
    img = Image.new("RGB", (w, h), "white")
    draw = ImageDraw.Draw(img)
    y = PAD
    for line in wrapped:
        draw.text((PAD, y), line, fill="black", font=font)
        y += line_h
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    print(f"OK {path} ({w}x{h})")


def main() -> None:
    if not SRC.is_file():
        raise SystemExit(f"Нет файла: {SRC}")
    text = SRC.read_text(encoding="utf-8", errors="replace")
    for png_name, spans in JOBS:
        parts = [extract_block(text, start, end) for start, end in spans]
        render_text_png("\n\n".join(parts), OUT / png_name)


if __name__ == "__main__":
    main()
