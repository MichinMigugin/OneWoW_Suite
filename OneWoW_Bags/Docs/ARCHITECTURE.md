# OneWoW_Bags — Architecture

## Overview

OneWoW_Bags is a unified bag/bank/guild bank replacement addon for World of Warcraft. It replaces consolidated Blizzard bag presentation with a single window per context (inventory, bank, guild bank). The addon is part of the OneWoW Suite and depends on `OneWoW_GUI` for UI primitives, database management, and theming.

**SavedVariable:** `OneWoW_Bags_DB`, initialized via `OneWoW_GUI.DB:Init` in **single** mode (defaults and persisted data under `db.global`).

**TOC:** `## Interface: 120001, 120005` (Retail + compatible build).

**Hard dependency:** `OneWoW_GUI`  
**Soft dependencies:** `OneWoW` (hub, overlays, item status, upgrade detection), `OneWoW_AltTracker`, `OneWoW_ShoppingList`, `TradeSkillMaster`, `Baganator` (profile import via `CategoryController`)

---

## File Tree & Load Order

The TOC loads files in this exact sequence. **Order matters**—each layer builds on the one before it.

```
Libs\LibStub\LibStub.lua

Locales\enUS.lua
Locales\esES.lua
Locales\koKR.lua
Locales\frFR.lua
Locales\ruRU.lua
Locales\deDE.lua

Core\Constants.lua                 ← OneWoW_GUI:RegisterGUIConstants, icon sizes, GUI metrics
Core\SectionDefaults.lua           ← stable section IDs, builtin lists, OneWoW Bags catch-all section sync
Core\Database.lua                  ← DB:Init, defaults, migrations
Core\BagTypes.lua                  ← bag ID constants, reagent/player bag helpers
Core\BankTypes.lua                 ← bank/warband tab constants
Core\Events.lua                    ← event router (dirtyBags, RuntimeEvents)
Core\PredicateEngine.lua           ← search expression tokenizer/compiler/evaluator

Data\Sorting.lua                   ← item sort comparators (SortButtons)
Data\Categories.lua                ← builtin category defs, classification engine

Modules\ItemPool.lua               ← frame object pool (ItemButton recycling)
Modules\ItemButton.lua             ← ItemButtonMixin + ApplyItemButtonMixin
Modules\BagSet.lua                 ← player inventory slot management
Modules\BankSet.lua                ← personal + warband bank slots
Modules\GuildBankSet.lua           ← guild bank tab/slot management + cache
Modules\CategoryManagerBase.lua    ← section/divider/header frame pool factory
Modules\CategoryManager.lua        ← bags: category assignment + bucketing
Modules\BankCategoryManager.lua    ← bank: CategoryManagerBase instance (section pools)
Modules\GuildBankCategoryManager.lua

Integrations\OneWoWBagsIntegration.lua  ← item-button callback hooks, overlay hooks
Integrations\TSMIntegration.lua         ← TSM group import

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
GUI\InfoBarFactory.lua             ← shared info bar builder (bank / guild bank)
GUI\InfoBar.lua                    ← bags top bar (view mode dropdown, search, expansion filter)
GUI\BagsBar.lua                    ← bags bottom bar (bag icons, gold, trackers)
GUI\BankInfoBar.lua
GUI\BarHelpers.lua                 ← shared bank/guild bank bar chrome (frame, gold, tab recycling)
GUI\BankBar.lua
GUI\BankWindow.lua
GUI\GuildBankInfoBar.lua
GUI\GuildBankBar.lua
GUI\GuildBankLog.lua               ← transaction log panel (GUILDBANKLOG_UPDATE)
GUI\GuildBankWindow.lua
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
│  Categories, PredicateEngine, Sorting, BagTypes, BankTypes   │
│  ─ Classification, expression evaluation, sort comparators   │
│  ─ Categories uses PredicateEngine for search builtins       │
└────────────────────────────┬─────────────────────────────────┘
                             │ reads
┌────────────────────────────▼─────────────────────────────────┐
│                      Core Layer                              │
│  Database (DB:Init, defaults, migrations)                    │
│  Events (event routing table, dirtyBags accumulator)         │
│  Constants (GUI metrics, icon sizes)                         │
│  SectionDefaults (section IDs, builtin ordering, OWB section)  │
└──────────────────────────────────────────────────────────────┘
```

### The Root Namespace Object

`OneWoW_Bags` (the second vararg from `local _, OneWoW_Bags = ...`) is the central orchestration hub. All layers attach their tables to it, and it is also exposed as `_G.OneWoW_Bags` for cross-addon access.

The root object provides:

