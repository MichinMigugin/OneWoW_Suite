#!/usr/bin/env python3
"""Move a set of locale keys from one scope's Locales dir into another's.

Relocates every `["KEY"] = "value",` line for the listed keys out of EVERY
<locale>.lua in --src and into the matching <locale>.lua in --dst.  Values are
preserved verbatim per locale, so already-translated strings move intact (no
re-translation).  Lines are inserted just after the opening of the destination
Register block, under a one-line provenance comment.

The key is removed from ALL src locales (so the source scope never retains it,
keeping src parity intact) but only inserted into dst locales that exist.  If src
has a locale dst lacks (e.g. core has 11 languages, the target addon only 6), the
key is dropped for that language — reported, and regenerated when that scope is
later translated.

This is the mechanical half of the "locale leak" cleanup: strings that were left
in the core "OneWoW" scope after their feature moved to another addon get
relocated to the scope that actually owns them (the addon's own scope, or the
shared scope when more than one addon needs them).

Usage:
    python bin/locale_migrate.py --src <Locales> --dst <Locales> --keys <file> [--apply]

--keys is a text file, one KEY per line (blank lines / # comments ignored).
Without --apply it is a dry run (prints what would move, changes nothing).
Run bin/locale_verify.py on both dirs afterwards to confirm parity holds.
"""
import argparse
import re
import sys
from pathlib import Path

# The opening line of a Register table, e.g.
#   OneWoW.Locale:Register(ADDON_NAME, "enUS", {
#   OneWoW.Locale:RegisterShared("enUS", {
# Inserting right AFTER this line is unambiguous; matching the closing `})`
# is not, because a `})` can appear inside a [[ ]] long-string (e.g. a
# DEVHELP_BODY help block that shows example code) and be matched first.
OPEN_RE = re.compile(r':Register(?:Shared)?\s*\(.*\{\s*$')


def load_keys(path):
    out = []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(line)
    return out


def line_matcher(key):
    # exact-key line:  [ "KEY" ] = ...
    return re.compile(r'^\s*\[\s*"' + re.escape(key) + r'"\s*\]\s*=')


def extract_from_src(src_path, keys, apply):
    """Remove matched key lines from src_path. Return {key: line} in file order."""
    src_lines = src_path.read_text(encoding="utf-8").splitlines(keepends=True)
    matchers = [(k, line_matcher(k)) for k in keys]
    moved, kept = {}, []
    for ln in src_lines:
        hit = next((k for k, rx in matchers if rx.match(ln)), None)
        if hit is not None:
            moved[hit] = ln if ln.endswith("\n") else ln + "\n"
        else:
            kept.append(ln)
    if apply and moved:
        src_path.write_text("".join(kept), encoding="utf-8")
    return moved


def insert_into_dst(dst_path, moved, scope_name, apply):
    """Insert moved lines (file order) right after the dst Register opening line."""
    dst_lines = dst_path.read_text(encoding="utf-8").splitlines(keepends=True)
    open_at = next((i for i, ln in enumerate(dst_lines) if OPEN_RE.search(ln)), None)
    if open_at is None:
        raise RuntimeError(f"no Register(...{{ opening found in {dst_path}")
    block = [f"\n    -- migrated from {scope_name} scope\n"] + list(moved.values())
    new_dst = dst_lines[:open_at + 1] + block + dst_lines[open_at + 1:]
    if apply:
        dst_path.write_text("".join(new_dst), encoding="utf-8")


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dst", required=True)
    ap.add_argument("--keys", required=True)
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args(argv[1:])

    src = Path(args.src)
    dst = Path(args.dst)
    keys = load_keys(args.keys)
    scope_name = src.parent.name
    print(f"{'APPLY' if args.apply else 'DRY-RUN'}: moving {len(keys)} keys")
    print(f"  src: {src}")
    print(f"  dst: {dst}\n")

    dst_names = {p.name for p in dst.glob("*.lua")}
    dropped = {}  # locale name -> [keys removed from src but with no dst home]
    for src_path in sorted(src.glob("*.lua")):
        moved = extract_from_src(src_path, keys, args.apply)
        if not moved:
            continue
        name = src_path.name
        if name in dst_names:
            insert_into_dst(dst / name, moved, scope_name, args.apply)
            print(f"  {name:10} moved {len(moved):4} -> dst")
        else:
            dropped[name] = list(moved)
            print(f"  {name:10} removed {len(moved):4} (no dst locale — dropped)")

    if dropped:
        langs = ", ".join(sorted(dropped))
        print(f"\n!! dst lacks these locales, so values were dropped (regenerate on "
              f"translation): {langs}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
