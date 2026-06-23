local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

OneWoW_Trackers = {}
local OneWoW_Trackers = OneWoW_Trackers

ns.UI = ns.UI or {}

local function ApplyLanguage()
    -- Localization lives in the OneWoW Locale service now (scope = ADDON_NAME).
    -- SetLanguage refolds every scope in place, pushes BINDING_* globals, and fires
    -- OnApply; ns.L is a stable view. esMX->esES is normalized inside.
    local lang = OneWoW_GUI:GetSetting("language") or GetLocale()
    OneWoW.Locale:SetLanguage(lang)
end

function OneWoW_Trackers:ApplyTheme()
    OneWoW_GUI:ApplyTheme(ns)
    if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
        ns.TrackerEngine:RefreshAllPinnedWindows()
    end
end

function OneWoW_Trackers:ApplyLanguage()
    ApplyLanguage()
end

local function RegisterAsOneWoWModule()
    if not OneWoW or not OneWoW.RegisterModule then return false end

    OneWoW:RegisterModule({
        name        = "trackers",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        addonName   = ADDON_NAME,
        order       = OneWoW:GetModuleTabOrder("trackers"),
        tabs = {
            {
                name        = "tracker",
                displayName = function() return ns.L["TAB_TRACKER"] end,
                create      = function(p) ns.UI.CreateTrackerTab(p) end,
            },
        },
    })

    return true
end

local function OnInitialize()
    ns:InitializeDatabase()

    OneWoW_GUI:MigrateSettings(ns.db.global)

    OneWoW_Trackers:ApplyTheme()
    ApplyLanguage()

    local function slashHandler(msg) ns:SlashCommandHandler(msg) end
    DB:RegisterSlashCommand("1wt",     slashHandler)
    DB:RegisterSlashCommand("owt",     slashHandler)
    DB:RegisterSlashCommand("tracker", slashHandler)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoW_Trackers, function(myself)
        myself:ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoW_Trackers, function()
        ApplyLanguage()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", OneWoW_Trackers, function()
        if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
            ns.TrackerEngine:RefreshAllPinnedWindows()
        end
        if ns.UI and ns.UI.RefreshTab then ns.UI.RefreshTab() end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", OneWoW_Trackers, function()
        if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
            ns.TrackerEngine:RefreshAllPinnedWindows()
        end
        if ns.UI and ns.UI.RefreshTab then ns.UI.RefreshTab() end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnMoneyDisplayChanged", OneWoW_Trackers, function()
        if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
            ns.TrackerEngine:RefreshAllPinnedWindows()
        end
        if ns.UI and ns.UI.RefreshTab then
            ns.UI.RefreshTab()
        end
    end)

    local _ver = OneWoW:GetAddonVersion(ADDON_NAME)
    if OneWoW and OneWoW.RegisterLoadComponent then
        OneWoW:RegisterLoadComponent("Trackers", _ver, "/1wt")
    end
end

local function OnEnable()
    RegisterAsOneWoWModule()

    if OneWoW then
        OneWoW:RegisterMinimap("OneWoW_Trackers",
            ns.L["CTX_OPEN_TRACKERS"],
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
    OneWoW.UI:Show("trackers")
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

-- Core-driven init: the suite loader calls _G["OneWoW_Trackers"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- one-shot guard makes the PLAYER_LOGIN safety net below a no-op when already run.
local didInit = false
function OneWoW_Trackers:OnAddonLoaded()
    if didInit then return end
    didInit = true
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_Trackers)
    OnInitialize()
end

-- Core-driven login-phase arming. Runs from the module's own PLAYER_LOGIN at
-- startup, or is driven by the loader (OneWoW:EnsureLoaded) for a mid-session
-- enable, when PLAYER_LOGIN has already fired and won't reach this module.
local didLogin = false
function OneWoW_Trackers:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    OnEnable()
    OneWoW_Trackers:RegisterEnteringWorldHandler("tracker_engine", function()
        if ns.TrackerEngine and ns.TrackerEngine.OnPlayerEnteringWorld then
            ns.TrackerEngine:OnPlayerEnteringWorld()
        end
    end)
    if OneWoW_Trackers.FireLoginHandlers then
        OneWoW_Trackers:FireLoginHandlers()
    end
end

function OneWoW_Trackers:OnPlayerEnteringWorld(isLogin, isReload, isZoning)
    if OneWoW_Trackers.FireEnteringWorldHandlers then
        OneWoW_Trackers:FireEnteringWorldHandlers(isLogin, isReload, isZoning)
    end
end
