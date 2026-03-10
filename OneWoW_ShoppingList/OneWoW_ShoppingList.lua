local ADDON_NAME, ns = ...

_G.OneWoW_ShoppingList = ns

local L = ns.L

ns.oneWoWHubActive = false

local function DetectOneWoW()
    if _G.OneWoW then
        ns.oneWoWHubActive = true
    end
end

local function ApplyTheme()
    local themeKey
    local hub = _G.OneWoW
    if hub and hub.db and hub.db.global then
        themeKey = hub.db.global.theme or "green"
    else
        local db = _G.OneWoW_ShoppingList_DB
        themeKey = (db and db.global and db.global.settings and db.global.settings.theme) or "green"
    end
    local Constants = ns.Constants

    if Constants and Constants.THEMES and Constants.THEMES[themeKey] then
        local selected = Constants.THEMES[themeKey]
        for key, value in pairs(selected) do
            if key ~= "name" then
                Constants.THEME[key] = value
            end
        end
    end
end

local function ApplyLanguage()
    local lang
    local hub = _G.OneWoW
    if hub and hub.db and hub.db.global then
        lang = hub.db.global.language or GetLocale()
    else
        local db = _G.OneWoW_ShoppingList_DB
        lang = (db and db.global and db.global.settings and db.global.settings.language) or GetLocale()
    end
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
    if ns.CatalogIntegration then
        ns.CatalogIntegration:Initialize()
    end
end

local function OnPlayerLogin()
    DetectOneWoW()

    if not ns.oneWoWHubActive then
        if ns.Minimap then
            ns.Minimap:Initialize()
        end
        if ns._pendingLoadVer then
            print("|cFF00FF00OneWoW|r: |cFFFFFFFFShopping List|r |cFF888888\226\128\147 v." .. ns._pendingLoadVer .. " \226\128\147|r |cFF00FF00Loaded|r - /1wsl")
        end
    end
end

local function OnAddonLoaded(loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end

    if not _G.OneWoW_ShoppingList_DB then
        _G.OneWoW_ShoppingList_DB = {}
    end

    _G.OneWoW_ShoppingList_DB = ns.Database:Initialize(_G.OneWoW_ShoppingList_DB)

    ApplyTheme()
    ApplyLanguage()
    InitializeModules()

    local _ver = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or ns.Constants.VERSION
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("ShoppingList", _ver, "/1wsl")
    else
        ns._pendingLoadVer = _ver
    end
end

local function HandleSlashCommand(msg)
    msg = strlower(strtrim(msg or ""))

    if msg == "help" then
        print("|cFFFFD100OneWoW Shopping List|r commands:")
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
                    print(string.format("|cFFFFD100OneWoW Shopping List:|r Added %s to %s.", name, activeList))
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

_G["1WoW_ShoppingList_OnAddonCompartmentClick"] = function(addonName, buttonName)
    if ns.MainWindow then
        ns.MainWindow:Toggle()
    end
end

_G["1WoW_ShoppingList_OnAddonCompartmentEnter"] = function(addonName, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("|cFFFFD100OneWoW|r " .. L["OWSL_WINDOW_TITLE"], 1, 1, 1)
    GameTooltip:AddLine(L["OWSL_MM_CLICK_TO_OPEN"], 0.7, 0.7, 0.7)

    local db = _G.OneWoW_ShoppingList_DB
    if db and db.global and db.global.shoppingLists then
        local lists = db.global.shoppingLists.lists
        if lists then
            local listCount  = 0
            local itemCount  = 0
            for _, listData in pairs(lists) do
                if not listData.parentList then
                    listCount = listCount + 1
                end
                if listData.items then
                    for _ in pairs(listData.items) do
                        itemCount = itemCount + 1
                    end
                end
            end
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine(string.format(L["OWSL_MM_LIST_COUNT"], listCount), 1, 0.82, 0)
            GameTooltip:AddLine(string.format(L["OWSL_MM_ITEM_COUNT"], itemCount), 0.7, 0.7, 0.7)
        end
    end

    GameTooltip:Show()
end

_G["1WoW_ShoppingList_OnAddonCompartmentLeave"] = function(addonName, button)
    GameTooltip:Hide()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    end
end)
