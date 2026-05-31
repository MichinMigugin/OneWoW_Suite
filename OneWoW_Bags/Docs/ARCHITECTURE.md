# OneWoW_Bags — Architecture

## Overview

OneWoW_Bags is a unified bag/bank/guild bank replacement addon for World of Warcraft. It replaces consolidated Blizzard bag presentation with a single window per context (inventory, bank, guild bank). The addon is part of the OneWoW Suite and depends on `OneWoW_GUI` for UI primitives, database management, and theming.

**SavedVariable:** `OneWoW_Bags_DB`, initialized via `OneWoW_GUI.DB:Init` in **single** mode (defaults and persisted data under `db.global`).

**TOC:** `## Interface: 120005, 120007` (Retail + compatible build).

**Hard dependency:** `OneWoW_GUI` (`RequiredDeps` in the TOC).

**Optional hub / integrations:** `OneWoW` (minimap hub, `UpgradeDetection`, `OverlayEngine`, `ItemStatus` junk hook, etc.—features degrade gracefully when absent). Also `OneWoW_AltTracker`, `OneWoW_ShoppingList`, `TradeSkillMaster`, `Baganator` (profile import via `CategoryController`), `Masque` (`OptionalDeps` in the TOC).

---

## File Tree & Load Order

The TOC loads files in this exact sequence. **Order matters**—each layer builds on the one before it.

```
Locales\enUS.lua
Locales\esES.lua
Locales\koKR.lua
Locales\frFR.lua
Locales\ruRU.lua
Locales\deDE.lua

Core\Profile.lua                   ← optional hot-path profiler (/owbprof); used by Categories, Bag/Bank sets, ItemButton
Core\Constants.lua                 ← OneWoW_GUI:RegisterGUIConstants, icon sizes, GUI metrics
Core\SectionDefaults.lua           ← stable section IDs, builtin lists, OneWoW Bags catch-all section sync
Core\Database.lua                  ← DB:Init, defaults, migrations
Core\BagTypes.lua                  ← bag ID constants, reagent/player bag helpers
Core\BankTypes.lua                 ← bank/warband tab constants
Core\Events.lua                    ← event router (dirtyBags, RuntimeEvents)

Data\SavedSearches.lua             ← user-defined SAVED(Name) search shortcuts
Data\Sorting.lua                   ← item sort comparators (SortButtons)
Data\Categories.lua                ← builtin category defs, classification engine (consumes OneWoW_GUI.PredicateEngine)
Data\BaganatorDefaultMap.lua       ← Baganator default category name map

Modules\ItemPool.lua               ← frame object pool (ItemButton recycling)
Modules\ItemButton.lua             ← ItemButtonMixin + ApplyItemButtonMixin
Modules\BagSet.lua                 ← player inventory slot management
Modules\BankSet.lua                ← personal + warband bank slots
Modules\GuildBankSet.lua           ← guild bank tab/slot management + cache
Modules\CategoryManagerBase.lua    ← section/divider/header frame pool factory
Modules\CategoryManager.lua        ← bags: category assignment + bucketing
Modules\BankCategoryManager.lua    ← bank: CategoryManagerBase instance (section pools)
Modules\GuildBankCategoryManager.lua

ImportExport\Serializer.lua        ← native category/section bundle encode/decode
ImportExport\Backup.lua            ← pre-import snapshot / undo storage
ImportExport\SyntaxTranslators\Registry.lua
ImportExport\SyntaxTranslators\SyndicatorLocaleMap.lua
ImportExport\SyntaxTranslators\Syndicator.lua
ImportExport\Planner.lua           ← import preview plan builder
ImportExport\Applier.lua           ← import plan applier

Integrations\OneWoWBagsIntegration.lua  ← item-button callback hooks, overlay hooks
Integrations\OneWoWTooltips.lua         ← keyword help tooltip integration
Integrations\TSMIntegration.lua         ← TSM group import
Integrations\BaganatorImport.lua        ← Baganator profile reader/parser
Integrations\Masque.lua                 ← optional Masque skinning for item icons

Controllers\WindowLayoutController.lua  ← generic layout orchestrator
Controllers\BagsController.lua
Controllers\BankController.lua
Controllers\GuildBankController.lua
Controllers\SettingsController.lua      ← setting write + side-effects + debounce
Controllers\CategoryController.lua      ← category/section CRUD, manual pin rules, Baganator import

Views\ListView.lua                 ← flat grid layout strategy
Views\CategoryViewHelpers.lua      ← shared layout pipeline: GetSectionedLayout, grouping, stacking, render dispatch
Views\CategoryView.lua             ← bags category view (thin wrapper over shared pipeline)
Views\BagView.lua                  ← per-bag sections layout strategy
Views\BankCategoryView.lua         ← bank category view (thin wrapper over shared pipeline)
Views\BankTabView.lua              ← bank per-tab layout
Views\GuildBankTabView.lua         ← guild bank per-tab layout

GUI\WindowHelpers.lua              ← window shell, scroll scaffold, filtering helpers
GUI\InfoBarFactory.lua             ← shared info bar builder (search history, saved search button, view dropdowns)
GUI\InfoBar.lua                    ← bags top bar configuration (view mode dropdown, search, expansion filter)
GUI\BagsBar.lua                    ← bags bottom bar (bag icons, gold, trackers)
GUI\BankInfoBar.lua
GUI\BarHelpers.lua                 ← shared bank/guild bank bar chrome (frame, gold, tab recycling)
GUI\BankBar.lua
GUI\BankWindow.lua
GUI\GuildBankInfoBar.lua
GUI\GuildBankBar.lua
GUI\GuildBankLog.lua               ← transaction log panel (GUILDBANKLOG_UPDATE)
GUI\GuildBankWindow.lua
GUI\ImportPreview.lua              ← import plan preview and conflict resolution
GUI\CategoryManager.lua            ← category management UI panel
GUI\Settings.lua
GUI\MainWindow.lua                 ← inventory main window

OneWoW_Bags.lua                    ← addon entry point, event frame, runtime handlers
```

---

## Architectural Pattern

OneWoW_Bags uses a **layered hybrid MVC** pattern. It is not strict MVC—some orchestration logic lives on the root namespace object—but the separation is intentional and consistent.

### Layer Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                      GUI Layer                               │
│  MainWindow, BankWindow, GuildBankWindow, Settings,          │
│  CategoryManager (UI), InfoBar, BagsBar, BarHelpers,         │
│  BankBar, GuildBankBar, WindowHelpers                        │
│  ─ Creates frames, wires user interactions to controllers    │
│  ─ Delegates layout to Views via WindowLayoutController      │
└────────────────────────────┬─────────────────────────────────┘
                             │ calls
┌────────────────────────────▼─────────────────────────────────┐
│                    Controller Layer                           │
│  BagsController, BankController, GuildBankController,        │
│  SettingsController, CategoryController,                     │
│  WindowLayoutController                                      │
│  ─ Reads/writes db.global                                    │
│  ─ Calls RequestLayoutRefresh / RequestVisualRefresh          │
│  ─ Calls InvalidateCategorization                            │
└────────────────────────────┬─────────────────────────────────┘
                             │ calls
