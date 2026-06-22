#!/usr/bin/env python3
"""Pre-commit hook: flag namespace publish and global-surface anti-patterns in Lua.

Enforces OneWoW/Docs/ARCHITECTURE.md §6.1 during the addon migration period.
See MIGRATION.md §3 for the cleanup checklist.

Flagged patterns (new code should not add these):
    OneWoW_<Unit> = ns              -- hand namespace publish
    _G[...] = ns                    -- Notes-style publish
    _G[...] = OneWoW_Bags           -- Bags-style publish (ns renamed to addon name)
    local ADDON_NAME, OneWoW_Foo = ...  -- vararg namespace renamed (use ns)
    ns.addon = ...                  -- back-reference hop
    OneWoW_<Unit>.db                -- db on lifecycle root (use ns.db)

Grandfathered paths (ALLOWED_NAMESPACE_PUBLISH) pass as [allowed]. Everyone else
prints [warn] while WARN_ONLY is True; flip to False when the inventory is drained.

Allowlist keys are `path` (whole file) or `path::pattern_id` (single pattern in
that file). Remove entries as units migrate.
"""

from __future__ import annotations

import re
import sys

# --- Enforcement phase -------------------------------------------------------
WARN_ONLY: bool = True  # Warn-only during migration; set False when worklist is drained.

ALLOWED_NAMESPACE_PUBLISH: set[str] = {
    "OneWoW/Core/StoreBootstrap.lua",
    "OneWoW_Bags/OneWoW_Bags.lua",
    "OneWoW_Notes/OneWoW_Notes.lua",
}

# (pattern_id, compiled regex, human label)
RULES: list[tuple[str, re.Pattern[str], str]] = [
    (
        "assign_ns",
        re.compile(r"OneWoW_\w+\s*=\s*ns\b"),
        "OneWoW_<Unit> = ns (namespace publish)",
    ),
    (
        "g_assign_ns",
        re.compile(r"_G\[[^\]]+\]\s*=\s*ns\b"),
        "_G[...] = ns (namespace publish)",
    ),
    (
        "g_assign_bags_ns",
        re.compile(r"_G\[[^\]]+\]\s*=\s*OneWoW_Bags\b"),
        "_G[...] = OneWoW_Bags (namespace-as-global)",
    ),
    (
        "renamed_ns_vararg",
        re.compile(r"local\s+(?:ADDON_NAME,\s*)?OneWoW_\w+\s*=\s*\.\.\."),
        "renamed vararg namespace (use local ADDON_NAME, ns = ...)",
    ),
    (
        "ns_addon_backref",
        re.compile(r"ns\.addon\s*="),
        "ns.addon back-reference (use ns.db)",
    ),
    (
        "lifecycle_root_db",
        re.compile(r"OneWoW_(?!GUI\b)\w+\.db\b"),
        ".db on lifecycle root (use ns.db)",
    ),
]


def strip_comments(line: str, in_block: bool) -> tuple[str, bool]:
    """Return (code_portion, in_block_comment_after_line)."""
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


def is_file_allowlisted(norm_path: str) -> bool:
    for entry in ALLOWED_NAMESPACE_PUBLISH:
        if "::" in entry:
            continue
        if norm_path == entry or norm_path.startswith(entry + "/"):
            return True
    return False


def is_rule_allowlisted(norm_path: str, pattern_id: str) -> bool:
    key = f"{norm_path}::{pattern_id}"
    if key in ALLOWED_NAMESPACE_PUBLISH:
        return True
    return is_file_allowlisted(norm_path)


def check_file(path: str) -> list[tuple[int, str, str, str]]:
    """Return (lineno, pattern_id, label, line)."""
    violations: list[tuple[int, str, str, str]] = []
    in_block = False

    try:
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
    except (OSError, UnicodeDecodeError) as e:
        print(f"{path}: error reading file: {e}", file=sys.stderr)
        return []

    for lineno, line in enumerate(lines, 1):
        code, in_block = strip_comments(line, in_block)
        if not code.strip():
            continue
        for pattern_id, regex, label in RULES:
            if regex.search(code):
                violations.append((lineno, pattern_id, label, line.rstrip()))

    return violations


def main(argv: list[str]) -> int:
    blocking = 0
    worklist_keys: set[str] = set()

    for path in argv[1:]:
        norm = path.replace("\\", "/")
        if is_file_allowlisted(norm):
            continue

        for lineno, pattern_id, label, line in check_file(path):
            allowed = is_rule_allowlisted(norm, pattern_id)
            if allowed:
                tag = "[allowed]"
            elif WARN_ONLY:
                tag = "[warn]"
                worklist_keys.add(f"{norm}::{pattern_id}")
            else:
                tag = "[error]"
                blocking += 1
            print(f"{tag} {path}:{lineno}: {label}")
            print(f"    {line}")

    if worklist_keys or blocking:
        print()
        print("Global surface rules: OneWoW/Docs/ARCHITECTURE.md §6.1")
        print("  local ADDON_NAME, ns = ...     -- private namespace")
        print("  ns.db = DB:Init(...)           -- internal db handle")
        print("  OneWoW_<Unit>_API.Get*(...)    -- cross-unit contract")
        print("  OneWoW_<Unit> = {}             -- thin lifecycle root only")
        if WARN_ONLY and worklist_keys:
            print()
            print("Warn-only mode: not blocking. Worklist (path::pattern_id):")
            for key in sorted(worklist_keys):
                print(f'    "{key}",')

    return 1 if blocking else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
