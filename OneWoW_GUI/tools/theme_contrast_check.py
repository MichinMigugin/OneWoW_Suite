#!/usr/bin/env python3
"""
Approximate WCAG 2.x contrast ratios for OneWoW GUI themes.

Reads OneWoW_GUI/Constants.lua, parses THEMES_ORDER and per-theme RGB tokens.
Uses opaque sRGB relative luminance (ignores alpha — same limitation as most web checkers).

Run from repo root:
  python OneWoW_GUI/tools/theme_contrast_check.py

Or from this directory:
  python theme_contrast_check.py
"""

from __future__ import annotations

import math
import re
import sys
from pathlib import Path


def rel_lum(r: float, g: float, b: float) -> float:
    def f(c: float) -> float:
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    R, G, B = f(r), f(g), f(b)
    return 0.2126 * R + 0.7152 * G + 0.0722 * B


def contrast_ratio(rgb1: tuple[float, float, float], rgb2: tuple[float, float, float]) -> float:
    l1 = rel_lum(*rgb1) + 0.05
    l2 = rel_lum(*rgb2) + 0.05
    return max(l1, l2) / min(l1, l2)


def parse_themes_order(text: str) -> list[str]:
    m = re.search(r"THEMES_ORDER\s*=\s*\{([^}]+)\}", text, re.DOTALL)
    if not m:
        raise SystemExit("Could not find THEMES_ORDER in Constants.lua")
    body = m.group(1)
    keys = []
    for part in body.split(","):
        p = part.strip().strip('"').strip("'")
        if p and not p.startswith("--"):
            keys.append(p)
    return keys


def extract_theme_block(text: str, key: str) -> str | None:
    m = re.search(rf"\b{re.escape(key)}\s*=\s*\{{", text)
    if not m:
        return None
    start = m.end() - 1
    depth = 0
    j = start
    while j < len(text):
        c = text[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[start : j + 1]
        j += 1
    return None


def parse_color_vec(block: str, field: str) -> tuple[float, float, float] | None:
    m = re.search(rf"{field}\s*=\s*\{{([^}}]+)\}}", block)
    if not m:
        return None
    nums = []
    for part in m.group(1).split(","):
        part = part.strip()
        if not part:
            continue
        try:
            nums.append(float(part))
        except ValueError:
            continue
    if len(nums) < 3:
        return None
    return nums[0], nums[1], nums[2]


def main() -> int:
    here = Path(__file__).resolve()
    constants = here.parent.parent / "Constants.lua"
    if not constants.is_file():
        print("Expected Constants.lua at", constants, file=sys.stderr)
        return 1

    text = constants.read_text(encoding="utf-8")
    keys = parse_themes_order(text)

    rows: list[tuple[str, float, float, float]] = []
    for key in keys:
        block = extract_theme_block(text, key)
        if not block:
            print(f"skip (no block): {key}", file=sys.stderr)
            continue
        tp = parse_color_vec(block, "TEXT_PRIMARY")
        bg = parse_color_vec(block, "BG_PRIMARY")
        ap = parse_color_vec(block, "ACCENT_PRIMARY")
        bs = parse_color_vec(block, "BG_SECONDARY")
        if not tp or not bg:
            continue
        r1 = contrast_ratio(tp, bg)
        r2 = contrast_ratio(ap, bs) if ap and bs else float("nan")
        rows.append((key, r1, r2, r1 if math.isnan(r2) else min(r1, r2)))

    rows.sort(key=lambda x: x[3])

    print("Theme".ljust(22), "TEXT/BG_PRI".rjust(12), "ACC/BG_SEC".rjust(12), "min".rjust(8))
    print("-" * 58)
    for key, r1, r2, mn in rows:
        r2s = f"{r2:.2f}" if not math.isnan(r2) else "n/a"
        print(f"{key:22}{r1:12.2f}{r2s:>12}{mn:8.2f}")

    print()
    print("Guidance: normal body text often targets WCAG 4.5:1; large text 3:1.")
    print("WoW uses translucent panels; in-game appearance may differ slightly.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
