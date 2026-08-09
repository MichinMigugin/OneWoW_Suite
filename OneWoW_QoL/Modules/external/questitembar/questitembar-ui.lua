local _, ns = ...

local QuestItemBarModule, L = ns.ModuleRegistry:Current()
local OneWoW_GUI = OneWoW_GUI

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

-- Session-only collapse memory (survives tab switches; cleared on /reload)
local collapsedCards = {}

local function GetSettings()
    return QuestItemBarModule.GetSettings()
end

local LIST_SCROLL_HEIGHT = 180
local MIN_LIST_HEIGHT = 80
local ROW_HEIGHT = 28
local ROW_GAP = 2
local SCROLLBAR_GUTTER = OneWoW_GUI.Constants.GUI.SCROLLBAR_CONTENT_GUTTER
local STATUS_COL_WIDTH = 100
local ITEM_ICON_WIDTH = 28
local ITEM_COL_MIN_WIDTH = 108
local QUEST_COL_MIN_WIDTH = 120
local TIGHT_LAYOUT_THRESHOLD = 280

-- Match OneWoW_GUI CreateCard / CreateCardStack chrome (Cards.lua)
local CARD_HEADER_H = 24
local CARD_PAD_TOP = 8
local CARD_PAD_BOTTOM = 10
local CARD_CHROME = CARD_HEADER_H + CARD_PAD_TOP + CARD_PAD_BOTTOM
local STACK_START_ABS = 6
local STACK_GAP = 8
local STACK_BOTTOM_PAD = 10
local STACK_MARGIN_X = 4
local CARD_CONTENT_INSET = 22

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

