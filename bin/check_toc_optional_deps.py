#!/usr/bin/env python3
"""Pre-commit hook: forbid suite-internal addons in ## OptionalDeps.

Blizzard auto-loads enabled OptionalDeps when the consumer is LoadAddOn'd,
bypassing OneWoW soft opt-out and the login orchestrator. Suite integrations
must use nil-guards and OneWoW:EnsureLoaded / WithAddon instead.

See OneWoW/Docs/ARCHITECTURE.md §2 OptionalDeps policy.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

OPTIONAL_DEPS_RE = re.compile(r"^##\s*OptionalDeps:\s*(.+)$", re.IGNORECASE)
SUITE_INTERNAL_RE = re.compile(r"^OneWoW", re.IGNORECASE)


def parse_optional_deps(line: str) -> list[str]:
    m = OPTIONAL_DEPS_RE.match(line.strip())
    if not m:
        return []
    return [dep.strip() for dep in m.group(1).split(",") if dep.strip()]


def check_toc(path: str) -> list[tuple[str, str]]:
    """Return list of (dep_name, line_text) violations."""
    violations: list[tuple[str, str]] = []
    try:
        text = Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as e:
        print(f"{path}: error reading file: {e}", file=sys.stderr)
        return []

    for line in text.splitlines():
        for dep in parse_optional_deps(line):
            if SUITE_INTERNAL_RE.match(dep):
                violations.append((dep, line.rstrip()))
    return violations


def main(argv: list[str]) -> int:
    rc = 0
    paths = argv[1:]
    if not paths:
        root = Path(__file__).resolve().parent.parent
        paths = [str(p) for p in sorted(root.glob("OneWoW*.toc"))]

    for path in paths:
        norm = path.replace("\\", "/")
        if not norm.endswith(".toc"):
            continue
        for dep, line in check_toc(path):
            print(f"{path}: suite-internal OptionalDep {dep!r}")
            print(f"    {line}")
            rc = 1

    if rc:
        print()
        print("Remove suite-internal entries from ## OptionalDeps.")
        print("Use nil-guards at call sites and OneWoW:EnsureLoaded / WithAddon")
        print("for explicit user actions.")
        print("Reference: OneWoW/Docs/ARCHITECTURE.md §2")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
