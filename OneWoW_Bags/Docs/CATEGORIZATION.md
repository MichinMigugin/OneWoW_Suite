# OneWoW_Bags — Categorization

This document describes how items are assigned to categories, how category rows are ordered, and how per-category sorting and grouping work. It reflects the implementation in `Data/Categories.lua`, `Modules/CategoryManager.lua`, `Views/CategoryView.lua`, `Views/CategoryViewHelpers.lua`, `Views/BankCategoryView.lua`, `Data/Sorting.lua`, `Core/SectionDefaults.lua`, and related settings in `Core/Database.lua`. The expression engine consumed throughout the pipeline (`PE` below) is provided by `OneWoW_GUI`; for engine internals and its public API, see [`OneWoW_GUI/Docs/PREDICATE_ENGINE.md`](../../OneWoW_GUI/Docs/PREDICATE_ENGINE.md).

## Overview

1. **Assignment**: For each occupied bag/bank slot, `Categories:GetItemCategory(bagID, slotID, itemInfo)` returns a **category name** string. The function filters by `appliesIn` per container type at assignment time.
2. **Bucket**: Buttons are grouped by that name (`CategoryManager:GetItemsByCategory` for bags; an inline loop in `BankCategoryView`).
3. **Category row order**: `H.GetSectionedLayout` (in `CategoryViewHelpers.lua`, shared by bags and bank) when sections or `displayOrder` apply, or `H.GetSortedCategoryNames` / `Categories:SortCategories` for fallbacks.
4. **Within-category presentation**: Optional search filter, then `SortButtons` (global `itemSort` and/or per-category `sortMode` + `subSortMode`), optional `stackItems`, optional `groupBy` sub-rows. All of these features are shared by both bags and bank via the `H.LayoutCategoryContent` pipeline.

---

## End-to-end flow (bags, category view)

1. `CategoryView:Layout` calls `CategoryManager:AssignCategories()`, which walks `BagSet:GetAllButtons()` and sets `button.owb_categoryName = Categories:GetItemCategory(...)` for occupied slots.
2. `CategoryManager:GetItemsByCategory()` buckets buttons by `owb_categoryName`.
3. `H.GetSectionedLayout(itemsByCategory, containerType)` (in `CategoryViewHelpers.lua`) produces either a flat sorted name list or a structured list of entries (`separator`, `section_header`, `category`).
4. `H.PinSpecialCategories` may move **"Recent Items"** to the top and **"Other"** to the bottom using `db.global.moveRecentToTop` and `moveOtherToBottom`.
5. `H.LayoutCategoryContent(config)` renders each category: filtered buttons are sorted, optionally stacked, and optionally split into subgroup grids.

---

## `GetItemCategory` pipeline

Classification is split into:

1. **`GetItemCategory`** — slot-keyed fast path, then **slot overlays** (upgrade / recent), then delegates to the base resolver.
2. **`ResolveBaseCategory`** (private) — manual pins through merged builtin/custom predicates, with **identity + `containerType` caching** (`baseCategoryCache`).

**`containerType`:** `BagTypes:GetContainerType(bagID)` yields `"backpack"`, `"character_bank"`, or `"warband_bank"`. `CategoryAppliesTo` uses this everywhere. `"Other"` and `"Empty"` always bypass `appliesIn` filtering.

### Phase A — `GetItemCategory` (slot layer)

| Step | Condition | Result / notes |
|------|-----------|----------------|
| A0 | Missing `itemInfo` | `"Other"` |
| A1 | **`categoryCache` hit** (`PE:GetItemCacheKey`) | Cached final category (includes prior overlay hits for this slot) |
| A2 | **1W Upgrades (overlay)** — `itemID` + `hyperlink`, `enableUpgradeCategory`, not disabled, `CategoryAppliesTo`, **`OneWoW` + `UpgradeDetection` present** | `"1W Upgrades"`; prefers `ItemLocation:CreateFromBagAndSlot` when the item exists |
| A3 | **Recent Items (overlay)** — not disabled, `CategoryAppliesTo`, `SlotMatchesRecent` | `"Recent Items"` |

Overlays run **after** the slot cache misses and **before** `ResolveBaseCategory`. **Upgrade beats Recent** on the same slot when both could apply.

After A2/A3, hits are written to **`categoryCache`** so repeat lookups are cheap.

