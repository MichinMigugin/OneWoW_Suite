#!/usr/bin/env python3
"""
Generate compact Lua sound data files for OneWoW DevTool.

The script only emits WoW addon Lua output:
- one Init file with build metadata and category slices
- one or more shard files with packed sound entries

Packed entry format:
    category;subcategory;tail;fdid

The redundant "sound/" prefix is omitted from stored entries and rebuilt in Lua.

python bin/extract_listfile_audio.py -v --from-wago --product wowt --shared-when-identical --version 12.0.5.66741 --compare-version 12.0.5.66591 --outfile "temp/SoundFiles-{product}.lua"
    
  --outfile "OneWoW_Utility_DevTool/Data/SoundFiles-{product}.lua"
"""

from __future__ import annotations

import argparse
import io
import json
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Iterable

DEFAULT_API_BASE = "https://wago.tools/api/files"
DEFAULT_BUILDS_LATEST = "https://wago.tools/api/builds"
DEFAULT_PRODUCT = "wow"
DEFAULT_TIMEOUT = 600
DEFAULT_ENTRIES_PER_SHARD = 100_000

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)

UNCAT = "uncategorized"
ENTRY_DELIM = ";"
PROGRESS_LINE_INTERVAL = 200_000

SoundRecord = tuple[str, str, str, str]
SoundDataset = dict[str, object]


def vprint(verbose: bool, msg: str) -> None:
    if verbose:
        print(f"[extract_listfile_audio] {msg}", file=sys.stderr, flush=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate compact Lua sound data files for OneWoW DevTool."
    )
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument(
        "--infile",
        type=Path,
        help="Local listfile path (id;path per line).",
    )
    src.add_argument(
        "--from-wago",
        action="store_true",
        help="Download file list from wago.tools/api/files as CSV.",
    )
    parser.add_argument(
        "--outfile",
        type=str,
        required=True,
        help="Output path template. Supports {version} and {product} placeholders (e.g. SoundFiles-{product}.lua).",
    )
    parser.add_argument(
        "--data-version",
        dest="data_version",
        metavar="VERSION",
        help="Required with --infile. Supports one exact build or a comma-separated list.",
    )
    parser.add_argument(
        "--product",
        default=DEFAULT_PRODUCT,
        metavar="PRODUCT",
        help="WoW product id for wago (default: wow). Examples: wow, wowt, wowxptr.",
    )
    parser.add_argument(
        "--version",
        "--build",
        dest="version",
        metavar="VERSION",
        help="Exact build for wago files API and output metadata. Omit for latest of --product.",
    )
    parser.add_argument(
        "--compare-version",
        metavar="VERSION",
        help="Compare the primary build against another exact build.",
    )
    parser.add_argument(
        "--compare-product",
        metavar="PRODUCT",
        help="Optional wago product for --compare-version. Defaults to --product.",
    )
    parser.add_argument(
        "--shared-when-identical",
        action="store_true",
        help="When comparing builds, write one payload that accepts both exact builds if datasets match.",
    )
    parser.add_argument(
        "--api-base",
        default=DEFAULT_API_BASE,
        help=f"Wago files API base URL (default: {DEFAULT_API_BASE}).",
    )
    parser.add_argument(
        "--builds-api-base",
        default=DEFAULT_BUILDS_LATEST,
        dest="builds_api_base",
        help=f"Wago builds API base (default: {DEFAULT_BUILDS_LATEST}).",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT,
        metavar="SEC",
        help=f"HTTP timeout in seconds (default: {DEFAULT_TIMEOUT}).",
    )
    parser.add_argument(
        "--entries-per-shard",
        type=int,
        default=DEFAULT_ENTRIES_PER_SHARD,
        metavar="N",
        help=f"Max packed entries per shard (default: {DEFAULT_ENTRIES_PER_SHARD}).",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Print progress while scanning large inputs.",
    )
    return parser.parse_args()


