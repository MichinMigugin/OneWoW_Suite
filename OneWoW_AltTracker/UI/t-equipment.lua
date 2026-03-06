local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local expandedRows = {}
local UpdateRowLayout
local currentSortColumn = nil
local currentSortAscending = true
local characterRows = {}
local hiddenColumns = {}

function ns.UI.CreateEquipmentTab(parent)
    local overviewPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    overviewPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    overviewPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)
    overviewPanel:SetHeight(110)
    overviewPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    overviewPanel:SetBackdropColor(T("BG_SECONDARY"))
    overviewPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local overviewTitle = overviewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overviewTitle:SetPoint("TOPLEFT", overviewPanel, "TOPLEFT", 10, -6)
    overviewTitle:SetText(L["EQUIPMENT_OVERVIEW"])
    overviewTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local statsContainer = CreateFrame("Frame", nil, overviewPanel)
    statsContainer:SetPoint("TOPLEFT", overviewTitle, "BOTTOMLEFT", 0, -8)
    statsContainer:SetPoint("BOTTOMRIGHT", overviewPanel, "BOTTOMRIGHT", -10, 6)

    local statLabels = {
        L["EQUIPMENT_ATTENTION"], L["EQUIPMENT_CHARACTERS"], L["EQUIPMENT_AVG_ILVL"], L["EQUIPMENT_HIGHEST_ILVL"], L["EQUIPMENT_LOWEST_ILVL"],
        L["EQUIPMENT_MISSING_ENCHANTS"], L["EQUIPMENT_MISSING_GEMS"], L["EQUIPMENT_LOW_DURABILITY"], L["EQUIPMENT_UPGRADE_READY"], L["EQUIPMENT_SET_BONUSES"]
    }

    local statTooltipTitles = {
        L["TT_EQUIPMENT_ATTENTION"], L["TT_EQUIPMENT_CHARACTERS"], L["TT_EQUIPMENT_AVG_ILVL"], L["TT_EQUIPMENT_HIGHEST_ILVL"], L["TT_EQUIPMENT_LOWEST_ILVL"],
        L["TT_EQUIPMENT_MISSING_ENCHANTS"], L["TT_EQUIPMENT_MISSING_GEMS"], L["TT_EQUIPMENT_LOW_DURABILITY"], L["TT_EQUIPMENT_UPGRADE_READY"], L["TT_EQUIPMENT_SET_BONUSES"]
    }

    local statTooltips = {
        L["TT_EQUIPMENT_ATTENTION_DESC"], L["TT_EQUIPMENT_CHARACTERS_DESC"], L["TT_EQUIPMENT_AVG_ILVL_DESC"], L["TT_EQUIPMENT_HIGHEST_ILVL_DESC"], L["TT_EQUIPMENT_LOWEST_ILVL_DESC"],
        L["TT_EQUIPMENT_MISSING_ENCHANTS_DESC"], L["TT_EQUIPMENT_MISSING_GEMS_DESC"], L["TT_EQUIPMENT_LOW_DURABILITY_DESC"], L["TT_EQUIPMENT_UPGRADE_READY_DESC"], L["TT_EQUIPMENT_SET_BONUSES_DESC"]
    }

    local statValues = {
        "0", "0", "0", "0", "0",
        "0", "0", "0", "0", "0"
    }

    local cols = 5
    local rows = 2
    local statBoxes = {}

    for i = 1, #statLabels do
        local row = math.ceil(i / cols)
        local col = ((i - 1) % cols) + 1

        local statBox = CreateFrame("Frame", nil, statsContainer, "BackdropTemplate")
        statBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        statBox:SetBackdropColor(T("BG_TERTIARY"))
        statBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local label = statBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOP", statBox, "TOP", 0, -5)
        label:SetText(statLabels[i])
        label:SetTextColor(T("TEXT_SECONDARY"))

        local value = statBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("BOTTOM", statBox, "BOTTOM", 0, 6)
        value:SetText(statValues[i])
        value:SetTextColor(T("TEXT_PRIMARY"))

        statBox.label = label
        statBox.value = value

        statBox:EnableMouse(true)
        statBox:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(statTooltipTitles[i], 1, 1, 1)
            GameTooltip:AddLine(statTooltips[i], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        statBox:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
            GameTooltip:Hide()
        end)

        table.insert(statBoxes, statBox)
    end

    statsContainer:SetScript("OnSizeChanged", function(self, width, height)
        local boxWidth = (width - (cols + 1) * 3) / cols
        local boxHeight = (height - (rows + 1) * 3) / rows

        for i, box in ipairs(statBoxes) do
            local row = math.ceil(i / cols)
            local col = ((i - 1) % cols) + 1

            local x = 3 + (col - 1) * (boxWidth + 3)
            local y = -3 - (row - 1) * (boxHeight + 3)

            box:SetSize(boxWidth, boxHeight)
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
        end
    end)

    local rosterPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rosterPanel:SetPoint("TOPLEFT", overviewPanel, "BOTTOMLEFT", 0, -8)
    rosterPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 30)
    rosterPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    rosterPanel:SetBackdropColor(T("BG_PRIMARY"))
    rosterPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    -- List container: single reference frame that header, scrollframe, and scrollbar all anchor to
    local listContainer = CreateFrame("Frame", nil, rosterPanel)
    listContainer:SetPoint("TOPLEFT", rosterPanel, "TOPLEFT", 8, -8)
    listContainer:SetPoint("BOTTOMRIGHT", rosterPanel, "BOTTOMRIGHT", -8, 8)

    local scrollBarWidth = 10

    -- Column Headers (inside listContainer, right edge leaves room for scrollbar)
    local headerRow = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
    headerRow:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, 0)
    headerRow:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", -scrollBarWidth, 0)
    headerRow:SetHeight(26)
    headerRow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    headerRow:SetBackdropColor(T("BG_TERTIARY"))
    headerRow:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local columns = {
        {key = "expand", label = "", width = 25, fixed = true, ttTitle = L["TT_COL_EXPAND"], ttDesc = L["TT_COL_EXPAND_DESC"]},
        {key = "faction", label = L["COL_FACTION"], width = 25, fixed = true, ttTitle = L["TT_COL_FACTION"], ttDesc = L["TT_COL_FACTION_DESC"]},
        {key = "mail", label = L["COL_MAIL"], width = 35, fixed = true, ttTitle = L["TT_COL_MAIL"], ttDesc = L["TT_COL_MAIL_DESC"]},
        {key = "name", label = L["COL_CHARACTER"], width = 135, fixed = false, ttTitle = L["TT_COL_CHARACTER"], ttDesc = L["TT_COL_CHARACTER_DESC"]},
        {key = "level", label = L["COL_LEVEL"], width = 40, fixed = true, ttTitle = L["TT_COL_LEVEL"], ttDesc = L["TT_COL_LEVEL_DESC"]},
        {key = "itemLevel", label = L["EQUIPMENT_COL_ILVL"], width = 50, fixed = true, ttTitle = L["TT_COL_ILVL"], ttDesc = L["TT_COL_ILVL_DESC"]},
        {key = "durability", label = L["EQUIPMENT_COL_DURABILITY"], width = 50, fixed = false, ttTitle = L["TT_COL_DURABILITY"], ttDesc = L["TT_COL_DURABILITY_DESC"]},
        {key = "enchants", label = L["EQUIPMENT_COL_ENCHANTS"], width = 55, fixed = false, ttTitle = L["TT_COL_ENCHANTS"], ttDesc = L["TT_COL_ENCHANTS_DESC"]},
        {key = "gems", label = L["EQUIPMENT_COL_GEMS"], width = 50, fixed = true, ttTitle = L["TT_COL_GEMS"], ttDesc = L["TT_COL_GEMS_DESC"]},
        {key = "tierSet", label = L["EQUIPMENT_COL_TIER_SET"], width = 45, fixed = false, ttTitle = L["TT_COL_TIER_SET"], ttDesc = L["TT_COL_TIER_SET_DESC"]},
        {key = "str", label = L["EQUIPMENT_COL_STR"], width = 45, fixed = true, ttTitle = L["TT_COL_STR"], ttDesc = L["TT_COL_STR_DESC"]},
        {key = "agi", label = L["EQUIPMENT_COL_AGI"], width = 45, fixed = true, ttTitle = L["TT_COL_AGI"], ttDesc = L["TT_COL_AGI_DESC"]},
        {key = "sta", label = L["EQUIPMENT_COL_STA"], width = 45, fixed = true, ttTitle = L["TT_COL_STA"], ttDesc = L["TT_COL_STA_DESC"]},
        {key = "int", label = L["EQUIPMENT_COL_INT"], width = 45, fixed = true, ttTitle = L["TT_COL_INT"], ttDesc = L["TT_COL_INT_DESC"]},
        {key = "armor", label = L["EQUIPMENT_COL_ARMOR"], width = 50, fixed = true, ttTitle = L["TT_COL_ARMOR"], ttDesc = L["TT_COL_ARMOR_DESC"]},
        {key = "ap", label = L["EQUIPMENT_COL_AP"], width = 50, fixed = true, ttTitle = L["TT_COL_AP"], ttDesc = L["TT_COL_AP_DESC"]},
        {key = "crit", label = L["EQUIPMENT_COL_CRIT"], width = 45, fixed = true, ttTitle = L["TT_COL_CRIT"], ttDesc = L["TT_COL_CRIT_DESC"]},
        {key = "haste", label = L["EQUIPMENT_COL_HASTE"], width = 50, fixed = true, ttTitle = L["TT_COL_HASTE"], ttDesc = L["TT_COL_HASTE_DESC"]},
        {key = "mastery", label = L["EQUIPMENT_COL_MASTERY"], width = 60, fixed = false, ttTitle = L["TT_COL_MASTERY"], ttDesc = L["TT_COL_MASTERY_DESC"]},
        {key = "vers", label = L["EQUIPMENT_COL_VERS"], width = 50, fixed = true, ttTitle = L["TT_COL_VERS"], ttDesc = L["TT_COL_VERS_DESC"]},
        {key = "status", label = L["EQUIPMENT_COL_STATUS"], width = 60, fixed = false, ttTitle = L["TT_COL_STATUS"], ttDesc = L["TT_COL_STATUS_DESC"]}
    }

    local colGap = 4
    headerRow.columnButtons = {}
    headerRow.columns = columns

    local hiddenIndicator = CreateFrame("Frame", nil, headerRow, "BackdropTemplate")
    hiddenIndicator:SetSize(30, 22)
    hiddenIndicator:SetPoint("RIGHT", headerRow, "RIGHT", -5, 0)
    hiddenIndicator:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    hiddenIndicator:SetBackdropColor(T("BG_SECONDARY"))
    hiddenIndicator:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    hiddenIndicator:Hide()

    local hiddenText = hiddenIndicator:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hiddenText:SetPoint("CENTER")
    hiddenText:SetTextColor(1, 0.5, 0)
    hiddenIndicator.text = hiddenText

    hiddenIndicator:EnableMouse(true)
    hiddenIndicator:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["TT_HIDDEN_COLS_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["TT_HIDDEN_COLS_DESC"], 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine(" ", 1, 1, 1)

        local hiddenList = {"Str", "Agi", "Sta", "Int", "Armor", "AP", "Crit", "Haste", "Mast", "Vers"}
        for _, colName in ipairs(hiddenList) do
            GameTooltip:AddLine(colName, 1, 0.5, 0)
        end

        GameTooltip:Show()
    end)
    hiddenIndicator:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_SECONDARY"))
        GameTooltip:Hide()
    end)

    headerRow.hiddenIndicator = hiddenIndicator

    local function CalculateContentMinWidths()
        if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return end
        if not headerRow or not headerRow.columns then return end

        for i, col in ipairs(headerRow.columns) do
            local maxChars = string.len(col.label or "")

            for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
                local text = ""

                if col.key == "name" then
                    text = charData.name or ""
                elseif col.key == "level" then
                    text = tostring(charData.level or 0)
                elseif col.key == "itemLevel" then
                    text = tostring(charData.itemLevel or 0)
                elseif col.key == "durability" then
                    text = "100%"
                elseif col.key == "enchants" then
                    text = "Missing: 10"
                elseif col.key == "gems" then
                    text = "Missing: 10"
                elseif col.key == "tierSet" then
                    text = "5/5"
                elseif col.key == "str" then
                    text = tostring((charData.stats and charData.stats.strength) or 0)
                elseif col.key == "agi" then
                    text = tostring((charData.stats and charData.stats.agility) or 0)
                elseif col.key == "sta" then
                    text = tostring((charData.stats and charData.stats.stamina) or 0)
                elseif col.key == "int" then
                    text = tostring((charData.stats and charData.stats.intellect) or 0)
                elseif col.key == "armor" then
                    text = tostring((charData.stats and charData.stats.armor) or 0)
                elseif col.key == "ap" then
                    text = tostring((charData.stats and charData.stats.attackPower) or 0)
                elseif col.key == "crit" then
                    text = "100.0%"
                elseif col.key == "haste" then
                    text = "100.0%"
                elseif col.key == "mastery" then
                    text = "100.0%"
                elseif col.key == "vers" then
                    text = "100.0%"
                elseif col.key == "status" then
                    text = "Needs Attention"
                end

                maxChars = math.max(maxChars, string.len(text))
            end

            col.contentMinWidth = math.max(col.width, (maxChars * 7) + 4)
        end
    end

    local function UpdateSortIndicators()
        if not headerRow or not headerRow.columnButtons then return end

        for i, btn in ipairs(headerRow.columnButtons) do
            local col = columns[i]
            if btn.sortArrow then
                btn.sortArrow:Hide()
            end

            if col and col.key == currentSortColumn then
                if not btn.sortArrow then
                    btn.sortArrow = btn:CreateTexture(nil, "OVERLAY")
                    btn.sortArrow:SetSize(8, 8)
                    btn.sortArrow:SetPoint("RIGHT", btn, "RIGHT", -3, 0)
                end

                if currentSortAscending then
                    btn.sortArrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
                    btn.sortArrow:SetTexCoord(0, 1, 1, 0)
                else
                    btn.sortArrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
                    btn.sortArrow:SetTexCoord(0, 1, 0, 1)
                end
                btn.sortArrow:Show()
            end
        end
    end

    local function UpdateAllRowCells()
        if not headerRow or not headerRow.columnButtons then return end
        if not characterRows then return end

        for _, charRow in ipairs(characterRows) do
            if charRow.cells then
                for i, cell in ipairs(charRow.cells) do
                    local btn = headerRow.columnButtons[i]
                    local col = columns[i]

                    if col and hiddenColumns[col.key] then
                        if cell.Hide then
                            cell:Hide()
                        elseif cell.SetAlpha then
                            cell:SetAlpha(0)
                        end
                    else
                        if cell.Show then
                            cell:Show()
                        elseif cell.SetAlpha then
                            cell:SetAlpha(1)
                        end

                        if btn and btn.columnWidth and btn.columnX then
                            local width = btn.columnWidth
                            local x = btn.columnX

                            cell:ClearAllPoints()

                            if i == 1 then
                                cell:SetSize(width, 32)
                                cell:SetPoint("LEFT", charRow, "LEFT", x, 0)
                            elseif i == 2 or i == 3 then
                                cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
                            else
                                cell:SetWidth(width - 6)
                                if i == 4 or i == 21 then
                                    cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
                                else
                                    cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local function UpdateColumnLayout()
        local availableWidth = headerRow:GetWidth() - 10
        if availableWidth <= 0 then return end

        local hideableColumns = {"str", "agi", "sta", "int", "armor", "ap", "crit", "haste", "mastery", "vers"}

        wipe(hiddenColumns)

        local testWidth = 0
        for _, col in ipairs(columns) do
            if not hiddenColumns[col.key] then
                local minWidth = col.contentMinWidth or col.width
                testWidth = testWidth + minWidth
            end
        end
        testWidth = testWidth + (#columns - 1) * colGap

        local shouldHide = (testWidth > availableWidth * 1.25)

        if shouldHide then
            for _, hideKey in ipairs(hideableColumns) do
                hiddenColumns[hideKey] = true
            end
        end

        fixedWidth = 0
        flexCount = 0
        local visibleCols = 0
        for _, col in ipairs(columns) do
            if not hiddenColumns[col.key] then
                visibleCols = visibleCols + 1
                local minWidth = col.contentMinWidth or col.width
                if col.fixed then
                    fixedWidth = fixedWidth + minWidth
                else
                    flexCount = flexCount + 1
                end
            end
        end

        local totalGaps = (visibleCols - 1) * colGap
        local remainingWidth = availableWidth - fixedWidth - totalGaps
        local flexWidth = flexCount > 0 and math.max(0, remainingWidth / flexCount) or 0

        local xOffset = 5
        local visibleButtons = {}
        for i, col in ipairs(columns) do
            local btn = headerRow.columnButtons[i]
            if btn then
                if hiddenColumns[col.key] then
                    btn:Hide()
                else
                    btn:Show()
                    local minWidth = col.contentMinWidth or col.width
                    local width = col.fixed and minWidth or math.max(minWidth, flexWidth)
                    btn.columnWidth = width
                    btn.columnX = xOffset
                    table.insert(visibleButtons, {btn = btn, width = width, xOffset = xOffset})
                    xOffset = xOffset + width + colGap
                end
            end
        end

        if #visibleButtons > 0 then
            local lastBtn = visibleButtons[#visibleButtons]
            local totalWidth = lastBtn.xOffset + lastBtn.width
            local maxWidth = headerRow:GetWidth() - 5
            if totalWidth > maxWidth then
                local overflow = totalWidth - maxWidth
                lastBtn.width = math.max(30, lastBtn.width - overflow)
                lastBtn.btn.columnWidth = lastBtn.width
            end
        end

        for _, btnInfo in ipairs(visibleButtons) do
            btnInfo.btn:SetWidth(btnInfo.width)
            btnInfo.btn:ClearAllPoints()
            btnInfo.btn:SetPoint("LEFT", headerRow, "LEFT", btnInfo.xOffset, 0)
        end

        UpdateAllRowCells()

        if headerRow.hiddenIndicator then
            local hiddenCount = 0
            for _ in pairs(hiddenColumns) do
                hiddenCount = hiddenCount + 1
            end

            if hiddenCount > 0 then
                headerRow.hiddenIndicator.text:SetText(string.format(L["EQUIPMENT_HIDDEN_COLS"], hiddenCount))
                headerRow.hiddenIndicator:Show()
            else
                headerRow.hiddenIndicator:Hide()
            end
        end
    end

    for i, col in ipairs(columns) do
        local btn = CreateFrame("Button", nil, headerRow, "BackdropTemplate")
        btn:SetHeight(22)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(T("BG_TERTIARY"))
        btn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

        if col.key == "expand" then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(14, 14)
            icon:SetPoint("CENTER")
            icon:SetAtlas("Gamepad_Rev_Plus_64")
            btn.icon = icon
        elseif col.key == "faction" then
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("CENTER")
            text:SetText(col.label)
            text:SetTextColor(T("TEXT_PRIMARY"))
            btn.text = text
        elseif col.key == "mail" then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(12, 12)
            icon:SetPoint("CENTER")
            icon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
            btn.icon = icon
        else
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("CENTER")
            text:SetText(col.label)
            text:SetTextColor(T("TEXT_PRIMARY"))
            if col.key == "durability" or col.key == "tierSet" or col.key == "mastery" then
                text:SetJustifyH("CENTER")
            end
            btn.text = text
        end

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
            if btn.text then btn.text:SetTextColor(T("TEXT_ACCENT")) end
            if col.ttTitle and col.ttDesc then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(col.ttTitle, 1, 1, 1)
                GameTooltip:AddLine(col.ttDesc, nil, nil, nil, true)
                GameTooltip:Show()
            end
        end)

        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
            if btn.text then btn.text:SetTextColor(T("TEXT_PRIMARY")) end
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function(self)
            if col.key == "expand" or col.key == "faction" or col.key == "mail" then
                return
            end

            if currentSortColumn == col.key then
                currentSortAscending = not currentSortAscending
            else
                currentSortColumn = col.key
                currentSortAscending = true
            end

            if parent then
                ns.UI.RefreshEquipmentTab(parent)
                C_Timer.After(0.1, function()
                    UpdateSortIndicators()
                end)
            end
        end)

        table.insert(headerRow.columnButtons, btn)
    end

    headerRow:SetScript("OnSizeChanged", function()
        C_Timer.After(0.1, function()
            UpdateColumnLayout()
        end)
    end)

    -- Bare ScrollFrame (no template) - avoids SecureScrollTemplates auto-wiring that breaks in 12.0.x
    local scrollFrame = CreateFrame("ScrollFrame", nil, listContainer)
    scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -scrollBarWidth, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 40))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 40))
        end
    end)

    -- Custom scrollbar track anchored to listContainer right side
    local scrollTrack = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", -2, 0)
    scrollTrack:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -2, 0)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollTrack:SetBackdropColor(T("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(30)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollThumb:SetBackdropColor(T("ACCENT_PRIMARY"))

    local function UpdateScrollThumb()
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        if maxScroll <= 0 then
            scrollThumb:Hide()
            return
        end
        scrollThumb:Show()
        local viewHeight = scrollFrame:GetHeight()
        local trackHeight = scrollTrack:GetHeight()
        local thumbHeight = math.max(20, trackHeight * (viewHeight / (viewHeight + maxScroll)))
        local thumbRange = trackHeight - thumbHeight
        local thumbPos = (scrollFrame:GetVerticalScroll() / maxScroll) * thumbRange
        scrollThumb:SetHeight(thumbHeight)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -thumbPos)
    end

    scrollFrame:SetScript("OnVerticalScroll", function() UpdateScrollThumb() end)
    scrollFrame:SetScript("OnScrollRangeChanged", function() UpdateScrollThumb() end)

    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")
    scrollThumb:SetScript("OnDragStart", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnDragStop", function(self) self.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self.dragStartY - curY
        local trackHeight = scrollTrack:GetHeight()
        local thumbRange = trackHeight - self:GetHeight()
        if thumbRange > 0 then
            local maxScroll = scrollFrame:GetVerticalScrollRange()
            local newScroll = self.dragStartScroll + (delta / thumbRange) * maxScroll
            scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, newScroll)))
        end
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(scrollFrame:GetWidth())
    scrollContent:SetHeight(400)
    scrollFrame:SetScrollChild(scrollContent)

    scrollFrame:HookScript("OnSizeChanged", function(self, width, height)
        scrollContent:SetWidth(width)
        UpdateScrollThumb()
    end)

    local statusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    statusBar:SetPoint("TOPLEFT", rosterPanel, "BOTTOMLEFT", 0, -5)
    statusBar:SetPoint("TOPRIGHT", rosterPanel, "BOTTOMRIGHT", 0, -5)
    statusBar:SetHeight(25)
    statusBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    statusBar:SetBackdropColor(T("BG_SECONDARY"))
    statusBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", statusBar, "LEFT", 10, 0)
    statusText:SetText(string.format(L["CHARACTERS_TRACKED"], 0, ""))
    statusText:SetTextColor(T("TEXT_SECONDARY"))

    C_Timer.After(0.2, function()
        UpdateColumnLayout()
    end)

    parent.overviewPanel = overviewPanel
    parent.statsContainer = statsContainer
    parent.statBoxes = statBoxes
    parent.rosterPanel = rosterPanel
    parent.listContainer = listContainer
    parent.headerRow = headerRow
    parent.scrollFrame = scrollFrame
    parent.scrollContent = scrollContent
    parent.statusBar = statusBar
    parent.statusText = statusText
    parent.CalculateContentMinWidths = CalculateContentMinWidths

    C_Timer.After(0.5, function()
        if ns.UI.RefreshEquipmentTab then
            ns.UI.RefreshEquipmentTab(parent)
        end
    end)
