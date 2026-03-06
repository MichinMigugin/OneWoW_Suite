local addonName, ns = ...

ns.BankTracker = {}
local BankTracker = ns.BankTracker

local goldBeforeBank = 0
local guildBankOpen = false
local warbandBankOpen = false

function BankTracker:Initialize()
    self:RegisterEvents()
end

function BankTracker:RegisterEvents()
    local frame = CreateFrame("Frame")

    frame:RegisterEvent("GUILDBANKFRAME_OPENED")
    frame:RegisterEvent("GUILDBANKFRAME_CLOSED")
    frame:RegisterEvent("BANKFRAME_OPENED")
    frame:RegisterEvent("BANKFRAME_CLOSED")
    frame:RegisterEvent("PLAYER_MONEY")

    frame:SetScript("OnEvent", function(self, event, ...)
        BankTracker:HandleEvent(event, ...)
    end)
end

function BankTracker:HandleEvent(event, ...)
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
