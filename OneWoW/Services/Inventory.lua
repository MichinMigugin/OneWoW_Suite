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
-- Phase 1 owns a subset of bag/bank events. Bags and Storage still register
-- the same events until later migration phases; core-event-funnel enforcement
-- lands only after Bags is off these events.
--
-- Channels:
--   RegisterDirtyCallback      fn(bagID)           BAG_UPDATE
--   RegisterDelayedCallback    fn(dirtyBags)       BAG_UPDATE_DELAYED (coalesced set)
--   RegisterBankOpenCallback   fn()                BANKFRAME_OPENED
--   RegisterBankClosedCallback fn()                BANKFRAME_CLOSED
--   RegisterBankSlotsCallback  fn(event, ...)      bank slot change events
--
-- Full design: OneWoW/Docs/INVENTORY.md
-- ============================================================================

local Inventory = {}
ns.Inventory = Inventory

local pairs, next, type, ipairs = pairs, next, type, ipairs
local wipe = wipe

local PE = ns.PredicateEngine

local EVENTS = {
    "BAG_UPDATE",
    "BAG_UPDATE_DELAYED",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED",
    "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED",
}
local EVENT_OWNER = "Inventory"

-- ownerID -> fn, one table per channel.
local dirtyCallbacks = {}
local delayedCallbacks = {}
local bankOpenCallbacks = {}
local bankClosedCallbacks = {}
local bankSlotsCallbacks = {}

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

local function FireDirty(bagID)
    for ownerID, fn in pairs(dirtyCallbacks) do
        ns.Lifecycle.SafeCall("Inventory.dirty:" .. ownerID, fn, bagID)
    end
end

local function FireDelayed(dirty)
    for ownerID, fn in pairs(delayedCallbacks) do
        ns.Lifecycle.SafeCall("Inventory.delayed:" .. ownerID, fn, dirty)
    end
end

local function FireBankOpen()
    for ownerID, fn in pairs(bankOpenCallbacks) do
        ns.Lifecycle.SafeCall("Inventory.bankOpen:" .. ownerID, fn)
    end
end

local function FireBankClosed()
    for ownerID, fn in pairs(bankClosedCallbacks) do
        ns.Lifecycle.SafeCall("Inventory.bankClosed:" .. ownerID, fn)
    end
end

local function FireBankSlots(event, ...)
    for ownerID, fn in pairs(bankSlotsCallbacks) do
        ns.Lifecycle.SafeCall("Inventory.bankSlots:" .. ownerID, fn, event, ...)
    end
end

function OnEvent(event, ...)
    if event == "BAG_UPDATE" then
        local bagID = ...
        if bagID ~= nil then
            dirtyBags[bagID] = true
            FireDirty(bagID)
        end
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        local dirty = dirtyBags
        dirtyBags = {}
        -- Single props wipe per delayed batch for PE consumers (Overlays, autoopen, …).
        -- Bags still invalidates on its own path until Phase 4; double wipe is harmless.
        PE:InvalidatePropsCache()
        FireDelayed(dirty)
        return
    end

    if event == "BANKFRAME_OPENED" then
        bankOpen = true
        FireBankOpen()
        return
    end

    if event == "BANKFRAME_CLOSED" then
        bankOpen = false
        FireBankClosed()
        return
    end

    if event == "PLAYERBANKSLOTS_CHANGED"
        or event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" then
        FireBankSlots(event, ...)
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

--- Drop all channel subscriptions for an owner. May unregister the shared events
--- when the last subscriber leaves.
---@param ownerID string
function Inventory.UnregisterCallback(ownerID)
    dirtyCallbacks[ownerID] = nil
    delayedCallbacks[ownerID] = nil
    bankOpenCallbacks[ownerID] = nil
    bankClosedCallbacks[ownerID] = nil
    bankSlotsCallbacks[ownerID] = nil
    EnsureEvents()
end

--- Live character/warband bank-open state from BANKFRAME_OPENED / CLOSED.
---@return boolean open
function Inventory.IsBankOpen()
    return bankOpen
end
