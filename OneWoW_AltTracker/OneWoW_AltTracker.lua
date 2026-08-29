local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

OneWoW_AltTracker = {}
local OneWoW_AltTracker = OneWoW_AltTracker

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
    return true
end

local function OnInitialize()
    ns:InitializeDatabase()
    OneWoW_GUI:MigrateSettings(ns.db.global)
    OneWoW_AltTracker:ApplyTheme()

    if ns.ApplyLanguage then
        ns.ApplyLanguage()
    end

    local function slashHandler() OneWoW_AltTracker:SlashCommandHandler() end
    DB:RegisterSlashCommand("1wat", slashHandler)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoW_AltTracker, function(self)
        self:ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoW_AltTracker, function()
        if ns.ApplyLanguage then ns.ApplyLanguage() end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", OneWoW_AltTracker, function()
        local mainFrame = OneWoWMainWindow
        if mainFrame then
            OneWoW_GUI:ApplyFontToFrame(mainFrame)
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", OneWoW_AltTracker, function()
        local mainFrame = OneWoWMainWindow
        if mainFrame then
            OneWoW_GUI:ApplyFontToFrame(mainFrame)
        end
        if ns.UI.ResizeOverviewPanels then
            ns.UI.ResizeOverviewPanels()
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnMoneyDisplayChanged", OneWoW_AltTracker, function()
        if ns.UI.RefreshMoneyDisplayTabs then
            ns.UI.RefreshMoneyDisplayTabs()
        end
    end)

    local _ver = OneWoW:GetAddonVersion(ADDON_NAME)
    OneWoW:RegisterLoadComponent("AltTracker", _ver, "/1wat", ADDON_NAME)
end

function OneWoW_AltTracker:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function OneWoW_AltTracker:ApplyLanguage()
    if ns.ApplyLanguage then
        ns.ApplyLanguage()
    end
end

local function OnEnable()
    ns.Core:Initialize()
    RegisterWithOneWoW()
    OneWoW:RegisterMinimap("OneWoW_AltTracker", ns.L["CTX_OPEN_ALTTRACKER"], "alttracker", nil)
end

function OneWoW_AltTracker:SlashCommandHandler()
    OneWoW.UI:Show("alttracker")
end

-- Core-driven init: the suite loader calls _G["OneWoW_AltTracker"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- DispatchUnitOnAddonLoaded guarantees at-most-once init per session.
function OneWoW_AltTracker:OnAddonLoaded()
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_AltTracker)
    OnInitialize()
end

-- Login-phase arming via RunManifestLoginPhase (cold start) or Settle
-- (mid-session enable). didLogin guard: Settle may re-invoke OnPlayerLogin.
local didLogin = false
function OneWoW_AltTracker:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    OnEnable()
    OneWoW_AltTracker:RegisterLoginHandler("actionbars", ns.SetupActionBarsCompat)
    OneWoW_AltTracker:RegisterLoginHandler("financials", function()
        if ns.UI and ns.UI.SetLoginServerTime then
            ns.UI.SetLoginServerTime()
        end
    end)
    if OneWoW_AltTracker.FireLoginHandlers then
        OneWoW_AltTracker:FireLoginHandlers()
    end
end
