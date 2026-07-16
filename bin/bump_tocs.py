#!/usr/bin/env python3
"""Bump ## Interface and/or ## Version across shippable OneWoW suite TOCs.

Version scheme (UTC): R6.YYMM.DDHH
  R6     major line
  YYMM   year (2-digit) + month
  DDHH   day + hour (00-23)

Does not run git. When a version is written, prints the tag name to use.

Examples:
  python bin/bump_tocs.py --set-version
  python bin/bump_tocs.py --interfaces 120007 120100
  python bin/bump_tocs.py --interfaces 120007 120100 --set-version
  python bin/bump_tocs.py --set-version --version R6.2607.0906
  python bin/bump_tocs.py --print-version
  python bin/bump_tocs.py --set-version --dry-run
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

_BIN = Path(__file__).resolve().parent
if str(_BIN) not in sys.path:
    sys.path.insert(0, str(_BIN))

from onewow_release_lib import (  # noqa: E402
    INTERFACE_RE,
    ROOT,
    VERSION_RE,
    discover_tocs,
    format_interfaces,
)


def compute_version(now: datetime | None = None) -> str:
    """Return R6.YYMM.DDHH in UTC."""
    stamp = now or datetime.now(timezone.utc)
    return f"R6.{stamp:%y%m}.{stamp:%d%H}"


def patch_toc(
    path: Path,
    *,
    interfaces: str | None,
    version: str | None,
    dry_run: bool,
) -> list[str]:
    """Apply Interface/Version updates. Returns list of change descriptions."""
    text = path.read_text(encoding="utf-8")
    original = text
    changes: list[str] = []

    if interfaces is not None:
        if not INTERFACE_RE.search(text):
            raise SystemExit(f"{path}: missing ## Interface: line")
        text, n = INTERFACE_RE.subn(rf"\g<1>{interfaces}", text, count=1)
        if n:
            changes.append(f"Interface -> {interfaces}")

    if version is not None:
        if not VERSION_RE.search(text):
            raise SystemExit(f"{path}: missing ## Version: line")
        text, n = VERSION_RE.subn(rf"\g<1>{version}", text, count=1)
        if n:
            changes.append(f"Version -> {version}")

    if text != original and not dry_run:
        path.write_text(text, encoding="utf-8", newline="\n")

    return changes


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Bump ## Interface / ## Version on shippable OneWoW TOCs (no git).",
    )
    p.add_argument(
        "--interfaces",
        nargs="+",
        metavar="N",
        help="Set ## Interface: (one or more numbers, e.g. 120007 121000). Omit to leave alone.",
    )
    p.add_argument(
        "--set-version",
        action="store_true",
        help="Set ## Version: to UTC R6.YYMM.DDHH (or --version if given).",
    )
    p.add_argument(
        "--version",
        metavar="R6.…",
        help="Explicit version string (implies --set-version).",
    )
    p.add_argument(
        "--print-version",
        action="store_true",
        help="Print the version that would be used and exit (no file writes).",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Show planned edits without writing files.",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    version: str | None = None
    if args.version is not None:
        version = args.version.strip()
        if not version:
            raise SystemExit("--version must be non-empty")
        args.set_version = True
    elif args.set_version or args.print_version:
        version = compute_version()

    if args.print_version:
        if version is None:
            version = compute_version()
        print(version)
        return 0

    interfaces: str | None = None
    if args.interfaces is not None:
        interfaces = format_interfaces(args.interfaces)

    if interfaces is None and not args.set_version:
        build_parser().error("specify --interfaces and/or --set-version (or --print-version)")

    tocs = discover_tocs()
    if not tocs:
        raise SystemExit("No shippable OneWoW*.toc files found")

    updated = 0
    for toc in tocs:
        changes = patch_toc(
            toc,
            interfaces=interfaces,
            version=version if args.set_version else None,
            dry_run=args.dry_run,
        )
        if changes:
            updated += 1
            prefix = "DRY-RUN " if args.dry_run else ""
            rel = toc.relative_to(ROOT).as_posix()
            print(f"{prefix}{rel}: {'; '.join(changes)}")

    action = "Would update" if args.dry_run else "Updated"
    print(f"{action} {updated}/{len(tocs)} TOC(s)")

    if args.set_version and version is not None:
        print(f"Tag: {version}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