### Phase B — `ResolveBaseCategory` (identity tier)

Runs when A2/A3 do not return. Items resolved here can reuse **`baseCategoryCache`** keyed by `PE:GetItemIdentityKey(itemID, hyperlink) .. "|" .. containerType` so every slot with the same identity in the same container type shares one merged-pool verdict.

| Step | Condition | Result / notes |
|------|-----------|----------------|
| B1 | **Manual pin** (`ResolveManualCategoryName`) | Same rules as before: `customCategoriesV2[*].items`, `categoryModifications[*].addedItems`, `pinnedCategoryShowsWhenDisabled`, `CategoryAppliesTo`, `PickBestCandidate` on ties |
| B2 | **1W Junk** | `enableJunkCategory`, not disabled, `CategoryAppliesTo`, `PE:BuildProps(...).isJunk` (Poor quality or `OneWoW.ItemStatus:IsItemJunk` when OneWoW is present) |
| B3 | No **hyperlink** | `"Other"` (predicate pool skipped) |
| B4 | **`not C_Item.IsItemDataCachedByID(itemID)`** | `"Other"`, **`tentative`** — requests load, sets `OneWoW_Bags._hasPendingTentatives`; **no** slot or base cache write |
| B5 | **`baseCategoryCache` hit** | Cached merged-pool category |
| B6 | **`PE:BuildProps` + merged pool** | `CollectCustomPredicateCandidates` walks **`precomputedCustomCands`** (rebuilt when `customCategoriesV2` changes); builtins from **`SEARCH_CATEGORIES`**. `PickBestCandidate` tie-break (see below). Pool filtered by `CategoryAppliesTo` after collection |
| B7 | **Inventory slots** | If pool result is `"Weapons"` / `"Armor"` and `enableInventorySlots`, remap via `GetSlotCategoryName` when allowed |
| B8 | **Disabled fallback** | Candidate-pool-derived name in `disabledCategories` → `"Other"` |
| B9 | **`_tooltipDataMissing` on props** | Verdict returned but **`tentative`** — caches skipped until tooltip/streaming catches up |
| B10 | **Cache write** | On non-tentative success: store in **`baseCategoryCache`**. Caller **`GetItemCategory`** stores in **`categoryCache`** when `cacheKey` exists, hyperlink exists, and **not tentative** |

**What never enters `baseCategoryCache`:** slot overlays (**Upgrades**, **Recent**) — they only exist in `GetItemCategory`.

**Custom category evaluation:** `InferFilterMode` and **`SavedSearches:Expand`** behave as before; expand runs only when the expression contains a literal `SAVED(` substring (`needsExpand` optimization).

### Manual pins (`ResolveManualCategoryName`) — detail

**No PredicateEngine on this path.** Candidates from `customCategoriesV2[*].items` and `categoryModifications[*].addedItems` (candidates carry `tieKey` for API lookups only; assignment ties do not use it). Filtered by `CategoryAppliesTo`, then `pinnedCategoryShowsWhenDisabled` stripping (when false), then `PickBestCandidate`.

### `#recent` vs Recent overlay

The **`#recent`** keyword still delegates to `Categories:SlotMatchesRecent` for PredicateEngine search/category expressions. The **Recent Items category overlay** (phase A3) is separate enforcement so recent gear surfaces above merged-pool classification until expiry **unless** phase A2 classified it as an upgrade first.

### Builtin search: Mats vs Reagents

Builtin rows split crafting mats from classic reagents:

- **`Mats`** — `#craftingreagent`
- **`Reagents`** — `#reagent & !#craftingreagent`

Both participate in the same merged pool as other `SEARCH_CATEGORIES` rows (sorted by `searchOrder`; duplicate `searchOrder` values keep stable ordering among ties).

---

## Tie-breaking (`PickBestCandidate` / `CandidateBeats`)

`PickBestCandidate(cands, db, g)` iterates all candidates and returns the one that beats all others via `CandidateBeats`. The comparison chain:

| Tier | Criterion | Direction | Notes |
|------|-----------|-----------|-------|
| 1 | `ModPriority(db, name)` | **Higher** wins | `categoryModifications[name].priority` or 0. This is the user-facing "Priority" setting (Lowest through Max). |
| 2 | `isCustom` | Custom wins | When user-facing priorities are equal, a custom category beats a builtin. |
| 3 | `defaultOrder` | **Lower** wins | From `CATEGORY_DEFINITIONS .priority` via the candidate's `defaultOrder` field; absent = 9999. Only relevant when two builtins tie on user priority. |
| 4 | `SectionOrderIndexForCategory(g, name)` | **Lower** wins | Index of the first `sectionOrder` entry whose `categorySections[sid].categories` lists the name; unsectioned = `#sectionOrder + 1`. Compares **sections**, not position within a section. |
| 5 | **List order** (`categoryListOrderMap`) | **Lower** wins | Global rank from `sectionOrder` + each section's `categories[]` in order (Category Manager sidebar). Earlier in the list wins when priorities and section index tie. Rebuilt on `InvalidateCache`. |
| 6 | `searchOrder` | **Lower** wins | From `CATEGORY_DEFINITIONS`; absent = 9999. Fallback for builtins not yet in any section list. |
| 7 | Category **name** | Alphabetical | Stable final tie; never uses internal `customCategoriesV2` entry IDs. |

**Where this applies:**

- **Manual pins (phase B1):** Candidates have no `isCustom` or `defaultOrder` fields — tiers 2–3 are skipped (both nil). Tie-breaking: user priority → section index → list order → `searchOrder` → name.
- **Merged pool (phase B6):** Full 7-tier chain. A custom category with the same user-facing priority as a builtin wins (tier 2). A builtin with a higher user-facing priority wins over any custom category (tier 1).

---

## Priority terminology (two distinct concepts)

1. **User-facing priority** (`categoryModifications[name].priority`) — the "Priority" button in the category manager GUI (Lowest = -2, Low = -1, Normal = 0, High = 1, Higher = 2, Max = 3). Two uses:
   - **Assignment tie-breaking** (tier 1 of `CandidateBeats`): only `mod.priority` is compared; **higher** value wins.
   - **Category row sorting** (`SortCategories`, priority mode): effective order = `defaultOrder + mod.priority`; **lower** total wins.

2. **Default order** (`CATEGORY_DEFINITIONS[*].priority`, stored in `CATEGORY_DEFAULT_ORDER`) — an internal numeric value (1–99) controlling where builtin categories appear by default in the header sort order. Exposed as `Categories:GetCategoryDefaultOrder(name)` (unknown names → **50**). Not directly visible to users, but indirectly affects header positioning.

**`searchOrder`** — among matching builtins not placed in a section list, **lower** `searchOrder` wins when all higher tiers tie.

**Section order** (`SectionOrderIndexForCategory`): **lower section index wins** when priorities tie across different sections. Categories not in any section get `#sectionOrder + 1`.

**List order** (`RebuildCategoryListOrderMap`): walks `sectionOrder`, then each section's `categories[]` array in order, assigning a 1-based rank per category name (first occurrence wins). Unlisted names fall back to `displayOrder` (if set), then custom `sortOrder`, then builtin `searchOrder` order, then `categoryOrder`. Drag-reorder in the Category Manager updates `categories[]` and invalidates this map via `InvalidateCategorization`.

---

## Builtin definitions

`CATEGORY_DEFINITIONS` in `Data/Categories.lua` lists built-in names, numeric **default order** (for header sorting), and optional **search** + **searchOrder** for predicate-based classification.

| Name | Default Order | Search | searchOrder |
|------|---------------|--------|-------------|
| 1W Junk | 1 | — | — |
| 1W Upgrades | 1 | — | — |
| Recent Items | 1 | — | — |
| Hearthstone | 2 | `#hearthstone` | 2 |
| Keystone | 3 | `#keystone` | 8 |
| Potions | 4 | `#potion` | 9 |
| Food | 5 | `#food` | 10 |
| Consumables | 6 | `#consumable` | 16 |
| Quest Items | 7 | `#quest` | 13 |
| Equipment Sets | 8 | `#set` | 3 |
| Weapons | 9 | `#weapon` | 14 |
| Armor | 10 | `#armor & #gear` | 15 |
| Mats | 10.5 | `#craftingreagent` | 10 |
| Reagents | 11 | `#reagent & !#craftingreagent` | 11 |
| Trade Goods | 12 | `#tradegoods` | 20 |
| Tradeskill | 13 | `#tradeskill` | 22 |
| Recipes | 14 | `#recipe` | 21 |
| Housing | 15 | `#housing` | 1 |
| Gems | 16 | `#gem` | 17 |
| Item Enhancement | 17 | `#enhancement` | 18 |
| Containers | 18 | `#container` | 19 |
| Keys | 19 | `#key` | 7 |
| Miscellaneous | 20 | `#misc & !#gear` | 6 |
| Battle Pets | 21 | `#battlepet` | 12 |
| Toys | 22 | `#toy` | 5 |
| Junk | 90 | `#poor` | 4 |
| Other | 98 | — | — |
| Empty | 99 | — | — |

