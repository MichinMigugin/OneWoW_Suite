# OneWoW_Bags — Categorization

This document describes how items are assigned to categories, how category rows are ordered, and how per-category sorting and grouping work. It reflects the implementation in `Data/Categories.lua`, `Modules/CategoryManager.lua`, `Views/CategoryView.lua`, `Views/CategoryViewHelpers.lua`, `Views/BankCategoryView.lua`, `Data/Sorting.lua`, `Core/SectionDefaults.lua`, and related settings in `Core/Database.lua`. The expression engine consumed throughout the pipeline (`PE` below) is provided by `OneWoW_GUI`; for engine internals and its public API, see [`OneWoW_GUI/Docs/PREDICATE_ENGINE.md`](../../OneWoW_GUI/Docs/PREDICATE_ENGINE.md).

## Overview

1. **Assignment**: For each occupied bag/bank slot, `Categories:GetItemCategory(bagID, slotID, itemInfo)` returns a **category name** string. The function filters by `appliesIn` per container type at assignment time.
2. **Bucket**: Buttons are grouped by that name (`CategoryManager:GetItemsByCategory` for bags; an inline loop in `BankCategoryView`).
3. **Category row order**: `H.GetSectionedLayout` (in `CategoryViewHelpers.lua`, shared by bags and bank) when sections or `displayOrder` apply, or `H.GetSortedCategoryNames` / `Categories:SortCategories` for fallbacks.
4. **Within-category presentation**: Optional search filter, then `SortButtons` (global `itemSort` and/or per-category `sortMode`), optional `stackItems`, optional `groupBy` sub-rows. All of these features are shared by both bags and bank via the `H.LayoutCategoryContent` pipeline.

---

## End-to-end flow (bags, category view)

1. `CategoryView:Layout` calls `CategoryManager:AssignCategories()`, which walks `BagSet:GetAllButtons()` and sets `button.owb_categoryName = Categories:GetItemCategory(...)` for occupied slots.
2. `CategoryManager:GetItemsByCategory()` buckets buttons by `owb_categoryName`.
3. `H.GetSectionedLayout(itemsByCategory, containerType)` (in `CategoryViewHelpers.lua`) produces either a flat sorted name list or a structured list of entries (`separator`, `section_header`, `category`).
4. `H.PinSpecialCategories` may move **"Recent Items"** to the top and **"Other"** to the bottom using `db.global.moveRecentToTop` and `moveOtherToBottom`.
5. `H.LayoutCategoryContent(config)` renders each category: filtered buttons are sorted, optionally stacked, and optionally split into subgroup grids.

---

## `GetItemCategory` pipeline

Resolution order (each step returns immediately when matched; later steps are skipped):

| Step | Condition | Result |
|------|-----------|--------|
| 0 | Missing `itemInfo` | `"Other"` |
| 1 | **Manual pin** — item ID found in `customCategoriesV2[*].items` or `categoryModifications[*].addedItems`, filtered by `appliesIn[containerType]` | Resolved name (see below) |
| 2 | **1W Junk** — `enableJunkCategory` **and** category not in `disabledCategories` **and** `appliesIn` check **and** `PredicateEngine` `props.isJunk` | `"1W Junk"` |
| 3 | **1W Upgrades** — `itemID` **and** `hyperlink` **and** `enableUpgradeCategory` **and** category not in `disabledCategories` **and** `appliesIn` check **and** `props.isUpgrade` | `"1W Upgrades"` |
| 4 | **Recent Items** — `"Recent Items"` not in `disabledCategories` **and** `appliesIn` check **and** `SlotMatchesRecent` (GUID map + `recentItemDuration`) | `"Recent Items"` |
| 5 | No **hyperlink** on the item | `"Other"` (classification skipped) |
| 6 | **Category cache** hit — `categoryCache[cacheKey]` exists | Cached string |
| 7 | **Merged candidate pool** — collect all matching custom predicate categories AND builtin search categories, filter by `appliesIn[containerType]`; `PickBestCandidate` picks one winner | Best name, or `"Other"` if none match |
| 8 | **Inventory slots** — result is `"Weapons"` or `"Armor"` **and** `enableInventorySlots` **and** slot name passes `appliesIn` check | Localized equip-slot category name (e.g. `_G["INVTYPE_HEAD"]`) |
| 9 | Result name is in **`disabledCategories`** | `"Other"` |
| 10 | — | Store in `categoryCache` when `cacheKey`, `hyperlink`, and `props.classID` all exist |

**Key detail — steps 1–4 bypass steps 7–9.** Manual pins, 1W Junk, 1W Upgrades, and Recent Items all return early. They are never remapped by inventory-slot logic or the disabled fallback. Step 9 only catches candidate-pool-derived names that happen to be disabled.

