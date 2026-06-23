local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

OneWoW_Catalog = {}
local OneWoW_Catalog = OneWoW_Catalog

local function RegisterWithOneWoW()
    OneWoW:RegisterModule({
        name        = "catalog",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        addonName   = ADDON_NAME,
        order       = OneWoW:GetModuleTabOrder("catalog"),
        tabs = {
            { name = "journal",     displayName = function() return ns.L["TAB_JOURNAL"]     end, create = function(p) ns.UI.CreateJournalTab(p)    end },
            { name = "vendors",     displayName = function() return ns.L["TAB_VENDORS"]     end, create = function(p) ns.UI.CreateVendorsTab(p)    end },
            { name = "tradeskills", displayName = function() return TRADESKILLS end, create = function(p) ns.UI.CreateTradeskillsTab(p) end },
            { name = "quests",      displayName = function() return ns.L["TAB_QUESTS"]      end, create = function(p) ns.UI.CreateQuestsTab(p)     end },
            { name = "itemsearch",  displayName = function() return ns.L["TAB_ITEMSEARCH"]  end, create = function(p) ns.UI.CreateItemSearchTab(p) end },
        },
    })
    OneWoW:RegisterSettingsPanel({
        name        = "catalog",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        order       = OneWoW:GetModuleTabOrder("catalog"),
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
    return true
end

local function OnInitialize()
    ns:InitializeDatabase()
    OneWoW_GUI:MigrateSettings(ns.db.global)
    OneWoW_Catalog:ApplyTheme()
    if ns.ApplyLanguage then ns.ApplyLanguage() end

    DB:RegisterSlashCommand("owcat", function(msg) OneWoW_Catalog:SlashCommandHandler(msg) end)
    DB:RegisterSlashCommand("onewowcatalog", function(msg) OneWoW_Catalog:SlashCommandHandler(msg) end)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoW_Catalog, function(self)
        self:ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoW_Catalog, function()
        if ns.ApplyLanguage then ns.ApplyLanguage() end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", OneWoW_Catalog, function()
        local mainFrame = OneWoWMainWindow
        if mainFrame then
            OneWoW_GUI:ApplyFontToFrame(mainFrame)
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", OneWoW_Catalog, function()
        local mainFrame = OneWoWMainWindow
        if mainFrame then
            OneWoW_GUI:ApplyFontToFrame(mainFrame)
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnMoneyDisplayChanged", OneWoW_Catalog, function()
        if ns.UI.RefreshItemSearchList then ns.UI.RefreshItemSearchList() end
        if ns.UI.RefreshVendorsList then ns.UI.RefreshVendorsList() end
        if ns.UI.RefreshQuestsList then ns.UI.RefreshQuestsList() end
    end)

    local _ver = OneWoW:GetAddonVersion(ADDON_NAME)
    OneWoW:RegisterLoadComponent("Catalog", _ver, "/owcat")
end

local function OnEnable()
    RegisterWithOneWoW()

    OneWoW:RegisterMinimap("OneWoW_Catalog",
        ns.L["CTX_OPEN_CATALOG"],
        "catalog", nil)
end

function OneWoW_Catalog:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function OneWoW_Catalog:ApplyLanguage()
    if ns.ApplyLanguage then ns.ApplyLanguage() end
end

function OneWoW_Catalog:SlashCommandHandler()
    OneWoW.UI:Show("catalog")
end

-- Core-driven init: the suite loader calls _G["OneWoW_Catalog"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- one-shot guard makes the PLAYER_LOGIN safety net below a no-op when already run.
local didInit = false
function OneWoW_Catalog:OnAddonLoaded()
    if didInit then return end
    didInit = true
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_Catalog)
    OnInitialize()
end

-- Core-driven login-phase arming. Runs from the module's own PLAYER_LOGIN at
-- startup, or is driven by the loader (OneWoW:EnsureLoaded) for a mid-session
-- enable, when PLAYER_LOGIN has already fired and won't reach this module.
local didLogin = false
function OneWoW_Catalog:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    OnEnable()
    if OneWoW_Catalog.FireLoginHandlers then
        OneWoW_Catalog:FireLoginHandlers()
    end
end
