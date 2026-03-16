#!/usr/bin/env python3
"""
Scrape WoWHead item list pages for container/opening items and generate Lua data.

Extracts item IDs from listviewitems JSON embedded in the page source,
then writes ns.AutoOpenItems table format for OneWoW_QoL autoopen module.

Usage:
    python onewow-qol-autoopen-ids.py --outfile autoopen-data.lua
    python onewow-qol-autoopen-ids.py --outfile path/to/autoopen-data.lua

If --outfile is a bare filename, uses the default autoopen module directory.
If --outfile includes directory paths, uses that path as-is.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    print("Error: 'requests' is required. Install with: pip install requests", file=sys.stderr)
    sys.exit(1)

# WoWHead URLs: container items (filter 11;1;0 = Container, Usable)
URLS = [
    "https://www.wowhead.com/items/quality:0:1?filter=11;1;0",  # Poor, Common
    "https://www.wowhead.com/items/quality:2?filter=11;1;0",   # Uncommon
    "https://www.wowhead.com/items/quality:3?filter=11;1;0",   # Rare
    "https://www.wowhead.com/items/quality:4:5:6:7?filter=11;1;0",  # Epic, Legendary, etc.
]

# Items that should be in the list but WoWHead filter may miss (manually curated)
EXTRA_IDS = {
    5523, 5524, 15874, 24476, 45072, 118697, 136926, 143753,
    152106, 152108, 152922, 157822, 157825, 170502, 183822,
    184866, 190339, 198395, 225249,
}

# Match: var listviewitems = ([...]);
LISTVIEW_PATTERN = re.compile(r"var\s+listviewitems\s*=\s*", re.IGNORECASE)

# Fix unquoted JSON keys (e.g. firstseenpatch, popularity) - JavaScript object notation
# Matches key: where key is an unquoted identifier after { or ,
UNQUOTED_KEY_PATTERN = re.compile(r"([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)(\s*:)")

SCRIPT_DIR = Path(__file__).resolve().parent
SUITE_ROOT = SCRIPT_DIR.parent
DEFAULT_OUTPUT_DIR = SUITE_ROOT / "OneWoW_QoL" / "Modules" / "external" / "autoopen"
MANUAL_DATA_PATH = DEFAULT_OUTPUT_DIR / "autoopen-data.lua"

# Match [123]=true in Lua table
LUA_ID_PATTERN = re.compile(r"\[(\d+)\]=true")

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scrape WoWHead for autoopen item IDs and write Lua data.")
    parser.add_argument("--outfile", required=True, help="Output Lua file (filename or path)")
    return parser.parse_args()


def resolve_output_path(outfile: str) -> Path:
    """Resolve --outfile to absolute path. Bare filename uses DEFAULT_OUTPUT_DIR."""
    p = Path(outfile)
    if len(p.parts) == 1:
        output_dir = DEFAULT_OUTPUT_DIR
        if not output_dir.exists():
            print(f"Error: Default output directory does not exist: {output_dir}", file=sys.stderr)
            sys.exit(1)
        return output_dir / p
    out_path = Path(outfile).resolve()
    if not out_path.parent.exists():
        print(f"Error: Parent directory does not exist: {out_path.parent}", file=sys.stderr)
        sys.exit(1)
    return out_path


def extract_listview_json(html: str) -> str | None:
    """Find and extract the listviewitems JSON array from page HTML."""
    match = LISTVIEW_PATTERN.search(html)
    if not match:
        return None

    start = match.end()
    if start >= len(html):
        return None

    # Find the opening bracket of the array
    i = start
    while i < len(html) and html[i] in " \t\n\r":
        i += 1
    if i >= len(html) or html[i] != "[":
        return None

    # Bracket-matching to extract the full array
    depth = 0
    in_string = False
    escape = False
    quote_char = None
    begin = i

    while i < len(html):
        c = html[i]
        if escape:
            escape = False
            i += 1
            continue
        if c == "\\" and in_string:
            escape = True
            i += 1
            continue
        if in_string:
            if c == quote_char:
                in_string = False
            i += 1
            continue
        if c in ('"', "'"):
            in_string = True
            quote_char = c
            i += 1
            continue
        if c == "[" or c == "{":
            depth += 1
            i += 1
            continue
        if c == "]" or c == "}":
            depth -= 1
            if depth == 0 and c == "]":
                return html[begin : i + 1]
            i += 1
            continue
        i += 1

    return None


def fix_json_keys(raw: str) -> str:
    """Quote unquoted object keys (firstseenpatch, popularity, etc.) for valid JSON."""
    return UNQUOTED_KEY_PATTERN.sub(r'\1"\2"\3', raw)


def parse_items_json(raw: str) -> list[dict]:
    """Parse listviewitems JSON and return list of item objects."""
    fixed = fix_json_keys(raw)
    try:
        return json.loads(fixed)
    except json.JSONDecodeError as e:
        # Try to salvage - sometimes only certain keys need fixing
        raise ValueError(f"JSON parse error: {e}") from e


def extract_ids_from_page(url: str, session: requests.Session) -> set[int]:
    """Fetch a WoWHead page and extract all item IDs from listviewitems."""
    ids: set[int] = set()
    try:
        resp = session.get(url, headers=HEADERS, timeout=30)
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f"  Warning: Failed to fetch {url}: {e}", file=sys.stderr)
        return ids

    raw_json = extract_listview_json(resp.text)
    if not raw_json:
        print(f"  Warning: No listviewitems found in {url}", file=sys.stderr)
        return ids

    try:
        items = parse_items_json(raw_json)
    except ValueError as e:
        print(f"  Warning: Could not parse JSON from {url}: {e}", file=sys.stderr)
        return ids

    for item in items:
        if isinstance(item, dict) and "id" in item:
            try:
                ids.add(int(item["id"]))
            except (TypeError, ValueError):
                pass

    return ids


def read_ids_from_lua(path: Path) -> set[int]:
    """Extract item IDs from a Lua AutoOpenItems table file."""
    ids: set[int] = set()
    if not path.exists():
        return ids
    text = path.read_text(encoding="utf-8")
    for m in LUA_ID_PATTERN.finditer(text):
        ids.add(int(m.group(1)))
    return ids


def format_lua_table(ids: set[int], output_path: Path) -> str:
    """Format item IDs as ns.AutoOpenItems Lua table."""
    sorted_ids = sorted(ids)
    entries = [f"[{i}]=true" for i in sorted_ids]

    # Match autoopen-data.lua style: ~10 entries per line
    lines: list[str] = []
    per_line = 10
    for i in range(0, len(entries), per_line):
        chunk = entries[i : i + per_line]
        lines.append("    " + ", ".join(chunk) + ",")

    body = "\n".join(lines)
    try:
        rel_path = output_path.relative_to(SUITE_ROOT)
    except ValueError:
        rel_path = output_path

    return f"""-- OneWoW_QoL Addon File (GENERATED - do not edit manually)