**`containerType` resolution:** At the top of `GetItemCategory`, `BagTypes:GetContainerType(bagID)` resolves the container type (`"backpack"`, `"character_bank"`, or `"warband_bank"`). This is used throughout the pipeline by `CategoryAppliesTo` to filter categories that don't apply to the current container. "Other" and "Empty" are always exempt from `appliesIn` filtering.

### Step 0: Missing `itemInfo`

If `itemInfo` is nil, the function returns `"Other"` immediately. No further processing occurs.

### Step 1: Manual assignment (`ResolveManualCategoryName`)

**No PredicateEngine on this path.** Candidates come from two sources:

- `customCategoriesV2[*].items` — manual pins on custom categories. Each candidate gets `tieKey = "c:" .. categoryId`.
- `categoryModifications[builtinName].addedItems` — manual pins into a built-in category. Each candidate gets `tieKey = "b:" .. catName`.

After collecting candidates, they are filtered by `CategoryAppliesTo(name, containerType, catMods)` — candidates whose category has `appliesIn[containerType] == false` are removed. If no candidates remain, the step returns nil.

**`pinnedCategoryShowsWhenDisabled` behavior:**

- If **false**: candidates whose category name is in `disabledCategories` are removed before tie-breaking. If no candidates remain, the step returns nil and the item falls through to later stages (Junk, Upgrades, Recent Items, etc.).
- If **true**: disabled categories are kept. A pinned item always wins assignment to its disabled category. The category will still appear in the bag layout (with items) via `GetSectionedLayout`'s visibility logic.

**Legacy saves:** An item ID can appear in multiple pin tables simultaneously. `CollectManualCategoryCandidates` collects all matches, then `PickBestCandidate` picks one winner.

### Step 2: 1W Junk

Gated by `db.global.enableJunkCategory` (separate toggle, default `true`) AND `"1W Junk"` not in `disabledCategories` AND `CategoryAppliesTo("1W Junk", containerType, catMods)`. If all pass, calls `PE:BuildProps(itemID, bagID, slotID, itemInfo).isJunk`. The `isJunk` prop is true when item quality is Poor, or when `OneWoW.ItemStatus:IsItemJunk(itemID)` returns true (cross-addon junk hook).

### Step 3: 1W Upgrades

Requires **both** `itemID` and `hyperlink` (items without a hyperlink skip this step entirely). Gated by `db.global.enableUpgradeCategory` (separate toggle, default `true`) AND `"1W Upgrades"` not in `disabledCategories` AND `CategoryAppliesTo("1W Upgrades", containerType, catMods)`. If all pass, calls `PE:BuildProps(...).isUpgrade`. The `isUpgrade` prop delegates to `OneWoW.UpgradeDetection:CheckItemUpgrade(hyperlink, itemLocation)`.

### Step 4: Recent Items

Gated by `disabledCategories` (no separate enable toggle) AND `CategoryAppliesTo("Recent Items", containerType, catMods)`. Calls `SlotMatchesRecent(itemID, bagID, slotID, itemInfo)`, which checks the item's GUID against the `recentItems` timestamp map. An item is "recent" if `time() - recentItems[guid] < recentItemDuration` (default 120 seconds, configurable 15–600). Expired entries are cleaned on access.

The `#recent` keyword in PredicateEngine delegates to `Categories:SlotMatchesRecent`, so search expressions like `#recent` work in custom categories or the search bar.

Recent Items comes before the merged candidate pool so that recently acquired non-junk, non-upgrade items surface temporarily regardless of what custom or builtin category they would normally fall into.

### Step 5: No hyperlink

If the item has no hyperlink (e.g. data not yet loaded), classification is impossible. Returns `"Other"`.

### Step 6: Category cache

Keyed by `PE:GetItemCacheKey(itemID, bagID, slotID, hyperlink)`. If a cached result exists, returns it immediately. The cache stores results from the merged candidate pool (steps 7–9) only — manual pins, Junk, Upgrades, and Recent Items bypass the cache entirely.

### Step 7: Merged candidate pool (custom predicates + builtin search)

Custom predicate categories and builtin search categories are collected into a **single candidate pool**. `PickBestCandidate` selects one winner using the unified tie-breaking chain (see below).

**Custom predicate candidates** — iterates all `customCategoriesV2` entries where `categoryData.enabled ~= false`. The `filterMode` is resolved via `InferFilterMode`: if `filterMode` is explicitly `"search"` or `"type"`, that mode is used; if `nil` (legacy data), it is inferred as `"search"` when `searchExpression` is non-empty, otherwise `"type"`. Only one matching path fires per category entry:

- **Search path** — calls `PE:CheckItem(searchExpression, ...)`.
- **Type/subtype path** — matches via `C_Item.GetItemClassInfo` / `GetItemSubClassInfo` (case-insensitive). When both type and subtype are set, `typeMatchMode == "or"` means OR; otherwise AND.

