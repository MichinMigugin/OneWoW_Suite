#!/usr/bin/env python3
"""Pre-commit hook: Ketho / lua-language-server WoW API compliance audit.

Runs when staged files touch a shipped OneWoW load unit. Delegates to:

    python bin/run_ketho_audit.py --addons <list>

See .cursor/rules/1W-Ricky-Audit.mdc.

Prerequisites (one-time per machine):
    winget install LuaLS.lua-language-server
    bin/audit-tools/vscode-wow-api (Ketho annotations — already present locally)
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
AUDIT_SCRIPT = REPO_ROOT / "bin" / "run_ketho_audit.py"
ADDON_RE = re.compile(r"(?:^|/)((?:OneWoW(?:_[^/]+)?))/")
SKIP_PREFIXES = (
    "Libs/",
    ".wow_docs/",
    ".lua-defs/",
    ".vscode/",
    ".releases/",
    "OneWoW_Bags/API/Examples/",
    "OneWoW_CatalogData_Quests/Tools/",
)


def normalize(path: str) -> str:
    return path.replace("\\", "/")


def addon_from_path(path: str) -> str | None:
    rel = normalize(path)
    if not rel.endswith((".lua", ".toc")):
        return None
    for prefix in SKIP_PREFIXES:
        if rel.startswith(prefix) or f"/{prefix}" in rel:
            return None
    m = ADDON_RE.search(rel)
    return m.group(1) if m else None


def collect_addons(filenames: list[str]) -> list[str]:
    addons: set[str] = set()
    for raw in filenames:
        addon = addon_from_path(raw)
        if addon:
            addons.add(addon)
    return sorted(addons)


def run_audit(addons: list[str]) -> int:
    if not AUDIT_SCRIPT.is_file():
        print("Ketho audit driver missing: bin/run_ketho_audit.py", file=sys.stderr)
        return 1

    args = [
        sys.executable,
        str(AUDIT_SCRIPT),
        "--addons",
        ",".join(addons),
    ]
    print(
        f"precommit_ketho_audit: scanning {len(addons)} addon(s): {', '.join(addons)}",
        file=sys.stderr,
    )
    proc = subprocess.run(args, cwd=REPO_ROOT)
    return proc.returncode


def main(argv: list[str]) -> int:
    filenames = argv[1:]
    if not filenames:
        return 0

    addons = collect_addons(filenames)
    if not addons:
        return 0

    return run_audit(addons)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
