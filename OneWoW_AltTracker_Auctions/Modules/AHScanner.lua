local addonName, ns = ...

ns.AHScanner = {}
local AHScanner = ns.AHScanner

local scanState = nil
local eventFrame = nil

function AHScanner:Initialize()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
    end

    eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    eventFrame:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    eventFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
    eventFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
    eventFrame:RegisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        AHScanner:HandleEvent(event, ...)
    end)
end

function AHScanner:HandleEvent(event, ...)
    if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if scanState and scanState.isScanning and not scanState.waitingForResults and not scanState.waitingForItemKey then
            self:ProcessNextItem()
        end

    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        self:OnSearchResults(false)

    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        self:OnSearchResults(true)

    elseif event == "ITEM_KEY_ITEM_INFO_RECEIVED" then
        if scanState and scanState.waitingForItemKey then
            local itemID = ...
            if itemID == scanState.pendingItemKeyID then
                scanState.waitingForItemKey = false
                scanState.pendingItemKeyID = nil
                scanState.itemInfoRetries = 0
                self:ProcessNextItem()
            end
        end

    elseif event == "AUCTION_HOUSE_SHOW" then
        if scanState and scanState.callback then
            scanState.callback("ahOpened")
        end

    elseif event == "AUCTION_HOUSE_CLOSED" then
        if scanState and scanState.isScanning then
            self:StopScan()
        end
    end
end

