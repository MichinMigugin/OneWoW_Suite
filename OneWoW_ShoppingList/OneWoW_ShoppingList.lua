local ADDON_NAME, ns = ...

OneWoW_ShoppingList = ns

local L = ns.L

ns.oneWoWHubActive = false

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local function DetectOneWoW()
    if OneWoW then
        ns.oneWoWHubActive = true
    end
end

local function ApplyTheme()
    if OneWoW_GUI then
        OneWoW_GUI:ApplyTheme(ns)
    end
end

local function ApplyLanguage()
    local lang = OneWoW_GUI:GetSetting("language")
    if lang == "esMX" then lang = "esES" end
    ns.SetLocale(lang)
end

ns.ApplyTheme = ApplyTheme
ns.ApplyLanguage = ApplyLanguage

local function InitializeModules()
    if ns.ShoppingList then
        ns.ShoppingList:Initialize()
    end
    if ns.DataAccess then
        ns.DataAccess:Initialize()
    end
    if ns.Alerts then
        ns.Alerts:Initialize()
    end
    if ns.Tooltips then
        ns.Tooltips:Initialize()
    end
    if ns.BagOverlays then
        ns.BagOverlays:Initialize()
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

local function OnPlayerLogin()
    DetectOneWoW()

    if OneWoW then
        OneWoW:RegisterMinimap("OneWoW_ShoppingList", (OneWoW.L and OneWoW.L["CTX_OPEN_SL"]), nil, function()
            if ns.MainWindow then ns.MainWindow:Toggle() end
        end)
    end
end

local function OnAddonLoaded(loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end

    ns:InitializeDatabase()

    local g = OneWoW_ShoppingList_DB.global
    local s = g.settings
    OneWoW_GUI:MigrateSettings({
        theme    = s.theme,
        language = s.language,
        minimap  = g.minimap,
    })

    ApplyTheme()
    ApplyLanguage()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", ns, function()
        ApplyTheme()
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

    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", ns, function()
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

    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", ns, function()
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

    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", ns, function(_, langCode)
        ns.SetLocale(langCode)
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

    local _ver = OneWoW_GUI:GetAddonVersion(ADDON_NAME)
    if OneWoW and OneWoW.RegisterLoadComponent then
        OneWoW:RegisterLoadComponent("ShoppingList", _ver, "/1wsl")
    end
end

local function HandleSlashCommand(msg)
    msg = strlower(strtrim(msg or ""))

    if msg == "help" then
        print(L["ADDON_CHAT_PREFIX"] .. " commands:")
        print("  |cFFFFFFFF/owsl|r - Toggle main window")
        print("  |cFFFFFFFF/owsl show|r - Show main window")
        print("  |cFFFFFFFF/owsl hide|r - Hide main window")
        print("  |cFFFFFFFF/owsl add <itemID>|r - Add item to active list")
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

SLASH_ONEWOW_SHOPPINGLIST1 = "/owsl"
SLASH_ONEWOW_SHOPPINGLIST2 = "/shoppinglist"
SLASH_ONEWOW_SHOPPINGLIST3 = "/1wsl"
SlashCmdList["ONEWOW_SHOPPINGLIST"] = HandleSlashCommand

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    end
end)
