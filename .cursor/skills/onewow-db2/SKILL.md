---
name: onewow-db2
description: Use when reasoning about client DB2 game-data tables — Journal/EJ membership, instance flags, MapDifficulty, Difficulty, DungeonEncounter, or other extracts under .wow_db2 — validating ATT vs Retail listing, regenerating Generated Lua, or deciding CSV vs FrameXML vs ATT Data/. Not for C_* APIs, FrameXML, or GlobalStrings (use wow-api-specialist / onewow-locale-workflow).
---

# OneWoW DB2 Extracts

Client **DB2 → CSV** extracts for offline tools and Generated Lua. Separate from
FrameXML / API mirrors in `.wow_docs`.

## When to load this skill

| Need | Use |
| --- | --- |
| What Retail EJ lists per expansion; dual-list remakes; flags (Timewalker) | `.wow_db2` + this skill |
| Valid difficulties for a map / instance | `MapDifficulty` / Generated `JournalMapDifficulties` |
| FK / relationship model for a DB2 group | `.wow_db2/docs/<group>.md` (mermaid) |
| Widget APIs, `C_*`, FrameXML, EJ Lua behavior | `wow-api-specialist` + `.wow_docs` |
| Locale strings | `onewow-locale-workflow` + GlobalStrings |
| Suite SavedVariables | `onewow-database-api` |
| Runtime Catalog Journal card rules | `OneWoW_CatalogData_Journal/Docs/JOURNAL_DATA.md` |

## Authoritative layout

1. [`.wow_db2/README.md`](.wow_db2/README.md) — build pin, group index, refresh steps, cross-model notes.
2. [`.wow_db2/docs/`](.wow_db2/docs/) — per-group docs (`journal.md` today; achievements later).
3. Flat CSVs in `.wow_db2/` (semicolon-delimited).
4. Journal generator: [`bin/journal_db2_tools.py`](bin/journal_db2_tools.py) → `OneWoW_CatalogData_Journal/Data/Generated/`.

**Build pin** lives in the README (e.g. `12.1.0.69283`). Bump it whenever CSVs are replaced.

## Rules of use

- **Not FrameXML.** Do not sync these via `refresh_wow_docs.py` / `bootstrap_wow_docs_manifest.py`.
- **Prefer Generated Lua at runtime** (`ns.JournalTierMembership`, `ns.JournalMapDifficulties`, `ns.JournalInstanceMeta`) over shipping raw CSVs in the addon.
- **Do not dump huge CSVs into context** (especially `PlayerCondition.csv`). Read headers, sample rows, or group docs; use `journal_db2_tools.py validate` / `report` for bulk diffs.
- **Invent no FKs** — confirm columns from CSV headers + `.wow_db2/docs/<group>.md`.
- After CSV refresh: update README build string → `python bin/journal_db2_tools.py generate` (+ `validate` as needed).

## Journal (current group)

- Listing truth: `JournalTierXInstance` → Generated TierMembership (exclude Current Season expansion `9000`).
- ATT remains loot/specials corpus; union by `instanceID` onto EJ cards — see `JOURNAL_DATA.md`.
- Flags: Timewalker=`1`, HideUserSelectableDifficulty=`2`, DoNotDisplayInstance=`4`.
- Schema chart: [`.wow_db2/docs/journal.md`](.wow_db2/docs/journal.md).

## Future groups

Add CSVs as needed, write `docs/<group>.md` (mermaid + table notes), link from the root README, and note cross-model edges (MapID, conditions, etc.). Extend generators when a group needs Generated Lua.

## Cross-skill nudges

- From API/FrameXML work that needs **table** membership or difficulty sets → load this skill.
- From Catalog Journal runtime / Generated membership → this skill for extract source; `onewow-suite-architecture` for load-unit wiring.