- **State flags:** `bankOpen`, `guildBankOpen`, `oneWoWHubActive`, `inventoryPresentationState` (contains `altShowActive`), `activeExpansionFilter` (bags search bar expansion filter), `activeBankExpansionFilter`
- **Lifecycle:** `OnAddonLoaded`, `OnPlayerLogin`, `InitializeControllers`, `InitializeDatabase`
- **Refresh orchestration:** `RequestLayoutRefresh(target)`, `RequestVisualRefresh(target)`, `RequestWindowReset(target)`
- **Cache invalidation:** `InvalidateCategorization(scope)` — refreshes `Categories` from `customCategoriesV2` / `recentItemDuration` / `recentItems`, clears category cache; if `scope == "props"` then `PredicateEngine:InvalidatePropsCache()`, else full `PredicateEngine:InvalidateCache()`
- **Blizzard hooks:** `HookBlizzardBags`, `SuppressBankFrame`, `RestoreBankFrame`, `SuppressGuildBankFrame`, `RestoreGuildBankFrame`
- **Guild bank orchestration:** `RefreshGuildBankContents`, `QueueGuildBankRefresh`, `TrackGuildBankTransferTab`, `TrackGuildBankTransferSource`, `ProcessPendingGuildBankTransferTabs`, `PurgeClearSource`, plus internal coalescing state for cross-tab moves
- **Helpers:** `GetDB`, `GetItemSortMode`, `SortButtons`, `ShouldShowItemQuality`, `ShouldDimJunkItem`, `ShouldStripJunkOverlays`, `EnsureCategoryModification`, `EnsureBuiltinCategoryAddedItems`, `IsAltShowActive`, `SetAltShowActive`, `IsBankUIEnabled`, `ReinitForLanguage`, `ApplyItemButtonMixin`, `HookPetCageTooltip`, `GetMoneyDialog`, `ShowMoneyDialog`
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
       ├─→ InvalidateCategorization("props")  ← Categories refresh + PredicateEngine:InvalidatePropsCache
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
- Bank and guild bank windows: `db.global.bankColumns`.

### 4. Category Classification Pipeline

**Bags — `CategoryView` only:** at the start of `CategoryView:Layout`, `CategoryManager:AssignCategories()` runs:

```
CategoryManager:AssignCategories()
  └─→ For each BagSet button with an item:
       └─→ Categories:GetItemCategory(bagID, slotID, itemInfo)
```

**`Categories:GetItemCategory` stages** (in order; early return stops the rest):

1. **Manual pins** — `customCategoriesV2[*].items` and `categoryModifications[*].addedItems` (no `PredicateEngine` on this path). Overrides everything below, including Junk/Upgrades. If `db.global.pinnedCategoryShowsWhenDisabled` is **false**, pins in **disabled** categories are ignored here so later stages can assign (e.g. `Other`). If **true**, a disabled pinned category still wins assignment. Legacy saves with the same item ID in multiple pin tables: `PickBestCandidate` among those rows (priority → section order → stable tie key).
2. **1W Junk** — `PredicateEngine` `props.isJunk`; gated by `enableJunkCategory` + `disabledCategories`.
3. **1W Upgrades** — `props.isUpgrade`; gated by settings + `disabledCategories`.
4. **Recent Items** — `SlotMatchesRecent` (GUID map + `recentItemDuration`). Surfaces recent non-junk/non-upgrade items before custom/builtin classification.
5. **No hyperlink** → `"Other"`.
6. **Category cache** read (PredicateEngine cache key when hyperlink exists).
7. **Merged candidate pool** — collects **all** matching custom predicate categories (`CollectCustomPredicateCandidates`) and builtin `SEARCH_CATEGORIES` matches into one pool, then picks one winner via `PickBestCandidate`: user-facing priority (higher wins) → custom beats builtin at equal priority → `defaultOrder` (lower wins) → section order → `searchOrder` → tieKey.
8. **Inventory slots** — if result is `Weapons` or `Armor` and `enableInventorySlots`, remap to localized equip-slot category name.
9. **Disabled fallback** — if final candidate-pool-derived name is disabled → `"Other"` (steps 1–4 bypass this).
10. **Cache write** when applicable (same key rules as before).

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

Search uses `PredicateEngine` (tokenizer, AST, evaluation):

- Keywords, properties, operators (`&` `|` `!`), parentheses, bare name text
- `#recent` is registered at `Data\Categories.lua` load via `PredicateEngine:RegisterKeyword` (Bags-only): GUID map + duration only. `#new` / `IsNew` in core engine use `C_NewItems` via `BuildProps` (can lag until `InvalidatePropsCache`); `#recent` does not use that cached flag for classification
- `WH:FilterBySearch` compiles the expression once per refresh and evaluates per button via `PredicateEngine:CheckItem`

