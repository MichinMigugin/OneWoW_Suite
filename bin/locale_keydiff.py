#!/usr/bin/env python3
"""Locale key/value analysis for the localization rollout (Phase 0 tooling).

Scans every `*/Locales/**/enUS.lua` in the suite, extracts the registered keys
and their English values, and classifies them so the rollout can (1) replace
strings with Blizzard globals, (2) consolidate duplicates into the shared scope,
and (3) translate only what remains into all 11 locales.

The primary unit of analysis is the VALUE, not the key name: two different keys
holding the same string (e.g. CLOSE = "Close" and CLOSE_IT = "Close") are the
same translatable string and should collapse to one home. Reference sets:

  * the core `shared` scope  (OneWoW/Locales/Shared/enUS.lua)
  * Blizzard's global strings (.wow_docs/general/GlobalStrings.lua), inverted to
    value -> [global names].

Suite report (no args) sections:
  A. SHARED COLLISIONS  — a scope re-defines a key name shared owns -> delete (contract).
  B. BLIZZARD BY VALUE  — a string equals a canonically-named Blizzard global ->
                          Phase 2: replace all sites with the bare global.
  C. CONSOLIDATE BY VALUE — a string with no usable global appears at >=2 sites ->
                          Phase 1: collapse to one shared key.
  D. TRANSLATE REMAINDER — per scope, keys left after routing B/C -> Phase 4 baseline.
  E. NAME-MATCH TRAPS   — a global shares a key's NAME but holds a different value.

Per-addon worklist (`--scope OneWoW_Bags`) buckets that scope's own keys into
DELETE / BLIZZARD / CONSOLIDATE / TRANSLATE for curation one addon at a time.

IMPORTANT: identical enUS value does NOT guarantee identical translation in other
languages (Close=verb vs Close=adjacent). Treat B/C as candidates needing a
meaning check before collapsing; Blizzard-by-value (B) is safest. Proper nouns
(addon names: "OneWoW", "Notes", ...) consolidate but must NOT be translated.

Read-only. Run from the repo root.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

# ["KEY"] = "value"  /  ['KEY'] = "value"  /  bareword  KEY = "value"
KEY_RE = re.compile(
    r"""^\s*
        (?:\[\s*(["'])(?P<bk>[A-Za-z0-9_]+)\1\s*\]
          |(?P<wk>[A-Za-z_][A-Za-z0-9_]*))
        \s*=\s*
        (?:(["'])(?P<val>(?:\\.|(?!\4).)*)\4)?
    """,
    re.VERBOSE,
)
# Blizzard global:  NAME = "value";
GLOBAL_RE = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"((?:\\.|[^"])*)"\s*;?\s*$')

# Values too trivial/ambiguous to treat as a consolidation or global-adoption signal.
TRIVIAL_RE = re.compile(r"^[\d\s%.\-:/|()]+$")

MAX_SITES_SHOWN = 15


def is_meaningful(v: str) -> bool:
    s = v.strip()
    return len(s) >= 2 and not TRIVIAL_RE.match(s)


def scope_for(path: Path, root: Path) -> str:
    rel = path.relative_to(root).as_posix()
    parts = rel.split("/")
    addon = parts[0]
    if addon == "OneWoW" and "Shared" in parts:
        return "shared"
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
        if key:
            out[key] = m.group("val")
    return out


def load_globals(root: Path) -> dict[str, str]:
    gpath = root / ".wow_docs" / "general" / "GlobalStrings.lua"
    out: dict[str, str] = {}
    if not gpath.exists():
        print(f"WARNING: {gpath} not found — Blizzard analysis skipped.", file=sys.stderr)
        return out
    for line in gpath.read_text(encoding="utf-8", errors="replace").splitlines():
        m = GLOBAL_RE.match(line)
        if m:
            out.setdefault(m.group(1), m.group(2))
    return out


def fmt_sites(st, limit: int = MAX_SITES_SHOWN) -> str:
    ordered = sorted(st)
    shown = ", ".join(f"{s}.{k}" for s, k in ordered[:limit])
    if len(ordered) > limit:
        shown += f", ... (+{len(ordered) - limit} more)"
    return shown


def build_indexes(root: Path):
    """Parse every enUS locale file into scope/value indices."""
    scopes: dict[str, dict[str, str | None]] = defaultdict(dict)
    files = sorted(root.glob("**/Locales/**/enUS.lua")) + sorted(root.glob("**/Locales/enUS.lua"))
    seen = set()
    for f in files:
        if f in seen or ".wow_docs" in f.parts:
            continue
        seen.add(f)
        scopes[scope_for(f, root)].update(parse_keys(f))

    sites: dict[str, set[tuple[str, str]]] = defaultdict(set)   # value -> {(scope, key)}
    for scope, kv in scopes.items():
        for k, v in kv.items():
            if v is not None:
                sites[v].add((scope, k))

    blizz = load_globals(root)
    glob_by_val: dict[str, list[str]] = defaultdict(list)       # value -> [global names]
    for name, val in blizz.items():
        glob_by_val[val].append(name)
    for v in glob_by_val:
        glob_by_val[v].sort()

    return scopes, sites, blizz, glob_by_val, len(seen)


def make_canonical(glob_by_val):
    """Return canonical(value) -> the global whose NAME is the value's upper-snake, or None.

    Gates out incidental same-value globals (KEY_NUMLOCK_MAC = "Clear").
    """
    def canonical(v: str) -> str | None:
        base = re.sub(r"[^0-9A-Za-z]+", "_", v.strip()).strip("_").upper()
        return next((n for n in glob_by_val.get(v, ()) if n == base), None)
    return canonical


def full_report(scopes, sites, blizz, glob_by_val, n_files) -> int:
    canonical = make_canonical(glob_by_val)
    shared_keys = set(scopes.get("shared", {}))
    key_scopes: dict[str, set[str]] = defaultdict(set)
    for scope, kv in scopes.items():
        if scope != "shared":
            for k in kv:
                key_scopes[k].add(scope)

    scoped_total = sum(len(kv) for sc, kv in scopes.items() if sc != "shared")
    print(f"Parsed {n_files} enUS files: {len(scopes)} scopes, {len(shared_keys)} shared "
          f"keys, {scoped_total} scoped keys, {len(blizz)} Blizzard globals.")
    print("NOTE: identical enUS value != identical translation — review meaning before "
          "collapsing (B safest).\n")

    # ---- A. Shared collisions ----
    collisions = sorted(k for k in key_scopes if k in shared_keys)
    print(f"== A. SHARED COLLISIONS ({len(collisions)}) -> delete from scope (contract) ==")
    for k in collisions:
        print(f"  {k}: also defined in {', '.join(sorted(key_scopes[k]))}")
    print()

    # ---- B. Blizzard adoption BY VALUE ----
    routed_b: set[tuple[str, str]] = set()
    b_hits = sorted((v for v in sites if canonical(v) and is_meaningful(v)),
                    key=lambda v: (-len(sites[v]), v.lower()))
    for v in b_hits:
        routed_b |= sites[v]
    print(f"== B. BLIZZARD BY VALUE ({len(b_hits)} strings, "
          f"{sum(len(sites[v]) for v in b_hits)} sites) -> Phase 2 bare global ==")
    for v in b_hits:
        print(f'  {canonical(v)} = "{v}"   [{len(sites[v])} sites]')
        print(f"       {fmt_sites(sites[v])}")
    print()

    # ---- C. Consolidation BY VALUE (no usable global) ----
    routed_c: set[tuple[str, str]] = set()
    consol = sorted((v for v, st in sites.items()
                     if not canonical(v) and len(st) >= 2 and is_meaningful(v)),
                    key=lambda v: (-len(sites[v]), v.lower()))
    print(f"== C. CONSOLIDATE BY VALUE ({len(consol)} strings) -> Phase 1 promote/normalize ==")
    for v in consol:
        st = sites[v]
        routed_c |= st
        names = sorted({k for _, k in st})
        tag = f"{len(names)} key names (rename)" if len(names) > 1 else "1 key name"
        hint = ""
        if v in glob_by_val:
            hint = f"  [incidental global, IGNORE unless apt: {'/'.join(glob_by_val[v][:3])}]"
        print(f'  "{v}"   [{len(st)} sites; {tag}]{hint}')
        print(f"       {fmt_sites(st)}")
    print()

    # ---- D. Per-scope translate remainder ----
    removed = defaultdict(int)
    for scope, _ in (routed_b | routed_c):
        removed[scope] += 1
    rows = [(sc, len(scopes[sc]), removed.get(sc, 0)) for sc in sorted(scopes)]
    width = max(len(r[0]) for r in rows)
    print("== D. PER-SCOPE TRANSLATE REMAINDER (total - routed to global/shared) ==")
    print(f"  {'scope'.ljust(width)}  total  routed  =translate")
    for sc, total, rem in rows:
        print(f"  {sc.ljust(width)}  {total:5d}  {rem:6d}  {total - rem:9d}")
    g_total = sum(r[1] for r in rows)
    g_routed = sum(r[2] for r in rows)
    print(f"  {'-' * (width + 26)}")
    print(f"  all keys: {g_total} | routed to global/shared: {g_routed} | "
          f"remaining: {g_total - g_routed}")
    print(f"  Phase-2 (global) strings translate 0x; ~{len(consol)} consolidated strings "
          f"translate 1x in shared.")
    print()

    # ---- E. Name-match traps ----
    traps = []
    for k in sorted(key_scopes):
        if k in blizz and k not in shared_keys:
            ours = {scopes[s].get(k) for s in key_scopes[k]}
            ours.discard(None)
            if ours and blizz[k] not in ours:
                traps.append((k, blizz[k], sorted(ours)))
    print(f"== E. NAME-MATCH TRAPS ({len(traps)}) -- global shares the NAME, different "
          f"value; never route by name ==")
    for k, gval, ours in traps:
        print(f'  {k}: global="{gval}"  ours={" | ".join(chr(34) + o + chr(34) for o in ours)}')
    return 0


def scope_report(scopes, sites, glob_by_val, target: str) -> int:
    canonical = make_canonical(glob_by_val)
    shared_keys = set(scopes.get("shared", {}))
    kv = scopes.get(target)
    if kv is None:
        print(f"Unknown scope '{target}'. Available scopes:")
        for s in sorted(scopes):
            print(f"  {s}")
        return 1

    coll, blz, cons, uniq = [], [], [], []
    for key in sorted(kv):
        val = kv[key]
        if key in shared_keys:
            coll.append((key, val))
        elif val is not None and canonical(val):
            blz.append((key, val, canonical(val)))
        elif val is not None and is_meaningful(val) and len(sites[val]) >= 2:
            cons.append((key, val, sorted(sites[val] - {(target, key)})))
        else:
            uniq.append((key, val))

    print(f"== SCOPE WORKLIST: {target} ({len(kv)} keys) ==")
    print(f"   delete={len(coll)}  blizzard={len(blz)}  consolidate={len(cons)}  "
          f"translate={len(uniq)}\n")

    print(f"-- A. DELETE (shared already owns) ({len(coll)}) --")
    for k, v in coll:
        print(f'  {k} = "{v}"')
    print(f"\n-- B. BLIZZARD GLOBAL ({len(blz)}) -> replace L[key] with bare global --")
    for k, v, g in blz:
        print(f'  {k} = "{v}"  ->  {g}')
    print(f"\n-- C. CONSOLIDATE ({len(cons)}) -> one shared key (also used elsewhere) --")
    for k, v, others in cons:
        print(f'  {k} = "{v}"')
        if others:
            print(f"       also: {fmt_sites(others)}")
    print(f"\n-- D. TRANSLATE (unique to this scope) ({len(uniq)}) --")
    for k, v in uniq:
        print(f'  {k} = "{v if v is not None else "(expr)"}"')
    return 0


def main(argv=None) -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except AttributeError:
        pass
    ap = argparse.ArgumentParser(description="Locale key/value rollout analysis.")
    ap.add_argument("--scope", metavar="NAME",
                    help="print a per-key worklist for one scope (e.g. OneWoW_Bags)")
    args = ap.parse_args(argv)

    root = Path.cwd()
    scopes, sites, blizz, glob_by_val, n_files = build_indexes(root)
    if args.scope:
        return scope_report(scopes, sites, glob_by_val, args.scope)
    return full_report(scopes, sites, blizz, glob_by_val, n_files)


if __name__ == "__main__":
    sys.exit(main())
