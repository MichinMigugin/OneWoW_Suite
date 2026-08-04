"""Shared Wowhead listview scrape + Lua ID-table helpers for bin/wowhead CLIs."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    print("Error: 'requests' is required. Install with: pip install requests", file=sys.stderr)
    sys.exit(1)

LISTVIEW_PATTERN = re.compile(r"var\s+listviewitems\s*=\s*", re.IGNORECASE)

# Fix unquoted JSON keys (e.g. firstseenpatch, popularity) — JavaScript object notation.
UNQUOTED_KEY_PATTERN = re.compile(r"([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)(\s*:)")

LUA_ID_PATTERN = re.compile(r"\[(\d+)\]=true")

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}


def extract_listview_json(html: str) -> str | None:
    """Find and extract the listviewitems JSON array from page HTML."""
    match = LISTVIEW_PATTERN.search(html)
    if not match:
        return None

    start = match.end()
    if start >= len(html):
        return None

    i = start
    while i < len(html) and html[i] in " \t\n\r":
        i += 1
    if i >= len(html) or html[i] != "[":
        return None

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
    """Quote unquoted object keys for valid JSON."""
    return UNQUOTED_KEY_PATTERN.sub(r'\1"\2"\3', raw)


def parse_items_json(raw: str) -> list[dict]:
    """Parse listviewitems JSON and return list of item objects."""
    fixed = fix_json_keys(raw)
    try:
        return json.loads(fixed)
    except json.JSONDecodeError as e:
        raise ValueError(f"JSON parse error: {e}") from e


def extract_ids_from_page(url: str, session: requests.Session) -> set[int]:
    """Fetch a Wowhead page and extract all item IDs from listviewitems."""
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


def scrape_urls(urls: list[str]) -> set[int]:
    """Fetch each URL and return the union of scraped item IDs."""
    session = requests.Session()
    all_ids: set[int] = set()
    for url in urls:
        print(f"  {url}")
        ids = extract_ids_from_page(url, session)
        all_ids.update(ids)
        print(f"    -> {len(ids)} items")
    return all_ids


def resolve_outfile(outfile: str, default_dir: Path) -> Path:
    """Resolve --outfile. Bare filename uses default_dir; paths use as-is."""
    p = Path(outfile)
    if len(p.parts) == 1:
        default_dir.mkdir(parents=True, exist_ok=True)
        return default_dir / p
    out_path = Path(outfile).resolve()
    if not out_path.parent.exists():
        print(f"Error: Parent directory does not exist: {out_path.parent}", file=sys.stderr)
        sys.exit(1)
    return out_path


def read_ids_from_lua(path: Path) -> set[int]:
    """Extract item IDs from a Lua `[id]=true` table file."""
    ids: set[int] = set()
    if not path.exists():
        return ids
    text = path.read_text(encoding="utf-8")
    for m in LUA_ID_PATTERN.finditer(text):
        ids.add(int(m.group(1)))
    return ids


def format_id_table_body(ids: set[int], per_line: int = 10) -> str:
    """Format sorted `[id]=true` entries, ~per_line per line."""
    entries = [f"[{i}]=true" for i in sorted(ids)]
    lines: list[str] = []
    for i in range(0, len(entries), per_line):
        chunk = entries[i : i + per_line]
        lines.append("    " + ", ".join(chunk) + ",")
    return "\n".join(lines)


def format_ns_id_table(
    ids: set[int],
    *,
    ns_key: str,
    output_path: Path,
    suite_root: Path,
    generated_by: str,
    addon_banner: str | None = None,
) -> str:
    """Format a full Lua file assigning `ns.<ns_key> = { … }`."""
    body = format_id_table_body(ids)
    try:
        rel_path = output_path.relative_to(suite_root).as_posix()
    except ValueError:
        rel_path = output_path.as_posix()

    banner = addon_banner or "OneWoW Addon File (GENERATED - do not edit manually)"
    return f"""-- {banner}
-- {rel_path}
-- Generated by {generated_by}
local _, ns = ...

ns.{ns_key} = {{
{body}
}}
"""


def write_ids_with_safety(
    ids: set[int],
    output_path: Path,
    *,
    format_lua,
    drop_fraction: float = 0.05,
) -> int:
    """
    Write Lua via format_lua(ids, output_path). Abort if count drops by more
    than drop_fraction vs an existing file. Backs up before overwrite.
    Returns 0 on success, 1 on abort.
    """
    if output_path.exists():
        existing_ids = read_ids_from_lua(output_path)
        if existing_ids and len(ids) < len(existing_ids) * (1.0 - drop_fraction):
            print(
                f"Error: New count ({len(ids)}) is >{drop_fraction * 100:.0f}% less "
                f"than existing ({len(existing_ids)}). Aborting.",
                file=sys.stderr,
            )
            return 1
        backup_path = output_path.parent / f"{output_path.stem}-bak{output_path.suffix}"
        backup_path.write_text(output_path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backed up to {backup_path}")

    lua_content = format_lua(ids, output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(lua_content, encoding="utf-8")
    print(f"Wrote: {output_path}")
    return 0
