"""Parse Wowhead quest listview rows and quest detail pages."""

from __future__ import annotations

import html as html_lib
import re
from typing import Any

from lib.wowhead.listview import fix_json_keys, parse_items_json

MAPPER_RE = re.compile(r"new Mapper\(", re.DOTALL)
SERIES_TABLE_RE = re.compile(
    r'<table class="series">(.*?)</table>',
    re.IGNORECASE | re.DOTALL,
)
STORYLINE_RE = re.compile(
    r'href="https?://www\.wowhead\.com/storyline/[^"]*-(\d+)"',
    re.IGNORECASE,
)
QUEST_LINK_RE = re.compile(r"/quest=(\d+)")
NPC_LINK_RE = re.compile(r"/npc=(\d+)")
OBJECT_LINK_RE = re.compile(r"/object=(\d+)")
HEADING_RE = re.compile(
    r"<h2[^>]*>\s*(Description|Objectives|Completion)\s*</h2>(.*?)(?=<h2|\Z)",
    re.IGNORECASE | re.DOTALL,
)
TAG_RE = re.compile(r"<[^>]+>")
INFOBOX_MARKUP_RE = re.compile(
    r'WH\.markup\.printHtml\("(\[ul\].*?\[\/ul\])"',
    re.DOTALL,
)
G_QUESTS_RE = re.compile(r"g_quests\[(\d+)\]")
TITLE_RE = re.compile(r"<title>(.*?)\s+-\s+Quest\b", re.IGNORECASE)

SIDE_NAMES = {1: "alliance", 2: "horde", 3: "both", 0: "none"}

# Wowhead quest `type` → Catalog questType / extra category.
TYPE_TO_QUEST = {
    1: "group",
    41: "pvp",
    62: "raid",
    81: "dungeon",
    85: "dungeon",
    88: "raid",
    89: "raid",
    98: "dungeon",
    109: "world",
}

TYPE_CATEGORIES = {
    83: "legendary",
    282: "campaign",
    283: "campaign",
    284: "campaign",
}

ICON_FLAGS = {
    "quest-start-daily": ("daily", "repeatable"),
    "quest-start-weekly": ("weekly", "repeatable"),
    "quest-start-repeatable": ("repeatable",),
}


def expansion_from_patch(patch: int | None) -> int | None:
    """Map Wowhead firstseenpatch (e.g. 120100) to Catalog expansion IDs."""
    if not patch:
        return None
    major = int(patch) // 10000
    if major <= 1:
        return 0
    return major - 1


def decode_class_mask(mask: int | None) -> list[int]:
    if not mask:
        return []
    classes = []
    for class_id in range(1, 14):
        if mask & (1 << (class_id - 1)):
            classes.append(class_id)
    return classes


def _frac(value: float) -> float:
    return round(value / 100.0, 6)


def _unique_ints(values: list[Any]) -> list[int]:
    out: list[int] = []
    seen: set[int] = set()
    for value in values:
        try:
            number = int(value)
        except (TypeError, ValueError):
            continue
        if number not in seen:
            seen.add(number)
            out.append(number)
    return out


def record_from_listview(item: dict[str, Any], default_expansion: int | None = None) -> dict[str, Any]:
    """Build a partial quest record from a quest-template listview row."""
    quest_id = int(item["id"])
    patch = item.get("firstseenpatch")
    expansion = expansion_from_patch(patch) if patch else default_expansion
    if expansion is None:
        expansion = default_expansion

    flags: list[str] = []
    for flag in ICON_FLAGS.get(str(item.get("icon") or ""), ()):
        if flag not in flags:
            flags.append(flag)

    categories: list[str] = []
    wow_type = item.get("type")
    extra = TYPE_CATEGORIES.get(wow_type)
    if extra:
        categories.append(extra)

    quest_type = TYPE_TO_QUEST.get(wow_type, "standard")

    record: dict[str, Any] = {
        "id": quest_id,
        "name": item.get("name") or "",
        "level": item.get("level") or 0,
        "requiredLevel": item.get("reqlevel") or 0,
        "faction": SIDE_NAMES.get(item.get("side"), "none"),
        "expansion": expansion,
        "zoneID": item.get("category") if isinstance(item.get("category"), int) and item["category"] > 0 else None,
        "sharable": False,
        "questType": quest_type,
    }
    if patch:
        record["firstseenpatch"] = int(patch)

    classes = decode_class_mask(item.get("reqclass"))
    if classes:
        record["requiredClasses"] = classes
    if categories:
        record["categories"] = categories
    if flags:
        record["flags"] = flags

    money = item.get("money") or 0
    if money:
        record["rewardGold"] = int(money)
    xp = item.get("xp") or 0
    if xp:
        record["rewardXP"] = int(xp)

    items = item.get("itemrewards") or []
    if items:
        record["rewardItems"] = _unique_ints(
            row[0] if isinstance(row, (list, tuple)) else row for row in items
        )
    choices = item.get("itemchoices") or []
    if choices:
        record["rewardChoices"] = _unique_ints(
            row[0] if isinstance(row, (list, tuple)) else row for row in choices
        )
    currencies = item.get("currencyrewards") or []
    if currencies:
        record["rewardCurrencies"] = [
            {"id": int(row[0]), "amount": int(row[1])}
            for row in currencies
            if isinstance(row, (list, tuple)) and len(row) >= 2
        ]
    return {key: value for key, value in record.items() if value is not None}


