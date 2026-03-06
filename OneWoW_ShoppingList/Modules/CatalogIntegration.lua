local ADDON_NAME, ns = ...
local L = ns.L

ns.CatalogIntegration = {}
local CatalogIntegration = ns.CatalogIntegration

local openListBtn
local makeListBtn
local addToActiveBtn
local currentRecipe = nil
local currentReagents = nil
local buttonsCreated = false

local function GetDB()
    return _G.OneWoW_ShoppingList_DB
end

local function T(key)
    if ns.Constants and ns.Constants.THEME and ns.Constants.THEME[key] then
        return unpack(ns.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function HideButtons()
    if openListBtn then openListBtn:Hide() end
    if makeListBtn then makeListBtn:Hide() end
    if addToActiveBtn then addToActiveBtn:Hide() end
end

local function ShowButtons()
    if openListBtn then openListBtn:Show() end
    if makeListBtn then makeListBtn:Show() end
    if addToActiveBtn then addToActiveBtn:Show() end
end

local function CreateButtons(statusBar)
    if buttonsCreated then return end
    buttonsCreated = true

    addToActiveBtn = CreateFrame("Button", nil, statusBar, "BackdropTemplate")
    addToActiveBtn:SetSize(100, 21)
    addToActiveBtn:SetPoint("RIGHT", statusBar, "RIGHT", -6, 0)
    addToActiveBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    addToActiveBtn:SetBackdropColor(T("BTN_NORMAL"))
    addToActiveBtn:SetBackdropBorderColor(T("BTN_BORDER"))

    addToActiveBtn.text = addToActiveBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addToActiveBtn.text:SetPoint("CENTER")
    addToActiveBtn.text:SetText(L["OWSL_PROF_BTN_ADD_TO_ACTIVE"])
    addToActiveBtn.text:SetTextColor(T("TEXT_PRIMARY"))

    addToActiveBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BTN_HOVER"))
        self:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["OWSL_TT_ADD_TO_ACTIVE_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_TT_ADD_TO_ACTIVE_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addToActiveBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BTN_NORMAL"))
        self:SetBackdropBorderColor(T("BTN_BORDER"))
        GameTooltip:Hide()
    end)
    addToActiveBtn:SetScript("OnClick", function()
        CatalogIntegration:AddToActiveList()
    end)

    makeListBtn = CreateFrame("Button", nil, statusBar, "BackdropTemplate")
    makeListBtn:SetSize(80, 21)
    makeListBtn:SetPoint("RIGHT", addToActiveBtn, "LEFT", -4, 0)
    makeListBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    makeListBtn:SetBackdropColor(T("BTN_NORMAL"))
    makeListBtn:SetBackdropBorderColor(T("BTN_BORDER"))

    makeListBtn.text = makeListBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    makeListBtn.text:SetPoint("CENTER")
    makeListBtn.text:SetText(L["OWSL_PROF_BTN_MAKE_LIST"])
    makeListBtn.text:SetTextColor(T("TEXT_PRIMARY"))

    makeListBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BTN_HOVER"))
        self:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["OWSL_TT_MAKE_LIST_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_TT_MAKE_LIST_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    makeListBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BTN_NORMAL"))
        self:SetBackdropBorderColor(T("BTN_BORDER"))
        GameTooltip:Hide()
    end)
    makeListBtn:SetScript("OnClick", function()
        CatalogIntegration:MakeNewList()
    end)

    openListBtn = CreateFrame("Button", nil, statusBar, "BackdropTemplate")
    openListBtn:SetSize(21, 21)
    openListBtn:SetPoint("RIGHT", makeListBtn, "LEFT", -4, 0)
    openListBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    openListBtn:SetBackdropColor(T("BTN_NORMAL"))
    openListBtn:SetBackdropBorderColor(T("BTN_BORDER"))

    openListBtn.icon = openListBtn:CreateTexture(nil, "ARTWORK")
    openListBtn.icon:SetSize(14, 14)
    openListBtn.icon:SetPoint("CENTER")
    openListBtn.icon:SetAtlas("Perks-ShoppingCart")

    openListBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BTN_HOVER"))
        self:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["OWSL_WINDOW_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_MM_CLICK_TO_OPEN"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    openListBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BTN_NORMAL"))
        self:SetBackdropBorderColor(T("BTN_BORDER"))
        GameTooltip:Hide()
    end)
    openListBtn:SetScript("OnClick", function()
        if ns.MainWindow then ns.MainWindow:Toggle() end
    end)

    HideButtons()