**"1W Junk"**, **"1W Upgrades"**, and **"Recent Items"** have no `search`/`searchOrder` in definitions — **Upgrades** and **Recent** are enforced as **slot overlays** in `GetItemCategory`; **Junk** is resolved inside **`ResolveBaseCategory`** before the merged pool.

**"Empty"** appears in definitions and default `displayOrder` for import/ordering. **`GetItemCategory` never returns `"Empty"`** for an item. Empty slots are handled by List/Tab layout and per-container `*ShowEmptySlots` settings, not this classifier.

**"Other"** has no search expression — it is the implicit fallback when nothing else matches.

**`SEARCH_CATEGORIES`** is the subset of `CATEGORY_DEFINITIONS` that have both `search` and `searchOrder`, sorted by `searchOrder` ascending. This is the table iterated in **phase B6**'s builtin collection.

---

## Sorting

### Category rows (order of headers)

- **`categorySort`**: `"priority"` or `"alphabetical"`. Alphabetical mode applies special ordering: **"Empty"** last; **"Other"** and **"Junk"** near bottom; **"Recent Items"** first among the rest; then string compare on names.
- **Priority mode** (`SortCategories`): effective order = `defaultOrder + mod.priority`; lower wins. When two categories tie on effective order, falls back to `customCategoriesV2[*].sortOrder` (lower wins, 999 if unset), then name alphabetical.
- **`categoryOrder`**: When set, used by `GetSortedCategoryNames` and for sorting **orphaned** categories (fallback path) in some layout paths.
- **`displayOrder`**: Linear sequence with `"----"` separators and `section:ID` … `section_end` blocks. Categories not listed are collected as **leftover**, sorted with `SortCategories`, and appended.
- **`sectionOrder` + `categorySections`**: When `displayOrder` is empty, sections render in `sectionOrder`, then any **orphaned** categories (fallback, should normally be empty since `SyncOnewowSectionCategories` scoops orphans into the ONEWOW_BAGS section).

If **`sectionOrder` is empty**, `GetSectionedLayout` returns `GetSortedCategoryNames` only (no section structure).

### Items inside a category

`OneWoW_Bags:SortButtons` (`Data/Sorting.lua`): `none`, `default` (bag ID then slot), `name`, `rarity`, `ilvl`, `type`, `expansion`.

- Default mode from `db.global.itemSort` via `WindowLayoutController:CreateViewContext`.
- **Per-category override**: `categoryModifications[categoryName].sortMode`. In both `CategoryView` and `BankCategoryView`, if set, it is passed as the primary override argument to `sortButtons`. Mode **`none`** leaves order unchanged (typically bag/slot from the pool).
- **Per-category sub-sort**: `categoryModifications[categoryName].subSortMode` is an optional secondary criterion. When present and different from the primary sort mode, `SortButtons` compares primary sort first, then sub-sort, then `default` bag/slot order as the deterministic fallback.
- **Sort direction**: `sortDescending` and `subSortDescending` (optional booleans on `categoryModifications`) override asc/desc per row; unset uses each mode's built-in default. Configured via direction toggles beside Sort / Sub-sort in Category Manager.
- **Legacy tie-breakers**: when no explicit sub-sort is configured, some primary modes keep their older built-in tie-breakers (`rarity -> name`, `ilvl -> rarity`, `type -> name`, `expansion -> rarity`) before falling back to `default`.
- **`rarity` / sub-sort `rarity`**: uses cached `_owb_itemQuality`, then `_owb_reagentQuality`, then `_owb_craftedQuality` (set on full update from container info and PredicateEngine props); see `Docs/ARCHITECTURE.md` sorting section.

---

## Grouping (sub-rows inside one category)

Shared by both `CategoryView` (bags) and `BankCategoryView` (bank) via `H.LayoutCategoryContent` (with category headers enabled and section expanded):

