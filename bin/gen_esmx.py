#!/usr/bin/env python3
"""Generate a scope's esMX locale by mirroring its esES file and applying Latin-American
term conventions (UI text is otherwise ~identical; flagged for later native review).
Usage: python gen_esmx.py <path/to/Locales>"""
import sys, re
from pathlib import Path

HEADER = "-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review."

# Castilian -> Latin-American term normalizations, applied to string VALUES only.
# Whole-word, case-sensitive; longest stems first so e.g. "pulsar" wins over "pulsa".
# "presionar" matches Blizzard's official es_MX client verb; "mouse" is LatAm-standard.
LATAM_SUBS = [
    (r"\bpulsando\b", "presionando"),
    (r"\bPulsando\b", "Presionando"),
    (r"\bpulsará\b",  "presionará"),
    (r"\bpulsar\b",   "presionar"),
    (r"\bPulsar\b",   "Presionar"),
    (r"\bpulsa\b",    "presiona"),
    (r"\bPulsa\b",    "Presiona"),
    (r"\bpulse\b",    "presione"),
    (r"\bPulse\b",    "Presione"),
    (r"\bratón\b",    "mouse"),
    (r"\bRatón\b",    "Mouse"),
    (r"\bRATÓN\b",    "MOUSE"),
]

def latam(txt: str) -> str:
    for pat, repl in LATAM_SUBS:
        txt = re.sub(pat, repl, txt)
    return txt

def gen(locales_dir: Path) -> str:
    es = locales_dir / "esES.lua"
    if not es.exists():
        return f"SKIP {locales_dir}: no esES.lua"
    txt = es.read_text(encoding="utf-8")
    # swap the locale string literal esES -> esMX (appears only as the Register code)
    txt = txt.replace('"esES"', '"esMX"')
    # apply Latin-American term conventions
    txt = latam(txt)
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
