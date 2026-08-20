#!/usr/bin/env python3
"""
Refresh OneWoW_CatalogData_Quests from Wowhead.

Discovers quest IDs from expansion list pages + /zone= pages, fetches
detail pages for new/sparse IDs, and union-merges into QuestDB shards.
Existing giver/turn-in pins and text are never dropped when Wowhead is blank.

Usage:
    python bin/wowhead/quest-refresh.py run --expansions midnight,bc --only-new
    python bin/wowhead/quest-refresh.py discover --expansions midnight
    python bin/wowhead/quest-refresh.py fetch --expansions midnight --only-new
    python bin/wowhead/quest-refresh.py merge --expansions midnight
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

BIN_DIR = Path(__file__).resolve().parents[1]
if str(BIN_DIR) not in sys.path:
    sys.path.insert(0, str(BIN_DIR))

from lib.wowhead import quests as Q  # noqa: E402

KEY_TO_EXP = {meta["key"]: exp for exp, meta in Q.SHARDS.items()}


def parse_expansions(raw: str | None) -> list[int]:
    if not raw or raw == "all":
        return list(Q.SHARDS)
    out: list[int] = []
    for part in raw.split(","):
        part = part.strip().lower()
        if part.isdigit():
            out.append(int(part))
            continue
        if part not in KEY_TO_EXP:
            raise SystemExit(f"Unknown expansion {part!r}. Use: {', '.join(KEY_TO_EXP)}")
        out.append(KEY_TO_EXP[part])
    return out


def cache_paths(cache_dir: Path, expansion: int) -> tuple[Path, Path]:
    key = Q.SHARDS[expansion]["key"]
    return cache_dir / "discover" / f"{key}.json", cache_dir / "fetched" / f"{key}.json"


def save_json(path: Path, data: dict[int, dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {str(quest_id): record for quest_id, record in data.items()}
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def load_json(path: Path) -> dict[int, dict]:
    if not path.exists():
        return {}
    raw = json.loads(path.read_text(encoding="utf-8"))
    return {int(quest_id): record for quest_id, record in raw.items()}


def cmd_discover(args: argparse.Namespace) -> int:
    cache_dir = Path(args.cache_dir)
    client = Q.WowheadSession(cache_dir)
    all_shards = Q.load_all_shards()
    for expansion in parse_expansions(args.expansions):
        print(f"=== discover {Q.SHARDS[expansion]['key']} ===")
        rows = Q.discover_expansion(client, expansion, all_shards=all_shards)
        discover_path, _ = cache_paths(cache_dir, expansion)
        save_json(discover_path, rows)
        print(f"Saved {len(rows)} list rows to {discover_path}")
    return 0


def _select_fetch_ids(
    expansion: int,
    rows: dict[int, dict],
    old: dict[int, dict],
    args: argparse.Namespace,
) -> list[int]:
    ids = sorted(set(rows) | set(old))
    chosen: list[int] = []
    for quest_id in ids:
        existing = old.get(quest_id)
        if args.only_new and existing is not None:
            continue
        if existing is None and not Q.is_plausible_new(expansion, quest_id, rows.get(quest_id) or {}):
            continue
        if args.only_sparse and existing is not None and not Q.needs_detail(existing, rows.get(quest_id)):
            continue
        if getattr(args, "min_id", 0) and quest_id < args.min_id:
            continue
        if getattr(args, "missing_text", False) and existing and existing.get("description"):
            continue
        if not args.only_new and not args.only_sparse:
            if not Q.needs_detail(existing, rows.get(quest_id)):
                continue
        chosen.append(quest_id)
    if args.limit:
        chosen = chosen[: args.limit]
    return chosen


def cmd_fetch(args: argparse.Namespace) -> int:
    cache_dir = Path(args.cache_dir)
    client = Q.WowheadSession(cache_dir)
    all_shards = Q.load_all_shards()
    zone_to_map = Q.build_zone_to_map(all_shards)
    for expansion in parse_expansions(args.expansions):
        print(f"=== fetch {Q.SHARDS[expansion]['key']} ===")
        discover_path, fetched_path = cache_paths(cache_dir, expansion)
        rows = load_json(discover_path)
        if not rows:
            print(f"  no discover cache at {discover_path}; run discover first")
            continue
        old = all_shards[expansion]
        ids = _select_fetch_ids(expansion, rows, old, args)
        print(f"  {len(ids)} detail pages to fetch")
        fetched = load_json(fetched_path)
        for i, quest_id in enumerate(ids, 1):
            print(f"  [{i}/{len(ids)}] quest={quest_id}")
            record = Q.fetch_detail(
                client,
                quest_id,
                default_expansion=expansion,
                zone_to_map=zone_to_map,
                force=args.force,
            )
            if record:
                fetched[quest_id] = record
            if client.consecutive_rate_limits >= 3:
                print("  aborting remaining live fetches (rate limit)")
                break
            if i % 25 == 0:
                save_json(fetched_path, fetched)
        save_json(fetched_path, fetched)
        print(f"Saved {len(fetched)} details to {fetched_path}")
    return 0


def cmd_merge(args: argparse.Namespace) -> int:
    cache_dir = Path(args.cache_dir)
    for expansion in parse_expansions(args.expansions):
        print(f"=== merge {Q.SHARDS[expansion]['key']} ===")
        discover_path, fetched_path = cache_paths(cache_dir, expansion)
        old = Q.load_shard(expansion)
        rows = {
            quest_id: record
            for quest_id, record in load_json(discover_path).items()
            if quest_id in old or Q.is_plausible_new(expansion, quest_id, record)
        }
        details = load_json(fetched_path)
        details_dir = cache_dir / "details"
        if details_dir.exists():
            for path in details_dir.glob("*.json"):
                quest_id = int(path.stem)
                if quest_id not in details:
                    details[quest_id] = json.loads(path.read_text(encoding="utf-8"))
        merged = Q.merge_expansion(expansion, list_rows=rows, details=details, old=old)
        rc = Q.write_shard_safe(expansion, merged, old=old)
        if rc:
            return rc
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    rc = cmd_discover(args)
    if rc:
        return rc
    rc = cmd_fetch(args)
    if rc:
        return rc
    return cmd_merge(args)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Refresh Catalog QuestDB from Wowhead")
    parser.add_argument(
        "command",
        choices=("discover", "fetch", "merge", "run"),
        help="discover IDs, fetch details, merge shards, or all three",
    )
    parser.add_argument(
        "--expansions",
        default="midnight",
        help="comma-separated keys (midnight,bc,...) or 'all'",
    )
    parser.add_argument(
        "--cache-dir",
        default=str(Q.DEFAULT_CACHE_DIR),
        help="raw HTML/JSON cache (gitignored Tools/wowhead)",
    )
    parser.add_argument("--only-new", action="store_true", help="detail-fetch IDs not already shipped")
    parser.add_argument("--only-sparse", action="store_true", help="detail-fetch shipped IDs missing pins/text")
    parser.add_argument("--missing-text", action="store_true", help="only IDs that still lack description")
    parser.add_argument("--min-id", type=int, default=0, help="skip quest IDs below this")
    parser.add_argument("--limit", type=int, default=0, help="cap detail fetches (debug)")
    parser.add_argument("--force", action="store_true", help="re-fetch cached detail pages")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    commands = {
        "discover": cmd_discover,
        "fetch": cmd_fetch,
        "merge": cmd_merge,
        "run": cmd_run,
    }
    return commands[args.command](args)


if __name__ == "__main__":
    raise SystemExit(main())
