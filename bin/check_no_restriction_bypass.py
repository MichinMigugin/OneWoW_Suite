#!/usr/bin/env python3
"""Pre-commit hook: forbid direct combat/restriction API calls.

All combat-lockdown and addon-restriction checks must route through the
OneWoW.Restriction funnel — see OneWoW/Docs/ARCHITECTURE.md. Use
`OneWoW.Restriction.IsAddonRestricted()` to gate secure-frame mutations /
protected actions, and `OneWoW.Restriction.IsInCombat()` for combat-only
UX/perf gates (fade, deferral, suppression).

Flagged identifiers (word-boundary, code only — comment/string mentions are
stripped first so docs and syntax tables do not false-positive):
  - InCombatLockdown
  - GetAddOnRestrictionState        (incl. C_RestrictedActions.* form)
  - IsAddOnRestrictionActive        (incl. C_RestrictedActions.* form)

Allowed file (by basename):
  - Restriction.lua — the funnel itself.

Escape hatch: -- noqa: restriction-funnel on the offending line.
"""

from __future__ import annotations

import os
import re
import sys

ALLOWED_BASENAMES = frozenset({"Restriction.lua"})

FORBIDDEN_RE = re.compile(
    r"\b(InCombatLockdown|GetAddOnRestrictionState|IsAddOnRestrictionActive)\b"
)


def normalize_path(path: str) -> str:
    return path.replace("\\", "/").lstrip("./")


def in_scope(path: str) -> bool:
    norm = normalize_path(path)
    if os.path.basename(norm) in ALLOWED_BASENAMES:
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


def has_noqa(raw_line: str) -> bool:
    if "--" not in raw_line:
        return False
    comment = raw_line.split("--", 1)[1]
    return "noqa: restriction-funnel" in comment


def check_file(path: str) -> list[tuple[int, str]]:
    """Return (line number, matched identifier) for each direct restriction call."""
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
        if not code:
            continue
        match = FORBIDDEN_RE.search(code)
        if match and not has_noqa(raw):
            violations.append((lineno, match.group(1)))

    return violations


def main(argv: list[str]) -> int:
    rc = 0
    for path in argv[1:]:
        for lineno, name in check_file(path):
            print(f"{path}:{lineno}: direct {name} bypasses the restriction funnel")
            rc = 1

    if rc:
        print()
        print("Route all combat/restriction checks through OneWoW.Restriction:")
        print("  IsAddonRestricted()  — gate secure-frame mutations / protected actions")
        print("  IsInCombat()         — combat-only UX/perf gates (fade, deferral)")
        print("Reference: OneWoW/Docs/ARCHITECTURE.md")
        print("Suppress (rare): add -- noqa: restriction-funnel on the line.")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
