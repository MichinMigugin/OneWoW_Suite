local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

local function GetSettings()
    return ns.QuestItemBarModule.GetSettings()
end

local LIST_SCROLL_HEIGHT = 180
local MIN_LIST_HEIGHT = 80
local ROW_HEIGHT = 28
local ROW_GAP = 2
local SCROLLBAR_WIDTH = 18
local STATUS_COL_WIDTH = 100
local ITEM_ICON_WIDTH = 28
local ITEM_ICON_AND_NAME_WIDTH = 108
local ITEM_COL_MIN_WIDTH = 108
local QUEST_COL_MIN_WIDTH = 120
local TIGHT_LAYOUT_THRESHOLD = 280

local function OpenMapWithQuest(questID)
    if not questID then return end
    C_QuestLog.SetSelectedQuest(questID)
    local openQuestDetails = QuestMapFrame_OpenToQuestDetails
    if openQuestDetails then
        openQuestDetails(questID)
    end
    local wmf = WorldMapFrame
    if wmf and not wmf:IsShown() then
        ToggleWorldMap()
    end
end

local function BuildContent(container, isEnabled, contentYOffset)
    local L = ns.L
    local s = GetSettings()
    local cy = 0

    cy = OneWoW_GUI:CreateSection(container, { title = L["QUESTITEMBAR_SETTINGS_HEADER"], yOffset = cy })

    -- Row 1: Show Bar | Lock Position | Sort: [Button]
    local previewing = ns.QuestItemBarModule:IsPreviewActive()
    local previewBtn = OneWoW_GUI:CreateFitTextButton(container, {
        text = previewing and L["QUESTITEMBAR_HIDE_BAR"] or L["QUESTITEMBAR_SHOW_BAR"],
        height = 26,
    })
    previewBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    previewBtn:SetScript("OnClick", function()
        if ns.QuestItemBarModule:IsPreviewActive() then
            ns.QuestItemBarModule:HidePreview()
        else
            ns.QuestItemBarModule:ShowPreview()
        end
        ns.QuestItemBarModule._refreshCustomDetail()
    end)

    local lockBtn = OneWoW_GUI:CreateFitTextButton(container, {
        text = s.locked and (L["QUESTITEMBAR_LOCK_BAR"] .. L["QUESTITEMBAR_LOCK_ON"]) or (L["QUESTITEMBAR_LOCK_BAR"] .. L["QUESTITEMBAR_LOCK_OFF"]),
        height = 26,
    })
    lockBtn:SetPoint("LEFT", previewBtn, "RIGHT", 8, 0)
    lockBtn:SetScript("OnClick", function()
        ns.QuestItemBarModule:SetLocked(not GetSettings().locked)
        ns.QuestItemBarModule._refreshCustomDetail()
    end)

    local sortLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sortLabel:SetPoint("LEFT", lockBtn, "RIGHT", 16, 0)
    sortLabel:SetText(L["QUESTITEMBAR_SORT"])
    sortLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local sortBtn = OneWoW_GUI:CreateFitTextButton(container, { text = ns.QuestItemBarModule:GetSortLabel(), height = 26 })
    sortBtn:SetPoint("LEFT", sortLabel, "RIGHT", 8, 0)
    sortBtn:SetScript("OnClick", function()
        local cur = GetSettings()
        local modes = ns.QuestItemBarModule.SORT_MODES
        local numModes = #modes
        local current = cur.sortMode or ns.QuestItemBarModule.defaultSortMode
        local currentIdx = 1
        for i, m in ipairs(modes) do
            if m.value == current then
                currentIdx = i
                break
            end
        end
        cur.sortMode = modes[(currentIdx % numModes) + 1].value
        ns.QuestItemBarModule:ScheduleUpdate()
        ns.QuestItemBarModule._refreshCustomDetail()
    end)

    local hideCheck = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
    hideCheck:SetPoint("LEFT", sortBtn, "RIGHT", 16, 0)
    hideCheck.Text:SetText(L["QUESTITEMBAR_HIDE_IF_EMPTY"])
    hideCheck.Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    hideCheck:SetChecked(s.hideWhenEmpty)
    hideCheck:SetScript("OnClick", function(self)
        GetSettings().hideWhenEmpty = self:GetChecked()
        ns.QuestItemBarModule:ScheduleUpdate()
    end)
    cy = cy - 36

    -- Row 2: Show only these quest items: [] Supertracked [] Current Zone [] Tracked
    local row2 = CreateFrame("Frame", nil, container)
    row2:SetPoint("TOPLEFT", container, "TOPLEFT", 8, cy)
    row2:SetPoint("TOPRIGHT", container, "TOPRIGHT", -8, cy)
    row2:SetHeight(24)

    local filterLabel = row2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("LEFT", row2, "LEFT", 0, 0)
    filterLabel:SetText(L["QUESTITEMBAR_SHOW_ONLY_THESE"])
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local superCheck = CreateFrame("CheckButton", nil, row2, "InterfaceOptionsCheckButtonTemplate")
    superCheck:SetPoint("LEFT", filterLabel, "RIGHT", 8, 0)
    superCheck:SetPoint("CENTER", row2, "CENTER", 0, 0)
    superCheck.Text:SetText(L["QUESTITEMBAR_FILTER_SUPERTRACKED"])
    superCheck.Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    superCheck:SetChecked(s.showOnlySupertracked)
    superCheck:SetScript("OnClick", function(self)
        GetSettings().showOnlySupertracked = self:GetChecked()
        ns.QuestItemBarModule:ScheduleUpdate()
        ns.QuestItemBarModule._refreshCustomDetail()
    end)
    superCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["QUESTITEMBAR_FILTER_SUPERTRACKED_TOOLTIP"])
        GameTooltip:Show()
    end)
    superCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local zoneCheck = CreateFrame("CheckButton", nil, row2, "InterfaceOptionsCheckButtonTemplate")
    zoneCheck:SetPoint("LEFT", superCheck.Text, "RIGHT", 8, 0)
    zoneCheck:SetPoint("CENTER", row2, "CENTER", 0, 0)
    zoneCheck.Text:SetText(L["QUESTITEMBAR_FILTER_CURRENT_ZONE"])
    zoneCheck.Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    zoneCheck:SetChecked(s.showOnlyCurrentZone)
    zoneCheck:SetScript("OnClick", function(self)
        GetSettings().showOnlyCurrentZone = self:GetChecked()
        ns.QuestItemBarModule:ScheduleUpdate()
        ns.QuestItemBarModule._refreshCustomDetail()
    end)

    local trackedCheck = CreateFrame("CheckButton", nil, row2, "InterfaceOptionsCheckButtonTemplate")
    trackedCheck:SetPoint("LEFT", zoneCheck.Text, "RIGHT", 8, 0)
    trackedCheck:SetPoint("CENTER", row2, "CENTER", 0, 0)
    trackedCheck.Text:SetText(L["QUESTITEMBAR_FILTER_TRACKED"])
    trackedCheck.Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    trackedCheck:SetChecked(s.showOnlyTracked)
    trackedCheck:SetScript("OnClick", function(self)
        GetSettings().showOnlyTracked = self:GetChecked()
        ns.QuestItemBarModule:ScheduleUpdate()
        ns.QuestItemBarModule._refreshCustomDetail()
    end)
    cy = cy - 34

    -- Dynamic order panel (only when sortMode == 5)
    local TIER_LABEL_KEYS = {
        supertracked = "QUESTITEMBAR_TIER_SUPERTRACKED",
        proximity    = "QUESTITEMBAR_TIER_PROXIMITY",
        zone        = "QUESTITEMBAR_TIER_ZONE",
        tracked     = "QUESTITEMBAR_TIER_TRACKED",
    }
    local DYNAMIC_ROW_HEIGHT = 24
    if s.sortMode == 5 then
        local orderLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        orderLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
        orderLabel:SetText(L["QUESTITEMBAR_DYNAMIC_ORDER"])
        orderLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        cy = cy - (orderLabel:GetStringHeight() + 4)

        local order = ns.QuestItemBarModule:GetDynamicOrder()
        for i = 1, #order do
            local key = order[i]
            local row = CreateFrame("Frame", nil, container)
            row:SetHeight(DYNAMIC_ROW_HEIGHT)
            row:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
            row:SetPoint("TOPRIGHT", container, "TOPRIGHT", -12, cy)

            local labelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            labelText:SetPoint("LEFT", row, "LEFT", 0, 0)
            labelText:SetText(L[TIER_LABEL_KEYS[key]] or key)
            labelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local canMoveUp = i > 1
            local canMoveDown = i < #order

            local upBtn = CreateFrame("Button", nil, row)
            upBtn:SetSize(18, 22)
            upBtn:SetPoint("RIGHT", row, "RIGHT", -28, 0)
            upBtn:SetNormalAtlas("common-button-collapseExpand-up")
            upBtn:SetHighlightAtlas("common-button-collapseExpand-up")
            if upBtn:GetNormalTexture() then upBtn:GetNormalTexture():SetVertexColor(1, 0.82, 0, 1) end
            if upBtn:GetHighlightTexture() then upBtn:GetHighlightTexture():SetVertexColor(1, 1, 0, 0.7) end
            if canMoveUp then upBtn:Show() else upBtn:Hide() end
            upBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["QUESTITEMBAR_MOVE_UP"])
                GameTooltip:Show()
            end)
            upBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            upBtn:SetScript("OnClick", function()
                if not canMoveUp then return end
                ns.QuestItemBarModule:SwapDynamicOrder(i, -1)
                ns.QuestItemBarModule._refreshCustomDetail()
            end)

            local downBtn = CreateFrame("Button", nil, row)
            downBtn:SetSize(18, 22)
            downBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            downBtn:SetNormalAtlas("common-button-collapseExpand-down")
            downBtn:SetHighlightAtlas("common-button-collapseExpand-down")
            if downBtn:GetNormalTexture() then downBtn:GetNormalTexture():SetVertexColor(1, 0.82, 0, 1) end
            if downBtn:GetHighlightTexture() then downBtn:GetHighlightTexture():SetVertexColor(1, 1, 0, 0.7) end
            if canMoveDown then downBtn:Show() else downBtn:Hide() end
            downBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["QUESTITEMBAR_MOVE_DOWN"])
                GameTooltip:Show()
            end)
            downBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            downBtn:SetScript("OnClick", function()
                if not canMoveDown then return end
                ns.QuestItemBarModule:SwapDynamicOrder(i, 1)
                ns.QuestItemBarModule._refreshCustomDetail()
            end)

            cy = cy - (DYNAMIC_ROW_HEIGHT + 2)
        end
        cy = cy - 8
    end

    -- Row 3: Sliders (Button Size left, Columns right)
    local sliderRowY = cy
    local sizeLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, sliderRowY)
    sizeLabel:SetText(string.format("%s: %d", L["QUESTITEMBAR_BUTTON_SIZE"], s.buttonSize or ns.QuestItemBarModule.defaultButtonSize))
    sizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local sizeSlider = CreateFrame("Slider", "OneWoW_QoL_QIBarSizeSlider", container, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, sliderRowY - sizeLabel:GetStringHeight() - 4)
    sizeSlider:SetWidth(170)
    sizeSlider:SetMinMaxValues(ns.QuestItemBarModule.MIN_BUTTON_SIZE, ns.QuestItemBarModule.MAX_BUTTON_SIZE)
    sizeSlider:SetValue(s.buttonSize or ns.QuestItemBarModule.defaultButtonSize)
    sizeSlider:SetValueStep(2)
    sizeSlider:SetObeyStepOnDrag(true)
    _G["OneWoW_QoL_QIBarSizeSliderLow"]:SetText(tostring(ns.QuestItemBarModule.MIN_BUTTON_SIZE))
    _G["OneWoW_QoL_QIBarSizeSliderHigh"]:SetText(tostring(ns.QuestItemBarModule.MAX_BUTTON_SIZE))
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        local v = math.floor(value + 0.5)
        GetSettings().buttonSize = v
        sizeLabel:SetText(string.format("%s: %d", L["QUESTITEMBAR_BUTTON_SIZE"], v))
        ns.QuestItemBarModule:ScheduleUpdate()
    end)

    local colsLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colsLabel:SetPoint("TOP", sizeLabel, "TOP")
    colsLabel:SetPoint("LEFT", sizeSlider, "RIGHT", 24, 0)
    colsLabel:SetText(string.format("%s: %d", L["QUESTITEMBAR_COLUMNS"], s.columns or ns.QuestItemBarModule.defaultColumns))
    colsLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local colsSlider = CreateFrame("Slider", "OneWoW_QoL_QIBarColsSlider", container, "OptionsSliderTemplate")
    colsSlider:SetPoint("TOP", sizeSlider, "TOP")
    colsSlider:SetPoint("LEFT", sizeSlider, "RIGHT", 24, 0)
    colsSlider:SetWidth(170)
    colsSlider:SetMinMaxValues(ns.QuestItemBarModule.MIN_COLUMNS, ns.QuestItemBarModule.MAX_COLUMNS)
    colsSlider:SetValue(s.columns or ns.QuestItemBarModule.defaultColumns)
    colsSlider:SetValueStep(1)
    colsSlider:SetObeyStepOnDrag(true)
    _G["OneWoW_QoL_QIBarColsSliderLow"]:SetText(tostring(ns.QuestItemBarModule.MIN_COLUMNS))
    _G["OneWoW_QoL_QIBarColsSliderHigh"]:SetText(tostring(ns.QuestItemBarModule.MAX_COLUMNS))
    colsSlider:SetScript("OnValueChanged", function(self, value)
        local v = math.floor(value + 0.5)
        GetSettings().columns = v
        colsLabel:SetText(string.format("%s: %d", L["QUESTITEMBAR_COLUMNS"], v))
        ns.QuestItemBarModule:ScheduleUpdate()
    end)
    cy = cy - 50

    -- Quest Item Status section
    local listSection = OneWoW_GUI:CreateSectionHeader(container, {
        title = L["QUESTITEMBAR_QUEST_ITEM_STATUS"],
        yOffset = cy,
    })
    cy = listSection.bottomY - 4

    local contentAboveHeight = math.abs(cy)
    local detailScrollFrame = container:GetParent() and container:GetParent():GetParent()
    local visibleHeight = (detailScrollFrame and detailScrollFrame.GetHeight and detailScrollFrame:GetHeight()) or 0
    local listHeight = LIST_SCROLL_HEIGHT
    if visibleHeight > 0 and contentYOffset then
        local contentTopInScroll = math.abs(contentYOffset)
        local availableForList = visibleHeight - contentTopInScroll - contentAboveHeight - 24
        listHeight = math.max(MIN_LIST_HEIGHT, availableForList)
    end

    local listScrollWrap = CreateFrame("Frame", nil, container, "BackdropTemplate")
    listScrollWrap:SetPoint("TOPLEFT", container, "TOPLEFT", 8, cy)
    listScrollWrap:SetPoint("TOPRIGHT", container, "TOPRIGHT", -8, cy)
    listScrollWrap:SetHeight(listHeight)
    listScrollWrap:SetBackdrop(BACKDROP_SIMPLE)
    listScrollWrap:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))

    local colHeader = CreateFrame("Frame", nil, listScrollWrap, "BackdropTemplate")
    colHeader:SetPoint("TOPLEFT", listScrollWrap, "TOPLEFT", 4, -4)
    colHeader:SetPoint("TOPRIGHT", listScrollWrap, "TOPRIGHT", -(4 + SCROLLBAR_WIDTH), -4)
    colHeader:SetHeight(18)
    colHeader:SetBackdrop(BACKDROP_SIMPLE)
    colHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    -- Compute layout before headers so Item column aligns with rows
    local containerWidth = container:GetWidth()
    if not containerWidth or containerWidth <= 0 then
        local parent = container:GetParent()
        containerWidth = parent and parent:GetWidth() or 0
    end
    local listWidth = math.max(0, (containerWidth or 0) - 16)
    local useTightLayout = listWidth < TIGHT_LAYOUT_THRESHOLD
    container._qibUsedTightLayout = useTightLayout
    -- Split flexible space 50/50 between Quest and Item so both benefit from wider windows
    local rowWidth = listWidth - 8 - SCROLLBAR_WIDTH
    local availableForQuestAndItem = rowWidth - 16 - STATUS_COL_WIDTH - 8
    local reserved = QUEST_COL_MIN_WIDTH + ITEM_COL_MIN_WIDTH + 8
    local extra = math.max(0, availableForQuestAndItem - reserved)
    local itemColWidth = useTightLayout and ITEM_ICON_WIDTH
        or (ITEM_COL_MIN_WIDTH + math.floor(extra * 0.5))

    local hdrQuest = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrQuest:SetPoint("LEFT", colHeader, "LEFT", 8, 0)
    hdrQuest:SetText(L["QUESTITEMBAR_DEBUG_COL_QUEST"])
    hdrQuest:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local hdrItem = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrItem:SetPoint("LEFT", colHeader, "RIGHT", -(STATUS_COL_WIDTH + itemColWidth + 8), 0)
    hdrItem:SetText(L["QUESTITEMBAR_DEBUG_COL_ITEM"])
    hdrItem:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local hdrStatus = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrStatus:SetPoint("RIGHT", colHeader, "RIGHT", -8, 0)
    hdrStatus:SetText(L["QUESTITEMBAR_DEBUG_COL_STATUS"])
    hdrStatus:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    hdrStatus:SetJustifyH("RIGHT")

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(listScrollWrap, {})
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", colHeader, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", listScrollWrap, "BOTTOMRIGHT", -(4 + SCROLLBAR_WIDTH), 4)

    local entries = ns.QuestItemBarModule.BuildQuestItemDebugList()
    local rowY = -2
    for _, entry in ipairs(entries) do
        local row = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, rowY)
        row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, rowY)
        row:SetBackdrop(BACKDROP_SIMPLE)
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        row:EnableMouse(true)

        local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        statusText:SetJustifyH("RIGHT")
        statusText:SetText(L[entry.status] or entry.status)
        if entry.included then
            statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end

        -- Item column (empty if no item; icon-only when space tight)
        local itemCol = CreateFrame("Frame", nil, row)
        itemCol:SetHeight(ROW_HEIGHT - 4)
        itemCol:SetPoint("RIGHT", row, "RIGHT", -(STATUS_COL_WIDTH + 8), 0)
        itemCol:SetPoint("LEFT", row, "RIGHT", -(STATUS_COL_WIDTH + 8 + itemColWidth), 0)

        if entry.itemID and (entry.link or entry.tex) then
            local iconResult = OneWoW_GUI:CreateItemIcon(itemCol, {
                size = 24,
                itemLink = entry.link,
                itemID = entry.itemID,
                quality = entry.quality,
                iconTexture = entry.tex,
                showIlvl = false,
            })
            iconResult.frame:SetPoint("LEFT", itemCol, "LEFT", 0, 0)
            if not useTightLayout then
                local nameText = itemCol:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                nameText:SetPoint("LEFT", iconResult.frame, "RIGHT", 6, 0)
                nameText:SetPoint("RIGHT", itemCol, "RIGHT", -4, 0)
                nameText:SetJustifyH("LEFT")
                nameText:SetWordWrap(false)
                nameText:SetText(entry.name or "")
                nameText:SetTextColor(OneWoW_GUI:GetItemQualityColor(entry.quality))
            end
            itemCol:EnableMouse(true)
            itemCol:SetScript("OnEnter", function(self)
                row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                local link = entry.link or (entry.itemID and C_Item.GetItemLinkByID(entry.itemID))
                if link then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(link)
                    GameTooltip:Show()
                end
            end)
            itemCol:SetScript("OnLeave", function(self)
                row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                GameTooltip:Hide()
            end)
        end

        -- Quest column (clickable, flexible - takes remaining space)
        local questBtn = CreateFrame("Button", nil, row)
        questBtn:SetHeight(ROW_HEIGHT - 4)
        questBtn:SetPoint("LEFT", row, "LEFT", 4, 0)
        questBtn:SetPoint("RIGHT", itemCol, "LEFT", -4, 0)
        local questText = questBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        questText:SetPoint("LEFT", questBtn, "LEFT", 0, 0)
        questText:SetPoint("RIGHT", questBtn, "RIGHT", -4, 0)
        questText:SetJustifyH("LEFT")
        questText:SetWordWrap(false)
        questText:SetText(entry.questTitle or L["QUESTITEMBAR_UNKNOWN_QUEST"])
        questText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        questBtn:SetScript("OnClick", function()
            if entry.questID then
                OpenMapWithQuest(entry.questID)
            end
        end)
        questBtn:SetScript("OnEnter", function(self)
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            questText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_HOVER"))
            if entry.questID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["QUESTITEMBAR_DEBUG_CLICK_QUEST"])
                GameTooltip:Show()
            end
        end)
        questBtn:SetScript("OnLeave", function(self)
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
            questText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            GameTooltip:Hide()
        end)

        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
            GameTooltip:Hide()
        end)

        rowY = rowY - (ROW_HEIGHT + ROW_GAP)
    end

    local contentHeight = math.max(1, math.abs(rowY) + 8)
    scrollContent:SetHeight(contentHeight)

    cy = cy - listHeight - 8

    container:SetHeight(math.abs(cy))
    return cy
