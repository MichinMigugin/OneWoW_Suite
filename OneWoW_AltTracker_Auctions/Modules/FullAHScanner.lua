local addonName, ns = ...

ns.FullAHScanner = {}
local FullAHScanner = ns.FullAHScanner

local SCAN_COOLDOWN_SECONDS = 15 * 60
local BATCH_SIZE = 250
local REPLICATE_TIMEOUT = 30

local scanState = nil
local scanFrame = nil
local lastScanTime = 0

local function GetOrCreateScanFrame()
    if scanFrame then return scanFrame end
    if not AuctionHouseFrame then return nil end
    scanFrame = CreateFrame("Frame", "OneWoW_FullAHScanFrame", AuctionHouseFrame)
    scanFrame:SetScript("OnEvent", function(self, event, ...)
        FullAHScanner:HandleEvent(event, ...)
    end)
    return scanFrame
end

function FullAHScanner:Initialize()
    local ahWatcher = CreateFrame("Frame")
    ahWatcher:RegisterEvent("AUCTION_HOUSE_CLOSED")
    ahWatcher:SetScript("OnEvent", function(self, event)
        if scanState and scanState.isScanning then
            FullAHScanner:AbortScan()
        end
    end)
end

function FullAHScanner:HandleEvent(event, ...)
    if event == "REPLICATE_ITEM_LIST_UPDATE" then
        if scanFrame then scanFrame:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE") end
        if scanState and scanState.timeoutHandle then
            scanState.timeoutHandle:Cancel()
            scanState.timeoutHandle = nil
        end
        self:CacheScanData()
    end
end

function FullAHScanner:CanScan()
    local now = time()
    local elapsed = now - lastScanTime
    if elapsed < SCAN_COOLDOWN_SECONDS then
        local remaining = math.ceil((SCAN_COOLDOWN_SECONDS - elapsed) / 60)
        return false, remaining
    end
    return true, 0
end

function FullAHScanner:GetLastScanTime()
    return lastScanTime
end

function FullAHScanner:StartScan(callback)
    if scanState and scanState.isScanning then return false end
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return false end

    local frame = GetOrCreateScanFrame()
    if not frame then return false end

    if not _G.OneWoW_AHPrices then
        _G.OneWoW_AHPrices = {}
    end

    local timeoutHandle = C_Timer.NewTimer(REPLICATE_TIMEOUT, function()
        if scanState and scanState.isScanning then
            if scanFrame then scanFrame:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE") end
            print("|cFFFFD100OneWoW:|r AH full scan timed out - the AH did not respond. You can try again.")
            FullAHScanner:AbortScan()
        end
    end)

    scanState = {
        isScanning = true,
        callback = callback,
        minPrices = {},
        timeoutHandle = timeoutHandle,
    }

    if callback then callback("scanStarted", 0) end

    frame:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    C_AuctionHouse.ReplicateItems()

    return true
end

function FullAHScanner:StopScan()
    if not scanState then return end
    local cb = scanState.callback
    if scanFrame then scanFrame:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE") end
    if scanState.timeoutHandle then
        scanState.timeoutHandle:Cancel()
    end
    scanState.isScanning = false
    scanState = nil
    if cb then cb("scanStopped") end
end

function FullAHScanner:AbortScan()
    if not scanState then return end
    local cb = scanState.callback
    if scanFrame then scanFrame:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE") end
    if scanState.timeoutHandle then
        scanState.timeoutHandle:Cancel()
    end
    scanState.isScanning = false
    scanState = nil
    if cb then cb("scanFailed") end
end

function FullAHScanner:IsScanning()
    return scanState and scanState.isScanning or false
end

function FullAHScanner:CacheScanData()
    if not scanState or not scanState.isScanning then return end

    local callback = scanState.callback
    if callback then callback("scanProgress", 0.1) end

    local totalItems = C_AuctionHouse.GetNumReplicateItems()
    if not totalItems or totalItems == 0 then
        self:CompleteScan(0)
        return
    end

    local minPrices = scanState.minPrices
    local processed = 0
    local limit = totalItems
    local serverTime = GetServerTime()

    local function ProcessBatch(startIndex)
        if not scanState or not scanState.isScanning then return end

        local endIndex = math.min(startIndex + BATCH_SIZE - 1, limit - 1)

        for i = startIndex, endIndex do
            local name, texture, count, quality, canUse, level, levelColHeader,
                  minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
                  bidderFullName, owner, ownerFullName, saleStatus, itemID, hasAllInfo =
                  C_AuctionHouse.GetReplicateItemInfo(i)

            if itemID and itemID > 0 and count and count > 0 and buyoutPrice and buyoutPrice > 0 then
                local pricePerUnit = math.floor(buyoutPrice / count)
                if not minPrices[itemID] or pricePerUnit < minPrices[itemID] then
                    minPrices[itemID] = pricePerUnit
                end
            end

            processed = processed + 1
        end

        local progress = 0.1 + (processed / limit) * 0.9
        if callback then callback("scanProgress", progress) end

        if processed >= limit then
            local pricesFound = 0
            for iID, price in pairs(minPrices) do
                _G.OneWoW_AHPrices[iID] = {
                    price = price,
                    timestamp = serverTime,
                }
                pricesFound = pricesFound + 1
            end
            FullAHScanner:CompleteScan(pricesFound)
        else
            C_Timer.After(0.01, function()
                ProcessBatch(startIndex + BATCH_SIZE)
            end)
        end
    end

    ProcessBatch(0)
end

function FullAHScanner:CompleteScan(pricesFound)
    if not scanState then return end
    local cb = scanState.callback
    if scanState.timeoutHandle then
        scanState.timeoutHandle:Cancel()
    end
    scanState.isScanning = false
    scanState = nil
    lastScanTime = time()
    if cb then cb("scanCompleted", 1.0, pricesFound) end
end

function FullAHScanner:GetPrice(itemID)
    if _G.OneWoW_AHPrices then
        local data = _G.OneWoW_AHPrices[itemID]
        if data then
            return data.price, data.timestamp
        end
    end
    return nil, nil
end
