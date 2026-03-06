local addonName, ns = ...

ns.NpcOrderTracker = {}
local Module = ns.NpcOrderTracker

local private = {
    crafterPending = false,
    crafterGoldBefore = 0,
    crafterPendingTime = 0,
    goldAtCustomerOpen = 0,
    goldBeforeCancel = 0,
}

local MONEY_WINDOW = 15

function Module:Initialize()
    if self.initialized then return end
    self.initialized = true

    local frame = CreateFrame("Frame")

    frame:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")
    frame:RegisterEvent("CRAFTINGORDERS_ORDER_PLACEMENT_RESPONSE")
    frame:RegisterEvent("CRAFTINGORDERS_ORDER_CANCEL_RESPONSE")
    frame:RegisterEvent("CRAFTINGORDERS_FULFILL_ORDER_RESPONSE")
    frame:RegisterEvent("CRAFTINGORDERS_CRAFT_ORDER_RESPONSE")
    frame:RegisterEvent("PLAYER_MONEY")

    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "CRAFTINGORDERS_SHOW_CUSTOMER" then
            private.goldAtCustomerOpen = GetMoney()
            private.goldBeforeCancel = GetMoney()

        elseif event == "CRAFTINGORDERS_ORDER_PLACEMENT_RESPONSE" then
            local result = ...
            if result == 0 then
                local goldBefore = private.goldAtCustomerOpen
                private.goldAtCustomerOpen = 0
                C_Timer.After(0.3, function()
                    local cost = goldBefore - GetMoney()
                    if cost > 0 then
                        ns.Transactions:RecordExpense("crafting_order_placed", cost, "Crafting Order", nil, "Order Commission", nil, nil)
                    end
                    private.goldBeforeCancel = GetMoney()
                end)
            end

        elseif event == "CRAFTINGORDERS_ORDER_CANCEL_RESPONSE" then
            local result = ...
            if result == 0 then
                local goldBefore = private.goldBeforeCancel
                C_Timer.After(0.3, function()
                    local refund = GetMoney() - goldBefore
                    if refund > 0 then
                        ns.Transactions:RecordIncome("crafting_order_refund", refund, "Crafting Order", nil, "Order Cancellation Refund", nil, nil)
                    end
                    private.goldBeforeCancel = GetMoney()
                end)
            end

        elseif event == "CRAFTINGORDERS_FULFILL_ORDER_RESPONSE" then
            local result = ...
            if result == 0 then
                private.crafterPending = true
                private.crafterGoldBefore = GetMoney()
                private.crafterPendingTime = GetServerTime()
            end

        elseif event == "CRAFTINGORDERS_CRAFT_ORDER_RESPONSE" then
            local result = ...
            if result == 0 then
                private.crafterPending = true
                private.crafterGoldBefore = GetMoney()
                private.crafterPendingTime = GetServerTime()
            end

        elseif event == "PLAYER_MONEY" then
            if not private.crafterPending then return end
            if (GetServerTime() - private.crafterPendingTime) > MONEY_WINDOW then
                private.crafterPending = false
                return
            end
            local gained = GetMoney() - private.crafterGoldBefore
            if gained > 0 then
                ns.Transactions:RecordIncome("crafting_order", gained, "Crafting Order", nil, "Crafting Order", nil, nil)
                private.crafterPending = false
            end
        end
    end)
end
