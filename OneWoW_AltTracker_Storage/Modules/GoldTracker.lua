local addonName, ns = ...

ns.GoldTracker = {}
local Module = ns.GoldTracker

local private = {
    previousGold = 0,
    eventFrame = nil,
    pendingTransactions = {},
}

function Module:Initialize()
    if self.initialized then return end
    self.initialized = true

    private.previousGold = GetMoney()
    print("[GoldTracker] Initialized, current gold: " .. private.previousGold)

    private.eventFrame = CreateFrame("Frame")
    private.eventFrame:RegisterEvent("PLAYER_MONEY")
    private.eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_MONEY" then
            Module:OnMoneyChanged()
        end
    end)
    print("[GoldTracker] Event listener registered")
end

function Module:OnMoneyChanged()
    local currentGold = GetMoney()
    local delta = currentGold - private.previousGold

    print("[GoldTracker] PLAYER_MONEY fired. Previous: " .. private.previousGold .. " Current: " .. currentGold .. " Delta: " .. delta)

    if delta == 0 then
        return
    end

    local charKey = ns:GetCharacterKey()
    if not charKey then
        private.previousGold = currentGold
        return
    end

    local success
    if delta > 0 then
        success = private.RecordIncome(delta, charKey)
    else
        success = private.RecordExpense(math.abs(delta), charKey)
    end

    if not success then
        print("[GoldTracker] Recording failed, queueing transaction")
        table.insert(private.pendingTransactions, {
            delta = delta,
            charKey = charKey,
            timestamp = GetServerTime(),
        })
        C_Timer.After(1.0, private.ProcessPendingTransactions)
    else
        private.previousGold = currentGold
        private.RefreshUI()
    end
end

function private.ProcessPendingTransactions()
    if #private.pendingTransactions == 0 then
        return
    end

    local i = 1
    while i <= #private.pendingTransactions do
        local tx = private.pendingTransactions[i]
        local success
        if tx.delta > 0 then
            success = private.RecordIncome(tx.delta, tx.charKey)
        else
            success = private.RecordExpense(math.abs(tx.delta), tx.charKey)
        end

        if success then
            print("[GoldTracker] Pending transaction recorded successfully")
            table.remove(private.pendingTransactions, i)
            private.previousGold = GetMoney()
            private.RefreshUI()
        else
            print("[GoldTracker] Pending transaction still failing")
            i = i + 1
        end
    end

    if #private.pendingTransactions > 0 then
        C_Timer.After(1.0, private.ProcessPendingTransactions)
    end
end

function private.RecordIncome(amount, charKey)
    local AccountingAddon = _G.OneWoW_AltTracker_Accounting
    if not AccountingAddon or not AccountingAddon.Transactions or not OneWoW_AltTracker_Accounting_DB then
        print("[GoldTracker] Accounting addon not ready")
        return false
    end

    local success = AccountingAddon.Transactions:RecordIncome("detected_profit", amount, "Detected Gold", nil, "Gold Gain", nil, "Detected via gold change")
    return success
end

function private.RecordExpense(amount, charKey)
    local AccountingAddon = _G.OneWoW_AltTracker_Accounting
    if not AccountingAddon or not AccountingAddon.Transactions or not OneWoW_AltTracker_Accounting_DB then
        print("[GoldTracker] Accounting addon not ready")
        return false
    end

    local success = AccountingAddon.Transactions:RecordExpense("detected_loss", amount, "Detected Gold", nil, "Gold Loss", nil, "Detected via gold change")
    return success
end

function private.RefreshUI()
    print("[GoldTracker] Attempting to refresh UI")
    if not _G.OneWoW_AltTracker then
        print("[GoldTracker] OneWoW_AltTracker not found")
        return
    end
    if not _G.OneWoW_AltTracker.UI then
        print("[GoldTracker] OneWoW_AltTracker.UI not found")
        return
    end
    if not _G.OneWoW_AltTracker.UI.RefreshFinancialsTab then
        print("[GoldTracker] RefreshFinancialsTab function not found")
        return
    end

    local financialsTab = _G.OneWoW_AltTracker.UI.FinancialsTab
    print("[GoldTracker] FinancialsTab exists: " .. (financialsTab and "YES" or "NO"))
    if financialsTab then
        print("[GoldTracker] Scheduling refresh")
        C_Timer.After(0.1, function()
            print("[GoldTracker] Calling RefreshFinancialsTab")
            _G.OneWoW_AltTracker.UI.RefreshFinancialsTab(financialsTab)
        end)
    end
end
