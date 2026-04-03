local ADDON_NAME, ns = ...
local L = ns.L

ns.ProfessionUI = {}
local ProfessionUI = ns.ProfessionUI

local function GetCurrentRecipeInfo()
    if not _G.ProfessionsFrame then return nil end

    local craftingPage = ProfessionsFrame.CraftingPage
    if not craftingPage then return nil end

    local schematicForm = craftingPage.SchematicForm
    if not schematicForm then return nil end

    local recipeInfo = schematicForm.GetRecipeInfo and schematicForm:GetRecipeInfo()
    if not recipeInfo then return nil end

    local recipeID = recipeInfo.recipeID
    if not recipeID then return nil end

    return recipeID, recipeInfo
end

local function AddIngredientsToList(listName, recipeID, quantity)
    quantity = tonumber(quantity) or 1

    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
    if not schematic or not schematic.reagentSlotSchematics then
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_NO_INGREDIENTS"])
        return false
    end

    local ingredients = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        if slot.reagents and #slot.reagents > 0 then
            local reagent = slot.reagents[1]
            if reagent and reagent.itemID then
                local qty = (slot.quantityRequired or 1) * quantity
                table.insert(ingredients, { itemID = reagent.itemID, quantity = qty })
            end
        end
    end

    if #ingredients == 0 then
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_NO_INGREDIENTS"])
        return false
    end

    for _, ingredient in ipairs(ingredients) do
        ns.ShoppingList:AddItemToList(listName, ingredient.itemID, ingredient.quantity)
    end

    return true, #ingredients
end

local openBtn
local makeListBtn
local addToActiveBtn
local addToListBtn