```
InfoBar / BankInfoBar / GuildBankInfoBar: search changed
  └─→ *Controller:OnSearchChanged → *GUI:RefreshLayout
       └─→ filterButtons → WH:FilterBySearch
            └─→ PredicateEngine:CheckItem(expr, itemID, bagID, slotID, info)
                 ├─→ Compile(expr) → cached AST
                 ├─→ BuildProps(...) → cached props (+ tooltip laziness inside props)
                 └─→ Evaluate AST → true/false
```

Expansion filtering for bags/bank uses `WindowHelpers:ResolveExpansionID` (PredicateEngine expansion helpers under the hood), not the same code path as the search box unless the user types expansion predicates.

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

### ItemPool

Acquire/release pool for `ContainerFrameItemButtonTemplate` buttons. `Preallocate(220)` at login. `OneWoW_GUI:SkinIconFrame` during creation; mixin applied when bound in `BagSet` / `BankSet` / `GuildBankSet`.

### ItemButtonMixin (`Modules\ItemButton.lua`)

Applied with `OneWoW_Bags:ApplyItemButtonMixin` (copies `OneWoW_Bags.ItemButtonMixin` methods onto the button once).

- `OWB_SetSlot`, `OWB_MarkDirty`, `OWB_IsDirty`, `OWB_FullUpdate`
- `OWB_UpdateNewItemGlow` — player bags only (`BagTypes:IsPlayerBag`); uses `PredicateEngine:BuildProps(...).isNew` + template overlays
- `OWB_UpdateJunkDim`, `OWB_UpdateUnusableOverlay` — junk from `BuildProps(...).isJunk`
- `OWB_RefreshCooldown`, `OWB_RefreshLock`, `OWB_SetIconSize`, `OWB_GetLink`

Per-button state includes `owb_bagID`, `owb_slotID`, `owb_itemInfo`, `owb_hasItem`, `owb_categoryName` (when categorized), `owb_isBank`, `owb_isGuildBank`, and internal junk/overlay flags.

### BagSet / BankSet / GuildBankSet

- `Build()` / `ReleaseAll()`, `UpdateDirtyBags` (bags + bank), `GetAllButtons`, `GetFreeSlotCount`, etc.
- `bagContainerFrames[bagID]` — parent frames with `SetID(bagID)` for secure behavior on container template buttons.
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

**ListView** — Grid with optional reagent-bag segment after normal bags. Computes column count from **content width** and icon spacing when not overridden by bag/category views. Honors `showEmptySlots`.

**CategoryView** — Thin wrapper: runs `CategoryManager:AssignCategories()` + `:GetItemsByCategory()`, then calls `H.GetSectionedLayout` and `H.LayoutCategoryContent` from the shared pipeline with bag-specific settings.

**BagView** — One section per physical bag; `selectedBag` filter.

**BankCategoryView** — Thin wrapper: builds `itemsByCategory` from `BankSet` via inline `Categories:GetItemCategory`, then calls `H.GetSectionedLayout` and `H.LayoutCategoryContent` from the shared pipeline with bank-specific settings.

**BankTabView** — Sections per bank tab; `bankSelectedTab`; respects warband vs character via `bankShowWarband`.

**GuildBankTabView** — Sections per guild tab; `guildBankSelectedTab`.

**Guild bank window view modes:** `guildBankViewMode` is `"tab"` or list (`ListView`) only—no bank-style category view for guild bank.

### WindowLayoutController

`Refresh(config)` is entirely driven by the injected `config` table (no hard-coded window branching).

`CreateViewContext(config)` returns:

- `sortButtons(buttons, overrideSortMode)` → `addon:SortButtons(..., overrideSortMode or config.sortMode)`
- `acquireSection` / `acquireSectionHeader` / `acquireDivider` — delegate to `sectionManager` when present
- `getCollapsed` / `setCollapsed` / `requestRelayout` / `containerType`

**Collapse `kind` values in use:**

- Bags: `"category"`, `"bag"`, `"section"` (section metadata in `categorySections`)
- Bank category mode: `"category"`, `"section"` (shared section collapse state via `categorySections`); bank tab mode: `"tab"` (with legacy fallbacks to `collapsedBankSections` in getters)
- Guild bank tab mode: `"tab"` (with legacy fallbacks to `collapsedGuildBankSections`)

### PredicateEngine