- `categoryModifications[name].groupBy`: `expansion`, `type`, `slot`, `quality`, or `none` / unset.
- Subgroups: small label + `RenderItemGrid` per group (`GroupItemsByExpansion`, `GroupItemsByType`, `GroupItemsBySlot`, `GroupItemsByQuality`).

---

## Layout visibility and `containerType`

`H.GetSectionedLayout(itemsByCategory, containerType)` (in `CategoryViewHelpers.lua`):

- **Disabled category**: hidden unless `pinnedCategoryShowsWhenDisabled` and the category has items in `itemsByCategory`.
- **`categoryModifications[cat].appliesIn[containerType]`**: when `appliesIn[containerType] == false`, the category is excluded from layout for that container. "Other" and "Empty" are always exempt.
- **Section header visibility**: resolved per-container. Bags use `section.showHeader`; bank uses `section.showHeaderBank` (falls back to `section.showHeader` when nil). This allows independent control of header visibility between bags and bank.

**Equipment sections**: If a section lists **"Weapons"** or **"Armor"** and **`enableInventorySlots`**, additional **dynamic** category names (localized equip slot labels) that have items and are not already listed in `displayOrder` can be injected into that section.

---

## PredicateEngine

The engine lives in `OneWoW_GUI` (`OneWoW_GUI.PredicateEngine`) and is acquired in Bags via `local PE = OneWoW_GUI.PredicateEngine`. Full reference: [`OneWoW_GUI/Docs/PREDICATE_ENGINE.md`](../../OneWoW_GUI/Docs/PREDICATE_ENGINE.md).

Search strings use its expression language (`#keyword`, operators, etc.). `BuildProps` enriches items using **bag-slot context** (`bagID`, `slotID`) so tooltip-backed predicates match the search bar (via `C_TooltipInfo.GetBagItem` where applicable). `CheckItem(expr, ...)` evaluates membership. Both custom `searchExpression` categories and builtin search categories use this engine. Custom category expressions expand `SAVED(Name)` shortcuts before calling the engine; built-in category searches are static and do not use saved searches.

**Bags-specific registration:** The `#recent` keyword is registered by `Data/Categories.lua` to delegate to `Categories:SlotMatchesRecent` (GUID map + duration are Bags-owned). `#catalyst` / `#catalystupgrade` are now registered by the engine itself and silently no-op when TransmogUpgradeMaster is absent.

---

## Overrides and persisted data (summary)

| Mechanism | Role |
|-----------|------|
| `customCategoriesV2` | Custom categories: `items`, `searchExpression`, `itemType` / `itemSubType`, `filterMode`, `typeMatchMode`, `enabled`, `sortOrder`, `isTSM`, etc. |
| `savedSearches` | Named predicate shortcuts expanded from `SAVED(Name)` before custom search categories are evaluated |
| `categoryModifications[name]` | `sortMode`, `subSortMode`, `sortDescending`, `subSortDescending`, `groupBy`, `priority`, `color`, `appliesIn`, `addedItems` |
| `disabledCategories` | Disable builtin/custom by name; classification remaps to **Other** when applicable |
| `enableJunkCategory` | Separate toggle for **phase B2** (default `true`); disabling skips the 1W Junk check entirely |
| `enableUpgradeCategory` | Separate toggle for **phase A2** (default `true`); disabling skips the 1W Upgrades overlay entirely |
| `pinnedCategoryShowsWhenDisabled` | If true, manual pins win even when their target category is disabled. If false, disabled pins are filtered out so later stages can assign. Also controls visibility of disabled categories with items in `H.GetSectionedLayout`. |
| `categoryOrder`, `sectionOrder`, `displayOrder`, `categorySections` | Structural ordering and grouping; `categorySections[id].showHeader` / `.showHeaderBank` control per-container header visibility |
| `enableInventorySlots` | Split **Weapons** / **Armor** into slot-named categories after candidate pool pick (default `false`) |
| `stackItems` | Merge identical items for display inside category view |
| `compactCategories` / `compactGap` | Side-by-side category blocks via `CategoryViewHelpers.LayoutCompactGroup` |
| `moveRecentToTop` | Pins **"Recent Items"** to the top of the layout (default `false`) |
| `moveOtherToBottom` | Pins **"Other"** to the bottom of the layout (default `false`) |
| `recentItemDuration` | Seconds an item stays "recent" after acquisition (default 120, range 15–600) |

