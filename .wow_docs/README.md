# `.wow_docs` — curated WoW UI reference

This directory holds a **small, hand-picked** slice of Blizzard client UI material mirrored from **more than one upstream** repo. The exact list of files, each file’s canonical upstream path, which repo it came from, and last-synced commit metadata live in [`manifest.json`](manifest.json).

## Upstream sources

| Key in `manifest.json` | Repository | Branch | Scanned roots |
|-------------------------|------------|--------|---------------|
| `wow-ui-source` (default) | [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) (`live`) | `live` | `Interface/AddOns` |
| `blizzard-interface-resources` | [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources) (`live`) | `live` | `Resources` |

Each key under `manifest.json` → `files` is the file's local path within `.wow_docs/`. Most values are a plain string — the file's upstream path in the default source (`wow-ui-source`, under `Interface/AddOns`). Files mirrored from a **non-default** source use the object form `{"source": "...", "path": "..."}` instead and live locally under a folder named for that source — e.g. the key `blizzard-interface-resources/Resources/GlobalStrings/enUS.lua` carries `{"source": "blizzard-interface-resources", "path": "Resources/GlobalStrings/enUS.lua"}`. Bootstrap derives both forms automatically by matching basenames across sources; only mappings it cannot infer (basename mismatch or ambiguity) need an entry in `MANUAL_OVERRIDES` inside [`bin/bootstrap_wow_docs_manifest.py`](../bin/bootstrap_wow_docs_manifest.py) — currently empty. Re-run bootstrap to regenerate `manifest.json` after adding files or editing overrides.

## Why it exists

The full upstream trees are large. Agents following [`.cursor/skills/wow-api-specialist/SKILL.md`](../.cursor/skills/wow-api-specialist/SKILL.md) are directed to use **this folder first** so they can answer FrameXML, implementation, and API-adjacent questions from a focused local set instead of searching or paging through entire repos.

The copies here target **areas OneWoW_Suite addons actually touch**—for example tooltips, items, bags/bank/containers, menus, cursors, colors, constants, professions, housing, and the per-locale `GlobalStrings` (Blizzard's official UI terms in all 11 client locales, used for localization)—rather than the full AddOns tree.

## Full local fallback

The curated set is intentionally small. A **full local clone** of the upstream sources lives at `.cache/onewow-suite/sources/wow-ui-source/Interface/AddOns` — the complete Blizzard `wow-ui-source` `Interface/AddOns` tree (including `Blizzard_APIDocumentationGenerated`). When `.wow_docs` does not contain what you need, search that clone; if you find material worth keeping, copy the file into an appropriate `.wow_docs` location and re-run `python bin/bootstrap_wow_docs_manifest.py` to register it in `manifest.json`.

## Maintenance

- **Sync from upstream:** `python bin/refresh_wow_docs.py` (or `--dry-run` first).
- **Regenerate manifest** after adding local files: `python bin/bootstrap_wow_docs_manifest.py`.
- **Cross-repo renames** bootstrap cannot auto-detect: edit `MANUAL_OVERRIDES` in `bin/bootstrap_wow_docs_manifest.py`, then re-run bootstrap.

Treat these files as **reference mirrors** of upstream; for canonical paths, history, and sync points, use the URLs above and the `last_synced_commit` / `last_synced_date` fields in `manifest.json` → `sources`.
