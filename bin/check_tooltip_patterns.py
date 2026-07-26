#!/usr/bin/env python3
"""Pre-commit: TooltipScanner GlobalStrings pattern coverage across all locales.

Mirrors OneWoW/Services/TooltipScanner.lua BuildChargesSearchPattern and asserts
text-match globals used by the scanner exist and are non-empty in every locale
under .wow_docs/.../GlobalStrings/.

Suite locale_verify / locale-parity does NOT cover Blizzard GlobalStrings —
this gate is for match-source format strings (charges, use/equip/unique labels).

Usage:
    python bin/check_tooltip_patterns.py

Exit non-zero on any failure.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Windows consoles often default to a legacy code page; GlobalStrings are UTF-8.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
GLOBALSTRINGS_DIR = (
    ROOT
    / ".wow_docs"
    / "blizzard-interface-resources"
    / "Resources"
    / "GlobalStrings"
)

LOCALES = (
    "enUS",
    "koKR",
    "frFR",
    "deDE",
    "zhCN",
    "esES",
    "zhTW",
    "esMX",
    "ruRU",
    "ptBR",
    "itIT",
)

# Globals used as plain text / pattern prefixes (must exist and be non-empty).
REQUIRED_TEXT_GLOBALS = (
    "USE_COLON",
    "ITEM_SPELL_TRIGGER_ONEQUIP",
    "ITEM_UNIQUE",
    "ITEM_UNIQUE_EQUIPPABLE",
)

# KEY = "value"; with Lua escapes inside the quoted value.
ASSIGN_RE = re.compile(
    r'^([A-Z0-9_]+)\s*=\s*"((?:[^"\\]|\\.)*)"\s*;?\s*$',
    re.M,
)

# Lua pattern magic chars — same set as TooltipScanner PATTERN_MAGIC.
LUA_MAGIC_RE = re.compile(r'([\\^$()%.\[\]*+\-?])')
PIPE4_FIRST_RE = re.compile(r"\|4(.*?):.*?;")


def unescape_lua_string(raw: str) -> str:
    """Decode common Lua short-string escapes used in GlobalStrings."""

    def repl(m: re.Match[str]) -> str:
        ch = m.group(1)
        return {
            "n": "\n",
            "t": "\t",
            "r": "\r",
            '"': '"',
            "'": "'",
            "\\": "\\",
        }.get(ch, ch)

    return re.sub(r"\\(.)", repl, raw)


def parse_globalstrings(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    out: dict[str, str] = {}
    for m in ASSIGN_RE.finditer(text):
        out[m.group(1)] = unescape_lua_string(m.group(2))
    return out


def build_charges_search_pattern(fmt: str) -> str | None:
    """Mirror TooltipScanner BuildChargesSearchPattern. None if unusable."""
    if not fmt:
        return None
    m = PIPE4_FIRST_RE.search(fmt)
    if m:
        return "(%d+) |4" + m.group(1)
    # Non-|4: placeholder-first, then escape, then restore (%d+).
    if "%d" not in fmt:
        return None
    with_ph = fmt.replace("%d", "\x01", 1)
    escaped = LUA_MAGIC_RE.sub(r"%\1", with_ph)
    return escaped.replace("\x01", "(%d+)", 1)


def main() -> int:
    if not GLOBALSTRINGS_DIR.is_dir():
        print(f"!! missing GlobalStrings dir: {GLOBALSTRINGS_DIR}")
        return 1

    failed = False
    for loc in LOCALES:
        path = GLOBALSTRINGS_DIR / f"{loc}.lua"
        if not path.is_file():
            print(f"!! {loc}: missing file {path}")
            failed = True
            continue

        globals_map = parse_globalstrings(path)

        charges = globals_map.get("ITEM_SPELL_CHARGES")
        pattern = build_charges_search_pattern(charges or "")
        if not pattern:
            print(
                f"!! {loc}: ITEM_SPELL_CHARGES cannot build search pattern\n"
                f"   raw={charges!r}"
            )
            failed = True
        else:
            print(f"OK {loc}: charges -> {pattern!r}  (from {charges!r})")

        for key in REQUIRED_TEXT_GLOBALS:
            val = globals_map.get(key)
            if not val:
                print(f"!! {loc}: {key} missing or empty")
                failed = True

    if failed:
        print("\ntooltip-globalstrings-patterns: FAILED")
        return 1

    print("\ntooltip-globalstrings-patterns: OK (11 locales)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
