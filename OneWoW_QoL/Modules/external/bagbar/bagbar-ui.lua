local _, ns = ...
local BagBarModule, L = ns.ModuleRegistry:Current()

local OneWoW_GUI = OneWoW_GUI

-- Session-only collapse memory (survives tab switches; cleared on /reload)
local collapsedCards = {}

local function GetSettings()
    return BagBarModule.GetSettings()
end

local function ItemTableEntries(itemTable)
    local entries = {}
    for itemID in pairs(itemTable) do
        C_Item.RequestLoadItemDataByID(itemID)
        local itemName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
        local _, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
        tinsert(entries, { id = itemID, label = itemName, icon = icon })
    end
    return entries
end

local function MacroTableEntries(macroTable)
    local names = {}
    for name in pairs(macroTable) do
        tinsert(names, name)
    end
    sort(names)
    local entries = {}
    for _, macroName in ipairs(names) do
        local mName, mIcon = GetMacroInfo(macroName)
        if mName then
            tinsert(entries, { id = macroName, label = mName, icon = mIcon })
        else
            tinsert(entries, {
                id = macroName,
                label = macroName .. " " .. L["BAGBAR_MACRO_MISSING"],
                icon = mIcon,
            })
        end
    end
    return entries
end

-- Card content width may still be 0 when builders run; GetStringHeight then
-- under-reports wrapped intros and absolute yOffset stacks overlap the text.
-- SetWidth(contentWidth) for measure; prefer relative anchors for layout.
local function AddCardIntro(content, contentWidth, text)
    local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetSpacing(2)
    local w = tonumber(contentWidth) or 0
    if w < 1 then
        w = content:GetWidth() or 0
    end
    if w >= 1 then
        fs:SetWidth(w)
    else
        fs:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    end
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    return fs
end

