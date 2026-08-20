#!/usr/bin/env python3
"""
Fill missing QuestDB starts from local BtWQuests fact tables (NPC id + coords).
Does not copy BtW files; writes OneWoW pin shape only. Never overwrites existing pins.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

BIN_DIR = Path(__file__).resolve().parents[1]
if str(BIN_DIR) not in sys.path:
    sys.path.insert(0, str(BIN_DIR))

from lib.wowhead.quest_lua import parse_questdb_file
from lib.wowhead.quests import SHARDS, write_shard_safe

SOURCE_RE = re.compile(
    r"\[(\d+)\]\s*=\s*\{[^{}]*?source\s*=\s*\{\s*type\s*=\s*\"npc\",\s*id\s*=\s*(\d+)",
    re.DOTALL,
)
NPC_RE = re.compile(
    r"\[(\d+)\]\s*=\s*\{\s*name\s*=\s*\"[^\"]*\",\s*locations\s*=\s*\{\s*\[(\d+)\]\s*=\s*\{\s*\{\s*x\s*=\s*([0-9.]+),\s*y\s*=\s*([0-9.]+)",
    re.DOTALL,
)


def parse_sources(path: Path) -> dict[int, int]:
    text = path.read_text(encoding="utf-8")
    return {int(qid): int(npc) for qid, npc in SOURCE_RE.findall(text)}


def parse_npc_pins(path: Path) -> dict[int, dict]:
    text = path.read_text(encoding="utf-8")
    pins: dict[int, dict] = {}
    for npc_id, map_id, x, y in NPC_RE.findall(text):
        pins[int(npc_id)] = {
            "npcID": int(npc_id),
            "mapID": int(map_id),
            "x": float(x),
            "y": float(y),
        }
    return pins


def main() -> int:
    parser = argparse.ArgumentParser(description="Fill sparse QuestDB pins from BtWQuests facts")
    parser.add_argument(
        "--btw-dir",
        required=True,
        help="Path to a BtWQuests* folder (uses Database/Quests.lua and NPCs.lua)",
    )
    parser.add_argument("--expansion", default="midnight")
    args = parser.parse_args()

    btw = Path(args.btw_dir)
    quests_lua = btw / "Database" / "Quests.lua"
    npcs_lua = btw / "Database" / "NPCs.lua"
    sources = parse_sources(quests_lua)
    npc_pins = parse_npc_pins(npcs_lua)
    print(f"BtW sources {len(sources)} npc pins {len(npc_pins)}")

    exp_id = next(k for k, v in SHARDS.items() if v["key"] == args.expansion)
    old = parse_questdb_file(BIN_DIR.parent / "OneWoW_CatalogData_Quests" / "Data" / "QuestDB" / SHARDS[exp_id]["file"])
    details: dict[int, dict] = {}
    filled = 0
    for quest_id, quest in old.items():
        if quest.get("starts"):
            continue
        npc_id = sources.get(quest_id)
        if not npc_id:
            continue
        pin = npc_pins.get(npc_id) or {"npcID": npc_id}
        rec = {
            "id": quest_id,
            "starts": [pin],
            "ends": [dict(pin)],
            "coords": {
                "source": "quest_giver",
                **{k: pin[k] for k in ("mapID", "x", "y") if k in pin},
            }
            if "x" in pin
            else None,
        }
        if rec["coords"] is None:
            rec.pop("coords")
        details[quest_id] = rec
        filled += 1

    print(f"filling {filled} sparse quests")
    from lib.wowhead.quests import merge_expansion

    merged = merge_expansion(exp_id, list_rows={}, details=details, old=old)
    return write_shard_safe(exp_id, merged, old=old)


if __name__ == "__main__":
    raise SystemExit(main())
