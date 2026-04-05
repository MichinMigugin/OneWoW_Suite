# OneWoW_Bags — Architecture

## Overview

OneWoW_Bags is a unified bag/bank/guild bank replacement addon for World of Warcraft. It replaces all Blizzard bag frames with a single consolidated window per container context (inventory, bank, guild bank). The addon is part of the OneWoW Suite and depends on `OneWoW_GUI` for UI primitives, database management, and theming.

**SavedVariable:** `OneWoW_Bags_DB` (single global table with a `.global` subtable)

**Hard dependency:** `OneWoW_GUI`  
**Soft dependencies:** `OneWoW` (hub, overlays, item status), `OneWoW_AltTracker`, `OneWoW_ShoppingList`, `TradeSkillMaster`

---

## File Tree & Load Order

The TOC loads files in this exact sequence. **Order matters**—each layer builds on the one before it.

```
Libs\LibStub\LibStub.lua          ← library loader

Locales\enUS.lua                   ← base locale (populates L + Locales["enUS"])
Locales\esES.lua                   ← partial overrides
Locales\koKR.lua
Locales\frFR.lua
Locales\ruRU.lua
Locales\deDE.lua

Core\Constants.lua                 ← GUI constants, icon size table
Core\Database.lua                  ← DB:Init, defaults, migrations
Core\BagTypes.lua                  ← bag ID constants, classification helpers
Core\BankTypes.lua                 ← bank/warband tab constants
Core\Events.lua                    ← event router (dirtyBags, RuntimeEvents)
Core\PredicateEngine.lua           ← search expression tokenizer/compiler/evaluator

Data\Sorting.lua                   ← item sort comparators
Data\Categories.lua                ← builtin category defs, classification engine

Modules\ItemPool.lua               ← frame object pool (ItemButton recycling)
Modules\ItemButton.lua             ← OWB_ mixin applied to pooled buttons
Modules\BagSet.lua                 ← player inventory slot management
Modules\BankSet.lua                ← personal + warband bank slots
Modules\GuildBankSet.lua           ← guild bank tab/slot management
Modules\CategoryManagerBase.lua    ← section/divider frame pool factory
Modules\CategoryManager.lua        ← bags: assign items → categories, build layout
Modules\BankCategoryManager.lua    ← bank: CategoryManagerBase instance
Modules\GuildBankCategoryManager.lua

Integrations\OneWoWBagsIntegration.lua  ← overlay callback hooks
Integrations\TSMIntegration.lua         ← TSM group import

Controllers\WindowLayoutController.lua  ← generic layout orchestrator
Controllers\BagsController.lua          ← bags-specific actions
Controllers\BankController.lua          ← bank-specific actions
Controllers\GuildBankController.lua     ← guild bank actions
Controllers\SettingsController.lua      ← setting write + side-effects
Controllers\CategoryController.lua      ← category/section CRUD

Views\ListView.lua                 ← flat grid layout strategy
Views\CategoryView.lua             ← categorized layout strategy
Views\BagView.lua                  ← per-bag sections layout strategy
Views\BankCategoryView.lua         ← bank category layout
Views\BankTabView.lua              ← bank per-tab layout
Views\GuildBankTabView.lua         ← guild bank per-tab layout

GUI\WindowHelpers.lua              ← window shell, scroll scaffold, filtering
GUI\InfoBarFactory.lua             ← shared info bar builder
GUI\InfoBar.lua                    ← bags top bar (view buttons, search, etc.)
GUI\BagsBar.lua                    ← bags bottom bar (bag icons, gold, trackers)
GUI\BankInfoBar.lua                ← bank top bar
GUI\BankBar.lua                    ← bank bottom bar
GUI\BankWindow.lua                 ← bank window frame
GUI\GuildBankInfoBar.lua
GUI\GuildBankBar.lua
GUI\GuildBankLog.lua
GUI\GuildBankWindow.lua
GUI\CategoryManager.lua            ← category management UI panel
GUI\Settings.lua                   ← settings UI panel
GUI\MainWindow.lua                 ← inventory main window

OneWoW_Bags.lua                    ← addon entry point (loads last)
```

---

## Architectural Pattern

OneWoW_Bags uses a **layered hybrid MVC** pattern. It is not strict MVC—some orchestration logic lives on the root namespace object—but the separation is intentional and consistent.

