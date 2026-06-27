local _, ns = ...

local tinsert = tinsert
local tremove = tremove

ns.AHTargetedScanner = ns.AHTargetedScanner or {}
local Scanner = ns.AHTargetedScanner

local searchQueue = {}
local searchFrame = nil
local activeCallback = nil
local pendingKeys = nil

local function GetSearchFrame()
    if searchFrame then return searchFrame end
    searchFrame = CreateFrame("Frame")
    searchFrame:SetScript("OnEvent", function(_, event, ...)
        Scanner:HandleEvent(event, ...)
    end)
    return searchFrame
end

function Scanner:HandleEvent(event, ...)
    if event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        self:OnSearchResults(...)
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        self:PumpQueue()
    elseif event == "AUCTION_HOUSE_CLOSED" or event == "AUCTION_HOUSE_DISABLED" then
        self:Abort()
    end
end

function Scanner:StartScan(itemKeys, callback)
    if not itemKeys or #itemKeys == 0 then return false end
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return false end
    if pendingKeys then return false end

    pendingKeys = itemKeys
    activeCallback = callback
    searchQueue = {}

    for _, itemKey in ipairs(itemKeys) do
        tinsert(searchQueue, itemKey)
    end

    local frame = GetSearchFrame()
    frame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
    frame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
    frame:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    frame:RegisterEvent("AUCTION_HOUSE_DISABLED")

    if callback then callback("scanStarted", 0) end
    self:PumpQueue()
    return true
end

function Scanner:PumpQueue()
    if not pendingKeys or #searchQueue == 0 then
        self:Complete()
        return
    end
    if not C_AuctionHouse.IsThrottledMessageSystemReady() then return end

    local batch = {}
    for _ = 1, math.min(10, #searchQueue) do
        tinsert(batch, tremove(searchQueue, 1))
    end
    if #batch > 0 then
        C_AuctionHouse.SearchForItemKeys(batch, {})
    end
end

function Scanner:OnSearchResults(itemKey)
    if not pendingKeys or not itemKey then return end
    local AHItemKeys = OneWoW.AHItemKeys
    local storageKey = AHItemKeys and AHItemKeys:SerializeItemKey(itemKey)
    if not storageKey then return end

    local buyout = C_AuctionHouse.GetMaxItemSearchResultBuyout(itemKey)
    if buyout and buyout > 0 then
        ns.AHPriceCache:MergeRealmEntries(nil, {
            [storageKey] = { price = buyout, timestamp = GetServerTime() },
        })
    end

    if activeCallback then
        activeCallback("scanProgress", 0.5)
    end
    C_Timer.After(0.05, function()
        self:PumpQueue()
    end)
end

function Scanner:Complete()
    local cb = activeCallback
    pendingKeys = nil
    activeCallback = nil
    searchQueue = {}
    if searchFrame then
        searchFrame:UnregisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
        searchFrame:UnregisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
        searchFrame:UnregisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
        searchFrame:UnregisterEvent("AUCTION_HOUSE_CLOSED")
        searchFrame:UnregisterEvent("AUCTION_HOUSE_DISABLED")
    end
    if cb then cb("scanCompleted", 1.0) end
end

function Scanner:Abort()
    pendingKeys = nil
    activeCallback = nil
    searchQueue = {}
    if searchFrame then
        searchFrame:UnregisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
        searchFrame:UnregisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
        searchFrame:UnregisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
        searchFrame:UnregisterEvent("AUCTION_HOUSE_CLOSED")
        searchFrame:UnregisterEvent("AUCTION_HOUSE_DISABLED")
    end
end