def normalize_path_field(path_field: str) -> str:
    path_field = path_field.strip()
    if len(path_field) >= 2 and path_field[0] == '"' and path_field[-1] == '"':
        return path_field[1:-1].replace('""', '"')
    return path_field


def parse_listfile_line(line: str) -> tuple[str, str] | None:
    stripped = line.rstrip("\n\r")
    if not stripped:
        return None
    fid, sep, path_raw = stripped.partition(";")
    if not sep:
        return None
    path = normalize_path_field(path_raw)
    if not path:
        return None
    return fid, path


def normalize_sound_path(path: str) -> str:
    return path.strip().replace("\\", "/").lstrip("/").lower()


def is_audio_path(path: str) -> bool:
    return path.endswith(".mp3") or path.endswith(".ogg")


def sound_path_buckets(path: str) -> tuple[str, str]:
    if not path:
        return UNCAT, UNCAT
    parts = [part for part in path.split("/") if part]
    if not parts or parts[0] != "sound":
        return UNCAT, UNCAT
    rest = parts[1:]
    if len(rest) <= 1:
        return UNCAT, UNCAT
    if len(rest) == 2:
        return rest[0], UNCAT
    return rest[0], rest[1]


def sound_path_stored_tail(path: str, top: str, sub: str) -> str:
    if not path:
        return path
    parts = [part for part in path.split("/") if part]
    if not parts or parts[0] != "sound":
        return path
    rest = parts[1:]
    if top == UNCAT and sub == UNCAT:
        tail = "/".join(rest)
    elif sub == UNCAT:
        tail = "/".join(rest[1:])
    else:
        tail = "/".join(rest[2:])
    return tail or path


def lua_quote(text: str) -> str:
    escaped = (
        text.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )
    return f'"{escaped}"'


def lua_table_key(key: str) -> str:
    return f"[{lua_quote(key)}]"


def split_data_versions(raw: str) -> list[str]:
    versions: list[str] = []
    seen: set[str] = set()
    for part in raw.split(","):
        version = part.strip()
        if not version or version in seen:
            continue
        versions.append(version)
        seen.add(version)
    if not versions:
        raise ValueError("missing data version")
    return versions


def primary_data_version(data_versions: list[str]) -> str:
    return data_versions[0]


def lua_data_version_literal(data_versions: list[str]) -> str:
    if len(data_versions) == 1:
        return lua_quote(data_versions[0])
    return "{ " + ", ".join(lua_quote(version) for version in data_versions) + " }"


def fetch_wago_latest_version(
    product: str,
    builds_base: str,
    timeout: int,
    verbose: bool,
) -> str:
    base = builds_base.rstrip("/")
    url = f"{base}/{urllib.parse.quote(product, safe='')}/latest"
    vprint(verbose, f"Fetching latest version string: GET {url}")
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=timeout) as resp:
            data = json.load(resp)
    except urllib.error.HTTPError as err:
        print(f"HTTP error fetching latest version: {err.code} {err.reason}", file=sys.stderr)
        raise
    except OSError as err:
        print(f"Request failed (latest version): {err}", file=sys.stderr)
        raise
    if not isinstance(data, dict) or not isinstance(data.get("version"), str):
        print("Error: unexpected JSON from builds/latest (missing version).", file=sys.stderr)
        raise ValueError("bad builds/latest response")
    version = data["version"]
    vprint(verbose, f"Latest version for product {product!r}: {version}")
    return version


def resolve_outfile_path(template: str, data_version: str, product: str) -> Path:
    try:
        return Path(template.format(version=data_version, product=product))
    except KeyError as err:
        print(
            f"Error: outfile template contains unknown placeholder {err}. Supported: {{version}}, {{product}}.",
            file=sys.stderr,
        )
        raise SystemExit(1) from err


def _fid_sort_key(fid: str) -> tuple[int, str]:
    try:
        return 0, f"{int(fid):012d}"
    except ValueError:
        return 1, fid


def pack_entry(top: str, sub: str, tail: str, fid: str) -> str:
    return ENTRY_DELIM.join((top, sub, tail, fid))


