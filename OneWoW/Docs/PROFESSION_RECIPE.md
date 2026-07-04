# Profession Recipe Funnel (`OneWoW.ProfessionRecipe`)

> **See also:** [ARCHITECTURE.md](ARCHITECTURE.md) §8.7 (summary + roster), §3.3
> (the `ns.RegisterEvent` core event multiplexer this builds on).

One core service owns trade-skill recipe scanning for the whole suite. Before it,
four unrelated listeners (AltTracker Professions, Catalog Tradeskills, core
`RecipeKnownUtil`, plus Blizzard) each registered their own frame with different
debounce timings and profession-name handling. That produced races and corrupted
SavedVariables keys: an empty-string `recipes[""]` bucket, and cross-contaminated
sets (e.g. `recipes.Mining` holding Cooking IDs) when a fast window switch let one
profession's recipes be committed under another profession's stale name.

**File:** [`OneWoW/Services/ProfessionRecipe.lua`](../Services/ProfessionRecipe.lua),
published as `OneWoW.ProfessionRecipe` via the Facade.

## Ownership

The service is the single owner of these events, registered through the core
`ns.RegisterEvent` multiplexer only while at least one consumer is subscribed:

- `TRADE_SKILL_SHOW`
- `TRADE_SKILL_LIST_UPDATE`
- `TRADE_SKILL_CLOSE`
- `NEW_RECIPE_LEARNED`

No other file in the suite may register these for recipe scanning. Events are
registered on 0→1 subscribers and torn down on 1→0.

## Channels

| API | Callback | Use |
| --- | --- | --- |
| `RegisterScanCallback(ownerID, fn)` | `fn(scan)` | Recipe data consumers (learned IDs + item map) |
| `RegisterOpenCallback(ownerID, fn)` | `fn(context)` | Live-query collectors needing only a "window ready" trigger |
| `RegisterClosedCallback(ownerID, fn)` | `fn()` | Transient-state teardown on `TRADE_SKILL_CLOSE` |
| `UnregisterCallback(ownerID)` | — | Drops all channels for an owner |
| `GetLastScan()` | — | The most recent ephemeral snapshot (sync UI helper) |

Re-registering an `ownerID` on a channel replaces the prior handler (no stacking).
Open callbacks fire **before** scan callbacks in a given scan, so a consumer's
profession list can be (re)built before recipe commit resolves against it.

## Scan snapshot

Scans are coalesced with a re-armed ~0.25s debounce and gated on
`C_TradeSkillUI.IsTradeSkillReady()`. `GetBaseProfessionInfo()` is re-read on
**every** scan so a fast window switch can never misattribute recipes. The
snapshot is **ephemeral** — core persists nothing:

```lua
{
  charKey  = "Name-Realm",
  baseInfo = { professionID, professionName, parentProfessionID,
               parentProfessionName, skillLevel, maxSkillLevel },
  learned  = { [recipeID] = true, ... },   -- learned recipes for the open profession
  itemMap  = { [itemID] = recipeID, ... },  -- from GetRecipeItemLink
  scannedAt = <time()>,
}
```

The snapshot carries the **numeric** profession identity, not just the name
string, because the empty/stale name string was the original corruption surface.

## Consumers (LoD-safe)

Every consumer subscribes on login (nil-guarding its own settings) and degrades
gracefully when peer units are absent — there are **no** suite-internal
`OptionalDeps`.

| Consumer | Channel | Responsibility |
| --- | --- | --- |
| `RecipeKnownUtil` (core) | scan | In-memory known-spell cache + item→spell session map |
| `AltTracker_Professions` `ProfessionRecipeCommit` | scan | Resolve canonical profession, commit `charData.recipes`, persist `recipeItemMap` |
| `AltTracker_Professions` `DataManager` | open / closed | Live-query collectors (basics / equipment / concentration / expansion bands) |
| `CatalogData_Tradeskills` `TradeskillScanner` | scan | `scanCache` merge, then its own `RegisterScanCallback` fan-out for Catalog UI |
| `AltTracker` Professions tab | scan | Live tab refresh when visible |

### Identity resolution (commit side)

`ProfessionRecipeCommit` resolves the snapshot to one of the character's own
profession slots, in priority order:

1. Numeric base skill line (`baseInfo.professionID` vs `professions[*].skillLine`)
2. Exact own-slot name match (non-empty)
3. Per-recipe plurality via `C_TradeSkillUI.GetProfessionInfoByRecipeID` (Blizzard-native, no catalog)
4. Catalog plurality via `OneWoW_CatalogData_Tradeskills_API.GetRecipeProfession` (only if that unit is loaded)
5. **Unresolved → skip** (never write `recipes[""]`)

### Persistence rules

- **Monotonic:** a partial/empty scan never shrinks a stored set.
- **Self-healing:** scanned IDs authoritatively belong to the resolved
  profession, so they are pruned from every other bucket, and the `""` bucket is
  dropped on any resolved commit. A retryable v3 repair in the Professions
  `Core/Database.lua` relocates orphaned `""` entries at login (deferred when no
  attribution source is available).
- **Degraded display:** without the catalog data unit loaded, the AltTracker
  Professions tab shows the stored Known count and dashes out Total/Missing —
  never a misleading `Total 0 / Known 0`.
