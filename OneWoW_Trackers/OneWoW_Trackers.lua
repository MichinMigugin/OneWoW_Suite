local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

-- We use _G[""] form since _G.OneWoW_Trackers would get caught in pre-commit hook.
_G["OneWoW_Trackers"] = ns

ns.oneWoWHubActive = false
ns.mode = "standalone"
ns.UI = ns.UI or {}

local function ApplyTheme()
    OneWoW_GUI:ApplyTheme(ns)
    if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
        ns.TrackerEngine:RefreshAllPinnedWindows()
    end
end

local function ApplyLanguage()
    local selectedLang
    if OneWoW_GUI and OneWoW_GUI.GetSetting then
        selectedLang = OneWoW_GUI:GetSetting("language")
    end
    selectedLang = selectedLang or GetLocale()
    if selectedLang == "esMX" then selectedLang = "esES" end
    ns.SetLocale(selectedLang)
end

local function RegisterAsOneWoWModule()
    if not OneWoW or not OneWoW.RegisterModule then return false end

    OneWoW:RegisterModule({
        name        = "trackers",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "Trackers" end,
        addonName   = "OneWoW_Trackers",
        order       = 2,
        tabs = {
            {
                name        = "tracker",
                displayName = function() return ns.L["TAB_TRACKER"] or "Tracker" end,
                create      = function(p) ns.UI.CreateTrackerTab(p) end,
            },
        },
    })

    ns.oneWoWHubActive = true
    ns.mode = "onewow_module"
    return true
end

local function OnInitialize()
    ns:InitializeDatabase()

    OneWoW_GUI:MigrateSettings(ns.db.global)

    ApplyTheme()
    ApplyLanguage()

    local function slashHandler(msg) ns:SlashCommandHandler(msg) end
    DB:RegisterSlashCommand("1wt",     slashHandler)
    DB:RegisterSlashCommand("owt",     slashHandler)
    DB:RegisterSlashCommand("tracker", slashHandler)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", ns, function()
        ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", ns, function()
        ApplyLanguage()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", ns, function()
        if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
            ns.TrackerEngine:RefreshAllPinnedWindows()
        end
        if ns.UI and ns.UI.RefreshTab then ns.UI.RefreshTab() end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", ns, function()
        if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
            ns.TrackerEngine:RefreshAllPinnedWindows()
        end
        if ns.UI and ns.UI.RefreshTab then ns.UI.RefreshTab() end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnMoneyDisplayChanged", ns, function()
        if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
            ns.TrackerEngine:RefreshAllPinnedWindows()
        end
        if ns.UI and ns.UI.RefreshTab then
            ns.UI.RefreshTab()
        end
    end)

    local _ver = OneWoW_GUI:GetAddonVersion(addonName)
    if OneWoW and OneWoW.RegisterLoadComponent then
        OneWoW:RegisterLoadComponent("Trackers", _ver, "/1wt")
    end
end

local function OnEnable()
    RegisterAsOneWoWModule()

    if OneWoW then
        OneWoW:RegisterMinimap("OneWoW_Trackers",
            (OneWoW.L and OneWoW.L["CTX_OPEN_TRACKERS"]) or "Open Trackers",
            "trackers",
            nil
        )
    end

    if ns.TrackerEngine and ns.TrackerEngine.Initialize then
        ns.TrackerEngine:Initialize()
    end

    if ns.TrackerPresets and ns.TrackerPresets.LoadBundledContent then
        ns.TrackerPresets:LoadBundledContent()
    end

    if ns.TrackerMapUI and ns.TrackerMapUI.Initialize then
        ns.TrackerMapUI:Initialize()
    end
end

function ns:SlashCommandHandler()
    if ns.mode == "notes_subtab" then
        if ns.oneWoWHubActive and OneWoW and OneWoW.GUI then
            OneWoW.GUI:Show("notes", "tracker")
        elseif OneWoW_Notes then
            if OneWoW_Notes.SlashCommandHandler then
                OneWoW_Notes:SlashCommandHandler("")
            end
        end
        return
    end

    if ns.oneWoWHubActive and OneWoW and OneWoW.GUI then
        OneWoW.GUI:Show("trackers")
        return
    end

    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

function ns:FormatResetTimer(seconds)
    if seconds <= 0 then return "<0m>" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if days > 0 then
        if hours > 0 then return string.format("<%dd %dhr>", days, hours)
        else return string.format("<%dd>", days) end
    elseif hours > 0 then
        return string.format("<%dhr>", hours)
    else
        return string.format("<%dm>", minutes)
    end
end

local pewFired = false
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        OnInitialize()
    elseif event == "PLAYER_LOGIN" then
        OnEnable()
    elseif event == "PLAYER_ENTERING_WORLD" and not pewFired then
        pewFired = true
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
