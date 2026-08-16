local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

ns.CatalogIntegration = {}
local CatalogIntegration = ns.CatalogIntegration

local openListBtn
local makeListBtn
local addToActiveBtn
local currentRecipe = nil
local currentReagents = nil
local buttonsCreated = false

local function GetDB()
    return ns.db
end

local function ApplyLabels()
    if not makeListBtn then return end
    makeListBtn:SetFitText(L["OWSL_PROF_BTN_MAKE_LIST"])
    addToActiveBtn:SetFitText(L["OWSL_PROF_BTN_ADD_TO_ACTIVE"])
end

local function AttachCatalogTooltip(btn, titleKey, descKey)
    btn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(L[titleKey], 1, 1, 1)
        GameTooltip:AddLine(L[descKey], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
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

    addToActiveBtn = OneWoW_GUI:CreateFitTextButton(statusBar, {
        text = L["OWSL_PROF_BTN_ADD_TO_ACTIVE"],
        height = 21,
        minWidth = 40,
        paddingX = 16,
    })
    addToActiveBtn:SetPoint("RIGHT", statusBar, "RIGHT", -6, 0)
    addToActiveBtn:SetScript("OnClick", function()
        CatalogIntegration:AddToActiveList()
    end)
    AttachCatalogTooltip(addToActiveBtn, "OWSL_TT_ADD_TO_ACTIVE_TITLE", "OWSL_TT_ADD_TO_ACTIVE_DESC")

    makeListBtn = OneWoW_GUI:CreateFitTextButton(statusBar, {
        text = L["OWSL_PROF_BTN_MAKE_LIST"],
        height = 21,
        minWidth = 40,
        paddingX = 16,
    })
    makeListBtn:SetPoint("RIGHT", addToActiveBtn, "LEFT", -4, 0)
    makeListBtn:SetScript("OnClick", function()
        CatalogIntegration:MakeNewList()
    end)
    AttachCatalogTooltip(makeListBtn, "OWSL_TT_MAKE_LIST_TITLE", "OWSL_TT_MAKE_LIST_DESC")

    openListBtn = OneWoW_GUI:CreateAtlasIconButton(statusBar, {
        atlas = "Perks-ShoppingCart",
        width = 21,
        height = 21,
        iconInset = 3,
    })
    openListBtn:SetPoint("RIGHT", makeListBtn, "LEFT", -4, 0)
    openListBtn:SetScript("OnClick", function()
        ns.MainWindow:Toggle()
    end)
    AttachCatalogTooltip(openListBtn, "OWSL_WINDOW_TITLE", "OWSL_MM_CLICK_TO_OPEN")

    OneWoW_GUI:RegisterFontRoot(makeListBtn, ApplyLabels)
    OneWoW_GUI:RegisterFontRoot(addToActiveBtn)

    HideButtons()
end

local function GetRecipeName(recipe)
    if not recipe then return nil end
    local name = nil
    if recipe.item then
        name = C_Item.GetItemNameByID(recipe.item)
    end
    if not name and recipe.id then
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
        print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_CONFIRM_LIST_EXISTS"], listName))
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
        print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_CRAFT_ORDER_UNDER"], listName, itemsAdded, itemsAdded ~= 1 and "s" or "", ""))
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
        print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_CRAFT_ORDER_UNDER"], activeList, itemsAdded, itemsAdded ~= 1 and "s" or "", ""))
    end

    if ns.MainWindow and ns.MainWindow.frame and ns.MainWindow.frame:IsShown() then
        if ns.MainWindow.RefreshSidebar then ns.MainWindow:RefreshSidebar() end
        if ns.MainWindow.RefreshItemList then ns.MainWindow:RefreshItemList() end
    end
end

--- Refresh Catalog tradeskill button labels after a language change.
function CatalogIntegration:ApplyLanguage()
    ApplyLabels()
end

local function TryRegister()
    if OneWoW_Catalog_TradeskillAPI then
        OneWoW_Catalog_TradeskillAPI.RegisterRecipeCallback(OnRecipeSelected)
        return true
    end
    return false
end

function CatalogIntegration:Initialize()
    if TryRegister() then return end

    OneWoW_ShoppingList:RegisterAddonLoadedWatcher("OneWoW_Catalog", function()
        C_Timer.After(0.5, function()
            TryRegister()
        end)
    end)
end
