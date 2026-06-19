#!/usr/bin/env python3
"""Pre-commit hook: forbid cross-family sub-addon global reads in Lua files.

Each OneWoW sub-addon is its own load unit (separate TOC). The sanctioned way to
read *another* unit's data is `OneWoW.DataManager:Query(...)` (graceful empty when
the target is unloaded) or `OneWoW:EnsureLoaded(...)` for explicit user actions.
Reaching directly into another family's global store (e.g. a Catalog file touching
`OneWoW_AltTracker_Storage._DB`) couples units that can be enabled/disabled
independently. See OneWoW/Docs/ARCHITECTURE.md §7.

What counts as a violation
    A file belonging to family A references a global owned by family B.
    Family membership is derived from the top-level addon folder (for files) and
    from the global's name prefix (for symbols) — see FAMILY_PREFIXES.

    Allowed always: the shared core surface (`OneWoW`, `OneWoW_GUI`) — that *is*
    the cross-unit channel. The bare `OneWoW` global never matches the pattern
    (no trailing `_Name`); `OneWoW_GUI` is explicitly ignored.

    Allowed by intent: naming a sub-addon in a *string literal*
    (`OneWoW:EnsureLoaded("OneWoW_AltTracker_Auctions")`, TOC-name lists in the
    loader). Strings are stripped before matching, so only bareword *global
    access* is flagged.

Enforcement ramp
    Phase 1 (now):  WARN_ONLY = True  -> every cross-family read prints, nothing
                    blocks. The §4.1 direct reads are grandfathered implicitly.
    Phase 2:        WARN_ONLY = False -> reads whose `path::symbol` key is in
                    ALLOWLIST print as [grandfathered] and pass; any *new* read
                    fails. Delete a key as each read migrates to DataManager.
    Phase 3:        WARN_ONLY = False, ALLOWLIST empty -> every cross-family read
                    hard-fails, same as check_no_g_literal.py. The rule is real.

Allowlist keys are `path::symbol` (NOT path:lineno) so they survive edits that
shift line numbers; only moving the file or migrating the read changes the key.

Comment/string handling mirrors check_no_g_literal.py's pragmatic stance: simple
`[[ ]]` / `--[[ ]]` long brackets only (no `[==[` =-padding).
"""

from __future__ import annotations

import re
import sys

# --- Enforcement phase (see module docstring) ---------------------------------
WARN_ONLY: bool = True  # Phase 1: report only, never block.

# Phase 2 seed: `path::symbol` keys grandfathering today's §4.1 direct reads.
# Empty while WARN_ONLY is True. Populate from this hook's own warn output when
# flipping to Phase 2, then delete entries as each read moves to DataManager.
ALLOWLIST: set[str] = set()

# --- Family model --------------------------------------------------------------
# Longest-first so a stem is never shadowed by a shorter one. A name (file folder
# or global symbol) belongs to the first family whose prefix it starts with.
# Note: "OneWoW_Catalog" intentionally also claims "OneWoW_CatalogData_*".
FAMILY_PREFIXES: list[str] = sorted(
    [
        "OneWoW_AltTracker",
        "OneWoW_Catalog",
        "OneWoW_Notes",
        "OneWoW_Trackers",
        "OneWoW_QoL",
        "OneWoW_ShoppingList",
        "OneWoW_DirectDeposit",
        "OneWoW_Bags",
        "OneWoW_Utility_DevTool",
    ],
    key=len,
    reverse=True,
)

CORE_FAMILY = "OneWoW"            # the core addon folder == its own family
IGNORE_SYMBOLS = {"OneWoW_GUI"}  # shared core surface, readable everywhere

# Bareword reference to a `OneWoW_<Name>` global (after comments/strings stripped).
SYMBOL_RE = re.compile(r"\bOneWoW_[A-Za-z0-9_]+\b")


def family_of(name: str) -> str | None:
    """Family label for a folder name or global symbol; None if unmodeled."""
    if name == CORE_FAMILY:
        return CORE_FAMILY
    for prefix in FAMILY_PREFIXES:
        if name.startswith(prefix):
            return prefix
    return None


def top_folder(path: str) -> str:
    """First path component, forward-slash normalized."""
    return path.replace("\\", "/").lstrip("./").split("/", 1)[0]


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


def check_file(path: str) -> list[tuple[int, str, str, str]]:
    """Return list of (lineno, symbol, symbol_family, raw_line) violations."""
    file_family = family_of(top_folder(path))
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
            if symbol in IGNORE_SYMBOLS:
                continue
            sym_family = family_of(symbol)
            if sym_family is None:           # unmodeled global — don't guess
                continue
            if sym_family == file_family:    # in-family read — fine
                continue
            violations.append((lineno, symbol, sym_family, raw.rstrip()))

    return violations


def main(argv: list[str]) -> int:
    blocking = 0
    seen_keys: set[str] = set()

    for path in argv[1:]:
        norm = path.replace("\\", "/")
        for lineno, symbol, sym_family, line in check_file(path):
            key = f"{norm}::{symbol}"
            seen_keys.add(key)
            grandfathered = key in ALLOWLIST
            if WARN_ONLY:
                tag = "[warn]"
            elif grandfathered:
                tag = "[grandfathered]"
            else:
                tag = "[error]"
                blocking += 1
            print(f"{tag} {path}:{lineno}: cross-family read of '{symbol}' "
                  f"(owned by {sym_family})")
            print(f"    {line}")

    if seen_keys and (WARN_ONLY or blocking):
        print()
        print("Cross-family data reads should go through:")
        print("  OneWoW.DataManager:Query(key, ...)   -- passive, degrades to empty")
        print("  OneWoW:EnsureLoaded(name)            -- explicit user actions only")
        print("Reference: OneWoW/Docs/ARCHITECTURE.md §7")
        if WARN_ONLY:
            print()
            print("Phase 1 (warn-only): not blocking. Candidate ALLOWLIST seed for"
                  " Phase 2:")
            for key in sorted(seen_keys):
                print(f'    "{key}",')

    return 1 if blocking else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
