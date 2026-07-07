#!/usr/bin/env python3
"""Ketho / lua-language-server WoW API compliance audit for OneWoW Suite.

Transparent audit reproducible by reviewers: sumneko LuaLS + Ketho wow-api
Annotations/Core, Retail 12.0 targeting, project .luarc.json globals merged
with Ketho's known-global list (minus deprecated APIs and annotated C_* tables).

Usage (from repo root):
    python bin/run_ketho_audit.py
    python bin/run_ketho_audit.py --verify-manifest
    python bin/run_ketho_audit.py --verify-manifest --update-manifest
    python bin/run_ketho_audit.py --addons OneWoW_QoL,OneWoW

PowerShell wrapper (audit rule compatibility):
    bin/audit-tools/Run-KethoAudit.ps1

See .cursor/rules/1W-Ricky-Audit.mdc.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
AUDIT_TOOLS = REPO_ROOT / "bin" / "audit-tools"
WOW_API = AUDIT_TOOLS / "vscode-wow-api"
ANNOTATIONS_CORE = WOW_API / "Annotations" / "Core"
ANNOTATIONS_FRAMEXML = WOW_API / "Annotations" / "FrameXML"
LUARC_PROJECT = REPO_ROOT / ".luarc.json"
LUARC_AUDIT = AUDIT_TOOLS / "luarc.audit.json"
MANIFEST_PATH = AUDIT_TOOLS / "audit-manifest.json"
REPORTS_DIR = AUDIT_TOOLS / "reports"
MANIFEST_DIFF_PATH = REPORTS_DIR / "manifest-diff.json"
SUMMARY_PATH = REPORTS_DIR / "summary.json"

AUDIT_BASE: dict | None = None
CRITICAL_CODES = frozenset({"undefined-global", "deprecated", "deprecated-field"})

# Repo-root ignoreDir entries that still apply inside every per-addon workspace.
SHARED_IGNORE_DIRS = frozenset({".wow_docs", ".vscode", ".lua-defs", "Libs/"})

SUMMARY_OTHER_CODES = frozenset(
    {
        "undefined-field",
        "lowercase-global",
        "duplicate-index",
        "duplicate-set-field",
        "global-element",
    }
)

# Private / non-shipping tools — keep in sync with 1W-Ricky-Audit.mdc
EXCLUDED_FROM_AUDIT = frozenset(
    {
        "OneWoW_Utility_Extractor",  # private internal tool, never shipped publicly
    }
)

TS_KEY_RE = re.compile(r'"([^"]+)":\s*true')
DEPRECATED_RE = re.compile(r'"([^"]+)"')
INTERFACE_RE = re.compile(r"^##\s*Interface:\s*(.+)$", re.MULTILINE)
SAVEDVARS_RE = re.compile(r"^##\s*SavedVariables(?:PerCharacter)?:\s*(.+)$", re.MULTILINE)
PUBLISHED_API_RE = re.compile(r"^(OneWoW_[A-Za-z0-9_]+_API)\s*=", re.MULTILINE)
PUBLISHED_TABLE_RE = re.compile(r"^(OneWoW(?:_[A-Za-z0-9]+)+)\s*=\s*\{", re.MULTILINE)
SIDEBAR_RE = re.compile(r'EnsureSideBar\([^,]+,\s*"([A-Za-z0-9_]+)"\)')

# Known integration / frame globals not captured by TOC/API scans.
STATIC_SUITE_GLOBALS = frozenset(
    {
        "OneWoW",
        "OneWoW_GUI",
        "OneWoW_MinimapButton",
        "OneWoW_AltTracker",
        "OneWoW_Catalog_TradeskillAPI",
        "OneWoW_ItemPricesAPI",
    }
)


@dataclass
class AddonRecord:
    name: str
    path: Path
    lua_files: int
    total_bytes: int
    toc_interface: str


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _parse_ts_keys(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    return set(TS_KEY_RE.findall(_read_text(path)))


def _parse_deprecated_list(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    return set(DEPRECATED_RE.findall(_read_text(path)))


def _lua_files_in(addon_dir: Path) -> list[Path]:
    ignore = {"Libs", "Tools", "tools"}
    files: list[Path] = []
    for path in addon_dir.rglob("*.lua"):
        rel = path.relative_to(addon_dir)
        if any(part in ignore for part in rel.parts):
            continue
        if "Libs" in path.parts:
            continue
        files.append(path)
    return files


def _toc_interface(toc_path: Path) -> str:
    text = _read_text(toc_path)
    m = INTERFACE_RE.search(text)
    return m.group(1).strip() if m else ""


def discover_addons() -> list[AddonRecord]:
    records: list[AddonRecord] = []
    for toc in sorted(REPO_ROOT.glob("OneWoW*/OneWoW*.toc")):
        name = toc.parent.name
        if name in EXCLUDED_FROM_AUDIT:
            continue
        lua_files = _lua_files_in(toc.parent)
        total_bytes = sum(p.stat().st_size for p in lua_files)
        records.append(
            AddonRecord(
                name=name,
                path=toc.parent,
                lua_files=len(lua_files),
                total_bytes=total_bytes,
                toc_interface=_toc_interface(toc),
            )
        )
    # Hub lives at OneWoW/OneWoW.toc (not OneWoW_ prefix glob above in all cases)
    hub_toc = REPO_ROOT / "OneWoW" / "OneWoW.toc"
    if hub_toc.is_file() and not any(r.name == "OneWoW" for r in records):
        lua_files = _lua_files_in(hub_toc.parent)
        records.append(
            AddonRecord(
                name="OneWoW",
                path=hub_toc.parent,
                lua_files=len(lua_files),
                total_bytes=sum(p.stat().st_size for p in lua_files),
                toc_interface=_toc_interface(hub_toc),
            )
        )
    records.sort(key=lambda r: r.name.lower())
    return records


def _record_dict(rec: AddonRecord) -> dict:
    return {
        "name": rec.name,
        "luaFiles": rec.lua_files,
        "totalBytes": rec.total_bytes,
        "tocInterface": rec.toc_interface,
    }


def load_manifest() -> dict:
    if MANIFEST_PATH.is_file():
        return json.loads(_read_text(MANIFEST_PATH))
    return {"included": [], "excluded": sorted(EXCLUDED_FROM_AUDIT)}


def write_manifest(records: list[AddonRecord]) -> None:
    included = [_record_dict(r) for r in records]
    payload = {
        "included": included,
        "excluded": sorted(EXCLUDED_FROM_AUDIT),
    }
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def manifest_diff(records: list[AddonRecord]) -> dict:
    manifest = load_manifest()
    on_disk = {r.name: r for r in records}
    manifest_included = {e["name"]: e for e in manifest.get("included", [])}
    manifest_all = set(manifest_included) | set(manifest.get("excluded", []))

    new_addons = [
        _record_dict(on_disk[name])
        for name in sorted(on_disk)
        if name not in manifest_all
    ]
    removed_addons = sorted(name for name in manifest_included if name not in on_disk)
    changed_addons = []
    for name, rec in on_disk.items():
        prev = manifest_included.get(name)
        if not prev:
            continue
        cur = _record_dict(rec)
        if (
            prev.get("luaFiles") != cur["luaFiles"]
            or prev.get("totalBytes") != cur["totalBytes"]
            or prev.get("tocInterface") != cur["tocInterface"]
        ):
            changed_addons.append(
                {
                    "name": name,
                    "previous": prev,
                    "current": cur,
                }
            )

    needs = bool(new_addons or removed_addons or changed_addons)
    return {
        "needsUserApproval": needs,
        "newAddons": new_addons,
        "removedAddons": removed_addons,
        "changedAddons": changed_addons,
        "manifestIncluded": [e["name"] for e in manifest.get("included", [])],
        "manifestExcluded": list(manifest.get("excluded", [])),
    }


def ketho_known_globals() -> list[str]:
    wow_globals = _parse_ts_keys(WOW_API / "src" / "data" / "globals.ts")
    wow_globalapi = _parse_ts_keys(WOW_API / "src" / "data" / "globalapi.ts")
    deprecated = _parse_deprecated_list(WOW_API / "src" / "data" / "deprecated.ts")
    allowed = wow_globals - wow_globalapi - deprecated
    return sorted(allowed)


def _savedvars_from_toc(toc_path: Path) -> set[str]:
    names: set[str] = set()
    text = _read_text(toc_path)
    for match in SAVEDVARS_RE.finditer(text):
        for part in match.group(1).split(","):
            name = part.strip()
            if name:
                names.add(name)
    return names


def _publish_globals_from_lua(path: Path) -> set[str]:
    try:
        text = _read_text(path)
    except OSError:
        return set()
    names: set[str] = set()
    names.update(PUBLISHED_API_RE.findall(text))
    names.update(PUBLISHED_TABLE_RE.findall(text))
    return names


def _sidebar_globals_from_lua(path: Path) -> set[str]:
    try:
        text = _read_text(path)
    except OSError:
        return set()
    if "EnsureSideBar" not in text:
        return set()
    return set(SIDEBAR_RE.findall(text))


def discover_suite_publish_globals() -> set[str]:
    """Load-unit publish surfaces: *_API, SavedVariables, hub tables, sidebars."""
    names: set[str] = set(STATIC_SUITE_GLOBALS)

    for rec in discover_addons():
        names.add(rec.name)

    hub_toc = REPO_ROOT / "OneWoW" / "OneWoW.toc"
    toc_paths = sorted(REPO_ROOT.glob("OneWoW*/OneWoW*.toc"))
    if hub_toc.is_file() and hub_toc not in toc_paths:
        toc_paths.append(hub_toc)
    for toc_path in toc_paths:
        names.update(_savedvars_from_toc(toc_path))

    for api_path in REPO_ROOT.glob("OneWoW*/Core/API.lua"):
        if "Libs" in api_path.parts:
            continue
        names.update(_publish_globals_from_lua(api_path))

    for entry in REPO_ROOT.glob("OneWoW_*/OneWoW_*.lua"):
        if "Libs" in entry.parts:
            continue
        names.update(_publish_globals_from_lua(entry))

    hub = REPO_ROOT / "OneWoW"
    if hub.is_dir():
        for sub in ("Core", "Services", "UI"):
            subdir = hub / sub
            if subdir.is_dir():
                for path in subdir.glob("*.lua"):
                    names.update(_publish_globals_from_lua(path))

    for path in REPO_ROOT.glob("OneWoW*/**/*.lua"):
        if "Libs" in path.parts or "Locales" in path.parts:
            continue
        names.update(_sidebar_globals_from_lua(path))

    return names


def write_luarc_audit(*, include_framexml: bool) -> dict:
    global AUDIT_BASE
    if not LUARC_PROJECT.is_file():
        raise SystemExit(f"Missing project config: {LUARC_PROJECT}")
    if not ANNOTATIONS_CORE.is_dir():
        raise SystemExit(
            "Missing Ketho annotations. Clone vscode-wow-api under "
            f"{WOW_API} (see bin/audit-tools/vscode-wow-api/setup/README.md)."
        )

    base = json.loads(_read_text(LUARC_PROJECT))
    libraries = [ANNOTATIONS_CORE.as_posix()]
    if include_framexml and ANNOTATIONS_FRAMEXML.is_dir() and any(ANNOTATIONS_FRAMEXML.iterdir()):
        libraries.append(ANNOTATIONS_FRAMEXML.as_posix())

    base["workspace.library"] = libraries
    base["runtime.builtin"] = {
        "io": "disable",
        "os": "disable",
        "package": "disable",
        "basic": "disable",
        "debug": "disable",
        "math": "disable",
        "string": "disable",
        "table": "disable",
        "utf8": "disable",
    }

    project_globals = list(base.get("diagnostics.globals", []))
    suite_globals = discover_suite_publish_globals()
    merged = sorted(set(project_globals) | set(ketho_known_globals()) | suite_globals)
    base["diagnostics.globals"] = merged

    AUDIT_BASE = base
    AUDIT_TOOLS.mkdir(parents=True, exist_ok=True)
    LUARC_AUDIT.write_text(json.dumps(base, indent=2) + "\n", encoding="utf-8")
    print(f"Suite publish globals whitelisted: {len(suite_globals)}", file=sys.stderr)
    return base


def ignore_dirs_for_addon(base: dict, addon_name: str) -> list[str]:
    """Rewrite repo-root ignoreDir paths for a per-addon LuaLS workspace."""
    prefix = f"{addon_name}/"
    ignores: set[str] = set(SHARED_IGNORE_DIRS)
    for entry in base.get("workspace.ignoreDir", []):
        norm = entry.replace("\\", "/")
        if norm.startswith(prefix):
            ignores.add(norm[len(prefix) :])
        elif norm.rstrip("/") in {".wow_docs", ".vscode", ".lua-defs"}:
            ignores.add(norm)
        elif norm == "Libs/" or norm.endswith("/Libs/"):
            ignores.add("Libs/")
    return sorted(ignores)


def luarc_config_for_addon(base: dict, addon: AddonRecord) -> dict:
    cfg = json.loads(json.dumps(base))
    cfg["workspace.ignoreDir"] = ignore_dirs_for_addon(base, addon.name)
    return cfg


def find_lua_language_server() -> str:
    found = shutil.which("lua-language-server")
    if found:
        return found
    raise SystemExit(
        "lua-language-server not found on PATH. Install with:\n"
        "  winget install LuaLS.lua-language-server"
    )


def sanitize_uri(uri: str) -> str:
    repo = REPO_ROOT.as_posix().lower()
    lowered = uri.lower()
    if repo in lowered:
        idx = lowered.index(repo)
        suffix = uri[idx + len(REPO_ROOT.as_posix()) :]
        return f"file:///<repo>{suffix}"
    return uri


def sanitize_check(raw: dict | list) -> dict:
    if isinstance(raw, list):
        return {}
    out: dict = {}
    for uri, issues in raw.items():
        key = sanitize_uri(uri)
        # Publish only compliance-relevant diagnostics to keep reports small.
        kept = [issue for issue in issues if issue.get("code") in CRITICAL_CODES]
        if kept:
            out[key] = kept
    return out


def classify_issues(issues: list[dict]) -> dict[str, int]:
    counts = {
        "UndefinedGlobal": 0,
        "Deprecated": 0,
        "UndefinedField": 0,
        "LowercaseGlobal": 0,
        "Other": 0,
    }
    files: set[str] = set()
    for item in issues:
        code = item.get("code", "")
        uri = item.get("_file", "")
        if uri:
            files.add(uri)
        if code == "undefined-global":
            counts["UndefinedGlobal"] += 1
        elif code in ("deprecated", "deprecated-field"):
            counts["Deprecated"] += 1
        elif code == "undefined-field":
            counts["UndefinedField"] += 1
        elif code == "lowercase-global":
            counts["LowercaseGlobal"] += 1
        elif code in SUMMARY_OTHER_CODES:
            counts["Other"] += 1
        else:
            counts["Other"] += 1
    counts["FilesWithIssues"] = len(files)
    counts["Total"] = sum(
        counts[k]
        for k in (
            "UndefinedGlobal",
            "Deprecated",
            "UndefinedField",
            "LowercaseGlobal",
            "Other",
        )
    )
    return counts


def flatten_raw(raw: dict | list) -> list[dict]:
    if isinstance(raw, list):
        return []
    flat: list[dict] = []
    for uri, issues in raw.items():
        safe_uri = sanitize_uri(uri)
        for issue in issues:
            entry = dict(issue)
            entry["_file"] = safe_uri
            flat.append(entry)
    return flat


def run_addon_check(
    addon: AddonRecord, luals: str, base: dict, *, index: int, total: int
) -> tuple[dict, dict[str, int], float]:
    report_dir = REPORTS_DIR / addon.name
    report_dir.mkdir(parents=True, exist_ok=True)
    raw_out = report_dir / "_raw_check.json"
    check_out = report_dir / "check.json"
    cfg_path = report_dir / "luarc.addon.json"
    cfg_path.write_text(json.dumps(luarc_config_for_addon(base, addon), indent=2) + "\n", encoding="utf-8")

    print(
        f"[{index}/{total}] {addon.name} - {addon.lua_files} lua files ...",
        flush=True,
    )

    t0 = time.perf_counter()
    cmd = [
        luals,
        f"--check={addon.path}",
        f"--configpath={cfg_path}",
        "--checklevel=Information",
        "--check_format=json",
        f"--check_out_path={raw_out}",
    ]
    proc = subprocess.run(cmd, cwd=REPO_ROOT)
    elapsed = time.perf_counter() - t0
    if proc.returncode not in (0, 1):
        raise SystemExit(
            f"lua-language-server failed for {addon.name} (exit {proc.returncode})"
        )

    if not raw_out.is_file():
        raise SystemExit(f"Expected check output missing for {addon.name}: {raw_out}")

    raw = json.loads(_read_text(raw_out))
    raw_out.unlink(missing_ok=True)
    flat = flatten_raw(raw)
    counts = classify_issues(flat)
    sanitized = sanitize_check(raw)
    check_out.write_text(json.dumps(sanitized, indent=2) + "\n", encoding="utf-8")
    cfg_path.unlink(missing_ok=True)

    return sanitized, counts, elapsed


def print_summary_table(rows: list[dict]) -> None:
    print(f"{'Addon':<34} {'Verdict':<6} {'Undef':>5} {'Depr':>5} {'Total':>6}")
    print("-" * 62)
    for row in rows:
        print(
            f"{row['Addon']:<34} {row['Verdict']:<6} "
            f"{row['UndefinedGlobal']:>5} {row['Deprecated']:>5} {row['Total']:>6}"
        )


def run_audit(addons: list[str] | None, *, include_framexml: bool) -> int:
    base = write_luarc_audit(include_framexml=include_framexml)
    luals = find_lua_language_server()
    records = discover_addons()
    if addons:
        wanted = {a.strip() for a in addons if a.strip()}
        records = [r for r in records if r.name in wanted]
        missing = wanted - {r.name for r in records}
        if missing:
            print(f"Unknown or excluded addon(s): {', '.join(sorted(missing))}", file=sys.stderr)
            return 1

    total = len(records)
    print(f"Ketho audit: {total} addon(s). LuaLS progress appears below each line.\n", flush=True)

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    summary: list[dict] = []
    fail = 0
    for index, rec in enumerate(records, 1):
        _, counts, elapsed = run_addon_check(rec, luals, base, index=index, total=total)
        critical = counts["UndefinedGlobal"] + counts["Deprecated"]
        verdict = "PASS" if critical == 0 else "FAIL"
        if verdict == "FAIL":
            fail += 1
        summary.append(
            {
                "Addon": rec.name,
                "Verdict": verdict,
                "UndefinedGlobal": counts["UndefinedGlobal"],
                "Deprecated": counts["Deprecated"],
                "UndefinedField": counts["UndefinedField"],
                "LowercaseGlobal": counts["LowercaseGlobal"],
                "Other": counts["Other"],
                "Total": counts["Total"],
                "FilesWithIssues": counts["FilesWithIssues"],
                "Report": f"{rec.name}/check.json",
                "ElapsedSec": round(elapsed, 2),
            }
        )
        print(f"    -> {verdict} ({elapsed:.1f}s)\n", flush=True)

    SUMMARY_PATH.write_text(json.dumps(summary, indent=4) + "\n", encoding="utf-8")
    print()
    print_summary_table(summary)
    passed = sum(1 for r in summary if r["Verdict"] == "PASS")
    print()
    print(f"{passed}/{len(summary)} PASS. Reports at bin/audit-tools/reports/")
    return 1 if fail else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="OneWoW Ketho / LuaLS compliance audit")
    parser.add_argument("--verify-manifest", action="store_true")
    parser.add_argument("--update-manifest", action="store_true")
    parser.add_argument(
        "--addons",
        help="Comma-separated addon folder names (default: all discovered)",
    )
    parser.add_argument(
        "--include-framexml",
        action="store_true",
        help="Add Annotations/FrameXML to workspace.library when populated",
    )
    args = parser.parse_args(argv)

    records = discover_addons()
    diff = manifest_diff(records)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_DIFF_PATH.write_text(json.dumps(diff, indent=2) + "\n", encoding="utf-8")

    if args.verify_manifest:
        if args.update_manifest:
            write_manifest(records)
            diff = manifest_diff(records)
            MANIFEST_DIFF_PATH.write_text(json.dumps(diff, indent=2) + "\n", encoding="utf-8")
            print(f"Manifest updated: {MANIFEST_PATH}")
        if diff["needsUserApproval"]:
            print("Manifest deltas detected — review bin/audit-tools/reports/manifest-diff.json")
            return 2
        print("No new or changed addons since last audit.")
        return 0

    addons = args.addons.split(",") if args.addons else None

    if diff["needsUserApproval"] and not addons:
        print(
            "Manifest verification required before full audit.\n"
            "Run: python bin/run_ketho_audit.py --verify-manifest\n"
            "See bin/audit-tools/reports/manifest-diff.json",
            file=sys.stderr,
        )
        return 2

    return run_audit(addons, include_framexml=args.include_framexml)


if __name__ == "__main__":
    sys.exit(main())
