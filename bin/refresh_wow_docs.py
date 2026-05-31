#!/usr/bin/env python3
"""Refresh .wow_docs/ from upstream sources per manifest.json.

Supports multi-source manifests: each file can come from a different git
repository. Useful for files outside the primary wow-ui-source mirror — e.g.
GlobalStrings.lua, which is extracted from the live client and lives in
Ketho/BlizzardInterfaceResources.

Manifest schema:
  {
    "wow_docs_root": ".",
    "sources": {
      "<source-name>": {
        "url": "<git-url>",
        "branch": "<branch>",
        "scan_roots": ["..."],
        "last_synced_commit": "<sha>",
        "last_synced_date": "<iso-date>"
      }, ...
    },
    "default_source": "<source-name>",
    "files": {
      "<local-rel>": "<upstream-rel>",                        # uses default source
      "<local-rel>": {"source": "<name>", "path": "<rel>"}    # explicit source
    }
  }

Old single-source manifests (with top-level "upstream_repo") are still read
correctly. Refresh auto-migrates them to the new format on first run.

Usage:
  python scripts/refresh_wow_docs.py
  python scripts/refresh_wow_docs.py --dry-run --diff-since-sync
  python scripts/refresh_wow_docs.py --cache-root D:/cache/onewow
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.parent.resolve()
DEFAULT_CACHE_ROOT = SCRIPT_DIR / Path(".cache/onewow-suite/sources")
DEFAULT_MANIFEST = SCRIPT_DIR / Path(".wow_docs/manifest.json")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def run_git(args: list[str], cwd: Path, capture: bool = False, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git"] + args, cwd=str(cwd), check=check, capture_output=capture, text=True,
    )


def ensure_upstream(cache_dir: Path, url: str, branch: str) -> None:
    if (cache_dir / ".git").exists():
        print(f"Updating cache: {cache_dir}", file=sys.stderr)
        run_git(["fetch", "origin", branch], cache_dir)
        run_git(["checkout", branch], cache_dir)
        run_git(["reset", "--hard", f"origin/{branch}"], cache_dir)
    else:
        cache_dir.parent.mkdir(parents=True, exist_ok=True)
        print(f"Cloning {url}", file=sys.stderr)
        print(f"  -> {cache_dir}", file=sys.stderr)
        subprocess.run(
            ["git", "clone", "--branch", branch, "--single-branch", url, str(cache_dir)],
            check=True,
        )


def get_head_commit(cache_dir: Path) -> str:
    return run_git(["rev-parse", "HEAD"], cache_dir, capture=True).stdout.strip()


def derive_source_name(url: str) -> str:
    """https://github.com/Gethe/wow-ui-source.git -> wow-ui-source"""
    name = url.rstrip("/").rsplit("/", 1)[-1]
    if name.endswith(".git"):
        name = name[:-4]
    return name


def normalize_manifest(manifest: dict, cache_root: Path) -> tuple[dict, str, bool]:
    """Convert manifest (old or new format) to internal form.

    Returns (sources, default_source, was_old_format).
    sources: {name: {url, branch, cache_dir, prev_commit, prev_date,
                     scan_roots, new_commit, new_date}}
    """
    if "sources" in manifest:
        sources = {}
        for name, src in manifest["sources"].items():
            sources[name] = {
                "url": src["url"],
                "branch": src.get("branch", "main"),
                "cache_dir": cache_root / name,
                "prev_commit": src.get("last_synced_commit", ""),
                "prev_date": src.get("last_synced_date", ""),
                "scan_roots": src.get("scan_roots", []),
                "new_commit": "",
                "new_date": "",
            }
        default = manifest.get("default_source") or next(iter(sources))
        if default not in sources:
            raise ValueError(f"default_source '{default}' not defined in sources")
        return sources, default, False

    if "upstream_repo" in manifest:
        # Old single-source format.
        name = derive_source_name(manifest["upstream_repo"])
        sources = {
            name: {
                "url": manifest["upstream_repo"],
                "branch": manifest.get("upstream_branch", "main"),
                "cache_dir": cache_root / name,
                "prev_commit": manifest.get("last_synced_commit", ""),
                "prev_date": manifest.get("last_synced_date", ""),
                "scan_roots": manifest.get("scan_roots", []),
                "new_commit": "",
                "new_date": "",
            }
        }
        return sources, name, True

    raise ValueError("Manifest has neither 'sources' nor 'upstream_repo'")


