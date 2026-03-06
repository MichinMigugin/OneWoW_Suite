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

function ns.UI.CreateLockoutsTab(parent)
    local overviewPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    overviewPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    overviewPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)
    overviewPanel:SetHeight(70)
    overviewPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    overviewPanel:SetBackdropColor(T("BG_SECONDARY"))
    overviewPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local overviewTitle = overviewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overviewTitle:SetPoint("TOPLEFT", overviewPanel, "TOPLEFT", 10, -6)
    overviewTitle:SetText(L["LOCKOUTS_OVERVIEW"])
    overviewTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local statsContainer = CreateFrame("Frame", nil, overviewPanel)
    statsContainer:SetPoint("TOPLEFT", overviewTitle, "BOTTOMLEFT", 0, -8)
    statsContainer:SetPoint("BOTTOMRIGHT", overviewPanel, "BOTTOMRIGHT", -10, 6)

    local statLabels = {
        L["LOCKOUTS_ATTENTION"], L["LOCKOUTS_ACTIVE"], L["LOCKOUTS_DUNGEONS"], L["LOCKOUTS_RAIDS"], L["LOCKOUTS_NEXT_IN"]
    }

    local statTooltipTitles = {
        L["TT_LOCKOUTS_ATTENTION"], L["TT_LOCKOUTS_ACTIVE"], L["TT_LOCKOUTS_DUNGEONS"], L["TT_LOCKOUTS_RAIDS"], L["TT_LOCKOUTS_NEXT_IN"]
    }

    local statTooltips = {
        L["TT_LOCKOUTS_ATTENTION_DESC"], L["TT_LOCKOUTS_ACTIVE_DESC"], L["TT_LOCKOUTS_DUNGEONS_DESC"], L["TT_LOCKOUTS_RAIDS_DESC"], L["TT_LOCKOUTS_NEXT_IN_DESC"]
    }

    local statValues = {
        "0", "0", "0", "0", "0m"
    }

    local cols = 5
    local rows = 1
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

    local listContainer = CreateFrame("Frame", nil, rosterPanel)
    listContainer:SetPoint("TOPLEFT", rosterPanel, "TOPLEFT", 8, -8)
    listContainer:SetPoint("BOTTOMRIGHT", rosterPanel, "BOTTOMRIGHT", -8, 8)

    local scrollBarWidth = 10

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
        {key = "lockout1", label = L["LOCKOUTS_COL_LOCKOUT_1"], width = 120, fixed = false, ttTitle = L["TT_COL_LOCKOUT_1"], ttDesc = L["TT_COL_LOCKOUT_1_DESC"]},
        {key = "lockout2", label = L["LOCKOUTS_COL_LOCKOUT_2"], width = 120, fixed = false, ttTitle = L["TT_COL_LOCKOUT_2"], ttDesc = L["TT_COL_LOCKOUT_2_DESC"]},
        {key = "lockout3", label = L["LOCKOUTS_COL_LOCKOUT_3"], width = 120, fixed = false, ttTitle = L["TT_COL_LOCKOUT_3"], ttDesc = L["TT_COL_LOCKOUT_3_DESC"]},
        {key = "lockout4", label = L["LOCKOUTS_COL_LOCKOUT_4"], width = 120, fixed = false, ttTitle = L["TT_COL_LOCKOUT_4"], ttDesc = L["TT_COL_LOCKOUT_4_DESC"]},
        {key = "expires", label = L["LOCKOUTS_COL_EXPIRES"], width = 80, fixed = false, ttTitle = L["TT_COL_EXPIRES"], ttDesc = L["TT_COL_EXPIRES_DESC"]}
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
                            cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
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
            if btn.text then btn.text:SetTextColor(T("TEXT_PRIMARY"))end
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
                ns.UI.RefreshLockoutsTab(parent)
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

    local scrollFrame = CreateFrame("ScrollFrame", nil, listContainer)
    scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -5)
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

    C_Timer.After(0.5, function()
        if ns.UI.RefreshLockoutsTab then
            ns.UI.RefreshLockoutsTab(parent)
        end
    end)
end