---@param container Frame
---@param onRelayout fun()|nil
local function BuildContent(container, onRelayout)
    local s = GetSettings()
    local uiEnabled = ns.ModuleRegistry:IsEnabled("bagbar")

    local stack = OneWoW_GUI:CreateCardStack(container, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })
    -- Relayout already sets container height; notify host so scroll chrome tracks collapse.
    stack.OnRelayout = function()
        if onRelayout then
            onRelayout()
        end
    end

    stack:AddCard("bagbar:settings", L["BAR_SETTINGS"], function(content, _)
        local y = 0

        local previewing = BagBarModule:IsPreviewActive()
        local previewBtn = OneWoW_GUI:CreateFitTextButton(content, {
            text = previewing and L["HIDE_BAR"] or L["SHOW_BAR"],
            height = 26,
        })
        previewBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        previewBtn:SetScript("OnClick", function()
            if BagBarModule:IsPreviewActive() then
                BagBarModule:HidePreview()
            else
                BagBarModule:ShowPreview()
            end
            BagBarModule._refreshCustomDetail()
        end)

        local lockBtn = OneWoW_GUI:CreateFitTextButton(content, {
            text = s.locked and (L["BAGBAR_LOCK_POSITION"] .. " (ON)") or (L["BAGBAR_LOCK_POSITION"] .. " (OFF)"),
            height = 26,
        })
        lockBtn:SetPoint("TOPLEFT", previewBtn, "TOPRIGHT", 12, 0)
        lockBtn:SetScript("OnClick", function()
            BagBarModule:SetLocked(not GetSettings().locked)
            BagBarModule._refreshCustomDetail()
        end)
        y = y - 32 - 12

        local GROW_DIRS = { "RIGHT", "LEFT", "DOWN", "UP" }
        local growDirLabels = {
            RIGHT = L["BAGBAR_GROW_RIGHT"],
            LEFT  = L["BAGBAR_GROW_LEFT"],
            DOWN  = L["DOWN"],
            UP    = L["UP"],
        }
        local curDir = s.growDirection or "RIGHT"

        local growDirLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        growDirLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        growDirLabel:SetText(L["GROW_DIRECTION"] .. ":")
        growDirLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local growDirDropdown = OneWoW_GUI:CreateDropdown(content, {
            text   = growDirLabels[curDir] or curDir,
            width  = 120,
            height = 26,
        })
        growDirDropdown:SetPoint("LEFT", growDirLabel, "RIGHT", 8, 0)
        growDirDropdown._activeValue = curDir
        OneWoW_GUI:AttachFilterMenu(growDirDropdown, {
            searchable = false,
            menuHeight = 140,
            buildItems = function()
                local items = {}
                for _, d in ipairs(GROW_DIRS) do
                    tinsert(items, { text = growDirLabels[d] or d, value = d })
                end
                return items
            end,
            getActiveValue = function()
                return GetSettings().growDirection or "RIGHT"
            end,
            onSelect = function(value, text)
                GetSettings().growDirection = value
                growDirDropdown._text:SetText(text)
                BagBarModule:ScheduleUpdate()
            end,
        })

        local hideAnchorCheck = OneWoW_GUI:CreateCheckbox(content, {
            label   = L["HIDE_ANCHOR_SHOW_ON_HOVER"],
            checked = s.hideAnchor,
            onClick = function(self)
                GetSettings().hideAnchor = self:GetChecked()
                BagBarModule:ScheduleUpdate()
            end,
        })
        hideAnchorCheck:SetPoint("LEFT", growDirDropdown, "RIGHT", 20, 0)
        hideAnchorCheck:SetPoint("TOP", growDirDropdown, "TOP", 0, 0)
        y = y - 32

        local SLIDER_PAIR_GAP = 24
        local SLIDER_WIDTH = 170

        local maxLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        maxLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        maxLabel:SetText(string.format("%s: %d", L["BAGBAR_MAX_BUTTONS"], math.min(s.maxButtons or 12, 24)))
        maxLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        y = y - maxLabel:GetStringHeight() - 4

        local maxSlider = CreateFrame("Slider", "OneWoW_QoL_BagBarMaxSlider", content, "OptionsSliderTemplate")
        maxSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        maxSlider:SetWidth(SLIDER_WIDTH)
        maxSlider:SetMinMaxValues(1, 24)
        maxSlider:SetValue(math.min(s.maxButtons or 12, 24))
        maxSlider:SetValueStep(1)
        maxSlider:SetObeyStepOnDrag(true)
        OneWoW_GUI:ConfigureOptionsSliderEnds(maxSlider, "1", "24")
        maxSlider:SetScript("OnValueChanged", function(_, value)
            local v = math.min(math.floor(value + 0.5), 24)
            GetSettings().maxButtons = v
            maxLabel:SetText(string.format("%s: %d", L["BAGBAR_MAX_BUTTONS"], v))
            BagBarModule:ScheduleUpdate()
        end)

        local colsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colsLabel:SetPoint("TOP", maxLabel, "TOP")
        colsLabel:SetPoint("LEFT", maxSlider, "RIGHT", SLIDER_PAIR_GAP, 0)
        colsLabel:SetText(string.format("%s: %d", L["BAGBAR_COLUMNS"], math.min(s.columns or 12, 24)))
        colsLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local colsSlider = CreateFrame("Slider", "OneWoW_QoL_BagBarColsSlider", content, "OptionsSliderTemplate")
        colsSlider:SetPoint("TOP", maxSlider, "TOP")
        colsSlider:SetPoint("LEFT", maxSlider, "RIGHT", SLIDER_PAIR_GAP, 0)
        colsSlider:SetWidth(SLIDER_WIDTH)
        colsSlider:SetMinMaxValues(1, 24)
        colsSlider:SetValue(math.min(s.columns or 12, 24))
        colsSlider:SetValueStep(1)
        colsSlider:SetObeyStepOnDrag(true)
        OneWoW_GUI:ConfigureOptionsSliderEnds(colsSlider, "1", "24")
        colsSlider:SetScript("OnValueChanged", function(_, value)
            local v = math.min(math.floor(value + 0.5), 24)
            GetSettings().columns = v
            colsLabel:SetText(string.format("%s: %d", L["BAGBAR_COLUMNS"], v))
            BagBarModule:ScheduleUpdate()
        end)
        y = y - 46

        local sliderRowY = y
        local sizeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sizeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, sliderRowY)
        sizeLabel:SetText(string.format("%s: %d", L["BUTTON_SIZE"], s.buttonSize or 36))
        sizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local sizeSlider = CreateFrame("Slider", "OneWoW_QoL_BagBarSizeSlider", content, "OptionsSliderTemplate")
        sizeSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 12, sliderRowY - sizeLabel:GetStringHeight() - 4)
        sizeSlider:SetWidth(SLIDER_WIDTH)
        sizeSlider:SetMinMaxValues(24, 48)
        sizeSlider:SetValue(s.buttonSize or 36)
        sizeSlider:SetValueStep(2)
        sizeSlider:SetObeyStepOnDrag(true)
        OneWoW_GUI:ConfigureOptionsSliderEnds(sizeSlider, "24", "48")
        sizeSlider:SetScript("OnValueChanged", function(_, value)
            local v = math.floor(value + 0.5)
            GetSettings().buttonSize = v
            sizeLabel:SetText(string.format("%s: %d", L["BUTTON_SIZE"], v))
            BagBarModule:ScheduleUpdate()
        end)

        local spacingLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        spacingLabel:SetPoint("TOP", sizeLabel, "TOP")
        spacingLabel:SetPoint("LEFT", sizeSlider, "RIGHT", SLIDER_PAIR_GAP, 0)
        spacingLabel:SetText(string.format("%s: %d", L["ICON_SPACING"], s.iconSpacing or 4))
        spacingLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local spacingSlider = CreateFrame("Slider", "OneWoW_QoL_BagBarSpacingSlider", content, "OptionsSliderTemplate")
        spacingSlider:SetPoint("TOP", sizeSlider, "TOP")
        spacingSlider:SetPoint("LEFT", sizeSlider, "RIGHT", SLIDER_PAIR_GAP, 0)
        spacingSlider:SetWidth(SLIDER_WIDTH)
        spacingSlider:SetMinMaxValues(0, 12)
        spacingSlider:SetValue(s.iconSpacing or 4)
        spacingSlider:SetValueStep(1)
        spacingSlider:SetObeyStepOnDrag(true)
        OneWoW_GUI:ConfigureOptionsSliderEnds(spacingSlider, "0", "12")
        spacingSlider:SetScript("OnValueChanged", function(_, value)
            local v = math.floor(value + 0.5)
            GetSettings().iconSpacing = v
            spacingLabel:SetText(string.format("%s: %d", L["ICON_SPACING"], v))
            BagBarModule:ScheduleUpdate()
        end)
        y = y - 50

        if not uiEnabled then
            previewBtn:Disable()
            lockBtn:Disable()
            hideAnchorCheck:Disable()
            growDirDropdown:Disable()
            maxSlider:Disable()
            sizeSlider:Disable()
            colsSlider:Disable()
            spacingSlider:Disable()
        end

        return math.max(1, math.abs(y))
    end)

    stack:AddCard("bagbar:expression", L["BAGBAR_EXPRESSION_FILTER_HEADER"], function(content, contentWidth)
        local exprDescToBoxGap = 14
        local exprDesc = AddCardIntro(content, contentWidth, L["BAGBAR_EXPRESSION_FILTER_DESC"])

        local exprBox = OneWoW_GUI:CreateEditBox(content, {
            height = 24,
            placeholderText = L["BAGBAR_EXPRESSION_FILTER_PLACEHOLDER"],
            onTextChanged = function(text)
                local cur = GetSettings()
                cur.expressionFilter = text or ""
                BagBarModule:ScheduleUpdate()
            end,
        })
        exprBox:SetPoint("TOPLEFT", exprDesc, "BOTTOMLEFT", 0, -exprDescToBoxGap)
        exprBox:SetPoint("TOPRIGHT", exprDesc, "BOTTOMRIGHT", -30, -exprDescToBoxGap)

        local exprHelpBtn
        if OneWoW_GUI.CreateKeywordHelpButton then
            exprHelpBtn = OneWoW_GUI:CreateKeywordHelpButton(content, { editBox = exprBox })
            exprHelpBtn:SetPoint("LEFT", exprBox, "RIGHT", 4, 0)
        end

        OneWoW_GUI:AttachSearchTooltip(exprBox)

        exprBox:SetText(s.expressionFilter or "")
        exprBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        if not uiEnabled then
            exprBox:Disable()
            if exprHelpBtn then exprHelpBtn:Disable() end
        end

        return math.max(1, (exprDesc:GetStringHeight() or 14) + exprDescToBoxGap + exprBox:GetHeight() + 16)
    end)

    stack:AddCard("bagbar:manual", L["BAGBAR_MANUAL_ITEMS_HEADER"], function(content, contentWidth)
        local gap = 8
        local manualIntro = AddCardIntro(content, contentWidth, L["BAGBAR_MANUAL_DESC"])

        local manualAdd = OneWoW_GUI:CreateValueAddRow(content, {
            x = 0,
            rightInset = 0,
            label = L["ITEM_ID"],
            addText = ADD,
            input = { kind = "itemId" },
            drop = { mode = "chip", text = L["DRAG_ITEM_HERE"] },
            onAdd = function(itemID)
                local cur = GetSettings()
                cur.manualItems[itemID] = true
                C_Item.RequestLoadItemDataByID(itemID)
                BagBarModule:ScheduleUpdate()
                C_Timer.After(0, function()
                    if BagBarModule._refreshCustomDetail then
                        BagBarModule._refreshCustomDetail()
                    end
                end)
                C_Timer.After(0.5, function()
                    if BagBarModule._refreshCustomDetail then
                        BagBarModule._refreshCustomDetail()
                    end
                end)
            end,
        })
        manualAdd.frame:SetPoint("TOPLEFT", manualIntro, "BOTTOMLEFT", 0, -gap)
        manualAdd.frame:SetPoint("TOPRIGHT", manualIntro, "BOTTOMRIGHT", 0, -gap)

        local manualList = OneWoW_GUI:CreateEntryList(content, {
            x = 0,
            rightInset = 0,
            grow = true,
            emptyText = L["NO_ITEMS"],
            sortKey = "bagbar:manual",
            getEntries = function()
                return ItemTableEntries(GetSettings().manualItems)
            end,
            onRemove = function(itemID)
                GetSettings().manualItems[itemID] = nil
                BagBarModule:ScheduleUpdate()
                C_Timer.After(0, function()
                    if BagBarModule._refreshCustomDetail then
                        BagBarModule._refreshCustomDetail()
                    end
                end)
            end,
        })
        manualList.frame:SetPoint("TOPLEFT", manualAdd.frame, "BOTTOMLEFT", 0, -gap)
        manualList.frame:SetPoint("TOPRIGHT", manualAdd.frame, "BOTTOMRIGHT", 0, -gap)

        if not uiEnabled then
            manualAdd:SetEnabled(false)
            manualList:SetEnabled(false)
        end

        return math.max(1,
            (manualIntro:GetStringHeight() or 14) + gap
            + manualAdd:GetHeight() + gap
            + manualList:GetHeight() + gap)
    end)

    stack:AddCard("bagbar:macros", L["BAGBAR_MACROS_HEADER"], function(content, contentWidth)
        local gap = 8
        local macroIntro = AddCardIntro(content, contentWidth, L["BAGBAR_MACROS_DESC"])

        local macroAdd = OneWoW_GUI:CreateValueAddRow(content, {
            x = 0,
            rightInset = 0,
            label = L["BAGBAR_MACRO_NAME_LABEL"],
            addText = ADD,
            input = { kind = "text", width = 120, maxLetters = 64 },
            drop = {
                mode = "chip",
                text = L["BAGBAR_DRAG_MACRO_HERE"],
                width = 120,
                cursorTypes = { "macro" },
            },
            onAdd = function(macroName)
                if GetMacroIndexByName(macroName) <= 0 then
                    return false
                end
                local mName = GetMacroInfo(macroName)
                if not mName then
                    return false
                end
                local cur = GetSettings()
                cur.manualMacros[mName] = true
                BagBarModule:ScheduleUpdate()
                C_Timer.After(0, function()
                    if BagBarModule._refreshCustomDetail then
                        BagBarModule._refreshCustomDetail()
                    end
                end)
                C_Timer.After(0.2, function()
                    if BagBarModule._refreshCustomDetail then
                        BagBarModule._refreshCustomDetail()
                    end
                end)
            end,
        })
        macroAdd.frame:SetPoint("TOPLEFT", macroIntro, "BOTTOMLEFT", 0, -gap)
        macroAdd.frame:SetPoint("TOPRIGHT", macroIntro, "BOTTOMRIGHT", 0, -gap)

        local macroList = OneWoW_GUI:CreateEntryList(content, {
            x = 0,
            rightInset = 0,
            grow = true,
            emptyText = L["NO_MACROS"],
            getEntries = function()
                return MacroTableEntries(GetSettings().manualMacros)
            end,
            onRemove = function(macroName)
                GetSettings().manualMacros[macroName] = nil
                BagBarModule:ScheduleUpdate()
                C_Timer.After(0, function()
                    if BagBarModule._refreshCustomDetail then
                        BagBarModule._refreshCustomDetail()
                    end
                end)
            end,
        })
        macroList.frame:SetPoint("TOPLEFT", macroAdd.frame, "BOTTOMLEFT", 0, -gap)
        macroList.frame:SetPoint("TOPRIGHT", macroAdd.frame, "BOTTOMRIGHT", 0, -gap)

        if not uiEnabled then
            macroAdd:SetEnabled(false)
            macroList:SetEnabled(false)
        end

        return math.max(1,
            (macroIntro:GetStringHeight() or 14) + gap
            + macroAdd:GetHeight() + gap
            + macroList:GetHeight() + gap)
    end)

    stack:AddCard("bagbar:blacklist", L["BLACKLIST"], function(content, contentWidth)
        local gap = 8
        local blDesc = AddCardIntro(content, contentWidth, L["BAGBAR_BLACKLIST_DESC"])

        local blAdd = OneWoW_GUI:CreateValueAddRow(content, {
            x = 0,
            rightInset = 0,
            label = L["ITEM_ID"],
            addText = ADD,
            input = { kind = "itemId" },
            drop = { mode = "chip", text = L["DRAG_ITEM_HERE"] },
            onAdd = function(itemID)
                local cur = GetSettings()
                cur.blacklist[itemID] = true
                C_Item.RequestLoadItemDataByID(itemID)
                BagBarModule:ScheduleUpdate()
                C_Timer.After(0, function()
                    if BagBarModule._refreshCustomDetail then
                        BagBarModule._refreshCustomDetail()
                    end
                end)
                C_Timer.After(0.5, function()
                    if BagBarModule._refreshCustomDetail then
                        BagBarModule._refreshCustomDetail()
                    end
                end)
            end,
        })
        blAdd.frame:SetPoint("TOPLEFT", blDesc, "BOTTOMLEFT", 0, -gap)
        blAdd.frame:SetPoint("TOPRIGHT", blDesc, "BOTTOMRIGHT", 0, -gap)

        local blList = OneWoW_GUI:CreateEntryList(content, {
            x = 0,
            rightInset = 0,
            grow = true,
            emptyText = L["NO_ITEMS"],
            sortKey = "bagbar:blacklist",
            getEntries = function()
                return ItemTableEntries(GetSettings().blacklist)
            end,
            onRemove = function(itemID)
                GetSettings().blacklist[itemID] = nil
                BagBarModule:ScheduleUpdate()
                C_Timer.After(0, function()
                    if BagBarModule._refreshCustomDetail then
                        BagBarModule._refreshCustomDetail()
                    end
                end)
            end,
        })
        blList.frame:SetPoint("TOPLEFT", blAdd.frame, "BOTTOMLEFT", 0, -gap)
        blList.frame:SetPoint("TOPRIGHT", blAdd.frame, "BOTTOMRIGHT", 0, -gap)

        if not uiEnabled then
            blAdd:SetEnabled(false)
            blList:SetEnabled(false)
        end

        return math.max(1,
            (blDesc:GetStringHeight() or 14) + gap
            + blAdd:GetHeight() + gap
            + blList:GetHeight() + gap)
    end)

    stack:Finish()
    return -container:GetHeight()
end

function BagBarModule:CreateCustomDetail(detailScrollChild, yOffset, _, registerRefresh)
    if detailScrollChild._bagbarContainer then
        OneWoW_GUI:ClearFrame(detailScrollChild._bagbarContainer)
    end

    local container = detailScrollChild._bagbarContainer or CreateFrame("Frame", nil, detailScrollChild)
    detailScrollChild._bagbarContainer = container
    container:SetParent(detailScrollChild)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
    container:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)
    container:Show()

    local capturedYOffset = yOffset

    local function applyHostHeight(cy)
        cy = cy or -container:GetHeight()
        detailScrollChild:SetHeight(math.abs(capturedYOffset) + math.abs(cy) + 20)
        if detailScrollChild.updateThumb then
            detailScrollChild.updateThumb()
        end
    end

    self._refreshCustomDetail = function()
        OneWoW_GUI:ClearFrame(container)
        local cy = BuildContent(container, applyHostHeight)
        applyHostHeight(cy)
    end

    if registerRefresh then
        registerRefresh(function()
            if self._refreshCustomDetail then
                self._refreshCustomDetail()
            end
        end)
    end

    local cy = BuildContent(container, applyHostHeight)

    return yOffset + cy
end
