#!/usr/bin/env python3
"""Move a set of locale keys from one scope's Locales dir into another's.

Relocates every `["KEY"] = "value",` line for the listed keys out of each
<locale>.lua in --src and into the matching <locale>.lua in --dst, for every
locale present in both directories.  Values are preserved verbatim per locale,
so already-translated strings move intact (no re-translation).  Lines are
inserted just before the closing `})` of the destination Register block, under a
one-line provenance comment.

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


def process_locale(src_path, dst_path, keys, apply):
    src_lines = src_path.read_text(encoding="utf-8").splitlines(keepends=True)
    matchers = [(k, line_matcher(k)) for k in keys]

    moved = {}          # key -> original line text
    kept = []
    for ln in src_lines:
        hit = None
        for k, rx in matchers:
            if rx.match(ln):
                hit = k
                break
        if hit is not None:
            moved[hit] = ln if ln.endswith("\n") else ln + "\n"
        else:
            kept.append(ln)

    found = list(moved)               # preserves src order
    missing = [k for k in keys if k not in moved]

    # build insertion block in src order
    block = [f"\n    -- migrated from {src_path.parent.parent.name} scope\n"]
    block += [moved[k] for k in found]

    dst_lines = dst_path.read_text(encoding="utf-8").splitlines(keepends=True)
    open_at = None
    for i, ln in enumerate(dst_lines):
        if OPEN_RE.search(ln):
            open_at = i
            break
    if open_at is None:
        raise RuntimeError(f"no Register(...{{ opening found in {dst_path}")

    # insert immediately after the opening `{` line (top of the table)
    new_dst = dst_lines[:open_at + 1] + block + dst_lines[open_at + 1:]

    if apply and found:
        src_path.write_text("".join(kept), encoding="utf-8")
        dst_path.write_text("".join(new_dst), encoding="utf-8")

    return found, missing


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
    print(f"{'APPLY' if args.apply else 'DRY-RUN'}: moving {len(keys)} keys")
    print(f"  src: {src}")
    print(f"  dst: {dst}\n")

    locales = sorted(p.name for p in src.glob("*.lua")
                     if (dst / p.name).exists())
    any_missing = False
    for name in locales:
        found, missing = process_locale(src / name, dst / name, keys, args.apply)
        flag = "" if not missing else f"  !! {len(missing)} not found"
        print(f"  {name:10} moved {len(found):4}{flag}")
        if missing:
            any_missing = True
            for k in missing[:10]:
                print(f"        - {k}")
    if any_missing:
        print("\n!! some keys were absent in some locales — investigate before --apply")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
