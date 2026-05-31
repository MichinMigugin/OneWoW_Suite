# `.wow_docs` — curated WoW UI reference

This directory holds a **small, hand-picked** slice of Blizzard client UI material mirrored from **more than one upstream** repo. The exact list of files, each file’s canonical upstream path, which repo it came from, and last-synced commit metadata live in [`manifest.json`](manifest.json).

## Upstream sources

| Key in `manifest.json` | Repository | Branch | Scanned roots |
|-------------------------|------------|--------|---------------|
| `wow-ui-source` (default) | [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) (`live`) | `live` | `Interface/AddOns` |
| `blizzard-interface-resources` | [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources) (`live`) | `live` | `Resources` |

Most entries under `manifest.json` → `files` are a string path relative to the default source (`wow-ui-source`, i.e. under `Interface/AddOns`). A few entries are objects with `"source"` and `"path"` when they are pulled from the other repo—for example `general/GlobalStrings.lua` maps to `Resources/GlobalStrings/enUS.lua` on `blizzard-interface-resources`.

## Why it exists

The full upstream trees are large. Agents following [`.cursor/skills/wow-api-specialist/SKILL.md`](../.cursor/skills/wow-api-specialist/SKILL.md) are directed to use **this folder first** so they can answer FrameXML, implementation, and API-adjacent questions from a focused local set instead of searching or paging through entire repos.

The copies here target **areas OneWoW_Suite addons actually touch**—for example tooltips, items, bags/bank/containers, menus, cursors, colors, constants, professions, and housing—rather than the full AddOns tree.

## Maintenance

Treat these files as **reference mirrors** of upstream; for canonical paths, history, and sync points, use the URLs above and the `last_synced_commit` / `last_synced_date` fields in `manifest.json` → `sources`.