### Layer Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                      GUI Layer                               │
│  MainWindow, BankWindow, GuildBankWindow, Settings,          │
│  CategoryManager (UI), InfoBar, BagsBar, WindowHelpers       │
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
│  ─ Layout: receives buttons + width, returns height          │
│  ─ Uses viewContext for sort, sections, collapse state        │
└────────────────────────────┬─────────────────────────────────┘
                             │ reads
┌────────────────────────────▼─────────────────────────────────┐
│                     Module Layer                             │
│  BagSet, BankSet, GuildBankSet (slot management)             │
│  ItemPool (frame recycling), ItemButton (mixin)              │
│  CategoryManager, CategoryManagerBase (section pools)        │
│  ─ Owns the item button frames and slot↔button mapping       │
│  ─ CategoryManager assigns categories to buttons             │
└────────────────────────────┬─────────────────────────────────┘
                             │ reads
┌────────────────────────────▼─────────────────────────────────┐
│                      Data Layer                              │
│  Categories, PredicateEngine, Sorting, BagTypes, BankTypes   │
│  ─ Classification, expression evaluation, sort comparators,  │
│    bag/bank ID helpers                                       │
│  ─ Categories uses PredicateEngine for search-based matching │
└────────────────────────────┬─────────────────────────────────┘
                             │ reads
┌────────────────────────────▼─────────────────────────────────┐
│                      Core Layer                              │
│  Database (DB:Init, defaults, migrations)                    │
│  Events (event routing table, dirtyBags accumulator)         │
│  Constants (GUI metrics, icon sizes)                         │
└──────────────────────────────────────────────────────────────┘
```

### The Root Namespace Object

`OneWoW_Bags` (the second vararg from `local _, OneWoW_Bags = ...`) serves as the central orchestration hub. All layers attach their tables to it, and it is also exposed as `_G.OneWoW_Bags` for cross-addon access.

The root object provides:
- **State flags:** `bankOpen`, `guildBankOpen`, `oneWoWHubActive`, `inventoryPresentationState` (contains `altShowActive`)
- **Lifecycle:** `OnAddonLoaded`, `OnPlayerLogin`, `InitializeControllers`, `InitializeDatabase`
- **Refresh orchestration:** `RequestLayoutRefresh(target)`, `RequestVisualRefresh(target)`, `RequestWindowReset(target)`
- **Cache invalidation:** `InvalidateCategorization(scope)`
- **Blizzard hooks:** `HookBlizzardBags`, `SuppressBankFrame`, `RestoreBankFrame`, `SuppressGuildBankFrame`, `RestoreGuildBankFrame`
- **Helpers:** `GetDB`, `ShouldShowItemQuality`, `ShouldDimJunkItem`, `ShouldStripJunkOverlays`, `EnsureCategoryModification`, `EnsureBuiltinCategoryAddedItems`, `IsAltShowActive`, `SetAltShowActive`, `IsBankUIEnabled`, `ReinitForLanguage`

---

## Data Flow

### 1. Startup Sequence

```
ADDON_LOADED
  └─→ OnAddonLoaded
       ├─→ InitializeDatabase (DB:Init, migrations)
       ├─→ InitializeControllers (creates controller instances)
       ├─→ MigrateSettings (OneWoW_GUI shared settings)
       ├─→ ApplyTheme, ApplyLanguage
       ├─→ Categories:SetCustomCategories (hydrates from db)
       ├─→ RegisterSlashCommands
       ├─→ RegisterRuntimeEvents (registers all game events)
       └─→ OneWoW_GUI callbacks (theme, language, font, icon, minimap)

PLAYER_LOGIN
  └─→ OnPlayerLogin
       ├─→ DetectOneWoW (hub presence)
       ├─→ Minimap launcher (if no hub)
       ├─→ ItemPool:Preallocate(220)
       ├─→ BagSet:Build (creates all button frames)
       ├─→ BagsBar:UpdateIcons
       ├─→ HookBlizzardBags (binding overrides, ContainerFrame suppression)
       └─→ HookPetCageTooltip
```

### 2. Bag Update Pipeline (Primary Data Flow)

This is the most important flow—it runs every time inventory changes.

```
Game event: BAG_UPDATE (fires per-bag, may fire many times in one frame)
  └─→ Events:OnBagUpdate(bagID)
       └─→ dirtyBags[bagID] = true  (accumulates)

