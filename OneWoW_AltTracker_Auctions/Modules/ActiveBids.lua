local addonName, ns = ...

ns.ActiveBids = {}
local ActiveBids = ns.ActiveBids

function ActiveBids:CollectData(charKey, charData)
    if not C_AuctionHouse then return false end

    local numBids = C_AuctionHouse.GetNumBids()

    if numBids == 0 then
        charData.activeBids = {}
        charData.numActiveBids = 0
        charData.lastBidUpdate = GetServerTime()
        return true
    end

    local bids = {}
    local totalBidAmount = 0
    local serverTime = GetServerTime()

    for i = 1, numBids do
        local bidInfo = C_AuctionHouse.GetBidInfo(i)

        if bidInfo then
            local itemKey = bidInfo.itemKey
            local itemID = itemKey and itemKey.itemID

            if itemID then
                local itemName, itemLink, itemRarity = GetItemInfo(itemID)
                local itemIcon = C_Item.GetItemIconByID(itemID)

                local bidData = {
                    auctionID = bidInfo.auctionID,
                    itemID = itemID,
                    itemName = itemName or "Unknown Item",
                    itemLink = itemLink or bidInfo.itemLink,
                    itemIcon = itemIcon,
                    itemRarity = itemRarity,
                    itemLevel = itemKey.itemLevel or 0,
                    quantity = bidInfo.quantity or 1,
                    minBid = bidInfo.minBid or 0,
                    bidAmount = bidInfo.bidAmount or 0,
                    buyoutAmount = bidInfo.buyoutAmount or 0,
                    timeLeft = bidInfo.timeLeft or 0,
                    bidder = bidInfo.bidder,
                    collectedAt = serverTime,
                }

                table.insert(bids, bidData)
                totalBidAmount = totalBidAmount + (bidInfo.bidAmount or 0)
            end
        end
    end

    charData.activeBids = bids
    charData.numActiveBids = #bids
    charData.totalBidAmount = totalBidAmount
    charData.lastBidUpdate = serverTime

    return true
end

function ActiveBids:GetBidStats(charData)
    if not charData or not charData.activeBids then
        return {
            total = 0,
            amount = 0,
        }
    end

    return {
        total = charData.numActiveBids or 0,
        amount = charData.totalBidAmount or 0,
    }
end
