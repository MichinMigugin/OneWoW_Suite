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

function ns.UI.CreateSummaryTab(parent)
    -- Account Overview Panel (Control Panel at top)
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
    overviewTitle:SetText(L["ACCOUNT_OVERVIEW"])
    overviewTitle:SetTextColor(T("ACCENT_PRIMARY"))

    -- Stats grid (2 rows x 5 columns) with more vertical space
    local statsContainer = CreateFrame("Frame", nil, overviewPanel)
    statsContainer:SetPoint("TOPLEFT", overviewTitle, "BOTTOMLEFT", 0, -8)
    statsContainer:SetPoint("BOTTOMRIGHT", overviewPanel, "BOTTOMRIGHT", -10, 6)

    local statLabels = {
        L["ATTENTION"], L["CHARACTERS"], L["TOTAL_GOLD"], L["FACTIONS"], L["RESTED"],
        L["PLAYTIME"], L["MOUNTS"], L["PETS"], L["PRIMARY_PROFESSIONS"], L["ACHIEVEMENTS"]
    }

    local statTooltipTitles = {
        L["TT_ATTENTION"], L["TT_CHARACTERS"], L["TT_TOTAL_GOLD"], L["TT_FACTIONS"], L["TT_RESTED"],
        L["TT_PLAYTIME"], L["TT_MOUNTS"], L["TT_PETS"], L["TT_PRIMARY_PROFESSIONS"], L["TT_ACHIEVEMENTS"]
    }

    local statTooltips = {
        L["TT_ATTENTION_DESC"], L["TT_CHARACTERS_DESC"], L["TT_TOTAL_GOLD_DESC"], L["TT_FACTIONS_DESC"], L["TT_RESTED_DESC"],
        L["TT_PLAYTIME_DESC"], L["TT_MOUNTS_DESC"], L["TT_PETS_DESC"], L["TT_PRIMARY_PROFESSIONS_DESC"], L["TT_ACHIEVEMENTS_DESC"]
    }

    local statValues = {
        "0", "0", "0g", "0/0", "0",
        "0h", "0/0", "0/0", "0/11", "0"
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

    -- Character Roster Panel
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

    -- Column definitions with 4px gaps
    local columns = {
        {key = "expand", label = "", width = 25, fixed = true, ttTitle = L["TT_COL_EXPAND"], ttDesc = L["TT_COL_EXPAND_DESC"]},
        {key = "faction", label = L["COL_FACTION"], width = 25, fixed = true, ttTitle = L["TT_COL_FACTION"], ttDesc = L["TT_COL_FACTION_DESC"]},
        {key = "mail", label = L["COL_MAIL"], width = 35, fixed = true, ttTitle = L["TT_COL_MAIL"], ttDesc = L["TT_COL_MAIL_DESC"]},
        {key = "name", label = L["COL_CHARACTER"], width = 101, fixed = false, ttTitle = L["TT_COL_CHARACTER"], ttDesc = L["TT_COL_CHARACTER_DESC"]},
        {key = "server", label = L["COL_SERVER"], width = 50, fixed = false, ttTitle = L["TT_COL_SERVER"], ttDesc = L["TT_COL_SERVER_DESC"]},
        {key = "level", label = L["COL_LEVEL"], width = 40, fixed = true, ttTitle = L["TT_COL_LEVEL"], ttDesc = L["TT_COL_LEVEL_DESC"]},
        {key = "class", label = L["COL_CLASS"], width = 60, fixed = false, ttTitle = L["TT_COL_CLASS"], ttDesc = L["TT_COL_CLASS_DESC"]},
        {key = "spec", label = L["COL_SPEC"], width = 70, fixed = false, ttTitle = L["TT_COL_SPEC"], ttDesc = L["TT_COL_SPEC_DESC"]},
        {key = "rested", label = L["COL_RESTED_XP"], width = 50, fixed = true, ttTitle = L["TT_COL_RESTED_XP"], ttDesc = L["TT_COL_RESTED_XP_DESC"]},
        {key = "itemLevel", label = L["COL_ITEM_LEVEL"], width = 50, fixed = true, ttTitle = L["TT_COL_ITEM_LEVEL"], ttDesc = L["TT_COL_ITEM_LEVEL_DESC"]},
        {key = "bags", label = L["COL_BAGS"], width = 40, fixed = true, ttTitle = L["TT_COL_BAGS"], ttDesc = L["TT_COL_BAGS_DESC"]},
        {key = "money", label = L["COL_GOLD"], width = 90, fixed = false, ttTitle = L["TT_COL_GOLD"], ttDesc = L["TT_COL_GOLD_DESC"]},
        {key = "hearth", label = L["COL_HEARTH"], width = 80, fixed = false, ttTitle = L["TT_COL_HEARTH"], ttDesc = L["TT_COL_HEARTH_DESC"]},
        {key = "lastSeen", label = L["COL_LAST_SEEN"], width = 80, fixed = false, ttTitle = L["TT_COL_LAST_SEEN"], ttDesc = L["TT_COL_LAST_SEEN_DESC"]}
    }

    local colGap = 4
    headerRow.columnButtons = {}
    headerRow.columns = columns

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
                            if i == 4 or i == 5 or i == 7 or i == 8 or i == 13 or i == 14 then
                                cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
                            elseif i == 12 then
                                cell:SetPoint("RIGHT", charRow, "LEFT", x + width - 3, 0)
                            else
                                cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
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

        local fixedWidth = 0
        local flexCount = 0
        for _, col in ipairs(columns) do
            if col.fixed then
                fixedWidth = fixedWidth + col.width
            else
                flexCount = flexCount + 1
            end
        end

        local totalGaps = (#columns - 1) * colGap
        local remainingWidth = availableWidth - fixedWidth - totalGaps
        local flexWidth = flexCount > 0 and math.max(0, remainingWidth / flexCount) or 0

        local xOffset = 5
        local visibleButtons = {}
        for i, col in ipairs(columns) do
            local btn = headerRow.columnButtons[i]
            if btn then
                local width = col.fixed and col.width or math.max(col.width, flexWidth)
                btn.columnWidth = width
                btn.columnX = xOffset
                table.insert(visibleButtons, {btn = btn, width = width, xOffset = xOffset})
                xOffset = xOffset + width + colGap
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
    end

    -- Create column header buttons
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
                ns.UI.RefreshSummaryTab(parent)
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

    -- Status Bar
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
    statusText:SetText(string.format(L["CHARACTERS_TRACKED"], 1, ""))
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

    C_Timer.After(0.5, function()
        if ns.UI.RefreshSummaryTab then
            ns.UI.RefreshSummaryTab(parent)
        end
    end)
end

function ns.UI.RefreshSummaryTab(summaryTab)
    if not summaryTab then
        return
    end

    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then
        return
    end

    local allChars = {}
    for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
        table.insert(allChars, {
            key = charKey,
            data = charData
        })
    end

    if #allChars == 0 then
        return
    end

    local currentChar = UnitName("player")
    local currentRealm = GetRealmName()
    local currentCharKey = currentChar .. "-" .. currentRealm

    local liveChar = _G.OneWoW_AltTracker_Character_DB.characters[currentCharKey]
    if liveChar then
        if not liveChar.xp then liveChar.xp = {} end
        liveChar.xp.currentXP = UnitXP("player")
        liveChar.xp.maxXP = UnitXPMax("player")
        liveChar.xp.restedXP = GetXPExhaustion() or 0
        liveChar.xp.restState = GetRestState()
        liveChar.xp.isResting = IsResting()
        liveChar.xp.isXPDisabled = IsXPUserDisabled()
    end

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
            elseif currentSortColumn == "server" then
                aVal = a.data.realm or ""
                bVal = b.data.realm or ""
            elseif currentSortColumn == "level" then
                aVal = a.data.level or 0
                bVal = b.data.level or 0
            elseif currentSortColumn == "class" then
                aVal = a.data.className or ""
                bVal = b.data.className or ""
            elseif currentSortColumn == "spec" then
                local aSpec = a.data.stats and a.data.stats.specName
                local bSpec = b.data.stats and b.data.stats.specName
                aVal = type(aSpec) == "string" and aSpec or (type(aSpec) == "table" and (aSpec.name or "") or "")
                bVal = type(bSpec) == "string" and bSpec or (type(bSpec) == "table" and (bSpec.name or "") or "")
            elseif currentSortColumn == "rested" then
                local aRested = 0
                if a.data.xp and a.data.xp.restedXP and a.data.xp.maxXP and a.data.xp.maxXP > 0 then
                    aRested = (a.data.xp.restedXP / a.data.xp.maxXP) * 100
                end
                local bRested = 0
                if b.data.xp and b.data.xp.restedXP and b.data.xp.maxXP and b.data.xp.maxXP > 0 then
                    bRested = (b.data.xp.restedXP / b.data.xp.maxXP) * 100
                end
                aVal = aRested
                bVal = bRested
            elseif currentSortColumn == "itemLevel" then
                aVal = a.data.itemLevel or 0
                bVal = b.data.itemLevel or 0
            elseif currentSortColumn == "bags" then
                aVal = 0
                bVal = 0
            elseif currentSortColumn == "money" then
                aVal = a.data.money or 0
                bVal = b.data.money or 0
            elseif currentSortColumn == "hearth" then
                aVal = (a.data.location and a.data.location.bindLocation) or ""
                bVal = (b.data.location and b.data.location.bindLocation) or ""
            elseif currentSortColumn == "lastSeen" then
                aVal = a.data.lastLogin or 0
                bVal = b.data.lastLogin or 0
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

    local scrollContent = summaryTab.scrollContent
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
                if not charRow.expandedFrame then
                    charRow.expandedFrame = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
                    charRow.expandedFrame:SetPoint("TOPLEFT", charRow, "BOTTOMLEFT", 0, -2)
                    charRow.expandedFrame:SetPoint("TOPRIGHT", charRow, "BOTTOMRIGHT", 0, -2)
                    charRow.expandedFrame:SetHeight(50)
                    charRow.expandedFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                    charRow.expandedFrame:SetBackdropColor(T("BG_SECONDARY"))

                    local leftCol = charRow.expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    leftCol:SetPoint("LEFT", charRow.expandedFrame, "LEFT", 15, 0)
                    leftCol:SetJustifyH("LEFT")
                    leftCol:SetTextColor(T("TEXT_PRIMARY"))

                    local rightCol = charRow.expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    rightCol:SetPoint("LEFT", charRow.expandedFrame, "CENTER", 15, 0)
                    rightCol:SetJustifyH("LEFT")
                    rightCol:SetTextColor(T("TEXT_PRIMARY"))

                    local totalTime = (charData.playTime and charData.playTime.total) or 0
                    local days = math.floor(totalTime / 86400)
                    local hours = math.floor((totalTime % 86400) / 3600)
                    local playtimeText = string.format("%d days, %d hours", days, hours)

                    local restedPercent = 0
                    if charData.xp and charData.xp.restedXP and charData.xp.maxXP and charData.xp.maxXP > 0 then
                        restedPercent = math.min(200, math.floor((charData.xp.restedXP / (charData.xp.maxXP * 1.5)) * 200))
                    end

                    local guildName = L["EXPANDED_NO_GUILD"]
                    local guildRank = ""
                    if charData.guild and charData.guild.name then
                        guildName = charData.guild.name
                        guildRank = charData.guild.rank or ""
                    end

                    leftCol:SetText(string.format("%s %s\n%s %s",
                        L["EXPANDED_TOTAL_PLAYTIME"], playtimeText,
                        L["EXPANDED_GUILD"], guildName))

                    rightCol:SetText(string.format("%s %d%%\n%s %s",
                        L["EXPANDED_RESTED_XP"], restedPercent,
                        L["EXPANDED_GUILD_RANK"], guildRank))

                    charRow.expandedFrame.leftCol = leftCol
                    charRow.expandedFrame.rightCol = rightCol
                end
                charRow.expandedFrame:Show()
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

        local nameFrame = CreateFrame("Frame", nil, charRow)
        nameFrame:SetAllPoints(nameText)
        nameFrame:EnableMouse(true)
        nameFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(charData.name or charKey, 1, 1, 1)

            if charData.guid then
                GameTooltip:AddLine(L["TT_CHAR_GUID"] .. " " .. charData.guid, 0.7, 0.7, 0.7, true)
            end

            if charData.sex then
                if charData.sex == 2 then
                    GameTooltip:AddLine(L["TT_CHAR_GENDER_MALE"], 0.7, 0.7, 0.7)
                elseif charData.sex == 3 then
                    GameTooltip:AddLine(L["TT_CHAR_GENDER_FEMALE"], 0.7, 0.7, 0.7)
                end
            end

            if charData.title then
                GameTooltip:AddLine(L["TT_CHAR_TITLE"] .. " " .. charData.title, 0.7, 0.7, 0.7, true)
            else
                GameTooltip:AddLine(L["TT_CHAR_NO_TITLE"], 0.5, 0.5, 0.5)
            end

            GameTooltip:Show()
        end)
        nameFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        table.insert(charRow.cells, nameText)

        local realmText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        realmText:SetText(charData.realm or "")
        realmText:SetTextColor(T("TEXT_SECONDARY"))
        realmText:SetJustifyH("LEFT")
        table.insert(charRow.cells, realmText)

        local levelContainer = CreateFrame("Frame", nil, charRow)
        levelContainer:SetSize(40, rowHeight)

        local level = charData.level or 0
        local isMaxLevel = (level >= 90)
        local xpDisabled = charData.xp and charData.xp.isXPDisabled

        if isMaxLevel then
            local levelText = levelContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            levelText:SetPoint("CENTER")
            levelText:SetText(L["LEVEL_MAX"])
            levelText:SetTextColor(1, 0.82, 0)
        else
            local iconTexture = levelContainer:CreateTexture(nil, "ARTWORK")
            iconTexture:SetSize(10, 10)
            iconTexture:SetPoint("LEFT", levelContainer, "LEFT", 3, 0)

            if xpDisabled then
                iconTexture:SetAtlas("transmog-icon-invalid")
                iconTexture:SetVertexColor(1, 0.2, 0.2)
            else
                iconTexture:SetAtlas("common-icon-checkmark")
                iconTexture:SetVertexColor(0.3, 1, 0.3)
            end

            local levelText = levelContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            levelText:SetPoint("LEFT", iconTexture, "RIGHT", 2, 0)
            levelText:SetText(tostring(level))
            levelText:SetTextColor(T("TEXT_PRIMARY"))
        end

        levelContainer:EnableMouse(true)
        levelContainer:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["COL_LEVEL"], 1, 1, 1)

            if isMaxLevel then
                GameTooltip:AddLine(L["TT_LEVEL_XP_ENABLED"], 0.5, 1, 0.5)
            elseif xpDisabled then
                GameTooltip:AddLine(L["TT_LEVEL_XP_DISABLED"], 1, 0.5, 0.5)
            else
                GameTooltip:AddLine(L["TT_LEVEL_XP_ENABLED"], 0.5, 1, 0.5)
            end

            GameTooltip:Show()
        end)
        levelContainer:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        table.insert(charRow.cells, levelContainer)

        local classText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        classText:SetText(charData.className or charData.class or "")
        classText:SetTextColor(T("TEXT_PRIMARY"))
        classText:SetJustifyH("LEFT")
        table.insert(charRow.cells, classText)

        local specText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local specName = (charData.stats and charData.stats.specName) or ""
        specText:SetText(tostring(specName or ""))
        specText:SetTextColor(T("TEXT_PRIMARY"))
        specText:SetJustifyH("LEFT")

        local specFrame = CreateFrame("Frame", nil, charRow)
        specFrame:SetAllPoints(specText)
        specFrame:EnableMouse(true)
        specFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tostring(specName or ""), 1, 1, 1)

            if charData.stats and charData.stats.specRole then
                local roleText = charData.stats.specRole
                if roleText == "TANK" then
                    GameTooltip:AddLine(L["TT_SPEC_ROLE"] .. " " .. L["TT_SPEC_ROLE_TANK"], 0.5, 0.8, 1)
                elseif roleText == "HEALER" then
                    GameTooltip:AddLine(L["TT_SPEC_ROLE"] .. " " .. L["TT_SPEC_ROLE_HEALER"], 0.3, 1, 0.3)
                elseif roleText == "DAMAGER" then
                    GameTooltip:AddLine(L["TT_SPEC_ROLE"] .. " " .. L["TT_SPEC_ROLE_DAMAGER"], 1, 0.5, 0.5)
                end
            end

            if charData.stats and charData.stats.heroSpecName then
                GameTooltip:AddLine(L["TT_SPEC_HERO_SPEC"] .. " " .. charData.stats.heroSpecName, 0.9, 0.8, 0.5)
            else
                GameTooltip:AddLine(L["TT_SPEC_NO_HERO"], 0.5, 0.5, 0.5)
            end

            GameTooltip:Show()
        end)
        specFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        table.insert(charRow.cells, specText)

        local restedText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local restedPercent = 0
        if charData.xp and charData.xp.restedXP and charData.xp.maxXP and charData.xp.maxXP > 0 then
            restedPercent = math.min(200, math.floor((charData.xp.restedXP / (charData.xp.maxXP * 1.5)) * 200))
        end
        restedText:SetText(restedPercent .. "%")
        restedText:SetTextColor(0, 0.74, 0.83)

        local restedFrame = CreateFrame("Frame", nil, charRow)
        restedFrame:SetAllPoints(restedText)
        restedFrame:EnableMouse(true)
        restedFrame:SetScript("OnEnter", function(self)
            local level = charData.level or 0
            local isMaxLevel = (level >= 90)

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["COL_RESTED_XP"], 1, 1, 1)

            if not isMaxLevel and charData.xp and charData.xp.currentXP ~= nil and charData.xp.maxXP and charData.xp.maxXP > 0 then
                local currentXP = charData.xp.currentXP or 0
                local xpPercent = (currentXP / charData.xp.maxXP) * 100
                local xpNeeded = charData.xp.maxXP - currentXP
                GameTooltip:AddLine(L["TT_RESTED_XP_TO_LEVEL"] .. " " .. string.format("%.1f%%  (%s XP needed)", xpPercent, BreakUpLargeNumbers(xpNeeded)), 1, 1, 1)
            end

            if charData.xp and charData.xp.restedXP then
                local restedAmount = charData.xp.restedXP
                GameTooltip:AddLine(L["TT_RESTED_AMOUNT"] .. " " .. tostring(restedAmount), 0, 0.74, 0.83)
            end

            if charData.xp and charData.xp.restState then
                if charData.xp.restState == 1 then
                    GameTooltip:AddLine(L["TT_RESTED_STATE_RESTED"], 0.5, 1, 0.5)
                else
                    GameTooltip:AddLine(L["TT_RESTED_STATE_NORMAL"], 0.7, 0.7, 0.7)
                end
            end

            if charData.xp and charData.xp.isResting then
                GameTooltip:AddLine(L["TT_RESTED_IN_REST_AREA"], 0.5, 1, 0.5)
            else
                GameTooltip:AddLine(L["TT_RESTED_NOT_IN_REST_AREA"], 0.7, 0.7, 0.7)
            end

            GameTooltip:Show()
        end)
        restedFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        table.insert(charRow.cells, restedText)

        local ilvlText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local ilvl = charData.itemLevel or 0
        ilvlText:SetText(tostring(ilvl))
        if charData.itemLevelColor then
            ilvlText:SetTextColor(charData.itemLevelColor.r, charData.itemLevelColor.g, charData.itemLevelColor.b)
        else
            ilvlText:SetTextColor(T("TEXT_PRIMARY"))
        end
        table.insert(charRow.cells, ilvlText)

        local bagsText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local bagsFree, bagsTotal = 0, 0
        if StorageAPI then
            local bagsData = StorageAPI.GetBags(charKey)
            if bagsData then
                for bagID = 0, 4 do
                    if bagsData[bagID] then
                        local numSlots = bagsData[bagID].numSlots or 0
                        bagsTotal = bagsTotal + numSlots

                        local usedSlots = 0
                        if bagsData[bagID].slots then
                            for slotID, itemData in pairs(bagsData[bagID].slots) do
                                if itemData then
                                    usedSlots = usedSlots + 1
                                end
                            end
                        end
                        bagsFree = bagsFree + (numSlots - usedSlots)
                    end
                end
            end
        end
        bagsText:SetText(bagsFree)
        bagsText:SetTextColor(0.3, 1, 0.3)
        table.insert(charRow.cells, bagsText)

        local goldText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local money = charData.money or 0
        local goldFormatted = ns.AltTrackerFormatters and ns.AltTrackerFormatters.FormatGold and ns.AltTrackerFormatters:FormatGold(money)
        goldText:SetText(goldFormatted)
        goldText:SetTextColor(1, 0.82, 0)
        goldText:SetJustifyH("RIGHT")
        table.insert(charRow.cells, goldText)

        local hearthText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local hearthLocation = (charData.location and charData.location.bindLocation) or ""
        hearthText:SetText(hearthLocation)
        hearthText:SetTextColor(T("TEXT_PRIMARY"))
        hearthText:SetJustifyH("LEFT")
        table.insert(charRow.cells, hearthText)

        local lastSeenContainer = CreateFrame("Frame", nil, charRow)
        lastSeenContainer:SetSize(80, rowHeight)

        local lastSeenText = lastSeenContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lastSeenText:SetPoint("CENTER")

        local lastLogin = charData.lastLogin or 0
        local currentTime = time()
        local timeDiff = currentTime - lastLogin
        local lastSeenFormatted = ""

        local currentCharKey = UnitName("player") .. "-" .. GetRealmName()
        if charKey == currentCharKey then
            lastSeenFormatted = L["FMT_NOW"]
            lastSeenText:SetTextColor(0.3, 1, 0.3)
        elseif timeDiff < 60 then
            lastSeenFormatted = "1" .. L["FMT_MINUTE_SHORT"]
            lastSeenText:SetTextColor(0.5, 1, 0.5)
        elseif timeDiff < 3600 then
            local minutes = math.floor(timeDiff / 60)
            lastSeenFormatted = tostring(minutes) .. L["FMT_MINUTE_SHORT"]
            lastSeenText:SetTextColor(0.7, 1, 0.7)
        else
            local years = math.floor(timeDiff / 31536000)
            local days = math.floor((timeDiff % 31536000) / 86400)
            local hours = math.floor((timeDiff % 86400) / 3600)
            local minutes = math.floor((timeDiff % 3600) / 60)

            if years > 0 then
                lastSeenFormatted = tostring(years) .. L["FMT_YEAR_SHORT"] .. " " .. tostring(days) .. L["FMT_DAY_SHORT"] .. " " .. tostring(hours) .. L["FMT_HOUR_SHORT"] .. " " .. tostring(minutes) .. L["FMT_MINUTE_SHORT"]
            else
                lastSeenFormatted = tostring(days) .. L["FMT_DAY_SHORT"] .. " " .. tostring(hours) .. L["FMT_HOUR_SHORT"] .. " " .. tostring(minutes) .. L["FMT_MINUTE_SHORT"]
            end
            lastSeenText:SetTextColor(1, 1, 0.5)
        end

        lastSeenText:SetText(lastSeenFormatted)

        lastSeenContainer:EnableMouse(true)
        lastSeenContainer:SetScript("OnEnter", function(self)
            if lastLogin > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(date("%Y-%m-%d %H:%M", lastLogin), 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end
        end)
        lastSeenContainer:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        table.insert(charRow.cells, lastSeenContainer)

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

        local headerRow = summaryTab.headerRow
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
                        if i == 4 or i == 5 or i == 7 or i == 8 or i == 13 then
                            cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
                        elseif i == 12 then
                            cell:SetPoint("RIGHT", charRow, "LEFT", x + width - 3, 0)
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

    if summaryTab.statusText then
        summaryTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], #allChars, ""))
    end

    ns.UI.RefreshSummaryStats(summaryTab)

    C_Timer.After(0.1, function()
        if summaryTab.headerRow then
            summaryTab.headerRow:GetScript("OnSizeChanged")(summaryTab.headerRow)
        end
    end)
