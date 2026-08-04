#!/usr/bin/env python3
"""
Scrape Wowhead item list pages for container/opening items and generate Lua data.

Writes ns.AutoOpenItems for the OneWoW_QoL autoopen module.

Usage:
    python bin/wowhead/autoopen-ids.py --outfile autoopen-data.lua
    python bin/wowhead/autoopen-ids.py --outfile path/to/autoopen-data.lua

If --outfile is a bare filename, uses the default autoopen module directory.
If --outfile includes directory paths, uses that path as-is.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

BIN_DIR = Path(__file__).resolve().parents[1]
if str(BIN_DIR) not in sys.path:
    sys.path.insert(0, str(BIN_DIR))

from lib.wowhead import listview  # noqa: E402

# Wowhead URLs: container items (filter 11;1;0 = Container, Usable)
URLS = [
    "https://www.wowhead.com/items/quality:0:1?filter=11;1;0",  # Poor, Common
    "https://www.wowhead.com/items/quality:2?filter=11;1;0",  # Uncommon
    "https://www.wowhead.com/items/quality:3?filter=11;1;0",  # Rare
    "https://www.wowhead.com/items/quality:4:5:6:7?filter=11;1;0",  # Epic, Legendary, etc.
]

# Items that should be in the list but Wowhead filter may miss (manually curated)
EXTRA_IDS = {
    5523, 5524, 15874, 24476, 45072, 118697, 136926, 143753,
    152106, 152108, 152922, 157822, 157825, 170502, 183822,
    184866, 190339, 198395, 225249, 270244, 270247, 264914,
}

SUITE_ROOT = BIN_DIR.parent
DEFAULT_OUTPUT_DIR = SUITE_ROOT / "OneWoW_QoL" / "Modules" / "external" / "autoopen"
MANUAL_DATA_PATH = DEFAULT_OUTPUT_DIR / "autoopen-data.lua"
GENERATED_BY = "bin/wowhead/autoopen-ids.py"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scrape Wowhead for autoopen item IDs and write Lua data."
    )
    parser.add_argument("--outfile", required=True, help="Output Lua file (filename or path)")
    return parser.parse_args()


def format_lua(ids: set[int], output_path: Path) -> str:
    return listview.format_ns_id_table(
        ids,
        ns_key="AutoOpenItems",
        output_path=output_path,
        suite_root=SUITE_ROOT,
        generated_by=GENERATED_BY,
        addon_banner="OneWoW_QoL Addon File (GENERATED - do not edit manually)",
    )


def main() -> int:
    args = parse_args()
    output_path = listview.resolve_outfile(args.outfile, DEFAULT_OUTPUT_DIR)

    print("Fetching Wowhead item lists...")
    scraped_ids = listview.scrape_urls(URLS)
    if not scraped_ids:
        print(
            "Error: Scrape returned 0 items. Check network or Wowhead page structure.",
            file=sys.stderr,
        )
        return 1

    all_ids = set(scraped_ids)
    all_ids.update(EXTRA_IDS)
    print(f"\nTotal unique IDs: {len(all_ids)} (including {len(EXTRA_IDS)} extra)")

    manual_ids = listview.read_ids_from_lua(MANUAL_DATA_PATH)
    missing_from_scrape = sorted(manual_ids - all_ids)
    if missing_from_scrape:
        print(f"\nIn {MANUAL_DATA_PATH.name} but NOT in scrape ({len(missing_from_scrape)}):")
        for i in missing_from_scrape:
            print(f"  {i}")

    return listview.write_ids_with_safety(all_ids, output_path, format_lua=format_lua)


if __name__ == "__main__":
    sys.exit(main())
