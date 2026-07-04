local _, ns = ...

-- ============================================================================
-- ProfessionRecipe
-- ============================================================================
-- The single suite-wide owner of the TRADE_SKILL_* / NEW_RECIPE_LEARNED event
-- funnel for recipe scanning. Before this service, four unrelated listeners
-- (AltTracker Professions, Catalog Tradeskills, core RecipeKnownUtil, plus
-- Blizzard) each registered their own frame with different debounce timings and
-- profession-name handling, which produced races and corrupted SavedVariables
-- keys (empty-string buckets, cross-contaminated recipe sets).
--
-- Consumers subscribe on login (via the Facade global OneWoW.ProfessionRecipe)
-- and receive ephemeral scan snapshots. Nothing here is persisted: the snapshot
-- carries the numeric profession identity + the learned recipe IDs so each
-- consumer resolves and stores in its own scope. Events are only registered
-- while at least one consumer is subscribed.
--
-- Channels:
--   RegisterScanCallback  fn(scan)     recipe IDs + item map (debounced, ready-gated)
--   RegisterOpenCallback  fn(context)  "window ready" trigger for live-query collectors
--   RegisterClosedCallback fn()        TRADE_SKILL_CLOSE teardown
-- ============================================================================

local ProfessionRecipe = {}
ns.ProfessionRecipe = ProfessionRecipe

local OneWoW_GUI = OneWoW_GUI

local C_TradeSkillUI = C_TradeSkillUI
local C_Timer = C_Timer
local ipairs, pairs, next, time, tonumber = ipairs, pairs, next, time, tonumber

local EVENTS = {
    "TRADE_SKILL_SHOW",
    "TRADE_SKILL_LIST_UPDATE",
    "TRADE_SKILL_CLOSE",
    "NEW_RECIPE_LEARNED",
}
local EVENT_OWNER = "ProfessionRecipe"
local DEBOUNCE = 0.25

-- ownerID -> fn, one table per channel.
local scanCallbacks = {}
local openCallbacks = {}
local closedCallbacks = {}

local eventsRegistered = false
local lastScan = nil
local scanTimer = nil

local OnEvent -- forward declaration (referenced by EnsureEvents)

local function AnySubscribers()
    return next(scanCallbacks) ~= nil
        or next(openCallbacks) ~= nil
        or next(closedCallbacks) ~= nil
end

-- Lazily register the shared core-frame events on 0->1 subscribers and tear them
-- down on 1->0. RecipeKnownUtil (core) is normally always subscribed, so this is
-- primarily a correctness/single-owner mechanism, not a perf optimization.
local function EnsureEvents()
    if AnySubscribers() then
        if not eventsRegistered then
            eventsRegistered = true
            for _, event in ipairs(EVENTS) do
                ns.RegisterEvent(event, EVENT_OWNER, OnEvent)
            end
        end
    elseif eventsRegistered then
        eventsRegistered = false
        for _, event in ipairs(EVENTS) do
            ns.UnregisterEvent(event, EVENT_OWNER)
        end
        if scanTimer then
            scanTimer:Cancel()
            scanTimer = nil
        end
        lastScan = nil
    end
end

-- Build an ephemeral snapshot of the currently open profession. Re-reads the
-- base profession info on every scan so a fast window switch can never attribute
-- one profession's recipes to another (the original cross-contamination bug).
local function BuildScan()
    local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    if not baseInfo then return nil end

    local learned = {}
    local itemMap = {}

    local ids = C_TradeSkillUI.GetAllRecipeIDs()
    if ids then
        for _, recipeID in ipairs(ids) do
            local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
            if info and info.learned then
                learned[recipeID] = true
            end

            local link = C_TradeSkillUI.GetRecipeItemLink(recipeID)
            if link then
                local itemID = tonumber(link:match("item:(%d+)"))
                if itemID then
                    itemMap[itemID] = recipeID
                end
            end
        end
    end

    return {
        charKey = OneWoW_GUI:GetCharacterKey(),
        baseInfo = {
            professionID = baseInfo.professionID,
            professionName = baseInfo.professionName,
            parentProfessionID = baseInfo.parentProfessionID,
            parentProfessionName = baseInfo.parentProfessionName,
            skillLevel = baseInfo.skillLevel,
            maxSkillLevel = baseInfo.maxSkillLevel,
        },
        learned = learned,
        itemMap = itemMap,
        scannedAt = time(),
    }
