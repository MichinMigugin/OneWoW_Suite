local _, ns = ...

-- ============================================================================
-- Overlays 2.0 — engine
-- ============================================================================
-- Matching + orchestration layer. Every user overlay is a compiled
-- PredicateEngine expression evaluated against PE:BuildProps; the "upgrade"
-- built-in stays detector-backed (ns.UpgradeDetection). At most
-- MAX_ICON_OVERLAYS icon overlays paint per button (priority = entry order);
-- item level and the quality border render independently of the cap.
--
-- Published as ns.OverlayEngine / OneWoW.OverlayEngine with the same
-- integration surface as the 1.0 engine (RegisterIntegration, ProcessButton,
-- CleanButton, Refresh, RequestRefresh), so external bag integrations work
-- unchanged. Surface hooks live in surfaces.lua.
--
-- Refresh contract:
--   RequestRefresh / Refresh — surface layout (item identity already drives
--     paint). Same-item skip_same may no-op when paintGeneration is unchanged.
--   InvalidateAndRequestRefresh — external predicate inputs changed
--     (collection journals, recipe learned, junk/protected, shopping list).
--     Wipes PE props, bumps paintGeneration so skip_same cannot strand stale
--     icons, then coalesced Refresh. Quality Border stays flash-safe via
--     keepQualityBorder + qb_noop on same-item rebuilds.
--   RebuildDefinitions — PE keyword set changed (late RegisterKeyword).
--     Nils compiled defs then InvalidateAndRequestRefresh.
-- ============================================================================

local PE = ns.PredicateEngine
local Defs = ns.Overlays2Defs
local Renderer = ns.Overlays2Renderer
local Registry = ns.SettingsFeatureRegistry
local ItemLevel = ns.ItemLevel

ns.OverlayEngine = {}
local Engine = ns.OverlayEngine

local ipairs, tinsert = ipairs, tinsert

local BATTLE_PET_CAGE_ID = 82800

-- Bumped when overlay definitions rebuild or external predicate inputs change
-- (InvalidateAndRequestRefresh) so same-item early-out cannot skip a needed
-- icon rebuild. Unchanged across guild-bank tab-query storms.
local paintGeneration = 0

-- LOAD-BEARING INVARIANT: this table is created at file-parse time (not inside
-- Initialize) and RegisterIntegration is an append-only insert with no
-- dependency on Initialize-created state. Bag integrations wire themselves via
-- ns:RegisterAddonLoadedWatcher, which fires BEFORE Engine:Initialize() runs.
-- Do NOT move this table's creation into Initialize.
Engine.integrationRefreshCallbacks = {}

function Engine:RegisterIntegration(fn)
    tinsert(self.integrationRefreshCallbacks, fn)
end

-- Surface refreshers (bags/bank/vendor/... passes) register here from
-- surfaces.lua; RefreshAll runs every one of them.
Engine.surfaceRefreshers = {}

function Engine:RegisterSurfaceRefresher(fn)
    tinsert(self.surfaceRefreshers, fn)
end

-- ----------------------------------------------------------------------------
-- Settings access
-- ----------------------------------------------------------------------------

local function IsGlobalEnabled()
    return Registry:IsEnabled("overlays", "general")
end

Engine.IsGlobalEnabled = IsGlobalEnabled

local function GetItemLevelCfg()
    return Registry:GetFeatureSettings("overlays", "itemlevel")
end

local function GetQualityBorderCfg()
    return Registry:GetFeatureSettings("overlays", "qualityborder")
end

-- Active definition list, rebuilt lazily after any overlays settings change.
local activeDefs = nil

local function GetActiveDefs()
    if not activeDefs then
        activeDefs = Defs:BuildActiveList()
    end
    return activeDefs
end

--- Compile errors from the last active-list build (settings UI surface).
---@return table<string, string> id -> error message
function Engine:GetCompileErrors()
    return GetActiveDefs().errors
end

