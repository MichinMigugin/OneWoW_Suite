local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

OneWoW_AltTracker = {}
local OneWoWAltTracker = OneWoW_AltTracker

ns.OneWoWAltTracker = OneWoWAltTracker
ns.oneWoWHubActive = false

-- Public cross-addon accessor. AltTracker data units (RequiredDeps:
-- OneWoW_AltTracker) read the effective progress override lists through this,
-- so the static baseline lives only in ns.OverrideDefaults (single source).
---@param key string one of "trackedCurrencyIDs", "worldBossQuestIDs", "weeklyActivityQuests"
---@return table|nil list effective override list (user customization, else baseline)
function OneWoWAltTracker:GetProgressList(key)
    return ns:GetProgressList(key)
end

--- Shared season definition (raids, dungeons, difficulties + raid-cache helpers)
--- populated in Data/d-season.lua. AltTracker data units read it through this
--- accessor so the table stays private to the hub namespace.
---@return table seasonData the ns.SeasonData module
function OneWoWAltTracker:GetSeasonData()
    return ns.SeasonData
end

local function RegisterWithOneWoW()
    local moduleName = "alttracker"

    OneWoW:RegisterModule({
        name = "alttracker",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        addonName = ADDON_NAME,
        order = OneWoW:GetModuleTabOrder(moduleName),
        tabs = {
            { name = "summary",     displayName = function() return ns.L["SUMMARY"]     end, create = function(p) ns.UI.CreateSummaryTab(p) end },
            { name = "progress",    displayName = function() return ns.L["PROGRESS"]    end, create = function(p) ns.UI.CreateProgressTab(p) end },
            { name = "bank",        displayName = function() return BANK        end, create = function(p) ns.UI.CreateBankTab(p) end },
            { name = "equipment",   displayName = function() return ns.L["SUBTAB_EQUIPMENT"]   end, create = function(p) ns.UI.CreateEquipmentTab(p) end },
            { name = "professions", displayName = function() return ns.L["SUBTAB_PROFESSIONS"] end, create = function(p) ns.UI.CreateProfessionsTab(p) end },
            { name = "auctions",    displayName = function() return AUCTIONS    end, create = function(p) ns.UI.CreateAuctionsTab(p) end },
            { name = "financials",  displayName = function() return ns.L["SUBTAB_FINANCIALS"]  end, create = function(p) ns.UI.CreateFinancialsTab(p) end },
            { name = "items",       displayName = function() return ITEMS       end, create = function(p) ns.UI.CreateItemsTab(p) end },
            { name = "actionbars",  displayName = function() return ns.L["SUBTAB_ACTIONBARS"]  end, create = function(p) ns.UI.CreateActionBarsTab(p) end },
            { name = "lockouts",    displayName = function() return ns.L["LOCKOUTS"]    end, create = function(p) ns.UI.CreateLockoutsTab(p) end },
        },
    })
    OneWoW:RegisterSettingsPanel({
        name        = moduleName,
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        order       = OneWoW:GetModuleTabOrder(moduleName),
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
    ns.oneWoWHubActive = true
    return true
end

local function OnInitialize()
    ns:InitializeDatabase()
    OneWoW_GUI:MigrateSettings(OneWoWAltTracker.db.global)
    OneWoWAltTracker:ApplyTheme()

    if ns.ApplyLanguage then
        ns.ApplyLanguage()
    end

    local function slashHandler(msg) OneWoWAltTracker:SlashCommandHandler(msg) end
    DB:RegisterSlashCommand("onewowat", slashHandler)
    DB:RegisterSlashCommand("owat", slashHandler)
    DB:RegisterSlashCommand("1wat", slashHandler)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoWAltTracker, function(self)
        self:ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoWAltTracker, function()
        if ns.ApplyLanguage then ns.ApplyLanguage() end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", OneWoWAltTracker, function()
        local mainFrame = _G["OneWoWAltTrackerMainFrame"]
        if mainFrame then
            OneWoW_GUI:ApplyFontToFrame(mainFrame)
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", OneWoWAltTracker, function()
        local mainFrame = _G["OneWoWAltTrackerMainFrame"]
        if mainFrame then
            OneWoW_GUI:ApplyFontToFrame(mainFrame)
        end
        if ns.UI.ResizeOverviewPanels then
            ns.UI.ResizeOverviewPanels()
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnMoneyDisplayChanged", OneWoWAltTracker, function()
        if ns.UI.RefreshMoneyDisplayTabs then
            ns.UI.RefreshMoneyDisplayTabs()
        end
    end)

    local _ver = OneWoW:GetAddonVersion(ADDON_NAME)
    if OneWoW and OneWoW.RegisterLoadComponent then
        OneWoW:RegisterLoadComponent("AltTracker", _ver, "/1wat")
    end
end

function OneWoWAltTracker:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function OneWoWAltTracker:ApplyLanguage()
    if ns.ApplyLanguage then
        ns.ApplyLanguage()
    end
end

local function OnEnable()
    ns.Core:Initialize()
    RegisterWithOneWoW()
    OneWoW:RegisterMinimap("OneWoW_AltTracker", ns.L["CTX_OPEN_ALTTRACKER"], "alttracker", nil)
end

function OneWoWAltTracker:SlashCommandHandler()
    if ns.oneWoWHubActive then
        OneWoW.UI:Show("alttracker")
        return
    end

    ns.UI:Toggle()
end

-- Core-driven init: the suite loader calls _G["OneWoW_AltTracker"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- one-shot guard makes the PLAYER_LOGIN safety net below a no-op when already run.
local didInit = false
function OneWoWAltTracker:OnAddonLoaded()
    if didInit then return end
    didInit = true
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoWAltTracker)
    OnInitialize()
end

-- Core-driven login-phase arming. Runs from the module's own PLAYER_LOGIN at
-- startup, or is driven by the loader (OneWoW:EnsureLoaded) for a mid-session
-- enable, when PLAYER_LOGIN has already fired and won't reach this module.
local didLogin = false
function OneWoWAltTracker:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    OnEnable()
    OneWoWAltTracker:RegisterLoginHandler("actionbars", ns.SetupActionBarsCompat)
    OneWoWAltTracker:RegisterLoginHandler("financials", function()
        if ns.UI and ns.UI.SetLoginServerTime then
            ns.UI.SetLoginServerTime()
        end
    end)
    if OneWoWAltTracker.FireLoginHandlers then
        OneWoWAltTracker:FireLoginHandlers()
    end
end
