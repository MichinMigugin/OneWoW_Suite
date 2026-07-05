local _, ns = ...

-- ============================================================================
-- Merchant
-- ============================================================================
-- The single suite-wide owner of the MERCHANT_SHOW / MERCHANT_UPDATE /
-- MERCHANT_CLOSED event funnel. Mirrors OneWoW.ProfessionRecipe: one core
-- service registers the events (only while at least one consumer is
-- subscribed), coalesces repaints into a debounced scan, and fans ephemeral
-- snapshots out to subscribers. Nothing is persisted in core -- each LoD
-- consumer (CatalogData_Vendors merge, Notes wishlist capture, …) resolves and
-- stores in its own scope.
--
-- Before this service, every merchant listener (VendorScanner, overlay-engine,
-- Accounting VendorTracker, Bags, QoL auto-repair/auto-open/vendor-panel) spun
-- up its own frame with its own MERCHANT_* registration and ad-hoc debounce
-- (VendorScanner's `scanInProgress` flag was set/cleared synchronously and
-- never actually debounced -- MERCHANT_SHOW's 0.5s scan and MERCHANT_UPDATE
-- scans routinely double-fired). Consumers migrate onto the channels below in
-- v2-G; this file is the funnel they target.
--
-- Channels:
--   RegisterScanCallback   fn(scan)  vendor snapshot (coalesced debounce, retry)
--   RegisterShowCallback   fn()      MERCHANT_SHOW, synchronous, no debounce
--   RegisterClosedCallback fn()      MERCHANT_CLOSED teardown
-- ============================================================================

local Merchant = {}
ns.Merchant = Merchant

local C_Timer = C_Timer
local C_Map = C_Map
local C_MerchantFrame = C_MerchantFrame
local C_CurrencyInfo = C_CurrencyInfo
local C_Item = C_Item
local MerchantFrame = MerchantFrame
local ipairs, pairs, next, time, tonumber, type = ipairs, pairs, next, time, tonumber, type
local floor = math.floor
local pcall, tinsert = pcall, tinsert
local UnitGUID, UnitName = UnitGUID, UnitName
local UnitCreatureType, UnitClassification, UnitLevel = UnitCreatureType, UnitClassification, UnitLevel
local GetSubZoneText, GetZoneText = GetSubZoneText, GetZoneText
local GetMerchantNumItems, GetMerchantItemLink, GetMerchantItemID = GetMerchantNumItems, GetMerchantItemLink, GetMerchantItemID
local GetMerchantItemCostInfo, GetMerchantItemCostItem = GetMerchantItemCostInfo, GetMerchantItemCostItem

local EVENTS = {
    "MERCHANT_SHOW",
    "MERCHANT_UPDATE",
    "MERCHANT_CLOSED",
}
local EVENT_OWNER = "Merchant"
local DEBOUNCE = 0.25
-- One deferred rescan per merchant session covers first-ever visits where the
-- item link / cost data is still uncached at first scan.
local RETRY_DELAY = 0.5

-- ownerID -> fn, one table per channel.
local scanCallbacks = {}
local showCallbacks = {}
local closedCallbacks = {}

local eventsRegistered = false
local lastScan = nil
local scanTimer = nil
local retryScheduled = false

local OnEvent -- forward declaration (referenced by EnsureEvents)

-- All channels share one refcount: a show/closed-only subscriber still needs the
-- events live, so any subscription keeps the funnel registered.
local function AnySubscribers()
    return next(scanCallbacks) ~= nil
        or next(showCallbacks) ~= nil
        or next(closedCallbacks) ~= nil
end

local function ClearTransient()
    if scanTimer then
        scanTimer:Cancel()
        scanTimer = nil
    end
    lastScan = nil
    retryScheduled = false
end

-- Lazily register the shared core-frame events on 0->1 subscribers and tear them
-- down on 1->0. Once overlay-engine holds a standing subscription (v2-G) this is
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
        ClearTransient()
    end
end

local function ExtractNPCID(guid)
    if not guid then return 0 end
    local ok, result = pcall(string.match, guid, "-(%d+)-%x+$")
    if ok and result then return tonumber(result) or 0 end
    return 0