local function BuildContent(container, onRelayout, contentYOffset)
    local s = GetSettings()

    local stack = OneWoW_GUI:CreateCardStack(container, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })
    stack.OnRelayout = function()
        if onRelayout then
            onRelayout()
        end
    end

    stack:AddCard("qib:settings", L["BAR_SETTINGS"], function(content, contentWidth)
        local y = 0

        -- Row 1: Show Bar | Lock Position | Sort: [Button]
        local previewing = QuestItemBarModule:IsPreviewActive()
        local previewBtn = OneWoW_GUI:CreateFitTextButton(content, {
            text = previewing and L["HIDE_BAR"] or L["SHOW_BAR"],
            height = 26,
        })
        previewBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        previewBtn:SetScript("OnClick", function()
            if QuestItemBarModule:IsPreviewActive() then
                QuestItemBarModule:HidePreview()
            else
                QuestItemBarModule:ShowPreview()
            end
            QuestItemBarModule._refreshCustomDetail()
        end)

        local lockBtn = OneWoW_GUI:CreateFitTextButton(content, {
            text = s.locked and (L["QUESTITEMBAR_LOCK_BAR"] .. L["QUESTITEMBAR_LOCK_ON"]) or (L["QUESTITEMBAR_LOCK_BAR"] .. L["QUESTITEMBAR_LOCK_OFF"]),
            height = 26,
        })
        lockBtn:SetPoint("LEFT", previewBtn, "RIGHT", 8, 0)
        lockBtn:SetScript("OnClick", function()
            QuestItemBarModule:SetLocked(not GetSettings().locked)
            QuestItemBarModule._refreshCustomDetail()
        end)

        local sortLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sortLabel:SetPoint("LEFT", lockBtn, "RIGHT", 16, 0)
        sortLabel:SetText(L["QUESTITEMBAR_SORT"])
        sortLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local sortBtn = OneWoW_GUI:CreateFitTextButton(content, { text = QuestItemBarModule:GetSortLabel(), height = 26 })
        sortBtn:SetPoint("LEFT", sortLabel, "RIGHT", 8, 0)
        sortBtn:SetScript("OnClick", function()
            local cur = GetSettings()
            local modes = QuestItemBarModule.SORT_MODES
            local numModes = #modes
            local current = cur.sortMode or QuestItemBarModule.defaultSortMode
            local currentIdx = 1
            for i, m in ipairs(modes) do
                if m.value == current then
                    currentIdx = i
                    break
                end
            end
            cur.sortMode = modes[(currentIdx % numModes) + 1].value
            QuestItemBarModule:ScheduleUpdate()
            QuestItemBarModule._refreshCustomDetail()
        end)

        local hideCheck = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        hideCheck:SetPoint("LEFT", sortBtn, "RIGHT", 16, 0)
        hideCheck.Text:SetText(L["QUESTITEMBAR_HIDE_IF_EMPTY"])
        hideCheck.Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        hideCheck:SetChecked(s.hideWhenEmpty)
        hideCheck:SetScript("OnClick", function(self)
            GetSettings().hideWhenEmpty = self:GetChecked()
            QuestItemBarModule:ScheduleUpdate()
        end)
        y = y - 36

        -- Hide anchor toggle
        local hideAnchorCheck = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
        hideAnchorCheck:SetPoint("TOPLEFT", content, "TOPLEFT", -4, y)
        hideAnchorCheck.Text:SetText(L["HIDE_ANCHOR_SHOW_ON_HOVER"])
        hideAnchorCheck.Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        hideAnchorCheck:SetChecked(s.hideAnchor)
        hideAnchorCheck:SetScript("OnClick", function(self)
            GetSettings().hideAnchor = self:GetChecked()
            QuestItemBarModule:ScheduleUpdate()
        end)
        y = y - 28

        -- Grow direction dropdown
        local GROW_DIRS = { "RIGHT", "LEFT", "DOWN", "UP" }
        local growDirLabels = {
            RIGHT = L["QUESTITEMBAR_GROW_RIGHT"],
            LEFT  = L["QUESTITEMBAR_GROW_LEFT"],
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
                QuestItemBarModule:ScheduleUpdate()
            end,
        })
        y = y - 32

        -- Row 2: Show only these quest items: [] Supertracked [] Current Zone [] Tracked
        local row2 = CreateFrame("Frame", nil, content)
        row2:SetPoint("TOPLEFT", content, "TOPLEFT", -4, y)
        row2:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        row2:SetHeight(24)

        local filterLabel = row2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        filterLabel:SetPoint("LEFT", row2, "LEFT", 4, 0)
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
            QuestItemBarModule:ScheduleUpdate()
            QuestItemBarModule._refreshCustomDetail()
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
            QuestItemBarModule:ScheduleUpdate()
            QuestItemBarModule._refreshCustomDetail()
        end)

        local trackedCheck = CreateFrame("CheckButton", nil, row2, "InterfaceOptionsCheckButtonTemplate")
        trackedCheck:SetPoint("LEFT", zoneCheck.Text, "RIGHT", 8, 0)
        trackedCheck:SetPoint("CENTER", row2, "CENTER", 0, 0)
        trackedCheck.Text:SetText(L["QUESTITEMBAR_FILTER_TRACKED"])
        trackedCheck.Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        trackedCheck:SetChecked(s.showOnlyTracked)
        trackedCheck:SetScript("OnClick", function(self)
            GetSettings().showOnlyTracked = self:GetChecked()
            QuestItemBarModule:ScheduleUpdate()
            QuestItemBarModule._refreshCustomDetail()
        end)
        y = y - 34

        -- Dynamic order panel (only when sortMode == 5): horizontal drag chips
        local TIER_LABEL_KEYS = {
            supertracked = "QUESTITEMBAR_TIER_SUPERTRACKED",
            proximity    = "QUESTITEMBAR_TIER_PROXIMITY",
            zone         = "QUESTITEMBAR_TIER_ZONE",
            tracked      = "QUESTITEMBAR_TIER_TRACKED",
        }
        local CHIP_H = 26
        local CHIP_GAP = 6
        local CHIP_PAD_X = 10
        if s.sortMode == 5 then
            local orderLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            orderLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            orderLabel:SetText(L["QUESTITEMBAR_DYNAMIC_ORDER"])
            orderLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            y = y - (orderLabel:GetStringHeight() + 6)

            local orderHost = CreateFrame("Frame", nil, content)
            orderHost:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            orderHost:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)

            local chips = {}
            local reorder = OneWoW_GUI:CreateReorderDrag({
                getItems = function()
                    return chips
                end,
                onReorder = function(from, to)
                    QuestItemBarModule:MoveDynamicOrder(from, to)
                    QuestItemBarModule._refreshCustomDetail()
                end,
                onPickup = function(chip)
                    chip:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
                end,
                onRestore = function(chip)
                    chip:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                end,
                onHover = function(chip)
                    chip:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                end,
                onUnhover = function(chip)
                    chip:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                end,
            })

            local availW = tonumber(contentWidth) or 0
            if availW < 1 then
                availW = orderHost:GetWidth() or 400
            end
            local x, rowY = 0, 0
            local order = QuestItemBarModule:GetDynamicOrder()
            for i = 1, #order do
                local key = order[i]
                local chip = OneWoW_GUI:CreateFrame(orderHost, {
                    height = CHIP_H,
                    bgColor = "BG_TERTIARY",
                    borderColor = "BORDER_SUBTLE",
                })
                local labelText = OneWoW_GUI:CreateFS(chip, 11)
                labelText:SetPoint("LEFT", chip, "LEFT", CHIP_PAD_X, 0)
                labelText:SetText(L[TIER_LABEL_KEYS[key]] or key)
                labelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                local chipW = math.max(48, (labelText:GetStringWidth() or 0) + CHIP_PAD_X * 2)
                chip:SetWidth(chipW)

                if x > 0 and (x + chipW) > availW then
                    x = 0
                    rowY = rowY - (CHIP_H + CHIP_GAP)
                end
                chip:SetPoint("TOPLEFT", orderHost, "TOPLEFT", x, rowY)
                x = x + chipW + CHIP_GAP

                chip:EnableMouse(true)
                chip:SetScript("OnEnter", function(self)
                    if reorder:IsActive() then
                        return
                    end
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(L[TIER_LABEL_KEYS[key]] or key)
                    GameTooltip:AddLine(L["QUESTITEMBAR_HINT_DRAG_REORDER"], 0.7, 0.7, 0.7, true)
                    GameTooltip:Show()
                end)
                chip:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)

                chips[i] = chip
                reorder:Attach(chip, i)
            end

            local totalH = (-rowY) + CHIP_H
            orderHost:SetHeight(totalH)
            y = y - totalH - 8
        end

        -- Row 3: Sliders (Button Size left, Columns right)
        local sliderRowY = y
        local sizeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sizeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, sliderRowY)
        sizeLabel:SetText(string.format("%s: %d", L["BUTTON_SIZE"], s.buttonSize or QuestItemBarModule.defaultButtonSize))
        sizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local sizeSlider = CreateFrame("Slider", "OneWoW_QoL_QIBarSizeSlider", content, "OptionsSliderTemplate")
        sizeSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 12, sliderRowY - sizeLabel:GetStringHeight() - 4)
        sizeSlider:SetWidth(170)
        sizeSlider:SetMinMaxValues(QuestItemBarModule.MIN_BUTTON_SIZE, QuestItemBarModule.MAX_BUTTON_SIZE)
        sizeSlider:SetValue(s.buttonSize or QuestItemBarModule.defaultButtonSize)
        sizeSlider:SetValueStep(2)
        sizeSlider:SetObeyStepOnDrag(true)
        OneWoW_GUI:ConfigureOptionsSliderEnds(sizeSlider, tostring(QuestItemBarModule.MIN_BUTTON_SIZE),
            tostring(QuestItemBarModule.MAX_BUTTON_SIZE))
        sizeSlider:SetScript("OnValueChanged", function(_, value)
            local v = math.floor(value + 0.5)
            GetSettings().buttonSize = v
            sizeLabel:SetText(string.format("%s: %d", L["BUTTON_SIZE"], v))
            QuestItemBarModule:ScheduleUpdate()
        end)

        local colsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colsLabel:SetPoint("TOP", sizeLabel, "TOP")
        colsLabel:SetPoint("LEFT", sizeSlider, "RIGHT", 24, 0)
        colsLabel:SetText(string.format("%s: %d", L["QUESTITEMBAR_COLUMNS"], s.columns or QuestItemBarModule.defaultColumns))
        colsLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local colsSlider = CreateFrame("Slider", "OneWoW_QoL_QIBarColsSlider", content, "OptionsSliderTemplate")
        colsSlider:SetPoint("TOP", sizeSlider, "TOP")
        colsSlider:SetPoint("LEFT", sizeSlider, "RIGHT", 24, 0)
        colsSlider:SetWidth(170)
        colsSlider:SetMinMaxValues(QuestItemBarModule.MIN_COLUMNS, QuestItemBarModule.MAX_COLUMNS)
        colsSlider:SetValue(s.columns or QuestItemBarModule.defaultColumns)
        colsSlider:SetValueStep(1)
        colsSlider:SetObeyStepOnDrag(true)
        OneWoW_GUI:ConfigureOptionsSliderEnds(colsSlider, tostring(QuestItemBarModule.MIN_COLUMNS),
            tostring(QuestItemBarModule.MAX_COLUMNS))
        colsSlider:SetScript("OnValueChanged", function(_, value)
            local v = math.floor(value + 0.5)
            GetSettings().columns = v
            colsLabel:SetText(string.format("%s: %d", L["QUESTITEMBAR_COLUMNS"], v))
            QuestItemBarModule:ScheduleUpdate()
        end)
        y = y - 50

        local spacingLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        spacingLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        spacingLabel:SetText(string.format("%s: %d", L["ICON_SPACING"], s.iconSpacing or 4))
        spacingLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        y = y - spacingLabel:GetStringHeight() - 4

        local spacingSlider = CreateFrame("Slider", "OneWoW_QoL_QIBarSpacingSlider", content, "OptionsSliderTemplate")
        spacingSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        spacingSlider:SetWidth(170)
        spacingSlider:SetMinMaxValues(0, 12)
        spacingSlider:SetValue(s.iconSpacing or 4)
        spacingSlider:SetValueStep(1)
        spacingSlider:SetObeyStepOnDrag(true)
        OneWoW_GUI:ConfigureOptionsSliderEnds(spacingSlider, "0", "12")
        spacingSlider:SetScript("OnValueChanged", function(_, value)
            local v = math.floor(value + 0.5)
            GetSettings().iconSpacing = v
            spacingLabel:SetText(string.format("%s: %d", L["ICON_SPACING"], v))
            QuestItemBarModule:ScheduleUpdate()
        end)
        y = y - 50

        return math.max(1, math.abs(y))
    end)

    -- Quest Item Status: titled card with fill-remaining scroll list
    stack:AddCard("qib:status", L["QUESTITEMBAR_QUEST_ITEM_STATUS"], function(content, contentWidth)
        -- Card chrome + prior stack items eat vertical space vs the old section header.
        local usedAbove = STACK_START_ABS + CARD_CHROME
        local settingsCard = stack.items[1]
        if settingsCard then
            usedAbove = usedAbove + settingsCard:GetHeight() + STACK_GAP
        end

        local detailScrollFrame = container:GetParent() and container:GetParent():GetParent()
        local visibleHeight = (detailScrollFrame and detailScrollFrame.GetHeight and detailScrollFrame:GetHeight()) or 0
        local listHeight = LIST_SCROLL_HEIGHT
        if visibleHeight > 0 and contentYOffset then
            local contentTopInScroll = math.abs(contentYOffset)
            local availableForList = visibleHeight - contentTopInScroll - usedAbove - STACK_BOTTOM_PAD
            listHeight = math.max(MIN_LIST_HEIGHT, availableForList)
        end

        local listScrollWrap = CreateFrame("Frame", nil, content, "BackdropTemplate")
        listScrollWrap:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        listScrollWrap:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        listScrollWrap:SetHeight(listHeight)
        listScrollWrap:SetBackdrop(BACKDROP_SIMPLE)
        listScrollWrap:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))

        local colHeader = CreateFrame("Frame", nil, listScrollWrap, "BackdropTemplate")
        colHeader:SetPoint("TOPLEFT", listScrollWrap, "TOPLEFT", 4, -4)
        colHeader:SetPoint("TOPRIGHT", listScrollWrap, "TOPRIGHT", -(4 + SCROLLBAR_GUTTER), -4)
        colHeader:SetHeight(18)
        colHeader:SetBackdrop(BACKDROP_SIMPLE)
        colHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

        local listWidth = math.max(0, contentWidth or 0)
        local useTightLayout = listWidth < TIGHT_LAYOUT_THRESHOLD
        container._qibUsedTightLayout = useTightLayout
        -- Split flexible space 50/50 between Quest and Item so both benefit from wider windows
        local rowWidth = listWidth - 8 - SCROLLBAR_GUTTER
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
        hdrItem:SetText(L["ITEM"])
        hdrItem:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local hdrStatus = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdrStatus:SetPoint("RIGHT", colHeader, "RIGHT", -8, 0)
        hdrStatus:SetText(STATUS)
        hdrStatus:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        hdrStatus:SetJustifyH("RIGHT")

        local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(listScrollWrap, {})
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", colHeader, "BOTTOMLEFT", 0, -2)
        scrollFrame:SetPoint("BOTTOMRIGHT", listScrollWrap, "BOTTOMRIGHT", -(4 + SCROLLBAR_GUTTER), 4)

        local entries = QuestItemBarModule.BuildQuestItemDebugList()
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
            statusText:SetText(L[entry.status])
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
                    local link = entry.link or (entry.itemID and select(2, C_Item.GetItemInfo(entry.itemID)))
                    if link then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetHyperlink(link)
                        GameTooltip:Show()
                    end
                end)
                itemCol:SetScript("OnLeave", function()
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
            questBtn:SetScript("OnLeave", function()
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

        return math.max(1, listHeight)
    end)

    stack:Finish()
    return -container:GetHeight()
end

function QuestItemBarModule:CreateCustomDetail(detailScrollChild, yOffset, _)
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

    local function applyHostHeight(cy)
        cy = cy or -container:GetHeight()
        local newH = math.abs(capturedYOffset) + math.abs(cy) + 20
        if math.abs((detailScrollChild:GetHeight() or 0) - newH) < 0.5 then
            return
        end
        detailScrollChild:SetHeight(newH)
    end

    local refreshing = false
    local function doRefresh()
        if refreshing then return end
        if container:GetParent() ~= detailScrollChild then return end
        refreshing = true
        OneWoW_GUI:ClearFrame(container)
        local cy = BuildContent(container, applyHostHeight, capturedYOffset)
        applyHostHeight(cy)
        refreshing = false
    end

    self._refreshCustomDetail = function()
        doRefresh()
        -- Deferred check: width may be 0 at build time; rebuild after layout if we used tight layout
        -- Skip deferred when we had sufficient width at build time (avoids unnecessary refresh)
        if container._qibUsedTightLayout then
            C_Timer.After(0, function()
                if container:GetParent() ~= detailScrollChild then return end
                local w = (container:GetWidth() or 0) - (STACK_MARGIN_X * 2) - CARD_CONTENT_INSET
                if w >= TIGHT_LAYOUT_THRESHOLD and QuestItemBarModule._refreshCustomDetail then
                    QuestItemBarModule._refreshCustomDetail()
                end
            end)
        end
    end

    local detailScrollFrame = detailScrollChild:GetParent()
    local detailContainer = detailScrollFrame and detailScrollFrame:GetParent()
    local detailPanel = detailContainer and detailContainer:GetParent()
    if detailScrollFrame and not detailScrollChild._qibResizeHooked then
        detailScrollChild._qibResizeHooked = true
        local lastW = -1
        local function onResize(_, width, _)
            if container:GetParent() ~= detailScrollChild then return end
            local w = tonumber(width) or (detailScrollFrame:GetWidth() or 0)
            if lastW >= 0 and math.abs(w - lastW) < 2 then
                return
            end
            lastW = w
            if QuestItemBarModule._refreshCustomDetail then
                QuestItemBarModule._refreshCustomDetail()
            end
        end
        detailScrollFrame:HookScript("OnSizeChanged", onResize)
        if detailPanel and detailPanel ~= detailScrollFrame then
            detailPanel:HookScript("OnSizeChanged", onResize)
        end
    end

    local cy = BuildContent(container, applyHostHeight, capturedYOffset)
    applyHostHeight(cy)

    return yOffset + cy
end
