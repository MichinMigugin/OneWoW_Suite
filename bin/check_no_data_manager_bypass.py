#!/usr/bin/env python3
"""Pre-commit hook: forbid cross-load-unit SavedVariables access in Lua files.

Each OneWoW sub-addon is its own load unit (separate TOC) and owns exactly the
SavedVariables globals declared in that TOC's `## SavedVariables` /
`## SavedVariablesPerCharacter` lines. A unit may touch only its **own** SVs;
any access to another unit's data goes through that unit's public
`OneWoW_<Unit>_API`. Reaching directly into another unit's store global
(e.g. a Catalog file touching `OneWoW_AltTracker_Storage_DB`, or the AltTracker
hub iterating `OneWoW_AltTracker_Character_DB.characters`) couples units that can
be enabled/disabled independently. See OneWoW/Docs/ARCHITECTURE.md §6/§7.

Ownership model (TOC-derived, naming-independent)
    The owner map is built by scanning every suite `*.toc` for its declared
    SavedVariables and mapping each SV global -> the TOC's load-unit folder. This
    is exact regardless of naming, so it correctly attributes globals whose name
    carries no family prefix (`OneWoW_AHPrices` -> Auctions) and per-character
    stores (`OneWoW_Trackers_CharDB` -> Trackers).

What counts as a violation
    A file under load unit A references (reads OR writes) an SV global owned by a
    different load unit B. Ownership is exact per TOC, so this catches both
    cross-*family* reads and same-family hub-to-store reads (e.g. the
    `OneWoW_AltTracker` hub touching `OneWoW_AltTracker_Storage_DB`) that the old
    prefix-based model was blind to.

    Shared core surface (readable everywhere): the bare `OneWoW` global (the
    cross-unit channel; never matches the SV pattern), `OneWoW_GUI` (the toolkit),
    and `OneWoW_DB` (core's hub DB). These never count as violations.

    Allowed by intent: naming a sub-addon / SV in a *string literal*
    (`OneWoW:EnsureLoaded("OneWoW_AltTracker_Auctions")`, the profile manager's
    `_G[dbName]` enumeration). Strings are stripped before matching, so only
    bareword *global access* is flagged.

    Sanctioned exceptions: `ALLOWED_FOREIGN_SV` grandfathers entries that are
    legitimately allowed to touch a foreign SV — the core profile manager
    (enumerates every unit's SV for import/export/wipe) and documented, time-boxed
    one-time data migrations.

Enforcement ramp
    Phase 0 (now): WARN_ONLY = True -> every cross-load-unit access prints,
                   nothing blocks. The output is the authoritative worklist for
                   the migration to `_API` getters/mutators.
    Later:         WARN_ONLY = False -> accesses whose `path::symbol` (or file
                   path) is in ALLOWED_FOREIGN_SV print as [allowed] and pass;
                   any other cross-load-unit access fails. Delete migration
                   entries as their data drains complete.

Allowlist keys are `path::symbol` (NOT path:lineno) so they survive edits that
shift line numbers; a bare path (no `::`) allowlists the whole file/tree. Only
moving the file or migrating the access changes the key.

Comment/string handling mirrors check_no_g_literal.py's pragmatic stance: simple
`[[ ]]` / `--[[ ]]` long brackets only (no `[==[` =-padding).
"""

from __future__ import annotations

import os
import re
import sys

# --- Enforcement phase (see module docstring) ---------------------------------
WARN_ONLY: bool = True  # Phase 0: report only, never block.

# Sanctioned cross-load-unit accesses. Each entry is either an exact
# `path::symbol` key or a bare path prefix (file or directory) allowlisting every
# foreign-SV access in that tree. When WARN_ONLY flips to False these pass as
# [allowed]; everything else off-list hard-fails.
ALLOWED_FOREIGN_SV: set[str] = {
    # Core profile manager — the sanctioned enumerator of every unit's SV for
    # import/export/restore. It indexes via `_G[dbName]` string literals, so it
    # is already invisible to the bareword scan; the file allowlist documents the
    # role and covers any future bareword access.
    "OneWoW/UI/t-charprofiles.lua",
    # Documented, time-boxed one-time migrations (drain legacy data out of a
    # sibling unit's SV). Remove each entry once the drain is retired.
    "OneWoW_Trackers/Core/Database.lua::OneWoW_Notes_DB",
    "OneWoW_AltTracker/Core/MigrationFix.lua::OneWoW_CatalogData_Quests_DB",
    "OneWoW_AltTracker/Core/MigrationFix.lua::OneWoW_CatalogData_Tradeskills_DB",
}

# --- Shared core surface (readable from any unit) ------------------------------
# The bare `OneWoW` global never matches the SV pattern (no `_Name`). `OneWoW_GUI`
# is the toolkit; `OneWoW_DB` is core's hub DB — both are the cross-unit channel.
SHARED_CORE_SV = {"OneWoW_DB"}
IGNORE_SYMBOLS = {"OneWoW_GUI"}

# Reference / vendored / generated trees to skip when discovering TOCs (mirrors
# the pre-commit `exclude` for this hook).
SKIP_DIRS = {
    "Libs",
    ".lua-defs",
    ".wow_docs",
    ".vscode",
    ".releases",
    ".git",
}