def resolve_entry(entry, default_source: str) -> tuple[str, str]:
    """File entry (str or dict) -> (source_name, upstream_path)."""
    if isinstance(entry, str):
        return default_source, entry
    if isinstance(entry, dict):
        return entry["source"], entry["path"]
    raise ValueError(f"Invalid file entry: {entry!r}")


def write_manifest(manifest_path: Path, manifest: dict, sources: dict, default_source: str) -> None:
    """Write the manifest in the new format, with stable key ordering."""
    out = {
        "wow_docs_root": manifest.get("wow_docs_root", "."),
        "sources": {
            name: {
                "url": s["url"],
                "branch": s["branch"],
                "scan_roots": s["scan_roots"],
                "last_synced_commit": s["new_commit"] or s["prev_commit"],
                "last_synced_date": s["new_date"] or s["prev_date"],
            }
            for name, s in sorted(sources.items())
        },
        "default_source": default_source,
        "files": dict(sorted(manifest["files"].items())),
    }
    manifest_path.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")


def print_diff_since(cache: Path, prev: str, new: str, paths: list[str], source_name: str) -> None:
    print(f"Source {source_name}: changes between {prev[:8]} and {new[:8]}:", file=sys.stderr)
    if run_git(["cat-file", "-e", prev], cache, capture=True, check=False).returncode != 0:
        print(f"  warn: previous commit {prev[:8]} not in cache history", file=sys.stderr)
        return
    log = run_git(
        ["log", "--oneline", "--no-decorate", f"{prev}..{new}", "--"] + paths,
        cache, capture=True, check=False,
    )
    if log.returncode == 0 and log.stdout.strip():
        for line in log.stdout.strip().splitlines():
            print(f"  {line}", file=sys.stderr)
    else:
        print(f"  (no commits touching tracked files)", file=sys.stderr)


