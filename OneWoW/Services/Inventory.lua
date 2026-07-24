local _, ns = ...

-- ============================================================================
-- Inventory
-- ============================================================================
-- Live bag/bank event funnel for the logged-in character. Mirrors Merchant /
-- ProfessionRecipe: one core service registers the WoW events (only while at
-- least one consumer is subscribed), accumulates dirty bag IDs, and fans out
-- to subscribers. Nothing is persisted here — AltTracker_Storage owns SV
-- writes; Bags owns UI layout; PredicateEngine stays pull/eval.
--
-- Suite-wide owner of bag/bank container events (enforced by core-event-funnel).
-- Guild bank / mail stay with their current owners.
--
-- Channels:
--   RegisterDirtyCallback       fn(bagID)           BAG_UPDATE
--   RegisterDelayedCallback     fn(dirtyBags)       BAG_UPDATE_DELAYED (coalesced set)
--   RegisterBankOpenCallback    fn()                BANKFRAME_OPENED
--   RegisterBankClosedCallback  fn()                BANKFRAME_CLOSED
--   RegisterBankSlotsCallback   fn(event, ...)      bank slot change events
--   RegisterContainerCallback   fn()                BAG_CONTAINER_UPDATE
--   RegisterLockCallback        fn(bagID, slotID)   ITEM_LOCK_CHANGED
--   RegisterCooldownCallback    fn()                BAG_UPDATE_COOLDOWN
--   RegisterBankTabsCallback    fn(bankType, ...)   BANK_TABS_CHANGED
--
-- Scan helpers:
--   BagTypes / BankTypes        container ID vocabulary (subdir modules)
--   GetBagIDs(scope)            resolve scope -> bagID list
--   ForEachSlot(scope, fn)      walk slots; fn may return true to stop
--
-- Full design: OneWoW/Docs/INVENTORY.md
-- ============================================================================

local Inventory = {}
ns.Inventory = Inventory

Inventory.BagTypes = ns.InventoryBagTypes
Inventory.BankTypes = ns.InventoryBankTypes

local pairs, next, type, ipairs = pairs, next, type, ipairs
local wipe, tinsert = wipe, tinsert
local C_Container = C_Container

local PE = ns.PredicateEngine
local BagTypes = Inventory.BagTypes
local BankTypes = Inventory.BankTypes

-- Cached "bank" = personal + warband tab IDs (static Enum ranges).
local allBankBagIDs = {}
for _, bagID in ipairs(BankTypes:GetBankTabIDs()) do
    tinsert(allBankBagIDs, bagID)
end
for _, bagID in ipairs(BankTypes:GetWarbandTabIDs()) do
    tinsert(allBankBagIDs, bagID)
end

local EVENTS = {
    "BAG_UPDATE",
    "BAG_UPDATE_DELAYED",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED",
    "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED",
    "BAG_CONTAINER_UPDATE",
    "ITEM_LOCK_CHANGED",
    "BAG_UPDATE_COOLDOWN",
    "BANK_TABS_CHANGED",
}
local EVENT_OWNER = "Inventory"

-- ownerID -> fn, one table per channel.
local dirtyCallbacks = {}
local delayedCallbacks = {}
local bankOpenCallbacks = {}
local bankClosedCallbacks = {}
local bankSlotsCallbacks = {}
local containerCallbacks = {}
local lockCallbacks = {}
local cooldownCallbacks = {}
local bankTabsCallbacks = {}

local eventsRegistered = false
local bankOpen = false
local dirtyBags = {}

local OnEvent -- forward declaration

local function AnySubscribers()
    return next(dirtyCallbacks) ~= nil
        or next(delayedCallbacks) ~= nil
        or next(bankOpenCallbacks) ~= nil
        or next(bankClosedCallbacks) ~= nil
        or next(bankSlotsCallbacks) ~= nil
        or next(containerCallbacks) ~= nil
        or next(lockCallbacks) ~= nil
        or next(cooldownCallbacks) ~= nil
        or next(bankTabsCallbacks) ~= nil
end

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
        wipe(dirtyBags)
        bankOpen = false
    end
end

local function FireChannel(callbacks, label, ...)
    for ownerID, fn in pairs(callbacks) do
        ns.Lifecycle.SafeCall("Inventory." .. label .. ":" .. ownerID, fn, ...)
    end
end

function OnEvent(event, ...)
    if event == "BAG_UPDATE" then
        local bagID = ...
        if bagID ~= nil then
            dirtyBags[bagID] = true
            FireChannel(dirtyCallbacks, "dirty", bagID)
        end
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        local dirty = dirtyBags
        dirtyBags = {}
        -- Single props wipe per delayed batch for PE consumers.
        PE:InvalidatePropsCache()
        FireChannel(delayedCallbacks, "delayed", dirty)
        return
    end

    if event == "BANKFRAME_OPENED" then
        bankOpen = true
        FireChannel(bankOpenCallbacks, "bankOpen")
        return
    end

    if event == "BANKFRAME_CLOSED" then
        bankOpen = false
        FireChannel(bankClosedCallbacks, "bankClosed")
        return
    end

    if event == "PLAYERBANKSLOTS_CHANGED"
        or event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" then
        FireChannel(bankSlotsCallbacks, "bankSlots", event, ...)
        return
    end

    if event == "BAG_CONTAINER_UPDATE" then
        FireChannel(containerCallbacks, "container")
        return
    end

    if event == "ITEM_LOCK_CHANGED" then
        FireChannel(lockCallbacks, "lock", ...)
        return
    end

    if event == "BAG_UPDATE_COOLDOWN" then
        FireChannel(cooldownCallbacks, "cooldown")
        return
    end

    if event == "BANK_TABS_CHANGED" then
        FireChannel(bankTabsCallbacks, "bankTabs", ...)
    end