Game event: BAG_UPDATE_DELAYED (fires once after all BAG_UPDATEs)
  └─→ Events:OnBagUpdateDelayed
       ├─→ InvalidatePredicatePropsCache (clears item property cache)
       └─→ OneWoW_Bags:ProcessBagUpdate(dirtyBags)
            ├─→ BagSet:UpdateDirtyBags(dirtyBags)
            │    ├─→ If slot count changed → RebuildBag (release + re-acquire from pool)
            │    ├─→ Else → mark existing buttons dirty
            │    └─→ ProcessDirtySlots → OWB_FullUpdate per dirty button
            │         └─→ C_Container.GetContainerItemInfo → update icon, count,
            │            quality, cooldown, new-item glow, junk dim, unusable overlay
            ├─→ GUI:RefreshLayout (if bags window shown)
            │    └─→ (see Layout Pipeline below)
            └─→ BankGUI:RefreshLayout (if bank open + built)
```

### 3. Layout Pipeline

Every `GUI:RefreshLayout()` call follows this exact sequence, orchestrated by `WindowLayoutController:Refresh`:

```
RefreshLayout()
  └─→ WindowLayoutController:Refresh(config)
       ├─→ updateWindowWidth (recalculate based on columns + icon size)
       ├─→ beforeLayout
       │    ├─→ InfoBar:UpdateVisibility
       │    ├─→ BagsBar:UpdateRowVisibility
       │    └─→ BindScrollFrame (reposition scroll anchors)
       ├─→ cleanup → CleanupAllViews
       │    ├─→ Hide + ClearAllPoints on all buttons
       │    └─→ CategoryManager:ReleaseAllSections (return to pool)
       ├─→ getButtons → BagSet:GetAllButtons
       ├─→ filterButtons
       │    ├─→ FilterBySearch (PredicateEngine:CheckItem per button)
       │    └─→ FilterByExpansion (PredicateEngine:GetExpansionID per button)
       ├─→ layoutButtons → delegate to active View
       │    ├─→ ListView:Layout   (flat grid, reagent bag gap)
       │    ├─→ CategoryView:Layout (sections with headers, compact mode)
       │    └─→ BagView:Layout   (per-bag sections)
       ├─→ contentFrame:SetHeight(layoutHeight)
       └─→ afterLayout → BagsBar:UpdateFreeSlots
```

### 4. Category Classification Pipeline

When `CategoryView` is active, `CategoryManager:AssignCategories()` runs at the start of each layout:

```
CategoryManager:AssignCategories()
  └─→ for each button with an item:
       └─→ Categories:GetItemCategory(bagID, slotID, itemInfo)
            ├─→ 1. 1W Junk check (OneWoW.ItemStatus or quality == Poor)
            ├─→ 2. 1W Upgrades check (UpgradeDetection or ilvl comparison)
            ├─→ 3. Custom category match (items table, search expression, type filter)
            ├─→ 4. Builtin addedItems check (manual assignments)
            ├─→ 5. Recent Items check (C_NewItems + GUID timestamp)
            ├─→ 6. Cache lookup (itemID → category)
            ├─→ 7. PredicateEngine search matching (ordered SEARCH_CATEGORIES)
            ├─→ 8. Inventory slot refinement (Weapons/Armor → slot name)
            └─→ 9. Fallback → "Other"

CategoryManager:GetSectionedLayout(itemsByCategory, containerType)
  └─→ Builds ordered layout entries from:
       ├─→ db.global.displayOrder (primary: explicit ordering with sections)
       ├─→ db.global.categorySections + db.global.sectionOrder (groups)
       ├─→ db.global.categoryOrder (legacy root ordering)
       ├─→ db.global.categoryModifications (hideIn, priority adjustments)
       └─→ Leftover categories sorted by priority
```

### 5. Search Pipeline

Search uses the `PredicateEngine`, a full expression evaluator supporting:
- Keywords: `#weapon`, `#armor`, `#food`, `#hearthstone`, etc.
- Properties: `ilvl > 400`, `quality >= epic`, `expansion = midnight`
- Operators: `&` (AND), `|` (OR), `!` (NOT), parentheses
- Text matching: bare strings match item name