┌────────────────────────────▼─────────────────────────────────┐
│                      View Layer                              │
│  ListView, CategoryView, BagView, BankCategoryView,          │
│  BankTabView, GuildBankTabView                               │
│  CategoryViewHelpers — grids, compact bins, labels (shared)  │
│  ─ Layout: receives buttons + width, returns height          │
│  ─ Uses viewContext for sort, sections, collapse state        │
└────────────────────────────┬─────────────────────────────────┘
                             │ reads
┌────────────────────────────▼─────────────────────────────────┐
│                     Module Layer                             │
│  BagSet, BankSet, GuildBankSet (slot management)             │
│  ItemPool (frame recycling), ItemButton (mixin)              │
│  CategoryManager (bags assignment + layout metadata)         │
│  CategoryManagerBase, BankCategoryManager,                   │
│  GuildBankCategoryManager (section pools)                    │
└────────────────────────────┬─────────────────────────────────┘
                             │ reads
┌────────────────────────────▼─────────────────────────────────┐
│                      Data Layer                              │
│  SavedSearches, Categories, Sorting, BagTypes, BankTypes     │
│  ─ Search shortcuts, classification, sort comparators        │
│  ─ Categories uses OneWoW_GUI.PredicateEngine for search     │
└────────────────────────────┬─────────────────────────────────┘
                             │ reads
┌────────────────────────────▼─────────────────────────────────┐
│                      Core Layer                              │
│  Database (DB:Init, defaults, migrations)                    │
│  Events (event routing table, dirtyBags accumulator)         │
│  Constants (GUI metrics, icon sizes)                         │
│  Profile (optional /owbprof timings)                         │
│  SectionDefaults (section IDs, builtin ordering, OWB section)  │
└──────────────────────────────────────────────────────────────┘
```

### The Root Namespace Object

`OneWoW_Bags` (the second vararg from `local _, OneWoW_Bags = ...`) is the central orchestration hub. All layers attach their tables to it, and it is also exposed as `_G["OneWoW_Bags"]` for cross-addon access.

The root object provides:

- **State flags:** `bankOpen`, `guildBankOpen`, `oneWoWHubActive`, `inventoryPresentationState` (contains `altShowActive`), `activeExpansionFilter` (bags search bar expansion filter), `activeBankExpansionFilter`
- **Lifecycle:** `OnAddonLoaded`, `OnPlayerLogin`, `InitializeControllers`, `InitializeDatabase`
- **Refresh orchestration:** `RequestLayoutRefresh(target)`, `RequestVisualRefresh(target)`, `RequestWindowReset(target)`
- **Cache invalidation:** `InvalidateCategorization(scope)` — refreshes `Categories` from `customCategoriesV2` / `recentItemDuration` / `recentItems`, clears category caches (`categoryCache` + `baseCategoryCache`); if `scope == "props"` then `OneWoW_GUI.PredicateEngine:InvalidatePropsCache()`, else full `OneWoW_GUI.PredicateEngine:InvalidateCache()`. **`InvalidateItemIDs(idSet)`** — surgical eviction after coalesced `GET_ITEM_INFO_RECEIVED` so identity-tier caches survive for unrelated items while streaming completes.
- **Blizzard hooks:** `HookBlizzardBags`, `SuppressBankFrame`, `RestoreBankFrame`, `SuppressGuildBankFrame`, `RestoreGuildBankFrame`
- **Guild bank orchestration:** `RefreshGuildBankContents`, `QueueGuildBankRefresh`, `TrackGuildBankTransferTab`, `TrackGuildBankTransferSource`, `ProcessPendingGuildBankTransferTabs`, `PurgeClearSource`, plus internal coalescing state for cross-tab moves
- **Helpers:** `GetDB`, `GetItemSortMode`, `SortButtons`, `ShouldShowItemQuality`, `ShouldDimJunkItem`, `ShouldStripJunkOverlays`, `EnsureCategoryModification`, `EnsureBuiltinCategoryAddedItems`, `IsAltShowActive`, `SetAltShowActive`, `IsBankUIEnabled`, `ReinitForLanguage`, `ApplyItemButtonMixin`, `HookPetCageTooltip`, `GetMoneyDialog`, `ShowMoneyDialog`, `UpdateSlotsForItemIDs`
- **Shared tables:** `SectionDefaults`, `CategoryViewHelpers`, `BarHelpers` (see Key Components)

---

## Data Flow

### 1. Startup Sequence

```
ADDON_LOADED (this addon)
  └─→ OnAddonLoaded
       ├─→ InitializeDatabase (DB:Init, RunMigrations)
       ├─→ InitializeControllers (WindowLayoutController, *Controller:Create)
       ├─→ OneWoW_GUI:MigrateSettings(db.global)
       ├─→ ApplyTheme, ApplyLanguage
       ├─→ Categories:SetCustomCategories, SetRecentItemDuration, SetRecentItems
       ├─→ RegisterSlashCommands
       ├─→ RegisterRuntimeEvents
       └─→ OneWoW_GUI:RegisterSettingsCallback (theme, language, font, icon, minimap)

PLAYER_LOGIN
  └─→ OnPlayerLogin
       ├─→ DetectOneWoW (hub presence)
       ├─→ Minimap launcher (if no hub) + OneWoW:RegisterMinimap when hub present
       ├─→ ItemPool:Preallocate(220)
       ├─→ BagSet:Build
       ├─→ BagsBar:UpdateIcons
       ├─→ HookBlizzardBags
       └─→ HookPetCageTooltip
```

`Integrations\OneWoWBagsIntegration.lua` registers `ADDON_LOADED` and, after a short delay, wraps `GUI:RefreshLayout`, `BankGUI:RefreshLayout`, and `GuildBankGUI:RefreshLayout` for overlay/callback behavior (see Integration Points).

### 2. Bag Update Pipeline (Primary Data Flow)

```
Game event: BAG_UPDATE (per bag, may repeat same frame)
  └─→ Events:OnBagUpdate(bagID)
       └─→ dirtyBags[bagID] = true

Game event: BAG_UPDATE_DELAYED (once after coalesced updates)
  └─→ Events:OnBagUpdateDelayed
       ├─→ InvalidateCategorization("props")  ← Categories refresh + OneWoW_GUI.PredicateEngine:InvalidatePropsCache
       └─→ OneWoW_Bags:ProcessBagUpdate(dirtyBags)
            ├─→ Categories:OnPlayerBagDirtySnapshot(dirtyBags) (expire GUID map; stamp GUIDs for Blizzard-new slots in player bags)
            ├─→ BagSet:UpdateDirtyBags(dirtyBags)
            │    ├─→ Slot count changed → RebuildBag (release + re-acquire from pool)
            │    ├─→ Else → OWB_MarkDirty on affected buttons
            │    └─→ ProcessDirtySlots → OWB_FullUpdate per dirty button
            │         └─→ C_Container.GetContainerItemInfo → texture, count, quality,
            │            cooldown, new-item glow, junk dim, unusable overlay, lock refresh
            ├─→ GUI:RefreshLayout (if bags window built + shown)
            └─→ BankGUI:RefreshLayout (if bank open, bank set built, window shown)
