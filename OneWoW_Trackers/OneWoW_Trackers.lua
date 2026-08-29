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
    OneWoW:RegisterSettingsPanel({
        name        = "trackers",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        order       = OneWoW:GetModuleTabOrder("trackers"),
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
end

local function OnInitialize()
    ns:InitializeDatabase()

    OneWoW_GUI:MigrateSettings(ns.db.global)

    OneWoW_Trackers:ApplyTheme()
    ApplyLanguage()

    local function slashHandler(msg) ns:SlashCommandHandler(msg) end
    DB:RegisterSlashCommand("1wt", slashHandler)

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
    OneWoW:RegisterLoadComponent("Trackers", _ver, "/1wt", ADDON_NAME)
end

local function OnEnable()
    RegisterAsOneWoWModule()

    OneWoW:RegisterMinimap("OneWoW_Trackers",
        ns.L["CTX_OPEN_TRACKERS"],
        "trackers",
        nil
    )

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
-- DispatchUnitOnAddonLoaded guarantees at-most-once init per session.
function OneWoW_Trackers:OnAddonLoaded()
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_Trackers)
    OnInitialize()
end

-- Login-phase arming via RunManifestLoginPhase (cold start) or Settle
-- (mid-session enable). didLogin guard: Settle may re-invoke OnPlayerLogin.
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
