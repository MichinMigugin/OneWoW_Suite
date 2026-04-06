local addonName, ns = ...

ns.AuctionTracker = {}
local Module = ns.AuctionTracker

local private = {
    auctionIdToLink = {},
    auctionIdToName = {},
    auctionIdToQuantity = {},
    auctionIdToBuyout = {},
    commodityIdToName = {},
    pendingPost = {
        itemLink = nil,
        quantity = nil,
        unitPrice = nil,
        goldBefore = nil,
        timestamp = nil,
    },
    pendingCommodity = nil,
}

function Module:Initialize()
    if self.initialized then return end
    self.initialized = true

    if not C_AuctionHouse then return end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
    frame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
    frame:RegisterEvent("AUCTION_HOUSE_AUCTION_CREATED")
    frame:RegisterEvent("PLAYER_MONEY")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "ITEM_SEARCH_RESULTS_UPDATED" then
            private.UpdateItemMap(...)
        elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
            private.UpdateCommodityMap(...)
        elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
            private.OnAuctionCreated()
        elseif event == "PLAYER_MONEY" then
            private.OnPlayerMoney()
        end
    end)

    hooksecurefunc(C_AuctionHouse, "PlaceBid", function(auctionId, bidAmount)
        private.OnPlaceBid(auctionId, bidAmount)
    end)

    hooksecurefunc(C_AuctionHouse, "ConfirmCommoditiesPurchase", function(itemId, quantity)
        private.OnConfirmCommodityPurchase(itemId, quantity)
    end)

    hooksecurefunc(C_AuctionHouse, "PostItem", function(item, duration, quantity, startPrice, buyoutPrice)
        private.OnPostItem(item, duration, quantity, buyoutPrice)
    end)

    hooksecurefunc(C_AuctionHouse, "PostCommodity", function(item, duration, quantity, unitPrice)
        private.OnPostCommodity(item, duration, quantity, unitPrice)
    end)
end

function private.UpdateItemMap(itemKey)
    wipe(private.auctionIdToLink)
    wipe(private.auctionIdToName)
    wipe(private.auctionIdToQuantity)
    wipe(private.auctionIdToBuyout)

    local numResults = C_AuctionHouse.GetNumItemSearchResults(itemKey)
    for i = 1, numResults do
        local info = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        if info and info.auctionID and info.buyoutAmount then
            private.auctionIdToLink[info.auctionID] = info.itemLink
            private.auctionIdToName[info.auctionID] = info.itemName
            private.auctionIdToQuantity[info.auctionID] = info.quantity or 1
            private.auctionIdToBuyout[info.auctionID] = info.buyoutAmount
        end
    end
end

function private.UpdateCommodityMap(itemID)
    private.commodityIdToName[itemID] = C_Item.GetItemNameByID(itemID)
end

function private.OnPlaceBid(auctionId, bidAmount)
    if not bidAmount or bidAmount == 0 then return end
    local link = private.auctionIdToLink[auctionId]
    local name = private.auctionIdToName[auctionId]
    local buyout = private.auctionIdToBuyout[auctionId]
    local quantity = private.auctionIdToQuantity[auctionId] or 1
    if not name or bidAmount ~= buyout then return end

    ns.Transactions:RecordExpense("auction_purchase", bidAmount, "Auction House", link, name, quantity, "Auction purchase")
end

function private.OnConfirmCommodityPurchase(itemId, quantity)
    local name = private.commodityIdToName[itemId] or C_Item.GetItemNameByID(itemId)

    private.pendingCommodity = {
        itemId = itemId,
        name = name or "Commodity",
        quantity = quantity,
        goldBefore = GetMoney(),
        time = GetTime(),
    }
end

function private.OnPostItem(item, duration, quantity, buyoutPrice)
    if not buyoutPrice or buyoutPrice == 0 then return end
    private.pendingPost.itemLink = C_Item.GetItemLink(item)
    private.pendingPost.quantity = quantity or 1
    private.pendingPost.unitPrice = buyoutPrice
    private.pendingPost.goldBefore = GetMoney()
    private.pendingPost.timestamp = GetTime()
end

function private.OnPostCommodity(item, duration, quantity, unitPrice)
    if not unitPrice or unitPrice == 0 then return end
    private.pendingPost.itemLink = C_Item.GetItemLink(item)
    private.pendingPost.quantity = quantity or 1
    private.pendingPost.unitPrice = unitPrice
    private.pendingPost.goldBefore = GetMoney()
    private.pendingPost.timestamp = GetTime()
end

function private.OnAuctionCreated()
    if not private.pendingPost.timestamp then return end
    if GetTime() - private.pendingPost.timestamp > 5 then
        wipe(private.pendingPost)
        return
    end
    private.pendingPost.auctionConfirmed = true
end

function private.OnPlayerMoney()
    if private.pendingCommodity and (GetTime() - private.pendingCommodity.time) < 10 then
        local cost = private.pendingCommodity.goldBefore - GetMoney()
        if cost > 0 then
            ns.Transactions:RecordExpense("auction_purchase", cost, "Auction House", nil,
                private.pendingCommodity.name, private.pendingCommodity.quantity, "Commodity purchase")
        end
        private.pendingCommodity = nil
        return
    end
    private.pendingCommodity = nil

    if not private.pendingPost.auctionConfirmed then return end
    if not private.pendingPost.goldBefore then
        wipe(private.pendingPost)
        return
    end

    local deposit = private.pendingPost.goldBefore - GetMoney()
    if deposit > 0 then
        local name = private.pendingPost.itemLink and select(1, GetItemInfo(private.pendingPost.itemLink)) or "Item"
        ns.Transactions:RecordExpense("auction_deposit", deposit, "Auction House", private.pendingPost.itemLink, name, private.pendingPost.quantity, "Posting deposit")
    end

    wipe(private.pendingPost)
end