```

Main bags window visibility ([`GUI:Show`](c:\Users\kelle\Downloads\Projects\OneWoW_Suite\OneWoW_Bags\GUI\MainWindow.lua) / [`GUI:Hide`](c:\Users\kelle\Downloads\Projects\OneWoW_Suite\OneWoW_Bags\GUI\MainWindow.lua) / [`GUI:FullReset`](c:\Users\kelle\Downloads\Projects\OneWoW_Suite\OneWoW_Bags\GUI\MainWindow.lua)):

```
GUI:Show (after init)
  └─→ Categories:BeginRecentExpiryTicker
       └─→ C_Timer.NewTicker(RECENT_EXPIRY_TICK_INTERVAL) while active
            ├─→ If GUI no longer shown → EndRecentExpiryTicker (safety)
            ├─→ CleanExpiredRecent → true if any GUID removed
            └─→ RequestLayoutRefresh("all") when removed

GUI:Hide / GUI:FullReset (start of reset)
  └─→ Categories:EndRecentExpiryTicker → cancel ticker + CleanExpiredRecent
```

Guild bank updates use a separate path: `GUILDBANKBAGSLOTS_CHANGED` and related events → `QueueGuildBankRefresh` (OnUpdate-coalesced) → `RefreshGuildBankContents` → slot cache + `GuildBankGUI:RefreshLayout` when visible.

### 3. Layout Pipeline

`WindowLayoutController:Refresh(config)` runs only when `config.mainWindow` exists **and is shown** and `config.isBuilt()` is true. It:

1. Optionally `updateWindowWidth()` — fixed horizontal width from column count + icon size + scrollbar allowance (`UpdateFixedWidth`).
2. `beforeLayout()` — visibility, scroll anchors (`BindScrollFrame`).
3. Reparents `config.containerFrames` under `config.contentFrame` (bag container frames carry `SetID(bagID)` for secure item buttons).
4. `cleanup()` — hide/clear button anchors, `CategoryManager` / `BankCategoryManager` / `GuildBankCategoryManager`:ReleaseAllSections.
5. `getButtons()` → `filterButtons()` — **window-specific** (see below).
6. `layoutButtons(filteredButtons)` → active View’s `Layout` → content height.
7. `afterLayout()` — free slot counts, etc.

**Per-window filtering:**

| Window | Filter chain (after `getButtons`) |
|--------|-----------------------------------|
| Bags (`GUI:RefreshLayout`) | `WH:FilterBySearch` → `WH:FilterByExpansion` (`activeExpansionFilter`) |
| Bank | `WH:FilterByTab` (`bankSelectedTab`) → `WH:FilterBySearch` → `WH:FilterByExpansion` (`activeBankExpansionFilter`) |
| Guild bank | `WH:FilterByTab` (`guildBankSelectedTab`) → `WH:FilterBySearch` (no expansion filter) |

**Column keys for width and grid metrics:**

- Inventory main window: `db.global.bagColumns` (not the legacy `columns` default key, which is unused by current GUI code).
- Bank window: `db.global.bankColumns` in personal mode, `db.global.warbandBankColumns` in warband mode (selected via `BankController:ActiveKeys().columns`).
- Guild bank window: `db.global.bankColumns`.

### 4. Category Classification Pipeline

**Bags — `CategoryView` only:** at the start of `CategoryView:Layout`, `CategoryManager:AssignCategories()` runs:

```
CategoryManager:AssignCategories()
  └─→ For each BagSet button with an item:
       └─→ Categories:GetItemCategory(bagID, slotID, itemInfo)
