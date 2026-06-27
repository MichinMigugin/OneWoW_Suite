#!/usr/bin/env python3
"""Inventory WoW API usage in OneWoW Suite vs .wow_docs coverage.

Scans suite Lua for C_* calls and Enum.* paths, then checks whether each
symbol is documented in .wow_docs (Documentation.lua, *ConstantsDocumentation.lua,
GlobalAPI, or other mirrored FrameXML reference files).

Usage:
  python bin/inventory_wow_api_docs.py
  python bin/inventory_wow_api_docs.py --json report.json
  python bin/inventory_wow_api_docs.py --enum-only
  python bin/inventory_wow_api_docs.py --globals-only
  python bin/inventory_wow_api_docs.py --widgets-only
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WOW_DOCS = ROOT / ".wow_docs"
GLOBAL_API = WOW_DOCS / "blizzard-interface-resources/Resources/GlobalAPI.lua"
FRAME_XML = WOW_DOCS / "blizzard-interface-resources/Resources/FrameXML.lua"
LUA_ENUM = WOW_DOCS / "blizzard-interface-resources/Resources/LuaEnum.lua"

SUITE_EXCLUDE_DIRS = {
    "Libs",
    ".wow_docs",
    ".lua-defs",
    ".vscode",
    ".releases",
    ".cache",
    ".git",
    "node_modules",
}
SUITE_EXCLUDE_PATH_PARTS = {
    "OneWoW_Bags/API/Examples",
    "OneWoW_CatalogData_Quests/Tools",
}

C_API_RE = re.compile(r"\b(C_[A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\b")
NS_RE = re.compile(r'Namespace\s*=\s*"([^"]+)"')
FUNC_NAME_RE = re.compile(r'Name\s*=\s*"([A-Za-z0-9_]+)"')
GLOBAL_API_ENTRY_RE = re.compile(r'"([^"]+)"')
ENUM_USE_RE = re.compile(r"\bEnum\.([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*)\b")
ENUM_TABLE_RE = re.compile(
    r'Name = "([A-Za-z0-9_]+)",\s*\n\s*Type = "Enumeration"',
    re.MULTILINE,
)
ENUM_FIELD_RE = re.compile(
    r'\{ Name = "([A-Za-z0-9_]+)", Type = "([A-Za-z0-9_]+)", EnumValue',
)
GLOBAL_CALL_RE = re.compile(r"(?<![:.])\b([A-Za-z_][A-Za-z0-9_]*)\s*\(")
LOCAL_FUNC_DEF_RE = re.compile(r"\b(?:local\s+)?function\s+([A-Za-z_][A-Za-z0-9_]*)")
LOCAL_FUNC_ASSIGN_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\b")
LOCAL_VAR_ASSIGN_RE = re.compile(
    r"\blocal\s+([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*="
)

# FrameXML widget / util globals: Table.Method( and Table:Method(
WIDGET_CALL_RE = re.compile(
    r"\b([A-Z][A-Za-z0-9_]*)\s*([.:])\s*([A-Za-z_][A-Za-z0-9_]*)\s*\("
)
WIDGET_FUNC_DOT_RE = re.compile(
    r"\bfunction\s+([A-Z][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*\("
)
WIDGET_FUNC_COLON_RE = re.compile(
    r"\bfunction\s+([A-Z][A-Za-z0-9_]*):([A-Za-z_][A-Za-z0-9_]*)\s*\("
)
MIXIN_ASSIGN_RE = re.compile(
    r"^([A-Z][A-Za-z0-9_]*)\s*=\s*CreateFromMixins\(([^)]+)\)",
    re.MULTILINE,
)

OPTIONAL_GLOBALS = frozenset({
    "GetMinimapShape",  # optional hook from minimap shape addons / LibDBIcon
})

LUA_CALL_EXCLUDE = frozenset({
    "and", "break", "do", "else", "elseif", "end", "for", "function", "goto",
    "if", "in", "local", "not", "or", "repeat", "return", "then", "until", "while",
    "assert", "collectgarbage", "error", "getmetatable", "ipairs", "next", "pairs",
    "pcall", "print", "rawequal", "rawget", "rawset", "select", "setmetatable",
    "tonumber", "tostring", "type", "unpack", "xpcall",
})

# Heuristic: Blizzard-style global names not defined locally and not in GlobalAPI.
BLIZZARD_GLOBAL_PREFIXES = (
    "Get", "Set", "Is", "Has", "Can", "Are", "Was", "Were", "Will", "Should",
    "Create", "Cancel", "Unit", "Player", "Browse", "Cast", "Use", "Pickup",
    "Accept", "Decline", "Buy", "Sell", "Show", "Hide", "Toggle", "Open", "Close",
    "Register", "Unregister", "Enable", "Disable", "Load", "Save", "Find", "Query",
)


def normalize(path: Path) -> str:
    return path.as_posix()


def in_suite_scope(path: Path) -> bool:
    rel = path.relative_to(ROOT)
    parts = rel.parts
    if not parts:
        return False
    if parts[0] in SUITE_EXCLUDE_DIRS:
        return False
    if parts[0] != "OneWoW" and not parts[0].startswith("OneWoW_"):
        return False
    rel_s = normalize(rel)
    if "Libs" in rel.parts:
        return False
    return not any(rel_s.startswith(p) for p in SUITE_EXCLUDE_PATH_PARTS)


def strip_lua_strings_comments(text: str) -> str:
    out: list[str] = []
    i, n = 0, len(text)
    state = "normal"
    while i < n:
        two = text[i : i + 2]
        if state == "normal":
            if text[i : i + 4] == "--[[":
                state = "block"
                i += 4
            elif two == "--":
                state = "line"
                i += 2
            elif two == "[[":
                state = "long"
                i += 2
            elif text[i] == '"':
                state = "dq"
                i += 1
            elif text[i] == "'":
                state = "sq"
                i += 1
            else:
                out.append(text[i])
                i += 1
        elif state == "line":
            if text[i] == "\n":
                out.append("\n")
                state = "normal"
            i += 1
        elif state in ("dq", "sq"):
            if text[i] == "\\":
                i += 2
            elif (state == "dq" and text[i] == '"') or (state == "sq" and text[i] == "'"):
                state = "normal"
                i += 1
            else:
                i += 1
        elif state == "block":
            if text[i : i + 2] == "]]":
                state = "normal"
                i += 2
            else:
                i += 1
        else:
            if two == "]]":
                state = "normal"
                i += 2
            else:
                i += 1
    return "".join(out)


def load_lua_enum_index() -> dict[str, set[str]]:
    """Map Enum table name -> members from Resources/LuaEnum.lua."""
    tables: dict[str, set[str]] = defaultdict(set)
    if not LUA_ENUM.is_file():
        return tables
    current: str | None = None
    for line in LUA_ENUM.read_text(encoding="utf-8", errors="replace").splitlines():
        table_match = re.match(r"\t([A-Za-z0-9_]+) = \{", line)
        if table_match:
            current = table_match.group(1)
            continue
        if current and re.match(r"\t\},", line):
            current = None
            continue
        if current:
            member_match = re.match(r"\t\t([A-Za-z0-9_]+) = ", line)
            if member_match:
                tables[current].add(member_match.group(1))
    return tables


def load_enum_documentation_index() -> tuple[dict[str, set[str]], dict[str, str]]:
    """Map Enum table name -> field names, and table -> doc file path."""
    tables: dict[str, set[str]] = defaultdict(set)
    table_files: dict[str, str] = {}

    for path in WOW_DOCS.rglob("*Documentation.lua"):
        text = path.read_text(encoding="utf-8", errors="replace")
        rel = normalize(path.relative_to(ROOT))
        for table_name in ENUM_TABLE_RE.findall(text):
            if table_name not in table_files:
                table_files[table_name] = rel
        for field_name, field_type in ENUM_FIELD_RE.findall(text):
            tables[field_type].add(field_name)
    return tables, table_files


def load_wow_docs_enum_reference_index() -> set[str]:
    """Enum.* paths referenced in mirrored FrameXML (non-documentation Lua)."""
    paths: set[str] = set()
    for path in WOW_DOCS.rglob("*.lua"):
        if path.name.endswith("Documentation.lua"):
            continue
        text = strip_lua_strings_comments(path.read_text(encoding="utf-8", errors="replace"))
        for enum_path in ENUM_USE_RE.findall(text):
            paths.add(enum_path)
    return paths


def split_enum_path(enum_path: str) -> tuple[str, str | None]:
    parts = enum_path.split(".", 1)
    table = parts[0]
    member = parts[1] if len(parts) > 1 else None
    return table, member


def classify_enum_path(
    enum_path: str,
    enum_tables: dict[str, set[str]],
    enum_table_files: dict[str, str],
    wow_docs_enum_refs: set[str],
    lua_enum_index: dict[str, set[str]],
) -> tuple[str, str | None]:
    table, member = split_enum_path(enum_path)
    doc_file = enum_table_files.get(table)

    if table in enum_tables or table in enum_table_files:
        if member is None:
            return "documented", doc_file
        if member in enum_tables.get(table, set()):
            return "documented", doc_file
        if table in lua_enum_index and member not in lua_enum_index[table]:
            return "field_missing", doc_file or ".wow_docs/blizzard-interface-resources/Resources/LuaEnum.lua"
        if table in lua_enum_index and member in lua_enum_index[table]:
            return "lua_enum_only", doc_file or ".wow_docs/blizzard-interface-resources/Resources/LuaEnum.lua"
        return "field_missing", doc_file

    if table in lua_enum_index:
        if member is None:
            return "lua_enum_only", ".wow_docs/blizzard-interface-resources/Resources/LuaEnum.lua"
        if member in lua_enum_index[table]:
            return "lua_enum_only", ".wow_docs/blizzard-interface-resources/Resources/LuaEnum.lua"
        return "field_missing", ".wow_docs/blizzard-interface-resources/Resources/LuaEnum.lua"

    if enum_path in wow_docs_enum_refs or table in {p.split(".", 1)[0] for p in wow_docs_enum_refs}:
        return "framexml_reference", doc_file

    return "missing", doc_file


def build_enum_report(
    enum_usage: dict[str, set[str]],
    enum_tables: dict[str, set[str]],
    enum_table_files: dict[str, str],
    wow_docs_enum_refs: set[str],
    lua_enum_index: dict[str, set[str]],
) -> dict:
    documented: list[dict] = []
    lua_enum_only: list[dict] = []
    field_missing: list[dict] = []
    framexml_only: list[dict] = []
    missing: list[dict] = []

    for enum_path in sorted(enum_usage):
        kind, doc_file = classify_enum_path(
            enum_path, enum_tables, enum_table_files, wow_docs_enum_refs, lua_enum_index
        )
        table, member = split_enum_path(enum_path)
        entry = {
            "path": enum_path,
            "symbol": f"Enum.{enum_path}",
            "table": table,
            "member": member,
            "coverage": kind,
            "doc_file": doc_file,
            "suite_files": sorted(enum_usage[enum_path]),
            "use_count": len(enum_usage[enum_path]),
        }
        if kind == "documented":
            documented.append(entry)
        elif kind == "lua_enum_only":
            lua_enum_only.append(entry)
        elif kind == "field_missing":
            field_missing.append(entry)
        elif kind == "framexml_reference":
            framexml_only.append(entry)
        else:
            missing.append(entry)

    tables_used = {split_enum_path(p)[0] for p in enum_usage}
    tables_with_docs = {t for t in tables_used if t in enum_table_files}
    tables_missing_docs = sorted(tables_used - tables_with_docs)

    members_by_table: dict[str, list[str]] = defaultdict(list)
    for enum_path in enum_usage:
        table, member = split_enum_path(enum_path)
        if member:
            members_by_table[table].append(member)

    return {
        "summary": {
            "enum_paths_used": len(enum_usage),
            "enum_tables_used": len(tables_used),
            "documented": len(documented),
            "lua_enum_only": len(lua_enum_only),
            "field_missing": len(field_missing),
            "framexml_reference_only": len(framexml_only),
            "missing": len(missing),
            "tables_without_constants_documentation": tables_missing_docs,
        },
        "documented_paths": sorted(documented, key=lambda e: (-e["use_count"], e["path"])),
        "lua_enum_only_paths": sorted(lua_enum_only, key=lambda e: (-e["use_count"], e["path"])),
        "field_missing_paths": sorted(field_missing, key=lambda e: (-e["use_count"], e["path"])),
        "missing_paths": sorted(missing, key=lambda e: (-e["use_count"], e["path"])),
        "framexml_only_paths": sorted(framexml_only, key=lambda e: (-e["use_count"], e["path"])),
        "tables_without_constants_documentation": {
            table: {
                "members_used": sorted(set(members_by_table.get(table, []))),
                "suite_files": sorted(
                    {f for p in enum_usage if p.startswith(table + ".") or p == table for f in enum_usage[p]}
                ),
            }
            for table in tables_missing_docs
        },
    }


def print_enum_report(enum_report: dict) -> None:
    s = enum_report["summary"]
    print("\n=== Enum.* vs .wow_docs coverage ===\n")
    print(f"Enum paths used (unique):    {s['enum_paths_used']}")
    print(f"Enum tables used:            {s['enum_tables_used']}")
    print(f"  Documented:                {s['documented']}")
    print(f"  LuaEnum.lua only:          {s.get('lua_enum_only', 0)}")
    print(f"  Table documented, field missing: {s['field_missing']}")
    print(f"  FrameXML reference only:   {s['framexml_reference_only']}")
    print(f"  Missing from .wow_docs:    {s['missing']}")

    missing_tables = s["tables_without_constants_documentation"]
    if missing_tables:
        print(f"\n--- Enum tables with NO enum table in *Documentation.lua ({len(missing_tables)}) ---")
        for table in missing_tables:
            info = enum_report["tables_without_constants_documentation"][table]
            members = info["members_used"]
            print(
                f"  Enum.{table}  ({len(members)} members, {len(info['suite_files'])} files)"
            )

    field_missing = enum_report["field_missing_paths"]
    if field_missing:
        print(f"\n--- Enum members missing from mirrored docs ({len(field_missing)}) ---")
        for e in field_missing[:40]:
            doc = e["doc_file"] or "(no table doc)"
            print(f"  Enum.{e['path']}  [{e['use_count']} files]  ({doc})")
        if len(field_missing) > 40:
            print(f"  ... and {len(field_missing) - 40} more (use --json)")

    missing_paths = enum_report["missing_paths"]
    if missing_paths:
        print(f"\n--- Enum paths with no constants doc ({len(missing_paths)}) ---")
        for e in missing_paths[:40]:
            print(f"  Enum.{e['path']}  [{e['use_count']} files]")
        if len(missing_paths) > 40:
            print(f"  ... and {len(missing_paths) - 40} more (use --json)")

    if enum_report["framexml_only_paths"]:
        print("\n--- Enum FrameXML reference only (top by usage) ---")
        for e in enum_report["framexml_only_paths"][:15]:
            print(f"  Enum.{e['path']}  [{e['use_count']} files]")


def iter_suite_lua() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*.lua"):
        if in_suite_scope(path):
            files.append(path)
    return sorted(files)


def load_named_api_list(path: Path) -> set[str]:
    entries: set[str] = set()
    if not path.is_file():
        return entries
    text = path.read_text(encoding="utf-8", errors="replace")
    for m in GLOBAL_API_ENTRY_RE.finditer(text):
        entries.add(m.group(1))
    return entries


def load_global_api() -> set[str]:
    return load_named_api_list(GLOBAL_API)


def global_api_plain_and_dotted(global_api: set[str]) -> tuple[set[str], set[str]]:
    plain = {name for name in global_api if "." not in name}
    dotted = {name for name in global_api if "." in name}
    return plain, dotted


def load_wow_docs_global_call_index() -> set[str]:
    """Global names invoked as functions in mirrored FrameXML (non-documentation Lua)."""
    names: set[str] = set()
    for path in WOW_DOCS.rglob("*.lua"):
        if path.name.endswith("Documentation.lua"):
            continue
        text = strip_lua_strings_comments(path.read_text(encoding="utf-8", errors="replace"))
        for name in GLOBAL_CALL_RE.findall(text):
            names.add(name)
    return names


def file_local_function_defs(text: str) -> set[str]:
    names = set(LOCAL_FUNC_DEF_RE.findall(text))
    names.update(LOCAL_FUNC_ASSIGN_RE.findall(text))
    for m in LOCAL_VAR_ASSIGN_RE.finditer(text):
        names.update(part.strip() for part in m.group(1).split(","))
    return names


def looks_like_blizzard_global(name: str) -> bool:
    if name.startswith("C_") or name.startswith("Enum"):
        return False
    if name[0].isupper() and any(name.startswith(prefix) for prefix in BLIZZARD_GLOBAL_PREFIXES):
        return True
    return name in {
        "hooksecurefunc",
        "issecurevariable",
        "securecall",
        "securecallfunction",
        "secureexecuterange",
        "secureinsert",
        "taintexpected",
        "tainttransfer",
        "forceinsecure",
    }


def scan_suite_global_calls() -> dict[str, set[str]]:
    """Plain global function calls in suite Lua -> defining files."""
    usage: dict[str, set[str]] = defaultdict(set)
    for path in iter_suite_lua():
        rel = normalize(path.relative_to(ROOT))
        text = strip_lua_strings_comments(path.read_text(encoding="utf-8", errors="replace"))
        local_defs = file_local_function_defs(text)
        for name in GLOBAL_CALL_RE.findall(text):
            if name in LUA_CALL_EXCLUDE or name in local_defs:
                continue
            if name.startswith("C_"):
                continue
            usage[name].add(rel)
    return usage


def classify_global_symbol(
    name: str,
    global_api_plain: set[str],
    framexml_api: set[str],
    wow_docs_calls: set[str],
) -> tuple[str, str | None]:
    if name in OPTIONAL_GLOBALS:
        return "optional_global", None
    if name in global_api_plain:
        return "global_api", ".wow_docs/blizzard-interface-resources/Resources/GlobalAPI.lua"
    if name in framexml_api:
        return "framexml_api", ".wow_docs/blizzard-interface-resources/Resources/FrameXML.lua"
    if name in wow_docs_calls:
        return "framexml_reference", None
    if looks_like_blizzard_global(name):
        return "missing", None
    return "addon_internal", None


def build_global_report(
    global_usage: dict[str, set[str]],
    global_api_plain: set[str],
    framexml_api: set[str],
    wow_docs_calls: set[str],
) -> dict:
    documented: list[dict] = []
    optional_globals: list[dict] = []
    framexml_api_only: list[dict] = []
    framexml_only: list[dict] = []
    missing: list[dict] = []
    addon_internal: list[dict] = []

    for name in sorted(global_usage):
        kind, doc_file = classify_global_symbol(name, global_api_plain, framexml_api, wow_docs_calls)
        entry = {
            "symbol": name,
            "coverage": kind,
            "doc_file": doc_file,
            "suite_files": sorted(global_usage[name]),
            "use_count": len(global_usage[name]),
        }
        if kind == "global_api":
            documented.append(entry)
        elif kind == "optional_global":
            optional_globals.append(entry)
        elif kind == "framexml_api":
            framexml_api_only.append(entry)
        elif kind == "framexml_reference":
            framexml_only.append(entry)
        elif kind == "missing":
            missing.append(entry)
        else:
            addon_internal.append(entry)

    return {
        "summary": {
            "globals_used": len(global_usage),
            "in_global_api": len(documented),
            "optional_global": len(optional_globals),
            "framexml_api_only": len(framexml_api_only),
            "framexml_reference_only": len(framexml_only),
            "missing": len(missing),
            "addon_internal": len(addon_internal),
            "global_api_catalog_size": len(global_api_plain),
        },
        "global_api_symbols": sorted(documented, key=lambda e: (-e["use_count"], e["symbol"])),
        "optional_global_symbols": sorted(optional_globals, key=lambda e: (-e["use_count"], e["symbol"])),
        "framexml_api_symbols": sorted(framexml_api_only, key=lambda e: (-e["use_count"], e["symbol"])),
        "framexml_reference_symbols": sorted(framexml_only, key=lambda e: (-e["use_count"], e["symbol"])),
        "missing_symbols": sorted(missing, key=lambda e: (-e["use_count"], e["symbol"])),
        "addon_internal_symbols": sorted(addon_internal, key=lambda e: (-e["use_count"], e["symbol"])),
    }


def print_global_report(global_report: dict) -> None:
    s = global_report["summary"]
    print("\n=== Global WoW API vs GlobalAPI.lua / FrameXML ===\n")
    print(f"Global calls used (unique):  {s['globals_used']}")
    print(f"  In GlobalAPI.lua:          {s['in_global_api']}")
    print(f"  Optional globals:          {s.get('optional_global', 0)}")
    print(f"  FrameXML.lua only:         {s['framexml_api_only']}")
    print(f"  FrameXML reference only:   {s['framexml_reference_only']}")
    print(f"  Missing from .wow_docs:    {s['missing']}")
    print(f"  Addon-internal (ignored):  {s['addon_internal']}")
    print(f"GlobalAPI.lua catalog:       {s['global_api_catalog_size']} plain symbols")

    missing = global_report["missing_symbols"]
    if missing:
        print(f"\n--- Missing / suspect globals ({len(missing)}) ---")
        for e in missing[:50]:
            print(f"  {e['symbol']}  [{e['use_count']} files]")
        if len(missing) > 50:
            print(f"  ... and {len(missing) - 50} more (use --json)")

    framexml_api = global_report["framexml_api_symbols"]
    if framexml_api:
        print(f"\n--- FrameXML.lua helpers used (top by usage) ---")
        for e in framexml_api[:20]:
            print(f"  {e['symbol']}  [{e['use_count']} files]")

    if global_report["global_api_symbols"]:
        print("\n--- Top GlobalAPI.lua symbols used in suite ---")
        for e in global_report["global_api_symbols"][:25]:
            print(f"  {e['symbol']}  [{e['use_count']} files]")


def is_widget_table_excluded(table: str) -> bool:
    return table.startswith("C_") or table == "Enum"


def load_framexml_widget_catalog() -> tuple[dict[str, dict[str, str]], set[str]]:
    """Map widget table -> method -> source (framexml_catalog or mirror path)."""
    catalog: dict[str, dict[str, str]] = defaultdict(dict)
    framexml_catalog_symbols: set[str] = set()

    for entry in load_named_api_list(FRAME_XML):
        if "." not in entry:
            continue
        table, method = entry.split(".", 1)
        catalog[table][method] = "framexml_catalog"
        framexml_catalog_symbols.add(entry)

    mixin_methods: dict[str, set[str]] = defaultdict(set)
    mixin_assignments: list[tuple[str, list[str]]] = []

    for path in WOW_DOCS.rglob("*.lua"):
        if path.name.endswith("Documentation.lua"):
            continue
        rel = normalize(path.relative_to(ROOT))
        text = strip_lua_strings_comments(path.read_text(encoding="utf-8", errors="replace"))

        for global_name, mixin_list in MIXIN_ASSIGN_RE.findall(text):
            mixins = [name.strip() for name in mixin_list.split(",") if name.strip()]
            mixin_assignments.append((global_name, mixins))

        for table, method in WIDGET_FUNC_DOT_RE.findall(text):
            if catalog[table].get(method) == "framexml_catalog":
                continue
            if method not in catalog[table]:
                catalog[table][method] = rel

        for table, method in WIDGET_FUNC_COLON_RE.findall(text):
            if table.endswith("Mixin"):
                mixin_methods[table].add(method)
                continue
            if catalog[table].get(method) == "framexml_catalog":
                continue
            if method not in catalog[table]:
                catalog[table][method] = rel

    for global_name, mixins in mixin_assignments:
        for mixin in mixins:
            for method in mixin_methods.get(mixin, set()):
                if catalog[global_name].get(method) == "framexml_catalog":
                    continue
                if method not in catalog[global_name]:
                    catalog[global_name][method] = f"mixin:{mixin}"

    return dict(catalog), framexml_catalog_symbols


def scan_suite_widget_calls() -> dict[str, set[str]]:
    """Table.Method / Table:Method calls for known FrameXML widget globals."""
    usage: dict[str, set[str]] = defaultdict(set)
    for path in iter_suite_lua():
        rel = normalize(path.relative_to(ROOT))
        text = strip_lua_strings_comments(path.read_text(encoding="utf-8", errors="replace"))
        for table, _sep, method in WIDGET_CALL_RE.findall(text):
            if is_widget_table_excluded(table):
                continue
            usage[f"{table}.{method}"].add(rel)
    return usage


def classify_widget_symbol(
    table: str,
    method: str,
    catalog: dict[str, dict[str, str]],
) -> tuple[str, str | None]:
    methods = catalog.get(table)
    if not methods:
        return "addon_internal", None
    source = methods.get(method)
    if source == "framexml_catalog":
        return "framexml_catalog", ".wow_docs/blizzard-interface-resources/Resources/FrameXML.lua"
    if source:
        if source.startswith("mixin:"):
            mixin = source.split(":", 1)[1]
            return "framexml_mirror", f".wow_docs/**/{mixin}.lua"
        return "framexml_mirror", source
    return "missing", None


def build_widget_report(
    widget_usage: dict[str, set[str]],
    catalog: dict[str, dict[str, str]],
) -> dict:
    catalog_entries = sum(len(methods) for methods in catalog.values())
    documented: list[dict] = []
    mirror_only: list[dict] = []
    missing: list[dict] = []
    tables_used: dict[str, list[str]] = defaultdict(list)

    for symbol in sorted(widget_usage):
        table, method = symbol.split(".", 1)
        if table not in catalog:
            continue
        kind, doc_file = classify_widget_symbol(table, method, catalog)
        entry = {
            "symbol": symbol,
            "table": table,
            "method": method,
            "coverage": kind,
            "doc_file": doc_file,
            "suite_files": sorted(widget_usage[symbol]),
            "use_count": len(widget_usage[symbol]),
        }
        tables_used[table].append(method)
        if kind == "framexml_catalog":
            documented.append(entry)
        elif kind == "framexml_mirror":
            mirror_only.append(entry)
        else:
            missing.append(entry)

    tables_in_suite = sorted(tables_used)
    return {
        "summary": {
            "catalog_tables": len(catalog),
            "catalog_methods": catalog_entries,
            "widget_calls_used": len(documented) + len(mirror_only) + len(missing),
            "framexml_catalog": len(documented),
            "framexml_mirror_only": len(mirror_only),
            "missing": len(missing),
            "tables_used": len(tables_in_suite),
        },
        "catalog_symbols": sorted(
            (f"{table}.{method}" for table in catalog for method in catalog[table]),
        ),
        "documented_symbols": sorted(documented, key=lambda e: (-e["use_count"], e["symbol"])),
        "mirror_only_symbols": sorted(mirror_only, key=lambda e: (-e["use_count"], e["symbol"])),
        "missing_symbols": sorted(missing, key=lambda e: (-e["use_count"], e["symbol"])),
        "tables_used": {
            table: {
                "methods_used": sorted(set(tables_used[table])),
                "suite_files": sorted(
                    {f for sym in widget_usage if sym.startswith(table + ".") for f in widget_usage[sym]}
                ),
            }
            for table in tables_in_suite
        },
    }


def print_widget_report(widget_report: dict) -> None:
    s = widget_report["summary"]
    print("\n=== FrameXML widgets vs FrameXML.lua / mirrored UI ===\n")
    print(f"Catalog tables:              {s['catalog_tables']}")
    print(f"Catalog methods:             {s['catalog_methods']}")
    print(f"Widget calls used (unique):  {s['widget_calls_used']}")
    print(f"  In FrameXML.lua catalog:   {s['framexml_catalog']}")
    print(f"  Mirror-only (.wow_docs):   {s['framexml_mirror_only']}")
    print(f"  Missing from catalog:      {s['missing']}")
    print(f"Widget tables used in suite: {s['tables_used']}")

    missing = widget_report["missing_symbols"]
    if missing:
        print(f"\n--- Missing widget methods ({len(missing)}) ---")
        for e in missing:
            print(f"  {e['symbol']}  [{e['use_count']} files]")
    else:
        print("\nAll suite widget calls match FrameXML.lua or mirrored UI definitions.")

    tables_used = widget_report["tables_used"]
    if tables_used:
        print("\n--- Widget tables used in suite ---")
        for table in sorted(tables_used, key=lambda t: (-len(tables_used[t]["suite_files"]), t)):
            info = tables_used[table]
            methods = info["methods_used"]
            print(f"  {table}  ({len(methods)} methods, {len(info['suite_files'])} files)")

    documented = widget_report["documented_symbols"]
    if documented:
        print("\n--- Top FrameXML.lua widget calls ---")
        for e in documented[:20]:
            print(f"  {e['symbol']}  [{e['use_count']} files]")

    mirror_only = widget_report["mirror_only_symbols"]
    if mirror_only:
        print("\n--- Mirror-only widget calls (not in FrameXML.lua list) ---")
        for e in mirror_only:
            doc = e["doc_file"] or "(mirror)"
            print(f"  {e['symbol']}  [{e['use_count']} files]  ({doc})")



def load_documentation_index() -> dict[str, set[str]]:
    """Map C_Namespace -> set of documented method names."""
    index: dict[str, set[str]] = defaultdict(set)
    for path in WOW_DOCS.rglob("*Documentation.lua"):
        text = path.read_text(encoding="utf-8", errors="replace")
        ns_match = NS_RE.search(text)
        if not ns_match:
            continue
        ns = ns_match.group(1)
        if not ns.startswith("C_"):
            continue
        in_functions = False
        depth = 0
        for line in text.splitlines():
            if "Functions" in line and "=" in line:
                in_functions = True
                continue
            if not in_functions:
                continue
            if line.strip().startswith("{"):
                depth += line.count("{") - line.count("}")
            fm = FUNC_NAME_RE.search(line)
            if fm and "Type" in line and "Function" in text:
                pass
            if fm:
                index[ns].add(fm.group(1))
        # Simpler: all Name = "Foo" after Namespace in file (works for Blizzard docs)
        for m in FUNC_NAME_RE.finditer(text):
            index[ns].add(m.group(1))
    return index


def load_wow_docs_symbol_index() -> set[str]:
    """All C_* and global symbols mentioned anywhere in .wow_docs Lua."""
    symbols: set[str] = set()
    for path in WOW_DOCS.rglob("*.lua"):
        if path.name.endswith("Documentation.lua"):
            continue
        text = strip_lua_strings_comments(path.read_text(encoding="utf-8", errors="replace"))
        for ns, method in C_API_RE.findall(text):
            symbols.add(f"{ns}.{method}")
        for m in GLOBAL_API_ENTRY_RE.finditer(path.read_text(encoding="utf-8", errors="replace")):
            symbols.add(m.group(1))
    return symbols


def doc_file_for_namespace(ns: str, doc_index: dict[str, set[str]]) -> str | None:
    for path in WOW_DOCS.rglob("*Documentation.lua"):
        text = path.read_text(encoding="utf-8", errors="replace")
        if f'Namespace = "{ns}"' in text:
            return normalize(path.relative_to(ROOT))
    return None


def scan_suite_usage() -> tuple[dict[str, dict[str, set[str]]], dict[str, set[str]]]:
    """Returns (c_api[ns][method] -> files, enum_paths -> files)."""
    c_usage: dict[str, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
    enum_usage: dict[str, set[str]] = defaultdict(set)

    for path in iter_suite_lua():
        rel = normalize(path.relative_to(ROOT))
        text = strip_lua_strings_comments(path.read_text(encoding="utf-8", errors="replace"))
        for ns, method in C_API_RE.findall(text):
            c_usage[ns][method].add(rel)
        for enum_path in ENUM_USE_RE.findall(text):
            enum_usage[enum_path].add(rel)
    return c_usage, enum_usage


def classify_c_symbol(
    ns: str,
    method: str,
    doc_index: dict[str, set[str]],
    global_api: set[str],
    wow_docs_refs: set[str],
) -> tuple[str, str | None]:
    full = f"{ns}.{method}"
    doc_file = doc_file_for_namespace(ns, doc_index)
    if method in doc_index.get(ns, set()):
        return "documentation", doc_file
    if full in global_api:
        return "global_api_only", doc_file
    if full in wow_docs_refs:
        return "framexml_reference", doc_file
    return "missing", doc_file


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", type=Path, help="Write full report as JSON")
    parser.add_argument(
        "--enum-only",
        action="store_true",
        help="Print only the Enum.* coverage section",
    )
    parser.add_argument(
        "--globals-only",
        action="store_true",
        help="Print only the global WoW API coverage section",
    )
    parser.add_argument(
        "--widgets-only",
        action="store_true",
        help="Print only the FrameXML widget/util coverage section",
    )
    args = parser.parse_args()

    c_usage, enum_usage = scan_suite_usage()
    global_usage = scan_suite_global_calls()
    widget_usage = scan_suite_widget_calls()
    widget_catalog, _framexml_widget_catalog = load_framexml_widget_catalog()
    widget_report = build_widget_report(widget_usage, widget_catalog)
    global_api = load_global_api()
    global_api_plain, _ = global_api_plain_and_dotted(global_api)
    framexml_api = {name for name in load_named_api_list(FRAME_XML) if "." not in name}
    wow_docs_global_calls = load_wow_docs_global_call_index()
    global_report = build_global_report(
        global_usage, global_api_plain, framexml_api, wow_docs_global_calls
    )

    enum_tables, enum_table_files = load_enum_documentation_index()
    lua_enum_index = load_lua_enum_index()
    wow_docs_enum_refs = load_wow_docs_enum_reference_index()
    enum_report = build_enum_report(
        enum_usage, enum_tables, enum_table_files, wow_docs_enum_refs, lua_enum_index
    )

    if args.enum_only:
        if args.json:
            args.json.write_text(json.dumps({"enum": enum_report}, indent=2), encoding="utf-8")
            print(f"Wrote {args.json}")
        print_enum_report(enum_report)
        return 0

    if args.globals_only:
        if args.json:
            args.json.write_text(json.dumps({"globals": global_report}, indent=2), encoding="utf-8")
            print(f"Wrote {args.json}")
        print_global_report(global_report)
        return 0

    if args.widgets_only:
        if args.json:
            args.json.write_text(json.dumps({"widgets": widget_report}, indent=2), encoding="utf-8")
            print(f"Wrote {args.json}")
        print_widget_report(widget_report)
        return 0

    doc_index = load_documentation_index()
    wow_docs_refs = load_wow_docs_symbol_index()

    missing: list[dict] = []
    global_api_only: list[dict] = []
    framexml_only: list[dict] = []
    documented: list[dict] = []

    for ns in sorted(c_usage):
        for method in sorted(c_usage[ns]):
            kind, doc_file = classify_c_symbol(ns, method, doc_index, global_api, wow_docs_refs)
            entry = {
                "symbol": f"{ns}.{method}",
                "namespace": ns,
                "method": method,
                "coverage": kind,
                "doc_file": doc_file,
                "suite_files": sorted(c_usage[ns][method]),
                "use_count": len(c_usage[ns][method]),
            }
            if kind == "missing":
                missing.append(entry)
            elif kind == "global_api_only":
                global_api_only.append(entry)
            elif kind == "framexml_reference":
                framexml_only.append(entry)
            else:
                documented.append(entry)

    # Namespace-level: suite uses C_Foo but no Documentation.lua at all
    namespaces_used = set(c_usage)
    namespaces_with_docs = {ns for ns in namespaces_used if doc_file_for_namespace(ns, doc_index)}
    namespaces_missing_docs = sorted(namespaces_used - namespaces_with_docs)

    # High-value missing: used in 3+ files or critical namespaces
    missing_sorted = sorted(missing, key=lambda e: (-e["use_count"], e["symbol"]))

    report = {
        "summary": {
            "suite_lua_files": len(iter_suite_lua()),
            "c_namespaces_used": len(namespaces_used),
            "c_symbols_used": sum(len(methods) for methods in c_usage.values()),
            "documented": len(documented),
            "global_api_only": len(global_api_only),
            "framexml_reference_only": len(framexml_only),
            "missing": len(missing),
            "namespaces_without_documentation_file": namespaces_missing_docs,
        },
        "enum": enum_report,
        "globals": global_report,
        "widgets": widget_report,
        "missing_symbols": missing_sorted,
        "global_api_only_symbols": sorted(global_api_only, key=lambda e: e["symbol"]),
        "framexml_only_symbols": sorted(framexml_only, key=lambda e: e["symbol"]),
        "namespaces_missing_documentation_file": {
            ns: {
                "methods_used": sorted(c_usage[ns]),
                "method_count": len(c_usage[ns]),
                "suite_files": sorted({f for m in c_usage[ns] for f in c_usage[ns][m]}),
            }
            for ns in namespaces_missing_docs
        },
    }

    if args.json:
        args.json.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"Wrote {args.json}")

    s = report["summary"]
    print("=== OneWoW Suite WoW API vs .wow_docs coverage ===\n")
    print(f"Suite Lua files scanned:     {s['suite_lua_files']}")
    print(f"C_* namespaces used:         {s['c_namespaces_used']}")
    print(f"C_* symbols used (unique):   {s['c_symbols_used']}")
    print(f"  Documented (Documentation.lua): {s['documented']}")
    print(f"  GlobalAPI.lua only:             {s['global_api_only']}")
    print(f"  FrameXML reference only:        {s['framexml_reference_only']}")
    print(f"  Missing from .wow_docs:         {s['missing']}")

    if namespaces_missing_docs:
        print(f"\n--- Namespaces with NO Documentation.lua ({len(namespaces_missing_docs)}) ---")
        for ns in namespaces_missing_docs:
            info = report["namespaces_missing_documentation_file"][ns]
            print(f"  {ns}  ({info['method_count']} methods, {len(info['suite_files'])} files)")

    if missing_sorted:
        print(f"\n--- Missing symbols ({len(missing_sorted)}) — fetch docs for these ---")
        for e in missing_sorted[:60]:
            print(f"  {e['symbol']}  [{e['use_count']} files]")
        if len(missing_sorted) > 60:
            print(f"  ... and {len(missing_sorted) - 60} more (use --json for full list)")

    if global_api_only:
        print(f"\n--- GlobalAPI-only (no Documentation.lua entry) — top by usage ---")
        top = sorted(global_api_only, key=lambda e: -e["use_count"])[:25]
        for e in top:
            print(f"  {e['symbol']}  [{e['use_count']} files]")

    print_global_report(global_report)
    print_widget_report(widget_report)
    print_enum_report(enum_report)

    return 0


if __name__ == "__main__":
    sys.exit(main())
