local addonName, ns = ...

ns.GoldWatcher = {}
local GoldWatcher = ns.GoldWatcher

local previousGold = 0
local FALLBACK_DELAY = 1.0

function GoldWatcher:Initialize()
    if self.initialized then return end
    self.initialized = true

    previousGold = GetMoney()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_MONEY")
    frame:SetScript("OnEvent", function()
        GoldWatcher:OnMoneyChanged()
    end)
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