```
User types in search box
  └─→ InfoBar:OnSearchChanged → BagsController:OnSearchChanged
       └─→ GUI:OnSearchChanged → GUI:RefreshLayout
            └─→ filterButtons
                 └─→ WH:FilterBySearch(buttons, searchText)
                      └─→ PredicateEngine:CheckItem(expr, itemID, bagID, slotID, info)
                           ├─→ Compile(expr) → cached AST
                           ├─→ BuildProps(itemID, bagID, slotID, info) → cached props
                           └─→ Evaluate AST against props → true/false
```

### 6. Settings Pipeline

All settings writes go through `SettingsController:Apply`:

```
Settings UI interaction
  └─→ SettingsController:Apply(settingKey, value)
       └─→ appliers[settingKey](self, db, value)
            ├─→ Writes db.global[key] = value
            └─→ Triggers appropriate refresh:
                 ├─→ RequestLayoutRefresh (layout-affecting changes)
                 ├─→ RequestVisualRefresh (appearance-only changes)
                 ├─→ RequestWindowReset (structural changes like scrollbar)
                 └─→ InvalidateCategorization (category-affecting changes)
```

---

## Key Components In Detail

### ItemPool

An acquire/release object pool for `ItemButton` frames. Pre-allocates 220 frames at login to avoid runtime creation stutter. Each button is created from `ContainerFrameItemButtonTemplate`, skinned by `OneWoW_GUI:SkinIconFrame`, and has the `OWB_` mixin applied.

### ItemButton Mixin

Applied to each pooled button via `ApplyItemButtonMixin`. Provides:
- `OWB_SetSlot(bagID, slotID)` — assigns the button to a bag slot
- `OWB_FullUpdate()` — reads `C_Container.GetContainerItemInfo` and updates all visuals
- `OWB_MarkDirty`, `OWB_IsDirty` — dirty flag management
- `OWB_IsJunkItem` — OneWoW.ItemStatus or quality-based junk check
- `OWB_UpdateNewItemGlow`, `OWB_UpdateJunkDim`, `OWB_UpdateUnusableOverlay`
- `OWB_RefreshCooldown`, `OWB_RefreshLock`, `OWB_SetIconSize`, `OWB_GetLink`

Each button carries state on itself:
- `owb_bagID`, `owb_slotID` — location
- `owb_itemInfo` — cached `C_Container.GetContainerItemInfo` result
- `owb_hasItem` — boolean
- `owb_categoryName` — set by `CategoryManager:AssignCategories`
- `owb_dirty` — dirty flag for deferred updates
- `owb_isBank` — set by `BankSet:ApplyBankScripts` for bank buttons
- `owb_isGuildBank` — set by `GuildBankSet:ApplyGuildBankScripts` for guild bank buttons

### BagSet / BankSet / GuildBankSet

These manage the slot-to-button mapping for each container context. They:
- `Build()` — iterate bag IDs, create buttons from `ItemPool`, call `OWB_SetSlot`
- `UpdateDirtyBags(dirtyBags)` — handle slot count changes (rebuild) or mark dirty
- `GetAllButtons()` — returns flat array of all buttons in bag order
- `ReleaseAll()` — return all buttons to `ItemPool`

`BagSet` holds `bagContainerFrames[bagID]` — invisible parent frames with correct `SetID(bagID)` that Blizzard's `ContainerFrameItemButtonTemplate` requires for secure pickup/use behavior.

`GuildBankSet` is structurally different from `BagSet`/`BankSet`: it uses a **cache-driven** approach instead of `C_Container`. Item data is read via `GetGuildBankItemInfo`/`GetGuildBankItemLink` into `cache[tabID][slotID]`, then applied to buttons via `ApplyCacheToButtons`. Guild bank buttons get custom scripts for money cursor handling, `AutoStoreGuildBankItem`, and cross-tab pickup. Each tab has a fixed 98 slots.

### CategoryManagerBase

A factory that creates pooled section/divider frames. Each `Create()` returns an independent instance with its own `sectionPool`/`activeSections` and `dividerPool`/`activeDividers`. Three instances exist:
- `OneWoW_Bags.CategoryManager` — for bags
- `OneWoW_Bags.BankCategoryManager` — for bank
- `OneWoW_Bags.GuildBankCategoryManager` — for guild bank

### CategoryManager (Data Module — `Modules\CategoryManager.lua`)

Extends `CategoryManagerBase` with category assignment logic. **Not to be confused with** `CategoryManagerUI` (`GUI\CategoryManager.lua`), which is the category management dialog.

