local addonName, ns = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB

OneWoW_AltTracker = {}
local OneWoWAltTracker = OneWoW_AltTracker

OneWoW_AltTracker.SeasonData = ns.SeasonData

ns.OneWoWAltTracker = OneWoWAltTracker
ns.oneWoWHubActive = false

local function RegisterWithOneWoW()
    if not OneWoW then return false end
    if not OneWoW.RegisterModule then return false end

    OneWoW:RegisterModule({
        name = "alttracker",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        addonName = "OneWoW_AltTracker",
        order = OneWoW:GetModuleTabOrder("alttracker"),
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
        name        = "alttracker",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        order       = OneWoW:GetModuleTabOrder("alttracker"),
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
    ns.oneWoWHubActive = true
    return true
end

local function OnInitialize()
    OneWoWAltTracker:InitializeDatabase()
    OneWoW_GUI:MigrateSettings(OneWoWAltTracker.db.global)
    OneWoWAltTracker:ApplyTheme()

    if ns.ApplyLanguage then
        ns.ApplyLanguage()
    end

    local function slashHandler(msg) OneWoWAltTracker:SlashCommandHandler(msg) end
    DB:RegisterSlashCommand("onewowat", slashHandler)
    DB:RegisterSlashCommand("owat", slashHandler)
    DB:RegisterSlashCommand("1wat", slashHandler)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoWAltTracker, function(self2)
        self2:ApplyTheme()
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

    local _ver = OneWoW:GetAddonVersion(addonName)
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
    if ns.Core and ns.Core.Initialize then
        ns.Core:Initialize()
    end

    RegisterWithOneWoW()

    if OneWoW then
        OneWoW:RegisterMinimap("OneWoW_AltTracker", (OneWoW.L and OneWoW.L["CTX_OPEN_ALTTRACKER"]) or "Open AltTracker", "alttracker", nil)
    end
end

function OneWoWAltTracker:SlashCommandHandler()
    if ns.oneWoWHubActive and OneWoW and OneWoW.UI then
        OneWoW.UI:Show("alttracker")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

function OneWoWAltTracker:InitializeDatabase()
    local defaults = ns.DatabaseDefaults or {}

    self.db = DB:NewCompat("OneWoW_AltTracker_DB", defaults, true)

    if not self.db.global.altTracker then
        self.db.global.altTracker = {
            characters = {},
            lastUpdate = time(),
            expansionVersion = 11
        }
    end

    if not self.db.global.warbandBankData then
        self.db.global.warbandBankData = {}
    end

    if not self.db.global.guildBanks then
        self.db.global.guildBanks = {}
    end

    if not self.db.global.actionBars then
        self.db.global.actionBars = {}
    end

    if not self.db.global.altTrackerSettings then
        self.db.global.altTrackerSettings = {
            enablePlaytimeTracking = true,
            enableDataCollection = true,
        }
    end

    if self.db.global.migrationStatus == nil then
        self.db.global.migrationStatus = {
            cleanupPerformed = false,
        }
    end

    if not self.db.global.overrides then
        self.db.global.overrides = { progress = { trackedCurrencyIDs = {3383, 3341, 3343, 3345, 3347, 3303, 3309, 3378, 3379, 3385, 3316, 3310, 3405}, worldBossQuestID = 0 } }
    end
    if not self.db.global.overrides.progress then
        self.db.global.overrides.progress = { trackedCurrencyIDs = {3383, 3341, 3343, 3345, 3347, 3303, 3309, 3378, 3379, 3385, 3316, 3310, 3405}, worldBossQuestID = 0 }
    end
    if not self.db.global.overrides.progress.trackedCurrencyIDs then
        self.db.global.overrides.progress.trackedCurrencyIDs = {3383, 3341, 3343, 3345, 3347, 3303, 3309, 3378, 3379, 3385, 3316, 3310, 3405}
        self.db.global.overrides.progress.currency1ID = nil
        self.db.global.overrides.progress.currency2ID = nil
    end
    do
        local ids = self.db.global.overrides.progress.trackedCurrencyIDs
        local required = {3310, 3405}
        for _, reqID in ipairs(required) do
            local found = false
            for _, id in ipairs(ids) do
                if id == reqID then found = true; break end
            end
            if not found then table.insert(ids, reqID) end
        end
    end
    if not self.db.global.overrides.progress.worldBossQuestIDs or #self.db.global.overrides.progress.worldBossQuestIDs == 0 then
        self.db.global.overrides.progress.worldBossQuestIDs = {92123, 92560, 92636, 92034}
        self.db.global.overrides.progress.worldBossQuestID = nil
    end
    if not self.db.global.overrides.progress.weeklyActivityQuests then
        self.db.global.overrides.progress.weeklyActivityQuests = {
            {questID = 95842, key = "voidAssaults", name = "Void Assaults"},
            {questID = 95843, key = "ritualSites",  name = "Ritual Sites"},
        }
    end
    self.db.global.overrides.progress.primaryRaidName = nil
    self.db.global.overrides.progress.worldBossName = nil
    if not self.db.global.favorites then
        self.db.global.favorites = {}
    end
    if not self.db.global.seasonChecklist then
        self.db.global.seasonChecklist = {}
    end
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
