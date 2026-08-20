#!/usr/bin/env python3
"""Run a script from sibling OneWoW_Devs/bin (Suite pre-commit bridge).

Usage:
    python bin/run_devs.py locale_verify.py OneWoW/Locales

If OneWoW_Devs is not next to this repo and ONEWOW_DEVS is unset, exit 0
so public forks without the private toolchain can still commit.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

SUITE_ROOT = Path(__file__).resolve().parents[1]


def find_devs() -> Path | None:
    env = os.environ.get("ONEWOW_DEVS")
    if env:
        path = Path(env).expanduser().resolve()
        return path if (path / "bin").is_dir() else None
    sibling = SUITE_ROOT.parent / "OneWoW_Devs"
    if (sibling / "bin").is_dir():
        return sibling
    return None


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: python bin/run_devs.py <script.py> [args...]", file=sys.stderr)
        return 2
    script, rest = argv[1], argv[2:]
    devs = find_devs()
    if devs is None:
        print(f"OneWoW_Devs not found; skipping {script}")
        return 0
    target = devs / "bin" / script
    if not target.is_file():
        print(f"missing {target}", file=sys.stderr)
        return 1
    return subprocess.call([sys.executable, str(target), *rest])


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
