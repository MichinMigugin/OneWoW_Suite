#!/usr/bin/env python3
"""Pre-commit hook: forbid per-addon Media/ folders outside the OneWoW hub.

All suite textures, fonts, and sounds ship under OneWoW/Media/ — shared assets
at the hub root, addon-owned assets under OneWoW/Media/<AddonName>/ subfolders.
Per-load-unit OneWoW_*/Media/ trees duplicate assets and bypass MEDIA_BASE.

Reference: OneWoW/Docs/GUI.md (Media assets).
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def find_violations() -> list[Path]:
    """Return OneWoW_*/Media directories (forbidden)."""
    violations: list[Path] = []
    for entry in sorted(REPO_ROOT.iterdir()):
        if not entry.is_dir():
            continue
        if not entry.name.startswith("OneWoW_"):
            continue
        media_dir = entry / "Media"
        if media_dir.is_dir():
            violations.append(media_dir)
    return violations


def main() -> int:
    violations = find_violations()
    if not violations:
        return 0

    for path in violations:
        rel = path.relative_to(REPO_ROOT)
        print(f"{rel}: per-addon Media/ folder is not allowed")

    print()
    print("Consolidate media under OneWoW/Media/:")
    print("  Shared assets     → OneWoW/Media/")
    print("  Addon-specific    → OneWoW/Media/<AddonName>/")
    print("Use OneWoW_GUI.Constants.MEDIA_BASE in Lua (never ship OneWoW_*/Media/).")
    print("Reference: OneWoW/Docs/GUI.md")
    return 1


if __name__ == "__main__":
    sys.exit(main())
