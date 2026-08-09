#!/usr/bin/env python3
"""Regenerate a locale .lua file from the enUS template, preserving layout.

Walks the enUS reference file line by line and rewrites it for a target locale:
  * header `local ADDON_NAME, X = ...`  -> `local ADDON_NAME = ...`
    (the enUS file owns the `X.L = GetTable(...)` view binding; other locales
     only Register their table, so the second upvalue is dropped).
    Module-style headers (`local _, ns = ...` + `local M = ns.ModuleRegistry:Current()`
    + `:Register(M._scope, ...)`, as used by OneWoW_QoL external modules) are kept
    verbatim — only the locale tag on the Register line is swapped.
  * the `:Register(ADDON_NAME, "enUS", {` tag is swapped to the target locale
  * every `["KEY"] = "value"` line keeps its key/indent/comment layout; the
    value is replaced from the merged translation map
  * the enUS-only footer after the table-closing `})` is dropped

Translation map = (existing locale file, if any) overlaid with --dict JSON.
Any key absent from the map falls back to the enUS value (reported as a TODO),
so output is always valid Lua even mid-translation. Dict/existing values are
RAW Lua string bodies (what sits between the quotes); embedded double quotes are
escaped on emit. Use "by\\nline" (literal backslash-n) for in-string newlines.

Usage:
    python bin/locale_gen.py --enus <enUS.lua> --locale <code> \
        [--existing <file.lua>] [--dict <map.json>] --out <file.lua>
"""
import argparse
import json
import re
import sys
from pathlib import Path

KV_RE = re.compile(r'^(\s*)\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=\s*(.*?),?\s*$')
VAL_RE = re.compile(r'^"((?:[^"\\]|\\.)*)"$|^\'((?:[^\'\\]|\\.)*)\'$')
REGISTER_RE = re.compile(r':Register(?:Shared)?\s*\(')


def parse_existing(path):
    """Return {key: raw_inner_value} from a locale file (long-strings stripped)."""
    text = re.sub(r'\[\[.*?\]\]', '', Path(path).read_text(encoding="utf-8"), flags=re.S)
    out = {}
    for line in text.splitlines():
        m = KV_RE.match(line)
        if not m:
            continue
        vm = VAL_RE.match(m.group(3).strip())
        if vm:
            out[m.group(2)] = vm.group(1) if vm.group(1) is not None else vm.group(2)
    return out


def emit_value(raw):
    """Wrap a raw Lua string body in quotes, matching enUS conventions.

    Values that contain a double quote but no single quote are wrapped in single
    quotes (Lua allows both) so code snippets like 'PlaySound(%d, "%s")' stay
    byte-identical to the enUS reference; everything else uses double quotes with
    bare double quotes escaped."""
    if re.search(r'(?<!\\)"', raw) and "'" not in raw:
        return f"'{raw}'"
    escaped = re.sub(r'(?<!\\)"', r'\\"', raw)
    return f'"{escaped}"'


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--enus", required=True)
    ap.add_argument("--locale", required=True)
    ap.add_argument("--existing")
    ap.add_argument("--dict")
    ap.add_argument("--out", required=True)
    args = ap.parse_args(argv[1:])

    tmap = {}
    if args.existing and Path(args.existing).exists():
        tmap.update(parse_existing(args.existing))
    if args.dict:
        tmap.update(json.loads(Path(args.dict).read_text(encoding="utf-8")))

    src_lines = Path(args.enus).read_text(encoding="utf-8").splitlines()
    out_lines = []
    todo, in_table, done = [], False, False
    for i, line in enumerate(src_lines):
        if i == 0:
            # Addon-table header `local ADDON_NAME, <tbl> = ...` -> drop the 2nd
            # upvalue (its `<tbl>.L = GetTable()` footer is enUS-only and is
            # excluded anyway by the `})` break below). Module-style headers
            # (e.g. `local _, ns = ...` with a following
            # `local M = ns.ModuleRegistry:Current()` and `:Register(M._scope,…)`)
            # are preserved verbatim so the scope expression keeps working.
            if re.match(r'\s*local\s+ADDON_NAME\s*,', line):
                out_lines.append("local ADDON_NAME = ...")
            else:
                out_lines.append(line)
            continue
        if not in_table and REGISTER_RE.search(line):
            in_table = True
            out_lines.append(re.sub(r'"enUS"', f'"{args.locale}"', line))
            continue
        if in_table and line.rstrip() == "})":
            out_lines.append(line)
            done = True
            break
        m = KV_RE.match(line) if in_table else None
        if m:
            indent, key = m.group(1), m.group(2)
            if key in tmap:
                val = tmap[key]
            else:
                vm = VAL_RE.match(m.group(3).strip())
                val = (vm.group(1) if vm.group(1) is not None else vm.group(2)) if vm else ""
                todo.append(key)
            out_lines.append(f'{indent}["{key}"] = {emit_value(val)},')
        else:
            out_lines.append(line)

    if not done:
        print("!! never found table close `})` — aborting", file=sys.stderr)
        return 2
    Path(args.out).write_text("\n".join(out_lines) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {args.out}  ({len(out_lines)} lines)")
    if todo:
        print(f"   {len(todo)} keys fell back to enUS (untranslated):")
        for k in todo:
            print(f"      - {k}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
