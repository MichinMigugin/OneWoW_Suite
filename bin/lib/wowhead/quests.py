"""Wowhead quest discover / detail-fetch / union-merge into QuestDB shards."""

from __future__ import annotations

import json
import re
import time
from collections import Counter
from pathlib import Path
from typing import Any

from lib.wowhead import listview
from lib.wowhead.quest_html import expansion_from_patch, parse_quest_page, record_from_listview
from lib.wowhead.quest_hygiene import BC_ZONES, clean_quest, is_bc_quest, union_merge
from lib.wowhead.quest_lua import parse_questdb_file, write_questdb_file

SUITE_ROOT = Path(__file__).resolve().parents[3]
QUESTDB_DIR = SUITE_ROOT / "OneWoW_CatalogData_Quests" / "Data" / "QuestDB"
DEFAULT_CACHE_DIR = SUITE_ROOT / "OneWoW_CatalogData_Quests" / "Tools" / "wowhead"

SHARDS: dict[int, dict[str, Any]] = {
    0: {
        "key": "classic",
        "file": "QuestDB_classic.lua",
        "list_urls": [
            "https://www.wowhead.com/eastern-kingdoms-quests",
            "https://www.wowhead.com/kalimdor-quests",
        ],
    },
    1: {
        "key": "bc",
        "file": "QuestDB_bc.lua",
        "list_urls": ["https://www.wowhead.com/outland-quests"],
    },
    2: {
        "key": "wotlk",
        "file": "QuestDB_wotlk.lua",
        "list_urls": ["https://www.wowhead.com/northrend-quests"],
    },
    3: {
        "key": "cata",
        "file": "QuestDB_cata.lua",
        "list_urls": ["https://www.wowhead.com/quests/cataclysm"],
    },
    4: {
        "key": "mop",
        "file": "QuestDB_mop.lua",
        "list_urls": ["https://www.wowhead.com/pandaria-quests"],
    },
    5: {
        "key": "wod",
        "file": "QuestDB_wod.lua",
        "list_urls": ["https://www.wowhead.com/draenor-quests"],
    },
    6: {
        "key": "legion",
        "file": "QuestDB_legion.lua",
        "list_urls": ["https://www.wowhead.com/quests/legion"],
    },
    7: {
        "key": "bfa",
        "file": "QuestDB_bfa.lua",
        "list_urls": ["https://www.wowhead.com/quests/battle-for-azeroth"],
    },
    8: {
        "key": "shadowlands",
        "file": "QuestDB_shadowlands.lua",
        "list_urls": ["https://www.wowhead.com/quests/shadowlands"],
    },
    9: {
        "key": "dragonflight",
        "file": "QuestDB_dragonflight.lua",
        "list_urls": ["https://www.wowhead.com/quests/dragonflight"],
    },
    10: {
        "key": "warwithin",
        "file": "QuestDB_warwithin.lua",
        "list_urls": ["https://www.wowhead.com/quests/war-within"],
    },
    11: {
        "key": "midnight",
        "file": "QuestDB_midnight.lua",
        "list_urls": ["https://www.wowhead.com/quests/midnight"],
    },
}

UNFILTERED_FOUND = 40000
ZONE_ID_RE = re.compile(r'\["zoneID"\]\s*=\s*(\d+)')


def shard_path(expansion: int) -> Path:
    return QUESTDB_DIR / SHARDS[expansion]["file"]


def load_shard(expansion: int) -> dict[int, dict[str, Any]]:
    return parse_questdb_file(shard_path(expansion))


def load_all_shards() -> dict[int, dict[int, dict[str, Any]]]:
    return {exp: load_shard(exp) for exp in SHARDS}


def existing_zone_ids(expansion: int) -> set[int]:
    path = shard_path(expansion)
    if not path.exists():
        return set()
    text = path.read_text(encoding="utf-8")
    return {int(match.group(1)) for match in ZONE_ID_RE.finditer(text)}


def pin_count(quests: dict[int, dict[str, Any]], field: str) -> int:
    return sum(1 for quest in quests.values() if quest.get(field))