- `AssignCategories()` — iterates all `BagSet` buttons, calls `Categories:GetItemCategory` on each, writes `button.owb_categoryName`
- `GetItemsByCategory()` — groups buttons by their assigned category name
- `GetSortedCategoryNames()` — orders names via `categoryOrder` or `Categories:SortCategories`
- `GetSectionedLayout(itemsByCategory, containerType)` — builds the ordered list of layout entries (categories, section headers, separators) from `displayOrder`, `categorySections`, `sectionOrder`, `categoryModifications.hideIn[containerType]`

### Views

Views are layout strategies. Each has a `Layout(contentFrame, ...)` function that:
1. Receives the content frame, available width, filtered buttons, and a `viewContext`
2. Positions buttons using `SetPoint` and `OWB_SetIconSize`
3. Returns the total content height

**ListView** — Simple grid. Sorts buttons, places in rows. Reagent bag items go after a gap. Stateless.

**CategoryView** — The most complex view. Maintains module-level `labelPool`/`activeLabels` for compact mode headers and groupBy sublabels. Two rendering modes:
- **Stacked** (default): Each category gets a collapsible section frame with header, item count, and content grid. Supports groupBy (expansion, type, slot, quality) within categories. Supports `stackItems` (merging duplicate items).
- **Compact**: Categories pack horizontally like a bin-packing algorithm. Small categories share rows; large ones get full-width lines. Uses font string labels instead of section frames.

**BagView** — One collapsible section per physical bag (Backpack, Bag 1–4, Reagent Bag). Supports single-bag filtering via `selectedBag`.

**BankCategoryView** — Categorizes independently from `CategoryManager`, using `Categories:GetItemCategory` directly on `BankSet` buttons. Supports stacked and compact modes like `CategoryView` but uses a flat category list with pins rather than the section/displayOrder graph. Maintains its own `labelPool`/`activeLabels`.

**BankTabView** — One collapsible section per bank tab (personal or warband depending on `bankShowWarband`). Supports single-tab filtering via `bankSelectedTab`.

**GuildBankTabView** — One collapsible section per guild bank tab. Supports single-tab filtering via `guildBankSelectedTab`.

### WindowLayoutController

A generic orchestrator used by all three windows. Its `Refresh(config)` method accepts a config table with callbacks. This table-driven approach means the controller contains zero window-specific logic—all specifics are injected by the caller.

Key config callbacks:
- `isBuilt()` — guard against layout before slots exist
- `getButtons()` — which set of buttons to lay out
- `filterButtons(buttons)` — search + expansion filtering
- `layoutButtons(filteredButtons)` — delegates to the active View
- `beforeLayout()` / `afterLayout()` — bar visibility, scroll binding, slot counts

### PredicateEngine

A full expression language for item matching. Supports:
- Tokenization → parsing → AST compilation → evaluation
- Property registry: numeric (`ilvl`, `quality`, `expansion`, `count`, `vendorprice`, `bindtype`, `currentbind`, etc.) and string (`name`, `equiploc`)
- Keyword registry: quality, item type, consumable subtypes, equipment, armor subclass, equipment slots, binding, expansion, collectibles, transmog, item state, vendor/value, crafting, upgrades, tooltip-driven, special
- Flag registry: `IsEquipment`, `IsSoulbound`, `IsBOE`, `IsWarbound`, `IsUpgrade`, etc. (verbose `IsXxx` style alternatives to `#keyword` syntax)
- Caching at three levels: compiled expressions, item properties, tooltip text
- Lazy resolution: bind fields and tooltip fields use a metatable `__index` to defer expensive tooltip scans until first access
- Used by: search filtering, builtin category matching, custom category search expressions

### Categories

Defines 27 builtin categories with priority ordering (including special categories like 1W Junk, 1W Upgrades, Recent Items, Other, and Empty). Classification priority:
1. **1W Junk** — OneWoW.ItemStatus junk flagging or Poor quality
2. **1W Upgrades** — item level comparison against equipped gear
3. **Custom categories** — user-defined (by item ID, search expression, or item type)
4. **Builtin addedItems** — manual item-to-builtin-category assignments
5. **Recent Items** — `C_NewItems` or GUID-based timestamp tracking
6. **Search-based builtins** — PredicateEngine evaluation in `searchOrder`
7. **Inventory slot refinement** — Weapons/Armor split into slot-specific categories
8. **Fallback** — "Other"

