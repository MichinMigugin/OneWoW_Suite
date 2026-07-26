# OneWoW Suite Database API

Design rationale for `OneWoW/GUI/Database.lua` — the shared database layer used by all addons in the OneWoW suite. This document explains the reasoning behind the API, not how to call it. For the API surface, read `Database.lua` directly.

Suite storage layout and global surface contract: [`ARCHITECTURE.md`](ARCHITECTURE.md) §6.1.

---

## V1 Decisions

- The suite owns the addon-facing DB API.
- The DB module lives in `OneWoW/GUI/` and is published as the `OneWoW_GUI.DB` global.
- Addon code works against logical scopes, not storage details.
- Initial scope set: `Global`, `Realm`, `Faction`, `Class`, `Spec`, `Char`.
- Scope names are referenced through `DB.Scope.*` constants, not raw strings.
- Scope resolution order: `Global -> Realm -> Faction -> Class -> Spec -> Char`.
- Presets are separate from scopes; only one preset is active at a time.
- Presets are sparse overlays applied at read time — they do not overwrite stored scope values.
- `Char` is a logical scope, not a requirement for a separate `SavedVariablesPerCharacter` global.
- The API supports multiple physical storage layouts for legacy SavedVariable shapes.
- Long-term, prefer one shared `SavedVariables` root per addon.
- Defaults are templates only and must never be stored by reference.
- Blizzard table helpers are internal implementation details, not part of the public API.
- `DB:Init` is `single`/`split` only. The AceDB compatibility path (`DB:NewCompat`) has been retired now that the whole suite is on the native API.
- `DB` is a stateless utility module. `db` handles are plain tables, not objects with methods.
- `Set` puts value last: `DB:Set(db, keys..., value)`.
- Structural one-time transforms use **init bridges** in each addon's `InitializeDatabase` (shape detection or one-shot flags). Defaults application is a **normalizer** via `Init` + `MergeMissing`, not a bridge.

---

## DB Module Location

The DB module source is `OneWoW/GUI/Database.lua`, published on the `OneWoW_GUI` global. Every suite addon has `RequiredDeps: OneWoW`, which loads the toolkit. Addon code accesses it as `local DB = OneWoW_GUI.DB` (or `local OneWoW_GUI = OneWoW_GUI` then `OneWoW_GUI.DB`).

---

## Core Direction

The suite owns the addon-facing database API. Addon code should not directly depend on AceDB initialization details, Blizzard `TableUtil` helpers, or per-addon merge/ensure helpers.

The DB layer can use Blizzard helpers internally (`CopyTable`, `GetOrCreateTableEntry`, etc.) but these are hidden from addon code.

### Why Not Expose Blizzard Helpers Directly

Blizzard provides useful primitives, but their semantics are wrong for saved variable initialization:

- `MergeTable` — overwrites destination values
- `SetTablePairsToTable` — wipes and replaces the destination

Saved variable initialization needs fill-only semantics: fill missing keys, never overwrite user data. That is what `DB:MergeMissing` provides.

---

## AceDB Compatibility (retired)

The suite is fully off AceDB. The former bridge — `DB:NewCompat`, a drop-in for `AceDB-3.0:New()` that read and wrote the same SavedVariables layout — has been removed now that its last caller (`OneWoW_AltTracker`) moved onto `DB:Init` (single mode). New and existing addons use `DB:Init` (`single`/`split`); account-wide per-character stores are bootstrapped by `OneWoW:BootStore` (shape ensured from `defaults`) and accessed via the `DB:GetCharData` / `DB:GetAllChars` / `DB:DeleteChar` helpers, which read and write the live SavedVariable global directly. There is no AceDB-format compat path.

On-disk data written under the old AceDB/compat character-key shapes is still normalized at load by `OneWoW_GUI:CanonicalizeCharacterKey` and the `DB:Consolidate*` passes, so no user data migration is required.

---

## Scope Model

V1 scopes: `Global`, `Realm`, `Faction`, `Class`, `Spec`, `Char`.

 `Race` is excluded as no real use case could be determined.

### Resolution Order

`Global -> Realm -> Faction -> Class -> Spec -> Char`

Later scopes override earlier ones. This allows large base tables in `Global` with sparse override tables in narrower scopes. `Char` is the most specific identity-based override.

### Physical Storage vs Logical Scopes

