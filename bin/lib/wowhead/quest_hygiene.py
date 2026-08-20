"""QuestDB keep/clean rules (mirrors Modules/QuestData.lua + clean_questdb.lua)."""

from __future__ import annotations

import re
from typing import Any

HIDDEN_CATEGORIES = {"test", "hidden"}
HIDDEN_FLAGS = {"deprecated", "internal", "unobtainable", "removed"}

INTERNAL_SUBSTR = (
    "reward test",
    "rated pvp incentive",
    "tracking quest",
    "reward quest",
    "quest start",
    "navigation playtest",
    ":]p",
    "test case",
    "test quest",
    "nav test",
    "test currency",
    "testing",
    "do not use",
    "event tracking",
    "unused",
    "vignette",
    "capstone",
)

CHROME_MARKERS = (
    "See if you've already completed this by typing:",
    "C_QuestLog.IsQuestFlaggedCompleted",
    "Wowhead Client",
    "Download Now",
    "Help keep the database up to date",
    "Accept this quest to record its description and rewards",
)

BC_MAPS = {
    94, 95, 97, 100, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 122,
}
BC_ZONES = {
    3430, 3431, 3433, 3483, 3518, 3519, 3520, 3521, 3522, 3523, 3524, 3525,
    3703, 4080, 6455, 6456,
}

COLOR_RE = re.compile(r"\|[cC][0-9A-Fa-f]{8}")
LEVEL_NAME_RE = re.compile(r"^Level\s+\d+$")
NTH_RE = re.compile(r"(?i)(?<![A-Za-z0-9])NTH(?![A-Za-z0-9])")
POI_RE = re.compile(r"(?i)(?<![A-Za-z0-9])poi(?![A-Za-z0-9])")
BRACKET_RE = re.compile(r"\[[^\]]*\]")


def strip_formatting(text: str | None) -> str | None:
    if text is None:
        return None
    text = COLOR_RE.sub("", str(text))
    text = re.sub(r"\|[rR]", "", text)
    return text.replace("||", "|")


