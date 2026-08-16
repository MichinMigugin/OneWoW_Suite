#!/usr/bin/env python3
"""Pre-commit hook: forbid CP1252-mojibake of UTF-8 in locale string values.

Catches the failure mode where a UTF-8 translation is decoded as Windows-1252
and saved back as UTF-8 (`ÐŸÐ¾Ñ‡Ñ‚Ð°` instead of `Почта`). `locale_verify`
does not catch this: key parity and printf specifiers still match.

Scope: `["KEY"] = "value"` assignments in `Locales/*.lua`. Comments are ignored.
C1 controls (U+0081, U+009D, ...) must round-trip as raw bytes; latin-1 encode
is not enough.

Usage:
    python bin/check_locale_encoding.py                       # every Locales/ scope
    python bin/check_locale_encoding.py <path/to/Locales> ...
    python bin/check_locale_encoding.py <path/to/foo.lua> ... # pre-commit passes files

Exit code is non-zero if any value looks like mojibake.
See OneWoW/Docs/LOCALES.md.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

KEY_RE = re.compile(r'\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=\s*"((?:[^"\\]|\\.)*)"')
# Also match single-quoted Lua values (emit_value wraps in '...' when the body
# contains a double quote).
KEY_RE_SQ = re.compile(r"\[\s*\"((?:[^\"\\]|\\.)*)\"\s*\]\s*=\s*'((?:[^'\\]|\\.)*)'")
LONGSTRING_RE = re.compile(r"\[\[.*?\]\]", re.S)

CYRILLIC = re.compile(r"[\u0400-\u04FF]")
HANGUL = re.compile(r"[\u1100-\u11FF\u3130-\u318F\uAC00-\uD7AF]")
CJK = re.compile(r"[\u3400-\u9FFF\uF900-\uFAFF]")


def reverse_cp1252_mojibake(s: str) -> str:
    raw = bytearray()
    for ch in s:
        o = ord(ch)
        if o < 256:
            raw.append(o)
        else:
            raw.append(ch.encode("cp1252")[0])
    return bytes(raw).decode("utf-8")


def already_has_script(s: str, loc: str) -> bool:
    """True when the value already contains the locale's native letters."""
    if loc == "ruRU":
        return bool(CYRILLIC.search(s))
    if loc == "koKR":
        return bool(HANGUL.search(s))
    if loc in ("zhCN", "zhTW"):
        return bool(CJK.search(s))
    return False


def is_mojibake(s: str, loc: str) -> bool:
    if not s or all(ord(c) < 128 for c in s):
        return False
    if already_has_script(s, loc):
        return False
    try:
        recovered = reverse_cp1252_mojibake(s)
    except (UnicodeEncodeError, UnicodeDecodeError, LookupError):
        return False
    return recovered != s


def iter_values(text: str):
    text = LONGSTRING_RE.sub("", text)
    for m in KEY_RE.finditer(text):
        yield m.group(1), m.group(2)
    for m in KEY_RE_SQ.finditer(text):
        yield m.group(1), m.group(2)


def locale_code_from_path(path: Path) -> str:
    return path.stem


def check_file(path: Path) -> list[tuple[str, str]]:
    loc = locale_code_from_path(path)
    text = path.read_text(encoding="utf-8")
    hits: list[tuple[str, str]] = []
    for key, val in iter_values(text):
        if is_mojibake(val, loc):
            hits.append((key, val))
    return hits


def files_from_args(args: list[str]) -> list[Path]:
    if not args:
        root = Path(".")
        out: list[Path] = []
        for ref in list(root.glob("**/Locales/**/*.lua")) + list(root.glob("**/Locales/*.lua")):
            if ".cache" in ref.parts or ".wow_docs" in ref.parts:
                continue
            if ref.name == "LocaleManager.lua":
                continue
            if ref not in out:
                out.append(ref)
        return sorted(out)

    files: list[Path] = []
    for a in args:
        p = Path(a)
        if p.is_dir():
            for f in sorted(p.glob("*.lua")):
                if f.name != "LocaleManager.lua":
                    files.append(f)
        elif p.suffix == ".lua" and p.name != "LocaleManager.lua":
            files.append(p)
    return files


def main(argv: list[str]) -> int:
    files = files_from_args(argv[1:])
    rc = 0
    for path in files:
        hits = check_file(path)
        if not hits:
            continue
        rc = 1
        print(f"{path}: {len(hits)} value(s) look like CP1252-mojibake of UTF-8")
        for key, val in hits[:8]:
            preview = val.replace("\n", "\\n")
            if len(preview) > 80:
                preview = preview[:77] + "..."
            print(f"    [{key}] = {preview!r}")
        if len(hits) > 8:
            print(f"    ... and {len(hits) - 8} more")
    if rc:
        print()
        print("Fix: restore real UTF-8 (the file was likely saved after a")
        print("Windows-1252 round-trip). Do not leave Latin-1 soup in locale")
        print("values. See OneWoW/Docs/LOCALES.md.")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
