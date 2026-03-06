local addonName, ns = ...

ns.DataManager = {}
local DataManager = ns.DataManager

local eventFrame = nil
local initialized = false

function DataManager:Initialize()
    if initialized then return end
    initialized = true
end

function DataManager:RegisterEvents()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
    end

    local events = {
        "BAG_UPDATE_DELAYED",
        "BANKFRAME_OPENED",
        "BANKFRAME_CLOSED",
        "GUILDBANKFRAME_OPENED",
        "GUILDBANKFRAME_CLOSED",
        "GUILDBANK_UPDATE_TABS",
        "MAIL_SHOW",
        "MAIL_CLOSED",
        "MAIL_INBOX_UPDATE",
        "UPDATE_PENDING_MAIL",
    }

    for _, event in ipairs(events) do
        eventFrame:RegisterEvent(event)
    end

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        DataManager:HandleEvent(event, ...)
    end)
end

function DataManager:HandleEvent(event, ...)
    if event == "BAG_UPDATE_DELAYED" then
        self:CollectBags()

        if C_Bank and C_Bank.CanUseBank then
            if C_Bank.CanUseBank(Enum.BankType.Character) then
                C_Timer.After(0.3, function()
                    self:CollectPersonalBank()
                end)
            end

            if C_Bank.CanUseBank(Enum.BankType.Account) then
                C_Timer.After(0.3, function()
                    self:CollectWarbandBank()
                end)
            end
        end

    elseif event == "BANKFRAME_OPENED" then
        C_Timer.After(0.5, function()
            self:CollectPersonalBank()
        end)

        if C_Bank and C_Bank.CanUseBank and C_Bank.CanUseBank(Enum.BankType.Account) then
            C_Timer.After(0.5, function()
                self:CollectWarbandBank()
            end)
        end

    elseif event == "GUILDBANKFRAME_OPENED" then
        C_Timer.After(0.5, function()
            self:CollectGuildBank()
        end)

    elseif event == "GUILDBANK_UPDATE_TABS" then
        C_Timer.After(0.2, function()
            self:CollectGuildBank()
        end)

    elseif event == "MAIL_SHOW" then
        C_Timer.After(0.5, function()
            self:CollectMail()
        end)

    elseif event == "MAIL_INBOX_UPDATE" or event == "UPDATE_PENDING_MAIL" then
        C_Timer.After(0.2, function()
            self:CollectMail()
        end)

    elseif event == "MAIL_CLOSED" then
        C_Timer.After(0.2, function()
            self:CollectMail()
        end)
    end
end

function DataManager:CollectBags()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if ns.DatabaseDefaults.settings.trackBags then
        ns.Bags:CollectData(charKey, charData)
    end

    if _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.UI and _G.OneWoW_AltTracker.UI.BankTab then
        local bankTab = _G.OneWoW_AltTracker.UI.BankTab
        if bankTab and bankTab:IsVisible() and _G.OneWoW_AltTracker.UI.RefreshBankDisplay then
            C_Timer.After(0.1, function()
                _G.OneWoW_AltTracker.UI.RefreshBankDisplay(bankTab)
            end)
        end
    end

    return true
end

function DataManager:CollectPersonalBank()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if ns.DatabaseDefaults.settings.trackPersonalBank then
        ns.PersonalBank:CollectData(charKey, charData)
    end

    if _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.UI and _G.OneWoW_AltTracker.UI.BankTab then
        local bankTab = _G.OneWoW_AltTracker.UI.BankTab
        if bankTab and bankTab:IsVisible() and _G.OneWoW_AltTracker.UI.RefreshBankDisplay then
            C_Timer.After(0.1, function()
                _G.OneWoW_AltTracker.UI.RefreshBankDisplay(bankTab)
            end)
        end
    end

    return true
end

function DataManager:CollectWarbandBank()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if ns.DatabaseDefaults.settings.trackWarbandBank then
        ns.WarbandBank:CollectData(charKey, charData)
    end

    if _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.UI and _G.OneWoW_AltTracker.UI.BankTab then
        local bankTab = _G.OneWoW_AltTracker.UI.BankTab
        if bankTab and bankTab:IsVisible() and _G.OneWoW_AltTracker.UI.RefreshBankDisplay then
            C_Timer.After(0.1, function()
                _G.OneWoW_AltTracker.UI.RefreshBankDisplay(bankTab)
            end)
        end
    end

    return true
end

function DataManager:CollectGuildBank()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if ns.DatabaseDefaults.settings.trackGuildBank then
        ns.GuildBank:CollectData(charKey, charData)
    end

    if _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.UI and _G.OneWoW_AltTracker.UI.BankTab then
        local bankTab = _G.OneWoW_AltTracker.UI.BankTab
        if bankTab and bankTab:IsVisible() and _G.OneWoW_AltTracker.UI.RefreshBankDisplay then
            C_Timer.After(0.1, function()
                _G.OneWoW_AltTracker.UI.RefreshBankDisplay(bankTab)
            end)
        end
    end

    return true
end

function DataManager:CollectMail()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if ns.DatabaseDefaults.settings.trackMail then
        ns.Mail:CollectData(charKey, charData)
    end

    return true
end

function DataManager:CollectAllData()
    self:CollectBags()

    return true
end

function DataManager:GetCharacterData(charKey)
    return ns:GetCharacterData(charKey)
end

function DataManager:GetAllCharacters()
    return ns:GetAllCharacters()
end

function DataManager:DeleteCharacter(charKey)
    return ns:DeleteCharacter(charKey)
end

