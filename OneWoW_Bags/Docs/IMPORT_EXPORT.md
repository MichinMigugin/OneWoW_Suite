# Import / Export

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
- **Baganator string (paste)** — paste a Baganator JSON export string.

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
  - `sortMode`, `groupBy`, `priority`, `color`, `forceOwnLine`: imported wins
    when set, otherwise keep existing.
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
syntax:

- Operators: `||` → `|`, `&&` → `&`, `~` and `!` both map to `!`.
- Keywords: localized keyword tokens (`#rüstung`, `#арм...`) are reverse-mapped
  to the canonical English tokens (`#armor`). Resolution order:
  1. Direct English match.
  2. Live Syndicator API (when Syndicator is loaded).
  3. Bundled `SyndicatorLocaleMap.lua` reverse table.
  4. Warn + preserve the literal token.
- Passthrough: item-level comparisons (`ilvl>N`) and money shorthands (`12g`,
  `>5s`) are copied as-is.
- Unknown tokens become a warning and are dropped with a comment in the result
  expression.

Untranslatable rules are flagged in the preview; you can choose **Snapshot
items** to convert the rule into a static item list captured from your current
bags, or **Drop rules** to discard them.

---

## Exporting

Click **Export** in the Category Manager. OneWoW emits a restricted Lua table
literal and opens a read-only copy dialog (powered by `LibCopyPaste-1.0`).

### What's included

- `customCategoriesV2` (excluding the built-in `sec_onewow_bags.categories`
  bucket — those are shipped by the addon).
- `categorySections`, `sectionOrder`.
- `categoryModifications`, `disabledCategories`, `categoryOrder`.
- `displayOrder`.
- Envelope metadata: `format`, `version`, `addon`, `exportedAt`, `exportedBy`,
  `exportedLocale`, `scope`.

### What's **not** included

Addon-global settings unrelated to sections/categories (window geometry, font
size, theme, etc.). The import format is intentionally a **category/section
bundle**, not a full profile.

### Format

The payload is a Lua table literal (deterministic key ordering, lexicographic
where possible). Example skeleton:

```lua
{
    format         = "OneWoW_Bags_CatBundle",
    version        = 1,
    addon          = "OneWoW_Bags",
    exportedAt     = 1713571200,
    exportedBy     = "CharacterName",
    exportedLocale = "enUS",
    scope          = "all",

    sections       = { ... },
    sectionOrder   = { ... },
    categories     = { ... },
    modifications  = { ... },
    disabledCategories = { ... },
    categoryOrder  = { ... },
    displayOrder   = { ... },
}
```

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
`categoryModifications`, `disabledCategories`, `categoryOrder`, `displayOrder`.

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
ImportExport/Backup.lua::Snapshot
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