end

local function GetCurrentLocation()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end

    local location = { mapID = mapID }
    local mapInfo = C_Map.GetMapInfo(mapID)
    location.zone = (mapInfo and mapInfo.name) or GetZoneText() or ""
    location.subzone = GetSubZoneText() or ""

    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if position then
        location.x = floor(position.x * 10000) / 100
        location.y = floor(position.y * 10000) / 100
    else
        location.x = 0
        location.y = 0
    end

    return location
end

-- Build the cost breakdown for one merchant slot (gold is carried separately as
-- `cost`; this covers the extended currency/item costs). Sets `needsRetry` when
-- a cost item's name is not yet cached.
local function BuildCurrencies(index, needsRetry)
    local currencies = {}
    local costCount = GetMerchantItemCostInfo(index)
    for c = 1, costCount do
        local texture, value, costLink, currName = GetMerchantItemCostItem(index, c)
        local costEntry = { amount = value, texture = texture }

        if costLink then
            local currID = tonumber(costLink:match("currency:(%d+)"))
            if currID then
                costEntry.currencyID = currID
                local currInfo = C_CurrencyInfo.GetCurrencyInfo(currID)
                costEntry.name = (currInfo and currInfo.name) or currName or ""
            else
                local itemCostID = tonumber(costLink:match("item:(%d+)"))
                if itemCostID then
                    costEntry.itemID = itemCostID
                    local costItemName = C_Item.GetItemNameByID(itemCostID)
                    if not costItemName then
                        C_Item.RequestLoadItemDataByID(itemCostID)
                        needsRetry.value = true
                    end
                    costEntry.name = costItemName or currName or ""
                end
            end
        elseif currName then
            costEntry.name = currName
        end

        if costEntry.amount and costEntry.amount > 0 then
            tinsert(currencies, costEntry)
        end
    end
    return currencies
end

-- Build an ephemeral snapshot of the currently open merchant. Returns the
-- snapshot plus whether a deferred rescan is warranted (uncached rows).
local function BuildScan()
    local guid = UnitGUID("npc")
    local npcID = ExtractNPCID(guid)
    if npcID == 0 then
        npcID = ExtractNPCID(UnitGUID("target"))
    end
    if npcID == 0 then return nil, false end

    local needsRetry = { value = false }
    local numItems = GetMerchantNumItems()
    local items = {}
    local now = time()

    for i = 1, numItems do
        -- GetMerchantItemLink is nil for uncached rows on a first-ever visit;
        -- GetMerchantItemID works uncached, so fall back to it rather than
        -- silently dropping the row (would lose collectibles on first sighting).
        local itemID
        local itemLink = GetMerchantItemLink(i)
        if itemLink then
            itemID = tonumber(itemLink:match("item:(%d+)"))
        else
            itemID = GetMerchantItemID(i)
            if itemID then
                C_Item.RequestLoadItemDataByID(itemID)
                needsRetry.value = true
            end
        end

        if itemID then
            local info = C_MerchantFrame.GetItemInfo(i)
            local itemEntry = {
                cost = (info and info.price) or 0,
                limited = (info and info.numAvailable and info.numAvailable > 0) or false,
                maxStack = (info and info.stackCount) or 1,
                isPurchasable = info and info.isPurchasable or false,
                isUsable = info and info.isUsable or false,
                lastSeen = now,
                currencies = {},
            }

            if info and info.hasExtendedCost then
                itemEntry.currencies = BuildCurrencies(i, needsRetry)
            end

            items[itemID] = itemEntry
        end
    end

    local scan = {
        npcID = npcID,
        name = UnitName("npc") or "",
        creatureType = UnitCreatureType("npc") or "",
        classification = UnitClassification("npc") or "normal",
        level = UnitLevel("npc") or 0,
        location = GetCurrentLocation(),
        items = items,
        scannedAt = now,
    }
    return scan, needsRetry.value
end

local function FireScan(scan)
    for ownerID, fn in pairs(scanCallbacks) do
        ns.Lifecycle.SafeCall("Merchant.scan:" .. ownerID, fn, scan)
    end
end

