#!/usr/bin/env python3
"""Pack the shippable OneWoW addons into a stable-named GitHub zip.

Used for the rolling nightly (and current) GitHub release assets. Names stay
fixed so wow2.xyz can keep the same download doors.

Examples:
    python bin/pack_github_zip.py
    python bin/pack_github_zip.py --name OneWoW-Suite-Nightly.zip
    python bin/pack_github_zip.py --name OneWoW-Suite-Current.zip
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_BIN = Path(__file__).resolve().parent
if str(_BIN) not in sys.path:
    sys.path.insert(0, str(_BIN))

from onewow_release_lib import (  # noqa: E402
    ROOT,
    discover_addon_dirs,
    require_uniform_version,
    write_suite_zip,
)

RELEASES_DIR = ROOT / ".releases"
STABLE_NAMES = frozenset({"OneWoW-Suite-Nightly.zip", "OneWoW-Suite-Current.zip"})


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Pack a stable-named OneWoW Suite zip.")
    parser.add_argument(
        "--name",
        default="OneWoW-Suite-Nightly.zip",
        help="Zip file name (default: OneWoW-Suite-Nightly.zip).",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=RELEASES_DIR,
        help="Directory for the zip (default: .releases).",
    )
    args = parser.parse_args(argv)
    if args.name not in STABLE_NAMES:
        raise SystemExit(
            f"Zip name must be one of: {', '.join(sorted(STABLE_NAMES))}"
        )

    version = require_uniform_version()
    addon_dirs = discover_addon_dirs()
    zip_path = write_suite_zip(args.out_dir / args.name, addon_dirs)
    size_mb = zip_path.stat().st_size / (1024 * 1024)
    print(f"Version: {version}")
    print(f"Addons: {len(addon_dirs)}")
    print(f"Zip: {zip_path.relative_to(ROOT).as_posix()} ({size_mb:.2f} MiB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
