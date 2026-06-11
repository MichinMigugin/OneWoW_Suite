#!/usr/bin/env python3
"""Pre-commit hook: forbid lifecycle WoW event registration in orchestrated units.

Orchestrated OneWoW load units (feature modules, data stores, sub-modules) must
not RegisterEvent ADDON_LOADED, PLAYER_LOGIN, or PLAYER_ENTERING_WORLD for
lifecycle dispatch — core drives those via OnAddonLoaded / OnPlayerLogin /
OnPlayerEnteringWorld (see OneWoW/Docs/ARCHITECTURE.md §3.3, §3.7).

Allowed registrars: OneWoW/OneWoW.lua, embedded Libs/ (excluded by
pre-commit). Gameplay events (PLAYER_ALIVE, BAG_UPDATE, …) are fine.

Escape hatch: -- noqa: lifecycle on the offending line.
"""

from __future__ import annotations

import re
import sys

LIFECYCLE_EVENTS = ("ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD")

ALLOWED_FILES = frozenset(
    {
        "OneWoW/OneWoW.lua",
    }
)

SKIP_PREFIXES = ("OneWoW_Utility_DevTool/",)

SKIP_CONTAINS = ("/Locales/", "\\Locales\\")

LOADER_MARKERS = ("EnsureLoaded(", "WithAddon(", "DoesAddOnExist(", "IsAddOnLoaded(")

DIRECT_REGISTER_RE = re.compile(
    r"""\.RegisterEvent\s*\(\s*["'](ADDON_LOADED|PLAYER_LOGIN|PLAYER_ENTERING_WORLD)["']"""
)

EVENT_REGISTRY_RE = re.compile(
    r"""RegisterFrameEventAndCallback\s*\(\s*["'](ADDON_LOADED|PLAYER_LOGIN|PLAYER_ENTERING_WORLD)["']"""
)

LIFECYCLE_STRING_RE = re.compile(
    r"""["'](ADDON_LOADED|PLAYER_LOGIN|PLAYER_ENTERING_WORLD)["']"""
)


def normalize_path(path: str) -> str:
    return path.replace("\\", "/").lstrip("./")


def in_scope(path: str) -> bool:
    norm = normalize_path(path)
    if norm in ALLOWED_FILES:
        return False
    if any(norm.startswith(p) for p in SKIP_PREFIXES):
        return False
    if any(s in norm for s in SKIP_CONTAINS):
        return False
    top = norm.split("/", 1)[0]
    return top == "OneWoW" or top.startswith("OneWoW_")


def strip_code(line: str, state: str) -> tuple[str, str]:
    """Return (code-only line, carry-over state), removing comments and strings."""
    out: list[str] = []
    i, n = 0, len(line)
    while i < n:
        two = line[i : i + 2]
        if state == "normal":
            if line[i : i + 4] == "--[[":
                state = "block"
                i += 4
            elif two == "--":
                break
            elif two == "[[":
                state = "long"
                i += 2
            elif line[i] == '"':
                state = "dq"
                i += 1
            elif line[i] == "'":
                state = "sq"
                i += 1
            else:
                out.append(line[i])
                i += 1
        elif state in ("dq", "sq"):
            if line[i] == "\\":
                i += 2
            elif (state == "dq" and line[i] == '"') or (state == "sq" and line[i] == "'"):
                state = "normal"
                i += 1
            else:
                i += 1
        else:
            if two == "]]":
                state = "normal"
                i += 2
            else:
                i += 1
    if state in ("dq", "sq"):
        state = "normal"
    return "".join(out), state


def is_loader_reference(code: str) -> bool:
    return any(marker in code for marker in LOADER_MARKERS)


def has_noqa_lifecycle(raw_line: str) -> bool:
    if "--" not in raw_line:
        return False
    comment = raw_line.split("--", 1)[1]
    return "noqa: lifecycle" in comment


def check_file(path: str) -> list[tuple[int, str, str]]:
    """Return list of (lineno, event_name, kind) violations."""
    if not in_scope(path):
        return []

    try:
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
    except (OSError, UnicodeDecodeError) as e:
        print(f"{path}: error reading file: {e}", file=sys.stderr)
        return []

    stripped_lines: list[str] = []
    state = "normal"
    for raw in lines:
        code, state = strip_code(raw, state)
        stripped_lines.append(code)

    file_has_register = any("RegisterEvent" in line for line in stripped_lines)

    violations: list[tuple[int, str, str]] = []
    state = "normal"
    for lineno, (raw, code) in enumerate(zip(lines, stripped_lines), 1):
        if has_noqa_lifecycle(raw):
            continue

        m = DIRECT_REGISTER_RE.search(code)
        if m:
            violations.append((lineno, m.group(1), "RegisterEvent"))
            continue

        m = EVENT_REGISTRY_RE.search(code)
        if m:
            violations.append((lineno, m.group(1), "RegisterFrameEventAndCallback"))
            continue

        if file_has_register and LIFECYCLE_STRING_RE.search(code):
            if not is_loader_reference(code):
                event = LIFECYCLE_STRING_RE.search(code)
                if event:
                    violations.append((lineno, event.group(1), "lifecycle string in event table"))

    return violations


def main(argv: list[str]) -> int:
    rc = 0
    for path in argv[1:]:
        for lineno, event, kind in check_file(path):
            print(f"{path}:{lineno}: forbidden lifecycle event {event!r} ({kind})")
            rc = 1

    if rc:
        print()
        print("Orchestrated units must chain lifecycle through core dispatch:")
        print("  OnAddonLoaded / OnPlayerLogin / OnPlayerEnteringWorld")
        print("  RegisterLoginHandler / RegisterEnteringWorldHandler")
        print("  BootStore onEnteringWorld for data stores")
        print("Gameplay events (PLAYER_ALIVE, BAG_UPDATE, …) may still use RegisterEvent.")
        print("Reference: OneWoW/Docs/ARCHITECTURE.md §3.7")
        print("            .cursor/rules/OneWoW-Suite-Architecture.mdc")
        print("Suppress (rare): add -- noqa: lifecycle on the line.")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