def _strip_html(text: str) -> str:
    text = html_lib.unescape(text)
    text = text.replace("[/li]", " ").replace("[li]", " ")
    text = re.sub(r"\[/?[^\]]+\]", " ", text)
    text = TAG_RE.sub(" ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def _section_text(html: str, heading: str) -> str | None:
    for match in HEADING_RE.finditer(html):
        if match.group(1).lower() == heading.lower():
            text = _strip_html(match.group(2))
            return text or None
    return None


def _parse_mapper(html: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]], int | None]:
    match = MAPPER_RE.search(html)
    if not match:
        return [], [], None
    # Mapper({ ... }) — extract the first balanced object after '('.
    start = match.end()
    i = start
    while i < len(html) and html[i] in " \t\n\r":
        i += 1
    if i >= len(html) or html[i] != "{":
        return [], [], None
    raw_obj = _balanced_object(html, i)
    if not raw_obj:
        return [], [], None
    # Reuse array walker by wrapping? parse via regex on point objects instead —
    # Mapper JS is not strict JSON (unquoted keys). Quote keys then parse.
    try:
        data = parse_items_json("[" + raw_obj + "]")[0]
    except (ValueError, IndexError):
        return [], [], None

    starts: list[dict[str, Any]] = []
    ends: list[dict[str, Any]] = []
    zone_id = None
    objectives = data.get("objectives") or {}
    if isinstance(objectives, dict):
        for raw_zone, payload in objectives.items():
            try:
                zone_id = int(raw_zone)
            except (TypeError, ValueError):
                zone_id = zone_id
            levels = payload.get("levels") if isinstance(payload, dict) else None
            if not levels:
                continue
            for level in levels:
                points = level if isinstance(level, list) else [level]
                for point in points:
                    if not isinstance(point, dict):
                        continue
                    pin = _pin_from_mapper_point(point, zone_id)
                    if not pin:
                        continue
                    kind = point.get("point")
                    if kind == "start":
                        starts.append(pin)
                    elif kind == "end":
                        ends.append(pin)
    return starts, ends, zone_id


def _balanced_object(html: str, start: int) -> str | None:
    if start >= len(html) or html[start] != "{":
        return None
    depth = 0
    in_string = False
    escape = False
    quote = None
    i = start
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
            if c == quote:
                in_string = False
            i += 1
            continue
        if c in ('"', "'"):
            in_string = True
            quote = c
            i += 1
            continue
        if c in "{[":
            depth += 1
        elif c in "}]":
            depth -= 1
            if depth == 0 and c == "}":
                return html[start : i + 1]
        i += 1
    return None


def _pin_from_mapper_point(point: dict[str, Any], zone_id: int | None) -> dict[str, Any] | None:
    npc_id = point.get("id")
    if not npc_id:
        return None
    pin: dict[str, Any] = {"npcID": int(npc_id)}
    coord = point.get("coord") or ((point.get("coords") or [None])[0])
    if isinstance(coord, (list, tuple)) and len(coord) >= 2:
        pin["x"] = _frac(float(coord[0]))
        pin["y"] = _frac(float(coord[1]))
    if zone_id:
        pin["zoneID"] = int(zone_id)
    return pin


