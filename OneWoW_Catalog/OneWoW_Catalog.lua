-- OneWoW Addon File
-- OneWoW_Catalog/OneWoW_Catalog.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_Catalog = LibStub("AceAddon-3.0"):NewAddon("OneWoW_Catalog", "AceEvent-3.0", "AceConsole-3.0")
local addon = OneWoW_Catalog

ns.addon = addon
ns.oneWoWHubActive = false

local function RegisterWithOneWoW()
    if not _G.OneWoW then return false end
    if not _G.OneWoW.RegisterModule then return false end

    _G.OneWoW:RegisterModule({
        name        = "catalog",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "Catalog" end,
        addonName   = "OneWoW_Catalog",
        order       = 4,
        tabs = {
            { name = "journal",     displayName = function() return ns.L["TAB_JOURNAL"]     or "Journal"     end, create = function(p) ns.UI.CreateJournalTab(p)    end },
            { name = "vendors",     displayName = function() return ns.L["TAB_VENDORS"]     or "Vendors"     end, create = function(p) ns.UI.CreateVendorsTab(p)    end },
            { name = "tradeskills", displayName = function() return ns.L["TAB_TRADESKILLS"] or "Tradeskills" end, create = function(p) ns.UI.CreateTradeskillsTab(p) end },
            { name = "quests",      displayName = function() return ns.L["TAB_QUESTS"]      or "Quests"      end, create = function(p) ns.UI.CreateQuestsTab(p)     end },
            { name = "itemsearch",  displayName = function() return ns.L["TAB_ITEMSEARCH"]  or "Item Search" end, create = function(p) ns.UI.CreateItemSearchTab(p) end },
        },
    })
    _G.OneWoW:RegisterSettingsPanel({
        name        = "catalog",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "Catalog" end,
        order       = 3,
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
    ns.oneWoWHubActive = true
    return true
end

function addon:OnInitialize()
    self:InitializeDatabase()

    OneWoW_GUI:MigrateSettings(self.db.global)

    self:ApplyTheme()
    if ns.ApplyLanguage then ns.ApplyLanguage() end
    addon.Catalog = ns.Catalog
    addon.UI = ns.UI
    self:RegisterChatCommand("owcat", "SlashCommandHandler")
    self:RegisterChatCommand("onewowcatalog", "SlashCommandHandler")

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(self2)
        self2:ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", self, function(self2)
        if ns.ApplyLanguage then ns.ApplyLanguage() end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function(self2)
        local mainFrame = _G["OneWoW_CatalogMainFrame"]
        if mainFrame and ns.UI and ns.UI.ApplyFontToFrame then
            ns.UI.ApplyFontToFrame(mainFrame)
        end
    end)

    local _ver = OneWoW_GUI:GetAddonVersion(addonName)
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("Catalog", _ver, "/owcat")
    end
end

function addon:OnEnable()
    if ns.Core and ns.Core.Initialize then
        ns.Core:Initialize()
    end

    RegisterWithOneWoW()

end

function addon:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function addon:ApplyLanguage()
    if ns.ApplyLanguage then ns.ApplyLanguage() end
end

function addon:SlashCommandHandler(input)
    if ns.oneWoWHubActive and _G.OneWoW and _G.OneWoW.GUI then
        _G.OneWoW.GUI:Show("catalog")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

function addon:InitializeDatabase()
    local defaults = ns.DatabaseDefaults or {}
    self.db = LibStub("AceDB-3.0"):New("OneWoW_Catalog_DB", defaults, true)
end