```

**`Categories:GetItemCategory`** splits work into a **slot-keyed outer layer** and an **identity-tier base resolver** (`ResolveBaseCategory`). Slot-dependent outcomes are evaluated before the base resolver; identity-tier work (manual pins through builtin/custom predicates) is cached per **item identity + `containerType`** so duplicate stacks in the same container type reuse one verdict.

**Outer layer** (`GetItemCategory`; order matters):

1. **Missing `itemInfo`** → `"Other"`.
2. **Slot-keyed cache** (`categoryCache`, key `PE:GetItemCacheKey(...)`) — stores final results including slot-overlay hits when applicable.
3. **1W Upgrades (slot overlay)** — `OneWoW.UpgradeDetection:CheckItemUpgrade` with `ItemLocation` when available; gated by `enableUpgradeCategory`, `disabledCategories`, `CategoryAppliesTo`, and `OneWoW` presence. Runs **before** Recent Items so an upgrade wins over a recent classification on the same slot.
4. **Recent Items (slot overlay)** — `SlotMatchesRecent`; gated by `disabledCategories` + `CategoryAppliesTo`.
5. **`ResolveBaseCategory(...)`** — see below. Writes through to slot cache only when the verdict is **not tentative** (full item data + tooltip resolution succeeded).

**`ResolveBaseCategory`** (identity tier; manual pins through builtin/custom pool):

1. **Manual pins** — `customCategoriesV2[*].items` and `categoryModifications[*].addedItems` (no PredicateEngine). Same `pinnedCategoryShowsWhenDisabled` and `PickBestCandidate` rules as before; filtered by `CategoryAppliesTo` for `containerType`.
2. **1W Junk** — `PE:BuildProps(...).isJunk`; gated by `enableJunkCategory` + `disabledCategories` + `CategoryAppliesTo`.
3. **No hyperlink** → `"Other"` (cannot run predicate pool meaningfully).
4. **Streaming deferral** — if `not C_Item.IsItemDataCachedByID(itemID)`, requests load and returns **`"Other", tentative=true`** so nothing is cached until `GET_ITEM_INFO_RECEIVED` + refresh (sets `OneWoW_Bags._hasPendingTentatives`).
5. **`baseCategoryCache` hit** — key `PE:GetItemIdentityKey(...) .. "|" .. containerType` — reuse merged-pool result for the same identity in the same container type.
6. **`PE:BuildProps` + merged candidate pool** — `CollectCustomPredicateCandidates` + all `SEARCH_CATEGORIES` entries; `PickBestCandidate` (priority → custom beats builtin → `defaultOrder` → section index → list order → `searchOrder` → name). Builtin candidates filtered by `disabledCategories` before evaluation; pool then filtered by `CategoryAppliesTo`.
7. **Inventory slots** — if result is `Weapons` or `Armor` and `enableInventorySlots`, remap to localized equip-slot name when allowed by `CategoryAppliesTo`.
8. **Disabled fallback** — candidate-pool-derived names only; manual/Junk still return early.
9. **Tooltip tentative** — if props recorded `_tooltipDataMissing`, return category but **`tentative=true`** so slot cache is not poisoned during cold tooltip/streaming.
10. **`baseCategoryCache` write** on successful non-tentative resolution.

**Important:** Slot overlays (**Upgrades**, **Recent**) live only in `GetItemCategory`; they **never** populate `baseCategoryCache`. Manual pins, Junk, and merged-pool results **do** use `baseCategoryCache` for reuse across slots with the same identity.

**`Categories:FindManualPinForItem(itemID)`** — returns `{ kind, categoryId | categoryName, displayName }` or `nil`; used for **single-pin enforcement** when adding items (see `CategoryController`).

**`H.GetSectionedLayout(itemsByCategory, containerType)`** (in `CategoryViewHelpers.lua`)

- `IsCategoryVisible` hides a category when `disabledCategories[catName]` is set **unless** `pinnedCategoryShowsWhenDisabled` is on **and** that category has items in `itemsByCategory` (so pinned rows can still appear for disabled categories).
- Applies `categoryModifications.appliesIn[containerType]` — categories with `appliesIn[containerType] == false` are excluded. "Other" and "Empty" are always exempt.
- Section header visibility is resolved per-container: bags use `showHeader`, bank uses `showHeaderBank` (falls back to `showHeader` when nil).
- When `displayOrder` / section graph is empty, falls back to `H.GetSortedCategoryNames`; otherwise builds from `displayOrder`, `categorySections`, `sectionOrder`, optional equip-slot names when inventory slots are enabled.
- Shared by both `CategoryView` (bags) and `BankCategoryView` (bank).

**Bank — `BankCategoryView`:** walks `BankSet:GetAllButtons()`, calls `Categories:GetItemCategory` per occupied slot (which filters by `appliesIn` at assignment time), groups into `itemsByCategory`, then calls `H.GetSectionedLayout` + `H.LayoutCategoryContent` with bank settings. `BankCategoryManager` supplies **section frames only** via `viewContext`.

**List / tab views:** no `AssignCategories`; sort order comes from `viewContext.sortButtons` → `SortButtons`.

### 5. Search Pipeline

Search uses `OneWoW_GUI.PredicateEngine` (tokenizer, AST, evaluation). For full engine internals and public API, see [`OneWoW_GUI/Docs/PREDICATE_ENGINE.md`](../../OneWoW_GUI/Docs/PREDICATE_ENGINE.md).

- Keywords, properties, operators (`&` `|` `!`), parentheses, bare name text
- `SAVED(Name)` shortcuts are expanded by `Data\SavedSearches.lua` before PredicateEngine evaluation. Saved searches are stored as `db.global.savedSearches[displayName] = predicate`.
- `#recent` is registered at `Data\Categories.lua` load via `PE:RegisterKeyword` (Bags-only): GUID map + duration only. `#new` / `IsNew` in the engine use `C_NewItems` via `BuildProps` (can lag until `InvalidatePropsCache`); `#recent` does not use that cached flag for classification
- `#catalyst` / `#catalystupgrade` are registered by the engine itself with call-time `TransmogUpgradeMaster_API` checks (no-op if the addon is absent)
- `WH:FilterBySearch` expands saved searches, then compiles the expression once per refresh and evaluates per button via `PE:CheckItem`
- Search history is UI-owned by `InfoBarFactory` on every container search box; stored in `db.global.searchHistory` up to `db.global.searchHistoryLimit` (Settings → General → Search; `0` disables the focus dropdown).
- Save-search button (`savedSearches = true`) on bags, personal/warband bank, and guild bank info bars; popups register once at `InfoBarFactory` load with query passed via `StaticPopup` data; writes to global `savedSearches`. Manage names in Settings → General → Search (not Bags).

```
InfoBar / BankInfoBar / GuildBankInfoBar: search changed
  └─→ *Controller:OnSearchChanged → *GUI:RefreshLayout
       └─→ filterButtons → WH:FilterBySearch
            ├─→ SavedSearches:Expand(expr)
            └─→ PE:CheckItem(expandedExpr, itemID, bagID, slotID, info)
                 ├─→ Compile(expandedExpr) → cached AST
                 ├─→ BuildProps(...) → cached props (+ tooltip laziness inside props)
                 └─→ Evaluate AST → true/false
```

Expansion filtering for bags/bank uses `WindowHelpers:ResolveExpansionID` (engine expansion helpers under the hood), not the same code path as the search box unless the user types expansion predicates.

### 6. Settings Pipeline

All settings writes go through `SettingsController:Apply`:

```
Settings UI interaction
  └─→ SettingsController:Apply(settingKey, value)
       └─→ appliers[settingKey](self, db, value)
            ├─→ Writes db.global[key] = value
            └─→ Triggers appropriate refresh:
                 ├─→ RequestLayoutRefresh
                 ├─→ RequestVisualRefresh (also re-layouts the same target in current code)
                 ├─→ RequestWindowReset
                 └─→ InvalidateCategorization (full cache, not props-only)
```

Layout-affecting numeric settings (e.g. `bagColumns`) use `SettingsController:Debounce` to reduce thrash.

**Category placement:** `pinnedCategoryShowsWhenDisabled` (General → Category Placement) runs applier `pinnedCategoryShowsWhenDisabled`: `InvalidateCategorization`, `RequestLayoutRefresh("all")`, and `CategoryManagerUI:Refresh` when present (same class of side effects as junk/upgrade category toggles).

---

## Key Components In Detail

### SectionDefaults (`Core\SectionDefaults.lua`)

Stable section IDs (`SEC_ONEWOW_BAGS`, `SEC_EQUIPMENT`, `SEC_CRAFTING`, `SEC_HOUSING`), default member lists per section, and `BUILTIN_SORT_PRIORITY` for ordering. `BuildOnewowMembers` / `SyncOnewowSectionCategories` maintain the **OneWoW Bags** catch-all section: builtins and custom categories not assigned elsewhere, sorted per saved `categoryOrder` or builtin priority. Used by `CategoryController`, category UI (`GUI\CategoryManager.lua`), and migrations (v3+ and v10+).

### CategoryViewHelpers (`Views\CategoryViewHelpers.lua`)

Shared by `CategoryView` and `BankCategoryView`. Contains the full shared layout pipeline:

- `H.GetSortedCategoryNames` / `H.GetSectionedLayout` — section/display-order resolution, `appliesIn` container filtering, per-container section header visibility (`showHeader` for bags, `showHeaderBank` for bank with fallback to `showHeader` when nil)
- Grouping functions: `GroupItemsByExpansion`, `GroupItemsByType`, `GroupItemsBySlot`, `GroupItemsByQuality`
- `StackItems` / `RestoreItemButtonCounts` — item stacking logic
- `FilterItems` — per-category search filter evaluation
- `H.LayoutCategoryContent(config)` — unified entry point for the full render dispatch (sort, stack, group, grid/compact)
- Label/header object pools, localized category titles, `RenderItemGrid`, compact multi-category line packing (`LayoutCompactGroup`), `PinSpecialCategories` for Recent/Other placement

### BarHelpers (`GUI\BarHelpers.lua`)

Shared bottom-bar construction for `BankBar` and `GuildBankBar`: themed bar frame, gold + free-slot font strings, tab button recycling helpers.

### Profile (`Core\Profile.lua`)