def build_zone_to_map(all_shards: dict[int, dict[int, dict[str, Any]]]) -> dict[int, int]:
    votes: dict[int, Counter[int]] = {}
    for shard in all_shards.values():
        for quest in shard.values():
            zone_id = quest.get("zoneID")
            map_id = quest.get("mapID")
            if isinstance(zone_id, int) and isinstance(map_id, int) and map_id:
                votes.setdefault(zone_id, Counter())[map_id] += 1
    return {zone_id: counts.most_common(1)[0][0] for zone_id, counts in votes.items()}


def apply_map_ids(record: dict[str, Any], zone_to_map: dict[int, int]) -> dict[str, Any]:
    zone_id = record.get("zoneID")
    if isinstance(zone_id, int) and zone_id in zone_to_map and not record.get("mapID"):
        record["mapID"] = zone_to_map[zone_id]
    for field in ("starts", "ends"):
        pins = record.get(field)
        if not isinstance(pins, list):
            continue
        for pin in pins:
            pin_zone = pin.get("zoneID")
            if pin.get("mapID") or not isinstance(pin_zone, int):
                continue
            if pin_zone in zone_to_map:
                pin["mapID"] = zone_to_map[pin_zone]
                pin.pop("zoneID", None)
    coords = record.get("coords")
    if isinstance(coords, dict) and not coords.get("mapID"):
        map_id = record.get("mapID")
        if map_id:
            coords["mapID"] = map_id
            coords.pop("zoneID", None)
    npc_maps: list[int] = []
    for field in ("starts", "ends"):
        for pin in record.get(field) or []:
            if isinstance(pin, dict) and pin.get("mapID"):
                npc_maps.append(int(pin["mapID"]))
    zone_list = [zone_id] if isinstance(zone_id, int) else []
    if npc_maps or zone_list:
        record["mapCandidates"] = {
            "npc": sorted(set(npc_maps)),
            "zone": zone_list,
        }
    return record


class WowheadSession:
    def __init__(self, cache_dir: Path) -> None:
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.session = listview.create_session()
        self._warmed = False
        self._fetches = 0
        self.consecutive_rate_limits = 0

    def warmup(self) -> None:
        if self._warmed:
            return
        try:
            html = listview.fetch_html(self.session, listview.WARMUP_URL)
            print(f"  Warmup {listview.WARMUP_URL} -> {200 if html else 'empty'}")
            self._warmed = True
        except listview.RateLimited:
            raise
        except Exception as err:
            print(f"  Warning: warmup failed: {err}")
            self._warmed = True

    def get(self, url: str, *, cache_name: str | None = None) -> str:
        cache_path = None
        if cache_name:
            cache_path = self.cache_dir / "html" / cache_name
            if cache_path.exists():
                return cache_path.read_text(encoding="utf-8")
        if self._fetches:
            listview.polite_sleep((3.5, 7.0))
        print(f"  GET {url}")
        html = ""
        for attempt in range(5):
            try:
                if not self._warmed:
                    self.warmup()
                html = listview.fetch_html(self.session, url)
                self.consecutive_rate_limits = 0
                break
            except listview.RateLimited as err:
                self.consecutive_rate_limits += 1
                if self.consecutive_rate_limits >= 3:
                    print("  Wowhead is rate-limiting this session; stopping live fetches.")
                    return ""
                wait = 60 + attempt * 45
                print(f"  rate limited ({err}); sleeping {wait}s and refreshing session")
                time.sleep(wait)
                self.session = listview.create_session()
                self._warmed = False
            except Exception as err:
                print(f"  Warning: fetch failed {url}: {err}")
                html = ""
                break
        self._fetches += 1
        if cache_path is not None and html:
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            cache_path.write_text(html, encoding="utf-8", newline="\n")
        return html


def _quest_items(html: str) -> list[dict[str, Any]]:
    views = listview.extract_named_listviews(html)
    items = views.get("quest") or []
    if items:
        return items
    for key, rows in views.items():
        if key == "quest" or key.startswith("quest#"):
            return rows
    return []


def _same_expansion_zones(html: str, expansion: int) -> set[int]:
    """Zone IDs from zone-template listviews tagged as this expansion."""
    zones: set[int] = set()
    for key, rows in listview.extract_named_listviews(html).items():
        if key != "zone" and not key.startswith("zone#"):
            continue
        for row in rows:
            zone_id = row.get("id")
            row_exp = row.get("expansion")
            if not isinstance(zone_id, int) or zone_id <= 0:
                continue
            if row_exp is None or int(row_exp) == expansion:
                zones.add(zone_id)
    return zones


