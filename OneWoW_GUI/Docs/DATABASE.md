# OneWoW Suite Database API

Design rationale for `OneWoW_GUI/Database.lua` — the shared database layer used by all addons in the OneWoW suite. This document explains the reasoning behind the API, not how to call it. For the API surface, read `Database.lua` directly.

---

## V1 Decisions

- The suite owns the addon-facing DB API.
- The DB module lives in `OneWoW_GUI` for now; it moves to `OneWoW` core when that refactor happens.
- Addon code works against logical scopes, not storage details.
- Initial scope set: `Global`, `Realm`, `Faction`, `Class`, `Spec`, `Char`.
- Scope names are referenced through `DB.Scope.*` constants, not raw strings.
- Scope resolution order: `Global -> Realm -> Faction -> Class -> Spec -> Char`.
- Presets are separate from scopes; only one preset is active at a time.
- Presets are sparse overlays applied at read time — they do not overwrite stored scope values.
- `Char` is a logical scope, not a requirement for a separate `SavedVariablesPerCharacter` global.
- The API supports multiple physical storage layouts for compatibility during incremental migration.
- Long-term, prefer one shared `SavedVariables` root per addon.
- Defaults are templates only and must never be stored by reference.
- Blizzard table helpers are internal implementation details, not part of the public API.
- AceDB addons are wrapped, not blocked. `Init` accepts an `aceDB` handle and returns the standard db shape. AceDB removal happens incrementally per addon.
- `DB` is a stateless utility module. `db` handles are plain tables, not objects with methods.
- `Set` puts value last: `DB:Set(db, keys..., value)`.
- Migrations use a versioned integer high-water mark. Defaults application is a normalizer, not a migration.

---

## DB Module Location

The DB module lives in `OneWoW_GUI` because every addon in the suite already depends on it.

Long-term, it should move to `OneWoW` (core) when that is refactored. Until then, addon code accesses the module as `local DB = OneWoW_GUI.DB`. When it moves, this import changes once per addon; runtime API calls stay the same.

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

## AceDB Compatibility

AceDB addons are wrapped, not blocked from adopting the DB API.

`DB:Init` accepts an `aceDB` handle. When provided, it takes `.global` and `.char` from the AceDB handle, runs `MergeMissing` against full defaults (because AceDB defaults in current code are often incomplete), and returns the standard normalized db shape.

This means AceDB addons adopt the DB API immediately without a storage migration. When AceDB is eventually removed from a specific addon, only the `Init` configuration changes — runtime code stays the same.

---

## Scope Model

V1 scopes: `Global`, `Realm`, `Faction`, `Class`, `Spec`, `Char`.

 `Race` is excluded as no real use case could be determined.

### Resolution Order

`Global -> Realm -> Faction -> Class -> Spec -> Char`

Later scopes override earlier ones. This allows large base tables in `Global` with sparse override tables in narrower scopes. `Char` is the most specific identity-based override.

### Physical Storage vs Logical Scopes

Logical scopes (`db.global`, `db.char`, resolved scope lookups) are the public concept. Physical storage (one shared root, split globals, AceDB handle) is an initialization detail hidden from addon code.

Long-term preferred layout: one shared `SavedVariables` root per addon, with character data stored at `MyAddon_DB.chars["Name-Realm"]` and exposed as `db.char`.

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
- Three initialization modes: single shared root (`savedVar`), split globals (`savedVar` + `savedVarChar`), AceDB wrapping (`aceDB`)
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

### `RunMigrations`

- Runs versioned migration steps in order
- Uses a version high-water mark at `db.global._migrationVersion`
- Skips already-completed versions
- Updates the stored version after each successful step
- If a step errors, execution stops so the next load retries from the failed step
- Called after `Init` (defaults are already applied)

---

## Default Reference Safety

The API must never store live db tables by directly assigning template tables from defaults. `MergeMissing` copies tables via `CopyTable` when filling missing keys. This prevents the dangerous pattern where mutating `db.settings` also mutates the defaults template because they share the same table reference.

---

## Metatables

Metatables may be useful for a narrow readonly resolved view but should not define the storage model:

- `pairs()` only sees real keys, not fallback values from `__index`
- Writes become ambiguous
- Nested virtual fallback tables are hard to reason about

Recommended: store scopes and presets as normal plain tables, resolve values explicitly in the DB layer, optionally expose readonly convenience views for limited read-only scenarios.

---

## Migrations vs Normalizers

The current codebase conflated two distinct concepts:

1. **One-time migrations** — structural data transformations that must run exactly once (rename keys, restructure tables, move data between scopes). These need version gating via `RunMigrations`.

2. **Normalizers** — idempotent transforms that fill missing defaults or fix data shapes. These run every load and are handled by `MergeMissing` inside `Init`.

Separating them is the biggest clarity win. `RunMigrations` handles concept 1. `Init` + `MergeMissing` handles concept 2.

### RunMigrations Format

Steps are an ordered array with `version` (integer, strictly increasing), `name` (string, for diagnostics), and `run` (function receiving the db handle). Steps run in version order; the stored `_migrationVersion` high-water mark gates execution.

### Bridging Legacy Boolean Flags

Existing addons using boolean completion flags (e.g. `categoriesV2Migrated`) need a one-time bridge between `Init` and `RunMigrations`. The bridge checks old flags, computes the correct version number, and sets `_migrationVersion` before `RunMigrations` reads it. After that, old flags are inert and can be cleaned up in a subsequent migration step.

---

## What the API Eliminates

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

### Boolean migration flags scattered through init

```lua
-- Before: interleaved boolean flags make it unclear where "apply defaults" ends
-- and "migrate data" begins
if not self.db.global.categoriesV2Migrated then
    self:MigrateCategorySystemV2()
    self.db.global.categoriesV2Migrated = true
end

-- After: versioned integer high-water mark, one migration array
DB:RunMigrations(db, {
    { version = 1, name = "category_system_v2", run = function(d) ... end },
})
```

---

## Suggested Conventions

1. Defaults describe as much static schema as possible.
2. Dynamic values are initialized after `Init`.
3. Migrations use `RunMigrations` with versioned steps in one place per addon.
4. Addon code uses the shared DB API for initialization, nested ensure/write, migrations, persistence helpers, resolved scope reads, explicit scoped writes, and preset operations.
5. Addon code does not call Blizzard `TableUtil` functions directly for database logic.
6. Addon code does not depend on AceDB-specific APIs unless a feature truly requires them.
7. Scope names are referenced through `DB.Scope.*` constants, not raw strings.
8. Presets are sparse overlays; only one is active at a time.
9. `Char` is a logical scope, not a requirement for a separate per-character `SavedVariables` global.
10. Prefer one shared `SavedVariables` root per addon long-term.
