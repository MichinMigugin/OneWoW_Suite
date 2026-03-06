local addonName, ns = ...

ns.AuctionHook = {}
local Module = ns.AuctionHook

local private = {
    hooks = {},
}

function Module:Initialize()
    if self.initialized then return end
    self.initialized = true

    if C_AuctionHouse then
        private.hooks.PlaceBid = C_AuctionHouse.PlaceBid
        C_AuctionHouse.PlaceBid = function(auctionId, bidAmount)
            private.OnPlaceBid(auctionId, bidAmount)
            return private.hooks.PlaceBid(auctionId, bidAmount)
        end
    else
        private.hooks.PlaceAuctionBid = PlaceAuctionBid
        PlaceAuctionBid = function(auctionIndex, bidAmount)
            private.OnPlaceAuctionBid(auctionIndex, bidAmount)
            return private.hooks.PlaceAuctionBid(auctionIndex, bidAmount)
        end
    end
end

function private.OnPlaceBid(auctionId, bidAmount)
    if not bidAmount or bidAmount == 0 then return end

    local itemLink, itemName, quantity = C_AuctionHouse.GetAuctionItemInfo(auctionId)
    if not itemLink then return end

    private.RecordAuctionPurchase(itemName or "Unknown Item", quantity or 1, bidAmount)
end

function private.OnPlaceAuctionBid(auctionIndex, bidAmount)
    if not bidAmount or bidAmount == 0 then return end

    local info = C_AuctionHouse.GetBrowseResultInfo(auctionIndex)
    if not info then return end

    private.RecordAuctionPurchase(info.itemName or "Unknown Item", info.quantity or 1, bidAmount)
end

function private.RecordAuctionPurchase(itemName, quantity, copperAmount)
    local AccountingAddon = _G.OneWoW_AltTracker_Accounting
    if not AccountingAddon or not AccountingAddon.Transactions or not OneWoW_AltTracker_Accounting_DB then
        return
    end

    AccountingAddon.Transactions:RecordExpense("auction_purchase", copperAmount, "Auction House", nil, itemName, quantity, "Auction purchase")

    if _G.OneWoW_AltTracker_Accounting.InvalidateStatistics then
        _G.OneWoW_AltTracker_Accounting:InvalidateStatistics()
    end
end
