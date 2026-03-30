local addonName, ns = ...

ns.GoldWatcher = {}
local GoldWatcher = ns.GoldWatcher

local previousGold = 0
local FALLBACK_DELAY = 1.0
local isMailboxOpen = false
local pendingAuctionSales = {}

function GoldWatcher:Initialize()
    if self.initialized then return end
    self.initialized = true

    previousGold = GetMoney()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_MONEY")
    frame:RegisterEvent("MAIL_SHOW")
    frame:RegisterEvent("MAIL_CLOSED")
    frame:RegisterEvent("MAIL_INBOX_UPDATE")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_MONEY" then
            GoldWatcher:OnMoneyChanged()
        elseif event == "MAIL_SHOW" then
            isMailboxOpen = true
            C_Timer.After(0.5, function()
                GoldWatcher:ScanInboxForAuctionSales()
            end)
        elseif event == "MAIL_INBOX_UPDATE" then
            if isMailboxOpen then
                C_Timer.After(0.3, function()
                    GoldWatcher:ScanInboxForAuctionSales()
                end)
            end
        elseif event == "MAIL_CLOSED" then
            isMailboxOpen = false
            wipe(pendingAuctionSales)
        end
    end)
end

function GoldWatcher:ScanInboxForAuctionSales()
    local numItems = GetInboxNumItems()
    for i = 1, numItems do
        local _, _, sender, subject, money = GetInboxHeaderInfo(i)
        if money and money > 0 then
            local invoiceType, itemName, buyer, bid, buyout, deposit, consignment, count = GetInboxInvoiceInfo(i)
            if invoiceType == "seller" or invoiceType == "seller_temp_invoice" then
                local already = false
                for _, entry in ipairs(pendingAuctionSales) do
                    if not entry.consumed and entry.amount == money and entry.itemName == (itemName or "Auction Item") then
                        already = true
                        break
                    end
                end
                if not already then
                    table.insert(pendingAuctionSales, {
                        amount = money,
                        itemName = itemName or "Auction Item",
                        buyer = buyer or "Auction House",
                        quantity = count or 1,
                        consumed = false,
                    })
                end
            end
        end
    end
end

function GoldWatcher:TryClaimPendingAuctionSales(amount)
    for _, entry in ipairs(pendingAuctionSales) do
        if not entry.consumed and math.abs(entry.amount - amount) <= 1 then
            entry.consumed = true
            ns.Transactions:RecordIncome("auction_sale", amount, entry.buyer, nil, entry.itemName, entry.quantity, "Auction sold")
            return true
        end
    end

    local remaining = amount
    local matched = {}
    for i, entry in ipairs(pendingAuctionSales) do
        if not entry.consumed and entry.amount <= remaining + 1 then
            table.insert(matched, entry)
            remaining = remaining - entry.amount
            if remaining <= 1 then break end
        end
    end

    if remaining <= 1 and #matched > 0 then
        for _, entry in ipairs(matched) do
            entry.consumed = true
            ns.Transactions:RecordIncome("auction_sale", entry.amount, entry.buyer, nil, entry.itemName, entry.quantity, "Auction sold")
        end
        return true
    end

    return false
end

function GoldWatcher:OnMoneyChanged()
    local current = GetMoney()
    local delta = current - previousGold
    previousGold = current

    if delta == 0 then return end

    local absDelta = math.abs(delta)
    local isIncome = delta > 0

    C_Timer.After(FALLBACK_DELAY, function()
        if ns.Transactions:IsAmountClaimed(absDelta, FALLBACK_DELAY + 0.5) then
            return
        end

        if isIncome and isMailboxOpen then
            if GoldWatcher:TryClaimPendingAuctionSales(absDelta) then
                return
            end
        end

        if isIncome then
            ns.Transactions:RecordIncome("uncategorized", absDelta, "Unknown", nil, "Uncategorized Income", nil, nil)
        else
            ns.Transactions:RecordExpense("uncategorized", absDelta, "Unknown", nil, "Uncategorized Expense", nil, nil)
        end
    end)
end

function GoldWatcher:GetPreviousGold()
    return previousGold
end
