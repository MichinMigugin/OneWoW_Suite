local ADDON_NAME, ns = ...

OneWoW_ShoppingList = ns

local L = ns.L

ns.oneWoWHubActive = false

local OneWoW_GUI = OneWoW_GUI

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
    -- Localization lives in the OneWoW Locale service now (scope = ADDON_NAME;
    -- shared vocab in the "shared" scope). SetLanguage refolds every scope in place,
    -- pushes BINDING_* globals, and fires OnApply; OneWoW_ShoppingList.L is a stable
    -- view. esMX->esES is normalized inside. Kept as a thin shim for the profile-sync
    -- loop (t-profiles SyncSettingToChildAddons) until Phase 6.
    local lang = OneWoW_GUI:GetSetting("language") or "enUS"
    OneWoW.Locale:SetLanguage(lang)
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

-- Core-driven login-phase arming. Runs from the module's own PLAYER_LOGIN at
-- startup, or is driven by the loader (OneWoW:EnsureLoaded) for a mid-session
-- enable, when PLAYER_LOGIN has already fired and won't reach this module.
local didLogin = false
function ns:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    DetectOneWoW()

    if OneWoW then
        OneWoW:RegisterMinimap("OneWoW_ShoppingList", L["CTX_OPEN_SL"], nil, function()
            if ns.MainWindow then ns.MainWindow:Toggle() end
        end)
    end
    if ns.FireLoginHandlers then
        ns:FireLoginHandlers()
    end
end

-- Core-driven init: the suite loader calls _G["OneWoW_ShoppingList"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- one-shot guard makes the PLAYER_LOGIN safety net below a no-op when already run.
local didInit = false
function ns:OnAddonLoaded()
    if didInit then return end
    didInit = true
    OneWoW.Lifecycle:CreateHandlerRegistry(ns)
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
        OneWoW.Locale:SetLanguage(langCode)
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
