# Import / Export

> **See also:** [Docs index](README.md) · [Categorization](CATEGORIZATION.md) (what gets classified) · [Search syntax](SEARCH_SYNTAX.md) (`SAVED(Name)` in exported rules) · [Architecture](ARCHITECTURE.md) (DB keys)

OneWoW Bags can import categories and sections from other addons, and export its
own configuration as a sharable text block. All operations go through a
**preview dialog** so you can see what will happen before anything is written.

This document describes the user-facing workflow first, then the on-disk format
and the internal pipeline for contributors.

---

## Quick Start

Open **Category Manager**. The action bar now has three import/export controls:

| Control | What it does |
|---|---|
| `Import from...` pulldown | Pick a source, opens the preview dialog |
| `Export` | Copy the current config to a clipboard dialog |
| `Undo` icon (curved arrow) | Revert the most recent import (one-shot) |

The pulldown is always visible. If Baganator or TSM is not loaded the
corresponding `(direct)` entry is tagged `(not loaded)`; you can still use the
`(paste)` entries to process an export string from that addon.

---

## Importing

Available sources:

- **Baganator (direct)** — reads live Baganator data via `BAGANATOR_CONFIG`.
- **TSM (direct)** — reads live TradeSkillMaster groups.
- **OneWoW string (paste)** — paste a string produced by OneWoW's `Export`
  button (see below).
- **Baganator string (paste)** — paste a Baganator export string (JSON v1/v2 or
  `BGR!1!` CBOR v3 from the Copy button).

Every source builds a **plan**, never touches the DB directly, and opens the
preview dialog.

### Preview Dialog

The preview shows:

1. **Header** — source name, locale, counts.
2. **Warnings panel** — collapsible list of non-fatal issues (untranslatable
   keywords, unmapped modifiers, etc.).
3. **Bulk resolution bar** — apply `Skip all` / `Rename all` / `Merge all` to
   every conflict in one click.
4. **Unmapped Baganator defaults** (Baganator imports only) — Keep / Ignore
   each unknown `default_*` category.
5. **Category & section tree** — one row per incoming entry; if a name
   conflicts with something you already have, the row gets a per-row
   resolution dropdown:
   - `Skip` — do not import this entry.
   - `Rename` — import with a custom prefix/suffix.
   - `Merge` — combine with the existing entry (see merge rules below).
6. **Rule handling** — for rules that were translated from another dialect you
   can choose `Translate`, `Snapshot items`, or `Drop rules`.
7. **Summary + Import / Cancel buttons** — a live count updates as you edit
   resolutions.

Click **Import** to apply the plan. A backup of the pre-import state is
snapshotted automatically — see "Undo" below.

### Merge Rules

When two categories with the same name collide and the user picks `Merge`:

- **filterMode**
  - If either side is search-based (`filterMode = "search"`), search wins.
  - Otherwise the imported `filterMode` replaces the existing one.
- **items** — always unioned (pinned item IDs from both sides are kept).
- **enabled** — sticky; stays enabled if either side was enabled.
- **modifications** (per category, per scope)
  - `sortMode`, `subSortMode`, `sortDescending`, `subSortDescending`, `groupBy`, `priority`, `color`: imported wins when set, otherwise keep existing.
  - `forceOwnLine`: unioned per container key (`backpack`, `character_bank`, `warband_bank`).
  - `appliesIn` (bag/bank/etc. scoping): intersected (fewer scopes kept).
  - `addedItems`: unioned.

Sections with the same name are merged: membership lists are unioned, and the
imported order is appended after the existing one.

### Handling Baganator Defaults

Baganator ships many `default_*` categories (e.g. `default_weapon`,
`default_housing`) that OneWoW represents via built-in names. The importer:

1. Translates known defaults to their OneWoW built-in names using
   `Data/BaganatorDefaultMap.lua`.
2. Flags unmapped defaults in the preview so you can **Keep** or **Ignore**
   each one.
3. Any defaults you `Keep` are placed into a new section named
   **"Baganator Import"** as placeholder categories for you to finish.

### Rule Translation

Baganator / Syndicator search expressions are translated to OneWoW predicate
syntax via `ImportExport/SyntaxTranslators/Syndicator.lua`:

- Operators: `||` → `|`, `&&` → `&`, `~` and `!` both map to `!`.
- `#keywords`: localized tokens (`#rüstung`, …) reverse-map to English, then to
  OneWoW canonical keywords (`#armor`, `#currentseason`, …). See the
  [Baganator compatibility registry](#baganator-import-compatibility) for the
  full matrix.
- **Bare keywords** (no `#`): Syndicator treats tokens like `Armor`, `BOE`, `tww`
  as keywords; OneWoW normally treats bare words as name substrings. The
  importer injects `#` for known Syndicator/OneWoW keywords during translation.
- Spaced keywords (`active season`, `item enhancement`, `my class`) are merged
  before lookup when they match a known phrase.
- Passthrough: quoted strings, `ilvl>N`, money shorthands (`12g`), and literal
  text like `Season 1` (not the `active season` keyword) are copied as-is.
- Syndicator-only keywords (`#auto`, `#recent`, `#bagtype`) emit a warning and
  are stripped.

Untranslatable rules are flagged in the preview; you can choose **Snapshot
items** or **Drop rules**. See [SEARCH_SYNTAX.md](SEARCH_SYNTAX.md) for OneWoW
predicate details.

---

## Exporting

Click **Export** in the Category Manager. OneWoW emits a restricted Lua table
literal and opens a read-only copy dialog (powered by `OneWoW.CopyPaste`).

### What's included

- `customCategoriesV2` (excluding the built-in `sec_onewow_bags.categories`
  bucket — those are shipped by the addon and regenerated on import).
- `categorySections`, `sectionOrder`.
- `categoryModifications`, `disabledCategories`, `categoryOrder`.
- `displayOrder`.
- **v2 only:** `savedSearches` — transitive closure of saved searches referenced
  by exported custom category `searchExpression` values (`SAVED(Name)` tokens).
- **v2 only:** `enableJunkCategory`, `enableUpgradeCategory` — whether optional
  **1W Junk** / **1W Upgrades** builtins participate in layout.
- Envelope metadata: `format`, `version`, `addon`, `exportedAt`, `exportedBy`,
  `exportedLocale`, `scope`.

### What's **not** included

Addon-global settings unrelated to sections/categories (window geometry, font
size, theme, per-category bag UI collapse in `collapsedSections`, etc.). The
import format is intentionally a **category/section bundle**, not a full
profile.

Import is **merge-oriented**: data is combined into the target profile rather
than replacing it wholesale. Ordering fields use **exported order first**,
then append any target-only sections/categories not present in the export.

### Format

Current version is **2**. Version **1** strings still import with a version
mismatch warning; missing v2 fields are treated as empty / no-op.

The payload is a Lua table literal (deterministic key ordering, lexicographic
where possible). Example skeleton:

```lua
{
    format                = "OneWoW_Bags.Export",
    version               = 2,
    addon                 = "OneWoW_Bags",
    exportedAt            = 1713571200,
    exportedBy            = "CharacterName",
    exportedLocale        = "enUS",
    scope                 = "all",

    sections              = { ... },
    sectionOrder          = { ... },
    categories            = { ... },
    modifications         = { ... },
    disabledCategories    = { ... },
    categoryOrder         = { ... },
    displayOrder          = { ... },
    savedSearches         = { ... },
    enableJunkCategory    = true,
    enableUpgradeCategory = true,
}
```

### Ordering restore on import

| Field | Behavior |
|-------|----------|
| `displayOrder` | Best-effort: remaps section IDs and renamed categories; **skips** unresolvable entries (skipped imports, missing builtins, unknown sections) instead of failing the whole layout. |
| `sectionOrder` | Remapped section IDs; exported order first, then target-only sections appended. |
| `categoryOrder` | Remapped category names; exported order first, then target-only names appended. |
| `sortOrder` (per custom category) | Applied when a category is **created** or **renamed**; preserved on merge. |

If `displayOrder` yields no valid entries after filtering, layout falls back to
`sectionOrder` + section membership (see `CategoryViewHelpers`).

`savedSearches` entries merge by display name (case-insensitive); imported
queries win on collision.

Parsing uses a strict hand-written decoder — it rejects function values, `--`
comments, metatables, and anything else that could smuggle code.

---

## Undo

Every `Applier:Apply` call begins with `Backup:Snapshot("pre_import", db)`,
which deep-copies every import-affected field of `db.global` into
`db.global.importBackup`.

- The **Undo** icon button in the Category Manager action bar is **always
  visible**, and is enabled only when a backup exists.
- Clicking it prompts for confirmation, restores the snapshot, clears the
  backup, and calls `SyncOnewowSectionCategories` + a single UI refresh.
- Only the most recent import is reversible — a new import replaces the
  snapshot.

Fields backed up: `customCategoriesV2`, `categorySections`, `sectionOrder`,
`categoryModifications`, `disabledCategories`, `categoryOrder`, `displayOrder`,
`savedSearches`, `enableJunkCategory`, `enableUpgradeCategory`.

---

## Manual test checklist

Export on character A, import on character B (or a profile with existing
categories). Verify:

1. Custom category with `searchExpression` using `SAVED(MySearch)` — search
   definition travels with the export and categorization works after import.
2. Section `collapsed`, `showHeader`, and `showHeaderBank` flags — including
   when the section name already exists on the target (merge path).
3. Custom section ordering matches the source (`sectionOrder` / `displayOrder`).
4. **1W Junk** / **1W Upgrades** visibility matches export when toggles differ
   on the target before import.
5. Skip one conflicting category in the preview — remaining `displayOrder`
   entries still restore; skipped names are omitted without clearing the whole
   layout.
6. **Undo** restores all backed-up fields including saved searches and junk/
   upgrade toggles.

---

## Internal Pipeline (for contributors)

```
Source (Baganator / TSM / paste)
      │
      ▼
Integrations/BaganatorImport.lua    Integrations/TSMIntegration.lua
ImportExport/Serializer.lua (OneWoW native)
      │
      ▼  intermediate payload (normalized)
ImportExport/SyntaxTranslators/Registry.lua
      │
      ▼
ImportExport/Planner.lua            (read-only; builds a Plan)
      │
      ▼
GUI/ImportPreview.lua               (user resolves conflicts)
      │
      ▼
ImportExport/Backup.lua::Snapshot   (deep copy via ImportExport/Util.lua)
ImportExport/Applier.lua::Apply     (mutates db.global)
      │
      ▼
SectionDefaults:SyncOnewowSectionCategories + UI refresh
```

Key invariants:

- **Planner never writes to `db.global`.** Only `Applier` mutates state.
- **Applier produces exactly one UI refresh** at the end, after all mutations
  are complete.
- **Snapshot is taken before the first mutation**, so partial failure is
  recoverable via Undo.
- **Re-keying** — renaming a category migrates its `categoryModifications` and
  `disabledCategories` entries atomically.

### Adding a new source addon

1. Create `Integrations/<Source>Import.lua` with `DirectRead(db)` and/or
   `ParseString(text)` entry points returning a normalized payload.
2. If the source uses a different search grammar, add
   `ImportExport/SyntaxTranslators/<Source>.lua` and register it in
   `Registry.lua`.
3. Add a `Planner:From<Source>Direct` / `Planner:From<Source>String` wrapper.
4. Add menu entries to the `Import from...` pulldown in `CategoryManager.lua`.

No other file should need to know about the new source.

---

## Baganator import compatibility

Living gap registry for Baganator/Syndicator → OneWoW_Bags import fidelity.
**Maintenance rule:** when you add or change any of the following, update the
relevant row here and touch the listed code paths:

- New `PredicateEngine` keyword → `SyntaxTranslators/Syndicator.lua`,
  `SyndicatorLocaleMap.lua`
- New OneWoW `groupBy` value, modification field, or builtin category →
  `Planner.lua`, `BaganatorDefaultMap.lua`
- Baganator export format version change → re-read vendored
  `_OneWoW_Offline/Baganator/`, update `Integrations/BaganatorImport.lua`
- Closing an import bug → mark row **Resolved**, note commit/PR

**Reference:** vendored
`Baganator/CustomiseDialog/Categories/ImportExport.lua` · **Code:**
`Integrations/BaganatorImport.lua`, `ImportExport/Planner.lua`,
`ImportExport/Applier.lua`, `Data/BaganatorDefaultMap.lua` · **Fixtures:**
`Docs/fixtures/baganator/`

### Decode / format

| Baganator concept | OneWoW status | User impact | Code touchpoints | Notes |
|-------------------|---------------|-------------|------------------|-------|
| JSON v1/v2 export (`categories[]`, `order`, …) | **Supported** | Paste imports categories + layout | `BaganatorImport.lua` | Lenient: `addon` field optional when `categories` present |
| `BGR!1!` CBOR v3 | **Supported** | Same as JSON after decode | `DecodeBaganatorPaste` | Requires `addon == "Baganator"` |
| `||` pipe escape in search | **Supported** | Rules decode correctly | `DecodeBaganatorPaste`, `Syndicator.lua` | Normalized to `\|` |
| Full profile export (`kind: "profile"`) | **Unsupported** | Clear error, no DB write | `ParseString` | Categories-only scope |
| Profile-shaped paste (`custom_categories`) | **Supported** | Routed through `NormalizeProfilePayload` | `BaganatorImport.lua` | Legacy SV paste |

### Schema / layout

| Baganator concept | OneWoW status | User impact | Code touchpoints | Notes |
|-------------------|---------------|-------------|------------------|-------|
| `categories[]` → customs | **Supported** | Custom categories in preview | `NormalizeExportPayload` | |
| `order` / `sections` | **Supported** | Section order + names | `Planner.pushDefaultSections`, `buildDisplayOrderFromBaganator` | v1 `_EQUIPMENT` migrated to `_1` |
| `modifications[]` | **Supported** | Priority, color, group, pins, hideIn | `Planner.applyBaganatorModification` | All source IDs, not only mapped defaults |
| `hidden[]` | **Supported** | `disabledCategories` in preview | `mapHiddenCategories` | |
| `displayOrder` from Baganator order | **Supported** | Global layout restored | `buildDisplayOrderFromBaganator` | `section:bag_sec_N`, `section_end` |
| Direct read active profile | **Supported** | Uses `BAGANATOR_CURRENT_PROFILE` | `DirectRead` | Fallback `DEFAULT` |
| Direct read `category_modifications` | **Supported** | Mods preserved on direct path | `NormalizeProfilePayload` | Was hardcoded `{}` pre-fix |

### Default categories

| Baganator concept | OneWoW status | User impact | Code touchpoints | Notes |
|-------------------|---------------|-------------|------------------|-------|
| Known `default_*` IDs | **Supported** | Map to OneWoW builtins | `BaganatorDefaultMap.lua` | |
| `default_auto_tradeskillmaster` | **Partial** | Keep/Ignore in preview | `BaganatorDefaultDisplayHints` | No builtin equivalent |
| `default_auto_inventory_slots` | **Partial** | Keep/Ignore | Display hints | OneWoW uses `enableInventorySlots` setting |
| `default_projectile` / `default_quiver` | **Partial** | Keep/Ignore (Classic-era) | Display hints | Retail exports may still reference them |

### Category modifications

| Baganator mod | OneWoW status | User impact | Code touchpoints | Notes |
|---------------|---------------|-------------|------------------|-------|
| `priority` | **Supported** | Clamped -2..3 | `applyBaganatorModification` | |
| `hideIn` → `appliesIn` | **Supported** | Per-container visibility | `InvertHideIn` | |
| `color` | **Supported** | Category color | Planner → Applier | |
| `group` → `groupBy` | **Partial** | expansion/type/slot/quality/set OK | Planner | `track` → warn + skip |
| `addedItems` `i:ID` | **Supported** | Item pins | Planner | Stored as string IDs |
| `addedItems` `p:ID` | **Unsupported** | Warn + skip | Planner | No pet-pin model |
| `showGroupPrefix` | **Unsupported** | Info warn, dropped | Planner | No OneWoW field |

### Search syntax

| Syndicator concept | OneWoW status | User impact | Code touchpoints | Notes |
|--------------------|---------------|-------------|------------------|-------|
| Bare keywords (`Armor`, `BOE`, `tww`) | **Supported** | Injected as `#keyword` | `Syndicator.lua` `tryBareKeyword` | |
| `#activeseason` / `active season` | **Supported** | Maps to `#currentseason` | `ENGLISH_TO_OW`, `PredicateEngine` | Implementations may disagree on edge items |
| Literal `Season 1` text | **Supported** | Passthrough (name substring) | Translator | Not rewritten to season keyword |
| `#upgrade` | **Partial** | Passthrough when PE loaded | PE + UpgradeDetection | Semantic diff vs Syndicator |
| `#junk` | **Partial** | Mapped but semantics differ | PE | OneWoW = poor quality or ItemStatus junk |
| `#auto`, `#recent`, `#bagtype` | **Intentional skip** | Stripped + warn | `ENGLISH_TO_OW` | Baganator auto-categories |
| Localized `#keywords` | **Supported** | Via locale map + live Syndicator | `SyndicatorLocaleMap.lua` | |

### Intentional non-imports

| Concept | Notes |
|---------|-------|
| Full Baganator profile | Export categories only |
| Battle pet pins | Item pins only |
| `group: track` | Baganator upgrade-track UI grouping |
| Baganator junk/upgrade **plugins** | Not the same as OneWoW `enableJunkCategory` / `enableUpgradeCategory` |
| `showGroupPrefix` | No OneWoW equivalent |

### Baganator manual QA

See `Docs/fixtures/baganator/README.md` for fixture strings and the in-game
checklist (migration JSON, `BGR!1!`, direct read, v1 legacy, profile reject,
undo).
