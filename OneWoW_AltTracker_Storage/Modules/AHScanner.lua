local addonName, ns = ...

ns.AHScanner = {}
local AHScanner = ns.AHScanner

local private = {
    isScanning = false,
    itemQueue = {},
    currentItemIndex = 1,
    ahPrices = {},
    scanStartTime = 0,
    lastSearchTime = 0,
    searchThrottleMs = 600,
    eventFrame = nil,
    callback = nil,
}

function AHScanner:Initialize()
    if not private.eventFrame then
        private.eventFrame = CreateFrame("Frame")
    end

    private.eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    private.eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    private.eventFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")

    private.eventFrame:SetScript("OnEvent", function(self, event, ...)
        AHScanner:HandleEvent(event, ...)
    end)

    if OneWoW_AltTracker_Storage_DB and not OneWoW_AltTracker_Storage_DB.ahPrices then
        OneWoW_AltTracker_Storage_DB.ahPrices = {}
    end
end

function AHScanner:HandleEvent(event, ...)
    if event == "AUCTION_HOUSE_SHOW" then
        if private.callback then
            private.callback("ahOpened")
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if private.isScanning then
            self:StopScan()
        end
        if private.callback then
            private.callback("ahClosed")
        end
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        self:ProcessSearchResults()
    end
end

function AHScanner:StartScan(itemsToScan, callback)
    if private.isScanning then return false end
    if not itemsToScan or #itemsToScan == 0 then return false end

    private.isScanning = true
    private.itemQueue = {}
    private.currentItemIndex = 1
    private.scanStartTime = GetTime()
    private.callback = callback

    for _, item in ipairs(itemsToScan) do
        if item.itemID and not item.isBound then
            table.insert(private.itemQueue, item)
        end
    end

    if #private.itemQueue == 0 then
        private.isScanning = false
        return false
    end

    if callback then
        callback("scanStarted", 0, #private.itemQueue)
    end

    self:ProcessNextItem()
    return true
end

function AHScanner:StopScan()
    private.isScanning = false
    private.itemQueue = {}
    private.currentItemIndex = 1
    if private.callback then
        private.callback("scanStopped")
    end
end

function AHScanner:ProcessNextItem()
    if not private.isScanning then return end

    if private.currentItemIndex > #private.itemQueue then
        self:CompleteScan()
        return
    end

    local currentTime = GetTime()
    local timeSinceLastSearch = (currentTime - private.lastSearchTime) * 1000

    if timeSinceLastSearch < private.searchThrottleMs then
        C_Timer.After((private.searchThrottleMs - timeSinceLastSearch) / 1000, function()
            AHScanner:ProcessNextItem()
        end)
        return
    end

    local itemData = private.itemQueue[private.currentItemIndex]
    if itemData then
        local itemKey = C_AuctionHouse.MakeItemKey(itemData.itemID, 0, 0, 0)
        local itemInfo = C_AuctionHouse.GetItemKeyInfo(itemKey)

        if itemInfo then
            local success = pcall(function()
                C_AuctionHouse.SendSearchQuery(itemKey, {}, false)
            end)

            if success then
                private.lastSearchTime = GetTime()
                if private.callback then
                    private.callback("itemScanning", private.currentItemIndex, #private.itemQueue, itemData.itemName)
                end
            else
                private.currentItemIndex = private.currentItemIndex + 1
                C_Timer.After(0.1, function()
                    AHScanner:ProcessNextItem()
                end)
            end
        else
            C_Timer.After(0.2, function()
                AHScanner:ProcessNextItem()
            end)
        end
    end
end

function AHScanner:ProcessSearchResults()
    if not private.isScanning or private.currentItemIndex > #private.itemQueue then
        return
    end

    local itemData = private.itemQueue[private.currentItemIndex]
    if not itemData then
        return
    end

    local itemKey = C_AuctionHouse.MakeItemKey(itemData.itemID, 0, 0, 0)
    local hasResults = C_AuctionHouse.HasSearchResults(itemKey)
    local numResults = C_AuctionHouse.GetItemSearchResultsQuantity(itemKey)

    if hasResults and numResults > 0 then
        local resultInfo = C_AuctionHouse.GetItemSearchResultInfo(itemKey, 1)
        if resultInfo and resultInfo.buyoutAmount then
            local pricePerUnit = math.floor(resultInfo.buyoutAmount / math.max(1, resultInfo.quantity or 1))
            if OneWoW_AltTracker_Storage_DB.ahPrices then
                OneWoW_AltTracker_Storage_DB.ahPrices[itemData.itemID] = {
                    price = pricePerUnit,
                    timestamp = GetServerTime(),
                    quantity = resultInfo.quantity or 0,
                }
            end
        end
    end

    private.currentItemIndex = private.currentItemIndex + 1
    C_Timer.After(0.1, function()
        AHScanner:ProcessNextItem()
    end)
end

function AHScanner:CompleteScan()
    private.isScanning = false
    if private.callback then
        private.callback("scanCompleted", #private.itemQueue, #private.itemQueue)
    end
    private.callback = nil
end

function AHScanner:IsScanning()
    return private.isScanning
end

function AHScanner:GetAHPrice(itemID)
    if OneWoW_AltTracker_Storage_DB and OneWoW_AltTracker_Storage_DB.ahPrices then
        local priceData = OneWoW_AltTracker_Storage_DB.ahPrices[itemID]
        if priceData then
            return priceData.price, priceData.timestamp
        end
    end
    return nil, nil
end