---

## Window Architecture

Three independent windows share the same structural pattern:

```
Window Shell (OneWoW_GUI:CreateFrame)
  ├─ Title Bar (OneWoW_GUI:CreateTitleBar)
  │   ├─ Brand text, title, close button
  │   └─ Settings button (bags only)
  ├─ Content Area (plain Frame)
  │   ├─ Info Bar (top: view mode buttons, search, expansion filter)
  │   ├─ Scroll Frame (UIPanelScrollFrameTemplate)
  │   │   └─ Content Frame (scroll child)
  │   │       ├─ Section frames (from CategoryManagerBase pool)
  │   │       └─ Item buttons (from ItemPool)
  │   └─ Bottom Bar (bag icons, gold display, trackers)
  └─ Resize handle
```

The guild bank window additionally has a **GuildBankLog** companion panel (`GuildBankLog.lua`) that displays transaction history (items and gold) with per-tab filtering. It positions itself adjacent to the main guild bank window and updates via `GUILDBANKLOG_UPDATE`.

Each window has:
- A `RefreshLayout()` that calls `WindowLayoutController:Refresh` with its specific config
- A `FullReset()` that destroys all frames and rebuilds from scratch (used for theme/language changes)
- Show/Hide/Toggle methods
- An `ApplyTheme()` for live theme switching

### InfoBarFactory

The bags window uses a hand-built `InfoBar` (`GUI\InfoBar.lua`), but the bank and guild bank windows use `InfoBarFactory:Create(config)` (`GUI\InfoBarFactory.lua`) to generate their info bars. The factory accepts a config table specifying the controller, view modes, expansion filter settings, and DB keys. This avoids duplicating info bar construction logic across windows while allowing per-window customization.

### Sorting

`OneWoW_Bags:SortButtons(buttons, overrideSortMode)` sorts item buttons in-place. Supported modes: `none` (no sort), `default` (bag/slot order), `name`, `rarity`, `ilvl`, `type` (class/subclass/equip location), `expansion`. Empty slots are always sorted last.

### Width Calculation

Window width is **fixed per column count**:
```
width = columns × (iconSize + spacing) - spacing + 4 + scrollbarSpace + (2 × outerPadding)
```
The window is not freely resizable horizontally—only the column count setting changes width. Vertical resizing is supported.

---

## Event System

### Event Flow

```
WoW Event → eventFrame:OnEvent
  ├─→ ADDON_LOADED → OnAddonLoaded (one-time init)
  ├─→ PLAYER_LOGIN → OnPlayerLogin (one-time init)
  └─→ All others → runtimeEventHandlers[event]
       └─→ Events:OnXxx → OneWoW_Bags:OnXxx
```

The `Events` table serves as a thin routing layer. It:
- Accumulates `BAG_UPDATE` events into `dirtyBags` (coalescing)
- Processes them on `BAG_UPDATE_DELAYED` (single batch update)
- Delegates everything else directly to `OneWoW_Bags` methods

### Key Event Groups

| Event Group | Handler Chain |
|---|---|
| Bag inventory changes | `BAG_UPDATE` → accumulate → `BAG_UPDATE_DELAYED` → `ProcessBagUpdate` |
| Item lock/cooldown | Direct to button's `OWB_RefreshLock`/`OWB_RefreshCooldown` |
| Bank open/close | `BANKFRAME_OPENED` → `SuppressBankFrame` + show `BankGUI` |
| Guild bank | `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` with `GuildBanker` type |
| Merchant | `MERCHANT_SHOW/CLOSED` → auto-open/close with guard timers |
| Money | `PLAYER_MONEY`/`ACCOUNT_MONEY` → update gold display |
| Quest changes | `QUEST_ACCEPTED`/`QUEST_REMOVED` → `ProcessBagUpdate(BuildAllBagDirtySet())` |
| Predicate invalidation | `EQUIPMENT_SETS_CHANGED`/`PLAYER_EQUIPMENT_CHANGED`/`GET_ITEM_INFO_RECEIVED` → coalesced `C_Timer.After(0)` refresh |

---

## Database Schema

All persisted state lives in `OneWoW_Bags_DB.global`. Key groups:

### Display Settings (Bags)
`viewMode`, `columns`, `bagColumns`, `scale`, `iconSize`, `itemSort`, `compactCategories`, `compactGap`, `categorySpacing`, `showCategoryHeaders`, `showEmptySlots`, `hideScrollBar`, `showBagsBar`, `showMoneyBar`, `showHeaderBar`, `showSearchBar`, `selectedBag`

### Display Settings (Bank / Guild Bank)
`bankViewMode`, `guildBankViewMode`, `bankColumns`, `bankCompactCategories`, `bankCompactGap`, `bankCategorySpacing`, `showBankCategoryHeaders`, `bankHideScrollBar`, `showBankBagsBar`, `showBankSearchBar`, `showBankHeaderBar`, `bankSelectedTab`, `guildBankSelectedTab`, `bankShowWarband`

### Behavior Settings
`autoOpen`, `autoClose`, `autoOpenWithBank`, `locked`, `bankLocked`, `enableBankUI`, `enableBankOverlays`, `altToShow`, `enableExpansionFilter`, `enableBankExpansionFilter`, `enableInventorySlots`, `stackItems`

### Visual Settings
`rarityColor`, `rarityIntensity`, `bankRarityColor`, `showNewItems`, `showUnusableOverlay`, `dimJunkItems`, `stripJunkOverlays`

### Category System
`customCategoriesV2` (table of custom category definitions), `disabledCategories`, `categoryModifications`, `categorySort`, `categoryOrder`, `categorySections`, `sectionOrder`, `displayOrder`, `enableJunkCategory`, `enableUpgradeCategory`, `moveUpgradesToTop`, `moveOtherToBottom`, `pinnedCategories`

### Collapse State
`collapsedSections` (bags categories), `collapsedBagSections` (bags per-bag), `collapsedBankSections`, `collapsedGuildBankSections`, `collapsedBankCategorySections`, `collapsedBankTabSections`, `collapsedGuildBankTabSections`

### Positions
`mainFramePosition`, `bankFramePosition`, `guildBankFramePosition`

### Tracking
`trackedCurrencies`, `recentItems`, `recentItemDuration`

### Migrations
`_migrationVersion` — integer, currently up to 7. Managed by `DB:RunMigrations`.

Migrations: 1 = category system v2 rename, 2 = junk rename, 3 = displayOrder build, 4 = category system v3 (section IDs, duration, pet/mount rename), 5 = itemSort reset, 6 = cleanup legacy flags, 7 = split collapsed bank/guild state into tab vs category keyed tables.

---

## Integration Points

### Addon Compartment
The addon registers `AddonCompartmentFunc`, `AddonCompartmentFuncOnEnter`, and `AddonCompartmentFuncOnLeave` in the TOC for the 12.0+ addon compartment button (accessible from the minimap). Clicking toggles the bags window; hovering shows a tooltip.

### OneWoW Hub Integration
- `RegisterLoadComponent` — registers with hub's addon loader UI
- `RegisterMinimap` — registers minimap button with hub
- `OneWoW.ItemStatus:IsItemJunk` — enhanced junk detection
- `OneWoW.UpgradeDetection:CheckItemUpgrade` — enhanced upgrade detection
- `OneWoW.OverlayEngine` — item button overlays (clean/refresh)
- `OneWoW.SettingsFeatureRegistry` — registers feature flags for settings interop

### OneWoW_GUI Integration
- `DB:Init` / `DB:RunMigrations` / `DB:MergeMissing` — database management
- `CreateFrame`, `CreateTitleBar`, `CreateFitTextButton`, `CreateDialog`, `CreateScrollFrame` — UI components
- `SkinIconFrame`, `UpdateIconQuality`, `StyleScrollBar` — visual skinning
- `GetThemeColor` — theme colors
- `GetSetting` / `SetSetting` — shared settings (theme, language, minimap)
- `RegisterSettingsCallback` — reactive updates on shared setting changes
- `SaveWindowPosition` / `RestoreWindowPosition` — position persistence
- `RegisterGUIConstants` — constant registration

### Item Button Callback API
External addons can register callbacks that fire after every layout refresh:
```lua
OneWoW_Bags:RegisterItemButtonCallback("MyAddon", function(button, bagID, slotID) ... end)
OneWoW_Bags:UnregisterItemButtonCallback("MyAddon")
```
The integration layer hooks `GUI:RefreshLayout`, `BankGUI:RefreshLayout`, and `GuildBankGUI:RefreshLayout` to fire callbacks 50ms after layout completes.