def clean_wowhead_text(text: str | None) -> str | None:
    if not text:
        return None
    text = strip_formatting(text) or ""
    text = re.sub(
        r"See if you've already completed this by typing:\s*/run\s+print\(\s*C_QuestLog\.IsQuestFlaggedCompleted\(\s*\d+\s*\)\s*\)",
        "",
        text,
    )
    text = re.sub(
        r"Gather info with the Wowhead Client\s*Download Now\s*Help keep the database up to date!?",
        "",
        text,
    )
    text = re.sub(r"Accept this quest to record its description and rewards\.?", "", text)
    text = re.sub(
        r"^Community Feasts are one of the main features.*?Getting a soup all the way to Legendary\s*",
        "",
        text,
        flags=re.S,
    )
    if "Progress:" in text and re.search(r"[\u0080-\uffff]", text):
        text = re.sub(r"\s*Progress:.*$", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text or None


def has_wowhead_chrome(text: str | None) -> bool:
    if not text:
        return False
    return any(marker in text for marker in CHROME_MARKERS)


def _upper(text: str | None) -> str:
    return str(text).upper() if text else ""


def is_internal_name(name: str | None, quest_id: int | None = None) -> bool:
    if not name:
        return True
    name = str(name).strip()
    lower = name.lower()
    if not name or LEVEL_NAME_RE.match(name):
        return True
    if any(token in lower for token in INTERNAL_SUBSTR):
        return True
    if POI_RE.search(lower):
        return True
    if "bonus objective" in lower and quest_id != 71153:
        return True
    if "placeholder" in lower:
        return True
    if "DNT" in _upper(name) or NTH_RE.search(name):
        return True
    if "[PH]" in _upper(name) or "(PH)" in _upper(name):
        return True
    if "[NYI]" in _upper(name):
        return True
    trimmed = _upper(name).strip()
    if "[REMOVED]" in trimmed or trimmed == "REMOVED":
        return True
    if BRACKET_RE.search(name.strip()):
        return True
    if name in {"?", "??"} or lower in {"zz", "test"}:
        return True
    return False


def _bad_text(text: str | None) -> bool:
    if not text:
        return False
    upper = text.upper()
    if "DNT" in upper or NTH_RE.search(text) or "[PH]" in upper or "(PH)" in upper:
        return True
    if "[NYI]" in upper or "placeholder" in text.lower():
        return True
    if "[REMOVED]" in upper or has_wowhead_chrome(text):
        return True
    if BRACKET_RE.search(str(text).strip()):
        return True
    return False


def _has_display_text(text: str | None) -> bool:
    if not text or not str(text).strip():
        return False
    if str(text).strip() == "Accept this quest to record its description and rewards.":
        return False
    return not has_wowhead_chrome(text)


def _quest_map_id(quest: dict[str, Any]) -> int | None:
    map_id = quest.get("mapID")
    if isinstance(map_id, int) and map_id != 0:
        return map_id
    coords = quest.get("coords")
    if isinstance(coords, dict) and isinstance(coords.get("mapID"), int) and coords["mapID"] != 0:
        return coords["mapID"]
    for field in ("starts", "ends"):
        pins = quest.get(field)
        if isinstance(pins, list) and pins and isinstance(pins[0], dict):
            pin_map = pins[0].get("mapID")
            if isinstance(pin_map, int) and pin_map != 0:
                return pin_map
    return None


def is_bc_quest(quest: dict[str, Any]) -> bool:
    map_id = _quest_map_id(quest)
    if map_id is not None:
        return map_id in BC_MAPS
    zone_id = quest.get("zoneID")
    return isinstance(zone_id, int) and zone_id in BC_ZONES


def resolve_expansion(quest: dict[str, Any]) -> Any:
    expansion = quest.get("expansion")
    if isinstance(expansion, int) and expansion <= 2 and is_bc_quest(quest):
        return 1
    return expansion


def _has_useful_sparse(quest: dict[str, Any]) -> bool:
    if (quest.get("rewardGold") or 0) > 0:
        return True
    if (quest.get("rewardXP") or 0) > 0:
        return True
    for key in ("rewardItems", "rewardChoices", "rewardCurrencies"):
        if quest.get(key):
            return True
    coords = quest.get("coords")
    if isinstance(coords, dict) and coords.get("mapID"):
        return True
    if quest.get("mapID"):
        return True
    return False


def clean_quest(quest: dict[str, Any] | None, *, drop_internal: bool = True) -> dict[str, Any] | None:
    """Clean a scraped/shipped record. Returns None to drop (new IDs only)."""
    if not isinstance(quest, dict) or not quest.get("id") or not quest.get("name"):
        return None
    quest = dict(quest)
    quest["name"] = strip_formatting(quest.get("name")) or quest["name"]
    if drop_internal and is_internal_name(quest["name"], quest.get("id")):
        return None

    quest["description"] = clean_wowhead_text(quest.get("description"))
    quest["objectivesText"] = clean_wowhead_text(quest.get("objectivesText"))

    if drop_internal and (_bad_text(quest.get("description")) or _bad_text(quest.get("objectivesText"))):
        return None

    categories = quest.get("categories") or []
    flags = quest.get("flags") or []
    if any(cat in HIDDEN_CATEGORIES for cat in categories):
        return None if drop_internal else quest
    if any(flag in HIDDEN_FLAGS for flag in flags):
        return None if drop_internal else quest

    if (
        drop_internal
        and not _has_display_text(quest.get("description"))
        and not _has_display_text(quest.get("objectivesText"))
        and not _has_useful_sparse(quest)
    ):
        return None

    expansion = resolve_expansion(quest)
    if isinstance(expansion, int):
        quest["expansion"] = expansion

    quest.pop("unknownQuickfacts", None)
    quest.pop("_wowheadStorylineID", None)
    quest.pop("firstseenpatch", None)
    for key in (
        "requiredClasses",
        "requiredRaces",
        "requiredProfessions",
        "categories",
        "flags",
        "rewardItems",
        "rewardChoices",
        "rewardCurrencies",
        "storyline",
        "series",
        "starts",
        "ends",
    ):
        if quest.get(key) == []:
            quest.pop(key, None)
    if quest.get("rewardGold") == 0:
        quest.pop("rewardGold", None)
    if quest.get("rewardXP") == 0:
        quest.pop("rewardXP", None)
    return quest


def is_empty_field(value: Any) -> bool:
    if value is None:
        return True
    if value == "" or value == [] or value == {}:
        return True
    if value == 0:
        return True
    return False


def merge_pins(old: list[dict[str, Any]] | None, new: list[dict[str, Any]] | None) -> list[dict[str, Any]] | None:
    if not new:
        return old or None
    if not old:
        return new
    merged: dict[tuple[Any, Any], dict[str, Any]] = {}
    for pin in list(old) + list(new):
        if not isinstance(pin, dict):
            continue
        key = (pin.get("npcID"), pin.get("mapID") or pin.get("zoneID"))
        prev = merged.get(key)
        if prev is None:
            merged[key] = dict(pin)
            continue
        if pin.get("x") is not None:
            merged[key] = dict(pin)
            if prev.get("mapID") and not pin.get("mapID"):
                merged[key]["mapID"] = prev["mapID"]
    return list(merged.values()) or None


def union_list(old: list[Any] | None, new: list[Any] | None) -> list[Any] | None:
    if not new:
        return old or None
    if not old:
        return list(new)
    out = list(old)
    seen = set()
    for item in old:
        if isinstance(item, (int, str)):
            seen.add(item)
        elif isinstance(item, dict):
            seen.add(tuple(sorted(item.items())))
    for item in new:
        marker: Any
        if isinstance(item, (int, str)):
            marker = item
        elif isinstance(item, dict):
            marker = tuple(sorted(item.items()))
        else:
            out.append(item)
            continue
        if marker not in seen:
            seen.add(marker)
            out.append(item)
    return out


def union_merge(old: dict[str, Any] | None, new: dict[str, Any] | None) -> dict[str, Any] | None:
    """Fill empties from new; never drop old pins/text when new is blank."""
    if not old:
        return dict(new) if new else None
    if not new:
        return dict(old)
    out = dict(old)
    for key, value in new.items():
        if key.startswith("_"):
            continue
        if is_empty_field(value):
            continue
        if key in ("starts", "ends"):
            merged = merge_pins(old.get(key), value if isinstance(value, list) else None)
            if merged:
                out[key] = merged
            continue
        if key in ("storyline", "series", "rewardItems", "rewardChoices", "categories", "flags"):
            merged_list = union_list(old.get(key) if isinstance(old.get(key), list) else None, value)
            if merged_list:
                out[key] = merged_list
            continue
        if key == "coords":
            old_coords = old.get("coords")
            if isinstance(old_coords, dict) and old_coords.get("x") is not None and (
                not isinstance(value, dict) or value.get("x") is None
            ):
                continue
            out[key] = value
            continue
        out[key] = value
    return out
