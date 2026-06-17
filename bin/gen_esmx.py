#!/usr/bin/env python3
"""Generate a scope's esMX locale by mirroring its esES file (UI text is ~identical;
flagged for later Latin-American review). Usage: python gen_esmx.py <path/to/Locales>"""
import sys, re
from pathlib import Path

HEADER = "-- Machine-drafted (Phase 4) — esMX mirrored from esES, pending Latin-American review."

def gen(locales_dir: Path) -> str:
    es = locales_dir / "esES.lua"
    if not es.exists():
        return f"SKIP {locales_dir}: no esES.lua"
    txt = es.read_text(encoding="utf-8")
    # swap the locale string literal esES -> esMX (appears only as the Register code)
    txt = txt.replace('"esES"', '"esMX"')
    # replace an existing machine-drafted header, or insert one after the first blank line
    if "Machine-drafted" in txt:
        txt = re.sub(r"--\s*Machine-drafted[^\n]*", HEADER, txt, count=1)
    else:
        lines = txt.splitlines(keepends=True)
        out, done = [], False
        for ln in lines:
            out.append(ln)
            if not done and ln.strip() == "":
                out.append(HEADER + "\n"); done = True
        txt = "".join(out)
    (locales_dir / "esMX.lua").write_text(txt, encoding="utf-8")
    return f"OK {locales_dir}/esMX.lua"

if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(gen(Path(p)))
