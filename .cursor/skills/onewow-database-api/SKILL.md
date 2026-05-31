---
name: onewow-database-api
description: Use this skill when authoring or reviewing OneWoW addon code that touches SavedVariables, defaults, migrations, or scope resolution — anything calling OneWoW_GUI.DB or accessing Addon.db.* paths.
---

# OneWoW Database API Skill

## Context

The OneWoW Suite owns its addon-facing database API in `OneWoW_GUI.DB`. All OneWoW addons must use it for SavedVariable management. Do not hand-roll merge functions, ensure-if-nil blocks, or per-addon default application logic.

`DB` is a stateless utility module. `db` handles are plain tables, not objects with methods — calls go through `DB:Read(db, ...)`, never `db:Read(...)`.

## Authoritative sources

1. `OneWoW_GUI/Database.lua` — API surface. Read first for function signatures and behavior.
2. `OneWoW_GUI/Docs/DATABASE.md` — design rationale. Read when uncertain *why* the API is shaped a certain way (scope resolution order, migrations vs. normalizers, default reference safety).

## Standard import

```lua
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end
local DB = OneWoW_GUI.DB
```

## Core operations

### Initialization

`DB:Init(config)` returns a normalized `db` table with `db.global` and `db.char` always populated. Three modes:

- `single` (preferred) — one shared SavedVariable root; char data at `root.chars["Name-Realm"]`
- `split` — separate `SavedVariables` and `SavedVariablesPerCharacter` globals
- `acedb` — wraps an existing AceDB handle for incremental migration

After `Init` returns, `db`, `db.global`, and every key in the defaults table are **guaranteed to exist**.

### Defaults

`DB:MergeMissing(target, defaults)` fills only `nil` keys, recurses into tables, and uses `CopyTable` on table values to prevent reference sharing with the defaults template. Called automatically inside `Init` when `config.defaults` is provided.

### Path operations

All take the `db` handle plus path keys:

- `DB:Read(db, ...)` — safe walk, returns nil if any segment missing
- `DB:Ensure(db, ...)` — walks path, creates intermediate tables, errors on non-table intermediate
- `DB:Set(db, ..., value)` — value is the **last** argument, path keys precede it
- `DB:Delete(db, ...)` — removes the final key

### Scoped reads/writes

Resolution order: `Global → Realm → Faction → Class → Spec → Char`. Reference scope names through `DB.Scope.*` constants, never raw strings.

- `DB:GetResolvedValue(db, ...)` — walks resolution order, applies active preset last
- `DB:GetResolvedTable(db, ...)` — assembled read-only view across scopes
- `DB:SetScopeValue(db, scope, ..., value)` — write to one specific scope

### Presets

Sparse overlays applied at read time. Only one active at a time. Do not mutate stored scope values.

- `DB:SetPresetValue(db, presetName, ..., value)`
- `DB:SetActivePreset(db, presetName)`

### Migrations

`DB:RunMigrations(db, migrations)` runs versioned, one-time structural transforms. Uses an integer high-water mark at `db.global._migrationVersion`.

```lua
DB:RunMigrations(db, {
    { version = 1, name = "category_system_v2", run = function(d) ... end },
    { version = 2, name = "rename_old_key",     run = function(d) ... end },
})
```

Migrations are structural (rename keys, restructure tables, move data between scopes). Defaults application is a normalizer handled by `Init` + `MergeMissing`, not a migration. Legacy boolean completion flags need a one-time bridge: compute the equivalent version and set `_migrationVersion` before `RunMigrations` reads it.

## Shared settings

Theme, language, and minimap are managed by `OneWoW_GUI:GetSetting` / `OneWoW_GUI:SetSetting`. Do not store them locally per-addon.

## Review checklist — anti-patterns to flag

1. **Defensive nil-chains on DB-defaulted keys.** `Addon.db and Addon.db.global and Addon.db.global.X` is dead code after `Init` + `MergeMissing`.

2. **`or default` on keys that have defaults.** `Addon.db.global.scale or 1.0` when `scale = 1.0` is in the defaults table — the fallback hides bugs in `MergeMissing`. `or {}` and `or default` are only correct for **dynamic keys** not defined in defaults (e.g. `catMods[entryName] or {}`).

3. **Hand-rolled merge / ensure-if-nil blocks.** `if not db.global.X then db.global.X = {} end`, custom `ApplyDefaults`, `mergeSubTable`, `mergeTabSettings` — replace with defaults + `MergeMissing` (automatic in `Init`) or `DB:Ensure` for dynamic paths.

4. **Boolean migration flags interleaved with init.** `if not db.global.fooMigrated then ... end` should be a versioned `RunMigrations` step.

5. **Direct Blizzard helpers for SV init.** `MergeTable` overwrites destination values; `SetTablePairsToTable` wipes and replaces — both wrong for fill-only SV semantics. `MergeMissing` is the correct primitive.

6. **Storing shared suite settings locally.** Theme, language, minimap state must go through `OneWoW_GUI:GetSetting` / `SetSetting`.

7. **Raw scope name strings.** `"global"`, `"realm"`, etc. should be `DB.Scope.Global`, `DB.Scope.Realm`.

8. **Defaults stored by reference.** Direct assignment of a defaults sub-table into a live db table creates a reference-sharing bug — mutations to the live table mutate the defaults template. `MergeMissing` handles this via `CopyTable`; manual paths must do the same.

9. **AceDB-specific calls in new code.** `db:RegisterDefaults`, `db:GetProfile`, profile callbacks. Wrap via `Init` `acedb` mode or migrate off AceDB. Do not depend on AceDB APIs unless a feature truly requires them.

10. **Object-oriented calls on `db`.** `db:Read(...)`, `db:Set(...)` won't work — `db` is a plain table, `DB` is the utility module.

## Related rules

- `.cursor/rules/No-Defensive-Guards.mdc` — overlaps with items 1–2 above and covers broader API/addon nil-checking.