end

function ns.UI.FormatPlaytimeCompact(seconds)
    seconds = tonumber(seconds) or 0
    local totalHours = math.floor(seconds / 3600)
    local days = math.floor(totalHours / 24)
    local years = math.floor(days / 365)
    local remDays = days % 365
    local remHours = totalHours % 24

    if years > 0 then
        return string.format("%dy %dd %dh", years, remDays, remHours)
    elseif days > 0 then
        return string.format("%dd %dh", days, remHours)
    else
        return string.format("%dh", totalHours)
    end
end

function ns.UI.ShowPlaytimeDialog(stats)
    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then
        return
    end

    local existingFrame = _G["OneWoWPlaytimeDialog"]
    if existingFrame and existingFrame:IsShown() then
        existingFrame:Hide()
        return
    end

    if existingFrame then
        existingFrame:Show()
        return
    end

    local classTotals = {}
    local accountTotal = 0

    for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
        if charData.class and charData.playTime and charData.playTime.total then
            local class = charData.class
            classTotals[class] = (classTotals[class] or 0) + charData.playTime.total
            accountTotal = accountTotal + charData.playTime.total
        end
    end

    local sortedClasses = {}
    for class, time in pairs(classTotals) do
        table.insert(sortedClasses, {class = class, time = time})
    end
    table.sort(sortedClasses, function(a, b) return a.time > b.time end)

    local frame = CreateFrame("Frame", "OneWoWPlaytimeDialog", UIParent, "BackdropTemplate")
    frame:SetSize(500, 400)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(T("BG_PRIMARY"))
    frame:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    title:SetText(L["PLAYTIME_BY_CLASS"])
    title:SetTextColor(T("ACCENT_PRIMARY"))

    local closeBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    closeBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    closeBtn:SetBackdropColor(T("BG_TERTIARY"))
    closeBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeText:SetPoint("CENTER")
    closeText:SetText("X")
    closeText:SetTextColor(T("TEXT_PRIMARY"))

    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 40)
    scrollFrame:EnableMouseWheel(true)

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 30))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 30))
        end
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(480)
    scrollFrame:SetScrollChild(scrollContent)

    local rowHeight = 24
    local highestTime = sortedClasses[1] and sortedClasses[1].time or 1

    local yOffset = 0
    for _, classInfo in ipairs(sortedClasses) do
        local classColor = RAID_CLASS_COLORS[classInfo.class] or {r = 1, g = 1, b = 1}
        local barPercent = classInfo.time / highestTime
        local accountPercent = classInfo.time / accountTotal

        local rowFrame = CreateFrame("Frame", nil, scrollContent)
        rowFrame:SetSize(scrollContent:GetWidth() - 20, rowHeight)
        rowFrame:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 10, yOffset)

        local classText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        classText:SetPoint("LEFT", 0, 0)
        classText:SetWidth(100)
        classText:SetText(LOCALIZED_CLASS_NAMES_MALE[classInfo.class] or classInfo.class)
        classText:SetTextColor(classColor.r, classColor.g, classColor.b)
        classText:SetJustifyH("LEFT")

        local bar = CreateFrame("StatusBar", nil, rowFrame)
        bar:SetPoint("LEFT", classText, "RIGHT", 8, 0)
        bar:SetPoint("RIGHT", rowFrame, "RIGHT", -160, 0)
        bar:SetHeight(rowHeight - 6)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(barPercent)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)

        local barBg = bar:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints()
        barBg:SetColorTexture(0, 0, 0, 0.4)

        local timeText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        timeText:SetPoint("LEFT", bar, "RIGHT", 8, 0)
        timeText:SetWidth(150)
        timeText:SetText(string.format("%5.1f%% - %s", accountPercent * 100, ns.UI.FormatPlaytimeCompact(classInfo.time)))
        timeText:SetTextColor(T("TEXT_PRIMARY"))
        timeText:SetJustifyH("LEFT")

        rowFrame:EnableMouse(true)
        rowFrame:SetScript("OnEnter", function(self)
            local classChars = {}
            for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
                if charData.class == classInfo.class then
                    table.insert(classChars, charData)
                end
            end
            table.sort(classChars, function(a, b)
                local at = (a.playTime and a.playTime.total) or 0
                local bt = (b.playTime and b.playTime.total) or 0
                return at > bt
            end)
            local className = LOCALIZED_CLASS_NAMES_MALE[classInfo.class] or classInfo.class
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(className .. " - " .. #classChars, classColor.r, classColor.g, classColor.b)
            for rank, charData in ipairs(classChars) do
                local t = (charData.playTime and charData.playTime.total) or 0
                local timeStr = t > 0 and ns.UI.FormatPlaytimeCompact(t) or "-"
                local name = charData.name or charData.realm or "?"
                GameTooltip:AddDoubleLine("#" .. rank .. "  " .. name, timeStr, 1, 1, 1, 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end)
        rowFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        yOffset = yOffset - rowHeight
    end

    local totalHeight = math.abs(yOffset) + 10
    scrollContent:SetHeight(totalHeight)

    local totalText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    totalText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
    totalText:SetText(L["TOTAL"] .. ": " .. ns.UI.FormatPlaytimeCompact(accountTotal))
    totalText:SetTextColor(T("ACCENT_PRIMARY"))

    table.insert(UISpecialFrames, "OneWoWPlaytimeDialog")
    frame:Show()
end

function ns.UI.RefreshSummaryStats(summaryTab)
    if not summaryTab or not summaryTab.statBoxes then return end
    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then
        return
    end

    local stats = {
        attention = nil,
        characters = 0,
        totalGold = 0,
        factions = {Alliance = 0, Horde = 0},
        rested = 0,
        playtime = 0,
        mounts = 0,
        pets = 0,
        professions = 0,
        achievements = 0
    }

    local allChars = {}
    for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
        table.insert(allChars, {
            key = charKey,
            data = charData
        })
    end
    stats.characters = #allChars

    for _, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local charData = charInfo.data

        if charData.money then
            stats.totalGold = stats.totalGold + charData.money
        end

        if charData.faction then
            if charData.faction == "Alliance" then
                stats.factions.Alliance = stats.factions.Alliance + 1
            elseif charData.faction == "Horde" then
                stats.factions.Horde = stats.factions.Horde + 1
            end
        end

        if charData.xp and charData.xp.restedXP and charData.xp.restedXP > 0 then
            stats.rested = stats.rested + 1
        end

        if charData.playTime and charData.playTime.total then
            stats.playtime = stats.playtime + charData.playTime.total
        end
    end

    local uniquePets = {}
    local uniqueMounts = {}
    if _G.OneWoW_AltTracker_Collections_DB and _G.OneWoW_AltTracker_Collections_DB.characters then
        for charKey, collData in pairs(_G.OneWoW_AltTracker_Collections_DB.characters) do
            if collData.petsMounts then
                if collData.petsMounts.pets and collData.petsMounts.pets.collection then
                    for _, pet in ipairs(collData.petsMounts.pets.collection) do
                        if pet.petID then
                            uniquePets[pet.petID] = true
                        end
                    end
                end
                if collData.petsMounts.mounts and collData.petsMounts.mounts.collection then
                    for _, mount in ipairs(collData.petsMounts.mounts.collection) do
                        if mount.mountID then
                            uniqueMounts[mount.mountID] = true
                        end
                    end
                end
            end

            if collData.achievements and collData.achievements.totalPoints then
                stats.achievements = math.max(stats.achievements, collData.achievements.totalPoints)
            end
        end
    end

    for _ in pairs(uniquePets) do
        stats.pets = stats.pets + 1
    end
    for _ in pairs(uniqueMounts) do
        stats.mounts = stats.mounts + 1
    end

    if _G.OneWoW_AltTracker_Professions_DB and _G.OneWoW_AltTracker_Professions_DB.characters then
        local profCount = {}
        for charKey, profData in pairs(_G.OneWoW_AltTracker_Professions_DB.characters) do
            if profData.professions then
                if profData.professions.Primary1 and profData.professions.Primary1.name then
                    profCount.Primary1 = true
                end
                if profData.professions.Primary2 and profData.professions.Primary2.name then
                    profCount.Primary2 = true
                end
            end
        end
        for _ in pairs(profCount) do
            stats.professions = stats.professions + 1
        end
    end

    local statBoxes = summaryTab.statBoxes
    if statBoxes then
        if statBoxes[1] then statBoxes[1].value:SetText(stats.attention or "-") end
        if statBoxes[2] then statBoxes[2].value:SetText(tostring(stats.characters)) end
        if statBoxes[3] then
            local goldFormatted = ns.AltTrackerFormatters and ns.AltTrackerFormatters.FormatGold and ns.AltTrackerFormatters:FormatGold(stats.totalGold)
            statBoxes[3].value:SetText(goldFormatted)

            statBoxes[3]:SetScript("OnEnter", function(self)
                self:SetBackdropColor(T("BG_HOVER"))
                local warbandGold = 0
                if StorageAPI then
                    warbandGold = StorageAPI.GetWarbandBankGold() or 0
                end
                local grandTotal = stats.totalGold + warbandGold
                local grandFormatted = ns.AltTrackerFormatters and ns.AltTrackerFormatters.FormatGold and ns.AltTrackerFormatters:FormatGold(grandTotal)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TT_TOTAL_GOLD"] .. ": " .. (grandFormatted or "0g"), 1, 0.82, 0)
                GameTooltip:AddLine("----------------------------", 0.4, 0.4, 0.4)
                local charsFormatted = ns.AltTrackerFormatters and ns.AltTrackerFormatters.FormatGold and ns.AltTrackerFormatters:FormatGold(stats.totalGold)
                GameTooltip:AddDoubleLine(L["TT_GOLD_CHARS_LABEL"], charsFormatted or "0g", 0.8, 0.8, 0.8, 1, 0.82, 0)
                local warbandFormatted = ns.AltTrackerFormatters and ns.AltTrackerFormatters.FormatGold and ns.AltTrackerFormatters:FormatGold(warbandGold)
                GameTooltip:AddDoubleLine(L["TT_GOLD_WARBAND_LABEL"], warbandFormatted or "0g", 0.8, 0.8, 0.8, 1, 0.82, 0)
                GameTooltip:Show()
            end)
            statBoxes[3]:SetScript("OnLeave", function(self)
                self:SetBackdropColor(T("BG_TERTIARY"))
                GameTooltip:Hide()
            end)
        end
        if statBoxes[4] then
            local allianceTexture = ns.AltTrackerFormatters and ns.AltTrackerFormatters:GetFactionTexture("Alliance", 14) or ""
            local hordeTexture = ns.AltTrackerFormatters and ns.AltTrackerFormatters:GetFactionTexture("Horde", 14) or ""
            statBoxes[4].value:SetText(stats.factions.Alliance .. allianceTexture .. " - " .. hordeTexture .. stats.factions.Horde)
        end
        if statBoxes[5] then statBoxes[5].value:SetText(tostring(stats.rested)) end
        if statBoxes[6] then
            local playtimeFormatted = ns.UI.FormatPlaytimeCompact(stats.playtime)
            statBoxes[6].value:SetText(playtimeFormatted)
            statBoxes[6]:EnableMouse(true)
            statBoxes[6]:SetScript("OnEnter", function(self)
                self:SetBackdropColor(T("BG_HOVER"))
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TT_PLAYTIME"], 1, 1, 1)
                GameTooltip:AddLine(L["TT_PLAYTIME_DESC"], nil, nil, nil, true)
                GameTooltip:AddLine(L["TT_PLAYTIME_CLICK"], 0.5, 0.8, 1, true)
                GameTooltip:Show()
            end)
            statBoxes[6]:SetScript("OnLeave", function(self)
                self:SetBackdropColor(T("BG_TERTIARY"))
                GameTooltip:Hide()
            end)
            statBoxes[6]:SetScript("OnMouseUp", function()
                if ns.UI.ShowPlaytimeDialog then
                    ns.UI.ShowPlaytimeDialog(stats)
                end
            end)
        end
        if statBoxes[7] then statBoxes[7].value:SetText(tostring(stats.mounts)) end
        if statBoxes[8] then statBoxes[8].value:SetText(tostring(stats.pets)) end
        if statBoxes[9] then statBoxes[9].value:SetText(tostring(stats.professions)) end
        if statBoxes[10] then statBoxes[10].value:SetText(tostring(stats.achievements)) end
    end
end