Logical scopes (`db.global`, `db.char`, resolved scope lookups) are the public concept. Physical storage (one shared root, split globals) is an initialization detail hidden from addon code.

Long-term preferred layout: one shared `SavedVariables` root per addon, with character data stored at `MyAddon_DB.chars["Name-Realm"]` and exposed as `db.char`.

### Internal db handle (`ns.db`)

After `DB:Init` returns, assign the handle on the load unit's private namespace:

```lua
function ns:InitializeDatabase()
    ns.db = DB:Init({
        savedVar = "OneWoW_MyUnit_DB",
        addonName = ADDON_NAME,
        defaults = ns.DatabaseDefaults,
    })
end
```

- **Internal reads:** `ns.db.global.*` (and `ns.db.char` when used) — the normal path
  for all files in the unit after init.
- **Raw SV global:** `OneWoW_<Unit>_DB` is WoW's persistence root. Touch it only in
  `Database.lua` (or BootStore `initDB`) for one-shot shape bridges before/during
  `DB:Init` — not from UI or cross-unit code.
- **Naming:** `savedVar` / TOC `## SavedVariables` must be `OneWoW_<LoadUnitName>_DB`,
  matching the TOC folder / `ADDON_NAME`.
- **Lifecycle root:** do not hang the db handle on `OneWoW_<Unit>.db`; use `ns.db`.
- **Stores:** `OneWoW:BootStore` may set `ns.db` inside `initDB`; same rules apply.

Cross-unit consumers read through the owner's `OneWoW_<Unit>_API`, not `ns.db` or
the raw `_DB` global. See ARCHITECTURE §6.1.

---

## Preset Model

Presets answer "what mode the player is currently in" (gathering, travel, immersive, fishing) — separate from scopes, which answer "who this character is."

Design:

- Named sparse override tables
- One active preset at a time
- Explicitly activated
- Overlay on top of resolved scope values at read time
- Do not overwrite stored base scope values when activated

Resolution: all scopes resolve first in priority order, then the active preset overlays last.

Starting with a single active preset avoids preset collision rules, multi-preset conflict resolution, and hard-to-debug stacked overrides. Multi-preset support can be added later if needed.

---

## Behavioral Rules

### `Init`

- Creates the root db object
- Normalizes `global` and `char` logical scopes
- Two initialization modes: single shared root (`savedVar`) and split globals (`savedVar` + `savedVarChar`)
- Applies defaults via `MergeMissing` without overwriting existing user values
- Returns a normalized db shape regardless of mode

### `MergeMissing`

- Recursively fills only `nil` keys
- Never overwrites existing scalar values
- Recurses only when both source and destination values are tables
- Copies default tables (via `CopyTable`) to prevent reference sharing

### `Ensure`

- Walks a path and creates missing intermediate tables
- Errors if an intermediate value exists but is not a table

### `Read`

- Safely walks a path and returns `nil` if any segment is missing
- Does not allocate

### `Set`

- Creates parent tables as needed
- Value is the last argument; path keys precede it
- Requires at least one key and one value
- Use `Delete` for nil writes

### `Delete`

- Safely walks to the parent table and removes the final key

### `GetResolvedValue`

- Resolves values through configured scope priority
- Overlays the active preset last
- Returns the final effective value for a path

### `GetResolvedTable`

- Returns a resolved copy/assembled view of a nested table
- Read-oriented; should not become the primary persisted table

### `SetScopeValue`

- Writes explicitly to one scope
- Does not guess the write target

### `SetPresetValue`

- Writes explicitly to a named preset override table
- Only stores keys the preset wants to override

### `SetActivePreset`

- Activates one preset at a time
- Does not mutate underlying scope values when switching

### Init bridges

One-time structural transforms run as **idempotent init bridges** beside `DB:Init` in each
addon's `InitializeDatabase`: shape-detected flat SV wraps, boolean or `_migrationVersion`
gates where a legacy step already ran, then `DB:Init`. Ongoing shape repair stays in
`MergeMissing`. There is no shared versioned migration runner.

---

## Init bridges vs normalizers

The codebase separates two concepts:

1. **One-time bridges** — structural data transforms that must run once (rename keys,
   restructure tables, move data between scopes). Gated by shape detection or a
   one-shot flag (e.g. `_monitorPinnedMigrated`, `_charDBDrained`).