end

local function GetRecipeName(recipe)
    if not recipe then return nil end
    local name = nil
    if recipe.item and C_Item and C_Item.GetItemNameByID then
        name = C_Item.GetItemNameByID(recipe.item)
    end
    if not name and recipe.id and C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(recipe.id)
    end
    return name or ("Recipe #" .. (recipe.id or 0))
end

local function OnRecipeSelected(recipe, reagents, panels)
    currentRecipe = recipe
    currentReagents = reagents

    if not panels or not panels.rightStatusBar then return end

    CreateButtons(panels.rightStatusBar)

    if recipe and reagents and #reagents > 0 then
        ShowButtons()
    else
        HideButtons()
    end
end

function CatalogIntegration:MakeNewList()
    if not currentRecipe or not currentReagents then return end
    if not ns.ShoppingList then return end

    local recipeName = GetRecipeName(currentRecipe)
    local listName = recipeName

    local db = GetDB()
    if not db then return end

    if db.global.shoppingLists.lists[listName] then
        print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_CONFIRM_LIST_EXISTS"], listName))
    else
        ns.ShoppingList:CreateList(listName)
    end

    local itemsAdded = 0
    for _, rg in ipairs(currentReagents) do
        local itemID = rg[1]
        local qty = rg[2]
        if itemID and qty then
            local ok = ns.ShoppingList:AddItemToList(listName, itemID, qty)
            if ok ~= false then itemsAdded = itemsAdded + 1 end
        end
    end

    if itemsAdded > 0 then
        print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_CRAFT_ORDER_UNDER"], listName, itemsAdded, itemsAdded ~= 1 and "s" or "", ""))
    end

    if ns.MainWindow and ns.MainWindow.frame and ns.MainWindow.frame:IsShown() then
        if ns.MainWindow.RefreshSidebar then ns.MainWindow:RefreshSidebar() end
        if ns.MainWindow.RefreshItemList then ns.MainWindow:RefreshItemList() end
    end
end

function CatalogIntegration:AddToActiveList()
    if not currentRecipe or not currentReagents then return end
    if not ns.ShoppingList then return end

    local db = GetDB()
    if not db then return end

    local activeList = db.global.shoppingLists.defaultList or db.global.shoppingLists.activeList or ns.MAIN_LIST_KEY

    local itemsAdded = 0
    for _, rg in ipairs(currentReagents) do
        local itemID = rg[1]
        local qty = rg[2]
        if itemID and qty then
            local ok = ns.ShoppingList:AddItemToList(activeList, itemID, qty)
            if ok ~= false then itemsAdded = itemsAdded + 1 end
        end
    end

    if itemsAdded > 0 then
        print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_CRAFT_ORDER_UNDER"], activeList, itemsAdded, itemsAdded ~= 1 and "s" or "", ""))
    end

    if ns.MainWindow and ns.MainWindow.frame and ns.MainWindow.frame:IsShown() then
        if ns.MainWindow.RefreshSidebar then ns.MainWindow:RefreshSidebar() end
        if ns.MainWindow.RefreshItemList then ns.MainWindow:RefreshItemList() end
    end
end

local function TryRegister()
    if _G.OneWoW_Catalog_TradeskillAPI then
        _G.OneWoW_Catalog_TradeskillAPI.RegisterRecipeCallback(OnRecipeSelected)
        return true
    end
    return false
end

function CatalogIntegration:Initialize()
    if TryRegister() then return end

    local hookFrame = CreateFrame("Frame")
    hookFrame:RegisterEvent("ADDON_LOADED")
    hookFrame:SetScript("OnEvent", function(self, event, addon)
        if addon == "OneWoW_Catalog" then
            C_Timer.After(0.5, function()
                TryRegister()
            end)
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
