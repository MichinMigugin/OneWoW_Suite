#!/usr/bin/env python3
"""Cross-suite locale-key usage analysis for the OneWoW addon suite.

The Locale service resolves a key as:  scope -> shared -> key-name.  So an addon
that binds `local L = ns.L` (its own scope) only sees  own-scope + shared.  An
addon file that instead binds `local L = OneWoW.L` reads the *core* "OneWoW"
scope, which is private to the core addon.  Reading core keys from another addon
"works" only because the key was left in the core scope -- a migration leak.

This tool finds those leaks and tells you where each key belongs:

  * For every addon, list referenced keys NOT satisfied by (own scope U shared).
    These render as the raw key name unless they happen to leak through core.
  * Classify each such leaked key by how many *distinct addons* reference it:
        - exactly one addon            -> move into THAT addon's scope
        - two or more addons           -> promote to the shared scope
  * Flag duplicate keys (defined in core AND in an addon's own scope).
  * Flag dead core keys (defined in core, referenced by no source file).

Run from the suite root:
    python bin/locale_usage.py
    python bin/locale_usage.py --addon OneWoW_QoL     # focus one addon

This is a read-only report; it changes nothing.
"""
import argparse
import re
import sys
from pathlib import Path

# Reuse the same key matcher idea as locale_verify: [ "KEY" ] = "value"
DEF_RE = re.compile(r'\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=')
# Strip Lua [[ ... ]] long-strings before parsing keys: example code inside a
# DEVHELP_BODY block can hold literal ["KEY"] = "value" lines that aren't real keys.
LONGSTRING_RE = re.compile(r'\[\[.*?\]\]', re.S)
# References in source: L["KEY"] / L['KEY'] / OneWoW.L["KEY"] / ns.L["KEY"]
REF_BRACKET_RE = re.compile(r'\bL\s*\[\s*["\']([A-Za-z0-9_]+)["\']\s*\]')
# Dot form L.KEY (filtered against the known key set to avoid matching methods).
REF_DOT_RE = re.compile(r'\bL\.([A-Za-z0-9_]+)\b')


def parse_keys(path):
    text = LONGSTRING_RE.sub("", path.read_text(encoding="utf-8"))
    return {m.group(1) for m in DEF_RE.finditer(text)}


def is_locale_file(path):
    return "Locales" in path.parts


def top_addon(path, root):
    rel = path.relative_to(root)
    return rel.parts[0] if rel.parts else "?"


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".", help="suite root (default: cwd)")
    ap.add_argument("--addon", default=None, help="focus a single addon folder")
    args = ap.parse_args(argv[1:])
    root = Path(args.root).resolve()

    # --- 1. defined keys per scope dir + shared -----------------------------
    shared_keys = set()
    scope_keys = {}          # addon_root -> set(keys)   (top-level scope only)
    core_keys = set()
    for enus in root.glob("**/enUS.lua"):
        parts = enus.relative_to(root).parts
        if "Locales" not in parts:
            continue
        if "Shared" in parts:
            shared_keys |= parse_keys(enus)
            continue
        addon = parts[0]
        scope_keys.setdefault(addon, set())
        scope_keys[addon] |= parse_keys(enus)
        if addon == "OneWoW":
            core_keys |= parse_keys(enus)

    all_defined = set(shared_keys)
    for ks in scope_keys.values():
        all_defined |= ks

    # --- 2. references per addon (source files, not locale files) -----------
    refs = {}                # key -> set(addon_root)
    refs_by_file = {}        # path -> set(keys)
    for lua in root.glob("**/*.lua"):
        if is_locale_file(lua):
            continue
        try:
            text = lua.read_text(encoding="utf-8")
        except Exception:
            continue
        keys = set(REF_BRACKET_RE.findall(text))
        for k in REF_DOT_RE.findall(text):
            if k in all_defined:
                keys.add(k)
        if not keys:
            continue
        addon = top_addon(lua, root)
        refs_by_file[lua] = keys
        for k in keys:
            refs.setdefault(k, set()).add(addon)

    # --- 3. per-addon leak report ------------------------------------------
    addons = sorted(scope_keys)
    if args.addon:
        addons = [a for a in addons if a == args.addon]

    print("=" * 72)
    print("PER-ADDON: referenced keys NOT in (own scope U shared)")
    print("=" * 72)
    for addon in addons:
        own = scope_keys.get(addon, set()) | shared_keys
        # all keys referenced by this addon's source
        ref_here = set()
        for path, keys in refs_by_file.items():
            if top_addon(path, root) == addon:
                ref_here |= keys
        missing = sorted(k for k in ref_here if k not in own)
        if not missing:
            continue
        print(f"\n## {addon}  ({len(missing)} unsatisfied)")
        for k in missing:
            consumers = refs.get(k, set())
            in_core = k in core_keys
            others = sorted(c for c in consumers if c != addon)
            if in_core and len(consumers) == 1:
                verdict = f"-> move to {addon} scope (core leak, single consumer)"
            elif in_core and len(consumers) >= 2:
                verdict = f"-> promote to SHARED (consumers: {', '.join(sorted(consumers))})"
            elif in_core:
                verdict = "-> in core, check consumers"
            else:
                verdict = "!! NOT defined anywhere (renders raw key) "
                if others:
                    verdict += f"(also ref'd by {', '.join(others)})"
            print(f"   {k:48} {verdict}")

    # --- 4. duplicates: core key also in an addon's own scope --------------
    print("\n" + "=" * 72)
    print("DUPLICATES: defined in OneWoW core AND in an addon's own scope")
    print("=" * 72)
    dup_found = False
    for addon in sorted(scope_keys):
        if addon == "OneWoW":
            continue
        dups = sorted(core_keys & scope_keys[addon])
        if dups:
            dup_found = True
            print(f"\n## {addon}  ({len(dups)})")
            for k in dups:
                print(f"   {k}")
    if not dup_found:
        print("   (none)")

    # --- 5. dead core keys: defined in core, referenced by nobody ----------
    print("\n" + "=" * 72)
    print("DEAD CORE KEYS: in OneWoW core scope, no source reference found")
    print("=" * 72)
    dead = sorted(k for k in core_keys if k not in refs)
    if dead:
        for k in dead:
            print(f"   {k}")
    else:
        print("   (none)")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