Expression pipeline with registries for properties, keywords, and flags; caches for compiled expressions, per-item props, and tooltip text. `InvalidateCache` wipes compile + props + tooltip; `InvalidatePropsCache` wipes props + tooltip only (used from `InvalidateCategorization("props")` on bag delayed updates).

Used for: search filtering, custom category expressions, builtin category search strings in `Categories`.

Tokenizer notes: string-property comparisons accept unquoted single-token values and quoted string literals for phrases. Standalone quoted `~"..."` / `~'...'` is treated as shorthand for `name~...`. `~` remains literal contains, while `~~` uses Lua pattern matching and malformed patterns fail safely as non-matches.

### Categories

**27** builtin rows in `CATEGORY_DEFINITIONS` (including `1W Junk`, `1W Upgrades`, `Recent Items`, `Other`, `Empty`, and search-driven builtins such as `Housing`, `Toys`, `Junk`, etc.). Builtin search categories are collected into `SEARCH_CATEGORIES` sorted by `searchOrder`.

Custom predicate and builtin search categories are merged into a **single candidate pool** during assignment. Tie-breaking: user-facing **priority** (`categoryModifications[].priority`, higher wins) → custom beats builtin at equal priority → `defaultOrder` (lower wins) → section order → `searchOrder` → stable tieKey.

---

## Window Architecture

Three windows share the same structural pattern (shell from `WindowHelpers:CreateWindowShell`, title bar, content area, optional settings button, scroll scaffold, resize handle).

**Guild bank:** `GuildBankLog` is a separate movable panel listening for `GUILDBANKLOG_UPDATE`, toggled from the guild bank bar; it is not a child of the main guild bank scroll content.

**Info bars:** Bags use hand-built `InfoBar.lua`. Bank and guild bank use `InfoBarFactory:Create` with per-window config (controller, view mode list for the dropdown, expansion filter flags, DB keys).

### Sorting (`Data\Sorting.lua` → `OneWoW_Bags:SortButtons`)

Modes: `none` (no reorder), `default` (bagID then slotID among occupied slots), `name`, `rarity`, `ilvl`, `type` (item class ID, subclass ID, then name), `expansion` (expansion ID via `WindowHelpers:ResolveExpansionID`, then quality). Empty slots are ordered last where the comparator considers `owb_hasItem`.

Default in **fresh DB defaults** is `itemSort = "none"` (migration 5); `GetItemSortMode` returns `db.global.itemSort or "default"` if the key were absent.

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
| Predicate-related | `EQUIPMENT_SETS_CHANGED`, `PLAYER_EQUIPMENT_CHANGED`, `GET_ITEM_INFO_RECEIVED` → `Events:OnPredicateInvalidation` → `InvalidateCategorization("props")` + deferred `RequestLayoutRefresh("all")` |

---

## Database Schema

Persisted layout and behavior state lives under `OneWoW_Bags_DB.global`. The defaults table in `Core\Database.lua` also includes `language`, `theme`, and `minimap` for `OneWoW_GUI:MigrateSettings` alignment.

### Display — bags

`viewMode`, `bagColumns`, `scale`, `iconSize`, `itemSort`, `compactCategories`, `compactGap`, `categorySpacing`, `showCategoryHeaders`, `showEmptySlots`, `hideScrollBar`, `showBagsBar`, `showMoneyBar`, `showHeaderBar`, `showSearchBar`, `selectedBag`

### Display — bank / guild bank

`bankViewMode`, `guildBankViewMode`, `bankColumns`, `bankCompactCategories`, `bankCompactGap`, `bankCategorySpacing`, `showBankCategoryHeaders`, `bankHideScrollBar`, `showBankBagsBar`, `showBankSearchBar`, `showBankHeaderBar`, `bankSelectedTab`, `guildBankSelectedTab`, `bankShowWarband`

### Behavior

`autoOpen`, `autoClose`, `autoOpenWithBank`, `locked`, `bankLocked`, `enableBankUI`, `enableBankOverlays`, `altToShow`, `enableExpansionFilter`, `enableBankExpansionFilter`, `enableInventorySlots`, `stackItems`

### Visual

`rarityColor`, `rarityIntensity`, `bankRarityColor`, `showNewItems`, `showUnusableOverlay`, `dimJunkItems`, `stripJunkOverlays`

### Categories

`customCategoriesV2`, `disabledCategories`, `categoryModifications`, `categorySort`, `categoryOrder`, `categorySections`, `sectionOrder`, `displayOrder`, `enableJunkCategory`, `enableUpgradeCategory`, `moveRecentToTop`, `moveOtherToBottom`, `pinnedCategoryShowsWhenDisabled`, `pinnedCategories`

