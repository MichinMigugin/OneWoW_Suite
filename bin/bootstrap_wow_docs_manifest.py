#!/usr/bin/env python3
"""Bootstrap a manifest mapping .wow_docs/ files to upstream paths across
one or more source repositories.

Writes a multi-source manifest by walking the local .wow_docs/ tree and
matching each file to its upstream origin across every source in UPSTREAM_URLS
(below). The first source in the list is the default — files matched there are
written as plain strings; files matched in other sources get the explicit
object form ({"source": "...", "path": "..."}).

To add a new source, edit UPSTREAM_URLS and re-run. Bootstrap overwrites
manifest.json — any custom entries you've added by hand will need to be
re-applied unless they correspond to files that match a source automatically.

Matching strategy (decreasing confidence):
  1. Basename appears once across all sources              -> auto-match
  2. Basename ambiguous, exactly one upstream file's hash
     matches the local file                                -> auto-match
  3. Basename ambiguous, multiple upstream files have
     identical content matching local                      -> pick first, flag
  4. Basename matches but no upstream hash matches local   -> auto-match (likely
     stale local copy), flag for review
  5. No basename match anywhere, but content hash matches
     a file in some source                                 -> auto-match, flag
  6. No match at all                                       -> flag for review

Outputs:
  .wow_docs/manifest.json         — sources block + auto-matched files
  .wow_docs/manifest-review.txt   — files needing manual decision (omitted if empty)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

# === Source definitions ===
# Edit this list to add or change upstream sources. The first entry is the
# default source — files matched there are written as plain strings in the
# manifest's "files" block. Files matched in any other source get the explicit
# object form ({"source": "<name>", "path": "..."}).
UPSTREAM_URLS = [
    {
        "name": "wow-ui-source",
        "url": "https://github.com/Gethe/wow-ui-source.git",
        "branch": "live",
        "scan_roots": ["Interface/AddOns"]
    },
    {
        "name": "blizzard-interface-resources",
        "url": "https://github.com/Ketho/BlizzardInterfaceResources.git",
        "branch": "live",
        "scan_roots": ["Resources"]
    },
]

SCRIPT_DIR = Path(__file__).parent.parent.resolve()
DEFAULT_CACHE_ROOT = SCRIPT_DIR / Path(".cache/onewow-suite/sources")
DEFAULT_WOW_DOCS = SCRIPT_DIR / Path(".wow_docs")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def run_git(args: list[str], cwd: Path, capture: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git"] + args, cwd=str(cwd), check=True, capture_output=capture, text=True,
    )


def derive_source_name(url: str) -> str:
    name = url.rstrip("/").rsplit("/", 1)[-1]
    if name.endswith(".git"):
        name = name[:-4]
    return name


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


def index_local(wow_docs: Path) -> dict[str, str]:
    return {
        f.relative_to(wow_docs).as_posix(): sha256_file(f)
        for f in wow_docs.rglob("*.lua")
    }


def index_all_upstreams(sources: list[dict]) -> tuple[dict, dict]:
    """Return (basename_index, hash_index).

    basename_index: {basename: [(source_name, upstream_relpath, hash), ...]}
    hash_index:     {hash: [(source_name, upstream_relpath), ...]}
    """
    basename_index: dict[str, list[tuple[str, str, str]]] = defaultdict(list)
    hash_index: dict[str, list[tuple[str, str]]] = defaultdict(list)

    for src in sources:
        cache_dir = src["cache_dir"]
        for root in src["scan_roots"]:
            root_path = cache_dir / root
            if not root_path.exists():
                print(f"  warn: scan root not found in {src['name']}: {root}", file=sys.stderr)
                continue
            for f in root_path.rglob("*.lua"):
                rel = f.relative_to(cache_dir).as_posix()
                h = sha256_file(f)
                basename_index[f.name].append((src["name"], rel, h))
                hash_index[h].append((src["name"], rel))

    return basename_index, hash_index


def format_candidate(src: str, path: str) -> str:
    return f"[{src}] {path}"


def match_files(
    local: dict[str, str],
    basename_index: dict,
    hash_index: dict,
) -> tuple[dict[str, tuple[str, str]], list[tuple[str, str, list[str]]]]:
    """Return (matched, review).

    matched: {local_relpath: (source_name, upstream_relpath)}
    review:  [(local_relpath, reason, candidate_strings)]
    """
    matched: dict[str, tuple[str, str]] = {}
    review: list[tuple[str, str, list[str]]] = []

    for local_rel, local_hash in sorted(local.items()):
        basename = Path(local_rel).name
        candidates = basename_index.get(basename, [])

        if candidates:
            if len(candidates) == 1:
                src, up_path, up_hash = candidates[0]
                matched[local_rel] = (src, up_path)
                if up_hash != local_hash:
                    review.append((
                        local_rel,
                        "single basename match but hash differs (likely stale local copy)",
                        [format_candidate(src, up_path)],
                    ))
                continue

            # Multiple basename candidates — disambiguate by hash.
            hash_matches = [(s, p) for s, p, h in candidates if h == local_hash]
            if len(hash_matches) == 1:
                matched[local_rel] = hash_matches[0]
            elif len(hash_matches) > 1:
                matched[local_rel] = hash_matches[0]
                review.append((
                    local_rel,
                    "identical content at multiple upstream paths; picked first",
                    [format_candidate(s, p) for s, p in hash_matches],
                ))
            else:
                matched[local_rel] = (candidates[0][0], candidates[0][1])
                review.append((
                    local_rel,
                    "ambiguous basename, no hash match across candidates (likely stale)",
                    [format_candidate(s, p) for s, p, _ in candidates],
                ))
            continue

        # No basename match anywhere — try content hash across all sources.
        hash_candidates = hash_index.get(local_hash, [])
        if len(hash_candidates) == 1:
            src, up_path = hash_candidates[0]
            matched[local_rel] = (src, up_path)
            review.append((
                local_rel,
                f"basename mismatch but content matches via hash; verify the pick is correct",
                [format_candidate(src, up_path)],
            ))
        elif len(hash_candidates) > 1:
            matched[local_rel] = hash_candidates[0]
            review.append((
                local_rel,
                "basename mismatch; content matches multiple upstream paths; picked first",
                [format_candidate(s, p) for s, p in hash_candidates],
            ))
        else:
            review.append((local_rel, "no upstream basename or hash match", []))

    return matched, review


def write_manifest(
    path: Path,
    matched: dict[str, tuple[str, str]],
    sources: list[dict],
    default_source: str,
) -> None:
    """Write multi-source manifest. String entries for default source files,
    object entries for files from any other source."""
    files: dict = {}
    for local_rel in sorted(matched):
        src_name, up_path = matched[local_rel]
        if src_name == default_source:
            files[local_rel] = up_path
        else:
            files[local_rel] = {"source": src_name, "path": up_path}

    out = {
        "wow_docs_root": ".",
        "sources": {
            src["name"]: {
                "url": src["url"],
                "branch": src["branch"],
                "scan_roots": list(src["scan_roots"]),
                "last_synced_commit": src["commit"],
                "last_synced_date": date.today().isoformat(),
            }
            for src in sources
        },
        "default_source": default_source,
        "files": files,
    }
    path.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")


def write_review(path: Path, review: list[tuple[str, str, list[str]]], wow_docs_root: str) -> None:
    if not review:
        if path.exists():
            path.unlink()
        return
    lines = [
        "# .wow_docs manifest review",
        "#",
        "# These files need manual decision. For each, either:",
        "#   1. Find the correct upstream path/source and edit manifest.json.",
        "#      Manifest entries can be string (default source) or object form:",
        "#        \"general/GlobalStrings.lua\": {",
        "#          \"source\": \"blizzard-interface-resources\",",
        "#          \"path\": \"Resources/GlobalStrings/enUS.lua\"",
        "#        }",
        "#   2. Delete the local file if it's no longer relevant.",
        "#   3. Leave as-is — refresh will follow whatever's in manifest.json.",
        "#",
        f"# Generated: {date.today().isoformat()}",
        "",
    ]
    for local_rel, reason, candidates in review:
        lines.append(f"{wow_docs_root}/{local_rel}")
        lines.append(f"  reason: {reason}")
        if candidates:
            lines.append("  candidates:")
            for c in candidates:
                lines.append(f"    {c}")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--wow-docs", default=str(DEFAULT_WOW_DOCS),
                        help="Path to .wow_docs directory (default: .wow_docs)")
    parser.add_argument("--cache-root", default=str(DEFAULT_CACHE_ROOT),
                        help=f"Parent dir for source caches; each source caches in "
                             f"<cache-root>/<source-name>/. Default: {DEFAULT_CACHE_ROOT}")
    parser.add_argument("--manifest", default=None,
                        help="Output manifest path (default: <wow-docs>/manifest.json)")
    parser.add_argument("--review", default=None,
                        help="Output review path (default: <wow-docs>/manifest-review.txt)")
    args = parser.parse_args()

    wow_docs = Path(args.wow_docs).resolve()
    cache_root = Path(args.cache_root).expanduser().resolve()
    manifest_path = Path(args.manifest) if args.manifest else wow_docs / "manifest.json"
    review_path = Path(args.review) if args.review else wow_docs / "manifest-review.txt"

    if not wow_docs.is_dir():
        print(f"Error: {wow_docs} is not a directory", file=sys.stderr)
        return 2

    if not UPSTREAM_URLS:
        print("Error: UPSTREAM_URLS is empty", file=sys.stderr)
        return 2

    # Normalize sources: ensure each has a name, set cache_dir.
    sources: list[dict] = []
    for raw in UPSTREAM_URLS:
        src = dict(raw)
        if "name" not in src:
            src["name"] = derive_source_name(src["url"])
        src["cache_dir"] = cache_root / src["name"]
        sources.append(src)

    default_source = sources[0]["name"]

    # Sync each source.
    for src in sources:
        ensure_upstream(src["cache_dir"], src["url"], src["branch"])
        src["commit"] = get_head_commit(src["cache_dir"])

    print("", file=sys.stderr)
    print("Sources:", file=sys.stderr)
    for src in sources:
        marker = "  (default)" if src["name"] == default_source else ""
        print(f"  {src['name']}{marker}: {src['commit'][:12]}", file=sys.stderr)

    print(f"\nIndexing local files in {wow_docs}...", file=sys.stderr)
    local = index_local(wow_docs)
    print(f"  {len(local)} .lua files", file=sys.stderr)

    print(f"\nIndexing upstream files...", file=sys.stderr)
    basename_index, hash_index = index_all_upstreams(sources)
    total_upstream = sum(len(v) for v in basename_index.values())
    print(f"  {total_upstream} .lua files across {len(sources)} source(s), "
          f"{len(basename_index)} unique basenames", file=sys.stderr)

    matched, review = match_files(local, basename_index, hash_index)

    print("", file=sys.stderr)
    print(f"Auto-matched: {len(matched)} files", file=sys.stderr)
    print(f"Need review:  {len(review)} files", file=sys.stderr)

    # Per-source breakdown of matched files
    by_source: dict[str, int] = defaultdict(int)
    for src_name, _ in matched.values():
        by_source[src_name] += 1
    if len(by_source) > 1:
        for name, count in sorted(by_source.items()):
            marker = "  (default)" if name == default_source else ""
            print(f"  from {name}{marker}: {count}", file=sys.stderr)

    write_manifest(manifest_path, matched, sources, default_source)
    print(f"\nWrote {manifest_path}", file=sys.stderr)

    write_review(review_path, review, args.wow_docs.replace("\\", "/").rstrip("/"))
    if review:
        print(f"Wrote {review_path} — please review", file=sys.stderr)
    elif review_path.exists():
        print(f"(removed empty {review_path})", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