--- True when any active overlay (or built-in) paints on the given surface
--- flag ("applyToVendorItems" / "applyToAuctionHouse").
local function AnySurfaceEnabled(flagKey)
    for _, def in ipairs(GetActiveDefs()) do
        if def.entry[flagKey] then return true end
    end
    if GetItemLevelCfg().enabled and GetItemLevelCfg()[flagKey] then return true end
    if GetQualityBorderCfg().enabled and GetQualityBorderCfg()[flagKey] then return true end
    return false
end

function Engine:AnyVendorOverlayEnabled()
    return AnySurfaceEnabled("applyToVendorItems")
end

function Engine:AnyAHOverlayEnabled()
    return AnySurfaceEnabled("applyToAuctionHouse")
end

-- ----------------------------------------------------------------------------
-- Matching
-- ----------------------------------------------------------------------------

local CONTEXT_FLAG = {
    vendor       = "applyToVendorItems",
    auctionhouse = "applyToAuctionHouse",
}

local function DefAppliesToContext(def, context)
    local flagKey = context and CONTEXT_FLAG[context]
    if not flagKey then return true end
    return def.entry[flagKey] == true
end

--- Evaluate all active definitions for one item. Returns an array of matched
--- defs, capped at MAX_ICON_OVERLAYS (priority = list order).
local function EvaluateMatches(itemID, itemLink, itemLocation, context)
    local matches = {}
    local bagID, slotID
    if itemLocation and itemLocation.IsBagAndSlot and itemLocation:IsBagAndSlot() then
        bagID, slotID = itemLocation:GetBagAndSlot()
    end

    local props
    for _, def in ipairs(GetActiveDefs()) do
        if #matches >= Defs.MAX_ICON_OVERLAYS then break end
        if DefAppliesToContext(def, context) then
            if def.upgrade then
                if itemLocation and C_Item.DoesItemExist(itemLocation)
                    and ns.UpgradeDetection:CheckItemUpgrade(itemLink, itemLocation) then
                    tinsert(matches, def)
                end
            else
                props = props or PE:BuildProps(itemID, bagID, slotID, itemLink)
                if PE:SafeEvaluate(def.compiled, props) then
                    tinsert(matches, def)
                end
            end
        end
    end
    return matches
end

-- ----------------------------------------------------------------------------
-- Paint config normalization
-- ----------------------------------------------------------------------------

-- User overlays store the 2.0 shape (icon table, bg table); the upgrade
-- built-in keeps its 1.0 flat keys (icon string, iconColor, bgEnabled, ...).
local function BuildPaint(def)
    local entry = def.entry
    if def.upgrade then
        return {
            iconSpec = { kind = "list", value = entry.icon or "Professions-Icon-Quality-Tier3-Small", tint = entry.iconColor },
            position = entry.position,
            scale = entry.scale,
            alpha = entry.alpha,
            effect = entry.effect,
            bg = entry.bgEnabled and {
                enabled = true,
                style = entry.bgStyle,
                scale = entry.bgScale,
                color = entry.bgColor,
                useRarityColor = entry.bgUseRarityColor,
                effect = entry.bgEffect,
            } or nil,
        }
    end
    return {
        iconSpec = entry.icon,
        position = entry.position,
        scale = entry.scale,
        alpha = entry.alpha,
        effect = entry.effect,
        bg = entry.bg,
    }
end

-- ----------------------------------------------------------------------------
-- Item level helpers
-- ----------------------------------------------------------------------------

local function GetPetLevelFromLink(itemLink)
    local level = itemLink:match("|Hbattlepet:%d+:(%d+)")
    return level and tonumber(level)
end

--- Value shown by the item level overlay for this item, or nil to skip it:
--- pet level for battle pets, slot count for containers, ilvl for equipment.
local function ComputeItemLevelText(cfg, itemLink, classID, itemLocation)
    local isPetItem = (classID == Enum.ItemClass.Battlepet)
        or (itemLink:find("|Hbattlepet:") ~= nil)
    local isContainer = (classID == Enum.ItemClass.Container)

    if isPetItem then
        if cfg.showPetLevel == false then return nil end
        local level = GetPetLevelFromLink(itemLink)
        if not level or level == 0 then return nil end
        return level
    end

    if isContainer then
        if cfg.showContainerSlots == false then return nil end
        local itemID = C_Item.GetItemInfoInstant(itemLink)
        local slots = ItemLevel.GetContainerSlotCount(itemID)
        if not slots or slots == 0 then return nil end
        return slots
    end

    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemLink)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP"
        or equipLoc == "INVTYPE_NON_EQUIP_IGNORE" then
        return nil
    end

    local ilvl = ItemLevel.Get(itemLink, itemLocation)
    if not ilvl then return nil end
    return ilvl
