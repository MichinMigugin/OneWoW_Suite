#!/usr/bin/env python3
"""
Scrape Wowhead for loot-spec gear tokens and generate PE data.

Matches items whose Use: text contains
"Create a soulbound item appropriate for your loot" (filter 107).

Writes ns.GearTokenIDs for OneWoW/Services/PredicateEngine/geartokens.lua.

Usage:
    python bin/wowhead/geartoken-ids.py --outfile geartokens.lua
    python bin/wowhead/geartoken-ids.py --outfile path/to/geartokens.lua
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

BIN_DIR = Path(__file__).resolve().parents[1]
if str(BIN_DIR) not in sys.path:
    sys.path.insert(0, str(BIN_DIR))

from lib.wowhead import listview  # noqa: E402

# Description contains (filter 107). Quality splits if a single page truncates.
FILTER = "107;0;Create+a+soulbound+item+appropriate+for+your+loot+"
URLS = [
    f"https://www.wowhead.com/items/quality:0:1?filter={FILTER}",
    f"https://www.wowhead.com/items/quality:2?filter={FILTER}",
    f"https://www.wowhead.com/items/quality:3?filter={FILTER}",
    f"https://www.wowhead.com/items/quality:4:5:6:7?filter={FILTER}",
    # Unsplit fallback (covers qualities the splits miss / overlap-safe union)
    f"https://www.wowhead.com/items?filter={FILTER}",
]

SUITE_ROOT = BIN_DIR.parent
DEFAULT_OUTPUT_DIR = SUITE_ROOT / "OneWoW" / "Services" / "PredicateEngine"
GENERATED_BY = "bin/wowhead/geartoken-ids.py"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scrape Wowhead for loot-spec gear token IDs and write Lua data."
    )
    parser.add_argument("--outfile", required=True, help="Output Lua file (filename or path)")
    return parser.parse_args()


def format_lua(ids: set[int], output_path: Path) -> str:
    return listview.format_ns_id_table(
        ids,
        ns_key="GearTokenIDs",
        output_path=output_path,
        suite_root=SUITE_ROOT,
        generated_by=GENERATED_BY,
        addon_banner="OneWoW Addon File (GENERATED - do not edit manually)",
    )


def main() -> int:
    args = parse_args()
    output_path = listview.resolve_outfile(args.outfile, DEFAULT_OUTPUT_DIR)

    print("Fetching Wowhead gear-token item lists...")
    all_ids = listview.scrape_urls(URLS)
    if not all_ids:
        print(
            "Error: Scrape returned 0 items. Check network or Wowhead page structure.",
            file=sys.stderr,
        )
        return 1

    print(f"\nTotal unique IDs: {len(all_ids)}")
    return listview.write_ids_with_safety(all_ids, output_path, format_lua=format_lua)


if __name__ == "__main__":
    sys.exit(main())