end

function ns.UI.RefreshEquipmentTab(equipmentTab)
    if not equipmentTab then return end
    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return end

    if equipmentTab.headerRow and equipmentTab.headerRow.columns and equipmentTab.CalculateContentMinWidths then
        equipmentTab.CalculateContentMinWidths()
    end

    local allChars = {}
    for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
        table.insert(allChars, {
            key = charKey,
            data = charData
        })
    end

    if #allChars == 0 then return end

    local currentChar = UnitName("player")
    local currentRealm = GetRealmName()
    local currentCharKey = currentChar .. "-" .. currentRealm
    table.sort(allChars, function(a, b)
        local aIsCurrent = (a.key == currentCharKey)
        local bIsCurrent = (b.key == currentCharKey)
        if aIsCurrent and not bIsCurrent then return true end
        if bIsCurrent and not aIsCurrent then return false end

        if currentSortColumn then
            local aVal, bVal

            if currentSortColumn == "name" then
                aVal = a.data.name or ""
                bVal = b.data.name or ""
            elseif currentSortColumn == "level" then
                aVal = a.data.level or 0
                bVal = b.data.level or 0
            elseif currentSortColumn == "itemLevel" then
                aVal = a.data.itemLevel or 0
                bVal = b.data.itemLevel or 0
            elseif currentSortColumn == "durability" then
                aVal = 100
                bVal = 100
            elseif currentSortColumn == "str" then
                aVal = (a.data.stats and a.data.stats.strength) or 0
                bVal = (b.data.stats and b.data.stats.strength) or 0
            elseif currentSortColumn == "agi" then
                aVal = (a.data.stats and a.data.stats.agility) or 0
                bVal = (b.data.stats and b.data.stats.agility) or 0
            elseif currentSortColumn == "sta" then
                aVal = (a.data.stats and a.data.stats.stamina) or 0
                bVal = (b.data.stats and b.data.stats.stamina) or 0
            elseif currentSortColumn == "int" then
                aVal = (a.data.stats and a.data.stats.intellect) or 0
                bVal = (b.data.stats and b.data.stats.intellect) or 0
            elseif currentSortColumn == "armor" then
                aVal = (a.data.stats and a.data.stats.armor) or 0
                bVal = (b.data.stats and b.data.stats.armor) or 0
            elseif currentSortColumn == "ap" then
                aVal = (a.data.stats and a.data.stats.attackPower) or 0
                bVal = (b.data.stats and b.data.stats.attackPower) or 0
            elseif currentSortColumn == "crit" then
                aVal = (a.data.stats and a.data.stats.critChance) or 0
                bVal = (b.data.stats and b.data.stats.critChance) or 0
            elseif currentSortColumn == "haste" then
                aVal = (a.data.stats and a.data.stats.haste) or 0
                bVal = (b.data.stats and b.data.stats.haste) or 0
            elseif currentSortColumn == "mastery" then
                aVal = (a.data.stats and a.data.stats.mastery) or 0
                bVal = (b.data.stats and b.data.stats.mastery) or 0
            elseif currentSortColumn == "vers" then
                aVal = (a.data.stats and a.data.stats.versatility) or 0
                bVal = (b.data.stats and b.data.stats.versatility) or 0
            else
                aVal = a.data.name or ""
                bVal = b.data.name or ""
            end

            if type(aVal) == "number" then
                if currentSortAscending then
                    return aVal < bVal
                else
                    return aVal > bVal
                end
            else
                if currentSortAscending then
                    return aVal < bVal
                else
                    return aVal > bVal
                end
            end
        end

        return (a.data.name or "") < (b.data.name or "")
    end)

    local scrollContent = equipmentTab.scrollContent
    if not scrollContent then return end

    for _, row in ipairs(characterRows) do
        if row.expandedFrame then
            row.expandedFrame:Hide()
            row.expandedFrame = nil
        end
        row:Hide()
        row:SetParent(nil)
    end
    wipe(characterRows)

    local yOffset = -5
    local rowHeight = 32
    local rowGap = 2

    local totalILevel = 0
    local charCount = 0

    for charIndex, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local charData = charInfo.data

        local charRow = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        charRow:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
        charRow:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        charRow:SetHeight(rowHeight)
        charRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        charRow:SetBackdropColor(T("BG_TERTIARY"))
        charRow.charKey = charKey
        charRow.cells = {}

        local expandBtn = CreateFrame("Button", nil, charRow)
        expandBtn:SetSize(25, rowHeight)
        local expandIcon = expandBtn:CreateTexture(nil, "ARTWORK")
        expandIcon:SetSize(14, 14)
        expandIcon:SetPoint("CENTER")
        expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
        expandBtn.icon = expandIcon
        table.insert(charRow.cells, expandBtn)

        local function CreateExpandedDetails()
            if not charRow.expandedFrame then
                charRow.expandedFrame = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
                charRow.expandedFrame:SetPoint("TOPLEFT", charRow, "BOTTOMLEFT", 0, -2)
                charRow.expandedFrame:SetPoint("TOPRIGHT", charRow, "BOTTOMRIGHT", 0, -2)
                charRow.expandedFrame:SetHeight(70)
                charRow.expandedFrame:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1
                })
                charRow.expandedFrame:SetBackdropColor(T("BG_SECONDARY"))
                charRow.expandedFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

                local equipment = (_G.OneWoW_AltTracker_Character_DB.characters[charKey] and _G.OneWoW_AltTracker_Character_DB.characters[charKey].equipment)
                if equipment then
                    local slotOrder = {1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 4, 19}
                    local iconSize = 48
                    local iconGap = 4
                    local largeGap = 12
                    local startX = 10
                    local startY = -10

                    for i, slotID in ipairs(slotOrder) do
                        local item = equipment[slotID]
                        local xPos = startX + (i - 1) * (iconSize + iconGap)

                        if i == 17 then
                            xPos = xPos + (largeGap - iconGap)
                        elseif i >= 18 then
                            xPos = xPos + (largeGap - iconGap) + (largeGap - iconGap)
                        end

                        local iconFrame = CreateFrame("Button", nil, charRow.expandedFrame, "BackdropTemplate")
                        iconFrame:SetSize(iconSize, iconSize)
                        iconFrame:SetPoint("TOPLEFT", charRow.expandedFrame, "TOPLEFT", xPos, startY)

                        local iconTexture = iconFrame:CreateTexture(nil, "BACKGROUND")
                        iconTexture:SetAllPoints(iconFrame)

                        local borderFrame = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
                        borderFrame:SetAllPoints(iconFrame)
                        borderFrame:SetFrameLevel(iconFrame:GetFrameLevel() + 1)

                        local ilvlText = iconFrame:CreateFontString(nil, "OVERLAY")
                        ilvlText:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
                        ilvlText:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2, 2)
                        ilvlText:SetTextColor(1, 1, 1, 1)
                        ilvlText:SetShadowColor(0, 0, 0, 1)
                        ilvlText:SetShadowOffset(1, -1)

                        if item and item.itemLink then
                            local itemTexture = GetItemIcon(item.itemID)
                            if itemTexture then
                                iconTexture:SetTexture(itemTexture)
                            else
                                iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                            end

                            if item.itemLevel and item.itemLevel > 0 then
                                ilvlText:SetText(tostring(item.itemLevel))
                            else
                                ilvlText:SetText("")
                            end

                            local qualityColors = {
                                [0] = {0.6, 0.6, 0.6, 1},
                                [1] = {1, 1, 1, 1},
                                [2] = {0.12, 1, 0, 1},
                                [3] = {0, 0.44, 0.87, 1},
                                [4] = {0.64, 0.21, 0.93, 1},
                                [5] = {1, 0.5, 0, 1},
                                [6] = {0.9, 0.8, 0.5, 1},
                                [7] = {0.41, 0.8, 0.94, 1}
                            }

                            local quality = item.quality or 1
                            local color = qualityColors[quality] or qualityColors[1]
                            borderFrame:SetBackdrop({
                                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                                edgeSize = 12,
                                insets = { left = 2, right = 2, top = 2, bottom = 2 }
                            })
                            borderFrame:SetBackdropBorderColor(color[1], color[2], color[3], color[4])

                            iconFrame:SetScript("OnEnter", function(self)
                                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                GameTooltip:SetHyperlink(item.itemLink)
                                GameTooltip:Show()
                            end)

                            iconFrame:SetScript("OnLeave", function(self)
                                GameTooltip:Hide()
                            end)
                        else
                            iconTexture:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
                            ilvlText:SetText("")

                            borderFrame:SetBackdrop({
                                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                                edgeSize = 12,
                                insets = { left = 2, right = 2, top = 2, bottom = 2 }
                            })
                            borderFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
                        end
                    end
                end
            end
            charRow.expandedFrame:Show()
        end

        local function RepositionAllRows()
            local yOffset = -5
            local rowHeight = 32
            local rowGap = 2

            for _, row in ipairs(characterRows) do
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
                row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
                yOffset = yOffset - (rowHeight + rowGap)

                if row.isExpanded and row.expandedFrame and row.expandedFrame:IsShown() then
                    local expandedHeight = row.expandedFrame:GetHeight()
                    yOffset = yOffset - (expandedHeight + rowGap)
                end
            end

            local totalHeight = math.abs(yOffset) + 50
            scrollContent:SetHeight(totalHeight)
        end

        local function ToggleExpanded()
            local isExpanded = charRow.isExpanded or false
            charRow.isExpanded = not isExpanded

            if charRow.isExpanded then
                expandIcon:SetAtlas("Gamepad_Rev_Minus_64")
                CreateExpandedDetails()
            else
                expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
                if charRow.expandedFrame then
                    charRow.expandedFrame:Hide()
                end
            end

            RepositionAllRows()
        end

        expandBtn:SetScript("OnClick", ToggleExpanded)

        local factionIcon = charRow:CreateTexture(nil, "ARTWORK")
        factionIcon:SetSize(18, 18)
        if charData.faction == "Alliance" then
            factionIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
        elseif charData.faction == "Horde" then
            factionIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-Horde")
        else
            factionIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
            factionIcon:SetDesaturated(true)
        end
        table.insert(charRow.cells, factionIcon)

        local mailIcon = charRow:CreateTexture(nil, "ARTWORK")
        mailIcon:SetSize(16, 16)
        mailIcon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
        local hasMail = false
        if StorageAPI then
            local mailData = StorageAPI.GetMail(charKey)
            hasMail = mailData and mailData.hasNewMail
        end
        if hasMail then
            mailIcon:SetVertexColor(1, 1, 0, 1)
        else
            mailIcon:SetVertexColor(0.3, 0.3, 0.3, 0.5)
        end
        table.insert(charRow.cells, mailIcon)

        local nameText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetText(charData.name or charKey)
        local classColor = RAID_CLASS_COLORS[charData.class]
        if classColor then
            nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            nameText:SetTextColor(1, 1, 1)
        end
        nameText:SetJustifyH("LEFT")
        table.insert(charRow.cells, nameText)

        local levelText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        levelText:SetText(tostring(charData.level or 0))
        levelText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, levelText)

        local ilvlText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local ilvl = charData.itemLevel or 0
        ilvlText:SetText(tostring(ilvl))
        ilvlText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, ilvlText)

        if ilvl > 0 then
            totalILevel = totalILevel + ilvl
            charCount = charCount + 1
        end

        local equipment = (_G.OneWoW_AltTracker_Character_DB.characters[charKey] and _G.OneWoW_AltTracker_Character_DB.characters[charKey].equipment)

        local totalDurability = 0
        local durabilityItems = 0
        local missingEnchants = 0
        local totalEnchantableSlots = 0
        local missingGems = 0
        local totalGemSlots = 0
        local tierCount = 0
        local tierPieces = {}
        local embellishmentCount = 0

        if equipment then
            local enchantableSlots = {
                [5] = true,
                [8] = true,
                [9] = true,
                [10] = true,
                [11] = true,
                [12] = true,
                [15] = true,
                [16] = true,
                [17] = true
            }

            for slotId = 1, 19 do
                if slotId ~= 4 and slotId ~= 18 and slotId ~= 19 then
                    local item = equipment[slotId]
                    if item and item.itemLink then
                        if item.durability and item.maxDurability then
                            totalDurability = totalDurability + (item.durability / item.maxDurability * 100)
                            durabilityItems = durabilityItems + 1
                        end

                        if enchantableSlots[slotId] and charData.level and charData.level >= 70 then
                            if item.quality and item.quality >= 3 then
                                totalEnchantableSlots = totalEnchantableSlots + 1
                                local enchantId = item.itemLink:match("item:%d+:(%d+)")
                                if not enchantId or enchantId == "0" or enchantId == "" then
                                    missingEnchants = missingEnchants + 1
                                end
                            end
                        end

                        local itemSockets = item.numSockets or 0
                        totalGemSlots = totalGemSlots + itemSockets
                        missingGems = missingGems + math.max(0, itemSockets - (item.socketsWithGems or 0))

                        if item.name then
                            if item.name:find("Hollow Sentinel's") or
                               item.name:find("Charhound's Vicious") or
                               item.name:find("Mother Eagle") or
                               item.name:find("Skymane of the") or
                               item.name:find("Spellweaver's Immaculate") or
                               item.name:find("Midnight Herald's") or
                               item.name:find("Augur's Ephemeral") or
                               item.name:find("Fallen Storms") or
                               item.name:find("Lucent Battalion") or
                               item.name:find("Dying Star's") or
                               item.name:find("Sudden Eclipse") or
                               item.name:find("Channeled Fury") or
                               item.name:find("Inquisitor's") or
                               item.name:find("Living Weapon's") then
                                tierCount = tierCount + 1
                                table.insert(tierPieces, item.name)
                            end
                        end
                    end
                end
            end
        end

        local durabilityPct = 100
        if durabilityItems > 0 then
            durabilityPct = math.floor(totalDurability / durabilityItems)
        end

        local durabilityText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        durabilityText:SetText(durabilityPct .. "%")
        if durabilityPct < 30 then
            durabilityText:SetTextColor(1, 0.34, 0.13)
        elseif durabilityPct < 70 then
            durabilityText:SetTextColor(1, 1, 0)
        else
            durabilityText:SetTextColor(0.30, 0.69, 0.31)
        end
        durabilityText:SetJustifyH("CENTER")
        table.insert(charRow.cells, durabilityText)

        local enchantsCell = CreateFrame("Frame", nil, charRow)
        enchantsCell:SetHeight(32)
        enchantsCell:EnableMouse(true)
        enchantsCell:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                ToggleExpanded()
            end
        end)
        enchantsCell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if missingEnchants > 0 then
                GameTooltip:SetText(string.format(L["TT_ENCHANTS_MISSING_OF"], missingEnchants, totalEnchantableSlots), 1, 0.35, 0.13)
            else
                GameTooltip:SetText(string.format(L["TT_ENCHANTS_ALL_OK"], totalEnchantableSlots), 0.30, 0.69, 0.31)
            end
            GameTooltip:AddLine(L["TT_ENCHANTS_SLOT_LIST"], 1, 1, 1)
            GameTooltip:AddLine(L["TT_ENCHANTS_QUALITY_NOTE"], 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        enchantsCell:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        local enchantsText = enchantsCell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        enchantsText:SetPoint("CENTER", enchantsCell, "CENTER", 0, 0)
        if missingEnchants > 0 then
            enchantsText:SetText(tostring(missingEnchants))
            if missingEnchants >= 5 then
                enchantsText:SetTextColor(1, 0.34, 0.13)
            else
                enchantsText:SetTextColor(1, 1, 0)
            end
        else
            enchantsText:SetText("0")
            enchantsText:SetTextColor(0.30, 0.69, 0.31)
        end
        table.insert(charRow.cells, enchantsCell)

        local gemsCell = CreateFrame("Frame", nil, charRow)
        gemsCell:SetHeight(32)
        gemsCell:EnableMouse(true)
        gemsCell:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                ToggleExpanded()
            end
        end)
        gemsCell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if missingGems > 0 then
                GameTooltip:SetText(string.format(L["TT_GEMS_MISSING_OF"], missingGems, totalGemSlots), 1, 0.35, 0.13)
            else
                GameTooltip:SetText(string.format(L["TT_GEMS_ALL_OK"], totalGemSlots), 0.30, 0.69, 0.31)
            end
            GameTooltip:Show()
        end)
        gemsCell:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        local gemsText = gemsCell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        gemsText:SetPoint("CENTER", gemsCell, "CENTER", 0, 0)
        if missingGems > 0 then
            gemsText:SetText(tostring(missingGems))
            if missingGems >= 5 then
                gemsText:SetTextColor(1, 0.34, 0.13)
            else
                gemsText:SetTextColor(1, 1, 0)
            end
        else
            gemsText:SetText("0")
            gemsText:SetTextColor(0.30, 0.69, 0.31)
        end
        table.insert(charRow.cells, gemsCell)

        local tierCell = CreateFrame("Frame", nil, charRow)
        tierCell:SetHeight(32)
        tierCell:EnableMouse(true)
        tierCell:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                ToggleExpanded()
            end
        end)
        tierCell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if tierCount >= 5 then
                GameTooltip:SetText(string.format(L["TT_TIER_TITLE"], tierCount), 0.30, 0.69, 0.31)
            elseif tierCount > 0 then
                GameTooltip:SetText(string.format(L["TT_TIER_TITLE"], tierCount), 1, 1, 0)
            else
                GameTooltip:SetText(string.format(L["TT_TIER_TITLE"], tierCount), 1, 0.34, 0.13)
            end
            if #tierPieces > 0 then
                GameTooltip:AddLine(L["TT_TIER_FOUND"], 1, 1, 1)
                for _, pieceName in ipairs(tierPieces) do
                    GameTooltip:AddLine("  " .. pieceName, 1, 0.82, 0)
                end
            end
            GameTooltip:AddLine(L["TT_TIER_TRACKING"], 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        tierCell:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        local tierSetText = tierCell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tierSetText:SetPoint("CENTER", tierCell, "CENTER", 0, 0)
        tierSetText:SetText(tierCount .. "/5")
        if tierCount == 0 then
            tierSetText:SetTextColor(1, 0.34, 0.13)
        elseif tierCount < 5 then
            tierSetText:SetTextColor(1, 1, 0)
        else
            tierSetText:SetTextColor(0.30, 0.69, 0.31)
        end
        table.insert(charRow.cells, tierCell)

        local strText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        strText:SetText(tostring((charData.stats and charData.stats.strength) or 0))
        strText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, strText)

        local agiText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        agiText:SetText(tostring((charData.stats and charData.stats.agility) or 0))
        agiText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, agiText)

        local staText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        staText:SetText(tostring((charData.stats and charData.stats.stamina) or 0))
        staText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, staText)

        local intText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        intText:SetText(tostring((charData.stats and charData.stats.intellect) or 0))
        intText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, intText)

        local armorText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        armorText:SetText(tostring((charData.stats and charData.stats.armor) or 0))
        armorText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, armorText)

        local apText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        apText:SetText(tostring((charData.stats and charData.stats.attackPower) or 0))
        apText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, apText)

        local critText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local critValue = (charData.stats and charData.stats.critChance) or 0
        critText:SetText(string.format("%.1f%%", critValue))
        critText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, critText)

        local hasteText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local hasteValue = (charData.stats and charData.stats.haste) or 0
        hasteText:SetText(string.format("%.1f%%", hasteValue))
        hasteText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, hasteText)

        local masteryText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local masteryValue = (charData.stats and charData.stats.mastery) or 0
        masteryText:SetText(string.format("%.1f%%", masteryValue))
        masteryText:SetTextColor(T("TEXT_PRIMARY"))
        masteryText:SetJustifyH("CENTER")
        table.insert(charRow.cells, masteryText)

        local versText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local versValue = (charData.stats and charData.stats.versatility) or 0
        versText:SetText(string.format("%.1f%%", versValue))
        versText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, versText)

        local statusCell = CreateFrame("Frame", nil, charRow)
        statusCell:SetHeight(32)
        statusCell:EnableMouse(true)
        statusCell:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                ToggleExpanded()
            end
        end)
        statusCell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if durabilityPct < 30 or missingEnchants >= 5 or missingGems >= 5 then
                GameTooltip:SetText(L["STATUS_ATTENTION"], 1, 0.34, 0.13)
            elseif missingEnchants > 0 or missingGems > 0 or durabilityPct < 70 then
                GameTooltip:SetText(L["STATUS_REVIEW"], 1, 1, 0)
            else
                GameTooltip:SetText(L["STATUS_OK"], 0.30, 0.69, 0.31)
            end
            if durabilityPct < 70 then
                GameTooltip:AddLine(string.format(L["TT_STATUS_REASON_DUR"], durabilityPct), 1, 1, 1)
            end
            if missingEnchants > 0 then
                GameTooltip:AddLine(string.format(L["TT_STATUS_REASON_ENCHANT"], missingEnchants), 1, 1, 1)
            end
            if missingGems > 0 then
                GameTooltip:AddLine(string.format(L["TT_STATUS_REASON_GEM"], missingGems), 1, 1, 1)
            end
            if durabilityPct >= 70 and missingEnchants == 0 and missingGems == 0 then
                GameTooltip:AddLine(L["TT_STATUS_ALL_OK"], 0.30, 0.69, 0.31)
            end
            GameTooltip:Show()
        end)
        statusCell:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        local statusText = statusCell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statusText:SetPoint("LEFT", statusCell, "LEFT", 0, 0)
        if durabilityPct < 30 or missingEnchants >= 5 or missingGems >= 5 then
            statusText:SetText(L["STATUS_ATTENTION"])
            statusText:SetTextColor(1, 0.34, 0.13)
        elseif missingEnchants > 0 or missingGems > 0 or durabilityPct < 70 then
            statusText:SetText(L["STATUS_REVIEW"])
            statusText:SetTextColor(1, 1, 0)
        else
            statusText:SetText(L["STATUS_OK"])
            statusText:SetTextColor(0.30, 0.69, 0.31)
        end
        table.insert(charRow.cells, statusCell)

        charRow:EnableMouse(true)
        charRow:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)

        charRow:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
        end)

        charRow:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                ToggleExpanded()
            end
        end)

        local headerRow = equipmentTab.headerRow
        if headerRow and headerRow.columnButtons then
            for i, cell in ipairs(charRow.cells) do
                local btn = headerRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX

                    cell:ClearAllPoints()

                    if i == 1 then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", charRow, "LEFT", x, 0)
                    elseif i == 2 or i == 3 then
                        cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
                    else
                        cell:SetWidth(width - 6)
                        if i == 4 or i == 21 then
                            cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
                        else
                            cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
                        end
                    end
                end
            end
        end

        charRow:Show()
        table.insert(characterRows, charRow)
        yOffset = yOffset - (rowHeight + rowGap)
    end

    local newHeight = math.max(400, #characterRows * (rowHeight + rowGap) + 10)
    scrollContent:SetHeight(newHeight)

    if equipmentTab.statusText then
        equipmentTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], #allChars, ""))
    end

    ns.UI.RefreshEquipmentStats(equipmentTab, allChars, charCount, totalILevel)

    C_Timer.After(0.1, function()
        if equipmentTab.headerRow then
            equipmentTab.headerRow:GetScript("OnSizeChanged")(equipmentTab.headerRow)
        end
    end)
