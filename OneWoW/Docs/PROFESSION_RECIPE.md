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
registered on 0→1 subscribers and torn down on 1→0. Enforced by the
`core-event-funnel` pre-commit hook (`OneWoW_Workspace/bin/check_no_core_event_bypass.py`),
whose `EVENT_OWNER` registry pins all four events to `ProfessionRecipe.lua`.

## Channels

| API | Callback | Use |
| --- | --- | --- |
| `RegisterScanCallback(ownerID, fn)` | `fn(scan)` | Recipe data consumers (learned IDs + item map). Debounced + ready-gated |
| `RegisterOpenCallback(ownerID, fn)` | `fn(context)` | Live-query collectors needing only a "window ready" trigger. Debounced + ready-gated |
| `RegisterShowCallback(ownerID, fn)` | `fn()` | **Immediate** `TRADE_SKILL_SHOW`, undebounced — panels that must appear in lockstep with the window. Delivers a catch-up call if the window is already open at subscribe time |
| `RegisterLearnedCallback(ownerID, fn)` | `fn(recipeID, recipeLevel, baseRecipeID)` | **Immediate** `NEW_RECIPE_LEARNED`, un-gated — fires even with the trade-skill window closed (trainer / world-drop learns), which the ready-gated scan cannot |
| `RegisterClosedCallback(ownerID, fn)` | `fn()` | Transient-state teardown on `TRADE_SKILL_CLOSE` |
| `UnregisterCallback(ownerID)` | — | Drops all channels for an owner |
| `IsTradeskillOpen()` | `→ boolean` | Live "is a profession window open" read (ready **or** `ProfessionsFrame` shown). Shared replacement for per-module `_atCrafting` flags |
| `GetLastScan()` | — | The most recent ephemeral snapshot (sync UI helper) |

Re-registering an `ownerID` on a channel replaces the prior handler (no stacking).
Open callbacks fire **before** scan callbacks in a given scan, so a consumer's
profession list can be (re)built before recipe commit resolves against it.

### Channel selection: why `NEW_RECIPE_LEARNED` is not on the scan channel

The scan is **ready-gated** (`IsTradeSkillReady()`) and debounced, so it only
fires while the trade-skill/professions window is open. `NEW_RECIPE_LEARNED`,
however, also fires when learning from a **trainer** (opens the trainer window,
not the trade-skill window) or a world-drop recipe item — contexts where a scan
never fires. Consumers that must react to *every* learn (trainer-cost accounting,
recipe-known overlay refresh) therefore use the immediate, un-gated
`RegisterLearnedCallback`, which also carries the event payload (the just-learned
`recipeID`) rather than only the full learned set a scan snapshot would provide.

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
| `overlay-engine` (core) | learned | Refresh recipe-known bag overlays on any learn (incl. trainer / drops) |
| `AltTracker_Professions` `ProfessionRecipeCommit` | scan | Resolve canonical profession, commit `charData.recipes`, persist `recipeItemMap` |
| `AltTracker_Professions` `DataManager` | open / closed | Live-query collectors (basics / equipment / concentration / expansion bands) |
| `AltTracker_Accounting` `TrainerTracker` | learned | Confirm + name trainer purchases against the `PLAYER_MONEY` gold diff |
| `CatDB_TradeSkillDB` | scan | recipe rows for Catalog; known-by is AltTracker Professions |
| `AltTracker` Professions tab | scan | Live tab refresh when visible |
| `Trackers` `TrackerEngine` | open | Defer a tracker full-scan when a profession window becomes ready |
| `QoL` `bagbar` | show / closed | Suppress the bag bar while the profession window is open |
| `QoL` `professionspanel` | show / open / closed | Sidebar tab + auto-show panel, live data refresh, teardown |
| `QoL` `autoopen` | `IsTradeskillOpen()` | Suppress auto-open while a profession window is open (state read, no subscription) |

### Identity resolution (commit side)

`ProfessionRecipeCommit` resolves the snapshot to one of the character's own
profession slots, in priority order:

1. Numeric base skill line (`baseInfo.professionID` vs `professions[*].skillLine`)
2. Exact own-slot name match (non-empty)
3. Per-recipe plurality via `C_TradeSkillUI.GetProfessionInfoByRecipeID` (Blizzard-native, no catalog)
4. Catalog plurality via `OneWoW_CatDB_TradeSkillDB_API.GetRecipeProfession` (only if that unit is loaded)
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