---

## Bags vs bank (category view)

Both views are thin wrappers that delegate to the shared pipeline in `CategoryViewHelpers.lua` (`H.GetSectionedLayout` + `H.LayoutCategoryContent`).

| Feature | Bags `CategoryView` | `BankCategoryView` |
|---------|---------------------|---------------------|
| Classification | `CategoryManager:AssignCategories()` (pre-walk `BagSet`) | Inline `Categories:GetItemCategory` per `BankSet` button |
| Bucketing | `CategoryManager:GetItemsByCategory()` | Inline loop building `itemsByCategory` |
| Sections / `displayOrder` | Yes (shared `H.GetSectionedLayout`) | Yes (shared `H.GetSectionedLayout`) |
| Per-category `sortMode` / `subSortMode` | Yes | Yes |
| Per-category `groupBy` | Yes | Yes |
| `stackItems` | Yes | Yes |
| `appliesIn` filtering | Yes (at assignment + layout) | Yes (at assignment + layout) |
| Section header visibility | `showHeader` | `showHeaderBank` (falls back to `showHeader`) |
| Compact mode | `compactCategories` / `compactGap` | `bankCompactCategories` / `bankCompactGap` |

---

## Integrations

- **TSM** (`Integrations/TSMIntegration.lua`): Creates `customCategoriesV2` entries with `"TSM: "` prefixed names, `items` maps, and `isTSM = true`. These behave like manual-pin custom categories for assignment (**phase B1**, not the merged pool).
- **Baganator** (`Controllers/CategoryController.lua`): `BAGANATOR_CAT_MAP` maps external keys to builtin names (including `"Empty"` for ordering/import). Does not change `GetItemCategory` logic for `"Empty"`.

---

## Cache and invalidation

- **`categoryCache`** — slot-keyed (`PE:GetItemCacheKey`); stores final categories including overlay results for that slot. Cleared by `Categories:InvalidateCache` / full categorization invalidation.
- **`baseCategoryCache`** — identity + `containerType`; stores merged-pool results shared across slots with the same item identity. Never holds upgrade/recent overlay verdicts.
- **Tentative results** — item data still streaming (`IsItemDataCachedByID`) or tooltip fields missing (`_tooltipDataMissing`): verdicts may return `"Other"` or a best-effort category but **omit cache writes** until a later refresh.
- **`InvalidateItemIDs`** — surgical eviction coordinated with `PredicateEngine:InvalidateItemIDs` on batched `GET_ITEM_INFO_RECEIVED` so unrelated identity keys stay hot during bulk streaming (see `Events:OnItemInfoReceived`).
- **`Categories:InvalidateCache`** and **`OneWoW_Bags:InvalidateCategorization`**: refresh custom categories, recent settings, clear caches; PredicateEngine invalidation per scope. See `Docs/ARCHITECTURE.md`.

---

## Related files

| File | Responsibility |
|------|------------------|
| `Data/Categories.lua` | `GetItemCategory`, internal `ResolveBaseCategory`, `SortCategories`, two-tier caches + tentative/streaming handling, `precomputedCustomCands`, manual/custom/builtin helpers, `InvalidateItemIDs` hooks |
| `Modules/CategoryManager.lua` | Bag assignment (`AssignCategories`), bucketing (`GetItemsByCategory`) |
| `Views/CategoryViewHelpers.lua` | Shared layout pipeline: `GetSortedCategoryNames`, `GetSectionedLayout`, grouping, stacking, filtering, `LayoutCategoryContent`, grids, compact layout, `PinSpecialCategories` |
| `Views/CategoryView.lua` | Bags category view (thin wrapper over shared pipeline) |
| `Views/BankCategoryView.lua` | Bank category view (thin wrapper over shared pipeline) |
| `Data/Sorting.lua` | `SortButtons` |
| `OneWoW_GUI/PredicateEngine.lua` | Shared expression engine and item props (see [`PREDICATE_ENGINE.md`](../../OneWoW_GUI/Docs/PREDICATE_ENGINE.md)) |
| `Core/SectionDefaults.lua` | Section IDs, builtin ordering, OneWoW Bags section sync |
| `Controllers/CategoryController.lua` | CRUD, import maps, UI refresh orchestration, `appliesIn` / `showHeaderBank` setters |
