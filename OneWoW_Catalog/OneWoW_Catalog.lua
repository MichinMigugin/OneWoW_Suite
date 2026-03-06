-- OneWoW Addon File
-- OneWoW_Catalog/OneWoW_Catalog.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

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
    if ns.ApplyTheme then ns.ApplyTheme() end
    if ns.ApplyLanguage then ns.ApplyLanguage() end
    addon.Catalog = ns.Catalog
    addon.UI = ns.UI
    self:RegisterChatCommand("owcat", "SlashCommandHandler")
    self:RegisterChatCommand("onewowcatalog", "SlashCommandHandler")
    local _ver = C_AddOns.GetAddOnMetadata(addonName, "Version") or ns.Constants.VERSION
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("Catalog", _ver, "/owcat")
    else
        print("|cFF00FF00OneWoW|r: |cFFFFFFFFCatalog|r v." .. _ver .. " |cFF00FF00Loaded|r - /owcat")
    end
end

function addon:OnEnable()
    if ns.Core and ns.Core.Initialize then
        ns.Core:Initialize()
    end

    RegisterWithOneWoW()

    if not ns.oneWoWHubActive then
        if ns.MinimapButton and ns.MinimapButton.Initialize then
            ns.MinimapButton:Initialize()
        end
    end
end

function addon:ApplyTheme()
    if ns.ApplyTheme then ns.ApplyTheme() end
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
    if not self.db.global.language then
        self.db.global.language = GetLocale()
    end
    if not self.db.global.theme then
        self.db.global.theme = "green"
    end
    if not self.db.global.minimap then self.db.global.minimap = {} end
    if self.db.global.minimap.hide == nil then self.db.global.minimap.hide = false end
    if self.db.global.minimap.minimapPos == nil then self.db.global.minimap.minimapPos = 220 end
    if not self.db.global.minimap.theme then self.db.global.minimap.theme = "horde" end
end