def build_dataset(lines: Iterable[str], verbose: bool = False) -> tuple[SoundDataset, int, int, int]:
    matched = 0
    total = 0
    dupes = 0
    next_progress = PROGRESS_LINE_INTERVAL
    t0 = time.perf_counter()
    records_by_fid: dict[str, SoundRecord] = {}
    dupe_examples: list[tuple[str, str, str]] = []
    vprint(verbose, "Starting line scan...")

    for line in lines:
        total += 1
        if verbose and total >= next_progress:
            elapsed = time.perf_counter() - t0
            vprint(
                verbose,
                f"Progress: scanned {total:,} lines, {matched:,} audio matches so far ({elapsed:.1f}s elapsed).",
            )
            next_progress += PROGRESS_LINE_INTERVAL

        parsed = parse_listfile_line(line)
        if parsed is None:
            continue
        fid, raw_path = parsed
        path = normalize_sound_path(raw_path)
        if not is_audio_path(path):
            continue
        matched += 1
        top, sub = sound_path_buckets(path)
        tail = sound_path_stored_tail(path, top, sub)
        new_record = (top, sub, tail, fid)
        old_record = records_by_fid.get(fid)
        if old_record and old_record != new_record:
            dupes += 1
            if len(dupe_examples) < 10:
                dupe_examples.append((fid, pack_entry(*old_record), pack_entry(*new_record)))
        records_by_fid[fid] = new_record

    records = sorted(
        records_by_fid.values(),
        key=lambda record: (record[0], record[1], record[2], _fid_sort_key(record[3])),
    )

    entries: list[str] = []
    slices: dict[str, dict[str, tuple[int, int]]] = {}
    current_top: str | None = None
    current_sub: str | None = None
    slice_start = 1

    for index, record in enumerate(records, start=1):
        top, sub, tail, fid = record
        entries.append(pack_entry(top, sub, tail, fid))
        if top != current_top or sub != current_sub:
            if current_top is not None and current_sub is not None:
                slices.setdefault(current_top, {})[current_sub] = (slice_start, index - 1)
            current_top = top
            current_sub = sub
            slice_start = index

    if current_top is not None and current_sub is not None:
        slices.setdefault(current_top, {})[current_sub] = (slice_start, len(entries))

    if verbose:
        elapsed = time.perf_counter() - t0
        vprint(
            verbose,
            f"Scan finished: {total:,} lines, {matched:,} audio rows, {len(entries):,} unique sounds in {elapsed:.1f}s.",
        )
    if dupes:
        print(
            f"Warning: {dupes} duplicate file id(s) with differing paths (last wins).",
            file=sys.stderr,
        )
        for fid, previous, current in dupe_examples:
            print(f"  {fid}: {previous!r} -> {current!r}", file=sys.stderr)

    dataset: SoundDataset = {
        "entries": entries,
        "slices": slices,
    }
    return dataset, matched, total, dupes


def compare_datasets(left: SoundDataset, right: SoundDataset) -> tuple[bool, int, list[str]]:
    left_entries = left["entries"]
    right_entries = right["entries"]
    if left_entries == right_entries and left["slices"] == right["slices"]:
        return True, 0, []

    diff_count = 0
    samples: list[str] = []
    left_len = len(left_entries)
    right_len = len(right_entries)
    max_len = max(left_len, right_len)
    for index in range(max_len):
        left_entry = left_entries[index] if index < left_len else None
        right_entry = right_entries[index] if index < right_len else None
        if left_entry == right_entry:
            continue
        diff_count += 1
        if len(samples) < 10:
            samples.append(f"entry {index + 1}: {left_entry!r} != {right_entry!r}")
    return False, diff_count, samples


def render_slice_table(
    slices: dict[str, dict[str, tuple[int, int]]],
) -> list[str]:
    lines = ["{"]
    for top in sorted(slices.keys()):
        lines.append(f"\t{lua_table_key(top)} = {{")
        for sub in sorted(slices[top].keys()):
            first, last = slices[top][sub]
            lines.append(f"\t\t{lua_table_key(sub)} = {{ {first}, {last} }},")
        lines.append("\t},")
    lines.append("}")
    return lines