Optional sampling profiler toggled with **`/owbprof`** (`on` / `off` / `reset` / `dump`). Used by `Categories:GetItemCategory`, `ResolveBaseCategory`, `BankSet`/`BagSet` hot paths, and `ItemButton:OWB_FullUpdate`. Disabled by default (zero overhead).

### ItemPool

Acquire/release pool for `ContainerFrameItemButtonTemplate` buttons. `Preallocate(220)` at login. `OneWoW_GUI:SkinIconFrame` during creation; mixin applied when bound in `BagSet` / `BankSet` / `GuildBankSet`.

### ItemButtonMixin (`Modules\ItemButton.lua`)

Applied with `OneWoW_Bags:ApplyItemButtonMixin` (copies `OneWoW_Bags.ItemButtonMixin` methods onto the button once).

- `OWB_SetSlot`, `OWB_MarkDirty`, `OWB_IsDirty`, `OWB_FullUpdate`
- `OWB_UpdateNewItemGlow` — player bags only (`BagTypes:IsPlayerBag`); uses `OneWoW_GUI.PredicateEngine:BuildProps(...).isNew` + template overlays; respects Masque (`Integrations\Masque.lua`) for border/glow ownership when Masque is active
- `OWB_UpdateJunkDim`, `OWB_UpdateUnusableOverlay` — junk from `BuildProps(...).isJunk`
- `OWB_RefreshCooldown`, `OWB_RefreshLock`, `OWB_SetIconSize`, `OWB_GetLink`

Per-button state includes `owb_bagID`, `owb_slotID`, `owb_itemInfo`, `owb_hasItem`, `owb_categoryName` (when categorized), `owb_isBank`, `owb_isGuildBank`, and internal junk/overlay flags.

### BagSet / BankSet / GuildBankSet

- `Build()` / `ReleaseAll()`, `UpdateDirtyBags` (bags + bank), `GetAllButtons`, `GetFreeSlotCount`, etc.
- `bagContainerFrames[bagID]` — parent frames with `SetID(bagID)` for secure behavior on container template buttons.
- **Bags:** `Ctrl+Right-click` on a bag item while the personal/warband bank is open delegates to `BankController:DepositBagButtonStack`. If "Stack identical items" produced a virtual stack, every underlying physical player-bag slot is queued. Each queued slot is revalidated and paced before `C_Container.UseContainerItem(..., bankType)` deposits into the active bank type.
- **Search transfer (bags ↔ personal/warband bank):** Info bar icons (`Banker` on bags, `hud-backpack` on bank) call `BankController:TransferSearchToBank` / `TransferSearchFromBank` using the same filters as the bags window (`WH:FilterBySearch` + `WH:FilterByExpansion`). Deposit `selectedBag` scope applies only in **bag** view mode (matches `BagView`); list/category deposit from all player bags. Withdraw scope respects `bankSelectedTab` / `warbandBankSelectedTab` when set (matches bank layout filters). Paced queues share `DEPOSIT_INTERVAL_SEC`. Guild bank excluded (different move API).
- **Guild bank:** tab/slot cache, `ApplyCacheToButtons`, money-cursor and guild-bank-specific scripts, `ClearCache` on close; fixed slot count per tab (98).

### CategoryManagerBase

`Create()` returns an instance with section/header/divider pools. Three module-level instances:

- `OneWoW_Bags.CategoryManager` — extends base with bags assignment + bucketing (`AssignCategories`, `GetItemsByCategory`)
- `OneWoW_Bags.BankCategoryManager`
- `OneWoW_Bags.GuildBankCategoryManager`

### CategoryManager (module)

- `AssignCategories` — **inventory BagSet only** (used from `CategoryView`).
- `GetItemsByCategory` — buckets assigned buttons by `owb_categoryName`.

Layout functions (`GetSortedCategoryNames`, `GetSectionedLayout`) live in `CategoryViewHelpers` and are shared by both bags and bank views.

**Naming:** not the same as `GUI\CategoryManager.lua` (category editor UI).

### Views

Each view exposes `Layout(...)` and returns total content height.

**ListView** — Grid with optional reagent-bag segment after normal bags. Computes column count from **content width** and icon spacing when not overridden by bag/category views. Honors per-container empty-slot settings via `viewContext.showEmptySlots` (`showEmptySlots` bags, `bankShowEmptySlots`, `warbandBankShowEmptySlots`, `guildBankShowEmptySlots`; List and Tab views only).

**CategoryView** — Thin wrapper: runs `CategoryManager:AssignCategories()` + `:GetItemsByCategory()`, then calls `H.GetSectionedLayout` and `H.LayoutCategoryContent` from the shared pipeline with bag-specific settings.

**BagView** — One section per physical bag; `selectedBag` filter.

**BankCategoryView** — Thin wrapper: builds `itemsByCategory` from `BankSet` via inline `Categories:GetItemCategory`, then calls `H.GetSectionedLayout` and `H.LayoutCategoryContent` from the shared pipeline with bank-specific settings.

**BankTabView** — Sections per bank tab; mode-aware selected tab (personal: `bankSelectedTab`, warband: `warbandBankSelectedTab`) and mode-aware columns (personal: `bankColumns`, warband: `warbandBankColumns`). Both read via `BankController:Get("selectedTab"/"columns")`. Respects warband vs character via `bankShowWarband`.

**GuildBankTabView** — Sections per guild tab; `guildBankSelectedTab`.

**Guild bank window view modes:** `guildBankViewMode` is `"tab"` or list (`ListView`) only—no bank-style category view for guild bank.

### WindowLayoutController

`Refresh(config)` is entirely driven by the injected `config` table (no hard-coded window branching).

`CreateViewContext(config)` returns:

- `sortButtons(buttons, overrideSortMode, overrideSubSortMode)` → `addon:SortButtons(..., overrideSortMode or config.sortMode, overrideSubSortMode)`
- `acquireSection` / `acquireSectionHeader` / `acquireDivider` — delegate to `sectionManager` when present
- `getCollapsed` / `setCollapsed` / `requestRelayout` / `containerType` / `showEmptySlots` (optional; List/Tab layout)

**Collapse `kind` values in use:**

- Bags: `"category"`, `"bag"`, `"section"` (section metadata in `categorySections`)
- Bank category mode: `"category"`, `"section"` (shared section collapse state via `categorySections`); bank tab mode: `"tab"` (with legacy fallbacks to `collapsedBankSections` in getters)
- Guild bank tab mode: `"tab"` (with legacy fallbacks to `collapsedGuildBankSections`)

### SavedSearches (`Data\SavedSearches.lua`)

Stores named search shortcuts in `db.global.savedSearches` and expands
`SAVED(Name)` tokens before expressions reach PredicateEngine. Names are matched
case-insensitively while preserving display casing. Missing, invalid, cyclic, or
too-deep references expand to a never-match predicate. Renaming a saved search
also updates references in other saved searches, search history, and custom
category search expressions.

### PredicateEngine