def refresh(manifest_path: Path, cache_root: Path, dry_run: bool, diff_since: bool) -> int:
    if not manifest_path.exists():
        print(f"Error: manifest not found at {manifest_path}", file=sys.stderr)
        print(f"Run bootstrap_wow_docs_manifest.py first.", file=sys.stderr)
        return 2

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    raw_root = manifest.get("wow_docs_root", ".")
    wow_docs_root = (manifest_path.parent / raw_root).resolve()
    files: dict = manifest.get("files", {})

    if not files:
        print("Manifest has no files. Nothing to refresh.", file=sys.stderr)
        return 0

    sources, default_source, was_old_format = normalize_manifest(manifest, cache_root)

    if was_old_format:
        print("Note: manifest is in old single-source format; will migrate to new format.",
              file=sys.stderr)

    today = date.today().isoformat()
    for name, src in sources.items():
        ensure_upstream(src["cache_dir"], src["url"], src["branch"])
        src["new_commit"] = get_head_commit(src["cache_dir"])
        src["new_date"] = today

    print("", file=sys.stderr)
    print("Sources:", file=sys.stderr)
    for name, src in sources.items():
        if src["prev_commit"] == src["new_commit"]:
            note = "manifest already at this commit"
        elif src["prev_commit"]:
            note = f"was {src['prev_commit'][:12]}"
        else:
            note = "first sync"
        marker = "  (default)" if name == default_source else ""
        print(f"  {name}{marker}: {src['new_commit'][:12]}  ({note})", file=sys.stderr)
    print("", file=sys.stderr)

    if diff_since:
        files_by_source: dict[str, list[str]] = {}
        for local_rel, entry in files.items():
            try:
                src_name, up_rel = resolve_entry(entry, default_source)
                files_by_source.setdefault(src_name, []).append(up_rel)
            except (KeyError, ValueError):
                pass
        for name, paths in files_by_source.items():
            src = sources.get(name)
            if src and src["prev_commit"] and src["prev_commit"] != src["new_commit"]:
                print_diff_since(src["cache_dir"], src["prev_commit"], src["new_commit"],
                                 sorted(set(paths)), name)
        print("", file=sys.stderr)

    changed: list[tuple[str, str, str]] = []
    unchanged = 0
    missing_upstream: list[tuple[str, str, str]] = []
    bad_entries: list[tuple[str, str]] = []

    for local_rel, entry in sorted(files.items()):
        try:
            src_name, upstream_rel = resolve_entry(entry, default_source)
        except (KeyError, ValueError) as e:
            bad_entries.append((local_rel, str(e)))
            continue
        if src_name not in sources:
            bad_entries.append((local_rel, f"references unknown source '{src_name}'"))
            continue

        src = sources[src_name]
        local_path = wow_docs_root / local_rel
        upstream_path = src["cache_dir"] / upstream_rel

        if not upstream_path.exists():
            missing_upstream.append((local_rel, src_name, upstream_rel))
            continue

        upstream_hash = sha256_file(upstream_path)
        local_hash = sha256_file(local_path) if local_path.exists() else ""

        if upstream_hash != local_hash:
            changed.append((local_rel, src_name, upstream_rel))
            if not dry_run:
                local_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(upstream_path, local_path)
        else:
            unchanged += 1

    print(f"Unchanged:        {unchanged}", file=sys.stderr)
    print(f"Updated:          {len(changed)}{'  (dry run, not written)' if dry_run else ''}",
          file=sys.stderr)
    if missing_upstream:
        print(f"Missing upstream: {len(missing_upstream)}", file=sys.stderr)
    if bad_entries:
        print(f"Bad entries:      {len(bad_entries)}", file=sys.stderr)

    if changed:
        print("", file=sys.stderr)
        for local_rel, src_name, up_rel in changed:
            arrow = "would copy" if dry_run else "+"
            print(f"  {arrow}  {local_rel}  <-  [{src_name}] {up_rel}", file=sys.stderr)

    if missing_upstream:
        print("", file=sys.stderr)
        print("Files no longer present at the manifest's upstream path:", file=sys.stderr)
        for local_rel, src_name, up_rel in missing_upstream:
            print(f"  ?  {local_rel}  ->  [{src_name}] {up_rel}", file=sys.stderr)
        print("", file=sys.stderr)
        print("Edit manifest.json to point to the new path, or remove the entry.", file=sys.stderr)

    if bad_entries:
        print("", file=sys.stderr)
        print("Manifest entries that couldn't be resolved:", file=sys.stderr)
        for local_rel, reason in bad_entries:
            print(f"  !  {local_rel}: {reason}", file=sys.stderr)

    any_commit_advanced = any(s["prev_commit"] != s["new_commit"] for s in sources.values())
    should_write = not dry_run and (changed or missing_upstream or was_old_format or any_commit_advanced)

    if should_write:
        write_manifest(manifest_path, manifest, sources, default_source)
        print(f"\nUpdated manifest: {manifest_path}", file=sys.stderr)

    return 1 if (missing_upstream or bad_entries) else 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--cache-root", default=str(DEFAULT_CACHE_ROOT),
                        help=f"Parent dir for source caches; each source caches in "
                             f"<cache-root>/<source-name>/. Default: {DEFAULT_CACHE_ROOT}")
    parser.add_argument("--upstream-cache", default=None,
                        help="Deprecated: previous single-source path. Its parent will be used "
                             "as cache-root, and the basename should match the source name.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--diff-since-sync", action="store_true",
                        help="Print upstream commits between last sync and HEAD per source")
    args = parser.parse_args()

    if args.upstream_cache:
        old = Path(args.upstream_cache).expanduser().resolve()
        cache_root = old.parent
        print(f"Note: --upstream-cache is deprecated. Treating {cache_root} as --cache-root.",
              file=sys.stderr)
        print(f"      Existing cache at {old.name}/ will be reused if the source name matches.",
              file=sys.stderr)
    else:
        cache_root = Path(args.cache_root).expanduser().resolve()

    return refresh(Path(args.manifest), cache_root, args.dry_run, args.diff_since_sync)


if __name__ == "__main__":
    sys.exit(main())
