local addonName, ns = ...

ns.ChatTracker = {}
local Module = ns.ChatTracker

local private = {
    eventFrame = nil,
}

function Module:Initialize()
    if self.initialized then return end
    self.initialized = true

    print("[ChatTracker] Initialized")
    private.eventFrame = CreateFrame("Frame")
    private.eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    private.eventFrame:SetScript("OnEvent", function(self, event, message)
        print("[ChatTracker] Event: " .. event)
        if event == "CHAT_MSG_SYSTEM" then
            Module:OnChatMessage(message)
        end
    end)
    print("[ChatTracker] Event listener registered")
end

function Module:OnChatMessage(message)
    local itemName, quantity, price = string.match(message, "You won an auction for (.+) %(x(%d+)%) for (.+)$")
    if itemName and quantity and price then
        private.RecordAuctionPurchase(itemName, tonumber(quantity), price)
        return
    end

    itemName, quantity, price = string.match(message, "Your auction of (.+) %(x(%d+)%) has sold for (.+)$")
    if itemName and quantity and price then
        private.RecordAuctionSale(itemName, tonumber(quantity), price)
        return
    end
end

function private.RecordAuctionPurchase(itemName, quantity, priceStr)
    local copperAmount = private.ParsePrice(priceStr)
    if not copperAmount or copperAmount == 0 then
        return
    end

    local AccountingAddon = _G.OneWoW_AltTracker_Accounting
    if not AccountingAddon or not AccountingAddon.Transactions or not OneWoW_AltTracker_Accounting_DB then
        return
    end

    AccountingAddon.Transactions:RecordExpense("auction_purchase", copperAmount, "Auction House", nil, itemName, quantity, "Auction purchase")
    private.InvalidateFinancialCache()
end

function private.RecordAuctionSale(itemName, quantity, priceStr)
    local copperAmount = private.ParsePrice(priceStr)
    if not copperAmount or copperAmount == 0 then
        return
    end

    local AccountingAddon = _G.OneWoW_AltTracker_Accounting
    if not AccountingAddon or not AccountingAddon.Transactions or not OneWoW_AltTracker_Accounting_DB then
        return
    end

    AccountingAddon.Transactions:RecordIncome("auction_sale", copperAmount, "Auction House", nil, itemName, quantity, "Auction sold")
    private.InvalidateFinancialCache()
end

function private.ParsePrice(priceStr)
    local g, s, c = 0, 0, 0

    local goldMatch = string.match(priceStr, "(%d+)g")
    if goldMatch then g = tonumber(goldMatch) end

    local silverMatch = string.match(priceStr, "(%d+)s")
    if silverMatch then s = tonumber(silverMatch) end

    local copperMatch = string.match(priceStr, "(%d+)c")
    if copperMatch then c = tonumber(copperMatch) end

    return g * 10000 + s * 100 + c
end

function private.InvalidateFinancialCache()
    if _G.OneWoW_AltTracker_Accounting then
        if _G.OneWoW_AltTracker_Accounting.InvalidateStatistics then
            _G.OneWoW_AltTracker_Accounting:InvalidateStatistics()
        end
    end
end
