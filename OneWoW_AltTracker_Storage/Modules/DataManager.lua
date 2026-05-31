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
        "GUILDBANKBAGSLOTS_CHANGED",
        "MAIL_SHOW",
        "MAIL_CLOSED",
        "MAIL_INBOX_UPDATE",
        "UPDATE_PENDING_MAIL",
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LOGOUT",
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

    elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
        C_Timer.After(0.3, function()
            self:CollectGuildBank()
        end)

    elseif event == "MAIL_SHOW" then
        C_Timer.After(0.5, function()
            self:CollectMail()
        end)

    elseif event == "MAIL_INBOX_UPDATE" then
        -- Inbox contents actually changed while the mailbox is open: full scan is safe.
        C_Timer.After(0.2, function()
            self:CollectMail()
        end)

    elseif event == "UPDATE_PENDING_MAIL" then
        -- Fires whenever the server flips the "you have new mail" indicator.
        -- This fires away from the mailbox too, so we MUST NOT do a full inbox
        -- scan here (that would return 0 items and wipe the flag). Just refresh
        -- hasNewMail from HasNewMail() and tell the UI to re-skin its icons.
        C_Timer.After(0.2, function()
            self:UpdateMailFlag()
        end)

    elseif event == "MAIL_CLOSED" then
        C_Timer.After(0.2, function()
            self:CollectMail()
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- On login / reload, make sure the current character's mail flag reflects
        -- reality before the UI reads it. HasNewMail() is ready by this point.
        C_Timer.After(1, function()
            self:UpdateMailFlag()
        end)

    elseif event == "PLAYER_LOGOUT" then
        -- Persist final state so other alts can see "Alt X had mail at logout".
        self:UpdateMailFlag()
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

    self:NotifyMailChanged()
    return true
end

function DataManager:UpdateMailFlag()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if ns.Mail and ns.Mail.UpdateHasNewMailFlag then
        ns.Mail:UpdateHasNewMailFlag(charKey, charData)
    end

    self:NotifyMailChanged()
    return true
end

-- Ask AltTracker's UI (if present and loaded) to re-skin any mail icons it has on
-- screen. We don't rebuild tabs here; AltTracker exposes a cheap in-place refresh.
function DataManager:NotifyMailChanged()
    local atUI = _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.UI
    if atUI and type(atUI.RefreshMailIcons) == "function" then
        atUI.RefreshMailIcons()
    end
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