def _pins_from_infobox(markup: str, label: str) -> list[dict[str, Any]]:
    # Start: [url=/npc=240691/decimus]Decimus[/url]
    idx = markup.lower().find(label.lower() + ":")
    if idx < 0:
        return []
    chunk = markup[idx : idx + 400]
    pins: list[dict[str, Any]] = []
    for match in NPC_LINK_RE.finditer(chunk):
        pins.append({"npcID": int(match.group(1))})
    return pins


def _series_ids(html: str, self_id: int) -> list[int]:
    match = SERIES_TABLE_RE.search(html)
    if not match:
        return []
    ids = _unique_ints(int(m.group(1)) for m in QUEST_LINK_RE.finditer(match.group(1)))
    return [quest_id for quest_id in ids if quest_id != self_id]


def parse_quest_page(html: str, quest_id: int) -> dict[str, Any]:
    """Parse a Wowhead quest detail page into a Catalog-shaped record."""
    record: dict[str, Any] = {"id": quest_id}

    title = TITLE_RE.search(html)
    if title:
        record["name"] = html_lib.unescape(title.group(1)).strip()

    gq = G_QUESTS_RE.search(html)
    if gq and int(gq.group(1)) == quest_id:
        obj = _balanced_object(html, html.find("{", gq.end()))
        if obj:
            try:
                meta = parse_items_json("[" + obj + "]")[0]
                list_rec = record_from_listview(meta)
                list_rec.pop("id", None)
                if record.get("name") and not list_rec.get("name"):
                    list_rec.pop("name", None)
                record.update(list_rec)
            except (ValueError, IndexError):
                pass

    starts, ends, mapper_zone = _parse_mapper(html)
    infobox = ""
    im = INFOBOX_MARKUP_RE.search(html)
    if im:
        infobox = (
            im.group(1)
            .replace("\\/", "/")
            .replace("\\n", "\n")
            .replace('\\"', '"')
        )

    if not starts:
        starts = _pins_from_infobox(infobox, "Start")
    if not ends:
        ends = _pins_from_infobox(infobox, "End")

    if starts:
        record["starts"] = starts
    if ends:
        record["ends"] = ends
    if mapper_zone:
        record["zoneID"] = mapper_zone

    first = next((pin for pin in starts if pin.get("x") is not None), None)
    if first:
        coords = {"x": first["x"], "y": first["y"], "source": "quest_giver"}
        if first.get("mapID"):
            coords["mapID"] = first["mapID"]
        elif first.get("zoneID"):
            coords["zoneID"] = first["zoneID"]
        record["coords"] = coords

    description = _section_text(html, "Description")
    objectives = _section_text(html, "Objectives")
    if description:
        record["description"] = description
    if objectives:
        record["objectivesText"] = objectives

    series = _series_ids(html, quest_id)
    if series:
        record["series"] = series

    storyline = STORYLINE_RE.search(html)
    if storyline:
        record["_wowheadStorylineID"] = int(storyline.group(1))

    lower_box = infobox.lower()
    if "sharable" in lower_box:
        record["sharable"] = True
    flags: list[str] = list(record.get("flags") or [])
    for token, flag in (("daily", "daily"), ("weekly", "weekly"), ("repeatable", "repeatable")):
        if token in lower_box and flag not in flags:
            flags.append(flag)
    if flags:
        record["flags"] = flags
    categories = list(record.get("categories") or [])
    if "legendary" in lower_box and "legendary" not in categories:
        categories.append("legendary")
    if "campaign" in lower_box and "campaign" not in categories:
        # campaign icon alt-text / markup often includes "campaign"
        if "quest-campaign" in html.lower() and "campaign" not in categories:
            categories.append("campaign")
    if categories:
        record["categories"] = categories

    side_match = re.search(r"Side:\s*(Alliance|Horde|Both)", infobox, re.I)
    if side_match:
        record["faction"] = side_match.group(1).lower()
        if record["faction"] == "both":
            record["faction"] = "both"

    return record


def zone_ids_from_html(html: str) -> set[int]:
    """Collect Wowhead zone IDs mentioned on a page."""
    ids: set[int] = set()
    for match in re.finditer(r"/zone=(\d+)", html):
        ids.add(int(match.group(1)))
    return ids


__all__ = [
    "expansion_from_patch",
    "parse_quest_page",
    "record_from_listview",
    "zone_ids_from_html",
]
