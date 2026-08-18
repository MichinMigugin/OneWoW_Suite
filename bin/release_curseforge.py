#!/usr/bin/env python3
"""Build the OneWoW Suite zip from the local tree and upload to CurseForge.

Reads ## Version: and ## Interface: from shippable TOCs (must agree).
Secrets from repo-root .env: CF_API_TOKEN, CF_PROJECT_ID (see env.example).

No git operations — commit/tag/push yourself after uploading.

Examples:
  python bin/bump_tocs.py --set-version
  python bin/release_curseforge.py --dry-run
  python bin/release_curseforge.py --release-type alpha
  python bin/release_curseforge.py --release-type release --changelog-file CHANGELOG.md

CHANGELOG.md is converted to HTML on upload (CurseForge markdown rendering is unreliable).

Requires: pip install -r bin/requirements.txt  (requests)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

_BIN = Path(__file__).resolve().parent
if str(_BIN) not in sys.path:
    sys.path.insert(0, str(_BIN))

from onewow_release_lib import (  # noqa: E402
    ROOT,
    discover_addon_dirs,
    discover_tocs,
    interface_to_game_version,
    load_dotenv,
    require_uniform_interfaces,
    require_uniform_version,
    write_suite_zip,
)

try:
    import requests
except ImportError:
    print(
        "Error: 'requests' is required. Install with: pip install -r bin/requirements.txt",
        file=sys.stderr,
    )
    sys.exit(1)

CF_API_BASE = "https://wow.curseforge.com/api"
RELEASES_DIR = ROOT / ".releases"


def _escape_html(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def _inline_md(text: str) -> str:
    """Escape HTML, then apply simple inline markdown (`code`, **bold**, *em*)."""
    s = _escape_html(text)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<em>\1</em>", s)
    return s


def markdown_to_html(md: str) -> str:
    """Convert a simple changelog markdown dialect to HTML for CurseForge.

    CF's changelogType=markdown often collapses newlines and shows raw #/- text.
    Uploading HTML is reliable. Supports: #/##/### headers, - lists (2-space
    nest), --- rules, blank lines, and basic inline `code` / *em* / **bold**.
    """
    lines = md.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out: list[str] = []
    list_stack: list[int] = []  # indent levels of open <ul>

    def close_lists_to(level: int) -> None:
        while list_stack and list_stack[-1] > level:
            out.append("</ul>")
            list_stack.pop()

    def close_all_lists() -> None:
        while list_stack:
            out.append("</ul>")
            list_stack.pop()

    for raw in lines:
        line = raw.rstrip()
        if not line.strip():
            close_all_lists()
            continue

        if line.strip() == "---":
            close_all_lists()
            out.append("<hr/>")
            continue

        if line.startswith("### "):
            close_all_lists()
            out.append(f"<h3>{_inline_md(line[4:].strip())}</h3>")
            continue
        if line.startswith("## "):
            close_all_lists()
            out.append(f"<h2>{_inline_md(line[3:].strip())}</h2>")
            continue
        if line.startswith("# "):
            close_all_lists()
            out.append(f"<h1>{_inline_md(line[2:].strip())}</h1>")
            continue

        stripped = line.lstrip(" ")
        if stripped.startswith("- "):
            indent = len(line) - len(stripped)
            level = indent // 2
            close_lists_to(level)
            if not list_stack or list_stack[-1] != level:
                out.append("<ul>")
                list_stack.append(level)
            out.append(f"<li>{_inline_md(stripped[2:].strip())}</li>")
            continue

        close_all_lists()
        out.append(f"<p>{_inline_md(line.strip())}</p>")

    close_all_lists()
    return "\n".join(out)

# Paths never included in the zip (relative to ROOT). Dot-dirs are always skipped.
ZIP_IGNORE_NAMES = frozenset(
    {
        "OneWoW_AccountSync",
        "bin",
        "AGENTS.md",
        "CLAUDE.md",
        "CONTRIBUTING.md",
        "README.md",
        "env.example",
    }
)


def build_suite_zip(version: str, addon_dirs: list[Path]) -> Path:
    """Write sibling-addon zip under .releases/; return the zip path."""
    return write_suite_zip(RELEASES_DIR / f"OneWoW Suite {version}.zip", addon_dirs)


def resolve_game_version_ids(
    session: requests.Session,
    token: str,
    interfaces: list[str],
) -> list[int]:
    """Map TOC interface numbers to CurseForge gameVersions IDs."""
    url = f"{CF_API_BASE}/game/versions"
    resp = session.get(url, headers={"X-Api-Token": token}, timeout=60)
    if resp.status_code != 200:
        raise SystemExit(
            f"CurseForge game/versions failed: HTTP {resp.status_code}\n{resp.text[:500]}"
        )
    versions = resp.json()
    by_name: dict[str, int] = {}
    for entry in versions:
        name = entry.get("name")
        vid = entry.get("id")
        if isinstance(name, str) and isinstance(vid, int):
            # Prefer first match; Retail names are unique enough for our use.
            by_name.setdefault(name, vid)

    ids: list[int] = []
    missing: list[str] = []
    for iface in interfaces:
        game_ver = interface_to_game_version(iface)
        vid = by_name.get(game_ver)
        if vid is None:
            missing.append(f"{iface} -> {game_ver}")
        else:
            ids.append(vid)
            print(f"Game version: {game_ver} (interface {iface}) -> id {vid}")

    if missing:
        raise SystemExit(
            "No CurseForge game version id for:\n  "
            + "\n  ".join(missing)
            + "\nCheck https://wow.curseforge.com/api/game/versions (with X-Api-Token)."
        )
    return ids


def upload_file(
    session: requests.Session,
    *,
    token: str,
    project_id: str,
    zip_path: Path,
    display_name: str,
    release_type: str,
    changelog: str,
    changelog_type: str,
    game_version_ids: list[int],
) -> int:
    """Upload zip; return new file id."""
    metadata = {
        "changelog": changelog,
        "changelogType": changelog_type,
        "displayName": display_name,
        "releaseType": release_type,
        "gameVersions": game_version_ids,
    }
    url = f"{CF_API_BASE}/projects/{project_id}/upload-file"
    with zip_path.open("rb") as fh:
        resp = session.post(
            url,
            headers={"X-Api-Token": token},
            data={"metadata": json.dumps(metadata)},
            files={"file": (zip_path.name, fh, "application/zip")},
            timeout=600,
        )
    if resp.status_code != 200:
        raise SystemExit(
            f"CurseForge upload failed: HTTP {resp.status_code}\n{resp.text[:1000]}"
        )
    body = resp.json()
    file_id = body.get("id")
    if not isinstance(file_id, int):
        raise SystemExit(f"Unexpected upload response: {body!r}")
    return file_id


def resolve_changelog(args: argparse.Namespace, version: str) -> tuple[str, str]:
    """Return (changelog body, changelogType).

    .md / .markdown files are converted to HTML — CurseForge's markdown
    changelog rendering often flattens newlines into a single paragraph.
    """
    if args.changelog_file is not None:
        path = Path(args.changelog_file)
        if not path.is_file():
            raise SystemExit(f"--changelog-file not found: {path}")
        text = path.read_text(encoding="utf-8")
        if path.suffix.lower() in {".md", ".markdown"}:
            return markdown_to_html(text), "html"
        return text, "text"
    if args.changelog is not None:
        return args.changelog, "text"
    return f"OneWoW Suite {version}", "text"


def get_credentials() -> tuple[str, str]:
    """CF_API_TOKEN and CF_PROJECT_ID from environment, with .env fill-in."""
    file_env = load_dotenv()
    token = os.environ.get("CF_API_TOKEN") or file_env.get("CF_API_TOKEN", "")
    project_id = os.environ.get("CF_PROJECT_ID") or file_env.get("CF_PROJECT_ID", "")
    missing = []
    if not token:
        missing.append("CF_API_TOKEN")
    if not project_id:
        missing.append("CF_PROJECT_ID")
    if missing:
        raise SystemExit(
            "Missing "
            + ", ".join(missing)
            + ". Set them in the environment or in a repo-root .env (see env.example)."
        )
    return token, project_id


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Zip shippable OneWoW addons and upload to CurseForge (no git).",
    )
    p.add_argument(
        "--release-type",
        choices=("alpha", "beta", "release"),
        default="release",
        help="CurseForge release type (default: release).",
    )
    p.add_argument(
        "--changelog",
        help="Changelog text (default: 'OneWoW Suite {version}').",
    )
    p.add_argument(
        "--changelog-file",
        metavar="PATH",
        help="Read changelog from a file (.md => markdown).",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Build the zip only; do not upload.",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.changelog is not None and args.changelog_file is not None:
        raise SystemExit("Use only one of --changelog or --changelog-file")

    tocs = discover_tocs()
    version = require_uniform_version(tocs)
    interfaces = require_uniform_interfaces(tocs)
    addon_dirs = discover_addon_dirs()

    # Sanity: do not zip ignored root names if they somehow appear.
    addon_dirs = [d for d in addon_dirs if d.name not in ZIP_IGNORE_NAMES]
    if not addon_dirs:
        raise SystemExit("No shippable addon directories to package")

    print(f"Version: {version}")
    print(f"Interfaces: {', '.join(interfaces)}")
    print(f"Addons: {len(addon_dirs)}")

    zip_path = build_suite_zip(version, addon_dirs)
    size_mb = zip_path.stat().st_size / (1024 * 1024)
    print(f"Zip: {zip_path.relative_to(ROOT).as_posix()} ({size_mb:.2f} MiB)")

    changelog, changelog_type = resolve_changelog(args, version)
    print(f"Changelog: {changelog_type} ({len(changelog)} chars)")

    if args.dry_run:
        print("Dry-run: skipping CurseForge upload.")
        return 0

    token, project_id = get_credentials()
    display_name = f"OneWoW Suite {version}.zip"

    session = requests.Session()
    game_ids = resolve_game_version_ids(session, token, interfaces)
    file_id = upload_file(
        session,
        token=token,
        project_id=project_id,
        zip_path=zip_path,
        display_name=display_name,
        release_type=args.release_type,
        changelog=changelog,
        changelog_type=changelog_type,
        game_version_ids=game_ids,
    )
    print(f"Uploaded: {display_name} ({args.release_type}) file id={file_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