Lives in `OneWoW_GUI` as `OneWoW_GUI.PredicateEngine` (published by the `OneWoW_GUI-1.0` LibStub library). Bags consumes it via `local PE = OneWoW_GUI.PredicateEngine`. Full reference: [`OneWoW_GUI/Docs/PREDICATE_ENGINE.md`](../../OneWoW_GUI/Docs/PREDICATE_ENGINE.md).

Used by Bags for: search filtering (`WH:FilterBySearch` after saved-search expansion), custom category expressions and builtin category search strings in `Data/Categories.lua`, item button state (`ItemButton` junk / new / upgrade flags), and keyword tooltips in `Integrations/OneWoWTooltips.lua`.

Cache invalidation boundary: `InvalidateCategorization("props")` on `BAG_UPDATE_DELAYED` calls `PE:InvalidatePropsCache()` (props + tooltip only). Full `PE:InvalidateCache()` runs on keyword/property registration, settings changes that reshape categorization, and manual refresh.

### Categories

**28** builtin rows in `CATEGORY_DEFINITIONS` (including `1W Junk`, `1W Upgrades`, `Recent Items`, crafting split **`Mats`** / **`Reagents`**, `Other`, `Empty`, and search-driven builtins such as `Housing`, `Toys`, `Junk`, etc.). Builtin search categories are collected into `SEARCH_CATEGORIES` sorted by `searchOrder` (ties retain stable relative order from definitions).

Custom predicate categories are mirrored into **`precomputedCustomCands`** when `customCategoriesV2` mutates so per-slot classification avoids repeating filter-mode inference and string lowercasing. During **`ResolveBaseCategory`**, custom predicate hits and builtin **`SEARCH_CATEGORIES`** hits are merged into a **single candidate pool**; tie-breaking: user-facing **priority** (higher wins) → custom beats builtin at equal priority → `defaultOrder` (lower wins) → section index → **Category Manager list order** → `searchOrder` → alphabetical name.

---

## Window Architecture

Three windows share the same structural pattern (shell from `WindowHelpers:CreateWindowShell`, title bar, content area, optional settings button, scroll scaffold, resize handle).

**Guild bank:** `GuildBankLog` is a separate movable panel listening for `GUILDBANKLOG_UPDATE`, toggled from the guild bank bar; it is not a child of the main guild bank scroll content.

**Info bars:** All three windows use `InfoBarFactory:Create` via thin config modules (`InfoBar.lua`, `BankInfoBar.lua`, `GuildBankInfoBar.lua`): controller, view mode dropdown, expansion filter (bags/bank), shared search history dropdown, and `savedSearches` save button where enabled.

### Sorting (`Data\Sorting.lua` → `OneWoW_Bags:SortButtons`)

Modes: `none` (no reorder), `default` (bagID then slotID among occupied slots), `name`, `rarity`, `ilvl`, `type` (item class ID, subclass ID, then name), `expansion` (expansion ID via `WindowHelpers:ResolveExpansionID`, then quality). Empty slots are ordered last where the comparator considers `owb_hasItem`.

**Sort caches on buttons** (`ItemButton:OWB_FullUpdate`, mirrored in `GuildBankSet`): `_owb_sortName`, `_owb_ilvl`, `_owb_classID`, `_owb_subClassID`, `_owb_expansionID`, `_owb_itemQuality` (container `info.quality`), `_owb_reagentQuality` and `_owb_craftedQuality` (copied from `PE:BuildProps` — no `BuildProps` in the sort loop). Cleared in `ItemPool:ResetButton` and empty-slot updates.

**`rarity` mode** (`CompareRarity`): descending comparisons in order — (1) item quality (`_owb_itemQuality`, fallback `owb_itemInfo.quality`), (2) reagent profession tier (`_owb_reagentQuality`), (3) crafted tier (`_owb_craftedQuality`). Item rarity wins globally; profession tiers break ties (e.g. same-name common herbs with different diamond tiers).

Default in **fresh DB defaults** is `itemSort = "none"` (migration 5); `GetItemSortMode` returns `db.global.itemSort or "default"` if the key were absent.

Per-category `categoryModifications[name].subSortMode` provides a secondary
criterion after `sortMode`. Optional `sortDescending` / `subSortDescending`
booleans override direction per row (`nil` = mode default). Category Manager
shows a direction toggle (`CovenantSanctum-Renown-DoubleArrow`, rotated for
asc/desc); disabled when sort/sub-sort is `none` or when sub-sort duplicates
primary. `SortButtons(buttons, sortMode, subSortMode, sortDescending, subSortDescending)`.

**Mode default direction** when `*Descending` is unset: `default`/`name`/`type` asc;
`rarity`/`ilvl`/`expansion` desc. Final bag/slot tie-break is always asc. Global
`itemSort` does not expose direction UI (always uses mode defaults).

When no explicit sub-sort is set, legacy tie-breakers remain for selected primary
modes, then all sorts fall back to `default` bag/slot order.

### Width calculation (`WindowLayoutController:UpdateFixedWidth`)

```
width = cols × (iconSize + spacing) - spacing + 4 + scrollbarSpace + (2 × outerPadding)
```

`cols` is `bagColumns` or `bankColumns` depending on the window. Vertical resizing adjusts height; horizontal size follows column settings.

---

## Event System

### Dispatch

A single hidden `eventFrame` in `OneWoW_Bags.lua` handles `ADDON_LOADED` and `PLAYER_LOGIN` directly; all other registered events map through `runtimeEventHandlers[event]` into `Events:*` methods and then `OneWoW_Bags:*` as needed.

### Key groups

| Group | Flow |
|--------|------|
| Bag updates | `BAG_UPDATE` → `dirtyBags` → `BAG_UPDATE_DELAYED` → `InvalidateCategorization("props")` + `ProcessBagUpdate` |
| Lock / cooldown | `ITEM_LOCK_CHANGED` → per-button `OWB_RefreshLock`; `BAG_UPDATE_COOLDOWN` → `OnCooldownUpdate` |
| Bank | `BANKFRAME_OPENED` / `CLOSED` → suppress/restore Blizzard bank, `BankGUI`, `C_Bank.Fetch*`, `BankPanel` warband vs character |
| Guild bank | `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` + `GuildBanker` |
| Merchant | `MERCHANT_SHOW` / `MERCHANT_CLOSED` (auto open/close with guards in `HookBlizzardBags`) |
| Money | `PLAYER_MONEY`, `ACCOUNT_MONEY`, guild bank money events |
| Quest | `QUEST_ACCEPTED` / `QUEST_REMOVED` → full-bag dirty rebuild |
| Predicate-related | `EQUIPMENT_SETS_CHANGED` / `PLAYER_EQUIPMENT_CHANGED` → `Events:OnPredicateInvalidation` → `InvalidateCategorization("props")` + deferred `RequestVisualRefresh` for visible windows; `GET_ITEM_INFO_RECEIVED` → coalesced `InvalidateItemIDs` + `UpdateSlotsForItemIDs` (no blanket categorization wipe) |

---

## Database Schema