local function CreateButtons(schematicForm)
    if openBtn then return end

    openBtn = CreateFrame("Button", nil, schematicForm, "BackdropTemplate")
    openBtn:SetSize(30, 30)
    openBtn:SetPoint("BOTTOMRIGHT", schematicForm, "BOTTOMRIGHT", -10, 10)
    openBtn:SetNormalAtlas("Perks-ShoppingCart")
    openBtn:SetPushedAtlas("Perks-ShoppingCart")
    openBtn:SetHighlightAtlas("Perks-ShoppingCart")
    openBtn:GetHighlightTexture():SetAlpha(0.5)

    openBtn:SetScript("OnClick", function()
        if ns.MainWindow then ns.MainWindow:Toggle() end
    end)
    openBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["OWSL_TT_OPEN_LIST_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_TT_OPEN_LIST_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    openBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    makeListBtn = CreateFrame("Button", nil, schematicForm, "BackdropTemplate")
    makeListBtn:SetSize(90, 30)
    makeListBtn:SetPoint("RIGHT", openBtn, "LEFT", -5, 0)
    makeListBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    makeListBtn:SetBackdropColor(0.14, 0.16, 0.14, 1.0)
    makeListBtn:SetBackdropBorderColor(0.32, 0.48, 0.35, 0.5)

    makeListBtn.text = makeListBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    makeListBtn.text:SetPoint("CENTER")
    makeListBtn.text:SetText(L["OWSL_PROF_BTN_MAKE_LIST"])
    makeListBtn.text:SetTextColor(0.88, 0.90, 0.88, 1.0)

    makeListBtn:SetScript("OnClick", function()
        local recipeID, recipeInfo = GetCurrentRecipeInfo()
        if not recipeID or not recipeInfo then return end

        local recipeName = recipeInfo.name or (string.format(L["OWSL_RECIPE_UNKNOWN"], recipeID))
        local listName   = recipeName

        local db = GetDB()
        if db and db.global.shoppingLists.lists[listName] then
            print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_CONFIRM_LIST_EXISTS"], listName))
            print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_CONFIRM_LIST_EXISTS2"])
        else
            ns.ShoppingList:CreateList(listName)
        end

        local ok, count = AddIngredientsToList(listName, recipeID, 1)
        if ok then
            print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_CRAFT_ORDER_UNDER"], listName, count, count ~= 1 and "s" or "", ""))
        end
    end)

    makeListBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["OWSL_TT_MAKE_LIST_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_TT_MAKE_LIST_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    makeListBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    addToActiveBtn = CreateFrame("Button", nil, schematicForm, "BackdropTemplate")
    addToActiveBtn:SetSize(100, 30)
    addToActiveBtn:SetPoint("RIGHT", makeListBtn, "LEFT", -5, 0)
    addToActiveBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    addToActiveBtn:SetBackdropColor(0.14, 0.16, 0.14, 1.0)
    addToActiveBtn:SetBackdropBorderColor(0.32, 0.48, 0.35, 0.5)

    addToActiveBtn.text = addToActiveBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addToActiveBtn.text:SetPoint("CENTER")
    addToActiveBtn.text:SetText(L["OWSL_PROF_BTN_ADD_TO_ACTIVE"])
    addToActiveBtn.text:SetTextColor(0.88, 0.90, 0.88, 1.0)

    addToActiveBtn:SetScript("OnClick", function()
        local recipeID, recipeInfo = GetCurrentRecipeInfo()
        if not recipeID then return end

        local db = GetDB()
        if not db then return end

        local activeList = db.global.shoppingLists.defaultList or db.global.shoppingLists.activeList or ns.MAIN_LIST_KEY
        local ok, count = AddIngredientsToList(activeList, recipeID, 1)
        if ok then
            print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_CRAFT_ORDER_UNDER"], activeList, count, count ~= 1 and "s" or "", ""))
        end
    end)

    addToActiveBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["OWSL_TT_ADD_TO_ACTIVE_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_TT_ADD_TO_ACTIVE_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addToActiveBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    addToListBtn = CreateFrame("Button", nil, schematicForm, "BackdropTemplate")
    addToListBtn:SetSize(100, 30)
    addToListBtn:SetPoint("RIGHT", addToActiveBtn, "LEFT", -5, 0)
    addToListBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    addToListBtn:SetBackdropColor(0.14, 0.16, 0.14, 1.0)
    addToListBtn:SetBackdropBorderColor(0.32, 0.48, 0.35, 0.5)

    addToListBtn.text = addToListBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addToListBtn.text:SetPoint("CENTER")
    addToListBtn.text:SetText(L["OWSL_PROF_BTN_ADD_TO_LIST"])
    addToListBtn.text:SetTextColor(0.88, 0.90, 0.88, 1.0)

    addToListBtn:SetScript("OnClick", function(self)
        local recipeID, recipeInfo = GetCurrentRecipeInfo()
        if not recipeID then return end

        local db = GetDB()
        if not db then return end

        local allLists = ns.ShoppingList:GetAllLists()
        MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, rootDescription)
            rootDescription:CreateTitle(L["OWSL_TT_ADD_TO_LIST_TITLE"])
            for listName in pairs(allLists) do
                local capturedName = listName
                rootDescription:CreateButton(listName, function()
                    local ok, count = AddIngredientsToList(capturedName, recipeID, 1)
                    if ok then
                        print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_CRAFT_ORDER_UNDER"], capturedName, count, count ~= 1 and "s" or "", ""))
                    end
                end)
            end
        end)
    end)

    addToListBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["OWSL_TT_ADD_TO_LIST_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_TT_ADD_TO_LIST_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addToListBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function GetDB()
    return _G.OneWoW_ShoppingList_DB
end

function ProfessionUI:Initialize()
    if not _G.ProfessionsFrame then
        local hookFrame = CreateFrame("Frame")
        hookFrame:RegisterEvent("ADDON_LOADED")
        hookFrame:SetScript("OnEvent", function(self, event, addon)
            if addon == "Blizzard_Professions" then
                C_Timer.After(0.5, function()
                    ProfessionUI:HookProfessionsFrame()
                end)
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    else
        C_Timer.After(0.5, function()
            ProfessionUI:HookProfessionsFrame()
        end)
    end
end

function ProfessionUI:UpdateVisibility()
    local db = _G.OneWoW_ShoppingList_DB
    local show = not (db and db.global and db.global.settings.showProfessionButtons == false)
    if show then
        if openBtn then openBtn:Show() end
        if makeListBtn then makeListBtn:Show() end
        if addToActiveBtn then addToActiveBtn:Show() end
        if addToListBtn then addToListBtn:Show() end
    else
        if openBtn then openBtn:Hide() end
        if makeListBtn then makeListBtn:Hide() end
        if addToActiveBtn then addToActiveBtn:Hide() end
        if addToListBtn then addToListBtn:Hide() end
    end
end

function ProfessionUI:HookProfessionsFrame()
    if not _G.ProfessionsFrame then return end
    local craftingPage = ProfessionsFrame.CraftingPage
    if not craftingPage then return end
    local schematicForm = craftingPage.SchematicForm
    if not schematicForm then return end

    CreateButtons(schematicForm)
    ProfessionUI:UpdateVisibility()

    if schematicForm.SetRecipeID then
        hooksecurefunc(schematicForm, "SetRecipeID", function(self)
            ProfessionUI:UpdateVisibility()
        end)
    end
end