end

local function Subscribe(tbl, ownerID, fn)
    if type(ownerID) ~= "string" or type(fn) ~= "function" then
        error("OneWoW.Inventory register: (ownerID string, fn function) required", 3)
    end
    tbl[ownerID] = fn
    EnsureEvents()
end

--- Subscribe to per-bag BAG_UPDATE marks (before the delayed coalesce).
---@param ownerID string stable id; re-registering replaces the prior handler
---@param fn fun(bagID: number)
function Inventory.RegisterDirtyCallback(ownerID, fn)
    Subscribe(dirtyCallbacks, ownerID, fn)
end

--- Subscribe to BAG_UPDATE_DELAYED with the coalesced dirty bag set.
--- `dirtyBags` is a map of bagID -> true for bags touched since the last delayed
--- fire (may be empty if DELAYED arrived without a prior BAG_UPDATE).
---@param ownerID string
---@param fn fun(dirtyBags: table)
function Inventory.RegisterDelayedCallback(ownerID, fn)
    Subscribe(delayedCallbacks, ownerID, fn)
end

--- Subscribe to BANKFRAME_OPENED.
---@param ownerID string
---@param fn fun()
function Inventory.RegisterBankOpenCallback(ownerID, fn)
    Subscribe(bankOpenCallbacks, ownerID, fn)
end

--- Subscribe to BANKFRAME_CLOSED.
---@param ownerID string
---@param fn fun()
function Inventory.RegisterBankClosedCallback(ownerID, fn)
    Subscribe(bankClosedCallbacks, ownerID, fn)
end

--- Subscribe to personal/warband bank slot change events.
---@param ownerID string
---@param fn fun(event: string, ...)
function Inventory.RegisterBankSlotsCallback(ownerID, fn)
    Subscribe(bankSlotsCallbacks, ownerID, fn)
end

--- Subscribe to BAG_CONTAINER_UPDATE (equipped bag slot count / container changes).
---@param ownerID string
---@param fn fun()
function Inventory.RegisterContainerCallback(ownerID, fn)
    Subscribe(containerCallbacks, ownerID, fn)
end

--- Subscribe to ITEM_LOCK_CHANGED.
---@param ownerID string
---@param fn fun(bagID: number|nil, slotID: number|nil)
function Inventory.RegisterLockCallback(ownerID, fn)
    Subscribe(lockCallbacks, ownerID, fn)
end

--- Subscribe to BAG_UPDATE_COOLDOWN.
---@param ownerID string
---@param fn fun()
function Inventory.RegisterCooldownCallback(ownerID, fn)
    Subscribe(cooldownCallbacks, ownerID, fn)
end

--- Subscribe to BANK_TABS_CHANGED.
---@param ownerID string
---@param fn fun(bankType: any, ...)
function Inventory.RegisterBankTabsCallback(ownerID, fn)
    Subscribe(bankTabsCallbacks, ownerID, fn)
end

--- Drop all channel subscriptions for an owner. May unregister the shared events
--- when the last subscriber leaves.
---@param ownerID string
function Inventory.UnregisterCallback(ownerID)
    dirtyCallbacks[ownerID] = nil
    delayedCallbacks[ownerID] = nil
    bankOpenCallbacks[ownerID] = nil
    bankClosedCallbacks[ownerID] = nil
    bankSlotsCallbacks[ownerID] = nil
    containerCallbacks[ownerID] = nil
    lockCallbacks[ownerID] = nil
    cooldownCallbacks[ownerID] = nil
    bankTabsCallbacks[ownerID] = nil
    EnsureEvents()
end

--- Live character/warband bank-open state from BANKFRAME_OPENED / CLOSED.
---@return boolean open
function Inventory.IsBankOpen()
    return bankOpen
end

--- Resolve a scope to a list of bag IDs.
--- Named scopes: "player" | "personal" | "warband" | "bank" (personal+warband).
--- Also accepts a dirtyBags map (bagID -> true) or an array of bag IDs.
---@param scope string|table
---@return number[] bagIDs
function Inventory.GetBagIDs(scope)
    if scope == "player" then
        return BagTypes:GetPlayerBagIDs()
    elseif scope == "personal" then
        return BankTypes:GetBankTabIDs()
    elseif scope == "warband" then
        return BankTypes:GetWarbandTabIDs()
    elseif scope == "bank" then
        return allBankBagIDs
    elseif type(scope) == "table" then
        if type(scope[1]) == "number" then
            return scope
        end
        local ids = {}
        for bagID in pairs(scope) do
            tinsert(ids, bagID)
        end
        return ids
    end
    error("OneWoW.Inventory.GetBagIDs: scope must be a named string or bagID table", 2)
end

--- Walk every slot in the resolved bags. `fn(bagID, slotID, containerInfo)` —
--- `containerInfo` may be nil for empty slots. Return true from `fn` to stop.
---@param scope string|table
---@param fn fun(bagID: number, slotID: number, containerInfo: table|nil): boolean|nil
function Inventory.ForEachSlot(scope, fn)
    if type(fn) ~= "function" then
        error("OneWoW.Inventory.ForEachSlot: fn function required", 2)
    end
    local bagIDs = Inventory.GetBagIDs(scope)
    for i = 1, #bagIDs do
        local bagID = bagIDs[i]
        local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
        for slotID = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagID, slotID)
            if fn(bagID, slotID, info) then
                return
            end
        end
    end
end