Persisted layout and behavior state lives under `OneWoW_Bags_DB.global`. The defaults table in `Core\Database.lua` also includes `language`, `theme`, and `minimap` for `OneWoW_GUI:MigrateSettings` alignment.

### Display — bags

`viewMode`, `bagColumns`, `scale`, `iconSize`, `itemSort`, `compactCategories`, `compactGap`, `categorySpacing`, `showCategoryHeaders`, `showEmptySlots`, `bankShowEmptySlots`, `warbandBankShowEmptySlots`, `guildBankShowEmptySlots`, `hideScrollBar`, `showBagsBar`, `showMoneyBar`, `showCurrencyTrackerCapHighlight`, `showHeaderBar`, `showSearchBar`, `selectedBag`

### Search

`searchHistoryLimit` (0 disables history, 1-10 keeps recent committed searches),
`searchHistory`, `savedSearches` (`displayName -> predicate string` used by
`SAVED(Name)`).

### Display — personal bank / warband bank / guild bank

Personal bank: `bankViewMode`, `bankColumns`, `bankCompactCategories`, `bankCompactGap`, `bankCategorySpacing`, `showBankCategoryHeaders`, `bankHideScrollBar`, `showBankBagsBar`, `showBankSearchBar`, `showBankHeaderBar`, `bankSelectedTab`, `collapsedBankTabSections`.

Warband bank (parallel keys, selected at runtime by `bankShowWarband`): `warbandBankViewMode`, `warbandBankColumns`, `warbandBankCompactCategories`, `warbandBankCompactGap`, `warbandBankCategorySpacing`, `showWarbandBankCategoryHeaders`, `warbandBankHideScrollBar`, `showWarbandBankBagsBar`, `showWarbandBankSearchBar`, `showWarbandBankHeaderBar`, `warbandBankSelectedTab`, `collapsedWarbandBankTabSections`.

Guild bank: `guildBankViewMode`, `guildBankSelectedTab`, `guildBankShowEmptySlots`.

Shared: `bankShowWarband` (active mode), `bankFramePosition`, `collapsedBankCategorySections` (categories are global across modes).

`BankController:Get(field)` / `BankController:GetFor(mode, field)` dispatches to the correct keyset based on mode.

### Behavior

`autoOpen`, `autoClose`, `autoOpenWithBank`, `locked`, `bankLocked`, `enableBankUI`, `enableBankOverlays`, `enableWarbandBankOverlays`, `altToShow`, `enableExpansionFilter`, `enableBankExpansionFilter`, `enableWarbandBankExpansionFilter`, `enableInventorySlots`, `stackItems`

`enableBankUI` and `bankLocked` are single shared keys mirrored into both Personal Bank and Warband Bank settings tabs via cross-tab UI sync.

### Visual

`rarityColor`, `rarityIntensity`, `bankRarityColor`, `warbandBankRarityColor`, `showNewItems`, `showUnusableOverlay`, `dimJunkItems`, `stripJunkOverlays`

### Categories

`customCategoriesV2`, `disabledCategories`, `categoryModifications` (including per-category `sortMode` and `subSortMode`), `categorySort`, `categoryOrder`, `categorySections`, `sectionOrder`, `displayOrder`, `enableJunkCategory`, `enableUpgradeCategory`, `moveRecentToTop`, `moveOtherToBottom`, `pinnedCategoryShowsWhenDisabled`, `pinnedCategories`

### Collapse

`collapsedSections`, `collapsedBagSections`, `collapsedBankSections`, `collapsedGuildBankSections`, `collapsedBankCategorySections`, `collapsedBankTabSections`, `collapsedWarbandBankTabSections`, `collapsedGuildBankTabSections`

### Other

`mainFramePosition`, `bankFramePosition`, `guildBankFramePosition`, `trackedCurrencies`, `recentItems`, `recentItemDuration`, `_migrationVersion`

### Migrations

`_migrationVersion` is advanced by `DB:RunMigrations` up to **17**:

1. `category_system_v2` — split Equipment/Consumables builtins; seed `categorySections` / `sectionOrder`  
2. `junk_rename` — `OneWoW Junk` / `OneWoW Upgrades` → `1W Junk` / `1W Upgrades` in disabled/collapsed maps  
3. `display_order` — build `displayOrder` from legacy section graph  
4. `category_system_v3` — `recentItemDuration` clamp; sections use `SectionDefaults` IDs; rebuild `displayOrder`  
5. `item_sort_to_none` — default `itemSort` to `none`  
6. `cleanup_old_flags` — remove legacy `*Migrated` boolean keys from SavedVariables  
7. `split_collapsed_bank_state` — separate collapsed keys for bank tab/category vs guild bank  
8. `columns_minimum_10` — raise `bagColumns` / `bankColumns` below 10 up to 10  
9. `bank_columns_minimum_15` — raise `bankColumns` below 15 up to 15  
10. `onewow_bags_default_section` — ensure Equipment/Crafting/Housing sections; add/sync **OneWoW Bags** section (`SEC_ONEWOW_BAGS`)  
11. `display_name_uniqueness` — disambiguate custom category display names that collide with builtins or each other  
12. `section_category_membership_cleanup` — strip stale names from section `categories` lists (removed custom rows, etc.)  
13. `rename_move_upgrades_to_top` — rename `moveUpgradesToTop` key to `moveRecentToTop`  
14. `hide_in_to_applies_in` — convert `categoryModifications[*].hideIn` to `appliesIn` with inverted semantics
15. `mats_crafting_category` — insert the `Mats` builtin before `Reagents` in all section/member/displayOrder lists so existing saves pick up the new crafting category
16. `split_warband_bank_settings` — copy legacy `bank*` values into parallel `warbandBank*` keys when the warband key is not already set, preserving user settings during the personal/warband settings split
17. `cleanup_legacy_root_keys` — remove stray legacy root-level SavedVariable keys while preserving supported root scopes: `global`, `chars`, `realms`, `factions`, `classes`, `specs`, `presets`, and `_activePreset`

---

## Integration Points

### Addon compartment

TOC hooks: `1WoW_Bags_OnAddonCompartmentClick`, `1WoW_Bags_OnAddonCompartmentEnter`, `1WoW_Bags_OnAddonCompartmentLeave` — toggle bags / tooltip.

### OneWoW hub

`RegisterLoadComponent`, `RegisterMinimap`, `ItemStatus`, `UpgradeDetection`, `OverlayEngine`, `SettingsFeatureRegistry` (when hub present).

### OneWoW_GUI

`DB:Init` / `RunMigrations` / `MergeMissing`, frame and scroll factories, `SkinIconFrame`, `UpdateIconQuality`, theme and shared settings APIs, window position helpers. `Core\Constants.lua` calls `RegisterGUIConstants` at load.

### Item button callbacks (`Integrations\OneWoWBagsIntegration.lua`)

```lua
OneWoW_Bags:RegisterItemButtonCallback("MyAddon", function(button, bagID, slotID) ... end)
OneWoW_Bags:UnregisterItemButtonCallback("MyAddon")
```

