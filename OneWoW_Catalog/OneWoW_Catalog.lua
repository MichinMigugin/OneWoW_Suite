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
local L = ns.L

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
    OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", self, function(owner, hidden)
        if owner.Minimap then owner.Minimap:SetShown(not hidden) end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function(owner)
        if owner.Minimap then owner.Minimap:UpdateIcon() end
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

    if not ns.oneWoWHubActive then
        self.Minimap = OneWoW_GUI:CreateMinimapLauncher("OneWoW_Catalog", {
            label = "Catalog",
            onClick = function()
                if ns.UI and ns.UI.Toggle then ns.UI:Toggle() end
            end,
            onRightClick = function()
                if ns.UI and ns.UI.Show then ns.UI:Show("settings") end
            end,
            onTooltip = function(frame)
                GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
                GameTooltip:AddLine(L["MINIMAP_TOOLTIP_TITLE"], 1, 0.82, 0, 1)
                GameTooltip:AddLine(L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
                GameTooltip:Show()
            end,
        })
    end

    if _G.OneWoW then
        _G.OneWoW:RegisterMinimap("OneWoW_Catalog",
            (_G.OneWoW.L and _G.OneWoW.L["CTX_OPEN_CATALOG"]) or "Open Catalog",
            "catalog", nil)
    end
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
