#!/usr/bin/env python3
"""Verify locale-file parity for a scope's Locales directory.

For every <locale>.lua next to enUS.lua, checks:
  * key parity   - same set of keys as enUS (reports missing / extra)
  * format specs - each shared key has the same multiset of printf-style
                   directives (%s, %d, %d%%, ...) as the enUS value

Usage:
    python bin/locale_verify.py <path/to/Locales> [more/Locales ...]

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
        status = "OK" if not (missing or extra or spec) else "FAIL"
        if status == "FAIL":
            ok_all = False
        print(f"   {path.stem:6} {len(loc)}/{len(ref)} | "
              f"miss {len(missing)} extra {len(extra)} spec {len(spec)} {status}")
        for k in sorted(missing):
            print(f"        - missing: {k}")
        for k in sorted(extra):
            print(f"        + extra:   {k}")
        for k in spec:
            print(f"        ~ spec:    {k}  enUS={ref[k]} vs {loc[k]}")
    return ok_all


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    ok = True
    for d in argv[1:]:
        ok = verify_dir(d) and ok
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
