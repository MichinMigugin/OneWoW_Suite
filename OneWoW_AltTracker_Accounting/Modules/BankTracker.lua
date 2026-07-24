local _, ns = ...

local Inventory = OneWoW.Inventory

ns.BankTracker = {}
local BankTracker = ns.BankTracker

local INVENTORY_OWNER = "Accounting_BankTracker"

local goldBeforeBank = 0
local guildBankOpen = false
local warbandBankOpen = false
local pendingTabPurchase = nil

local TAB_PURCHASE_WINDOW = 10

local function bankTypeLabel(bankType)
    if bankType == Enum.BankType.Account then
        return "Warband Bank"
    elseif bankType == Enum.BankType.Guild then
        return "Guild Bank"
    end
    return "Character Bank"
end

function BankTracker:Initialize()
    self:RegisterEvents()
end

function BankTracker:RegisterEvents()
    Inventory.RegisterBankOpenCallback(INVENTORY_OWNER, function()
        BankTracker:HandleEvent("BANKFRAME_OPENED")
    end)
    Inventory.RegisterBankClosedCallback(INVENTORY_OWNER, function()
        BankTracker:HandleEvent("BANKFRAME_CLOSED")
    end)
    Inventory.RegisterGuildOpenCallback(INVENTORY_OWNER, function()
        BankTracker:HandleEvent("GUILDBANKFRAME_OPENED")
    end)
    Inventory.RegisterGuildClosedCallback(INVENTORY_OWNER, function()
        BankTracker:HandleEvent("GUILDBANKFRAME_CLOSED")
    end)

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_MONEY")
    frame:SetScript("OnEvent", function(_, event)
        BankTracker:HandleEvent(event)
    end)

    -- Post-hook: money may already be deducted, or may arrive on PLAYER_MONEY.
    -- Prefer goldBeforeBank (maintained while a bank UI is open) as the baseline.
    hooksecurefunc(C_Bank, "PurchaseBankTab", function(bankType)
        BankTracker:OnPurchaseBankTab(bankType)
    end)
end

function BankTracker:OnPurchaseBankTab(bankType)
    local goldNow = GetMoney()
    local baseline = goldBeforeBank
    if baseline <= 0 then
        baseline = goldNow
    end

    pendingTabPurchase = {
        bankType = bankType,
        goldBefore = goldNow,
        time = GetTime(),
        recorded = false,
    }

    local immediateCost = baseline - goldNow
    if immediateCost > 0 then
        ns.Transactions:RecordExpense(
            "bank_tab_purchase",
            immediateCost,
            bankTypeLabel(bankType),
            nil,
            "Bank Tab",
            nil,
            "Purchased bank tab")
        pendingTabPurchase.recorded = true
        goldBeforeBank = goldNow
    end
end

function BankTracker:HandleEvent(event)
    if event == "GUILDBANKFRAME_OPENED" then
        guildBankOpen = true
        goldBeforeBank = GetMoney()

    elseif event == "GUILDBANKFRAME_CLOSED" then
        if guildBankOpen then
            C_Timer.After(0.1, function()
                self:CheckGuildBankTransaction()
            end)
        end
        guildBankOpen = false

    elseif event == "BANKFRAME_OPENED" then
        warbandBankOpen = true
        goldBeforeBank = GetMoney()

    elseif event == "BANKFRAME_CLOSED" then
        if warbandBankOpen then
            C_Timer.After(0.1, function()
                self:CheckWarbandBankTransaction()
            end)
        end
        warbandBankOpen = false

    elseif event == "PLAYER_MONEY" then
        if pendingTabPurchase and (GetTime() - pendingTabPurchase.time) <= TAB_PURCHASE_WINDOW then
            local goldAfter = GetMoney()
            local cost = pendingTabPurchase.goldBefore - goldAfter
            if cost > 0 and not pendingTabPurchase.recorded then
                ns.Transactions:RecordExpense(
                    "bank_tab_purchase",
                    cost,
                    bankTypeLabel(pendingTabPurchase.bankType),
                    nil,
                    "Bank Tab",
                    nil,
                    "Purchased bank tab")
                pendingTabPurchase.recorded = true
                goldBeforeBank = goldAfter
                pendingTabPurchase = nil
                return
            elseif cost > 0 and pendingTabPurchase.recorded then
                ns.Transactions:ClaimAmount(cost)
                goldBeforeBank = goldAfter
                pendingTabPurchase = nil
                return
            elseif pendingTabPurchase.recorded then
                pendingTabPurchase = nil
            end
        end

        if guildBankOpen or warbandBankOpen then
            C_Timer.After(0.2, function()
                if guildBankOpen then
                    self:CheckGuildBankTransaction()
                elseif warbandBankOpen then
                    self:CheckWarbandBankTransaction()
                end
            end)
        end
    end
end

function BankTracker:CheckGuildBankTransaction()
    local goldAfter = GetMoney()
    local difference = goldAfter - goldBeforeBank

    local guildAsPersonal = OneWoW_AltTracker_Accounting_DB and
                            OneWoW_AltTracker_Accounting_DB.settings and
                            OneWoW_AltTracker_Accounting_DB.settings.guildAsPersonal == true

    if guildAsPersonal then
        if difference ~= 0 then
            ns.Transactions:RecordTransfer(
                difference > 0 and "guild_bank_withdraw" or "guild_bank_deposit",
                math.abs(difference), "Guild Bank", nil, "Gold Transfer", nil, nil)
        end
    else
        if difference > 0 then
            ns.Transactions:RecordIncome("guild_bank_withdraw", difference, "Guild Bank", nil, "Gold Withdrawal", nil, nil)
        elseif difference < 0 then
            ns.Transactions:RecordExpense("guild_bank_deposit", math.abs(difference), "Guild Bank", nil, "Gold Deposit", nil, nil)
        end
    end

    goldBeforeBank = goldAfter
end

function BankTracker:CheckWarbandBankTransaction()
    local goldAfter = GetMoney()
    local difference = goldAfter - goldBeforeBank

    if difference ~= 0 then
        ns.Transactions:RecordTransfer(
            difference > 0 and "warband_bank_withdraw" or "warband_bank_deposit",
            math.abs(difference), "Warband Bank", nil, "Gold Transfer", nil, nil)
    end

    goldBeforeBank = goldAfter
end
