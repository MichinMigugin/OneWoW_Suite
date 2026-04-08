local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local BagSet = OneWoW_Bags.BagSet
local WH = OneWoW_Bags.WindowHelpers

local floor = math.floor
local pairs, ipairs = pairs, ipairs
local tinsert, sort = tinsert, sort
local C_Container = C_Container

OneWoW_Bags.InfoBar = {}
local InfoBar = OneWoW_Bags.InfoBar

local infoBarFrame = nil

local ROW1_H = 28
local ROW2_H = 28

local function GetController()
    return OneWoW_Bags.BagsController
end

local function GetEffectiveInfoBarChrome(db)
    local altReveal = OneWoW_Bags:IsAltShowActive()
    local showHeader = (db.global.showHeaderBar ~= false) or altReveal
    local showSearch = (db.global.showSearchBar ~= false) or altReveal
    return showHeader, showSearch
end

function InfoBar:Create(parent)
    if infoBarFrame then return infoBarFrame end

    infoBarFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    infoBarFrame:SetHeight(Constants.GUI.INFOBAR_HEIGHT)
    infoBarFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    infoBarFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    infoBarFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    infoBarFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    infoBarFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local btnY   = -floor((ROW1_H - 22) / 2)
    local searchY = -(ROW1_H + floor((ROW2_H - 22) / 2))

    -- Row 1 right: Category Manager button
    local catMgrBtn = InfoBar:CreateViewBtn(infoBarFrame, L["CATEGORY_MANAGER_BTN"])
    catMgrBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -OneWoW_GUI:GetSpacing("SM"), btnY)
    catMgrBtn:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.ToggleCategoryManager then
            controller:ToggleCategoryManager()
        end
    end)
    infoBarFrame.catMgrBtn = catMgrBtn

    local sortBtn = InfoBar:CreateViewBtn(infoBarFrame, L["CLEANUP"] or "Sort")
    sortBtn:SetPoint("TOPRIGHT", catMgrBtn, "TOPLEFT", -3, 0)
    sortBtn:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.SortBags then
            controller:SortBags()
        end
    end)
    infoBarFrame.sortBtn = sortBtn

    -- Row 1 left: view buttons
    local viewList = InfoBar:CreateViewBtn(infoBarFrame, L["VIEW_LIST"])
    viewList:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", OneWoW_GUI:GetSpacing("SM"), btnY)
    viewList:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.SetViewMode then
            controller:SetViewMode("list")
        end
        InfoBar:UpdateViewButtons()
    end)
    infoBarFrame.viewList = viewList

    local viewCat = InfoBar:CreateViewBtn(infoBarFrame, L["VIEW_CATEGORY"])
    viewCat:SetPoint("TOPLEFT", viewList, "TOPRIGHT", 3, 0)
    viewCat:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.SetViewMode then
            controller:SetViewMode("category")
        end
        InfoBar:UpdateViewButtons()
    end)
    infoBarFrame.viewCat = viewCat

    local viewBag = InfoBar:CreateViewBtn(infoBarFrame, L["VIEW_BAG"])
    viewBag:SetPoint("TOPLEFT", viewCat, "TOPRIGHT", 3, 0)
    viewBag:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.SetViewMode then
            controller:SetViewMode("bag")
        end
        InfoBar:UpdateViewButtons()
    end)
    infoBarFrame.viewBag = viewBag

    local expacDropdown, expacText = OneWoW_GUI:CreateDropdown(infoBarFrame, {
        width = 130, height = 22, text = L["EXPAC_FILTER_BTN"],
    })
    expacDropdown:SetPoint("TOPLEFT", viewBag, "TOPRIGHT", 8, 0)
    OneWoW_GUI:AttachFilterMenu(expacDropdown, {
        searchable = false,
        buildItems = function()
            local items = { { text = L["EXPAC_FILTER_ALL"], value = "ALL" } }
            if not BagSet.isBuilt or not WH then return items end
            local found = {}
            for _, btn in ipairs(BagSet:GetAllButtons()) do
                if btn.owb_hasItem and btn.owb_itemInfo and btn.owb_itemInfo.itemID then
                    local expansionID = WH:ResolveExpansionID(btn.owb_itemInfo, btn.owb_bagID, btn.owb_slotID)
                    if expansionID ~= nil then
                        found[expansionID] = true
                    end
                end
            end
            local ids = {}
            for id in pairs(found) do tinsert(ids, id) end
            if #ids == 0 then
                ids = WH:GetKnownExpansionIDs()
            else
                sort(ids)
            end
            for _, id in ipairs(ids) do
                tinsert(items, { text = WH:GetExpansionName(id) or ("Expansion " .. id), value = id })
            end
            return items
        end,
        getActiveValue = function()
            local controller = GetController()
            local v = controller and controller.GetExpansionFilter and controller:GetExpansionFilter() or nil
            return (v == nil) and "ALL" or v
        end,
        onSelect = function(value, text)
            local controller = GetController()
            if controller and controller.SetExpansionFilter then
                controller:SetExpansionFilter(value)
            end
            if value == "ALL" then
                expacText:SetText(L["EXPAC_FILTER_BTN"])
            else
                expacText:SetText(text)
            end
        end,
    })
    infoBarFrame.expacDropdown = expacDropdown
    infoBarFrame.expacText = expacText

    -- Row 2 right: empty slots toggle (created before searchBox so search can anchor to it)
    local emptyToggleBtn = CreateFrame("Button", nil, infoBarFrame)
    emptyToggleBtn:SetSize(22, 22)
    emptyToggleBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -OneWoW_GUI:GetSpacing("SM"), searchY)
    local emptyIcon = emptyToggleBtn:CreateTexture(nil, "ARTWORK")
    emptyIcon:SetAllPoints()
    emptyIcon:SetTexture("Interface\\COMMON\\FavoritesIcon")
    emptyToggleBtn:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.ToggleEmptySlots then
            controller:ToggleEmptySlots()
        end
        InfoBar:UpdateViewButtons()
    end)
    emptyToggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local controller = GetController()
        local showing = controller and controller.GetShowEmptySlots and controller:GetShowEmptySlots() or true
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
            local controller = GetController()
            if controller and controller.OnSearchChanged then
                controller:OnSearchChanged(text)
            end
        end,
    })
    searchBox:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", OneWoW_GUI:GetSpacing("SM"), searchY)
    searchBox:SetPoint("TOPRIGHT", emptyToggleBtn, "TOPLEFT", -3, 0)
    infoBarFrame.searchBox = searchBox

    InfoBar:UpdateVisibility()
    InfoBar:UpdateViewButtons()

    local function CreateShoppingCartButton()
        if infoBarFrame.shoppingCartBtn then return end
        local cartBtn = CreateFrame("Button", nil, infoBarFrame)
        cartBtn:SetSize(22, 22)
        cartBtn:SetPoint("TOPRIGHT", infoBarFrame.sortBtn or catMgrBtn, "TOPLEFT", -3, 0)
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
            GameTooltip:SetText(L["SHOPPING_LIST"], 1, 1, 1)
            GameTooltip:AddLine(L["SHOPPING_LIST_DESC"], 0.8, 0.8, 0.8, true)
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
    local db = OneWoW_Bags:GetDB()
    local controller = GetController()
    local mode = controller and controller.GetViewMode and controller:GetViewMode() or db.global.viewMode

    local showHeader, showSearch = GetEffectiveInfoBarChrome(db)

    local buttons = {
        { btn = infoBarFrame.viewList, mode = "list" },
        { btn = infoBarFrame.viewCat, mode = "category" },
        { btn = infoBarFrame.viewBag, mode = "bag" },
    }

    for _, entry in ipairs(buttons) do
        local btn = entry.btn
        if not showHeader then
            btn:Hide()
        else
            btn:Show()
            if entry.mode == mode then
                btn.isActive = true
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            else
                btn.isActive = false
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end
    end

    if infoBarFrame.catMgrBtn then infoBarFrame.catMgrBtn:SetShown(showHeader) end
    if infoBarFrame.sortBtn then infoBarFrame.sortBtn:SetShown(showHeader) end
    if infoBarFrame.shoppingCartBtn then infoBarFrame.shoppingCartBtn:SetShown(showHeader) end
    if infoBarFrame.searchBox then infoBarFrame.searchBox:SetShown(showSearch) end

    if infoBarFrame.expacDropdown then
        local showExpac = showHeader and (db.global.enableExpansionFilter == true)
        infoBarFrame.expacDropdown:SetShown(showExpac == true)
        if showExpac and infoBarFrame.expacText then
            local activeFilter = controller and controller.GetExpansionFilter and controller:GetExpansionFilter() or nil
            if activeFilter == nil then
                infoBarFrame.expacText:SetText(L["EXPAC_FILTER_BTN"])
            else
                local expName = WH and WH:GetExpansionName(activeFilter) or tostring(activeFilter)
                infoBarFrame.expacText:SetText(expName)
            end
        end
    end

    if infoBarFrame.emptyToggleBtn then
        local showing = controller and controller.GetShowEmptySlots and controller:GetShowEmptySlots() or true
        if showing then
            infoBarFrame.emptyToggleBtn:SetAlpha(1.0)
        else
            infoBarFrame.emptyToggleBtn:SetAlpha(0.35)
        end
        infoBarFrame.emptyToggleBtn:SetShown(showSearch and mode == "list")
    end

    local newHeight = 0
    if showHeader then newHeight = newHeight + ROW1_H end
    if showSearch then newHeight = newHeight + ROW2_H end

    if newHeight == 0 then
        infoBarFrame:Hide()
    else
        infoBarFrame:SetHeight(newHeight)
        infoBarFrame:Show()
    end