2. **Normalizers** — idempotent transforms that fill missing defaults or fix data
   shapes every load. Handled by `MergeMissing` inside `Init`.

The API must never store live db tables by directly assigning template tables from defaults. `MergeMissing` copies tables via `CopyTable` when filling missing keys. This prevents the dangerous pattern where mutating `db.settings` also mutates the defaults template because they share the same table reference.

---

## Metatables

Metatables may be useful for a narrow readonly resolved view but should not define the storage model:

- `pairs()` only sees real keys, not fallback values from `__index`
- Writes become ambiguous
- Nested virtual fallback tables are hard to reason about

Recommended: store scopes and presets as normal plain tables, resolve values explicitly in the DB layer, optionally expose readonly convenience views for limited read-only scenarios.

---

## Default Reference Safety

The DB API is designed to kill specific defensive programming patterns that were widespread across the suite. These patterns hid actual initialization bugs and made code harder to maintain.

### Triple-and nil-check chains

```lua
-- Before: defensive chain because db or db.global might be nil
local showWarband = db and db.global and db.global.bankShowWarband

-- After: DB:Init guarantees db and db.global exist
local showWarband = db.global.bankShowWarband
```

### Redundant `or {}` fallbacks on defaulted keys

```lua
-- Before: fallback hides the bug if MergeMissing failed to initialize the key
local catMods = db.global.categoryModifications or {}

-- After: MergeMissing guarantees all defaulted keys exist
local catMods = db.global.categoryModifications
```

The `or {}` fallback is still appropriate for dynamic sub-keys not defined in defaults (e.g. `catMods[entryName] or {}`, `sec.categories or {}`).

### Scattered ensure-if-nil blocks

```lua
-- Before: manual table creation scattered across consumer files
if not db.global.categoryModifications then db.global.categoryModifications = {} end
if not db.global.categoryModifications[catName] then
    db.global.categoryModifications[catName] = {}
end

-- After: one call that creates the full path
local catMod = DB:Ensure(db, "global", "categoryModifications", catName)
```

Better yet, if the key is in defaults, it does not need ensuring at all.

### Custom merge/apply functions per addon

Every addon had its own `ApplyDefaults`, `mergeSubTable`, or `mergeTabSettings` function. All replaced by `DB:MergeMissing`, called once inside `DB:Init`.

### Boolean bridge flags scattered through init

```lua
-- Before: interleaved boolean flags make it unclear where "apply defaults" ends
-- and "bridge legacy data" begins
if not self.db.global.categoriesV2Migrated then
    self:MigrateCategorySystemV2()
    self.db.global.categoriesV2Migrated = true
end

-- After: one-shot bridge flag in InitializeDatabase, then Init
if not db.global.categoriesV2Migrated then
    bridgeCategorySystemV2(db)
    db.global.categoriesV2Migrated = true
end
```

---

## Stores documented elsewhere

Some `OneWoW_DB.global` subtrees have rules of their own that this API document
does not cover:

| Store | Owner | Reference |
| --- | --- | --- |
| `searchCatalog` | `OneWoW.SearchCatalog` | [SEARCH_CATALOG.md](SEARCH_CATALOG.md) — entry shape, the former-name uniqueness invariant, and why a profile restores it by deep copy rather than re-creating entries by name |

The catalog is worth calling out because it is the one store where **identity is
load-bearing**. Entry ids are what let a rename avoid rewriting expression text
across five addons, so any code that swaps the table wholesale must preserve them:
deleting and re-creating entries by name mints new ids and drops every
former-name redirect, silently breaking stored expressions the user cannot see.

---

## Suggested Conventions

1. Defaults describe as much static schema as possible.
2. Dynamic values are initialized after `Init`.
3. One-time SV shape fixes use idempotent bridges in `InitializeDatabase` (before or after `Init` as needed).
4. Addon code uses the shared DB API for initialization, nested ensure/write, persistence helpers, resolved scope reads, explicit scoped writes, and preset operations.
5. Addon code does not call Blizzard `TableUtil` functions directly for database logic.
6. Addon code does not depend on AceDB-specific APIs unless a feature truly requires them.
7. Scope names are referenced through `DB.Scope.*` constants, not raw strings.
8. Presets are sparse overlays; only one is active at a time.
9. `Char` is a logical scope, not a requirement for a separate per-character `SavedVariables` global.
10. Prefer one shared `SavedVariables` root per addon long-term.