end

local function FireOpen(context)
    for ownerID, fn in pairs(openCallbacks) do
        ns.Lifecycle.SafeCall("ProfessionRecipe.open:" .. ownerID, fn, context)
    end
end

local function FireScan(scan)
    for ownerID, fn in pairs(scanCallbacks) do
        ns.Lifecycle.SafeCall("ProfessionRecipe.scan:" .. ownerID, fn, scan)
    end
end

local function FireClosed()
    for ownerID, fn in pairs(closedCallbacks) do
        ns.Lifecycle.SafeCall("ProfessionRecipe.closed:" .. ownerID, fn)
    end
end

-- Debounced scan body. Ready-gated: the child/category/recipe APIs only return
-- valid data while the trade-skill window is fully loaded.
local function DoScan()
    scanTimer = nil
    if not C_TradeSkillUI.IsTradeSkillReady() then return end

    local scan = BuildScan()
    if not scan then return end

    lastScan = scan
    FireOpen({
        charKey = scan.charKey,
        baseInfo = scan.baseInfo,
        scannedAt = scan.scannedAt,
    })
    FireScan(scan)
end

local function ArmScan()
    if scanTimer then scanTimer:Cancel() end
    scanTimer = C_Timer.NewTimer(DEBOUNCE, DoScan)
end

function OnEvent(event)
    if event == "TRADE_SKILL_CLOSE" then
        if scanTimer then
            scanTimer:Cancel()
            scanTimer = nil
        end
        FireClosed()
        return
    end
    -- TRADE_SKILL_SHOW / TRADE_SKILL_LIST_UPDATE / NEW_RECIPE_LEARNED all coalesce
    -- into one re-armed scan.
    ArmScan()
end

local function Subscribe(tbl, ownerID, fn)
    if type(ownerID) ~= "string" or type(fn) ~= "function" then
        error("OneWoW.ProfessionRecipe register: (ownerID string, fn function) required", 3)
    end
    tbl[ownerID] = fn
    EnsureEvents()
    -- Catch-up: if a profession window is already open when a consumer subscribes,
    -- deliver the current state on the next debounce tick.
    if C_TradeSkillUI.IsTradeSkillReady() then
        ArmScan()
    end
end

--- Subscribe to recipe scan snapshots (learned IDs + item map).
---@param ownerID string stable id; re-registering replaces the prior handler
---@param fn fun(scan: table)
function ProfessionRecipe.RegisterScanCallback(ownerID, fn)
    Subscribe(scanCallbacks, ownerID, fn)
end

--- Subscribe to the "profession window ready" trigger for live-query collectors
--- that read the trade-skill APIs directly and do not need recipe IDs.
---@param ownerID string
---@param fn fun(context: table)
function ProfessionRecipe.RegisterOpenCallback(ownerID, fn)
    Subscribe(openCallbacks, ownerID, fn)
end

--- Subscribe to TRADE_SKILL_CLOSE for transient-state teardown.
---@param ownerID string
---@param fn fun()
function ProfessionRecipe.RegisterClosedCallback(ownerID, fn)
    Subscribe(closedCallbacks, ownerID, fn)
end

--- Drop all channel subscriptions for an owner. May unregister the shared events
--- when the last subscriber leaves.
---@param ownerID string
function ProfessionRecipe.UnregisterCallback(ownerID)
    scanCallbacks[ownerID] = nil
    openCallbacks[ownerID] = nil
    closedCallbacks[ownerID] = nil
    EnsureEvents()
end

--- The most recent ephemeral scan snapshot, or nil if none this session.
---@return table|nil scan
function ProfessionRecipe.GetLastScan()
    return lastScan
end