end

function ns.UI.RefreshEquipmentStats(equipmentTab, allChars, charCount, totalILevel)
    if not equipmentTab or not equipmentTab.statBoxes then return end

    local stats = {
        attention = 0,
        characters = #allChars,
        avgIlvl = 0,
        highestIlvl = 0,
        lowestIlvl = 999,
        missingEnchants = 0,
        missingGems = 0,
        lowDurability = 0,
        upgradeReady = 0,
        tierSets = 0
    }

    if charCount > 0 then
        stats.avgIlvl = math.floor(totalILevel / charCount)
    end

    for _, charInfo in ipairs(allChars) do
        local charData = charInfo.data
        local charKey = charInfo.key
        local equipment = (_G.OneWoW_AltTracker_Character_DB.characters[charKey] and _G.OneWoW_AltTracker_Character_DB.characters[charKey].equipment)

        local ilvl = charData.itemLevel or 0
        if ilvl > 0 then
            if ilvl > stats.highestIlvl then
                stats.highestIlvl = ilvl
            end
            if ilvl < stats.lowestIlvl then
                stats.lowestIlvl = ilvl
            end
        end

        if equipment then
            local enchantableSlots = {
                [5] = true, [8] = true, [9] = true, [10] = true,
                [11] = true, [12] = true, [15] = true, [16] = true, [17] = true
            }

            local charMissingEnchants = 0
            local charMissingGems = 0
            local charLowDurability = 0
            local charTierCount = 0

            for slotId = 1, 19 do
                if slotId ~= 4 and slotId ~= 18 and slotId ~= 19 then
                    local item = equipment[slotId]
                    if item and item.itemLink then
                        if item.durability and item.maxDurability then
                            if item.durability < item.maxDurability * 0.3 then
                                charLowDurability = charLowDurability + 1
                            end
                        end

                        if enchantableSlots[slotId] and charData.level and charData.level >= 70 then
                            if item.quality and item.quality >= 3 then
                                local enchantId = item.itemLink:match("item:%d+:(%d+)")
                                if not enchantId or enchantId == "0" or enchantId == "" then
                                    charMissingEnchants = charMissingEnchants + 1
                                end
                            end
                        end

                        charMissingGems = charMissingGems + math.max(0, (item.numSockets or 0) - (item.socketsWithGems or 0))

                        if item.name then
                            if item.name:find("Hollow Sentinel's") or
                               item.name:find("Charhound's Vicious") or
                               item.name:find("Mother Eagle") or
                               item.name:find("Skymane of the") or
                               item.name:find("Spellweaver's Immaculate") or
                               item.name:find("Midnight Herald's") or
                               item.name:find("Augur's Ephemeral") or
                               item.name:find("Fallen Storms") or
                               item.name:find("Lucent Battalion") or
                               item.name:find("Dying Star's") or
                               item.name:find("Sudden Eclipse") or
                               item.name:find("Channeled Fury") or
                               item.name:find("Inquisitor's") or
                               item.name:find("Living Weapon's") then
                                charTierCount = charTierCount + 1
                            end
                        end
                    end
                end
            end

            if charMissingEnchants > 0 then
                stats.missingEnchants = stats.missingEnchants + 1
            end
            if charMissingGems > 0 then
                stats.missingGems = stats.missingGems + 1
            end
            if charLowDurability >= 3 then
                stats.lowDurability = stats.lowDurability + 1
            end
            if charTierCount >= 2 then
                stats.tierSets = stats.tierSets + 1
            end

            if charLowDurability >= 3 or charMissingEnchants >= 5 or charMissingGems >= 5 then
                stats.attention = stats.attention + 1
            end
        end
    end

    if stats.lowestIlvl == 999 then
        stats.lowestIlvl = 0
    end

    local statBoxes = equipmentTab.statBoxes
    if statBoxes then
        if statBoxes[1] then statBoxes[1].value:SetText(tostring(stats.attention)) end
        if statBoxes[2] then statBoxes[2].value:SetText(tostring(stats.characters)) end
        if statBoxes[3] then statBoxes[3].value:SetText(tostring(stats.avgIlvl)) end
        if statBoxes[4] then statBoxes[4].value:SetText(tostring(stats.highestIlvl)) end
        if statBoxes[5] then statBoxes[5].value:SetText(tostring(stats.lowestIlvl)) end
        if statBoxes[6] then statBoxes[6].value:SetText(tostring(stats.missingEnchants)) end
        if statBoxes[7] then statBoxes[7].value:SetText(tostring(stats.missingGems)) end
        if statBoxes[8] then statBoxes[8].value:SetText(tostring(stats.lowDurability)) end
        if statBoxes[9] then statBoxes[9].value:SetText(tostring(stats.upgradeReady)) end
        if statBoxes[10] then statBoxes[10].value:SetText(tostring(stats.tierSets)) end
    end
end
