#!/usr/bin/env python3
"""Pre-commit hook: warn on hardcoded RGB literals in widget color APIs.

Suite UI should use OneWoW_GUI:GetThemeColor(key) for semantic colors, or
documented exceptions in OneWoW/Docs/GUI.md §Colors intentionally not themed.

Flagged APIs (when the call uses numeric RGB literals, not GetThemeColor):
    SetBackdropColor, SetBackdropBorderColor
    SetTextColor, SetVertexColor
    SetColorTexture

Skipped (not violations):
    Lines containing GetThemeColor
    GameTooltip:AddLine / AddDoubleLine (tooltip RGB convention)
    (0, 0, 0, 0) transparent backdrops
    unpack( of a named constant (WOW_QUEST_GOLD, MONOKAI, OVERLAY_DIM, …)
    C_Item.GetItemQualityColor, RAID_CLASS_COLORS, dynamic color variables
    -- noqa: theme-color on the line

Path allowlist (whole trees): OneWoW/GUI/Constants.lua, OneWoW_Utility_DevTool/,
Libs/, .wow_docs/, Tools/, OneWoW_Bags/API/Examples/

Enforcement: WARN_ONLY = True prints [warn] and exits 0. Flip to False to block.
"""

from __future__ import annotations

import os
import re
import sys

WARN_ONLY: bool = True

ALLOWED_PATH_PREFIXES: tuple[str, ...] = (
    "OneWoW/GUI/Constants.lua",
    "OneWoW_Utility_DevTool/",
    "Libs/",
    ".lua-defs/",
    ".wow_docs/",
    ".vscode/",
    ".releases/",
    "OneWoW_Bags/API/Examples/",
    "OneWoW_CatalogData_Quests/Tools/",
)

COLOR_API = re.compile(
    r"\b(?:SetBackdropColor|SetBackdropBorderColor|SetTextColor|SetVertexColor|SetColorTexture)\s*\("
)

# Numeric literal in color position: 0.5, 1, 255/255, etc.
NUMERIC_COLOR = re.compile(
    r"(?:\b0(?:\.\d+)?\b|\b1(?:\.0+)?\b|\d+\s*/\s*\d+)"
)

SKIP_SUBSTRINGS = (
    "GetThemeColor",
    "GameTooltip:AddLine",
    "GameTooltip:AddDoubleLine",
    "C_Item.GetItemQualityColor",
    "RAID_CLASS_COLORS",
    "GetItemQualityColor",
    "noqa: theme-color",
)

TRANSPARENT_BACKDROP = re.compile(
    r"SetBackdropColor\s*\(\s*0\s*,\s*0\s*,\s*0\s*,\s*0\s*\)"
)

UNPACK_CONSTANT = re.compile(
    r"unpack\s*\(\s*(?:OneWoW_GUI\.Constants\.)?"
    r"(?:WOW_QUEST_GOLD|OVERLAY_DIM|ICON_OVERLAY_TEXT|REORDER_BTN_HIGHLIGHT|MONOKAI|GUTTER)",
    re.IGNORECASE,
)


def norm_path(path: str) -> str:
    return path.replace("\\", "/")


def is_allowlisted(path: str) -> bool:
    p = norm_path(path)
    for prefix in ALLOWED_PATH_PREFIXES:
        if p == prefix or p.startswith(prefix):
            return True
    return False


def strip_comments(line: str, in_block: bool) -> tuple[str, bool]:
    if in_block:
        if "]]" in line:
            in_block = False
            line = line.split("]]", 1)[1]
        else:
            return "", in_block

    if "--[[" in line:
        before, after = line.split("--[[", 1)
        if "]]" not in after:
            in_block = True
        line = before

    stripped = line.lstrip()
    if stripped.startswith("--"):
        return "", in_block

    if "--" in line:
        line = line.split("--", 1)[0]

    return line, in_block


def should_skip_line(code: str) -> bool:
    if not code.strip():
        return True
    for sub in SKIP_SUBSTRINGS:
        if sub in code:
            return True
    if TRANSPARENT_BACKDROP.search(code):
        return True
    if UNPACK_CONSTANT.search(code):
        return True
    if not COLOR_API.search(code):
        return True
    if not NUMERIC_COLOR.search(code):
        return True
    # Dynamic variables passed through (e.g. rr, gg, bb from a picker)
    if re.search(
        r"\b(?:SetBackdropColor|SetBackdropBorderColor|SetTextColor|SetVertexColor|SetColorTexture)\s*\(\s*[a-zA-Z_]\w*\s*,",
        code,
    ):
        return True
    return False


def check_file(path: str) -> list[tuple[int, str]]:
    if is_allowlisted(path):
        return []

    violations: list[tuple[int, str]] = []
    in_block = False

    try:
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
    except (OSError, UnicodeDecodeError) as e:
        print(f"{path}: error reading file: {e}", file=sys.stderr)
        return []

    for lineno, line in enumerate(lines, 1):
        code, in_block = strip_comments(line, in_block)
        if should_skip_line(code):
            continue
        violations.append((lineno, line.rstrip()))

    return violations


def main(argv: list[str]) -> int:
    rc = 0
    for path in argv[1:]:
        for lineno, line in check_file(path):
            tag = "warn" if WARN_ONLY else "error"
            print(f"{path}:{lineno}: [{tag}] hardcoded color literal in widget API")
            print(f"    {line}")
            if not WARN_ONLY:
                rc = 1

    if rc:
        print()
        print("Fix: use OneWoW_GUI:GetThemeColor(key) or a documented exception")
        print("(see OneWoW/Docs/GUI.md §Colors intentionally not themed).")
        print("Suppress a one-off line with: -- noqa: theme-color")
    elif any(check_file(p) for p in argv[1:]):
        print()
        print("Theme color bypass check: warnings only (WARN_ONLY=True).")

    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