After `GUI:RefreshLayout`, visible inventory buttons fire registered callbacks (~50ms delay). After `BankGUI:RefreshLayout`, bank buttons fire when `enableBankOverlays` is true. After `GuildBankGUI:RefreshLayout`, when **`db.global.enableBankOverlays`** is true, the integration **clears** OneWoW overlays on guild bank buttons (`ClearGuildBankOverlays`) rather than invoking the same per-button callback loop. (Guild bank uses this shared key directly—not `BankController`-dispatched warband/personal overlay toggles.)

### TSM / Baganator

`TSMIntegration:Import` → `customCategoriesV2`. `CategoryController:ImportBaganator()` maps Baganator profiles into OneWoW_Bags structures when that addon is present (`OptionalDeps`).

### `API/` (documentation only)

The addon folder includes `API/` (`README.md`, `INTEGRATION_GUIDE.md`, `INDEX.md`, and `Examples/*.lua`) and the canonical reference at [`Docs/ITEM_BUTTON.md`](ITEM_BUTTON.md). These files are **not** listed in the TOC; they document `RegisterItemButtonCallback` and related integration patterns for other authors.

---

## Blizzard Frame Suppression

### Bags

`hooksecurefunc` on Blizzard open/close/toggle bag functions; `ContainerFrame1..13` and `ContainerFrameCombinedBags` OnShow hides; override bindings on a secure button where applicable.

### Bank

`SuppressBankFrame` — disable BankFrame scripts, move offscreen, reparent bank container frames 7–13 to a hidden parent. `RestoreBankFrame` reverses when disabling custom bank UI.

### Guild bank

`SuppressGuildBankFrame` / `RestoreGuildBankFrame` — alpha and position, preserve OnHide hook.

---

## Refresh Targets

`RequestLayoutRefresh`, `RequestVisualRefresh`, and `RequestWindowReset` accept `target`:

| Target | GUI | Sets |
|--------|-----|------|
| `"bags"` | `GUI` | `BagSet` |
| `"bank"` | `BankGUI` | `BankSet` |
| `"guild"` | `GuildBankGUI` | `GuildBankSet` |
| `"bank_related"` | `BankGUI`, `GuildBankGUI` | `BankSet`, `GuildBankSet` |
| `"all"` (default) | all three | all three |

`RequestVisualRefresh` refreshes set visuals then triggers a matching layout refresh for the same target scope.

### Layout refresh hardening (post-load)

Inventory windows share `WindowLayoutController:Refresh`, which runs `cleanup` (hide all item buttons) then view layout (`Show` matching buttons). Failures between those steps produce empty chrome with valid slot counts.

| Mechanism | Location | Behavior |
|-----------|----------|----------|
| Guarded layout | `WindowHelpers:RunGuardedLayoutRefresh` | Wraps each GUI `RefreshLayout` body in `pcall`; always clears `_layoutInProgress`. Reentrant calls schedule `RequestLayoutRefresh(..., "reentrant_followup")` instead of returning silently. |
| Guard reset | `onHide` / `FullReset` on `GUI`, `BankGUI`, `GuildBankGUI` | Clears `_layoutInProgress` so a stuck in-flight layout cannot survive window close. |
| Coalesced flush | `FlushPendingLayoutRefreshes` | Clears `pendingRefresh` only when a refresh actually runs. Skips (hidden frame or `Set._building`) leave pending set and reschedule flush on the next frame. |
| Zone enter | `Events:OnPlayerEnteringWorld` | After zone load (not initial login), refreshes each visible built UI (`bags` / `bank` / `guild`) immediately and again after 0.1s. |
| Frame show | `WindowHelpers:AttachLayoutOnShow` | Hooks main window `OnShow` to request `show_onshow` when the backing set is already built. |

---

## Performance Patterns

- **Pooling:** `ItemPool`, `CategoryManagerBase` section/divider/header frames, `CategoryViewHelpers` compact label pools, bank/guild tab button recycling via `BarHelpers`
- **Dirty batching:** `dirtyBags` until `BAG_UPDATE_DELAYED`
- **Predicate / category caches** with targeted invalidation (`props` vs full) and **`InvalidateItemIDs`** for streaming item-info batches
- **Settings debounce** on high-churn sliders
- **Combat-deferred cleanup** via `WindowHelpers:RegisterDeferredCleanup` when windows hide during lockdown
- **Guild bank refresh coalescing** — `QueueGuildBankRefresh` uses a one-shot OnUpdate driver
- **Scoped refresh targets** — pure display settings (e.g. `bagColumns`, `scale`) target `"bags"` only; category-affecting settings (e.g. junk/upgrade toggles, `stackItems`, `appliesIn` changes) target `"all"` to keep bags and bank in sync

---

## Custom Category System

**Storage (`customCategoriesV2`):** per-row `items` (explicit item IDs, keyed by `tostring(itemID)`), optional `searchExpression` / `filterMode == "search"`, and type / subtype strings vs `C_Item.GetItemClassInfo` / `GetItemSubClassInfo` with `typeMatchMode` where applicable.

**Classification:** explicit `items` pins are resolved only in the **manual** stage of `GetItemCategory` (first). Custom predicate categories (search + type/subtype) and builtin search categories are collected into a merged candidate pool; the winner is picked by user-facing **priority** → custom-wins-ties → `defaultOrder` → section index → list order → `searchOrder` → alphabetical name.

**Manual pins (global rule):** at most **one** pin per item ID across all `customCategoriesV2[*].items` and all `categoryModifications[*].addedItems`. `CategoryController:AddItemToCategory` / `AddItemsToCategory` returns `false, owningDisplayName` if the item is already pinned elsewhere; the category manager UI shows `UIErrorsFrame` messages from locale keys `ERR_ITEM_ALREADY_MANUAL_CATEGORY` / `_GENERIC`. Adding to the **same** custom category again is a no-op. `Categories:AddItemToBuiltinCategory` enforces the same rule when called directly.

**Organization:** orphaned categories (fallback), `categorySections` + `sectionOrder`, and `displayOrder` with `"----"`, `"section:id"`, `"section_end"` markers. The **OneWoW Bags** section (`SectionDefaults.SEC_ONEWOW_BAGS`) holds a generated member list (`BuildOnewowMembers`); `CategoryController` and related UI call `SyncOnewowSectionCategories` after changes so unassigned builtins/custom rows stay in that section. Reordering sections (`CategoryController:MoveSectionOrder`) and moving categories within or between sections (`CategoryController:MoveCategoryToSection`) use default `RefreshUI()` so **categorization cache** and **`categoryListOrderMap`** invalidate when assignment depends on section or list order.

---

## View Context Pattern

`WindowLayoutController:CreateViewContext` builds the table passed into views. Callers (e.g. `MainWindow`, `BankWindow`, `GuildBankWindow`) supply `sectionManager`, `sortMode`, `containerType`, collapse getters/setters, and `requestRelayout` (typically `RefreshLayout` on that window). Category views can pass per-category `sortMode` and `subSortMode` through `viewContext.sortButtons`. Views must not assume a single global collapse table—behavior is always wired through `viewContext`.
