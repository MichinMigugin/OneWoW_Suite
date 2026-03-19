local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.InfoBar = {}
local InfoBar = OneWoW_Bags.InfoBar

local infoBarFrame = nil
local OneWoW_GUI = OneWoW_Bags.GUILib
local T = OneWoW_Bags.T
local S = OneWoW_Bags.S

local ROW1_H = 28
local ROW2_H = 28

function InfoBar:Create(parent)
    if infoBarFrame then return infoBarFrame end

    local Constants = OneWoW_Bags.Constants
    local L = OneWoW_Bags.L
    local C = Constants.GUI

    infoBarFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    infoBarFrame:SetHeight(C.INFOBAR_HEIGHT)
    infoBarFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    infoBarFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    infoBarFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    infoBarFrame:SetBackdropColor(T("BG_TERTIARY"))
    infoBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local btnY   = -math.floor((ROW1_H - 22) / 2)
    local searchY = -(ROW1_H + math.floor((ROW2_H - 22) / 2))

    -- Row 1 right: Category Manager button
    local catMgrBtn = InfoBar:CreateViewBtn(infoBarFrame, L["CATEGORY_MANAGER_BTN"])
    catMgrBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -S("SM"), btnY)
    catMgrBtn:SetScript("OnClick", function()
        if OneWoW_Bags.CategoryManagerUI then
            OneWoW_Bags.CategoryManagerUI:Toggle()
        end
    end)
    infoBarFrame.catMgrBtn = catMgrBtn

    -- Row 1 left: view buttons
    local viewList = InfoBar:CreateViewBtn(infoBarFrame, L["VIEW_LIST"])
    viewList:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", S("SM"), btnY)
    viewList:SetScript("OnClick", function()
        OneWoW_Bags.db.global.viewMode = "list"
        InfoBar:UpdateViewButtons()
        if OneWoW_Bags.GUI.RefreshLayout then
            OneWoW_Bags.GUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewList = viewList

    local viewCat = InfoBar:CreateViewBtn(infoBarFrame, L["VIEW_CATEGORY"])
    viewCat:SetPoint("TOPLEFT", viewList, "TOPRIGHT", 3, 0)
    viewCat:SetScript("OnClick", function()
        OneWoW_Bags.db.global.viewMode = "category"
        InfoBar:UpdateViewButtons()
        if OneWoW_Bags.GUI.RefreshLayout then
            OneWoW_Bags.GUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewCat = viewCat

    local viewBag = InfoBar:CreateViewBtn(infoBarFrame, L["VIEW_BAG"])
    viewBag:SetPoint("TOPLEFT", viewCat, "TOPRIGHT", 3, 0)
    viewBag:SetScript("OnClick", function()
        OneWoW_Bags.db.global.viewMode = "bag"
        InfoBar:UpdateViewButtons()
        if OneWoW_Bags.GUI.RefreshLayout then
            OneWoW_Bags.GUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewBag = viewBag

    -- Row 2 right: empty slots toggle (created before searchBox so search can anchor to it)
    local emptyToggleBtn = CreateFrame("Button", nil, infoBarFrame)
    emptyToggleBtn:SetSize(22, 22)
    emptyToggleBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -S("SM"), searchY)
    local emptyIcon = emptyToggleBtn:CreateTexture(nil, "ARTWORK")
    emptyIcon:SetAllPoints()
    emptyIcon:SetTexture("Interface\\COMMON\\FavoritesIcon")
    emptyToggleBtn:SetScript("OnClick", function()
        local db = OneWoW_Bags.db.global
        db.showEmptySlots = not db.showEmptySlots
        InfoBar:UpdateViewButtons()
        if OneWoW_Bags.GUI.RefreshLayout then
            OneWoW_Bags.GUI:RefreshLayout()
        end
    end)
    emptyToggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local showing = OneWoW_Bags.db.global.showEmptySlots
        if showing == nil then showing = true end
        if showing then
            GameTooltip:SetText(L["EMPTY_SLOTS_HIDE"], 1, 1, 1)
        else
            GameTooltip:SetText(L["EMPTY_SLOTS_SHOW"], 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    emptyToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    infoBarFrame.emptyToggleBtn = emptyToggleBtn

    -- Row 2: search bar fills left to just before the empty slots toggle
    local searchBox = OneWoW_GUI:CreateEditBox(infoBarFrame, {
        name = "OneWoW_BagsSearch",
        height = 22,
        placeholderText = L["SEARCH_PLACEHOLDER"],
        onTextChanged = function(text)
            if OneWoW_Bags.GUI.OnSearchChanged then
                OneWoW_Bags.GUI:OnSearchChanged(text)
            end
        end,
    })
    searchBox:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", S("SM"), searchY)
    searchBox:SetPoint("TOPRIGHT", emptyToggleBtn, "TOPLEFT", -3, 0)
    infoBarFrame.searchBox = searchBox

    InfoBar:UpdateViewButtons()

    -- Shopping cart button (optional, created when ShoppingList loads)
    local function CreateShoppingCartButton()
        if infoBarFrame.shoppingCartBtn then return end
        local cartBtn = CreateFrame("Button", nil, infoBarFrame)
        cartBtn:SetSize(22, 22)
        cartBtn:SetPoint("TOPRIGHT", catMgrBtn, "TOPLEFT", -3, 0)
        cartBtn:SetNormalAtlas("Perks-ShoppingCart")
        cartBtn:SetPushedAtlas("Perks-ShoppingCart")
        cartBtn:SetHighlightAtlas("Perks-ShoppingCart")
        cartBtn:GetHighlightTexture():SetAlpha(0.5)
        cartBtn:SetScript("OnClick", function()
            if _G.OneWoW_ShoppingList and _G.OneWoW_ShoppingList.MainWindow then
                _G.OneWoW_ShoppingList.MainWindow:Toggle()
            end
        end)
        cartBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(OneWoW_Bags.L["SHOPPING_LIST"], 1, 1, 1)
            GameTooltip:AddLine(OneWoW_Bags.L["SHOPPING_LIST_DESC"], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        cartBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        infoBarFrame.shoppingCartBtn = cartBtn
    end

    if _G.OneWoW_ShoppingList then
        CreateShoppingCartButton()
    else
        local slEventFrame = CreateFrame("Frame")
        slEventFrame:RegisterEvent("ADDON_LOADED")
        slEventFrame:SetScript("OnEvent", function(_, event, addonName)
            if addonName == "OneWoW_ShoppingList" then
                CreateShoppingCartButton()
                slEventFrame:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end

    return infoBarFrame
end

function InfoBar:CreateViewBtn(parent, label)
    local btn = OneWoW_GUI:CreateFitTextButton(parent, { text = label, height = 22, minWidth = 36 })
    btn.isActive = false

    btn._defaultEnter = btn:GetScript("OnEnter")
    btn._defaultLeave = btn:GetScript("OnLeave")

    btn:SetScript("OnEnter", function(self)
        if not self.isActive and self._defaultEnter then
            self._defaultEnter(self)
        end
    end)

    btn:SetScript("OnLeave", function(self)
        if not self.isActive and self._defaultLeave then
            self._defaultLeave(self)
        end
    end)

    return btn
end

function InfoBar:UpdateViewButtons()
    if not infoBarFrame then return end
    local mode = OneWoW_Bags.db and OneWoW_Bags.db.global.viewMode or "list"

    local buttons = {
        { btn = infoBarFrame.viewList, mode = "list" },
        { btn = infoBarFrame.viewCat, mode = "category" },
        { btn = infoBarFrame.viewBag, mode = "bag" },
    }

    for _, entry in ipairs(buttons) do
        local btn = entry.btn
        if entry.mode == mode then
            btn.isActive = true
            btn:SetBackdropColor(T("BG_ACTIVE"))
            btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
            btn.text:SetTextColor(T("TEXT_ACCENT"))
        else
            btn.isActive = false
            btn:SetBackdropColor(T("BTN_NORMAL"))
            btn:SetBackdropBorderColor(T("BTN_BORDER"))
            btn.text:SetTextColor(T("TEXT_PRIMARY"))
        end
    end

    if infoBarFrame.emptyToggleBtn then
        local showing = OneWoW_Bags.db and OneWoW_Bags.db.global.showEmptySlots
        if showing == nil then showing = true end
        if showing then
            infoBarFrame.emptyToggleBtn:SetAlpha(1.0)
        else
            infoBarFrame.emptyToggleBtn:SetAlpha(0.35)
        end
        infoBarFrame.emptyToggleBtn:SetShown(mode == "list")
    end
end

function InfoBar:GetSearchText()
    if infoBarFrame and infoBarFrame.searchBox then
        if infoBarFrame.searchBox.GetSearchText then
            return infoBarFrame.searchBox:GetSearchText()
        end
        return infoBarFrame.searchBox:GetText() or ""
    end
    return ""
end

function InfoBar:ClearSearch()
    if infoBarFrame and infoBarFrame.searchBox then
        infoBarFrame.searchBox:SetText("")
        infoBarFrame.searchBox:ClearFocus()
    end
end

function InfoBar:GetFrame()
    return infoBarFrame
end

function InfoBar:Reset()
    if infoBarFrame then
        infoBarFrame:Hide()
        infoBarFrame:SetParent(UIParent)
    end
    infoBarFrame = nil
end