function AHScanner:StartScan(itemsToScan, callback)
    if scanState and scanState.isScanning then return false end
    if not itemsToScan or #itemsToScan == 0 then return false end

    local itemQueue = {}
    for _, item in ipairs(itemsToScan) do
        if item.itemID and not item.isBound then
            table.insert(itemQueue, item)
        end
    end

    if #itemQueue == 0 then return false end

    scanState = {
        isScanning = true,
        itemQueue = itemQueue,
        currentIndex = 1,
        callback = callback,
        pricesFound = 0,
        itemInfoRetries = 0,
        maxItemInfoRetries = 5,
        waitingForResults = false,
        waitingForItemKey = false,
        pendingItemKeyID = nil,
        timeoutHandle = nil,
    }

    if callback then
        callback("scanStarted", 0, #itemQueue)
    end

    self:ProcessNextItem()
    return true
end

function AHScanner:StopScan()
    if not scanState then return end
    local cb = scanState.callback
    if scanState.timeoutHandle then
        scanState.timeoutHandle:Cancel()
    end
    scanState.isScanning = false
    scanState = nil
    if cb then
        cb("scanStopped")
    end
end

function AHScanner:IsScanning()
    return scanState and scanState.isScanning or false
end

function AHScanner:AdvanceToNextItem()
    if not scanState then return end

    scanState.itemInfoRetries = 0
    scanState.waitingForResults = false
    scanState.waitingForItemKey = false
    scanState.pendingItemKeyID = nil
    if scanState.timeoutHandle then
        scanState.timeoutHandle:Cancel()
        scanState.timeoutHandle = nil
    end

    scanState.currentIndex = scanState.currentIndex + 1

    if scanState.callback then
        scanState.callback("itemScanned", scanState.currentIndex - 1, #scanState.itemQueue, scanState.pricesFound)
    end

    self:ProcessNextItem()
end

function AHScanner:ProcessNextItem()
    if not scanState or not scanState.isScanning then return end

    if scanState.currentIndex > #scanState.itemQueue then
        self:CompleteScan()
        return
    end

    if scanState.waitingForResults or scanState.waitingForItemKey then
        return
    end

    if not C_AuctionHouse.IsThrottledMessageSystemReady() then
        return
    end

    local itemData = scanState.itemQueue[scanState.currentIndex]
    if not itemData then
        self:AdvanceToNextItem()
        return
    end

    local itemKey = C_AuctionHouse.MakeItemKey(itemData.itemID, 0, 0, 0)
    local itemInfo = C_AuctionHouse.GetItemKeyInfo(itemKey)

    if itemInfo then
        scanState.itemInfoRetries = 0

        local success = pcall(function()
            C_AuctionHouse.SendSearchQuery(itemKey, {}, false)
        end)

        if success then
            scanState.waitingForResults = true
            scanState.timeoutHandle = C_Timer.NewTimer(3, function()
                if scanState and scanState.isScanning and scanState.waitingForResults then
                    AHScanner:AdvanceToNextItem()
                end
            end)
        else
            self:AdvanceToNextItem()
        end
    else
        scanState.itemInfoRetries = scanState.itemInfoRetries + 1
        if scanState.itemInfoRetries >= scanState.maxItemInfoRetries then
            self:AdvanceToNextItem()
        else
            scanState.waitingForItemKey = true
            scanState.pendingItemKeyID = itemData.itemID
            local currentIndex = scanState.currentIndex
            C_Timer.After(1.0, function()
                if not scanState or scanState.currentIndex ~= currentIndex then return end
                if scanState.waitingForItemKey and scanState.pendingItemKeyID == itemData.itemID then
                    scanState.waitingForItemKey = false
                    scanState.pendingItemKeyID = nil
                    scanState.itemInfoRetries = scanState.itemInfoRetries + 1
                    if scanState.itemInfoRetries >= scanState.maxItemInfoRetries then
                        AHScanner:AdvanceToNextItem()
                    else
                        AHScanner:ProcessNextItem()
                    end
                end
            end)
        end
    end
end

function AHScanner:OnSearchResults(isCommodity)
    if not scanState or not scanState.isScanning or not scanState.waitingForResults then
        return
    end

    local itemData = scanState.itemQueue[scanState.currentIndex]
    if not itemData then
        self:AdvanceToNextItem()
        return
    end

    if isCommodity then
        local numResults = C_AuctionHouse.GetNumCommoditySearchResults(itemData.itemID)
        if numResults and numResults > 0 then
            local resultInfo = C_AuctionHouse.GetCommoditySearchResultInfo(itemData.itemID, 1)
            if resultInfo and resultInfo.unitPrice then
                _G.OneWoW_AHPrices[itemData.itemID] = {
                    price = resultInfo.unitPrice,
                    timestamp = GetServerTime(),
                }
                scanState.pricesFound = scanState.pricesFound + 1
            end
        end
    else
        local itemKey = C_AuctionHouse.MakeItemKey(itemData.itemID, 0, 0, 0)
        local hasResults = C_AuctionHouse.HasSearchResults(itemKey)
        local numResults = C_AuctionHouse.GetItemSearchResultsQuantity(itemKey)

        if hasResults and numResults > 0 then
            local resultInfo = C_AuctionHouse.GetItemSearchResultInfo(itemKey, 1)
            if resultInfo and resultInfo.buyoutAmount then
                local pricePerUnit = math.floor(resultInfo.buyoutAmount / math.max(1, resultInfo.quantity or 1))
                _G.OneWoW_AHPrices[itemData.itemID] = {
                    price = pricePerUnit,
                    timestamp = GetServerTime(),
                }
                scanState.pricesFound = scanState.pricesFound + 1
            end
        end
    end

    self:AdvanceToNextItem()
end

function AHScanner:CompleteScan()
    if not scanState then return end
    local cb = scanState.callback
    local total = #scanState.itemQueue
    local found = scanState.pricesFound
    if scanState.timeoutHandle then
        scanState.timeoutHandle:Cancel()
    end
    scanState.isScanning = false
    scanState = nil
    if cb then
        cb("scanCompleted", total, total, found)
    end
end

function AHScanner:GetPrice(itemID)
    if _G.OneWoW_AHPrices then
        local data = _G.OneWoW_AHPrices[itemID]
        if data then
            return data.price, data.timestamp
        end
    end
    return nil, nil
end

AHScanner.GetAHPrice = AHScanner.GetPrice