end

function ns.QuestItemBarModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled)
    self._detailScrollChild = detailScrollChild
    if detailScrollChild._qibContainer then
        OneWoW_GUI:ClearFrame(detailScrollChild._qibContainer)
    end

    local container = detailScrollChild._qibContainer or CreateFrame("Frame", nil, detailScrollChild)
    detailScrollChild._qibContainer = container
    container:SetParent(detailScrollChild)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
    container:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)
    container:Show()

    local capturedYOffset = yOffset

    local function doRefresh()
        if container:GetParent() ~= detailScrollChild then return end
        OneWoW_GUI:ClearFrame(container)
        local cy = BuildContent(container, isEnabled, capturedYOffset)
        detailScrollChild:SetHeight(math.abs(capturedYOffset) + math.abs(cy) + 20)
    end

    self._refreshCustomDetail = function()
        doRefresh()
        -- Deferred check: width may be 0 at build time; rebuild after layout if we used tight layout
        -- Skip deferred when we had sufficient width at build time (avoids unnecessary refresh)
        if container._qibUsedTightLayout then
            C_Timer.After(0, function()
                if container:GetParent() ~= detailScrollChild then return end
                local w = (container:GetWidth() or 0) - 16
                if w >= TIGHT_LAYOUT_THRESHOLD and ns.QuestItemBarModule._refreshCustomDetail then
                    ns.QuestItemBarModule._refreshCustomDetail()
                end
            end)
        end
    end

    local detailScrollFrame = detailScrollChild:GetParent()
    local detailContainer = detailScrollFrame and detailScrollFrame:GetParent()
    local detailPanel = detailContainer and detailContainer:GetParent()
    if detailScrollFrame and not detailScrollChild._qibResizeHooked then
        detailScrollChild._qibResizeHooked = true
        local function onResize()
            if container:GetParent() == detailScrollChild and ns.QuestItemBarModule._refreshCustomDetail then
                ns.QuestItemBarModule._refreshCustomDetail()
            end
        end
        detailScrollFrame:HookScript("OnSizeChanged", onResize)
        if detailPanel and detailPanel ~= detailScrollFrame then
            detailPanel:HookScript("OnSizeChanged", onResize)
        end
    end

    local cy = BuildContent(container, isEnabled, capturedYOffset)

    return yOffset + cy
end
