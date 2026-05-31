local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

OneWoW_QoL = {}
local addon = OneWoW_QoL

ns.oneWoWHubActive = false

local function RegisterWithOneWoW()
    if not OneWoW then return false end
    if not OneWoW.RegisterModule then return false end

    local tabs = {
        { name = "features", displayName = function() return ns.L["TAB_FEATURES"] or "QoL Features" end, create = function(p) ns.UI.CreateFeaturesTab(p) end },
        { name = "toggles",  displayName = function() return ns.L["TAB_TOGGLES"]  or "Toggles"      end, create = function(p) ns.UI.CreateTogglesTab(p) end },
    }
    if OneWoW.GUI and OneWoW.GUI.GetQoLFeatureTabs then
        for _, tab in ipairs(OneWoW.GUI:GetQoLFeatureTabs()) do
            table.insert(tabs, tab)
        end
    end
    OneWoW:RegisterModule({
        name = "qol",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "QoL" end,
        addonName = "OneWoW_QoL",
        order = 4,
        tabs = tabs,
    })
    OneWoW:RegisterSettingsPanel({
        name        = "qol",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "QoL" end,
        order       = 4,
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
    ns.oneWoWHubActive = true
    return true
end

local function OnInitialize()
    addon:InitializeDatabase()

    OneWoW_GUI:MigrateSettings(addon.db.global)

    OneWoW_GUI:ApplyTheme(addon)
    if ns.ApplyLanguage then ns.ApplyLanguage() end

    local function slashHandler() addon:SlashCommandHandler() end
    DB:RegisterSlashCommand("owqol", slashHandler)
    DB:RegisterSlashCommand("onewowqol", slashHandler)
    DB:RegisterSlashCommand("1wqol", slashHandler)

    if OneWoW_GUI.RegisterSettingsCallback then
        OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", addon, function(myself)
            OneWoW_GUI:ApplyTheme(myself)
        end)
        OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", addon, function()
            if ns.ApplyLanguage then ns.ApplyLanguage() end
        end)
    end

    local _ver = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
    if OneWoW and OneWoW.RegisterLoadComponent then
        OneWoW:RegisterLoadComponent("QoL", _ver, "/1wqol")
    end
end

function addon:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function addon:ApplyLanguage()
    if ns.ApplyLanguage then
        ns.ApplyLanguage()
    end
end

local function OnEnable()
    if ns.Core and ns.Core.Initialize then
        ns.Core:Initialize()
    end

    RegisterWithOneWoW()

    if OneWoW then
        OneWoW:RegisterMinimap("OneWoW_QoL", (OneWoW.L and OneWoW.L["CTX_OPEN_QOL"]) or "Open QoL", "qol", nil)
    end

    addon.PlayMountsModule = ns.PlayMountsModule
    addon.ModuleRegistry = ns.ModuleRegistry
    addon.UI = ns.UI
end

function addon:SlashCommandHandler()
    if ns.oneWoWHubActive and OneWoW and OneWoW.GUI then
        OneWoW.GUI:Show("qol")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

function addon:CopyTextKeybind()
    if ns.CopyTextModule then
        ns.CopyTextModule:Capture()
    end
end

function addon:InitializeDatabase()
    ns.InitializeDatabase(self)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        OnInitialize()
    elseif event == "PLAYER_LOGIN" then
        OnEnable()
    end
end)
