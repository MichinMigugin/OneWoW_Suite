local _, ns = ...

ns.GoldWatcher = {}
local GoldWatcher = ns.GoldWatcher

local previousGold = 0
local FALLBACK_DELAY = 1.0
local isMailboxOpen = false
local pendingAuctionSales = {}
local pendingAuctionRefunds = {}

local function getCharKey()
    return ns:GetCharacterKey()
end

local function persistLastMoney(copper)
    local db = OneWoW_AltTracker_Accounting_DB
    local charKey = getCharKey()
    if not db or not db.settings or not charKey then return end
    if not db.settings.lastMoneyByCharacter then
        db.settings.lastMoneyByCharacter = {}
    end
    db.settings.lastMoneyByCharacter[charKey] = copper
end

local function readLastMoney()
    local db = OneWoW_AltTracker_Accounting_DB
    local charKey = getCharKey()
    if not db or not db.settings or not db.settings.lastMoneyByCharacter or not charKey then
        return nil
    end
    return db.settings.lastMoneyByCharacter[charKey]
end

local function recordSellerInvoice(entry)
    local consignment = entry.consignment or 0
    local deposit = entry.deposit or 0
    local sale = entry.bid or 0
    if sale <= 0 then
        -- Reconstruct from Blizzard: money = bid + deposit - consignment.
        sale = (entry.amount or 0) - deposit + consignment
    end
    ns.Transactions:RecordIncome(
        "auction_sale", sale, entry.buyer, nil, entry.itemName, entry.quantity, "Auction sold")
    if deposit > 0 then
        ns.Transactions:RecordIncome(
            "auction_deposit", deposit, "Auction House", nil, entry.itemName, entry.quantity, "AH deposit refund")
    end
    if consignment > 0 then
        ns.Transactions:RecordExpense(
            "auction_fee", consignment, "Auction House", nil, entry.itemName, entry.quantity, "AH house cut")
    end
    -- PLAYER_MONEY only moves by the net mail amount; claim that so a later
    -- GoldWatcher pass does not also write uncategorized / re-claim the sale.
    ns.Transactions:ClaimAmount(entry.amount)
end

local function recordBuyerRefund(entry)
    ns.Transactions:RecordIncome(
        "auction_refund", entry.amount, "Auction House", nil, entry.itemName, entry.quantity, "AH refund")
    ns.Transactions:ClaimAmount(entry.amount)
end

function GoldWatcher:Initialize()
    if self.initialized then return end
    self.initialized = true

    local current = GetMoney()
    local lastMoney = readLastMoney()
    if lastMoney ~= nil and lastMoney ~= current then
        local delta = current - lastMoney
        local absDelta = math.abs(delta)
        if absDelta > 0 then
            if delta > 0 then
                ns.Transactions:RecordIncome(
                    "offline_delta", absDelta, "Offline", nil, "Offline Gold Change", nil, "Gold changed while offline")
            else
                ns.Transactions:RecordExpense(
                    "offline_delta", absDelta, "Offline", nil, "Offline Gold Change", nil, "Gold changed while offline")
            end
        end
    end

    previousGold = current
    persistLastMoney(current)

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
                GoldWatcher:ScanInboxForAuctionMail()
            end)
        elseif event == "MAIL_INBOX_UPDATE" then
            if isMailboxOpen then
                C_Timer.After(0.3, function()
                    GoldWatcher:ScanInboxForAuctionMail()
                end)
            end
        elseif event == "MAIL_CLOSED" then
            isMailboxOpen = false
            wipe(pendingAuctionSales)
            wipe(pendingAuctionRefunds)
        end
    end)
end

function GoldWatcher:ScanInboxForAuctionMail()
    local numItems = GetInboxNumItems()
    for i = 1, numItems do
        local _, _, _, _, money = GetInboxHeaderInfo(i)
        if money and money > 0 then
            local invoiceType, itemName, playerName, bid, _, deposit, consignment, _, _, _, count = GetInboxInvoiceInfo(i)
            itemName = itemName or "Auction Item"
            count = count or 1

            if invoiceType == "seller" or invoiceType == "seller_temp_invoice" then
                local already = false
                for _, entry in ipairs(pendingAuctionSales) do
                    if not entry.consumed and entry.amount == money and entry.itemName == itemName then
                        already = true
                        break
                    end
                end
                if not already then
                    table.insert(pendingAuctionSales, {
                        amount = money,
                        bid = bid or 0,
                        deposit = deposit or 0,
                        itemName = itemName,
                        buyer = playerName or "Auction House",
                        quantity = count,
                        consignment = consignment or 0,
                        consumed = false,
                    })
                end
            elseif invoiceType == "buyer" then
                local already = false
                for _, entry in ipairs(pendingAuctionRefunds) do
                    if not entry.consumed and entry.amount == money and entry.itemName == itemName then
                        already = true
                        break
                    end
                end
                if not already then
                    table.insert(pendingAuctionRefunds, {
                        amount = money,
                        itemName = itemName,
                        quantity = count,
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
            recordSellerInvoice(entry)
            return true
        end
    end

    local remaining = amount
    local matched = {}
    for _, entry in ipairs(pendingAuctionSales) do
        if not entry.consumed and entry.amount <= remaining + 1 then
            table.insert(matched, entry)
            remaining = remaining - entry.amount
            if remaining <= 1 then break end
        end
    end

    if remaining <= 1 and #matched > 0 then
        for _, entry in ipairs(matched) do
            entry.consumed = true
            recordSellerInvoice(entry)
        end
        return true
    end

    return false
end

function GoldWatcher:TryClaimPendingAuctionRefunds(amount)
    for _, entry in ipairs(pendingAuctionRefunds) do
        if not entry.consumed and math.abs(entry.amount - amount) <= 1 then
            entry.consumed = true
            recordBuyerRefund(entry)
            return true
        end
    end
    return false
end

function GoldWatcher:OnMoneyChanged()
    local current = GetMoney()
    local delta = current - previousGold
    previousGold = current
    persistLastMoney(current)

    if delta == 0 then return end

    local absDelta = math.abs(delta)
    local isIncome = delta > 0

    C_Timer.After(FALLBACK_DELAY, function()
        if ns.Transactions:IsAmountClaimed(absDelta) then
            return
        end

        if isIncome and isMailboxOpen then
            if GoldWatcher:TryClaimPendingAuctionSales(absDelta) then
                return
            end
            if GoldWatcher:TryClaimPendingAuctionRefunds(absDelta) then
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
