#!/usr/bin/env python3
"""Locale key-diff analysis for the localization rollout (Phase 0 tooling).

Scans every `*/Locales/**/enUS.lua` in the suite, extracts the registered keys
and their English values, and classifies them against two reference sets:

  * the core `shared` scope  (OneWoW/Locales/Shared/enUS.lua)
  * Blizzard's global strings (.wow_docs/general/GlobalStrings.lua)

Output drives the rollout plan:
  A. SHARED COLLISIONS    — a scope re-defines a key shared already owns -> delete it.
  B. BLIZZARD CANDIDATES  — key NAME matches a Blizzard global -> Phase 2 (bare global).
                            Split into exact-value matches vs name-only (value differs).
  C. CROSS-SCOPE DUPES    — key defined in >=2 scopes, not covered by A/B -> Phase 1
                            (promote to shared). Flags value disagreement.
  D. PER-SCOPE TOTALS     — keys per scope and the must-translate remainder
                            (total minus shared/blizzard-covered) -> Phase 3 baseline.

Read-only. No arguments; run from the repo root:  python bin/locale_keydiff.py
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

# ["KEY"] = "value"  /  ['KEY'] = "value"  /  bareword  KEY = "value"
# Value capture is best-effort: only a simple double/single-quoted literal; keys
# whose value is an expression (a global, concatenation) capture value = None.
KEY_RE = re.compile(
    r"""^\s*
        (?:\[\s*(["'])(?P<bk>[A-Za-z0-9_]+)\1\s*\]   # ["KEY"] bracket form
          |(?P<wk>[A-Za-z_][A-Za-z0-9_]*))            # bareword KEY
        \s*=\s*
        (?:(["'])(?P<val>(?:\\.|(?!\4).)*)\4)?         # optional "value"
    """,
    re.VERBOSE,
)
# Blizzard global:  NAME = "value";
GLOBAL_RE = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"((?:\\.|[^"])*)"\s*;?\s*$')


def scope_for(path: Path, root: Path) -> str:
    """Derive the registration scope name from a locale file path."""
    rel = path.relative_to(root).as_posix()
    parts = rel.split("/")
    addon = parts[0]
    if addon == "OneWoW" and "Shared" in parts:
        return "shared"
    # OneWoW_QoL/Modules/external/<id>/Locales/enUS.lua -> OneWoW_QoL.<id>
    if "Modules" in parts and "external" in parts:
        i = parts.index("external")
        return f"{addon}.{parts[i + 1]}"
    return addon


def parse_keys(path: Path) -> dict[str, str | None]:
    out: dict[str, str | None] = {}
    in_block = False
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        s = line.strip()
        if in_block:
            if "]]" in s:
                in_block = False
            continue
        if s.startswith("--[["):
            if "]]" not in s[4:]:
                in_block = True
            continue
        if s.startswith("--") or not s:
            continue
        m = KEY_RE.match(line)
        if not m:
            continue
        key = m.group("bk") or m.group("wk")
        if not key:
            continue
        out[key] = m.group("val")
    return out


def load_globals(root: Path) -> dict[str, str]:
    gpath = root / ".wow_docs" / "general" / "GlobalStrings.lua"
    globals_map: dict[str, str] = {}
    if not gpath.exists():
        print(f"WARNING: {gpath} not found — Blizzard analysis skipped.", file=sys.stderr)
        return globals_map
    for line in gpath.read_text(encoding="utf-8", errors="replace").splitlines():
        m = GLOBAL_RE.match(line)
        if m:
            globals_map.setdefault(m.group(1), m.group(2))
    return globals_map


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # scope/value text may be non-ASCII
    except AttributeError:
        pass
    root = Path.cwd()
    blizz = load_globals(root)

    # scope -> { key: value }
    scopes: dict[str, dict[str, str | None]] = defaultdict(dict)
    files = sorted(root.glob("**/Locales/**/enUS.lua")) + sorted(root.glob("**/Locales/enUS.lua"))
    seen_files = set()
    for f in files:
        if f in seen_files or ".wow_docs" in f.parts:
            continue
        seen_files.add(f)
        scopes[scope_for(f, root)].update(parse_keys(f))

    shared = scopes.get("shared", {})
    shared_keys = set(shared)

    # key -> scopes that define it (non-shared); key -> distinct values
    key_scopes: dict[str, set[str]] = defaultdict(set)
    key_vals: dict[str, set[str]] = defaultdict(set)
    for scope, kv in scopes.items():
        if scope == "shared":
            continue
        for k, v in kv.items():
            key_scopes[k].add(scope)
            if v is not None:
                key_vals[k].add(v)

    print(f"Parsed {len(seen_files)} enUS locale files into {len(scopes)} scopes "
          f"({len(shared_keys)} shared keys, {len(blizz)} Blizzard globals).\n")

    # ---- A. Shared collisions ----
    collisions = sorted(k for k in key_scopes if k in shared_keys)
    print(f"== A. SHARED COLLISIONS ({len(collisions)}) -> delete from scope ==")
    for k in collisions:
        print(f"  {k}: defined in {', '.join(sorted(key_scopes[k]))}")
    print()

    # ---- B. Blizzard-global candidates (name match), excluding shared collisions ----
    blizz_exact, blizz_namebrk = [], []
    for k in sorted(key_scopes):
        if k in shared_keys or k not in blizz:
            continue
        vals = key_vals.get(k, set())
        if vals and all(v == blizz[k] for v in vals):
            blizz_exact.append(k)
        else:
            blizz_namebrk.append(k)
    print(f"== B. BLIZZARD CANDIDATES -> Phase 2 (bare global) ==")
    print(f"  -- exact value match ({len(blizz_exact)}) --")
    for k in blizz_exact:
        print(f"    {k} = \"{blizz[k]}\"  [{len(key_scopes[k])} scope(s)]")
    print(f"  -- name match, VALUE DIFFERS ({len(blizz_namebrk)}) -- review before adopting --")
    for k in blizz_namebrk:
        ours = " | ".join(sorted(key_vals.get(k, set()))) or "(expr)"
        print(f"    {k}: Blizzard=\"{blizz[k]}\"  ours=\"{ours}\"")
    print()

    # ---- C. Cross-scope duplicates not covered by A/B ----
    # Same NAME in >=2 scopes splits two ways: values AGREE (one real string ->
    # genuine promote-to-shared) vs values DIFFER (same name, per-addon meaning ->
    # NOT shared; promoting would force one wrong value).
    covered = set(collisions) | set(blizz_exact)
    dupes = [k for k, sc in key_scopes.items() if len(sc) >= 2 and k not in covered]
    agree = sorted((k for k in dupes if len(key_vals.get(k, set())) <= 1),
                   key=lambda k: (-len(key_scopes[k]), k))
    differ = sorted((k for k in dupes if len(key_vals.get(k, set())) > 1),
                    key=lambda k: (-len(key_scopes[k]), k))

    print(f"== C. CROSS-SCOPE DUPLICATES ({len(dupes)}) ==")
    print(f"  -- C1: values AGREE ({len(agree)}) -> Phase 1 promote candidates --")
    for k in agree:
        val = next(iter(key_vals.get(k, {"(expr)"})))
        print(f"    {k}: {len(key_scopes[k])} scopes = \"{val}\"")
    print(f"  -- C2: values DIFFER ({len(differ)}) -> per-addon, do NOT promote --")
    for k in differ:
        print(f"    {k}: {len(key_scopes[k])} scopes, {len(key_vals[k])} distinct values")
    print()

    # ---- D. Per-scope totals + must-translate remainder ----
    print("== D. PER-SCOPE TOTALS (remainder = must-translate for Phase 3) ==")
    removable = set(collisions) | set(blizz_exact)
    rows = []
    for scope in sorted(scopes):
        if scope == "shared":
            continue
        total = len(scopes[scope])
        remove = sum(1 for k in scopes[scope] if k in removable)
        rows.append((scope, total, remove, total - remove))
    width = max((len(s) for s, *_ in rows), default=10)
    print(f"  {'scope'.ljust(width)}  total  -covered  =translate")
    for scope, total, remove, rem in rows:
        print(f"  {scope.ljust(width)}  {total:5d}  {remove:8d}  {rem:9d}")
    grand = sum(r[3] for r in rows)
    print(f"  {'TOTAL'.ljust(width)}  {'':5}  {'':8}  {grand:9d}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