def _frequent_zone_ids(shard: dict[int, dict[str, Any]], minimum: int = 3) -> set[int]:
    counts: Counter[int] = Counter()
    for quest in shard.values():
        zone_id = quest.get("zoneID")
        if isinstance(zone_id, int) and zone_id > 0:
            counts[zone_id] += 1
    return {zone_id for zone_id, count in counts.items() if count >= minimum}


# Quest ID floors for expansions whose zone pages mix in older leftover rows.
ID_FLOOR = {
    9: 65000,
    10: 75000,
    11: 84000,
}


def is_plausible_new(expansion: int, quest_id: int, record: dict[str, Any]) -> bool:
    """True if a newly discovered ID belongs on this expansion's shard."""
    patch = record.get("firstseenpatch")
    if patch:
        return expansion_from_patch(int(patch)) == expansion
    floor = ID_FLOOR.get(expansion)
    if floor is not None:
        return quest_id >= floor
    return True


def _keep_list_record(
    quest_id: int,
    record: dict[str, Any],
    expansion: int,
    owned_elsewhere: set[int],
    shard: dict[int, dict[str, Any]],
) -> bool:
    if quest_id in owned_elsewhere:
        return False
    if quest_id in shard:
        return True
    rec_exp = record.get("expansion")
    if rec_exp is not None and rec_exp != expansion:
        return False
    return is_plausible_new(expansion, quest_id, record)


def discover_expansion(
    client: WowheadSession,
    expansion: int,
    *,
    all_shards: dict[int, dict[int, dict[str, Any]]],
) -> dict[int, dict[str, Any]]:
    """Walk expansion list pages + zone pages. Return listview-partial records."""
    meta = SHARDS[expansion]
    records: dict[int, dict[str, Any]] = {}
    shard = all_shards.get(expansion, {})
    pending_zones = _frequent_zone_ids(shard)
    if expansion == 1:
        pending_zones.update(BC_ZONES)
    seen_zones: set[int] = set()
    owned_elsewhere = {
        quest_id
        for other_exp, other in all_shards.items()
        if other_exp != expansion
        for quest_id in other
    }

    for url in meta["list_urls"]:
        html = client.get(url, cache_name=f"list/{meta['key']}/{_slug(url)}.html")
        items = _quest_items(html)
        found = listview.quests_found_count(html)
        if found and found >= UNFILTERED_FOUND:
            print(f"  skip unfiltered list {url} ({found} found)")
            continue
        kept = 0
        for item in items:
            if not isinstance(item, dict) or "id" not in item:
                continue
            record = record_from_listview(item, expansion)
            quest_id = int(record["id"])
            zone_id = record.get("zoneID")
            if isinstance(zone_id, int) and zone_id > 0:
                pending_zones.add(zone_id)
            if not _keep_list_record(quest_id, record, expansion, owned_elsewhere, shard):
                continue
            records[quest_id] = record
            kept += 1
        pending_zones.update(_same_expansion_zones(html, expansion))
        print(f"  list {url} -> {kept}/{len(items)} rows, found={found}")

    while pending_zones:
        zone_id = pending_zones.pop()
        if zone_id in seen_zones or zone_id <= 0:
            continue
        seen_zones.add(zone_id)
        html = client.get(
            f"https://www.wowhead.com/zone={zone_id}",
            cache_name=f"zone/{zone_id}.html",
        )
        if not html:
            continue
        items = _quest_items(html)
        kept = 0
        for item in items:
            if not isinstance(item, dict) or "id" not in item:
                continue
            record = record_from_listview(item, expansion)
            quest_id = int(record["id"])
            if not _keep_list_record(quest_id, record, expansion, owned_elsewhere, shard):
                continue
            records[quest_id] = record
            kept += 1
            rec_zone = record.get("zoneID")
            if isinstance(rec_zone, int) and rec_zone > 0 and rec_zone not in seen_zones:
                # Only walk the quest's own category when firstseenpatch agrees.
                if record.get("expansion") == expansion:
                    pending_zones.add(rec_zone)
        extra = {zid for zid in _same_expansion_zones(html, expansion) if zid not in seen_zones}
        pending_zones.update(extra)
        print(
            f"  zone {zone_id} -> {kept}/{len(items)} quests "
            f"zones+={len(extra)} pending={len(pending_zones)}"
        )

    print(f"  discover {meta['key']}: {len(records)} quest IDs from {len(seen_zones)} zones")
    return records