Custom candidates carry `isCustom = true`.

**Builtin search candidates** — iterates `SEARCH_CATEGORIES` (all `CATEGORY_DEFINITIONS` entries that have both `search` and `searchOrder`). For each non-disabled definition, calls `PE:CheckItem(def.search, ...)`. Builtin candidates carry `isCustom = false`, `defaultOrder = def.priority`, and `searchOrder = def.searchOrder`.

Candidates whose name is in `disabledCategories` are excluded before entering the pool.

**Explicit `items` pin lists are NOT checked here** — those are handled in step 1.

If no candidates match, result is `"Other"`.

### Step 8: Inventory slot remap

If `db.global.enableInventorySlots` is true and the result from step 7 is `"Weapons"` or `"Armor"`, the item's `equipLoc` is resolved to a localized slot name via `GetSlotCategoryName`. Robe/chest and ranged variants are normalized (`INVTYPE_ROBE` → `INVTYPE_CHEST`, `INVTYPE_RANGEDRIGHT` → `INVTYPE_RANGED`).

### Step 9: Disabled fallback

If the final category name (after optional slot remap) is in `disabledCategories`, it becomes `"Other"`. This only affects candidate-pool-derived names — steps 1–4 all return early and bypass this check.

### Step 10: Cache write

Stores the result in `categoryCache` when all three conditions are met: `cacheKey` exists, `hyperlink` exists, and `props.classID ~= nil`.

---

## Tie-breaking (`PickBestCandidate` / `CandidateBeats`)

`PickBestCandidate(cands, db, g)` iterates all candidates and returns the one that beats all others via `CandidateBeats`. The comparison chain:

| Tier | Criterion | Direction | Notes |
|------|-----------|-----------|-------|
| 1 | `ModPriority(db, name)` | **Higher** wins | `categoryModifications[name].priority` or 0. This is the user-facing "Priority" setting (Lowest through Max). |
| 2 | `isCustom` | Custom wins | When user-facing priorities are equal, a custom category beats a builtin. |
| 3 | `defaultOrder` | **Lower** wins | From `CATEGORY_DEFINITIONS .priority` via the candidate's `defaultOrder` field; absent = 9999. Only relevant when two builtins tie on user priority. |
| 4 | `SectionOrderIndexForCategory(g, name)` | **Lower** wins | First section in `sectionOrder` containing the name; unsectioned = `#sectionOrder + 1` |
| 5 | `searchOrder` | **Lower** wins | From `CATEGORY_DEFINITIONS`; absent = 9999 |
| 6 | `tieKey` (or `name` if no tieKey) | **Lower** wins | String comparison; custom candidates use `customCategoriesV2` entry ID, builtins use their category name |

**Where this applies:**

- **Manual pins (step 1):** Candidates have no `isCustom` or `defaultOrder` fields — tiers 2–3 are skipped (both nil). Tie-breaking: user priority → section order → tieKey (`"c:"` prefix for custom pins, `"b:"` prefix for builtin pins).
- **Merged pool (step 7):** Full 6-tier chain. A custom category with the same user-facing priority as a builtin wins (tier 2). A builtin with a higher user-facing priority wins over any custom category (tier 1).

---

## Priority terminology (two distinct concepts)

1. **User-facing priority** (`categoryModifications[name].priority`) — the "Priority" button in the category manager GUI (Lowest = -2, Low = -1, Normal = 0, High = 1, Higher = 2, Max = 3). Two uses:
   - **Assignment tie-breaking** (tier 1 of `CandidateBeats`): only `mod.priority` is compared; **higher** value wins.
   - **Category row sorting** (`SortCategories`, priority mode): effective order = `defaultOrder + mod.priority`; **lower** total wins.

2. **Default order** (`CATEGORY_DEFINITIONS[*].priority`, stored in `CATEGORY_DEFAULT_ORDER`) — an internal numeric value (1–99) controlling where builtin categories appear by default in the header sort order. Exposed as `Categories:GetCategoryDefaultOrder(name)` (unknown names → **50**). Not directly visible to users, but indirectly affects header positioning.

**`searchOrder`** — among matching builtins, **lower** `searchOrder` wins when all higher tiers tie.

**Section order** (`SectionOrderIndexForCategory`): scans `db.global.sectionOrder` and `categorySections[sid].categories` for the first section containing the category; **lower section index wins** when priorities tie. Categories not in any section get `#sectionOrder + 1`.

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
| Reagents | 11 | `#reagent` | 11 |
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

**"1W Junk"**, **"1W Upgrades"**, and **"Recent Items"** have no `search`/`searchOrder` — they are handled by dedicated steps (2, 3, 4) in the pipeline, not the merged candidate pool.