end

local function BuiltinAppliesToContext(cfg, context)
    local flagKey = context and CONTEXT_FLAG[context]
    if not flagKey then return true end
    return cfg[flagKey] == true
end

-- ----------------------------------------------------------------------------
-- Button pipeline
-- ----------------------------------------------------------------------------

local function SyncItemContextMatching(button)
    -- BankDepositing (and other) context can stick at Mismatch after an early
    -- eval; re-sync once overlay paint runs (including async ContinueOnItemLoad).
    if button.UpdateItemContextMatching then
        button:UpdateItemContextMatching()
    end
end

local function PaintButton(button, itemID, itemLink, itemLocation, context, classID)
    local matches = EvaluateMatches(itemID, itemLink, itemLocation, context)
    for i, def in ipairs(matches) do
        Renderer:ApplyOverlay(button, BuildPaint(def), i, itemLink)
    end

    local quality = select(3, C_Item.GetItemInfo(itemLink))

    local ilvlCfg = GetItemLevelCfg()
    if ilvlCfg.enabled and BuiltinAppliesToContext(ilvlCfg, context) then
        local text = ComputeItemLevelText(ilvlCfg, itemLink, classID, itemLocation)
        if text then
            Renderer:ApplyItemLevel(button, ilvlCfg, text, quality)
        end
    end

    local qbCfg = GetQualityBorderCfg()
    if qbCfg.enabled and BuiltinAppliesToContext(qbCfg, context) then
        -- Only paint when quality is known. Avoid ApplyQualityBorder(nil) which
        -- hides an existing border during async item-info / re-layout passes.
        if quality then
            Renderer:ApplyQualityBorder(button, qbCfg, quality)
        end
    else
        Renderer:HideQualityBorder(button)
    end

    Renderer:ShowContainer(button)
    button._owbOverlayPaintGen = paintGeneration
    SyncItemContextMatching(button)
end

