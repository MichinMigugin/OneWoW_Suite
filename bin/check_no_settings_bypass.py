#!/usr/bin/env python3
"""Pre-commit hook: forbid direct access to the OneWoW settings tree.

All reads/writes of OneWoW.db.global.settings.* must go through
OneWoW.SettingsFeatureRegistry (the settings funnel) — see
OneWoW/Docs/MIGRATION.md step 6. The check matches the suffix pattern
`db.global.settings` so aliased access is caught too
(e.g. `local ow = OneWoW; ow.db.global.settings`).

Allowed files (by basename):
  - SettingsFeatureRegistry.lua — the funnel itself.
  - Database.lua — defaults/migrations own the tree; CatalogData units also
    have their own unrelated `ns.db.global.settings` roots in Core/Database.lua.

Escape hatch: -- noqa: settings-funnel on the offending line.
"""

from __future__ import annotations

import os
import re
import sys

ALLOWED_BASENAMES = frozenset(
    {
        "SettingsFeatureRegistry.lua",
        "Database.lua",
    }
)

SETTINGS_ACCESS_RE = re.compile(r"\bdb\s*\.\s*global\s*\.\s*settings\b")


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
    return "noqa: settings-funnel" in comment


def check_file(path: str) -> list[int]:
    """Return line numbers with direct settings-tree access."""
    if not in_scope(path):
        return []

    try:
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
    except (OSError, UnicodeDecodeError) as e:
        print(f"{path}: error reading file: {e}", file=sys.stderr)
        return []

    violations: list[int] = []
    state = "normal"
    for lineno, raw in enumerate(lines, 1):
        code, state = strip_code(raw, state)
        if not code:
            continue
        if SETTINGS_ACCESS_RE.search(code) and not has_noqa(raw):
            violations.append(lineno)

    return violations


def main(argv: list[str]) -> int:
    rc = 0
    for path in argv[1:]:
        for lineno in check_file(path):
            print(f"{path}:{lineno}: direct db.global.settings access bypasses the settings funnel")
            rc = 1

    if rc:
        print()
        print("Route all settings reads/writes through OneWoW.SettingsFeatureRegistry:")
        print("  IsEnabled / SetEnabled / GetSetting / SetSetting / GetFeatureSettings")
        print("  IsIntegrationEnabled / SetIntegrationEnabled / ResetTab")
        print("Reference: OneWoW/Docs/MIGRATION.md step 6")
        print("Suppress (rare): add -- noqa: settings-funnel on the line.")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
