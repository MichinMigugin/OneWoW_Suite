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
| Find & Fix (magnifying glass) | Scan for orphaned category data and stale layout references; preview before cleanup |
| `Export` | Copy the current config to a clipboard dialog |
| `Undo` icon (curved arrow) | Revert the most recent import **or cleanup** (one-shot) |

The pulldown is always visible. If Baganator or TSM is not loaded the
corresponding `(direct)` entry is tagged `(not loaded)`; you can still use the
`(paste)` entries to process an export string from that addon.

### Category Manager origin indicators

The left panel shows a colored dot on each section and category row (right-aligned):

| Dot | Meaning |
|---|---|
| Green | Built-in section or category |
| Blue | Custom (user-created) |
| Red | Imported from Baganator or TSM |

Hover a row for a tooltip with the origin text. The right-panel detail header
shows matching type tags: `[Built-in]`, `[Custom]`, `[Baganator]`, or `[TSM]`.

Import metadata uses existing boolean flags on SavedVariables records:
`isBaganator` / `isTSM` on `customCategoriesV2` entries (categories) and, for
Baganator imports, on `categorySections` (sections). OneWoW-to-OneWoW string
import round-trips these flags via export; it does not stamp new external-import
flags on categories that were not already marked.

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
6. **Rule handling** (Baganator imports only) — categories that had a Baganator
   search rule show an extra row with the original rule text (`rule: …`) and a
   **cycle button** (click to rotate). Hover the button for a tooltip. Options:
   - **Use translated** (default) — import the rule converted to OneWoW search
     syntax. The category keeps matching new items as you loot them. Any pinned
     item IDs from the export are kept too.
   - **Skip rule** — do not import the search rule. Only item IDs explicitly
     listed in the Baganator export are pinned to the category; nothing new will
     match unless you add pins yourself.
   - **Snapshot items** — same import result as Skip rule (search rule dropped,
     exported item IDs kept). The preview selects this when translation failed,
     or you can pick it when you prefer a fixed pin list over a live rule.
7. **Summary + Import / Cancel buttons** — a live count updates as you edit
   resolutions.

Click **Import** to apply the plan. A backup of the pre-import state is
snapshotted automatically — see "Undo" below.

### Merge Rules

When two categories with the same name collide and the user picks `Merge`:

- **filterMode**
  - If either side is search-based (`filterMode = "search"`), search wins.
  - Otherwise the imported `filterMode` replaces the existing one.
  - `filterMode` now only selects which editor a category opens; matching is
    always `searchExpression`. A type-based payload written before that change
    carries localized type names and no expression, so the applier compiles one
    against **this** client's locale on the way in. A name the exporter's locale
    knew and ours does not leaves the category on its item pins and reported by
    the lint — the same outcome as a local category whose names stopped
    resolving.
- **items** — always unioned (pinned item IDs from both sides are kept).
- **enabled** — sticky; stays enabled if either side was enabled.
- **modifications** (per category, per scope)
  - `sortMode`, `subSortMode`, `sortDescending`, `subSortDescending`, `groupBy`, `subGroupBy`, `priority`, `color`: imported wins when set, otherwise keep existing.
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

When a category has a Baganator search rule, the preview shows the **original**
Baganator expression next to the rule-handling button (not the converted
OneWoW text). Use the button to choose how that rule is applied on import:

| Button label | What you get |
|---|---|
| **Use translated** | Live search rule in OneWoW syntax (`filterMode = "search"`). Keeps matching dynamically. Default when translation succeeds. |
| **Skip rule** | No search rule — category is item-pin only (`filterMode = "items"`). Only exported item IDs are pinned. |
| **Snapshot items** | Same as Skip rule at import time. Auto-selected when translation fails; pick manually if you want a fixed list even though translation worked. |

Categories with `(0 items)` in the preview rely entirely on **Use translated**
— switching to Skip rule or Snapshot items leaves an empty category unless you
add pins later.

See [SEARCH_SYNTAX.md](SEARCH_SYNTAX.md) for OneWoW predicate details.

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
- **v3+:** `searchCatalog` — an opaque, **core-owned** blob holding the
  transitive closure of every named expression the exported rules depend on,
  across all three reference kinds (`#token`, `SAVED(Name)`, `CATEGORY(Name)`),
  built by `OneWoW.SearchCatalog:BuildExportPayload`. Bags carries it without
  reading inside; if it learned the entry shape, a later core-side export would
  grow a second, drifting format. References are **canonicalized** on the way
  out — former names resolved to current ones — so `formerNames` never appear in
  a payload.
- **v3+:** `danglingCategories` — categories an exported rule names but that are
  not themselves in the export. Reported as an import warning rather than
  emitted silently, since they resolve to nothing on the far side.
- **v2 only (still imported):** `savedSearches` — the same idea but limited to
  `SAVED(Name)`, so a rule saying `#sell` shipped a bundle that resolved to
  nothing. The planner lifts a v2 payload into the v3 shape, so both land on one
  code path.

### Resolving catalog conflicts

`OneWoW.SearchCatalog:PlanImport` classifies each incoming entry as `create`,
`merge` (identical body — a no-op) or `conflict` (same name, different body).
Only conflicts need a decision, and the preview surfaces one row each:

- **Import as new** (default) with an editable name, prefilled from the
  catalog's `suggestedName`.
- **Keep mine** — the incoming entry is dropped and the local one is untouched.

A `create` that *reclaims* a former name gets a warning line rather than a
choice: reclaiming is what importing that payload means, but it silently changes
what older text pointing at that name resolves to.

Because only `create` and `import_as_new` ever write, the applier's record of
what it created is a complete delta — which is what lets the undo remove exactly
those entries and nothing else. See
[`OneWoW/Docs/SEARCH_CATALOG.md`](../../OneWoW/Docs/SEARCH_CATALOG.md).
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

-- Per-category modification example (round-trips via export/import):
-- modifications = {
--     ["Mats"] = {
--         groupBy    = "subtype",
--         subGroupBy = "quality",
--         priority   = 0,
--     },
-- }
```

### Native modification fields (OneWoW v2 export)

`Serializer:BuildExport` deep-copies `categoryModifications` as-is (no field
filter). `Planner:FromOneWowString` deep-copies `payload.modifications`.
`Applier:mergeModifications` merges scalar fields when present on import:

| Field | Export | Import merge | Notes |
|-------|--------|--------------|-------|
| `sortMode`, `subSortMode`, `sortDescending`, `subSortDescending` | Yes | Yes | |
| `groupBy` | Yes | Yes | `expansion`, `type`, `subtype`, `slot`, `quality`, `track`, `equipmentset`, `none` |
| `subGroupBy` | Yes | Yes | OneWoW-only composite axis; same enum as `groupBy` |
| `priority`, `color` | Yes | Yes | |
| `appliesIn`, `addedItems`, `forceOwnLine` | Yes | Yes | Separate merge rules (see §5 above) |

Baganator import has no `subGroupBy` source; composite grouping is configured
only via native OneWoW export or in-game Category Manager.

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

## Find & Fix (config cleanup)

The magnifying-glass button in the Category Manager action bar (left of
**Import from...**) scans `db.global` for stale category/section data and opens
a preview dialog before applying changes.

### What it detects

| Issue | Example |
|---|---|
| Orphaned `categoryModifications` keys | `aa`, `Imp: Bank It` after the category was deleted or renamed |
| Stale section members | A section lists a category name that no longer exists |
| Stale `sectionOrder` IDs | Order references a section that was removed |
| Stale `categoryOrder` / `displayOrder` entries | Order lists a category name that no longer exists |

Valid category names include all custom categories, effective built-in names
(from `SectionDefaults`), and `"Empty"`. Empty-but-valid modification tables
on built-ins (e.g. `Keys = {}` after browsing the manager) are **not** flagged.

### Apply behavior

- Takes a snapshot via `ImportExport/Backup.lua` before mutating (same undo slot
  as import).
- Removes selected entries (`nil` keys, not empty tables).
- Calls `SyncOnewowSectionCategories` when the ONEWOW BAGS section exists.

Deleting a custom category via the Category Manager also purges its
`categoryModifications`, `disabledCategories`, and order-array references
immediately (see `CategoryController:DeleteCategory`).

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
2. **Find & Fix** lists orphaned modification keys (empty or not) and removes
   them on apply; export no longer includes deleted test categories.
3. Section `collapsed`, `showHeader`, and `showHeaderBank` flags — including
   when the section name already exists on the target (merge path).
4. Custom section ordering matches the source (`sectionOrder` / `displayOrder`).
5. **1W Junk** / **1W Upgrades** visibility matches export when toggles differ
   on the target before import.
6. Skip one conflicting category in the preview — remaining `displayOrder`
   entries still restore; skipped names are omitted without clearing the whole
   layout.
7. **Undo** restores all backed-up fields including saved searches and junk/
   upgrade toggles.

---

## Internal Pipeline (for contributors)

```
Source (Baganator / TSM / paste)
      │
      ▼
Integrations/BaganatorImport.lua    Integrations/TSMIntegration.lua
ImportExport/Serializer.lua (OneWoW native)
ImportExport/ConfigCleanup.lua (Find & Fix scan/apply)
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
  `ImportExport/Applier.lua` (`mergeModifications` field list),
  `ImportExport/Planner.lua`, `Docs/IMPORT_EXPORT.md`; Baganator mapping when
  applicable → `BaganatorImport:MapGroupBy`, `Data/BaganatorDefaultMap.lua`
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
| `group` → `groupBy` | **Supported** | expansion/slot/quality/track pass through; Baganator `type` → OneWoW `subtype` | `BaganatorImport:MapGroupBy`, Planner | OneWoW `type` = item class; Baganator `type` = subclass |
| `subGroupBy` | **N/A** | Not in Baganator; set in OneWoW only | Native export / Category Manager | Composite `group / sub-group` labels |
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
| Baganator junk/upgrade **plugins** | Not the same as OneWoW `enableJunkCategory` / `enableUpgradeCategory` |
| `showGroupPrefix` | No OneWoW equivalent |

### Baganator manual QA

See `Docs/fixtures/baganator/README.md` for fixture strings and the in-game
checklist (migration JSON, `BGR!1!`, direct read, v1 legacy, profile reject,
undo).