### Collapse

`collapsedSections`, `collapsedBagSections`, `collapsedBankSections`, `collapsedGuildBankSections`, `collapsedBankCategorySections`, `collapsedBankTabSections`, `collapsedGuildBankTabSections`

### Other

`mainFramePosition`, `bankFramePosition`, `guildBankFramePosition`, `trackedCurrencies`, `recentItems`, `recentItemDuration`, `_migrationVersion`

### Migrations

`_migrationVersion` is advanced by `DB:RunMigrations` up to **14**:

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

After `GUI:RefreshLayout`, visible inventory buttons fire registered callbacks (~50ms delay). After `BankGUI:RefreshLayout`, bank buttons fire when `enableBankOverlays` is true. After `GuildBankGUI:RefreshLayout`, the integration **clears** OneWoW overlays on guild bank buttons (`ClearGuildBankOverlays`) rather than invoking the same per-button callback loop.

### TSM / Baganator

`TSMIntegration:Import` → `customCategoriesV2`. `CategoryController:ImportBaganator()` maps Baganator profiles into OneWoW_Bags structures when that addon is present (`OptionalDeps`).

### `API/` (documentation only)

The addon folder includes `API/` (`README.md`, `ITEM_BUTTON_API.md`, `INTEGRATION_GUIDE.md`, and `Examples/*.lua`). These files are **not** listed in the TOC; they document `RegisterItemButtonCallback` and related integration patterns for other authors.

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

---

## Performance Patterns

- **Pooling:** `ItemPool`, `CategoryManagerBase` section/divider/header frames, `CategoryViewHelpers` compact label pools, bank/guild tab button recycling via `BarHelpers`
- **Dirty batching:** `dirtyBags` until `BAG_UPDATE_DELAYED`
- **Predicate / category caches** with targeted invalidation (`props` vs full)
- **Settings debounce** on high-churn sliders
- **Combat-deferred cleanup** via `WindowHelpers:RegisterDeferredCleanup` when windows hide during lockdown
- **Guild bank refresh coalescing** — `QueueGuildBankRefresh` uses a one-shot OnUpdate driver
- **Scoped refresh targets** — pure display settings (e.g. `bagColumns`, `scale`) target `"bags"` only; category-affecting settings (e.g. junk/upgrade toggles, `stackItems`, `appliesIn` changes) target `"all"` to keep bags and bank in sync

---

## Custom Category System

**Storage (`customCategoriesV2`):** per-row `items` (explicit item IDs, keyed by `tostring(itemID)`), optional `searchExpression` / `filterMode == "search"`, and type / subtype strings vs `C_Item.GetItemClassInfo` / `GetItemSubClassInfo` with `typeMatchMode` where applicable.

**Classification:** explicit `items` pins are resolved only in the **manual** stage of `GetItemCategory` (first). Custom predicate categories (search + type/subtype) and builtin search categories are collected into a merged candidate pool; the winner is picked by user-facing **priority** → custom-wins-ties → `defaultOrder` → section order → `searchOrder` → stable tieKey.

**Manual pins (global rule):** at most **one** pin per item ID across all `customCategoriesV2[*].items` and all `categoryModifications[*].addedItems`. `CategoryController:AddItemToCategory` / `AddItemsToCategory` returns `false, owningDisplayName` if the item is already pinned elsewhere; the category manager UI shows `UIErrorsFrame` messages from locale keys `ERR_ITEM_ALREADY_MANUAL_CATEGORY` / `_GENERIC`. Adding to the **same** custom category again is a no-op. `Categories:AddItemToBuiltinCategory` enforces the same rule when called directly.

**Organization:** root order, `categorySections` + `sectionOrder`, and `displayOrder` with `"----"`, `"section:id"`, `"section_end"` markers. The **OneWoW Bags** section (`SectionDefaults.SEC_ONEWOW_BAGS`) holds a generated member list (`BuildOnewowMembers`); `CategoryController` and related UI call `SyncOnewowSectionCategories` after changes so unassigned builtins/custom rows stay in that section. Reordering sections (`CategoryController:MoveSection` / `MoveSectionCategory`) uses default `RefreshUI()` so **categorization cache** invalidates when assignment depends on section order.

---

## View Context Pattern

`WindowLayoutController:CreateViewContext` builds the table passed into views. Callers (e.g. `MainWindow`, `BankWindow`, `GuildBankWindow`) supply `sectionManager`, `sortMode`, `containerType`, collapse getters/setters, and `requestRelayout` (typically `RefreshLayout` on that window). Views must not assume a single global collapse table—behavior is always wired through `viewContext`.