function ns.UI.RefreshLockoutsTab(lockoutsTab)
    if not lockoutsTab then return end
    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return end
    if not _G.OneWoW_AltTracker_Endgame_DB or not _G.OneWoW_AltTracker_Endgame_DB.characters then return end

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
            elseif currentSortColumn == "lockout1" or currentSortColumn == "lockout2" or currentSortColumn == "lockout3" or currentSortColumn == "lockout4" then
                local lockoutIndex = tonumber(string.match(currentSortColumn, "%d+"))
                local aEndgame = _G.OneWoW_AltTracker_Endgame_DB and _G.OneWoW_AltTracker_Endgame_DB.characters and _G.OneWoW_AltTracker_Endgame_DB.characters[a.key]
                local bEndgame = _G.OneWoW_AltTracker_Endgame_DB and _G.OneWoW_AltTracker_Endgame_DB.characters and _G.OneWoW_AltTracker_Endgame_DB.characters[b.key]
                aVal = (aEndgame and aEndgame.raids and aEndgame.raids.lockouts and aEndgame.raids.lockouts[lockoutIndex] and aEndgame.raids.lockouts[lockoutIndex].name) or ""
                bVal = (bEndgame and bEndgame.raids and bEndgame.raids.lockouts and bEndgame.raids.lockouts[lockoutIndex] and bEndgame.raids.lockouts[lockoutIndex].name) or ""
            elseif currentSortColumn == "expires" then
                local aEndgame = _G.OneWoW_AltTracker_Endgame_DB and _G.OneWoW_AltTracker_Endgame_DB.characters and _G.OneWoW_AltTracker_Endgame_DB.characters[a.key]
                local bEndgame = _G.OneWoW_AltTracker_Endgame_DB and _G.OneWoW_AltTracker_Endgame_DB.characters and _G.OneWoW_AltTracker_Endgame_DB.characters[b.key]
                local currentTime = time()
                local aSoonest = 999999999
                local bSoonest = 999999999
                if aEndgame and aEndgame.raids and aEndgame.raids.lockouts then
                    for _, lockout in ipairs(aEndgame.raids.lockouts) do
                        if lockout.reset and lockout.reset > 0 then
                            local expiresAt = currentTime + lockout.reset
                            if expiresAt < aSoonest then
                                aSoonest = expiresAt
                            end
                        end
                    end
                end
                if bEndgame and bEndgame.raids and bEndgame.raids.lockouts then
                    for _, lockout in ipairs(bEndgame.raids.lockouts) do
                        if lockout.reset and lockout.reset > 0 then
                            local expiresAt = currentTime + lockout.reset
                            if expiresAt < bSoonest then
                                bSoonest = expiresAt
                            end
                        end
                    end
                end
                aVal = aSoonest
                bVal = bSoonest
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

    local scrollContent = lockoutsTab.scrollContent
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

        local endgameData = _G.OneWoW_AltTracker_Endgame_DB.characters[charKey]
        local lockouts = {}
        local currentTime = time()

        if endgameData and endgameData.raids and endgameData.raids.lockouts then
            for _, lockout in ipairs(endgameData.raids.lockouts) do
                local expiresAt = currentTime + (lockout.reset or 0)
                if lockout.reset and lockout.reset > 0 then
                    table.insert(lockouts, {
                        name = lockout.name,
                        id = lockout.id,
                        difficulty = lockout.difficultyName,
                        expiresAt = expiresAt,
                        isRaid = true,
                        encounterProgress = lockout.encounterProgress or 0,
                        totalEncounters = lockout.numEncounters or 0,
                    })
                end
            end
        end

        table.sort(lockouts, function(a, b)
            if a.isRaid ~= b.isRaid then
                return a.isRaid
            end
            return (a.expiresAt or 0) < (b.expiresAt or 0)
        end)

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
                    charRow.expandedFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                    charRow.expandedFrame:SetBackdropColor(T("BG_SECONDARY"))

                    local raidList = {}
                    local dungeonList = {}

                    for _, lockout in ipairs(lockouts) do
                        if lockout.isRaid then
                            table.insert(raidList, lockout)
                        else
                            table.insert(dungeonList, lockout)
                        end
                    end

                    local leftCol = charRow.expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    leftCol:SetPoint("LEFT", charRow.expandedFrame, "LEFT", 15, 0)
                    leftCol:SetJustifyH("LEFT")
                    leftCol:SetTextColor(T("TEXT_PRIMARY"))

                    local rightCol = charRow.expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    rightCol:SetPoint("LEFT", charRow.expandedFrame, "CENTER", 15, 0)
                    rightCol:SetJustifyH("LEFT")
                    rightCol:SetTextColor(T("TEXT_PRIMARY"))

                    local leftText = L["LOCKOUTS_RAIDS"] .. ":\n"
                    if #raidList > 0 then
                        for _, lockout in ipairs(raidList) do
                            local timeLeft = lockout.expiresAt - currentTime
                            local daysLeft = math.floor(timeLeft / 86400)
                            local hoursLeft = math.floor((timeLeft % 86400) / 3600)
                            local timeLeftText = daysLeft > 0 and string.format("%dd %dh", daysLeft, hoursLeft) or string.format("%dh", hoursLeft)
                            local progressText = string.format("(%d/%d)", lockout.encounterProgress, lockout.totalEncounters)
                            leftText = leftText .. string.format("%s %s - %s\n", lockout.difficulty or "", lockout.name or "", progressText)
                        end
                    else
                        leftText = leftText .. L["LOCKOUTS_NO_RAID"] .. "\n"
                    end

                    local rightText = L["LOCKOUTS_DUNGEONS"] .. ":\n"
                    if #dungeonList > 0 then
                        for _, lockout in ipairs(dungeonList) do
                            local timeLeft = lockout.expiresAt - currentTime
                            local daysLeft = math.floor(timeLeft / 86400)
                            local hoursLeft = math.floor((timeLeft % 86400) / 3600)
                            local timeLeftText = daysLeft > 0 and string.format("%dd %dh", daysLeft, hoursLeft) or string.format("%dh", hoursLeft)
                            rightText = rightText .. string.format("%s %s - %s\n", lockout.difficulty or "", lockout.name or "", timeLeftText)
                        end
                    else
                        rightText = rightText .. L["LOCKOUTS_NO_DUNGEON"] .. "\n"
                    end

                    leftCol:SetText(leftText)
                    rightCol:SetText(rightText)

                    local leftHeight = leftCol:GetStringHeight()
                    local rightHeight = rightCol:GetStringHeight()
                    local contentHeight = math.max(leftHeight, rightHeight) + 20

                    charRow.expandedFrame:SetHeight(contentHeight)
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
        if _G.OneWoW_AltTracker_Storage_DB and _G.OneWoW_AltTracker_Storage_DB.characters then
            local storageData = _G.OneWoW_AltTracker_Storage_DB.characters[charKey]
            hasMail = storageData and storageData.mail and storageData.mail.hasNewMail
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

        local lockoutTexts = {}
        for i = 1, 4 do
            local lockout = lockouts[i]
            local lockoutText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lockoutText:SetJustifyH("LEFT")

            if lockout then
                local displayText = lockout.name or ""
                if lockout.isRaid and lockout.totalEncounters and lockout.totalEncounters > 0 then
                    displayText = string.format("%s (%d/%d)", displayText, lockout.encounterProgress or 0, lockout.totalEncounters)
                end

                lockoutText:SetText(displayText)
                lockoutText:SetTextColor(T("TEXT_PRIMARY"))

                lockoutText:EnableMouse(true)
                lockoutText:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(lockout.name or "", 1, 1, 1)
                    GameTooltip:AddLine(string.format("%s: %s", L["LOCKOUTS_DIFFICULTY"], lockout.difficulty or ""), 0.7, 0.7, 0.7)
                    if lockout.isRaid and lockout.totalEncounters and lockout.totalEncounters > 0 then
                        GameTooltip:AddLine(string.format("%s: %d/%d", L["PROGRESS"], lockout.encounterProgress or 0, lockout.totalEncounters), 1, 0.82, 0)
                    end
                    if lockout.expiresAt then
                        local timeLeft = lockout.expiresAt - currentTime
                        local daysLeft = math.floor(timeLeft / 86400)
                        local hoursLeft = math.floor((timeLeft % 86400) / 3600)
                        local minutesLeft = math.floor((timeLeft % 3600) / 60)
                        local timeLeftText = ""
                        if daysLeft > 0 then
                            timeLeftText = string.format("%dd %dh", daysLeft, hoursLeft)
                        elseif hoursLeft > 0 then
                            timeLeftText = string.format("%dh %dm", hoursLeft, minutesLeft)
                        else
                            timeLeftText = string.format("%dm", minutesLeft)
                        end
                        GameTooltip:AddLine(string.format("%s: %s", L["LOCKOUTS_UNLOCKS_IN"], timeLeftText), 0.5, 0.9, 1)
                    end
                    GameTooltip:Show()
                end)
                lockoutText:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
            else
                lockoutText:SetText("-")
                lockoutText:SetTextColor(T("TEXT_SECONDARY"))
            end

            table.insert(charRow.cells, lockoutText)
            table.insert(lockoutTexts, lockoutText)
        end

        local expiresText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        expiresText:SetJustifyH("LEFT")
        if #lockouts > 0 then
            local soonestLockout = lockouts[1]
            if soonestLockout and soonestLockout.expiresAt then
                local timeLeft = soonestLockout.expiresAt - currentTime
                local daysLeft = math.floor(timeLeft / 86400)
                local hoursLeft = math.floor((timeLeft % 86400) / 3600)
                if daysLeft > 0 then
                    expiresText:SetText(string.format("%dd %dh", daysLeft, hoursLeft))
                else
                    expiresText:SetText(string.format("%dh", hoursLeft))
                end
                expiresText:SetTextColor(0.5, 0.9, 1)
            else
                expiresText:SetText("-")
                expiresText:SetTextColor(T("TEXT_SECONDARY"))
            end
        else
            expiresText:SetText("-")
            expiresText:SetTextColor(T("TEXT_SECONDARY"))
        end
        table.insert(charRow.cells, expiresText)

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

        local headerRow = lockoutsTab.headerRow
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
                        if i == 4 or i == 6 or i == 7 or i == 8 or i == 9 or i == 10 then
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

    if lockoutsTab.statusText then
        lockoutsTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], #allChars, ""))
    end

    ns.UI.RefreshLockoutsStats(lockoutsTab)

    C_Timer.After(0.1, function()
        if lockoutsTab.headerRow then
            lockoutsTab.headerRow:GetScript("OnSizeChanged")(lockoutsTab.headerRow)
        end
    end)
