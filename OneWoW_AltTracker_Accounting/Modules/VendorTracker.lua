local _, ns = ...

ns.VendorTracker = {}
local VendorTracker = ns.VendorTracker

local OneWoW = OneWoW

local private = {
    goldBeforeRepair = 0,
    pendingCursorSell = nil,
    pendingJunkSale = nil,
    goldBeforeMoney = 0,
}

local MERCHANT_INCOME_DELAY = 0.3
local JUNK_SALE_WINDOW = 5

function VendorTracker:Initialize()
    -- Gold-before-repair snapshot routes through the core OneWoW.Merchant show
    -- channel (single MERCHANT_* owner); live merchant state comes from
    -- IsMerchantOpen(). The frame keeps UPDATE_INVENTORY_DURABILITY (not a
    -- merchant event) plus PLAYER_MONEY for junk-sale / merchant income nets.
    OneWoW.Merchant.RegisterShowCallback("Accounting_VendorTracker", function()
        VendorTracker:OnMerchantShow()
    end)

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    frame:RegisterEvent("PLAYER_MONEY")
    frame:SetScript("OnEvent", function(_, event)
        VendorTracker:HandleEvent(event)
    end)

    hooksecurefunc("BuyMerchantItem", function(index, quantity)
        VendorTracker:OnBuyMerchantItem(index, quantity)
    end)

    hooksecurefunc("BuybackItem", function(index)
        VendorTracker:OnBuybackItem(index)
    end)

    hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
        VendorTracker:OnUseContainerItem(bag, slot)
    end)

    -- QoL VendorPanel and drag-to-merchant sells use Pickup + SellCursorItem,
    -- which bypass UseContainerItem. Snapshot sell info on pickup; record on sell.
    hooksecurefunc(C_Container, "PickupContainerItem", function(bag, slot)
        VendorTracker:OnPickupContainerItem(bag, slot)
    end)

    hooksecurefunc("SellCursorItem", function()
        VendorTracker:OnSellCursorItem()
    end)

    hooksecurefunc(C_MerchantFrame, "SellAllJunkItems", function()
        VendorTracker:OnSellAllJunkItems()
    end)
end

function VendorTracker:OnMerchantShow()
    private.goldBeforeRepair = GetMoney()
    private.goldBeforeMoney = GetMoney()
end

function VendorTracker:HandleEvent(event)
    if event == "UPDATE_INVENTORY_DURABILITY" then
        if OneWoW.Merchant.IsMerchantOpen() then
            C_Timer.After(0.1, function()
                VendorTracker:CheckRepairCost()
            end)
        end
    elseif event == "PLAYER_MONEY" then
        if not OneWoW.Merchant.IsMerchantOpen() then
            private.pendingJunkSale = nil
            private.goldBeforeMoney = GetMoney()
            return
        end

        local goldAfter = GetMoney()
        local delta = goldAfter - private.goldBeforeMoney
        private.goldBeforeMoney = goldAfter

        if private.pendingJunkSale and (GetTime() - private.pendingJunkSale.time) <= JUNK_SALE_WINDOW then
            if delta > 0 then
                ns.Transactions:RecordIncome(
                    "vendor_sale", delta, "Vendor", nil, "Junk Sale", nil, "Sell all junk")
                private.pendingJunkSale = nil
                return
            end
        end

        if delta > 0 then
            local absDelta = delta
            C_Timer.After(MERCHANT_INCOME_DELAY, function()
                if not OneWoW.Merchant.IsMerchantOpen() then return end
                if ns.Transactions:HasClaimForAmount(absDelta) then return end
                ns.Transactions:RecordIncome(
                    "vendor_sale", absDelta, "Vendor", nil, "Vendor Sale", nil, nil)
            end)
        end
    end
end

function VendorTracker:CheckRepairCost()
    local goldAfter = GetMoney()
    local repairCost = private.goldBeforeRepair - goldAfter
    if repairCost > 0 then
        ns.Transactions:RecordExpense("repair", repairCost, "Vendor", nil, "Armor Repair", nil, nil)
    end
    private.goldBeforeRepair = goldAfter
end

function VendorTracker:OnBuyMerchantItem(index, quantity)
    if not OneWoW.Merchant.IsMerchantOpen() then return end
    local itemInfo = C_MerchantFrame.GetItemInfo(index)
    local itemLink = GetMerchantItemLink(index)
    if itemInfo and itemInfo.name and itemInfo.price and itemInfo.price > 0 then
        quantity = quantity or 1
        ns.Transactions:RecordExpense("vendor_purchase", itemInfo.price * quantity, "Vendor", itemLink, itemInfo.name, quantity, nil)
    end
end

function VendorTracker:OnBuybackItem(index)
    local itemLink = GetBuybackItemLink(index)
    local name, _, count, price = GetBuybackItemInfo(index)
    if name and price and price > 0 then
        ns.Transactions:RecordExpense("vendor_buyback", price, "Vendor", itemLink, name, count or 1, nil)
    end
end

function VendorTracker:OnUseContainerItem(bag, slot)
    if not OneWoW.Merchant.IsMerchantOpen() then return end
    local itemLink = C_Container.GetContainerItemLink(bag, slot)
    if not itemLink then return end
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if not itemID then return end
    local name, _, _, _, _, _, _, stackCount, _, _, sellPrice = C_Item.GetItemInfo(itemID)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local count = (info and info.stackCount) or stackCount or 1
    if sellPrice and sellPrice > 0 then
        ns.Transactions:RecordIncome("vendor_sale", sellPrice * count, "Vendor", itemLink, name or "Item", count, nil)
    end
end

function VendorTracker:OnPickupContainerItem(bag, slot)
    if not OneWoW.Merchant.IsMerchantOpen() then
        private.pendingCursorSell = nil
        return
    end
    local itemLink = C_Container.GetContainerItemLink(bag, slot)
    if not itemLink then
        private.pendingCursorSell = nil
        return
    end
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if not itemID then
        private.pendingCursorSell = nil
        return
    end
    local name, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemID)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local count = (info and info.stackCount) or 1
    if sellPrice and sellPrice > 0 then
        private.pendingCursorSell = {
            amount = sellPrice * count,
            itemLink = itemLink,
            name = name or "Item",
            count = count,
            time = GetTime(),
        }
    else
        private.pendingCursorSell = nil
    end
end

function VendorTracker:OnSellCursorItem()
    if not OneWoW.Merchant.IsMerchantOpen() then
        private.pendingCursorSell = nil
        return
    end
    local pending = private.pendingCursorSell
    private.pendingCursorSell = nil
    if not pending or not pending.amount or pending.amount <= 0 then return end
    if (GetTime() - pending.time) > 10 then return end
    ns.Transactions:RecordIncome(
        "vendor_sale", pending.amount, "Vendor", pending.itemLink, pending.name, pending.count, nil)
end

function VendorTracker:OnSellAllJunkItems()
    if not OneWoW.Merchant.IsMerchantOpen() then return end
    private.pendingJunkSale = {
        goldBefore = GetMoney(),
        time = GetTime(),
    }
    private.goldBeforeMoney = GetMoney()
end
