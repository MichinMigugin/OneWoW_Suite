local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

OneWoW_Mail = {}
local OneWoW_Mail = OneWoW_Mail

local function ApplyLanguage()
    ns.ApplyLanguage()
end

local function InitializeModules()
    if ns.Shell then
        ns.Shell:Initialize()
    end
    if ns.AutoRun then
        ns.AutoRun:Initialize()
    end
end

function OneWoW_Mail:ApplyTheme()
    OneWoW_GUI:ApplyTheme(ns)
    if ns.Shell then
        ns.Shell:ApplyTheme()
    end
end

function OneWoW_Mail:ApplyLanguage()
    ApplyLanguage()
end

function OneWoW_Mail:ReinitForLanguage(_)
    ApplyLanguage()
    if not ns.Shell then
        return
    end
    local mailboxOpen = ns.Shell:IsMailboxOpen()
    local useBlizzard = ns.Shell:UsesBlizzardUI()
    local wasShown = ns.Shell:IsShown()
    ns.Shell:FullReset()
    if mailboxOpen and useBlizzard then
        ns.Shell:EnsureModeButtons()
        return
    end
    if wasShown then
        C_Timer.After(0.1, function()
            if ns.Shell then
                ns.Shell:Show()
            end
        end)
    end
end

local didLogin = false
function OneWoW_Mail:OnPlayerLogin()
    if didLogin then return end
    didLogin = true

    -- Bring up Storage / Character when Mail is wanted (FirstRun datastores).
    OneWoW:EnsureLoaded("OneWoW_AltTracker_Storage")
    OneWoW:EnsureLoaded("OneWoW_AltTracker_Character")

    OneWoW:RegisterMinimap("OneWoW_Mail", ns.L["CTX_OPEN_MAIL"], nil, function()
        if ns.Shell then ns.Shell:Toggle() end
    end)

    if OneWoW_Mail.FireLoginHandlers then
        OneWoW_Mail:FireLoginHandlers()
    end
end

function OneWoW_Mail:OnAddonLoaded()
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_Mail)
    ns:InitializeDatabase()

    local g = ns.db.global
    OneWoW_GUI:MigrateSettings({
        theme = g.theme,
        language = g.language,
        minimap = g.minimap,
    })

    OneWoW_Mail:ApplyTheme()
    ApplyLanguage()
    InitializeModules()

    SLASH_ONEWOW_MAIL1 = "/1wmail"
    SlashCmdList["ONEWOW_MAIL"] = function()
        if ns.Shell then
            ns.Shell:Toggle()
        end
    end

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoW_Mail, function(myself)
        myself:ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoW_Mail, function(myself, lang)
        myself:ReinitForLanguage(lang)
    end)

    local _ver = OneWoW:GetAddonVersion(ADDON_NAME)
    OneWoW:RegisterLoadComponent("Mail", _ver, "/1wmail", ADDON_NAME)
end
