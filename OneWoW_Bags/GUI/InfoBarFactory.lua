local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local WH = OneWoW_Bags.WindowHelpers

local floor = math.floor
local ipairs, pairs = ipairs, pairs
local tinsert, sort = tinsert, sort

OneWoW_Bags.InfoBarFactory = {}

function OneWoW_Bags.InfoBarFactory:Create(config)
    local bar = {}
    local infoBarFrame = nil

    local ROW1_H = 28
    local ROW2_H = 28

    local function GetShowHeader(db)
        if config.showHeaderFn then return config.showHeaderFn(db) end
        if not config.showHeaderKey then return true end
        return db.global[config.showHeaderKey] ~= false
    end

    local function GetShowSearch(db)
        if config.showSearchFn then return config.showSearchFn(db) end
        if not config.showSearchKey then return true end
        return db.global[config.showSearchKey] ~= false
    end

    local function GetController()
        if config.controller then
            return config.controller
        end
        if config.controllerKey then
            return OneWoW_Bags[config.controllerKey]
        end
        return nil
    end

    local function GetGUI()
        return OneWoW_Bags[config.guiTargetKey]
    end

    local function GetFactoryChromeInsets()
        local db = OneWoW_Bags:GetDB()
        local hideScroll = false
        if config.hideScrollBarFn then
            hideScroll = config.hideScrollBarFn(db) and true or false
        elseif config.hideScrollBarKey then
            hideScroll = db.global[config.hideScrollBarKey] and true or false
        else
            hideScroll = db.global.hideScrollBar and true or false
        end
        return WH:GetItemGridChromeInsets(hideScroll)
    end

    local function GetExpacEnabled(db)
        if config.expacFilter then
            if config.expacFilter.settingFn then
                return config.expacFilter.settingFn(db) == true
            end
            return db.global[config.expacFilter.settingKey] == true
        end
        return false
    end

    local function effectiveViewMode(raw)
        if raw then
            for _, vm in ipairs(config.viewModes) do
                if vm.mode == raw then
                    return raw
                end
            end
        end
        return config.viewModes[1].mode
    end

    local function viewModeLabel(mode)
        for _, vm in ipairs(config.viewModes) do
            if vm.mode == mode then
                return L[vm.labelKey] or vm.labelKey
            end
        end
        return L[config.viewModes[1].labelKey] or config.viewModes[1].labelKey
    end

    function bar:CreateViewBtn(parent, label)
        local btn = OneWoW_GUI:CreateFitTextButton(parent, { text = label, height = 22, minWidth = 36 })
        btn.isActive = false

        btn._defaultEnter = btn:GetScript("OnEnter")
        btn._defaultLeave = btn:GetScript("OnLeave")

        btn:SetScript("OnEnter", function(self)
            if not self.isActive and self._defaultEnter then self._defaultEnter(self) end
        end)
        btn:SetScript("OnLeave", function(self)
            if not self.isActive and self._defaultLeave then self._defaultLeave(self) end
        end)

        return btn
    end

    function bar:Create(parent)
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

        local leftInset, rightInset = GetFactoryChromeInsets()

        local dropW = config.viewModeDropdownWidth or 170
        local viewModeDropdown, viewModeText = OneWoW_GUI:CreateDropdown(infoBarFrame, {
            width = dropW,
            height = 22,
            text = viewModeLabel(config.viewModes[1].mode),
        })
        viewModeDropdown:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", leftInset, btnY)
        infoBarFrame.viewModeDropdown = viewModeDropdown
        infoBarFrame.viewModeText = viewModeText
        OneWoW_GUI:AttachFilterMenu(viewModeDropdown, {
            searchable = false,
            buildItems = function()
                local items = {}
                for _, vm in ipairs(config.viewModes) do
                    tinsert(items, { text = L[vm.labelKey] or vm.labelKey, value = vm.mode })
                end
                return items
            end,
            getActiveValue = function()
                local controller = GetController()
                local raw = controller and controller.GetViewMode and controller:GetViewMode()
                if raw == nil then
                    local d = OneWoW_Bags:GetDB()
                    raw = d and d.global and d.global[config.viewModeDBKey]
                end
                return effectiveViewMode(raw)
            end,
            onSelect = function(value, text)
                local controller = GetController()
                if config.onViewModeChanged then
                    config.onViewModeChanged(value, controller)
                elseif controller and controller.SetViewMode then
                    controller:SetViewMode(value)
                end
                if viewModeText then
                    viewModeText:SetText(text)
                end
                bar:UpdateViewButtons()
            end,
        })

        if config.expacFilter then
            local ef = config.expacFilter
            local expacDropdown, expacText = OneWoW_GUI:CreateDropdown(infoBarFrame, {
                width = 130, height = 22, text = L["EXPAC_FILTER_BTN"],
            })
            expacDropdown:SetPoint("TOPLEFT", viewModeDropdown, "TOPRIGHT", 8, 0)
            OneWoW_GUI:AttachFilterMenu(expacDropdown, {
                searchable = false,
                buildItems = function()
                    local BagSet = OneWoW_Bags[ef.bagSetKey]
                    local items = { { text = L["EXPAC_FILTER_ALL"], value = "ALL" } }
                    if not BagSet or not BagSet.isBuilt or not WH then return items end
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
                        tinsert(items, { text = WH:GetExpansionName(id) or L["EXPANSION_FALLBACK"]:format(id), value = id })
                    end
                    return items
                end,
                getActiveValue = function()
                    local controller = GetController()
                    local v = controller and controller.GetExpansionFilter and controller:GetExpansionFilter() or OneWoW_Bags[ef.filterKey]
                    return (v == nil) and "ALL" or v
                end,
                onSelect = function(value, text)
                    local controller = GetController()
                    if config.onExpansionFilterChanged then
                        config.onExpansionFilterChanged(value, text, controller)
                    elseif controller and controller.SetExpansionFilter then
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
        end

        if config.categoryManagerCallback then
            local categoriesBtn = OneWoW_GUI:CreateAtlasIconButton(infoBarFrame, {
                atlas = "housing-sidetabs-catalog-active",
                width = 20,
                height = 20,
            })
            categoriesBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, btnY)
            categoriesBtn:SetScript("OnClick", function()
                config.categoryManagerCallback(GetController())
            end)
            categoriesBtn:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["CATEGORY_MANAGER_BTN"], 1, 1, 1)
                GameTooltip:Show()
            end)
            categoriesBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
            infoBarFrame.categoriesBtn = categoriesBtn
        end

        if config.cleanupCallback then
            local cleanupBtn = OneWoW_GUI:CreateAtlasIconButton(infoBarFrame, {
                atlas = "crosshair_ui-cursor-broom_32",
                width = 20,
                height = 20,
            })
            if infoBarFrame.categoriesBtn then
                cleanupBtn:SetPoint("RIGHT", infoBarFrame.categoriesBtn, "LEFT", -4, 0)
            else
                cleanupBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, btnY)
            end
            cleanupBtn:SetScript("OnClick", function()
                config.cleanupCallback(GetController())
            end)
            cleanupBtn:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["CLEANUP"], 1, 1, 1)
                GameTooltip:Show()
            end)
            cleanupBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
            infoBarFrame.cleanupBtn = cleanupBtn
        end

        local emptyToggleBtn = CreateFrame("Button", nil, infoBarFrame)
        emptyToggleBtn:SetSize(22, 22)
        emptyToggleBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, searchY)
        local emptyIcon = emptyToggleBtn:CreateTexture(nil, "ARTWORK")
        emptyIcon:SetAllPoints()
        emptyIcon:SetTexture("Interface\\COMMON\\FavoritesIcon")
        emptyToggleBtn:SetScript("OnClick", function()
            local controller = GetController()
            if config.onEmptySlotsToggled then
                config.onEmptySlotsToggled(controller)
            elseif controller and controller.ToggleEmptySlots then
                controller:ToggleEmptySlots()
            end
            bar:UpdateViewButtons()
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

        local searchBox = OneWoW_GUI:CreateEditBox(infoBarFrame, {
            name = config.searchName,
            height = 22,
            placeholderText = L["SEARCH_PLACEHOLDER"],
            onTextChanged = function(text)
                local controller = GetController()
                if config.onSearchChanged then
                    config.onSearchChanged(text, controller)
                elseif controller and controller.OnSearchChanged then
                    controller:OnSearchChanged(text)
                else
                    local gui = GetGUI()
                    if gui then gui:OnSearchChanged(text) end
                end
            end,
        })
        searchBox:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", leftInset, searchY)
        searchBox:SetPoint("TOPRIGHT", emptyToggleBtn, "TOPLEFT", -3, 0)
        infoBarFrame.searchBox = searchBox

        bar:UpdateVisibility()
        return infoBarFrame
    end

    function bar:UpdateViewButtons()
        if not infoBarFrame then return end
        local db = OneWoW_Bags:GetDB()
        local controller = GetController()
        local rawMode = controller and controller.GetViewMode and controller:GetViewMode() or db.global[config.viewModeDBKey] or config.viewModes[1].mode
        local showHeader = GetShowHeader(db)
        local showSearch = GetShowSearch(db)

        if infoBarFrame.viewModeDropdown and infoBarFrame.viewModeText then
            if showHeader then
                infoBarFrame.viewModeDropdown:Show()
                infoBarFrame.viewModeText:SetText(viewModeLabel(effectiveViewMode(rawMode)))
            else
                infoBarFrame.viewModeDropdown:Hide()
            end
        end

        if infoBarFrame.cleanupBtn then
            infoBarFrame.cleanupBtn:SetShown(showHeader)
        end

        if infoBarFrame.categoriesBtn then
            infoBarFrame.categoriesBtn:SetShown(showHeader)
        end

        if infoBarFrame.emptyToggleBtn then
            local showing = controller and controller.GetShowEmptySlots and controller:GetShowEmptySlots() or true
            infoBarFrame.emptyToggleBtn:SetAlpha(showing and 1.0 or 0.35)
            infoBarFrame.emptyToggleBtn:SetShown(showSearch and (rawMode == "list" or rawMode == "tab"))
        end

        if infoBarFrame.searchBox then
            infoBarFrame.searchBox:SetShown(showSearch)
        end

        if config.expacFilter and infoBarFrame.expacDropdown then
            local ef = config.expacFilter
            local showExpac = showHeader and GetExpacEnabled(db)
            infoBarFrame.expacDropdown:SetShown(showExpac == true)
            if showExpac and infoBarFrame.expacText then
                local activeFilter = controller and controller.GetExpansionFilter and controller:GetExpansionFilter() or OneWoW_Bags[ef.filterKey]
                if activeFilter == nil then
                    infoBarFrame.expacText:SetText(L["EXPAC_FILTER_BTN"])
                else
                    local expName = WH and WH:GetExpansionName(activeFilter) or tostring(activeFilter)
                    infoBarFrame.expacText:SetText(expName)
                end
            end
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

    function bar:UpdateVisibility()
        if not infoBarFrame then return end

        local db = OneWoW_Bags:GetDB()
        local showHeader = GetShowHeader(db)
        local showSearch = GetShowSearch(db)
        local searchY = showHeader and -(ROW1_H + floor((ROW2_H - 22) / 2)) or -floor((ROW2_H - 22) / 2)
        local btnY = -floor((ROW1_H - 22) / 2)
        local leftInset, rightInset = GetFactoryChromeInsets()

        bar:UpdateViewButtons()

        if showHeader and infoBarFrame.viewModeDropdown then
            infoBarFrame.viewModeDropdown:ClearAllPoints()
            infoBarFrame.viewModeDropdown:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", leftInset, btnY)
        end

        if infoBarFrame.categoriesBtn and showHeader then
            infoBarFrame.categoriesBtn:ClearAllPoints()
            infoBarFrame.categoriesBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, btnY)
        end

        if infoBarFrame.cleanupBtn and showHeader then
            infoBarFrame.cleanupBtn:ClearAllPoints()
            if infoBarFrame.categoriesBtn then
                infoBarFrame.cleanupBtn:SetPoint("RIGHT", infoBarFrame.categoriesBtn, "LEFT", -4, 0)
            else
                infoBarFrame.cleanupBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, btnY)
            end
        end

        if infoBarFrame.searchBox and showSearch then
            infoBarFrame.searchBox:ClearAllPoints()
            infoBarFrame.searchBox:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", leftInset, searchY)
            infoBarFrame.searchBox:SetPoint("TOPRIGHT", infoBarFrame.emptyToggleBtn, "TOPLEFT", -3, 0)
        end

        if infoBarFrame.emptyToggleBtn and showSearch then
            infoBarFrame.emptyToggleBtn:ClearAllPoints()
            infoBarFrame.emptyToggleBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, searchY)
        end
    end

    function bar:GetSearchText()
        if infoBarFrame and infoBarFrame.searchBox then
            if infoBarFrame.searchBox.GetSearchText then
                return infoBarFrame.searchBox:GetSearchText()
            end
            return infoBarFrame.searchBox:GetText() or ""
        end
        return ""
    end

    function bar:ClearSearch()
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

    function bar:GetFrame()
        return infoBarFrame
    end

    function bar:Reset()
        if infoBarFrame then
            infoBarFrame:Hide()
            infoBarFrame:SetParent(UIParent)
        end
        infoBarFrame = nil
    end

    return bar
end
