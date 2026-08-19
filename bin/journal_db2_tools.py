#!/usr/bin/env python3
"""Validate / generate Catalog Journal membership tables from .wow_db2 CSVs.

Usage:
    python bin/journal_db2_tools.py generate
    python bin/journal_db2_tools.py validate
    python bin/journal_db2_tools.py report
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import defaultdict
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
SUITE_ROOT = SCRIPT_DIR.parent
DEFAULT_DB2 = SUITE_ROOT / ".wow_db2"
DEFAULT_OUT = SUITE_ROOT / "OneWoW_CatalogData_Journal" / "Data" / "Generated"
DATA_DIR = SUITE_ROOT / "OneWoW_CatalogData_Journal" / "Data"

BUILD_PIN = "12.1.0.69382"
CURRENT_SEASON_EXPANSION = 9000

REQUIRED_FOR_GENERATE = (
    "JournalTier.csv",
    "JournalTierXInstance.csv",
    "JournalInstance.csv",
    "JournalInstanceEntrance.csv",
    "MapDifficulty.csv",
    "Difficulty.csv",
    "Map.csv",
    "AreaPOI.csv",
    "Achievement.csv",
    "Achievement_Category.csv",
)

DELVE_DIFFICULTY_ID = 208
# Season/story duplicate maps that share a display name with a primary delve.
COLLAPSE_DELVE_MAP_IDS = {2767, 2768, 2836}
# Map.ExpansionID is suite expansionID - 1 (TWW 10 -> 11, Midnight 11 -> 12).
MAP_EXPANSION_TO_SUITE = 1
STATS_CATEGORY_ROOT = 1
GUILD_CATEGORY_ROOT = 15076
GLORY_DELVER_BY_SUITE = {
    11: 40438,  # Glory of the War Within Delver
    12: 61906,  # Glory of the Midnight Delver
}
LAIR_SOLO_TITLES = {
    "Let Me Solo Him: Zekvir": 2682,
    "Let Me Solo Him: The Underpin": 2831,
    "Let Me Solo Her: Nexus-Princess Ky'veza": 2951,
}

EXPANSION_FILES = (
    ("Classic", 1),
    ("BurningCrusade", 2),
    ("WrathoftheLichKing", 3),
    ("Cataclysm", 4),
    ("MistsofPandaria", 5),
    ("WarlordsofDraenor", 6),
    ("Legion", 7),
    ("BattleforAzeroth", 8),
    ("Shadowlands", 9),
    ("Dragonflight", 10),
    ("TheWarWithin", 11),
    ("Midnight", 12),
)

INSTANCE_ID_RE = re.compile(r"^\s*\[(\d+)\]\s*=\s*\{", re.M)
FALLBACK_PATH = DATA_DIR / "JournalInstanceEntranceFallbacks.lua"


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh, delimiter=";"))


def require_csvs(db2: Path) -> list[str]:
    missing = [name for name in REQUIRED_FOR_GENERATE if not (db2 / name).is_file()]
    return missing


def expansion_id_from_tier_row(row: dict[str, str]) -> int | None:
    exp = int(row["Expansion"])
    if exp == CURRENT_SEASON_EXPANSION or exp <= 0 or exp % 100 != 0:
        return None
    return exp // 100


def load_membership(db2: Path) -> tuple[
    dict[int, dict[int, int]],
    dict[int, dict[str, object]],
    dict[int, list[int]],
    dict[int, dict[str, object]],
]:
    """Return (membership, instance_meta, map_difficulties, difficulty_meta)."""
    tiers: dict[str, int] = {}
    for row in read_csv(db2 / "JournalTier.csv"):
        eid = expansion_id_from_tier_row(row)
        if eid is not None:
            tiers[row["ID"]] = eid

    membership: dict[int, dict[int, int]] = defaultdict(dict)
    for row in read_csv(db2 / "JournalTierXInstance.csv"):
        eid = tiers.get(row["JournalTierID"])
        if eid is None:
            continue
        iid = int(row["JournalInstanceID"])
        order = int(row["OrderIndex"] or 0)
        membership[eid][iid] = order

    instance_meta: dict[int, dict[str, object]] = {}
    for row in read_csv(db2 / "JournalInstance.csv"):
        iid = int(row["ID"])
        instance_meta[iid] = {
            "name": row.get("Name_lang") or f"Instance {iid}",
            "mapID": int(row["MapID"] or 0),
            "flags": int(row["Flags"] or 0),
        }

    map_diffs: dict[int, set[int]] = defaultdict(set)
    for row in read_csv(db2 / "MapDifficulty.csv"):
        map_id = int(row["MapID"] or 0)
        diff_id = int(row["DifficultyID"] or 0)
        if map_id and diff_id:
            map_diffs[map_id].add(diff_id)

    map_difficulties = {mid: sorted(diffs) for mid, diffs in map_diffs.items()}

    difficulty_meta: dict[int, dict[str, object]] = {}
    for row in read_csv(db2 / "Difficulty.csv"):
        did = int(row["ID"])
        difficulty_meta[did] = {
            "name": row.get("Name_lang") or f"Difficulty {did}",
            "maxPlayers": int(row["MaxPlayers"] or 0),
            "instanceType": int(row["InstanceType"] or 0),
        }

    return dict(membership), instance_meta, map_difficulties, difficulty_meta


def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def lua_num(value: float) -> str:
    text = f"{float(value):.4f}".rstrip("0").rstrip(".")
    if text in ("", "-0"):
        return "0"
    return text


def load_entrances(db2: Path) -> dict[int, list[dict[str, object]]]:
    """JournalInstanceID -> unique world-space entrance rows."""
    by_iid: dict[int, list[dict[str, object]]] = defaultdict(list)
    seen: dict[int, set[tuple]] = defaultdict(set)
    for row in read_csv(db2 / "JournalInstanceEntrance.csv"):
        iid = int(row["JournalInstanceID"] or 0)
        if not iid:
            continue
        map_id = int(row["MapID"] or 0)
        x = float(row["Position_0"] or 0)
        y = float(row["Position_1"] or 0)
        faction = int(row["Faction"] or -1)
        key = (map_id, faction, round(x, 4), round(y, 4))
        if key in seen[iid]:
            continue
        seen[iid].add(key)
        by_iid[iid].append({
            "mapID": map_id,
            "x": x,
            "y": y,
            "faction": faction,
        })
    return dict(by_iid)


def write_lua_header(lines: list[str], filename: str) -> None:
    lines.append(f"-- {filename}")
    lines.append(f"-- Auto-generated by bin/journal_db2_tools.py from .wow_db2 ({BUILD_PIN})")
    lines.append("-- Do not edit by hand; re-run: python bin/journal_db2_tools.py generate")
    lines.append("local _, ns = ...")
    lines.append("")


def emit_tier_membership(path: Path, membership: dict[int, dict[int, int]]) -> None:
    lines: list[str] = []
    write_lua_header(lines, "TierMembership.lua")
    lines.append("-- [expansionID] = { [instanceID] = orderIndex, ... }")
    lines.append("ns.JournalTierMembership = {")
    for eid in sorted(membership):
        lines.append(f"\t[{eid}] = {{")
        for iid, order in sorted(membership[eid].items(), key=lambda kv: (kv[1], kv[0])):
            lines.append(f"\t\t[{iid}] = {order},")
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def emit_map_difficulties(
    path: Path,
    map_difficulties: dict[int, list[int]],
    difficulty_meta: dict[int, dict[str, object]],
) -> None:
    lines: list[str] = []
    write_lua_header(lines, "MapDifficulties.lua")
    lines.append("-- [mapID] = { difficultyID, ... }")
    lines.append("ns.JournalMapDifficulties = {")
    for mid in sorted(map_difficulties):
        diffs = ", ".join(str(d) for d in map_difficulties[mid])
        lines.append(f"\t[{mid}] = {{ {diffs} }},")
    lines.append("}")
    lines.append("")
    lines.append("-- [difficultyID] = { name, maxPlayers }")
    lines.append("ns.JournalDifficultyMeta = {")
    for did in sorted(difficulty_meta):
        meta = difficulty_meta[did]
        name = lua_escape(str(meta["name"]))
        max_p = int(meta["maxPlayers"])
        lines.append(f'\t[{did}] = {{ name = "{name}", maxPlayers = {max_p} }},')
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def emit_instance_flags(path: Path, instance_meta: dict[int, dict[str, object]]) -> None:
    lines: list[str] = []
    write_lua_header(lines, "InstanceFlags.lua")
    lines.append("-- JournalInstanceFlags: Timewalker=1, HideUserSelectableDifficulty=2, DoNotDisplayInstance=4")
    lines.append("-- [instanceID] = { flags, name, mapID }")
    lines.append("ns.JournalInstanceMeta = {")
    for iid in sorted(instance_meta):
        meta = instance_meta[iid]
        name = lua_escape(str(meta["name"]))
        lines.append(
            f'\t[{iid}] = {{ flags = {int(meta["flags"])}, name = "{name}", '
            f'mapID = {int(meta["mapID"])} }},'
        )
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def load_categories(db2: Path) -> dict[int, int]:
    """Achievement_Category ID -> Parent."""
    parents: dict[int, int] = {}
    for row in read_csv(db2 / "Achievement_Category.csv"):
        parents[int(row["ID"])] = int(row["Parent"] or -1)
    return parents


def category_is_stats_or_guild(category_id: int, parents: dict[int, int]) -> bool:
    seen: set[int] = set()
    cid = category_id
    while cid and cid not in seen:
        if cid in (STATS_CATEGORY_ROOT, GUILD_CATEGORY_ROOT):
            return True
        seen.add(cid)
        parent = parents.get(cid, -1)
        if parent in (STATS_CATEGORY_ROOT, GUILD_CATEGORY_ROOT):
            return True
        cid = parent
        if cid == -1:
            break
    return False


def achievement_diff_token(title: str) -> str | None:
    """Parse an English achievement title into a JOURNAL_DIFF_* suffix."""
    low = title.lower()
    if low.startswith("heroic:"):
        return "H"
    if low.startswith("mythic:"):
        return "M"
    if low.startswith("normal:"):
        return "N"
    if "keystone" in low:
        return "M+"
    if "timewalking" in low or low.startswith("timewalker"):
        return "TW"
    if "looking for raid" in low or "raid finder" in low or low.startswith("lfr:"):
        return "LFR"
    heroic = "heroic" in low
    if "(10 player)" in low:
        return "10H" if heroic else "10N"
    if "(25 player)" in low:
        return "25H" if heroic else "25N"
    return None


def load_delves(db2: Path) -> dict[int, dict[int, dict[str, object]]]:
    """suite expansionID -> { mapID: { order, name } } for primary delves."""
    delve_maps: set[int] = set()
    for row in read_csv(db2 / "MapDifficulty.csv"):
        if int(row["DifficultyID"] or 0) == DELVE_DIFFICULTY_ID:
            mid = int(row["MapID"] or 0)
            if mid and mid not in COLLAPSE_DELVE_MAP_IDS:
                delve_maps.add(mid)

    by_exp: dict[int, list[tuple[str, int]]] = defaultdict(list)
    for row in read_csv(db2 / "Map.csv"):
        mid = int(row["ID"])
        if mid not in delve_maps:
            continue
        if int(row["InstanceType"] or 0) != 5:
            continue
        suite_exp = int(row["ExpansionID"] or 0) + MAP_EXPANSION_TO_SUITE
        name = row.get("MapName_lang") or f"Delve {mid}"
        by_exp[suite_exp].append((name, mid))

    membership: dict[int, dict[int, dict[str, object]]] = {}
    for eid, rows in by_exp.items():
        rows.sort(key=lambda kv: (kv[0].lower(), kv[1]))
        membership[eid] = {
            mid: {"order": order, "name": name} for order, (name, mid) in enumerate(rows)
        }
    return membership


def load_delve_names(
    db2: Path,
    membership: dict[int, dict[int, dict[str, object]]],
) -> dict[int, str]:
    names: dict[int, str] = {}
    for cards in membership.values():
        for mid, info in cards.items():
            names[mid] = str(info["name"])
    if names:
        return names
    wanted = {mid for cards in membership.values() for mid in cards}
    for row in read_csv(db2 / "Map.csv"):
        mid = int(row["ID"])
        if mid in wanted:
            names[mid] = row.get("MapName_lang") or f"Delve {mid}"
    return names


def load_delve_entrances(
    db2: Path,
    names: dict[int, str],
) -> dict[int, list[dict[str, object]]]:
    """mapID -> one regular Delve door (plus matching bountiful POI id)."""
    name_to_map = {name: mid for mid, name in names.items()}
    regular: dict[int, dict[str, object]] = {}
    bountiful: dict[int, list[dict[str, object]]] = defaultdict(list)

    for row in read_csv(db2 / "AreaPOI.csv"):
        name = row.get("Name_lang") or ""
        mid = name_to_map.get(name)
        if not mid:
            continue
        desc = row.get("Description_lang") or ""
        entry = {
            "areaPoiID": int(row["ID"]),
            "mapID": int(row["ContinentID"] or 0),
            "x": float(row["Pos_0"] or 0),
            "y": float(row["Pos_1"] or 0),
            "faction": -1,
        }
        if desc == "Delve":
            if mid not in regular:
                regular[mid] = entry
        elif "Bountiful Delve" in desc:
            bountiful[mid].append(entry)

    by_mid: dict[int, list[dict[str, object]]] = {}
    for mid, door in regular.items():
        match_id = None
        for cand in bountiful.get(mid, []):
            if (
                cand["mapID"] == door["mapID"]
                and abs(float(cand["x"]) - float(door["x"])) < 0.05
                and abs(float(cand["y"]) - float(door["y"])) < 0.05
            ):
                match_id = int(cand["areaPoiID"])
                break
        if match_id is None and bountiful.get(mid):
            match_id = int(bountiful[mid][0]["areaPoiID"])
        row = {
            "mapID": door["mapID"],
            "x": door["x"],
            "y": door["y"],
            "faction": -1,
            "areaPoiID": int(door["areaPoiID"]),
        }
        if match_id:
            row["bountifulPoiID"] = match_id
        by_mid[mid] = [row]
    return by_mid


def load_journal_achievements(db2: Path) -> dict[int, list[dict[str, object]]]:
    """JournalInstance.MapID -> achievement rows (player tree only)."""
    map_ids: set[int] = set()
    for row in read_csv(db2 / "JournalInstance.csv"):
        mid = int(row["MapID"] or 0)
        if mid:
            map_ids.add(mid)

    parents = load_categories(db2)
    by_map: dict[int, list[dict[str, object]]] = defaultdict(list)
    for row in read_csv(db2 / "Achievement.csv"):
        title = row.get("Title_lang") or ""
        if " (copy)" in title:
            continue
        mid = int(row["Instance_ID"] or 0)
        if mid <= 0 or mid not in map_ids:
            continue
        if category_is_stats_or_guild(int(row["Category"] or 0), parents):
            continue
        entry: dict[str, object] = {"id": int(row["ID"])}
        diff = achievement_diff_token(title)
        if diff:
            entry["diff"] = diff
        by_map[mid].append(entry)
    for mid in by_map:
        by_map[mid].sort(key=lambda r: int(r["id"]))
    return dict(by_map)


def load_delve_achievements(
    db2: Path,
    membership: dict[int, dict[int, dict[str, object]]],
    names: dict[int, str],
) -> dict[int, list[dict[str, object]]]:
    """Delve mapID -> Stories/Discoveries + expansion Glory + matching lair solos."""
    by_map: dict[int, list[dict[str, object]]] = defaultdict(list)
    seen: dict[int, set[int]] = defaultdict(set)

    def add(mid: int, ach_id: int) -> None:
        if ach_id in seen[mid]:
            return
        seen[mid].add(ach_id)
        by_map[mid].append({"id": ach_id})

    title_index: dict[str, int] = {}
    for row in read_csv(db2 / "Achievement.csv"):
        title = row.get("Title_lang") or ""
        if " (copy)" in title:
            continue
        title_index[title] = int(row["ID"])

    for mid, name in names.items():
        stories = title_index.get(f"{name} Stories")
        discoveries = title_index.get(f"{name} Discoveries")
        if stories:
            add(mid, stories)
        if discoveries:
            add(mid, discoveries)

    for suite_exp, cards in membership.items():
        glory = GLORY_DELVER_BY_SUITE.get(suite_exp)
        if not glory:
            continue
        for mid in cards:
            add(mid, glory)

    for title, mid in LAIR_SOLO_TITLES.items():
        ach_id = title_index.get(title)
        if ach_id and mid in names:
            add(mid, ach_id)

    for mid in by_map:
        by_map[mid].sort(key=lambda r: int(r["id"]))
    return dict(by_map)


def emit_delve_membership(path: Path, membership: dict[int, dict[int, dict[str, object]]]) -> None:
    lines: list[str] = []
    write_lua_header(lines, "DelveMembership.lua")
    lines.append("-- Primary delve MapIDs. Not EJ; cache key is expansionID .. \":delve:\" .. mapID.")
    lines.append("-- [expansionID] = { [mapID] = { order, name }, ... }")
    lines.append("ns.DelveMembership = {")
    for eid in sorted(membership):
        lines.append(f"\t[{eid}] = {{")
        for mid, info in sorted(membership[eid].items(), key=lambda kv: (int(kv[1]["order"]), kv[0])):
            name = lua_escape(str(info["name"]))
            lines.append(f'\t\t[{mid}] = {{ order = {int(info["order"])}, name = "{name}" }},')
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def emit_delve_entrances(path: Path, entrances: dict[int, list[dict[str, object]]]) -> None:
    lines: list[str] = []
    write_lua_header(lines, "DelveEntrances.lua")
    lines.append("-- World-space delve doors from AreaPOI (Description == Delve).")
    lines.append("-- mapID is the continent Map.db2 id. Convert with C_Map.GetMapPosFromWorldPos.")
    lines.append("-- [mapID] = { { mapID, x, y, faction, areaPoiID, bountifulPoiID? }, ... }")
    lines.append("ns.DelveEntrances = {")
    for mid in sorted(entrances):
        lines.append(f"\t[{mid}] = {{")
        for row in entrances[mid]:
            extra = ""
            if row.get("bountifulPoiID"):
                extra = f", bountifulPoiID = {int(row['bountifulPoiID'])}"
            lines.append(
                f'\t\t{{ mapID = {int(row["mapID"])}, x = {lua_num(row["x"])}, '
                f'y = {lua_num(row["y"])}, faction = {int(row["faction"])}, '
                f'areaPoiID = {int(row["areaPoiID"])}{extra} }},'
            )
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def emit_achievements(
    path: Path,
    journal: dict[int, list[dict[str, object]]],
    delves: dict[int, list[dict[str, object]]],
) -> None:
    lines: list[str] = []
    write_lua_header(lines, "Achievements.lua")
    lines.append("-- Achievement IDs only. Names/points/status come from GetAchievementInfo.")
    lines.append("-- [mapID] = { { id, diff? }, ... }  diff is a JOURNAL_DIFF_* suffix.")
    lines.append("ns.JournalAchievements = {")
    _emit_ach_table(lines, journal)
    lines.append("}")
    lines.append("")
    lines.append("-- Delve Stories/Discoveries + expansion Glory + matching lair solos.")
    lines.append("ns.DelveAchievements = {")
    _emit_ach_table(lines, delves)
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def _emit_ach_table(lines: list[str], by_map: dict[int, list[dict[str, object]]]) -> None:
    for mid in sorted(by_map):
        lines.append(f"\t[{mid}] = {{")
        for row in by_map[mid]:
            if row.get("diff"):
                lines.append(f'\t\t{{ id = {int(row["id"])}, diff = "{row["diff"]}" }},')
            else:
                lines.append(f'\t\t{{ id = {int(row["id"])} }},')
        lines.append("\t},")


def emit_instance_entrances(path: Path, entrances: dict[int, list[dict[str, object]]]) -> None:
    lines: list[str] = []
    write_lua_header(lines, "InstanceEntrances.lua")
    lines.append("-- World-space entrance pins from JournalInstanceEntrance.")
    lines.append("-- mapID is the continent/world Map.db2 id (not a UiMapID). Convert at runtime")
    lines.append("-- with C_Map.GetMapPosFromWorldPos. faction: -1 any, 0 Horde, 1 Alliance.")
    lines.append("-- [instanceID] = { { mapID, x, y, faction }, ... }")
    lines.append("ns.JournalInstanceEntrances = {")
    for iid in sorted(entrances):
        lines.append(f"\t[{iid}] = {{")
        for row in entrances[iid]:
            lines.append(
                f'\t\t{{ mapID = {int(row["mapID"])}, x = {lua_num(row["x"])}, '
                f'y = {lua_num(row["y"])}, faction = {int(row["faction"])} }},'
            )
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def parse_att_instance_ids(path: Path) -> set[int]:
    text = path.read_text(encoding="utf-8")
    return {int(m.group(1)) for m in INSTANCE_ID_RE.finditer(text)}


def load_entrance_fallback_ids() -> set[int]:
    if not FALLBACK_PATH.is_file():
        return set()
    return parse_att_instance_ids(FALLBACK_PATH)


def entrance_fallback_overlap_lines(
    entrances: dict[int, list[dict[str, object]]],
    instance_meta: dict[int, dict[str, object]],
) -> list[str]:
    overlap = sorted(load_entrance_fallback_ids() & set(entrances))
    lines: list[str] = []
    for iid in overlap:
        name = instance_meta.get(iid, {}).get("name", "?")
        lines.append(
            f"REMOVE handmade entrance for instance {iid} ({name}): "
            f"JournalInstanceEntrance now has a DB2 door"
        )
    return lines


def report_entrance_fallback_overlap(
    entrances: dict[int, list[dict[str, object]]],
    instance_meta: dict[int, dict[str, object]],
    *,
    fail: bool,
) -> int:
    lines = entrance_fallback_overlap_lines(entrances, instance_meta)
    if not lines:
        print("Entrance fallbacks: no overlap with DB2 (OK)")
        return 0
    print("Entrance fallbacks that must be removed (DB2 now has doors):")
    for line in lines:
        print(f"  {line}")
    return 1 if fail else 0


def collect_att_instances() -> dict[int, set[int]]:
    """expansionID -> set of instanceIDs present in *-instances.lua."""
    by_exp: dict[int, set[int]] = {}
    for name, eid in EXPANSION_FILES:
        path = DATA_DIR / f"{name}-instances.lua"
        if path.is_file():
            by_exp[eid] = parse_att_instance_ids(path)
    return by_exp


def cmd_generate(db2: Path, out_dir: Path) -> int:
    missing = require_csvs(db2)
    if missing:
        print("Missing required CSV(s) under", db2, file=sys.stderr)
        for name in missing:
            print(f"  - {name}", file=sys.stderr)
        return 1

    membership, instance_meta, map_difficulties, difficulty_meta = load_membership(db2)
    entrances = load_entrances(db2)
    delve_membership = load_delves(db2)
    delve_names = load_delve_names(db2, delve_membership)
    delve_entrances = load_delve_entrances(db2, delve_names)
    journal_achs = load_journal_achievements(db2)
    delve_achs = load_delve_achievements(db2, delve_membership, delve_names)
    out_dir.mkdir(parents=True, exist_ok=True)
    emit_tier_membership(out_dir / "TierMembership.lua", membership)
    emit_map_difficulties(out_dir / "MapDifficulties.lua", map_difficulties, difficulty_meta)
    emit_instance_flags(out_dir / "InstanceFlags.lua", instance_meta)
    emit_instance_entrances(out_dir / "InstanceEntrances.lua", entrances)
    emit_delve_membership(out_dir / "DelveMembership.lua", delve_membership)
    emit_delve_entrances(out_dir / "DelveEntrances.lua", delve_entrances)
    emit_achievements(out_dir / "Achievements.lua", journal_achs, delve_achs)

    cards = sum(len(v) for v in membership.values())
    delve_cards = sum(len(v) for v in delve_membership.values())
    print(
        f"Generated TierMembership ({cards} cards), MapDifficulties, InstanceFlags, "
        f"InstanceEntrances ({len(entrances)} instances), "
        f"DelveMembership ({delve_cards} delves), DelveEntrances ({len(delve_entrances)}), "
        f"Achievements ({len(journal_achs)} maps, {len(delve_achs)} delves) -> {out_dir}"
    )
    if report_entrance_fallback_overlap(entrances, instance_meta, fail=True):
        print(
            "Delete those ids from JournalInstanceEntranceFallbacks.lua, then re-run generate.",
            file=sys.stderr,
        )
        return 1
    return 0


def cmd_validate(db2: Path) -> int:
    missing = require_csvs(db2)
    if missing:
        print("Missing required CSV(s); cannot validate:", ", ".join(missing), file=sys.stderr)
        return 1

    membership, instance_meta, map_difficulties, _ = load_membership(db2)
    att = collect_att_instances()

    membership_ids: set[int] = set()
    for eid, cards in membership.items():
        membership_ids.update(cards)

    print(f"Build pin: {BUILD_PIN}")
    print(f"EJ membership cards: {sum(len(v) for v in membership.values())} across {len(membership)} expansions")
    print(f"Unique instanceIDs in membership: {len(membership_ids)}")
    entrances = load_entrances(db2)
    print(f"Entrance pins: {len(entrances)} instanceIDs")
    fallback_ids = load_entrance_fallback_ids()
    print(f"Entrance fallbacks: {len(fallback_ids)} handmade instanceIDs")
    delve_membership = load_delves(db2)
    delve_names = load_delve_names(db2, delve_membership)
    delve_entrances = load_delve_entrances(db2, delve_names)
    journal_achs = load_journal_achievements(db2)
    delve_achs = load_delve_achievements(db2, delve_membership, delve_names)
    print(f"Delve cards: {sum(len(v) for v in delve_membership.values())} across {len(delve_membership)} expansions")
    print(f"Delve entrance pins: {len(delve_entrances)}")
    print(f"Journal achievement maps: {len(journal_achs)}")
    print(f"Delve achievement maps: {len(delve_achs)}")

    orphans: list[str] = []
    for eid, ids in sorted(att.items()):
        for iid in sorted(ids):
            if iid not in membership.get(eid, {}):
                # ATT stub on an expansion that EJ does not list for that tier
                if iid in membership_ids:
                    orphans.append(
                        f"ATT orphan stub: expansion {eid} lists instance {iid} "
                        f"(EJ lists it under other tier(s) only)"
                    )
                else:
                    orphans.append(f"ATT-only instance: expansion {eid} instance {iid} (not in EJ membership)")

    multi = [
        iid
        for iid in membership_ids
        if sum(1 for eid in membership if iid in membership[eid]) > 1
    ]
    print(f"Multi-tier instanceIDs: {len(multi)} -> {sorted(multi)}")

    # Shared-ID loot hint: instance in membership under one expansion but ATT
    # tables for another expansion may still hold loot (Onyxia Classic-tables).
    print("\n--- Orphans / stubs (informational) ---")
    if not orphans:
        print("(none)")
    else:
        for line in orphans[:80]:
            print(line)
        if len(orphans) > 80:
            print(f"... and {len(orphans) - 80} more")

    missing_meta = [iid for iid in membership_ids if iid not in instance_meta]
    if missing_meta:
        print("\nMembership instanceIDs missing JournalInstance rows:", sorted(missing_meta)[:40])

    no_map_diff = []
    for eid, cards in membership.items():
        for iid in cards:
            meta = instance_meta.get(iid)
            if not meta:
                continue
            mid = int(meta["mapID"])
            if mid and mid not in map_difficulties:
                no_map_diff.append((eid, iid, mid))
    if no_map_diff:
        print(f"\nCards with MapID but no MapDifficulty rows: {len(no_map_diff)}")
        for row in no_map_diff[:20]:
            print(f"  expansion {row[0]} instance {row[1]} map {row[2]}")

    print("\n--- Entrance fallback overlap ---")
    if report_entrance_fallback_overlap(entrances, instance_meta, fail=True):
        return 1
    return 0


def cmd_report(db2: Path) -> int:
    rc = cmd_validate(db2)
    if rc != 0:
        return rc
    membership, instance_meta, _, _ = load_membership(db2)
    print("\n--- Dual-listed instances ---")
    by_iid: dict[int, list[int]] = defaultdict(list)
    for eid, cards in membership.items():
        for iid in cards:
            by_iid[iid].append(eid)
    for iid, eids in sorted(by_iid.items()):
        if len(eids) > 1:
            name = instance_meta.get(iid, {}).get("name", "?")
            print(f"  {iid} {name}: expansions {sorted(eids)}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "mode",
        choices=("generate", "validate", "report"),
        help="generate Lua, validate ATT vs membership, or print a dual-list report",
    )
    parser.add_argument(
        "--db2",
        type=Path,
        default=DEFAULT_DB2,
        help=f"CSV root (default: {DEFAULT_DB2})",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUT,
        help=f"Generated Lua output dir (default: {DEFAULT_OUT})",
    )
    args = parser.parse_args()
    db2 = args.db2 if args.db2.is_absolute() else SUITE_ROOT / args.db2
    out = args.out if args.out.is_absolute() else SUITE_ROOT / args.out

    if args.mode == "generate":
        return cmd_generate(db2, out)
    if args.mode == "validate":
        return cmd_validate(db2)
    return cmd_report(db2)


if __name__ == "__main__":
    raise SystemExit(main())
