local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

OneWoW_ShoppingList = {}
local OneWoW_ShoppingList = OneWoW_ShoppingList

local L = ns.L

local function InitializeModules()
    if ns.ShoppingList then
        ns.ShoppingList:Initialize()
    end
    if ns.DataAccess then
        ns.DataAccess:Initialize()
    end
    if ns.FarmList then
        ns.FarmList:Initialize()
    end
    if ns.Alerts then
        ns.Alerts:Initialize()
    end
    if ns.Tooltips then
        ns.Tooltips:Initialize()
    end
    if ns.BagButton then
        ns.BagButton:Initialize()
    end
    if ns.ProfessionUI then
        ns.ProfessionUI:Initialize()
    end
    if ns.OrdersUI then
        ns.OrdersUI:Initialize()
    end
    if ns.CatalogIntegration then
        ns.CatalogIntegration:Initialize()
    end
end

function OneWoW_ShoppingList:ApplyTheme()
    OneWoW_GUI:ApplyTheme(ns)
end

function OneWoW_ShoppingList:ApplyLanguage()
    ns.ApplyLanguage()
end

-- Login-phase arming via RunManifestLoginPhase (cold start) or Settle
-- (mid-session enable). didLogin guard: Settle may re-invoke OnPlayerLogin.
local didLogin = false
function OneWoW_ShoppingList:OnPlayerLogin()
    if didLogin then return end
    didLogin = true

    OneWoW:RegisterMinimap("OneWoW_ShoppingList", L["CTX_OPEN_SL"], nil, function()
        if ns.MainWindow then ns.MainWindow:Toggle() end
    end)
    if OneWoW_ShoppingList.FireLoginHandlers then
        OneWoW_ShoppingList:FireLoginHandlers()
    end
    OneWoW:SignalDataReady(ADDON_NAME)
end

-- Core-driven init: the suite loader calls _G["OneWoW_ShoppingList"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- DispatchUnitOnAddonLoaded guarantees at-most-once init per session.
function OneWoW_ShoppingList:OnAddonLoaded()
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_ShoppingList)
    ns:InitializeDatabase()

    local g = ns.db.global
    local s = g.settings
    OneWoW_GUI:MigrateSettings({
        theme    = s.theme,
        language = s.language,
        minimap  = g.minimap,
    })

    OneWoW_ShoppingList:ApplyTheme()
    ns.ApplyLanguage()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoW_ShoppingList, function(myself)
        myself:ApplyTheme()
        if ns.MainWindow and ns.MainWindow.Rebuild then
            local wasShown = ns.MainWindow:IsShown()
            ns.MainWindow:Rebuild()
            if wasShown then
                C_Timer.After(0.1, function()
                    if ns.MainWindow and ns.MainWindow.Show then ns.MainWindow:Show() end
                end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", OneWoW_ShoppingList, function()
        if ns.MainWindow then
            local wasShown = ns.MainWindow:IsShown()
            ns.MainWindow:Rebuild()
            if wasShown then
                C_Timer.After(0.1, function()
                    if ns.MainWindow then ns.MainWindow:Show() end
                end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", OneWoW_ShoppingList, function()
        if ns.MainWindow then
            local wasShown = ns.MainWindow:IsShown()
            ns.MainWindow:Rebuild()
            if wasShown then
                C_Timer.After(0.1, function()
                    if ns.MainWindow then ns.MainWindow:Show() end
                end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoW_ShoppingList, function()
        ns.ApplyLanguage()
        ns.ProfessionUI:ApplyLanguage()
        ns.OrdersUI:ApplyLanguage()
        ns.CatalogIntegration:ApplyLanguage()
        if ns.MainWindow then
            local wasShown = ns.MainWindow:IsShown()
            ns.MainWindow:Rebuild()
            if wasShown then
                C_Timer.After(0.1, function()
                    if ns.MainWindow then ns.MainWindow:Show() end
                end)
            end
        end
    end)

    InitializeModules()

    local _ver = OneWoW:GetAddonVersion(ADDON_NAME)
    OneWoW:RegisterLoadComponent("ShoppingList", _ver, "/1wsl", ADDON_NAME)
    OneWoW:SignalDataReady(ADDON_NAME)
end

local function HandleSlashCommand(msg)
    msg = strlower(strtrim(msg or ""))

    if msg == "help" then
        print(L["ADDON_CHAT_PREFIX"] .. " commands:")
        print("  |cFFFFFFFF/1wsl|r - Toggle main window")
        print("  |cFFFFFFFF/1wsl show|r - Show main window")
        print("  |cFFFFFFFF/1wsl hide|r - Hide main window")
        print("  |cFFFFFFFF/1wsl add <itemID>|r - Add item to active list")
        print("  |cFFFFFFFF/1wsl farm|r - Show Farming tab")
        return
    end

    if msg == "farm" or msg == "farming" then
        OneWoW_ShoppingList_API.ShowFarming()
        return
    end

    if msg == "show" then
        if ns.MainWindow then ns.MainWindow:Show() end
        return
    end

    if msg == "hide" then
        if ns.MainWindow then ns.MainWindow:Hide() end
        return
    end

    local addID = msg:match("^add%s+(%d+)$")
    if addID then
        local itemID = tonumber(addID)
        if itemID and itemID > 0 then
            local activeList = ns.ShoppingList and ns.ShoppingList:GetActiveListName()
            if activeList then
                local ok = ns.ShoppingList:AddItemToList(activeList, itemID, 1)
                if ok then
                    local name = C_Item.GetItemNameByID(itemID) or tostring(itemID)
                    print(string.format(L["ADDON_CHAT_PREFIX"] .. " Added %s to %s.", name, activeList))
                end
            end
        end
        return
    end

    if ns.MainWindow then ns.MainWindow:Toggle() end
end

SLASH_ONEWOW_SHOPPINGLIST1 = "/1wsl"
SlashCmdList["ONEWOW_SHOPPINGLIST"] = HandleSlashCommand