-- {rel_path}
-- Generated by bin/onewow-qol-autoopen-ids.py
local addonName, ns = ...

ns.AutoOpenItems = {{
{body}
}}
"""


def main() -> int:
    args = parse_args()
    output_path = resolve_output_path(args.outfile)

    print("Fetching WoWHead item lists...")
    session = requests.Session()
    scraped_ids: set[int] = set()
    all_ids: set[int] = set()

    for url in URLS:
        print(f"  {url}")
        ids = extract_ids_from_page(url, session)
        scraped_ids.update(ids)
        all_ids.update(ids)
        print(f"    -> {len(ids)} items")

    if not scraped_ids:
        print("Error: Scrape returned 0 items. Check network or WoWHead page structure.", file=sys.stderr)
        return 1

    all_ids.update(EXTRA_IDS)

    print(f"\nTotal unique IDs: {len(all_ids)} (including {len(EXTRA_IDS)} extra)")

    # Compare against manual autoopen-data.lua; log IDs in manual but not in scrape
    manual_ids = read_ids_from_lua(MANUAL_DATA_PATH)
    missing_from_scrape = sorted(manual_ids - all_ids)
    if missing_from_scrape:
        print(f"\nIn {MANUAL_DATA_PATH.name} but NOT in scrape ({len(missing_from_scrape)}):")
        for i in missing_from_scrape:
            print(f"  {i}")

    # Safety: >5% drop if overwriting existing file
    if output_path.exists():
        existing_ids = read_ids_from_lua(output_path)
        if existing_ids and len(all_ids) < len(existing_ids) * 0.95:
            print(
                f"Error: New count ({len(all_ids)}) is >5% less than existing ({len(existing_ids)}). Aborting.",
                file=sys.stderr,
            )
            return 1
        # Backup before overwrite
        backup_path = output_path.parent / f"{output_path.stem}-bak{output_path.suffix}"
        backup_path.write_text(output_path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backed up to {backup_path}")

    lua_content = format_lua_table(all_ids, output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(lua_content, encoding="utf-8")

    print(f"Wrote: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