**"Empty"** appears in definitions and default `displayOrder` for import/ordering. **`GetItemCategory` never returns `"Empty"`** for an item. Empty slots are handled by list/bag views and `showEmptySlots`, not this classifier.

**"Other"** has no search expression — it is the implicit fallback when nothing else matches.

**`SEARCH_CATEGORIES`** is the subset of `CATEGORY_DEFINITIONS` that have both `search` and `searchOrder`, sorted by `searchOrder` ascending. This is the table iterated in step 7's builtin collection.

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
- **Per-category override**: `categoryModifications[categoryName].sortMode`. In both `CategoryView` and `BankCategoryView`, if set, it is passed as the override argument to `sortButtons`. Mode **`none`** leaves order unchanged (typically bag/slot from the pool).

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

Search strings use its expression language (`#keyword`, operators, etc.). `BuildProps` enriches items; `CheckItem(expr, ...)` evaluates membership. Both custom `searchExpression` categories and builtin search categories use this engine.

**Bags-specific registration:** The `#recent` keyword is registered by `Data/Categories.lua` to delegate to `Categories:SlotMatchesRecent` (GUID map + duration are Bags-owned). `#catalyst` / `#catalystupgrade` are now registered by the engine itself and silently no-op when TransmogUpgradeMaster is absent.

---

## Overrides and persisted data (summary)

| Mechanism | Role |
|-----------|------|
| `customCategoriesV2` | Custom categories: `items`, `searchExpression`, `itemType` / `itemSubType`, `filterMode`, `typeMatchMode`, `enabled`, `sortOrder`, `isTSM`, etc. |
| `categoryModifications[name]` | `sortMode`, `groupBy`, `priority`, `color`, `appliesIn`, `addedItems` |
| `disabledCategories` | Disable builtin/custom by name; classification remaps to **Other** when applicable |
| `enableJunkCategory` | Separate toggle for step 2 (default `true`); disabling skips the 1W Junk check entirely |
| `enableUpgradeCategory` | Separate toggle for step 3 (default `true`); disabling skips the 1W Upgrades check entirely |
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
| Per-category `sortMode` | Yes | Yes |
| Per-category `groupBy` | Yes | Yes |
| `stackItems` | Yes | Yes |
| `appliesIn` filtering | Yes (at assignment + layout) | Yes (at assignment + layout) |
| Section header visibility | `showHeader` | `showHeaderBank` (falls back to `showHeader`) |
| Compact mode | `compactCategories` / `compactGap` | `bankCompactCategories` / `bankCompactGap` |

---

## Integrations

- **TSM** (`Integrations/TSMIntegration.lua`): Creates `customCategoriesV2` entries with `"TSM: "` prefixed names, `items` maps, and `isTSM = true`. These behave like manual-pin custom categories for assignment (step 1, not step 7).
- **Baganator** (`Controllers/CategoryController.lua`): `BAGANATOR_CAT_MAP` maps external keys to builtin names (including `"Empty"` for ordering/import). Does not change `GetItemCategory` logic for `"Empty"`.

---

## Cache and invalidation

- **Category cache** (`Categories.lua`): keyed by `PredicateEngine:GetItemCacheKey(...)`; stores resolved classification for items with hyperlink and props. Only caches results from the merged candidate pool (steps 7–10). Steps 1–4 bypass the cache.
- **`Categories:InvalidateCache`** and **`OneWoW_Bags:InvalidateCategorization`**: refresh custom categories, recent settings, clear caches; PredicateEngine invalidation per scope. See `Docs/ARCHITECTURE.md`.

---

## Related files

| File | Responsibility |
|------|------------------|
| `Data/Categories.lua` | Assignment, `SortCategories`, manual/custom/builtin helpers, cache, `appliesIn` filtering at classification time |
| `Modules/CategoryManager.lua` | Bag assignment (`AssignCategories`), bucketing (`GetItemsByCategory`) |
| `Views/CategoryViewHelpers.lua` | Shared layout pipeline: `GetSortedCategoryNames`, `GetSectionedLayout`, grouping, stacking, filtering, `LayoutCategoryContent`, grids, compact layout, `PinSpecialCategories` |
| `Views/CategoryView.lua` | Bags category view (thin wrapper over shared pipeline) |
| `Views/BankCategoryView.lua` | Bank category view (thin wrapper over shared pipeline) |
| `Data/Sorting.lua` | `SortButtons` |
| `OneWoW_GUI/PredicateEngine.lua` | Shared expression engine and item props (see [`PREDICATE_ENGINE.md`](../../OneWoW_GUI/Docs/PREDICATE_ENGINE.md)) |
| `Core/SectionDefaults.lua` | Section IDs, builtin ordering, OneWoW Bags section sync |
| `Controllers/CategoryController.lua` | CRUD, import maps, UI refresh orchestration, `appliesIn` / `showHeaderBank` setters |
