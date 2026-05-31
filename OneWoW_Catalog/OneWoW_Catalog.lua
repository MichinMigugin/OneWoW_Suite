local ADDON_NAME, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB
local addon = {}
OneWoW_Catalog = addon

ns.addon = addon
ns.oneWoWHubActive = false

local function RegisterWithOneWoW()
    OneWoW:RegisterModule({
        name        = "catalog",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "Catalog" end,
        addonName   = ADDON_NAME,
        order       = 4,
        tabs = {
            { name = "journal",     displayName = function() return ns.L["TAB_JOURNAL"]     or "Journal"     end, create = function(p) ns.UI.CreateJournalTab(p)    end },
            { name = "vendors",     displayName = function() return ns.L["TAB_VENDORS"]     or "Vendors"     end, create = function(p) ns.UI.CreateVendorsTab(p)    end },
            { name = "tradeskills", displayName = function() return ns.L["TAB_TRADESKILLS"] or "Tradeskills" end, create = function(p) ns.UI.CreateTradeskillsTab(p) end },
            { name = "quests",      displayName = function() return ns.L["TAB_QUESTS"]      or "Quests"      end, create = function(p) ns.UI.CreateQuestsTab(p)     end },
            { name = "itemsearch",  displayName = function() return ns.L["TAB_ITEMSEARCH"]  or "Item Search" end, create = function(p) ns.UI.CreateItemSearchTab(p) end },
        },
    })
    OneWoW:RegisterSettingsPanel({
        name        = "catalog",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "Catalog" end,
        order       = 3,
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

    local _ver = OneWoW_GUI:GetAddonVersion(ADDON_NAME)
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
        OneWoW.GUI:Show("catalog")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == ADDON_NAME then
            OnInitialize()
        end
    elseif event == "PLAYER_LOGIN" then
        OnEnable()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
