local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local PE = OneWoW_Bags.PredicateEngine

local floor = math.floor
local ipairs, pairs = ipairs, pairs
local tinsert, sort = tinsert, sort

OneWoW_Bags.InfoBarFactory = {}

function OneWoW_Bags.InfoBarFactory:Create(config)
    local bar = {}
    local infoBarFrame = nil

    local ROW1_H = 28
    local ROW2_H = 28

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

        local prevBtn = nil
        infoBarFrame._viewButtons = {}
        for i, vm in ipairs(config.viewModes) do
            local btn = bar:CreateViewBtn(infoBarFrame, L[vm.labelKey] or vm.labelKey)
            if i == 1 then
                btn:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", OneWoW_GUI:GetSpacing("SM"), btnY)
            else
                btn:SetPoint("TOPLEFT", prevBtn, "TOPRIGHT", 3, 0)
            end
            btn:SetScript("OnClick", function()
                local controller = GetController()
                if config.onViewModeChanged then
                    config.onViewModeChanged(vm.mode, controller)
                elseif controller and controller.SetViewMode then
                    controller:SetViewMode(vm.mode)
                end
                bar:UpdateViewButtons()
            end)
            infoBarFrame._viewButtons[i] = { btn = btn, mode = vm.mode }
            infoBarFrame["view_" .. vm.mode] = btn
            prevBtn = btn
        end

        if config.expacFilter then
            local ef = config.expacFilter
            local expacDropdown, expacText = OneWoW_GUI:CreateDropdown(infoBarFrame, {
                width = 130, height = 22, text = L["EXPAC_FILTER_BTN"],
            })
            expacDropdown:SetPoint("TOPLEFT", prevBtn, "TOPRIGHT", 8, 0)
            OneWoW_GUI:AttachFilterMenu(expacDropdown, {
                searchable = false,
                buildItems = function()
                    local BagSet = OneWoW_Bags[ef.bagSetKey]
                    local items = { { text = L["EXPAC_FILTER_ALL"], value = "ALL" } }
                    if not BagSet or not BagSet.isBuilt then return items end
                    local found = {}
                    for _, btn in ipairs(BagSet:GetAllButtons()) do
                        if btn.owb_hasItem and btn.owb_itemInfo and btn.owb_itemInfo.itemID then
                            local props = PE:BuildProps(btn.owb_itemInfo.itemID, btn.owb_bagID, btn.owb_slotID, btn.owb_itemInfo)
                            if props.expansionID ~= nil then
                                found[props.expansionID] = true
                            end
                        end
                    end
                    local ids = {}
                    for id in pairs(found) do tinsert(ids, id) end
                    sort(ids)
                    for _, id in ipairs(ids) do
                        tinsert(items, { text = PE:GetExpansionName(id) or ("Expansion " .. id), value = id })
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

        if config.cleanupCallback then
            local cleanupBtn = bar:CreateViewBtn(infoBarFrame, L["CLEANUP"] or "Cleanup")
            cleanupBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -OneWoW_GUI:GetSpacing("SM"), btnY)
            cleanupBtn:SetScript("OnClick", function()
                config.cleanupCallback(GetController())
            end)
            infoBarFrame.cleanupBtn = cleanupBtn
        end

        local emptyToggleBtn = CreateFrame("Button", nil, infoBarFrame)
        emptyToggleBtn:SetSize(22, 22)
        emptyToggleBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -OneWoW_GUI:GetSpacing("SM"), searchY)
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
        searchBox:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", OneWoW_GUI:GetSpacing("SM"), searchY)
        searchBox:SetPoint("TOPRIGHT", emptyToggleBtn, "TOPLEFT", -3, 0)
        infoBarFrame.searchBox = searchBox

        bar:UpdateViewButtons()
        return infoBarFrame
    end

    function bar:UpdateViewButtons()
        if not infoBarFrame then return end
        local db = OneWoW_Bags:GetDB()
        local controller = GetController()
        local mode = controller and controller.GetViewMode and controller:GetViewMode() or db.global[config.viewModeDBKey] or config.viewModes[1].mode

        for _, entry in ipairs(infoBarFrame._viewButtons) do
            local btn = entry.btn
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

        if infoBarFrame.emptyToggleBtn then
            local showing = controller and controller.GetShowEmptySlots and controller:GetShowEmptySlots() or true
            infoBarFrame.emptyToggleBtn:SetAlpha(showing and 1.0 or 0.35)
            infoBarFrame.emptyToggleBtn:SetShown(mode == "list" or mode == "tab")
        end

        if config.expacFilter and infoBarFrame.expacDropdown then
            local ef = config.expacFilter
            local showExpac = db.global[ef.settingKey] == true
            infoBarFrame.expacDropdown:SetShown(showExpac == true)
            if showExpac and infoBarFrame.expacText then
                local activeFilter = controller and controller.GetExpansionFilter and controller:GetExpansionFilter() or OneWoW_Bags[ef.filterKey]
                if activeFilter == nil then
                    infoBarFrame.expacText:SetText(OneWoW_Bags.L["EXPAC_FILTER_BTN"])
                else
                    local expName = PE:GetExpansionName(activeFilter) or tostring(activeFilter)
                    infoBarFrame.expacText:SetText(expName)
                end
            end
        end
    end

    function bar:UpdateVisibility()
        bar:UpdateViewButtons()
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