def write_init_file(
    init_path: Path,
    data_versions: list[str],
    slices: dict[str, dict[str, tuple[int, int]]],
) -> None:
    lines = [
        "-- AUTOMATICALLY GENERATED -- https://wago.tools/",
        "local _, Addon = ...",
        "",
        f"local dataVersion = {lua_data_version_literal(data_versions)}",
        "if not Addon.ValidateDataBuildGameBuild(dataVersion) then",
        "\treturn",
        "end",
        "",
        "Addon._SoundFilesVersion = dataVersion",
        f"Addon._SoundEntryDelimiter = {lua_quote(ENTRY_DELIM)}",
        "Addon._SoundEntries = {}",
        "Addon._SoundSlices = ",
    ]
    lines.extend(render_slice_table(slices))
    lines.append("")
    init_path.write_text("\n".join(lines), encoding="utf-8")


def write_shard_file(
    shard_path: Path,
    shard_idx: int,
    total_shards: int,
    entries: list[str],
) -> None:
    lines = [
        f"-- AUTOMATICALLY GENERATED -- shard {shard_idx}/{total_shards}",
        "local _, Addon = ...",
        'if type(Addon._SoundEntries) ~= "table" then',
        "\treturn",
        "end",
        "local E = Addon._SoundEntries",
        "",
    ]
    for entry in entries:
        lines.append(f"E[#E + 1] = {lua_quote(entry)}")
    lines.append("")
    shard_path.write_text("\n".join(lines), encoding="utf-8")


