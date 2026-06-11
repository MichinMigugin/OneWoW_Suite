local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB
local addon = {}
OneWoW_Catalog = addon

ns.addon = addon
ns.oneWoWHubActive = false

local function RegisterWithOneWoW()
    OneWoW:RegisterModule({
        name        = "catalog",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        addonName   = ADDON_NAME,
        order       = OneWoW:GetModuleTabOrder("catalog"),
        tabs = {
            { name = "journal",     displayName = function() return ns.L["TAB_JOURNAL"]     end, create = function(p) ns.UI.CreateJournalTab(p)    end },
            { name = "vendors",     displayName = function() return ns.L["TAB_VENDORS"]     end, create = function(p) ns.UI.CreateVendorsTab(p)    end },
            { name = "tradeskills", displayName = function() return ns.L["TAB_TRADESKILLS"] end, create = function(p) ns.UI.CreateTradeskillsTab(p) end },
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
    ns.oneWoWHubActive = true
    return true
end

local function OnInitialize()
    ns:InitializeDatabase()
    OneWoW_GUI:MigrateSettings(addon.db.global)

    addon:ApplyTheme()
    if ns.ApplyLanguage then ns.ApplyLanguage() end
    addon.Catalog = ns.Catalog
    addon.UI = ns.UI

    DB:RegisterSlashCommand("owcat", function(msg) addon:SlashCommandHandler(msg) end)
    DB:RegisterSlashCommand("onewowcatalog", function(msg) addon:SlashCommandHandler(msg) end)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", addon, function(myself)
        myself:ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", addon, function()
        if ns.ApplyLanguage then ns.ApplyLanguage() end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", addon, function()
        local mainFrame = OneWoW_CatalogMainFrame
        if mainFrame then
            OneWoW_GUI:ApplyFontToFrame(mainFrame)
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", addon, function()
        local mainFrame = OneWoW_CatalogMainFrame
        if mainFrame then
            OneWoW_GUI:ApplyFontToFrame(mainFrame)
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnMoneyDisplayChanged", addon, function()
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
        (OneWoW.L and OneWoW.L["CTX_OPEN_CATALOG"]) or "Open Catalog",
        "catalog", nil)
end

function addon:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function addon:ApplyLanguage()
    if ns.ApplyLanguage then ns.ApplyLanguage() end
end

function addon:SlashCommandHandler()
    if ns.oneWoWHubActive then
        OneWoW.UI:Show("catalog")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

-- Core-driven init: the suite loader calls _G["OneWoW_Catalog"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- one-shot guard makes the PLAYER_LOGIN safety net below a no-op when already run.
local didInit = false
function addon:OnAddonLoaded()
    if didInit then return end
    didInit = true
    OneWoW.Lifecycle:CreateHandlerRegistry(addon)
    OnInitialize()
end

-- Core-driven login-phase arming. Runs from the module's own PLAYER_LOGIN at
-- startup, or is driven by the loader (OneWoW:EnsureLoaded) for a mid-session
-- enable, when PLAYER_LOGIN has already fired and won't reach this module.
local didLogin = false
function addon:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    OnEnable()
    if addon.FireLoginHandlers then
        addon:FireLoginHandlers()
    end
end
