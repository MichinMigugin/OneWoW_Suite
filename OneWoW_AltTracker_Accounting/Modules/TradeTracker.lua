local addonName, ns = ...

ns.TradeTracker = {}
local TradeTracker = ns.TradeTracker

local private = {
    playerMoney = 0,
    targetMoney = 0,
    targetName = nil,
    playerItems = {},
    targetItems = {},
}

function TradeTracker:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TRADE_SHOW")
    frame:RegisterEvent("TRADE_CLOSED")
    frame:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
    frame:RegisterEvent("TRADE_TARGET_ITEM_CHANGED")
    frame:RegisterEvent("TRADE_MONEY_CHANGED")
    frame:RegisterEvent("UI_INFO_MESSAGE")
    frame:SetScript("OnEvent", function(self, event, ...)
        TradeTracker:HandleEvent(event, ...)
    end)
end

function TradeTracker:HandleEvent(event, ...)
    if event == "TRADE_SHOW" then
        private.playerMoney = 0
        private.targetMoney = 0
        private.targetName = UnitName("target")
        wipe(private.playerItems)
        wipe(private.targetItems)

    elseif event == "TRADE_CLOSED" then
        private.targetName = nil
        wipe(private.playerItems)
        wipe(private.targetItems)

    elseif event == "TRADE_MONEY_CHANGED" then
        private.playerMoney = GetPlayerTradeMoney() or 0
        private.targetMoney = GetTargetTradeMoney() or 0

    elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
        local slot = ...
        private.UpdateItem(private.playerItems, slot, GetTradePlayerItemInfo, GetTradePlayerItemLink)

    elseif event == "TRADE_TARGET_ITEM_CHANGED" then
        local slot = ...
        private.UpdateItem(private.targetItems, slot, GetTradeTargetItemInfo, GetTradeTargetItemLink)

    elseif event == "UI_INFO_MESSAGE" then
        local msgType = ...
        if msgType == LE_GAME_ERR_TRADE_COMPLETE then
            TradeTracker:RecordCompletedTrade()
        end
    end
end

function private.UpdateItem(items, slot, infoFunc, linkFunc)
    local name, _, quantity = infoFunc(slot)
    local link = linkFunc(slot)
    if name and link then
        items[slot] = {name = name, link = link, quantity = quantity or 1}
    else
        items[slot] = nil
    end
end

function TradeTracker:RecordCompletedTrade()
    local targetName = private.targetName
    if not targetName then return end

    local playerGaveItems = next(private.playerItems) ~= nil
    local targetGaveItems = next(private.targetItems) ~= nil

    if private.playerMoney > 0 and targetGaveItems and not playerGaveItems then
        for _, item in pairs(private.targetItems) do
            ns.Transactions:RecordExpense("trade_buy", private.playerMoney, targetName, item.link, item.name, item.quantity, "Trade purchase")
        end

    elseif private.targetMoney > 0 and playerGaveItems and not targetGaveItems then
        for _, item in pairs(private.playerItems) do
            ns.Transactions:RecordIncome("trade_sale", private.targetMoney, targetName, item.link, item.name, item.quantity, "Trade sale")
        end

    elseif private.playerMoney > 0 and not targetGaveItems and not playerGaveItems then
        ns.Transactions:RecordExpense("money_transfer_out", private.playerMoney, targetName, nil, "Gold Transfer", nil, "Sent to " .. targetName)

    elseif private.targetMoney > 0 and not playerGaveItems and not targetGaveItems then
        ns.Transactions:RecordIncome("money_transfer_in", private.targetMoney, targetName, nil, "Gold Transfer", nil, "Received from " .. targetName)
    end

    wipe(private.playerItems)
    wipe(private.targetItems)
    private.playerMoney = 0
    private.targetMoney = 0
    private.targetName = nil
end
