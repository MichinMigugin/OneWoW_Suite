#!/usr/bin/env python3
"""Pre-commit hook: ModuleManifest ↔ FirstRun.CATALOG consumer-graph invariants.

ModuleManifest.stores (ownership / BringUp children) and
FirstRun.CATALOG[].datastores (consumer pulls) are intentionally distinct.
This check keeps them consistent — it does not require them to be identical.

Invariants (hard fail):
  1. Every FirstRun.CATALOG.addonName exists in ModuleManifest.
  2. Every CATALOG.datastores entry appears in some ModuleManifest.stores.
  3. Every ModuleManifest.stores entry has a STORE_LABEL_KEYS entry and a TOC.
  4. parentRequiredStores ⊆ that parent's stores; TOC RequiredDeps includes
     the owning hub iff the store is parent-required.

See OneWoW/Docs/ARCHITECTURE.md §4.1.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOADER = ROOT / "OneWoW" / "Core" / "AddonLoader.lua"
WIZARD = ROOT / "OneWoW" / "Core" / "FirstRunWizard.lua"

QUOTED = re.compile(r'["\']([^"\']+)["\']')
BARE_KEY = re.compile(r"^\s*([A-Za-z_][\w]*)\s*=")
REQUIRED_DEPS = re.compile(r"^##\s*RequiredDeps:\s*(.+)$", re.IGNORECASE | re.MULTILINE)


def _brace_block(text: str, open_idx: int) -> str:
    """Return the substring of a `{...}` block starting at open_idx (`{`)."""
    depth = 0
    for i in range(open_idx, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[open_idx : i + 1]
    raise ValueError(f"unbalanced braces from index {open_idx}")


def _find_assign_block(text: str, name: str) -> str:
    """Find `name = { ... }` and return the brace block body including braces."""
    m = re.search(rf"\b{re.escape(name)}\s*=\s*\{{", text)
    if not m:
        raise ValueError(f"could not find {name} = {{ ... }}")
    return _brace_block(text, m.end() - 1)


def _strip_lua_comments(text: str) -> str:
    """Remove `--` line comments and `--[[ ... ]]` blocks (good enough for tables)."""
    text = re.sub(r"--\[\[[\s\S]*?\]\]", "", text)
    out: list[str] = []
    for line in text.splitlines():
        in_sq = False
        in_dq = False
        i = 0
        kept = []
        while i < len(line):
            c = line[i]
            if c == "'" and not in_dq:
                in_sq = not in_sq
                kept.append(c)
            elif c == '"' and not in_sq:
                in_dq = not in_dq
                kept.append(c)
            elif c == "-" and not in_sq and not in_dq and i + 1 < len(line) and line[i + 1] == "-":
                break
            else:
                kept.append(c)
            i += 1
        out.append("".join(kept))
    return "\n".join(out)


def parse_module_manifest(text: str) -> dict[str, dict]:
    """Return { addon: { stores: [...], parent_required: set([...]) } }."""
    text = _strip_lua_comments(text)
    block = _find_assign_block(text, "ns.ModuleManifest")
    # Split on top-level `{ addon = "` entries.
    parts = re.split(r"\{\s*addon\s*=\s*", block)
    result: dict[str, dict] = {}
    for part in parts[1:]:
        qm = re.match(r'["\']([^"\']+)["\']', part)
        if not qm:
            continue
        addon = qm.group(1)
        stores: list[str] = []
        parent_required: set[str] = set()
        stores_m = re.search(r"\bstores\s*=\s*\{", part)
        if stores_m:
            stores_block = _brace_block(part, stores_m.end() - 1)
            stores = QUOTED.findall(stores_block)
        pr_m = re.search(r"\bparentRequiredStores\s*=\s*\{", part)
        if pr_m:
            pr_block = _brace_block(part, pr_m.end() - 1)
            for line in pr_block.splitlines():
                km = BARE_KEY.match(line)
                if km:
                    parent_required.add(km.group(1))
        result[addon] = {"stores": stores, "parent_required": parent_required}
    return result


def parse_catalog(text: str) -> list[dict]:
    """Return [{ addonName, datastores: [...] }, ...]."""
    text = _strip_lua_comments(text)
    # Prefer FirstRun.CATALOG; fall back to CATALOG assignment after FirstRun.
    try:
        block = _find_assign_block(text, "FirstRun.CATALOG")
    except ValueError:
        block = _find_assign_block(text, "CATALOG")
    entries: list[dict] = []
    # Walk addonName entries.
    for m in re.finditer(r"\baddonName\s*=\s*[\"']([^\"']+)[\"']", block):
        addon = m.group(1)
        # Slice from this match to the next addonName or end of block.
        start = m.start()
        nxt = re.search(r"\baddonName\s*=\s*[\"']", block[m.end() :])
        end = m.end() + nxt.start() if nxt else len(block)
        chunk = block[start:end]
        datastores: list[str] = []
        ds_m = re.search(r"\bdatastores\s*=\s*\{", chunk)
        if ds_m:
            ds_block = _brace_block(chunk, ds_m.end() - 1)
            datastores = QUOTED.findall(ds_block)
        entries.append({"addonName": addon, "datastores": datastores})
    return entries


def parse_store_label_keys(text: str) -> set[str]:
    text = _strip_lua_comments(text)
    block = _find_assign_block(text, "STORE_LABEL_KEYS")
    keys: set[str] = set()
    for line in block.splitlines():
        km = BARE_KEY.match(line)
        if km:
            keys.add(km.group(1))
    return keys


def toc_required_deps(store: str) -> list[str] | None:
    toc = ROOT / store / f"{store}.toc"
    if not toc.is_file():
        return None
    text = toc.read_text(encoding="utf-8")
    m = REQUIRED_DEPS.search(text)
    if not m:
        return []
    return [d.strip() for d in m.group(1).split(",") if d.strip()]


def main() -> int:
    errors: list[str] = []

    try:
        loader_text = LOADER.read_text(encoding="utf-8")
        wizard_text = WIZARD.read_text(encoding="utf-8")
    except OSError as e:
        print(f"error reading sources: {e}", file=sys.stderr)
        return 1

    try:
        manifest = parse_module_manifest(loader_text)
        catalog = parse_catalog(wizard_text)
        label_keys = parse_store_label_keys(loader_text)
    except ValueError as e:
        print(f"parse error: {e}", file=sys.stderr)
        return 1

    owned_stores: dict[str, str] = {}  # store -> owning parent
    for parent, info in manifest.items():
        for store in info["stores"]:
            if store in owned_stores:
                errors.append(
                    f"store {store!r} listed under both "
                    f"{owned_stores[store]!r} and {parent!r}"
                )
            owned_stores[store] = parent

    # 1. CATALOG features ⊆ ModuleManifest
    for entry in catalog:
        name = entry["addonName"]
        if name not in manifest:
            errors.append(
                f"FirstRun.CATALOG feature {name!r} is missing from ModuleManifest"
            )

    # 2. Consumer pulls ⊆ owned stores
    for entry in catalog:
        for ds in entry["datastores"]:
            if ds not in owned_stores:
                errors.append(
                    f"FirstRun.CATALOG[{entry['addonName']!r}].datastores "
                    f"lists unknown store {ds!r} (not in any ModuleManifest.stores)"
                )

    # 3. STORE_LABEL_KEYS + TOC for every owned store
    for store, parent in sorted(owned_stores.items()):
        if store not in label_keys:
            errors.append(
                f"ModuleManifest store {store!r} (parent {parent}) "
                f"missing STORE_LABEL_KEYS entry"
            )
        deps = toc_required_deps(store)
        if deps is None:
            errors.append(
                f"ModuleManifest store {store!r} has no TOC at "
                f"{store}/{store}.toc"
            )

    # 4. parentRequiredStores ⊆ stores; TOC RequiredDeps match
    for parent, info in manifest.items():
        for store in info["parent_required"]:
            if store not in info["stores"]:
                errors.append(
                    f"parentRequiredStores[{store!r}] under {parent!r} "
                    f"is not in that parent's stores list"
                )
        for store in info["stores"]:
            deps = toc_required_deps(store)
            if deps is None:
                continue
            required = store in info["parent_required"]
            has_parent = parent in deps
            if required and not has_parent:
                errors.append(
                    f"{store}.toc RequiredDeps must include owning hub {parent!r} "
                    f"(listed in parentRequiredStores)"
                )
            if not required and has_parent:
                errors.append(
                    f"{store}.toc RequiredDeps must not include hub {parent!r} "
                    f"(not in parentRequiredStores; use RequiredDeps: OneWoW only)"
                )

    if errors:
        print("Manifest ↔ CATALOG consumer-graph alignment failed:\n")
        for err in errors:
            print(f"  - {err}")
        print()
        print("Ownership: ModuleManifest.stores / parentRequiredStores / STORE_LABEL_KEYS")
        print("Consumer pulls: FirstRun.CATALOG[].datastores")
        print("Reference: OneWoW/Docs/ARCHITECTURE.md §4.1")
        return 1

    print(
        f"OK: {len(manifest)} manifest units, {len(owned_stores)} stores, "
        f"{len(catalog)} CATALOG features"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
