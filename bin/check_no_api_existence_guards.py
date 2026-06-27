#!/usr/bin/env python3
"""Pre-commit hook: forbid defensive Blizzard API / Enum existence guards.

OneWoW targets WoW Retail 12+ only. C_* namespaces, Enum.* tables, and modern
Blizzard globals are guaranteed at load time — do not guard them before use.

Flagged patterns (code only — comments/strings stripped first):
  - C_Foo and C_Foo.Bar          (namespace + member existence chain)
  - not C_Foo or not C_Foo.Bar  (negative existence guard)
  - and C_Foo.Bar then           (method reference used as existence test)
  - local x = C_Foo and C_Foo.Bar
  - Enum and Enum.Table
  - FlagsUtil and FlagsUtil.Method
  - ItemLocation and ItemLocation.Method

Valid (not flagged): value-nil checks before API calls, e.g.
  itemLocation and C_Item.DoesItemExist(itemLocation)

Escape hatch: -- noqa: api-existence-guard on the offending line.

See .cursor/rules/No-Defensive-Guards.mdc.
"""

from __future__ import annotations

import os
import re
import sys

NOQA = "noqa: api-existence-guard"

PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (
        re.compile(r"\bC_\w+\s+and\s+C_\w+\."),
        "C_* namespace/method existence chain",
    ),
    (
        re.compile(r"\bnot\s+C_\w+\s+or\s+not\s+C_\w+\."),
        "negative C_* existence guard",
    ),
    (
        re.compile(r"\band\s+C_\w+\.\w+\s+then\b"),
        "C_* method referenced without call before 'then'",
    ),
    (
        re.compile(r"\blocal\s+\w+\s*=\s*C_\w+\s+and\s+C_\w+\."),
        "guarded C_* local alias",
    ),
    (
        re.compile(r"\bEnum\s+and\s+Enum\."),
        "Enum existence guard",
    ),
    (
        re.compile(r"\bFlagsUtil\s+and\s+FlagsUtil\."),
        "FlagsUtil existence guard",
    ),
    (
        re.compile(r"\bItemLocation\s+and\s+ItemLocation\."),
        "ItemLocation existence guard",
    ),
    (
        re.compile(r"\band\s+C_\w+\s+then\b"),
        "C_* namespace truthiness before 'then'",
    ),
]


def normalize_path(path: str) -> str:
    return path.replace("\\", "/").lstrip("./")


def in_scope(path: str) -> bool:
    norm = normalize_path(path)
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
    return NOQA in comment


def check_file(path: str) -> list[tuple[int, str]]:
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
        if has_noqa(raw):
            continue
        for pattern, label in PATTERNS:
            if pattern.search(code):
                violations.append((lineno, label))
                break

    return violations


def main(argv: list[str]) -> int:
    rc = 0
    for path in argv[1:]:
        for lineno, label in check_file(path):
            print(f"{path}:{lineno}: {label}")
            rc = 1

    if rc:
        print()
        print("Remove defensive API/Enum existence guards on Retail 12+.")
        print("Call C_* / Enum.* directly; nil-check return values when documented.")
        print("Reference: .cursor/rules/No-Defensive-Guards.mdc")
        print(f"Suppress (rare): add -- {NOQA} on the line.")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
