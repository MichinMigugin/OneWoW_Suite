#!/usr/bin/env python3
"""Pre-commit hook: forbid raw addon loading outside the core loader funnel.

All programmatic addon loading in the suite must go through the loader API —
OneWoW:EnsureLoaded / OneWoW:WithAddon / OneWoW:BringUp — so that soft opt-out,
combat deferral, and lifecycle dispatch are honored on every load path (see
OneWoW/Docs/ARCHITECTURE.md). Raw C_AddOns.LoadAddOn / UIParentLoadAddOn calls
bypass all of that.

Allowed call sites: OneWoW/Core/AddonLoader.lua and OneWoW/Core/Lifecycle.lua
(the funnel itself).

Escape hatch: -- noqa: loadaddon on the offending line.
"""

from __future__ import annotations

import re
import sys

ALLOWED_FILES = frozenset(
    {
        "OneWoW/Core/AddonLoader.lua",
        "OneWoW/Core/Lifecycle.lua",
    }
)

SKIP_CONTAINS = ("/Locales/", "\\Locales\\")

# Bare-name match (no trailing paren) so pcall(C_AddOns.LoadAddOn, ...) and
# other indirect references are caught too.
RAW_LOAD_RE = re.compile(r"\b(C_AddOns\.LoadAddOn|UIParentLoadAddOn)\b")


def normalize_path(path: str) -> str:
    return path.replace("\\", "/").lstrip("./")


def in_scope(path: str) -> bool:
    norm = normalize_path(path)
    if norm in ALLOWED_FILES:
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


def has_noqa_loadaddon(raw_line: str) -> bool:
    if "--" not in raw_line:
        return False
    comment = raw_line.split("--", 1)[1]
    return "noqa: loadaddon" in comment


def check_file(path: str) -> list[tuple[int, str]]:
    """Return list of (lineno, matched_name) violations."""
    if not in_scope(path):
        return []

    try:
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
    except (OSError, UnicodeDecodeError) as e:
        print(f"{path}: error reading file: {e}", file=sys.stderr)
        return []

    violations: list[tuple[int, str]] = []
    state = "normal"
    for lineno, raw in enumerate(lines, 1):
        code, state = strip_code(raw, state)
        if has_noqa_loadaddon(raw):
            continue
        m = RAW_LOAD_RE.search(code)
        if m:
            violations.append((lineno, m.group(1)))

    return violations


def main(argv: list[str]) -> int:
    rc = 0
    for path in argv[1:]:
        for lineno, name in check_file(path):
            print(f"{path}:{lineno}: forbidden raw addon load {name!r}")
            rc = 1

    if rc:
        print()
        print("Load addons through the core loader funnel instead:")
        print("  OneWoW:EnsureLoaded(name)   -- explicit user actions")
        print("  OneWoW:WithAddon(name, fn)  -- load + callback with failure text")
        print("  OneWoW:BringUp(name)        -- mid-session feature bring-up")
        print("Reference: OneWoW/Docs/ARCHITECTURE.md")
        print("Suppress (rare): add -- noqa: loadaddon on the line.")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
