local _, ns = ...

ns.VendorTracker = {}
local VendorTracker = ns.VendorTracker

local OneWoW = OneWoW

local private = {
    goldBeforeRepair = 0,
}

function VendorTracker:Initialize()
    -- Gold-before-repair snapshot routes through the core OneWoW.Merchant show
    -- channel (single MERCHANT_* owner); live merchant state comes from
    -- IsMerchantOpen(). The frame keeps UPDATE_INVENTORY_DURABILITY (not a
    -- merchant event).
    OneWoW.Merchant.RegisterShowCallback("Accounting_VendorTracker", function()
        VendorTracker:OnMerchantShow()
    end)

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
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
end

function VendorTracker:OnMerchantShow()
    private.goldBeforeRepair = GetMoney()
end

function VendorTracker:HandleEvent(event)
    if event == "UPDATE_INVENTORY_DURABILITY" then
        if OneWoW.Merchant.IsMerchantOpen() then
            C_Timer.After(0.1, function()
                VendorTracker:CheckRepairCost()
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