def write_dataset(
    out_path: Path,
    data_versions: list[str],
    dataset: SoundDataset,
    verbose: bool,
    *,
    entries_per_shard: int,
) -> list[Path]:
    if entries_per_shard < 1:
        print("Error: --entries-per-shard must be >= 1.", file=sys.stderr)
        raise SystemExit(1)

    entries: list[str] = dataset["entries"]
    slices: dict[str, dict[str, tuple[int, int]]] = dataset["slices"]
    parent = out_path.parent
    stem = out_path.stem
    parent.mkdir(parents=True, exist_ok=True)

    if out_path.is_file():
        out_path.unlink()
        vprint(verbose, f"Removed legacy monolithic file {out_path}.")

    init_path = parent / f"{stem}-Init.lua"
    shard_glob = f"{stem}-S*.lua"

    for old_path in parent.glob(shard_glob):
        old_path.unlink()
        vprint(verbose, f"Removed old shard {old_path.name}")

    write_init_file(init_path, data_versions, slices)
    shard_paths: list[Path] = [init_path]

    total_shards = max(1, (len(entries) + entries_per_shard - 1) // entries_per_shard) if entries else 0
    for offset in range(0, len(entries), entries_per_shard):
        shard_idx = offset // entries_per_shard + 1
        shard_path = parent / f"{stem}-S{shard_idx:04d}.lua"
        write_shard_file(
            shard_path,
            shard_idx,
            total_shards,
            entries[offset : offset + entries_per_shard],
        )
        shard_paths.append(shard_path)

    return shard_paths


def build_wago_url(api_base: str, product: str, version: str) -> str:
    query = urllib.parse.urlencode({"product": product, "format": "csv", "version": version})
    sep = "&" if "?" in api_base else "?"
    return api_base.rstrip("/") + sep + query


def read_wago_lines(url: str, timeout: int, verbose: bool) -> io.TextIOWrapper | None:
    vprint(verbose, f"Opening HTTP connection (timeout {timeout}s); first bytes can take 30s+...")
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    ctx = ssl.create_default_context()
    try:
        response = urllib.request.urlopen(req, context=ctx, timeout=timeout)
    except urllib.error.HTTPError as err:
        print(f"HTTP error: {err.code} {err.reason}", file=sys.stderr)
        if err.code == 403:
            print("Tip: 403 often means a User-Agent header is required.", file=sys.stderr)
        return None
    except OSError as err:
        print(f"Request failed: {err}", file=sys.stderr)
        return None
    return io.TextIOWrapper(response, encoding="utf-8", errors="replace", newline="")


def load_wago_dataset(
    url: str,
    timeout: int,
    verbose: bool,
) -> tuple[SoundDataset, int, int, int] | None:
    stream = read_wago_lines(url, timeout, verbose)
    if stream is None:
        return None
    try:
        return build_dataset(stream, verbose)
    finally:
        stream.close()


def load_local_dataset(
    infile: Path,
    verbose: bool,
) -> tuple[SoundDataset, int, int, int] | None:
    if not infile.is_file():
        print(f"Error: input not found: {infile}", file=sys.stderr)
        return None
    with infile.open("r", encoding="utf-8", errors="replace", newline="") as stream:
        return build_dataset(stream, verbose)


def main() -> int:
    args = parse_args()
    verbose = args.verbose
    vprint(verbose, "Starting compact sound data generation")

    if args.shared_when_identical and not args.compare_version:
        print("Error: --shared-when-identical requires --compare-version.", file=sys.stderr)
        return 1

    if args.from_wago:
        if args.version and "," in args.version:
            print("Error: --version accepts only one build when using --from-wago.", file=sys.stderr)
            return 1
        try:
            primary_version = args.version or fetch_wago_latest_version(
                args.product,
                args.builds_api_base,
                args.timeout,
                verbose,
            )
        except (urllib.error.HTTPError, OSError, ValueError):
            return 1
        data_versions = [primary_version]
    else:
        if not args.data_version:
            print("Error: --data-version is required with --infile.", file=sys.stderr)
            return 1
        try:
            data_versions = split_data_versions(args.data_version)
        except ValueError:
            print("Error: Lua output requires at least one data version.", file=sys.stderr)
            return 1
        primary_version = primary_data_version(data_versions)

    out_path = resolve_outfile_path(args.outfile, primary_version, args.product)
    vprint(verbose, f"Resolved output path: {out_path}")

    if args.from_wago:
        primary_url = build_wago_url(args.api_base, args.product, primary_version)
        if not verbose:
            print(f"GET {primary_url}", file=sys.stderr)
        primary_result = load_wago_dataset(primary_url, args.timeout, verbose)
        if primary_result is None:
            return 1
    else:
        primary_result = load_local_dataset(args.infile, verbose)
        if primary_result is None:
            return 1

    primary_dataset, matched, total, _ = primary_result
    output_versions = list(data_versions)

    if args.compare_version:
        if not args.from_wago:
            print("Error: --compare-version is only supported with --from-wago.", file=sys.stderr)
            return 1
        compare_product = args.compare_product or args.product
        compare_url = build_wago_url(args.api_base, compare_product, args.compare_version)
        compare_result = load_wago_dataset(compare_url, args.timeout, verbose)
        if compare_result is None:
            return 1
        compare_dataset, _, _, _ = compare_result
        identical, diff_count, samples = compare_datasets(primary_dataset, compare_dataset)
        if identical:
            print(
                f"Compared {primary_version} vs {args.compare_version}: identical sound datasets.",
                file=sys.stderr,
            )
            if args.shared_when_identical:
                output_versions = [primary_version, args.compare_version]
        else:
            print(
                f"Compared {primary_version} vs {args.compare_version}: {diff_count} differing packed entries.",
                file=sys.stderr,
            )
            for sample in samples:
                print(f"  {sample}", file=sys.stderr)

    shard_paths = write_dataset(
        out_path,
        output_versions,
        primary_dataset,
        verbose,
        entries_per_shard=args.entries_per_shard,
    )

    where = f"{shard_paths[0]}, {len(shard_paths) - 1} shard(s) under {out_path.parent}"
    print(f"Wrote {len(primary_dataset['entries'])} sounds to {where} (scanned {total} lines).", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