### TSM Integration
`TSMIntegration:Import()` reads TSM group data and converts it to `customCategoriesV2` entries.

### Baganator Import
`CategoryController:ImportBaganator()` reads Baganator profile data and maps its categories/sections to OneWoW_Bags equivalents.

---

## Blizzard Frame Suppression

The addon intercepts Blizzard bag/bank frames to replace them:

### Bags
- `hooksecurefunc` on `OpenBackpack`, `CloseBackpack`, `ToggleAllBags`, `OpenAllBags`, `CloseAllBags`, `OpenBag`, `CloseBag`
- `ContainerFrame1..13` and `ContainerFrameCombinedBags` get `HookScript("OnShow", Hide)`
- Key bindings overridden via `SetOverrideBinding` on a secure button frame

### Bank
- `SuppressBankFrame` — removes scripts, moves offscreen, hides bank container frames (7–13) by reparenting to a hidden frame
- `RestoreBankFrame` — reverses suppression (called when bank UI is disabled)

### Guild Bank
- `SuppressGuildBankFrame` — moves offscreen, sets alpha to 0
- `RestoreGuildBankFrame` — reverses on close

---

## Refresh Targets

The `RequestLayoutRefresh`, `RequestVisualRefresh`, and `RequestWindowReset` methods accept a `target` parameter:

| Target | GUI Keys | Visual Keys |
|---|---|---|
| `"bags"` | `GUI` | `BagSet` |
| `"bank"` | `BankGUI` | `BankSet` |
| `"guild"` | `GuildBankGUI` | `GuildBankSet` |
| `"bank_related"` | `BankGUI`, `GuildBankGUI` | `BankSet`, `GuildBankSet` |
| `"all"` (default) | `GUI`, `BankGUI`, `GuildBankGUI` | `BagSet`, `BankSet`, `GuildBankSet` |

This avoids unnecessary work—a bags-only setting change doesn't refresh bank windows.

---

## Performance Patterns

- **Object pooling**: `ItemPool` (buttons) and `CategoryManagerBase` (sections/dividers) avoid frame creation during layout
- **Dirty flag batching**: `BAG_UPDATE` events accumulate in `dirtyBags`, processed once on `BAG_UPDATE_DELAYED`
- **Multi-level caching**: PredicateEngine caches compiled expressions, item properties, and tooltip text. `Categories` caches `itemID → categoryName`
- **Debounced settings**: `SettingsController:Debounce` delays rapid slider changes (columns, spacing) to avoid layout thrashing
- **Deferred cleanup**: Combat lockdown defers frame cleanup; `PLAYER_REGEN_ENABLED` triggers it afterward
- **Preallocation**: 220 buttons created at login before the window is ever shown
- **Targeted refresh**: Layout/visual refreshes are scoped to the affected window context

---

## Custom Category System

Custom categories support three filter modes:

1. **Item list** — explicit `items[itemID] = true` mapping
2. **Search expression** — PredicateEngine expression (`searchExpression` field), evaluated per item
3. **Type filter** — `itemType` and/or `itemSubType` string matching against `C_Item.GetItemClassInfo`/`GetItemSubClassInfo`, with `typeMatchMode` ("and"/"or")

Categories are organized into:
- **Root categories** — top-level, ordered by `categoryOrder` or sorted by priority
- **Sections** — named groups (`categorySections`) that contain ordered category lists, with collapsible headers
- **Display order** — `displayOrder` array encodes the full layout: categories, `"----"` separators, `"section:ID"` / `"section_end"` markers

---

## View Context Pattern

Views receive a `viewContext` object created by `WindowLayoutController:CreateViewContext`. This decouples views from specific data sources:

```lua
viewContext = {
    sortButtons(buttons, overrideSortMode),  -- sort callback
    acquireSection(parent),                   -- pool acquisition
    acquireSectionHeader(parent),             -- pool acquisition
    acquireDivider(parent),                   -- pool acquisition
    getCollapsed(kind, key),                  -- read collapse state
    setCollapsed(kind, key, collapsed),       -- write + relayout
    requestRelayout(),                        -- trigger refresh
    containerType,                            -- "backpack", "bank", etc.
}
```

This allows the same View code to work with different CategoryManagers, different collapse state tables, and different refresh callbacks depending on which window it's rendering in.
