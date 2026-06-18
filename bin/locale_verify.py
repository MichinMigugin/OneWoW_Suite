#!/usr/bin/env python3
"""Verify locale-file parity for a scope's Locales directory.

For every <locale>.lua next to enUS.lua, checks:
  * key parity   - same set of keys as enUS (reports missing / extra)
  * format specs - each shared key has the same multiset of printf-style
                   directives (%s, %d, %d%%, ...) as the enUS value
  * duplicate keys - no key is assigned twice in the same table (Lua keeps the
                   last assignment; the linter flags the earlier one as
                   `duplicate-index`). enUS is checked for this too.

Usage:
    python bin/locale_verify.py                       # no args: scan every Locales/ scope
    python bin/locale_verify.py <path/to/Locales> ... # one or more Locales dirs
    python bin/locale_verify.py <path/to/foo.lua> ... # locale files -> their parent scope(s)

Args may be Locales directories OR individual locale files (each file is mapped to its
parent Locales dir, deduped). With no args, every Locales/ scope in the repo is checked.
This lets it run both standalone and as a pre-commit hook (which passes changed files).

Exit code is non-zero if any locale fails, so it can gate a commit.
"""
import re
import sys
from pathlib import Path

KEY_RE = re.compile(r'\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=\s*"((?:[^"\\]|\\.)*)"')
# printf-style directive: %, optional flags/width/precision, conversion char.
# %% is a literal percent and is captured so it is compared too.
# NOTE: the space flag (`% d`) is intentionally excluded. It is effectively never
# used in WoW addon strings, whereas literal "30% durability" / "5% chance" text
# (a percent sign followed by a space and a word starting with s/d/f/g/x/c) is
# common — keeping the space flag made those literals match as bogus directives.
SPEC_RE = re.compile(r'%[-+#0]*[0-9]*\.?[0-9]*[sdfgxXc%]')


# Lua [[ ... ]] long-string (e.g. a DEVHELP_BODY help block). Its contents must be
# stripped before key extraction: example code inside it can contain literal
# `["KEY"] = "value"` lines that would otherwise be miscounted as real keys (this
# masked a migration bug that inserted keys *inside* such a string).
LONGSTRING_RE = re.compile(r'\[\[.*?\]\]', re.S)


def parse(path):
    """Return {key: sorted_specs} for one locale file."""
    text = path.read_text(encoding="utf-8")
    text = LONGSTRING_RE.sub("", text)
    out = {}
    for m in KEY_RE.finditer(text):
        key, val = m.group(1), m.group(2)
        out[key] = sorted(SPEC_RE.findall(val))
    return out


def find_dupes(path):
    """Return {key: count} for keys assigned more than once in the table.

    Lua's table constructor keeps the LAST assignment, so an earlier duplicate is
    dead code the linter flags as `duplicate-index`. Long-strings are stripped first
    so example `["K"] = "v"` lines inside a help block are not miscounted.
    """
    text = path.read_text(encoding="utf-8")
    text = LONGSTRING_RE.sub("", text)
    counts = {}
    for m in KEY_RE.finditer(text):
        counts[m.group(1)] = counts.get(m.group(1), 0) + 1
    return {k: c for k, c in counts.items() if c > 1}


def verify_dir(locales_dir):
    locales_dir = Path(locales_dir)
    ref_path = locales_dir / "enUS.lua"
    if not ref_path.exists():
        print(f"!! {locales_dir}: no enUS.lua reference")
        return False

    ref = parse(ref_path)
    ref_keys = set(ref)
    ok_all = True
    print(f"== {locales_dir}  (enUS = {len(ref)} keys)")

    # enUS is the reference for key parity, but still check it for duplicate keys.
    ref_dupes = find_dupes(ref_path)
    if ref_dupes:
        ok_all = False
        print(f"   {'enUS':6} {len(ref)}/{len(ref)} | dup {len(ref_dupes)} FAIL")
        for k in sorted(ref_dupes):
            print(f"        * dup-key: {k} (x{ref_dupes[k]})")

    for path in sorted(locales_dir.glob("*.lua")):
        if path.name == "enUS.lua":
            continue
        # Only treat files that actually register locale keys.
        loc = parse(path)
        if not loc:
            continue
        loc_keys = set(loc)
        missing = ref_keys - loc_keys
        extra = loc_keys - ref_keys
        spec = sorted(k for k in (ref_keys & loc_keys) if ref[k] != loc[k])
        dupes = find_dupes(path)
        status = "OK" if not (missing or extra or spec or dupes) else "FAIL"
        if status == "FAIL":
            ok_all = False
        print(f"   {path.stem:6} {len(loc)}/{len(ref)} | "
              f"miss {len(missing)} extra {len(extra)} spec {len(spec)} "
              f"dup {len(dupes)} {status}")
        for k in sorted(missing):
            print(f"        - missing: {k}")
        for k in sorted(extra):
            print(f"        + extra:   {k}")
        for k in spec:
            print(f"        ~ spec:    {k}  enUS={ref[k]} vs {loc[k]}")
        for k in sorted(dupes):
            print(f"        * dup-key: {k} (x{dupes[k]})")
    return ok_all


def scope_dirs_from_args(args):
    """Map each arg (a Locales dir, or a file inside one) to its scope dir; dedupe, keep order."""
    dirs = []
    for a in args:
        p = Path(a)
        d = p if p.is_dir() else p.parent
        if d not in dirs:
            dirs.append(d)
    return dirs


def all_scope_dirs(root=Path(".")):
    """Every Locales/ scope in the repo (excludes vendored/cached reference trees)."""
    refs = sorted(root.glob("**/Locales/**/enUS.lua")) + sorted(root.glob("**/Locales/enUS.lua"))
    dirs = []
    for ref in refs:
        if ".cache" in ref.parts or ".wow_docs" in ref.parts:
            continue
        d = ref.parent
        if d not in dirs:
            dirs.append(d)
    return dirs


def main(argv):
    dirs = scope_dirs_from_args(argv[1:]) if len(argv) > 1 else all_scope_dirs()
    if not dirs:
        print("locale_verify: no Locales scopes to check")
        return 0
    ok = True
    for d in dirs:
        ok = verify_dir(d) and ok
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