def _slug(url: str) -> str:
    return re.sub(r"[^a-zA-Z0-9._-]+", "_", url.rstrip("/").split("//", 1)[-1])


def detail_path(cache_dir: Path, quest_id: int) -> Path:
    return cache_dir / "details" / f"{quest_id}.json"


def fetch_detail(
    client: WowheadSession,
    quest_id: int,
    *,
    default_expansion: int,
    zone_to_map: dict[int, int],
    force: bool = False,
) -> dict[str, Any] | None:
    path = detail_path(client.cache_dir, quest_id)
    if path.exists() and not force:
        return json.loads(path.read_text(encoding="utf-8"))

    html = client.get(
        f"https://www.wowhead.com/quest={quest_id}",
        cache_name=f"quest/{quest_id}.html",
    )
    if not html:
        return None
    record = parse_quest_page(html, quest_id)
    if not record.get("expansion"):
        record["expansion"] = default_expansion
    record = apply_map_ids(record, zone_to_map)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    return record


def needs_detail(existing: dict[str, Any] | None, list_row: dict[str, Any] | None) -> bool:
    if existing is None:
        return True
    if not existing.get("starts") and not existing.get("ends"):
        return True
    if not existing.get("description") and not existing.get("objectivesText"):
        return True
    return False


def merge_expansion(
    expansion: int,
    *,
    list_rows: dict[int, dict[str, Any]],
    details: dict[int, dict[str, Any]],
    old: dict[int, dict[str, Any]],
    drop_new_internal: bool = True,
) -> dict[int, dict[str, Any]]:
    out = {quest_id: dict(record) for quest_id, record in old.items()}
    all_ids = set(old) | set(list_rows) | set(details)
    # Discover caches can include cross-expansion leftovers; never steal IDs.
    for quest_id in all_ids:
        old_rec = old.get(quest_id)
        new_rec = union_merge(list_rows.get(quest_id), details.get(quest_id))
        if new_rec is None:
            continue
        if old_rec is None:
            cleaned = clean_quest(new_rec, drop_internal=drop_new_internal)
            if cleaned:
                # Force the shard's expansion unless BC remap says otherwise.
                if cleaned.get("expansion") is None or (
                    expansion != 1 and not is_bc_quest(cleaned)
                ):
                    cleaned["expansion"] = expansion
                out[quest_id] = cleaned
            continue
        merged = union_merge(old_rec, new_rec)
        if merged:
            merged["id"] = quest_id
            merged["expansion"] = old_rec.get("expansion", expansion)
            out[quest_id] = merged
    return out


def write_shard_safe(
    expansion: int,
    quests: dict[int, dict[str, Any]],
    *,
    old: dict[int, dict[str, Any]],
    drop_fraction: float = 0.05,
) -> int:
    path = shard_path(expansion)
    new_starts = pin_count(quests, "starts")
    old_starts = pin_count(old, "starts")
    if old and len(quests) < len(old) * (1.0 - drop_fraction):
        print(
            f"Error: {SHARDS[expansion]['key']} count {len(quests)} "
            f"<{drop_fraction:.0%} below existing {len(old)}. Aborting."
        )
        return 1
    if old_starts and new_starts < old_starts * (1.0 - drop_fraction):
        print(
            f"Error: {SHARDS[expansion]['key']} starts {new_starts} "
            f"<{drop_fraction:.0%} below existing {old_starts}. Aborting."
        )
        return 1
    if path.exists():
        backup_dir = DEFAULT_CACHE_DIR / "bak"
        backup_dir.mkdir(parents=True, exist_ok=True)
        backup = backup_dir / path.name
        backup.write_text(path.read_text(encoding="utf-8"), encoding="utf-8", newline="\n")
        print(f"Backed up to {backup}")
    write_questdb_file(path, quests)
    print(
        f"Wrote {path.name}: {len(old)} -> {len(quests)} quests, "
        f"starts {old_starts} -> {new_starts}"
    )
    return 0