local function FireShow()
    for ownerID, fn in pairs(showCallbacks) do
        ns.Lifecycle.SafeCall("Merchant.show:" .. ownerID, fn)
    end
end

local function FireClosed()
    for ownerID, fn in pairs(closedCallbacks) do
        ns.Lifecycle.SafeCall("Merchant.closed:" .. ownerID, fn)
    end
end

local ArmScan -- forward declaration (DoScan re-arms on retry)

-- Debounced scan body. `GetMerchantNumItems` reflects the frame's active filter,
-- so a filtered view scans a subset (known limitation, not fixed here).
local function DoScan()
    scanTimer = nil
    if not (MerchantFrame and MerchantFrame:IsShown()) then return end

    local scan, needsRetry = BuildScan()
    if not scan then return end

    lastScan = scan
    FireScan(scan)

    -- One deferred rescan pass for a first-ever visit whose item/cost data was
    -- still loading. Consumers must be idempotent (catch-up + retry re-deliver).
    if needsRetry and not retryScheduled then
        retryScheduled = true
        C_Timer.After(RETRY_DELAY, function()
            if eventsRegistered and MerchantFrame and MerchantFrame:IsShown() then
                ArmScan()
            end
        end)
    end
end

function ArmScan()
    if scanTimer then scanTimer:Cancel() end
    scanTimer = C_Timer.NewTimer(DEBOUNCE, DoScan)
end

function OnEvent(event)
    if event == "MERCHANT_CLOSED" then
        ClearTransient()
        FireClosed()
        return
    end
    if event == "MERCHANT_SHOW" then
        -- Show fires synchronously (merchants have no ready gate); consumers that
        -- must act at open time (auto-repair, gold snapshots, panel anchoring)
        -- run before any scan.
        FireShow()
    end
    -- MERCHANT_SHOW / MERCHANT_UPDATE coalesce into one re-armed scan.
    ArmScan()
end

local function Subscribe(tbl, ownerID, fn)
    if type(ownerID) ~= "string" or type(fn) ~= "function" then
        error("OneWoW.Merchant register: (ownerID string, fn function) required", 3)
    end
    tbl[ownerID] = fn
    EnsureEvents()
    -- Catch-up: subscribing while a merchant is already open (e.g. mid-session
    -- EnsureLoaded at a vendor) delivers the current state on the next debounce
    -- tick. Fans out to all scan subscribers -- consumers must be idempotent.
    if MerchantFrame and MerchantFrame:IsShown() then
        ArmScan()
    end
end

--- Subscribe to vendor scan snapshots (npc identity + item map with costs).
---@param ownerID string stable id; re-registering replaces the prior handler
---@param fn fun(scan: table)
function Merchant.RegisterScanCallback(ownerID, fn)
    Subscribe(scanCallbacks, ownerID, fn)
end

--- Subscribe to MERCHANT_SHOW, fired synchronously before any scan. For
--- consumers that must act at open time (repair, gold snapshot, panel anchor).
---@param ownerID string
---@param fn fun()
function Merchant.RegisterShowCallback(ownerID, fn)
    Subscribe(showCallbacks, ownerID, fn)
end

--- Subscribe to MERCHANT_CLOSED for transient-state teardown.
---@param ownerID string
---@param fn fun()
function Merchant.RegisterClosedCallback(ownerID, fn)
    Subscribe(closedCallbacks, ownerID, fn)
end

--- Drop all channel subscriptions for an owner. May unregister the shared events
--- when the last subscriber leaves.
---@param ownerID string
function Merchant.UnregisterCallback(ownerID)
    scanCallbacks[ownerID] = nil
    showCallbacks[ownerID] = nil
    closedCallbacks[ownerID] = nil
    EnsureEvents()
end

--- The most recent ephemeral scan snapshot, or nil if none this session.
---@return table|nil scan
function Merchant.GetLastScan()
    return lastScan
end

--- Live merchant-open state. Lets pure state-flag consumers drop their own
--- `merchantOpen` booleans without holding a subscription.
---@return boolean open
function Merchant.IsMerchantOpen()
    return MerchantFrame ~= nil and MerchantFrame:IsShown()
end