# Bareword reference to a `OneWoW_<Name>` global (after comments/strings stripped).
SYMBOL_RE = re.compile(r"\bOneWoW_[A-Za-z0-9_]+\b")

# `## SavedVariables: A, B` / `## SavedVariablesPerCharacter: C` (case-insensitive).
TOC_SV_RE = re.compile(
    r"^\s*##\s*SavedVariables(?:PerCharacter)?\s*:\s*(.+)$",
    re.IGNORECASE,
)

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def top_folder(path: str) -> str:
    """First path component, forward-slash normalized."""
    return path.replace("\\", "/").lstrip("./").split("/", 1)[0]


def build_sv_owner_map(root: str) -> dict[str, str]:
    """Map each declared SavedVariables global -> its owning load-unit folder.

    Scans every `*.toc` under `root` (skipping SKIP_DIRS). The owner is the TOC's
    top-level folder relative to `root`.
    """
    owners: dict[str, str] = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if not fn.endswith(".toc"):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, root).replace("\\", "/")
            owner = rel.split("/", 1)[0]
            try:
                with open(full, encoding="utf-8") as f:
                    toc_lines = f.readlines()
            except (OSError, UnicodeDecodeError):
                continue
            for line in toc_lines:
                m = TOC_SV_RE.match(line)
                if not m:
                    continue
                for raw in m.group(1).split(","):
                    name = raw.strip()
                    if name:
                        owners.setdefault(name, owner)
    return owners


def strip_code(line: str, state: str) -> tuple[str, str]:
    """Return (code-only line, carry-over state), removing comments and strings.

    Carried states across lines: 'long' ([[ ]] string) and 'block' (--[[ ]]
    comment). Quoted strings never carry (Lua forbids raw newlines in them).
    """
    out: list[str] = []
    i, n = 0, len(line)
    while i < n:
        two = line[i : i + 2]
        if state == "normal":
            if line[i : i + 4] == "--[[":
                state = "block"
                i += 4
            elif two == "--":
                break  # rest of line is a single-line comment
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
                i += 2  # skip escaped char
            elif (state == "dq" and line[i] == '"') or (state == "sq" and line[i] == "'"):
                state = "normal"
                i += 1
            else:
                i += 1
        else:  # 'long' or 'block' — consume until closing ]]
            if two == "]]":
                state = "normal"
                i += 2
            else:
                i += 1
    # Unterminated quotes don't span lines in Lua; reset defensively.
    if state in ("dq", "sq"):
        state = "normal"
    return "".join(out), state


def check_file(path: str, sv_owner: dict[str, str]) -> list[tuple[int, str, str, str]]:
    """Return list of (lineno, symbol, owner_unit, raw_line) violations."""
    file_unit = top_folder(path)
    violations: list[tuple[int, str, str, str]] = []

    try:
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
    except (OSError, UnicodeDecodeError) as e:
        print(f"{path}: error reading file: {e}", file=sys.stderr)
        return []

    state = "normal"
    for lineno, raw in enumerate(lines, 1):
        code, state = strip_code(raw, state)
        for m in SYMBOL_RE.finditer(code):
            symbol = m.group(0)
            if symbol in IGNORE_SYMBOLS or symbol in SHARED_CORE_SV:
                continue
            owner = sv_owner.get(symbol)
            if owner is None:          # not a declared SV global — not our concern
                continue
            if owner == file_unit:     # same load unit — fine
                continue
            violations.append((lineno, symbol, owner, raw.rstrip()))

    return violations


def is_allowed(norm_path: str, symbol: str) -> bool:
    """True if this `path::symbol` (or its file/dir path) is allowlisted."""
    if f"{norm_path}::{symbol}" in ALLOWED_FOREIGN_SV:
        return True
    for entry in ALLOWED_FOREIGN_SV:
        if "::" in entry:
            continue
        if norm_path == entry or norm_path.startswith(entry + "/"):
            return True
    return False


def main(argv: list[str]) -> int:
    sv_owner = build_sv_owner_map(REPO_ROOT)
    blocking = 0
    worklist_keys: set[str] = set()

    for path in argv[1:]:
        norm = path.replace("\\", "/")
        for lineno, symbol, owner, line in check_file(path, sv_owner):
            allowed = is_allowed(norm, symbol)
            if allowed:
                tag = "[allowed]"
            elif WARN_ONLY:
                tag = "[warn]"
                worklist_keys.add(f"{norm}::{symbol}")
            else:
                tag = "[error]"
                blocking += 1
            print(f"{tag} {path}:{lineno}: cross-load-unit access of '{symbol}' "
                  f"(owned by {owner})")
            print(f"    {line}")

    if worklist_keys or blocking:
        print()
        print("Cross-load-unit data access should go through the owner's public API:")
        print("  OneWoW_<Unit>_API.Get*(...)          -- read another unit's data")
        print("  OneWoW_<Unit>_API.Set*/Reset*(...)   -- mutate another unit's data")
        print("Reference: OneWoW/Docs/ARCHITECTURE.md §6/§7")
        if WARN_ONLY and worklist_keys:
            print()
            print("Phase 0 (warn-only): not blocking. Authoritative migration"
                  " worklist (path::symbol):")
            for key in sorted(worklist_keys):
                print(f'    "{key}",')

    return 1 if blocking else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