local function BuildOverlaysForButton(button, itemLink, itemLocation, context)
    if not button or not itemLink then
        Renderer:CleanButton(button)
        return
    end

    local objType = button.GetObjectType and button:GetObjectType()
    if objType == "Texture" or objType == "FontString" then
        return
    end

    if not IsGlobalEnabled() then
        Renderer:CleanButton(button)
        return
    end

    local isBattlePetLink = itemLink:find("|Hbattlepet:") ~= nil
    local itemID, classID

    if isBattlePetLink then
        itemID  = BATTLE_PET_CAGE_ID
        classID = Enum.ItemClass.Battlepet
    else
        itemID = C_Item.GetItemInfoInstant(itemLink)
    end

    if not itemID then
        Renderer:CleanButton(button)
        return
    end

    -- Same-item repaint: compare by itemID (guild bank links can change string
    -- when tab data finishes loading). Full link equality falsely fails and
    -- hides→shows the Quality Border (~1s tooltip catchup flash).
    local sameItem = false
    if button.onewow_itemLink and itemID then
        if isBattlePetLink then
            sameItem = button.onewow_itemLink == itemLink
        else
            sameItem = C_Item.GetItemInfoInstant(button.onewow_itemLink) == itemID
        end
    end

    -- Guild bank tab-query waves re-fire ProcessButton on unchanged slots.
    -- Skip Clean+rebuild when this generation already painted this item and
    -- Quality Border is either done (and still shown) or not required. Settings
    -- rebuild bumps paintGeneration so live updates still repaint.
    -- Require IsShown(): layout cleanup Hide()s buttons and can leave the QB
    -- child hidden while _owbQbQuality stays set — skip_same must not strand it.
    if sameItem
        and button._owbOverlayPaintGen == paintGeneration
        and C_Item.IsItemDataCachedByID(itemID) then
        local qbCfg = GetQualityBorderCfg()
        local needsQb = qbCfg.enabled and BuiltinAppliesToContext(qbCfg, context)
        local qbFrame = button.onewow_qualityBorderFrame
        local qbOk = not needsQb
            or (button._owbQbQuality and qbFrame and qbFrame:IsShown())
        if qbOk then
            local flashNote = OneWoW._overlayFlashNote
            if flashNote then
                flashNote("skip_same")
            end
            button.onewow_itemLink = itemLink
            if needsQb and qbFrame then
                qbFrame:SetFrameLevel(button:GetFrameLevel() + 1)
            end
            return
        end
    end

    Renderer:CleanButton(button, sameItem)
    button.onewow_itemLink = itemLink

    if not classID then
        local _, _, _, _, _, cID = C_Item.GetItemInfoInstant(itemLink)
        classID = cID
    end

    if C_Item.IsItemDataCachedByID(itemID) then
        PaintButton(button, itemID, itemLink, itemLocation, context, classID)
    else
        local flashNote = OneWoW._overlayFlashNote
        if flashNote then
            flashNote("async_sched", { itemID = itemID })
        end
        C_Item.RequestLoadItemDataByID(itemID)
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            if not IsGlobalEnabled() then return end
            -- Re-check the button still shows this item (async load can
            -- outlive a slot change).
            if button.onewow_itemLink ~= itemLink then return end
            local note = OneWoW._overlayFlashNote
            if note then
                note("async_paint", { itemID = itemID })
            end
            local _, _, _, _, _, cID = C_Item.GetItemInfoInstant(itemLink)
            PaintButton(button, itemID, itemLink, itemLocation, context, cID)
        end)
    end
end

-- ----------------------------------------------------------------------------
-- Public API
-- ----------------------------------------------------------------------------

function Engine:ProcessButton(button, link, location, context)
    BuildOverlaysForButton(button, link, location, context)
end

function Engine:CleanButton(button)
    Renderer:CleanButton(button)
end

function Engine:HideQualityBorder(button)
    Renderer:HideQualityBorder(button)
end

local function RefreshAll()
    for _, fn in ipairs(Engine.surfaceRefreshers) do
        fn()
    end
    for _, fn in ipairs(Engine.integrationRefreshCallbacks) do
        fn()
    end
end

function Engine:Refresh()
    RefreshAll()
end

local refreshPending = false

--- Coalescing variant of Refresh: any number of requests inside one debounce
--- window produce a single repaint. Preferred entry point for settings-driven
--- refreshes (slider drags fire dozens of mutations per second).
function Engine:RequestRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.05, function()
        refreshPending = false
        RefreshAll()
    end)
end

--- Wipe PE props, bump paintGeneration, then RequestRefresh.
--- Use when overlay predicate inputs changed without a slot item swap
--- (collection status, recipe known, junk/protected). Bare RequestRefresh
--- alone hits skip_same and leaves stale icons.
function Engine:InvalidateAndRequestRefresh()
    PE:InvalidatePropsCache()
    paintGeneration = paintGeneration + 1
    Engine:RequestRefresh()
end

--- Drop cached overlay definitions so they recompile against the current
--- keyword set, then invalidate paint. Call after PE:RegisterKeyword when a
--- shipped overlay preset uses that keyword (late registration otherwise
--- leaves compiled defs stuck as always-false).
function Engine:RebuildDefinitions()
    activeDefs = nil
    Engine:InvalidateAndRequestRefresh()
end

-- Rebuild definitions and repaint whenever any overlay setting changes,
-- regardless of which UI mutated it.
Registry:RegisterListener("OverlayEngine", function(storageTab)
    if storageTab == "overlays" then
        activeDefs = nil
        paintGeneration = paintGeneration + 1
        Engine:RequestRefresh()
    end
end)
