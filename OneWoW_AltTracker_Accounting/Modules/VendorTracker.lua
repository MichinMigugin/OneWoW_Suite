local addonName, ns = ...

ns.VendorTracker = {}
local VendorTracker = ns.VendorTracker

local private = {
    goldBeforeRepair = 0,
    merchantOpen = false,
}

function VendorTracker:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:RegisterEvent("MERCHANT_CLOSED")
    frame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    frame:SetScript("OnEvent", function(self, event, ...)
        VendorTracker:HandleEvent(event, ...)
    end)

    hooksecurefunc("BuyMerchantItem", function(index, quantity)
        VendorTracker:OnBuyMerchantItem(index, quantity)
    end)

    hooksecurefunc("BuybackItem", function(index)
        VendorTracker:OnBuybackItem(index)
    end)

    if C_Container then
        hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
            VendorTracker:OnUseContainerItem(bag, slot)
        end)
    else
        hooksecurefunc("UseContainerItem", function(bag, slot)
            VendorTracker:OnUseContainerItem(bag, slot)
        end)
    end
end

function VendorTracker:HandleEvent(event, ...)
    if event == "MERCHANT_SHOW" then
        private.merchantOpen = true
        private.goldBeforeRepair = GetMoney()
    elseif event == "MERCHANT_CLOSED" then
        private.merchantOpen = false
    elseif event == "UPDATE_INVENTORY_DURABILITY" then
        if private.merchantOpen then
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
    if not private.merchantOpen then return end
    local itemInfo = C_MerchantFrame.GetItemInfo(index)
    local itemLink = GetMerchantItemLink(index)
    if itemInfo and itemInfo.name and itemInfo.price and itemInfo.price > 0 then
        quantity = quantity or 1
        ns.Transactions:RecordExpense("vendor_purchase", itemInfo.price * quantity, "Vendor", itemLink, itemInfo.name, quantity, nil)
    end
end

function VendorTracker:OnBuybackItem(index)
    local itemLink = GetBuybackItemLink(index)
    local name, texture, count, price = GetBuybackItemInfo(index)
    if name and price and price > 0 then
        ns.Transactions:RecordExpense("vendor_buyback", price, "Vendor", itemLink, name, count or 1, nil)
    end
end

function VendorTracker:OnUseContainerItem(bag, slot)
    if not private.merchantOpen then return end
    local itemLink = C_Container and C_Container.GetContainerItemLink(bag, slot) or GetContainerItemLink(bag, slot)
    if not itemLink then return end
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if not itemID then return end
    local name, _, _, _, _, _, _, stackCount, _, _, sellPrice = C_Item.GetItemInfo(itemID)
    local info = C_Container and C_Container.GetContainerItemInfo(bag, slot)
    local count = (info and info.stackCount) or stackCount or 1
    if sellPrice and sellPrice > 0 then
        ns.Transactions:RecordIncome("vendor_sale", sellPrice * count, "Vendor", itemLink, name or "Item", count, nil)
    end
end
