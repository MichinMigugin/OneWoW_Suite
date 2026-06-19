#!/usr/bin/env python3
"""Generate OneWoW_QoL/MODULES.md from module.lua + Locales/enUS.lua."""
from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXT = ROOT / "OneWoW_QoL" / "Modules" / "external"

CAT_LABEL = {
    "AUTOMATION": "Automation",
    "INTERFACE": "Interface",
    "SOCIAL": "Social",
    "ECONOMY": "Economy",
    "UTILITY": "Utility",
    "COMBAT": "Combat",
}

CAT_ORDER = ["AUTOMATION", "INTERFACE", "SOCIAL", "ECONOMY", "UTILITY", "COMBAT"]


def grab(text: str, key: str) -> str:
    m = re.search(rf'\["{re.escape(key)}"\]\s*=\s*"((?:\\.|[^"\\])*)"', text)
    if not m:
        m = re.search(rf"{key}\s*=\s*\"((?:\\.|[^\"\\])*)\"", text)
    return m.group(1) if m else ""


def main() -> None:
    mods: list[dict] = []
    for folder in sorted(EXT.iterdir()):
        mod_lua = folder / "module.lua"
        if not mod_lua.is_file():
            continue
        text = mod_lua.read_text(encoding="utf-8")
        mid = grab(text, "id") or folder.name
        title_key = grab(text, "title")
        desc_key = grab(text, "description")
        category = grab(text, "category")

        loc = folder / "Locales" / "enUS.lua"
        title = desc = ""
        if loc.is_file():
            loc_text = loc.read_text(encoding="utf-8")
            if title_key:
                title = grab(loc_text, title_key)
            if desc_key:
                desc = grab(loc_text, desc_key)

        readme = folder / "README.md"
        mods.append(
            {
                "id": mid,
                "folder": folder.name,
                "title": title or mid,
                "desc": desc,
                "category": category or "INTERFACE",
                "readme": readme if readme.is_file() else None,
            }
        )

    by_cat: dict[str, list[dict]] = defaultdict(list)
    for m in mods:
        by_cat[m["category"]].append(m)

    lines: list[str] = [
        "# OneWoW QoL — External Modules",
        "",
        "Catalog of toggleable features under `Modules/external/`. Each module is independent — enable only what you want in the QoL Features UI (`/1wqol`).",
        "",
        "Module authors: [DEVELOPERS.md](DEVELOPERS.md). Suite docs: [OneWoW/Docs/README.md](../OneWoW/Docs/README.md).",
        "",
        f"**{len(mods)} modules** across {len(by_cat)} categories (matches `module.lua` `category` values in the Features UI).",
        "",
        "---",
        "",
    ]

    for cat in CAT_ORDER:
        if cat not in by_cat:
            continue
        label = CAT_LABEL.get(cat, cat.title())
        lines.append(f"## {label}")
        lines.append("")
        for m in sorted(by_cat[cat], key=lambda x: x["title"].lower()):
            link = ""
            if m["readme"]:
                rel = m["readme"].relative_to(ROOT / "OneWoW_QoL").as_posix()
                link = f" — [details]({rel})"
            lines.append(f"### {m['title']}")
            lines.append("")
            if m["desc"]:
                lines.append(m["desc"])
                lines.append("")
            lines.append(f"- **Module id:** `{m['id']}` · **Folder:** `Modules/external/{m['folder']}/`{link}")
            lines.append("")

    out = ROOT / "OneWoW_QoL" / "MODULES.md"
    out.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8", newline="\n")
    print(f"Wrote {out} ({len(mods)} modules)")


if __name__ == "__main__":
    main()