end

function ns.UI.RefreshLockoutsStats(lockoutsTab)
    if not lockoutsTab or not lockoutsTab.statBoxes then return end
    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return end
    if not _G.OneWoW_AltTracker_Endgame_DB or not _G.OneWoW_AltTracker_Endgame_DB.characters then return end

    local stats = {
        attention = 0,
        active = 0,
        dungeons = 0,
        raids = 0,
        nextReset = nil
    }

    local currentTime = time()
    local soonestReset = nil

    for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
        local endgameData = _G.OneWoW_AltTracker_Endgame_DB.characters[charKey]

        local hasLockouts = false
        if endgameData and endgameData.raids and endgameData.raids.lockouts then
            for _, lockout in ipairs(endgameData.raids.lockouts) do
                if lockout.reset and lockout.reset > 0 then
                    local expiresAt = currentTime + lockout.reset
                    stats.active = stats.active + 1
                    hasLockouts = true

                    stats.raids = stats.raids + 1

                    if not soonestReset or expiresAt < soonestReset then
                        soonestReset = expiresAt
                    end
                end
            end
        end

        if not hasLockouts then
            stats.attention = stats.attention + 1
        end
    end

    local statBoxes = lockoutsTab.statBoxes
    if statBoxes then
        if statBoxes[1] then statBoxes[1].value:SetText(tostring(stats.attention)) end
        if statBoxes[2] then statBoxes[2].value:SetText(tostring(stats.active)) end
        if statBoxes[3] then statBoxes[3].value:SetText(tostring(stats.dungeons)) end
        if statBoxes[4] then statBoxes[4].value:SetText(tostring(stats.raids)) end
        if statBoxes[5] then
            if soonestReset then
                local timeLeft = soonestReset - currentTime
                local daysLeft = math.floor(timeLeft / 86400)
                local hoursLeft = math.floor((timeLeft % 86400) / 3600)
                local minutesLeft = math.floor((timeLeft % 3600) / 60)

                if daysLeft > 0 then
                    statBoxes[5].value:SetText(string.format("%dd %dh", daysLeft, hoursLeft))
                elseif hoursLeft > 0 then
                    statBoxes[5].value:SetText(string.format("%dh %dm", hoursLeft, minutesLeft))
                else
                    statBoxes[5].value:SetText(string.format("%dm", minutesLeft))
                end
            else
                statBoxes[5].value:SetText("-")
            end
        end
    end
end
