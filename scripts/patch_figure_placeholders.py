#!/usr/bin/env python3
"""Подставить единые блоки рисунков 1–13 в KURSOVAYA_BD.md, убрать блоки mermaid."""
from __future__ import annotations

import re
from pathlib import Path

from figure_specs import FIGURES, figure_blockquote

ROOT = Path(__file__).resolve().parents[1]
MD = ROOT / "docs" / "KURSOVAYA_BD.md"


def strip_mermaid(text: str) -> str:
    return re.sub(r"```mermaid\r?\n.*?```\r?\n", "", text, flags=re.DOTALL)


def replace_figure_block(text: str, n: int) -> str:
    spec = FIGURES[n]
    header = f"#### Рисунок {n} — {spec['title']}"
    pattern = re.compile(
        rf"#### Рисунок {n} —[^\n]+\n(?:\n>?[^\n]*\n)*",
        re.MULTILINE,
    )
    replacement = header + "\n\n" + figure_blockquote(n) + "\n\n"
    new, count = pattern.subn(replacement, text, count=1)
    if count != 1:
        raise SystemExit(f"Figure {n}: expected 1 replacement, got {count}")
    return new


def main() -> None:
    text = MD.read_text(encoding="utf-8")
    text = strip_mermaid(text)
    text = re.sub(
        r"Ниже — исходник для генерации \(в печатную версию можно не включать\)\.\s*\n+",
        "Исходник ER — приложение А (`01-er-full.mmd`).\n\n",
        text,
    )
    for n in range(1, 14):
        text = replace_figure_block(text, n)
    MD.write_text(text, encoding="utf-8")
    print(f"Updated {MD}")


if __name__ == "__main__":
    main()
