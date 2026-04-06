local addonName, ns = ...

ns.ActiveAuctions = {}
local ActiveAuctions = ns.ActiveAuctions

function ActiveAuctions:CollectData(charKey, charData)
    if not C_AuctionHouse then return false end

    local serverTime = GetServerTime()
    local previousAuctions = {}

    if charData.activeAuctions then
        for _, auction in ipairs(charData.activeAuctions) do
            previousAuctions[auction.auctionID] = auction
        end
    end

    local numAuctions = C_AuctionHouse.GetNumOwnedAuctions()

    if numAuctions == 0 then
        self:DetectAuctionOutcomes(charKey, charData, previousAuctions, {}, serverTime)
        charData.activeAuctions = {}
        charData.numActiveAuctions = 0
        charData.lastAuctionUpdate = serverTime
        return true
    end

    local auctions = {}
    local currentAuctions = {}
    local totalValue = 0

    for i = 1, numAuctions do
        local auctionInfo = C_AuctionHouse.GetOwnedAuctionInfo(i)

        if auctionInfo then
            local itemKey = auctionInfo.itemKey
            local itemID = itemKey and itemKey.itemID

            if itemID then
                local itemName, itemLink, itemRarity = GetItemInfo(itemID)
                local itemIcon = C_Item.GetItemIconByID(itemID)

                local auctionData = {
                    auctionID = auctionInfo.auctionID,
                    itemID = itemID,
                    itemName = itemName or "Unknown Item",
                    itemLink = itemLink or auctionInfo.itemLink,
                    itemIcon = itemIcon,
                    itemRarity = itemRarity,
                    itemLevel = itemKey.itemLevel or 0,
                    quantity = auctionInfo.quantity or 1,
                    bidAmount = auctionInfo.bidAmount or 0,
                    buyoutAmount = auctionInfo.buyoutAmount or 0,
                    timeLeftSeconds = auctionInfo.timeLeftSeconds or 0,
                    endsAt = serverTime + (auctionInfo.timeLeftSeconds or 0),
                    bidder = auctionInfo.bidder,
                    status = auctionInfo.status or 0,
                    collectedAt = serverTime,
                }

                if auctionInfo.status == 1 then
                    local auctionToRecord = previousAuctions[auctionInfo.auctionID] or auctionData
                    local salePrice = auctionInfo.bidAmount or auctionInfo.buyoutAmount
                    self:RecordHistoryEvent(charData, auctionToRecord, "sold", salePrice, serverTime, "status_field")
                    currentAuctions[auctionInfo.auctionID] = auctionData
                elseif auctionInfo.status == 0 then
                    table.insert(auctions, auctionData)
                    currentAuctions[auctionData.auctionID] = auctionData
                    totalValue = totalValue + (auctionInfo.buyoutAmount or 0)
                end
            end
        end
    end

    self:DetectAuctionOutcomes(charKey, charData, previousAuctions, currentAuctions, serverTime)

    charData.activeAuctions = auctions
    charData.numActiveAuctions = #auctions
    charData.totalAuctionValue = totalValue
    charData.lastAuctionUpdate = serverTime

    return true
end

function ActiveAuctions:RecordHistoryEvent(charData, auction, outcome, goldAmount, timestamp, detectionMethod)
    if not charData.auctionHistory then
        charData.auctionHistory = {}
    end

    for _, event in ipairs(charData.auctionHistory) do
        if event.auctionID == auction.auctionID then
            if event.outcome ~= "sold" and outcome == "sold" then
                event.outcome = "sold"
                event.salePrice = goldAmount
                event.detectionMethod = detectionMethod
                event.confirmed = (detectionMethod == "mail")
            end
            return
        end
    end

    local historyEntry = {
        auctionID = auction.auctionID,
        itemID = auction.itemID,
        itemName = auction.itemName,
        itemLink = auction.itemLink,
        itemIcon = auction.itemIcon,
        itemRarity = auction.itemRarity,
        itemLevel = auction.itemLevel,
        quantity = auction.quantity,
        listPrice = auction.buyoutAmount,
        salePrice = goldAmount,
        outcome = outcome,
        timestamp = timestamp,
        postedAt = auction.collectedAt,
        duration = timestamp - (auction.collectedAt or timestamp),
        detectionMethod = detectionMethod,
        confirmed = (detectionMethod == "mail"),
    }

    table.insert(charData.auctionHistory, 1, historyEntry)

    if #charData.auctionHistory > 100 then
        table.remove(charData.auctionHistory)
    end

end

function ActiveAuctions:DetectAuctionOutcomes(charKey, charData, previousAuctions, currentAuctions, serverTime)
    if not previousAuctions or not next(previousAuctions) then return end

    for auctionID, oldAuction in pairs(previousAuctions) do
        if not currentAuctions[auctionID] then
            local outcome = "canceled"
            local goldChange = 0

            if oldAuction.endsAt and oldAuction.endsAt <= serverTime then
                outcome = "expired"
                goldChange = 0
            end

            self:RecordHistoryEvent(charData, oldAuction, outcome, goldChange, serverTime, "snapshot_comparison")
        end
    end
end

function ActiveAuctions:GetAuctionStats(charData)
    if not charData or not charData.activeAuctions then
        return {
            total = 0,
            value = 0,
            expiringSoon = 0,
        }
    end

    local stats = {
        total = charData.numActiveAuctions or 0,
        value = charData.totalAuctionValue or 0,
        expiringSoon = 0,
    }

    local serverTime = GetServerTime()
    local twoHours = 7200

    for _, auction in ipairs(charData.activeAuctions) do
        if auction.endsAt then
            local timeLeft = auction.endsAt - serverTime
            if timeLeft > 0 and timeLeft < twoHours then
                stats.expiringSoon = stats.expiringSoon + 1
            end
        end
    end

    return stats
end

function ActiveAuctions:GetHistoryStats(charData)
    if not charData or not charData.auctionHistory then
        return {
            totalEvents = 0,
            sold = 0,
            expired = 0,
            canceled = 0,
            goldEarned = 0,
            successRate = 0,
        }
    end

    local stats = {
        totalEvents = #charData.auctionHistory,
        sold = 0,
        expired = 0,
        canceled = 0,
        goldEarned = 0,
    }

    for _, event in ipairs(charData.auctionHistory) do
        if event.outcome == "sold" then
            stats.sold = stats.sold + 1
            stats.goldEarned = stats.goldEarned + (event.salePrice or 0)
        elseif event.outcome == "expired" then
            stats.expired = stats.expired + 1
        elseif event.outcome == "canceled" then
            stats.canceled = stats.canceled + 1
        end
    end

    local totalPosted = stats.sold + stats.expired + stats.canceled
    if totalPosted > 0 then
        stats.successRate = math.floor((stats.sold / totalPosted) * 100)
    else
        stats.successRate = 0
    end

    return stats
end