end

function InfoBar:UpdateVisibility()
    if not infoBarFrame then return end

    local db = OneWoW_Bags:GetDB()

    self:UpdateViewButtons()

    local showHeader, showSearch = GetEffectiveInfoBarChrome(db)

    if showSearch and infoBarFrame.searchBox then
        local searchY = showHeader and -(ROW1_H + floor((ROW2_H - 22) / 2)) or -floor((ROW2_H - 22) / 2)
        infoBarFrame.searchBox:ClearAllPoints()
        infoBarFrame.searchBox:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", OneWoW_GUI:GetSpacing("SM"), searchY)
        infoBarFrame.searchBox:SetPoint("TOPRIGHT", infoBarFrame.emptyToggleBtn, "TOPLEFT", -3, 0)

        if infoBarFrame.emptyToggleBtn then
            infoBarFrame.emptyToggleBtn:ClearAllPoints()
            infoBarFrame.emptyToggleBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -OneWoW_GUI:GetSpacing("SM"), searchY)
        end
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
        if infoBarFrame.searchBox.RestorePlaceholder then
            infoBarFrame.searchBox:RestorePlaceholder()
        elseif infoBarFrame.searchBox.placeholderText and infoBarFrame.searchBox.placeholderText ~= "" then
            infoBarFrame.searchBox:SetText(infoBarFrame.searchBox.placeholderText)
            infoBarFrame.searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
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
