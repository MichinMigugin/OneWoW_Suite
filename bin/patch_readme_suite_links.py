#!/usr/bin/env python3
"""Replace per-addon 'Part of the OneWoW Suite' sections with link to root README."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REPLACEMENT_TEMPLATE = """## OneWoW Suite

Part of the [OneWoW Suite]({link}). See the suite README for the full addon catalog and install guide.
"""

SECTION_RE = re.compile(
    r"\n## Part of the OneWoW Suite\n.*?(?=\n## |\n---\n\n\*\*Author|\n---\n\n\*\*Authors|\n\n\*\*Author|\n\n\*\*Authors|\Z)",
    re.DOTALL,
)

FOOTER_PATTERNS = [
    (r"\*\*All rights reserved\. Part of the OneWoW Suite\.\*\*", "**All rights reserved.**"),
    (r"\*\*Part of the OneWoW Suite\*\*", "**All rights reserved.**"),
]

INTRO_DEVTOOL = (
    "Part of the OneWoW Suite.",
    "Part of the [OneWoW Suite](../README.md).",
)

# README paths relative to ROOT -> link to suite README
README_PATHS = [
    "OneWoW/README.md",
    "OneWoW_QoL/README.md",
    "OneWoW_Bags/README.md",
    "OneWoW_Notes/README.md",
    "OneWoW_Catalog/README.md",
    "OneWoW_AltTracker/README.md",
    "OneWoW_Trackers/README.md",
    "OneWoW_ShoppingList/README.md",
    "OneWoW_DirectDeposit/README.md",
    "OneWoW_Utility_DevTool/README.md",
    "OneWoW_CatalogData_Journal/README.md",
    "OneWoW_CatalogData_Vendors/README.md",
    "OneWoW_CatalogData_Tradeskills/README.md",
    "OneWoW_CatalogData_Quests/README.md",
    "OneWoW_AltTracker_Storage/README.md",
    "OneWoW_AltTracker_Character/README.md",
    "OneWoW_AltTracker_Professions/README.md",
    "OneWoW_AltTracker_Collections/README.md",
    "OneWoW_AltTracker_Endgame/README.md",
    "OneWoW_AltTracker_Auctions/README.md",
    "OneWoW_AltTracker_Accounting/README.md",
]


def suite_link(readme_rel: str) -> str:
    depth = readme_rel.count("/")
    return ("../" * depth) + "README.md"


def patch_file(readme_rel: str) -> bool:
    path = ROOT / readme_rel
    if not path.is_file():
        print(f"SKIP missing {readme_rel}")
        return False
    text = path.read_text(encoding="utf-8")
    original = text
    link = suite_link(readme_rel)
    replacement = REPLACEMENT_TEMPLATE.format(link=link)

    if "## Part of the OneWoW Suite" in text:
        text = SECTION_RE.sub("\n" + replacement.rstrip() + "\n", text, count=1)
    elif "## OneWoW Suite" not in text:
        # Insert before final --- author block if no section exists
        m = re.search(r"\n---\n\n\*\*Author", text)
        if m:
            text = text[: m.start()] + "\n" + replacement.rstrip() + "\n" + text[m.start() :]

    for old, new in FOOTER_PATTERNS:
        text = text.replace(old, new)

    if readme_rel == "OneWoW_Utility_DevTool/README.md":
        text = text.replace(INTRO_DEVTOOL[0], INTRO_DEVTOOL[1])

    if text != original:
        path.write_text(text, encoding="utf-8", newline="\n")
        print(f"Patched {readme_rel}")
        return True
    print(f"No change {readme_rel}")
    return False


def main() -> None:
    n = sum(1 for p in README_PATHS if patch_file(p))
    print(f"Done: {n} files updated")


if __name__ == "__main__":
    main()
