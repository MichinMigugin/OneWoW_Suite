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

function ns.UI.CreateProfessionsTab(parent)
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
    overviewTitle:SetText(L["PROFESSIONS_OVERVIEW"])
    overviewTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local statsContainer = CreateFrame("Frame", nil, overviewPanel)
    statsContainer:SetPoint("TOPLEFT", overviewTitle, "BOTTOMLEFT", 0, -8)
    statsContainer:SetPoint("BOTTOMRIGHT", overviewPanel, "BOTTOMRIGHT", -10, 6)

    local statLabels = {
        L["PROF_ATTENTION"], L["PROF_CHARACTERS"], L["PROF_PRIMARY_PROFS"], L["PROF_SECONDARY_PROFS"], L["PROF_MAX_LEVEL"],
        L["PROF_NO_PROFESSIONS"], L["PROF_INCOMPLETE_SECONDARY"], L["PROF_MISSING_EQUIPMENT"], L["PROF_RECIPES"], L["PROF_TOOLS_MISSING"]
    }

    local statTooltipTitles = {
        L["TT_PROF_ATTENTION"], L["TT_PROF_CHARACTERS"], L["TT_PROF_PRIMARY_PROFS"], L["TT_PROF_SECONDARY_PROFS"], L["TT_PROF_MAX_LEVEL"],
        L["TT_PROF_NO_PROFESSIONS"], L["TT_PROF_INCOMPLETE_SECONDARY"], L["TT_PROF_MISSING_EQUIPMENT"], L["TT_PROF_RECIPES"], L["TT_PROF_TOOLS_MISSING"]
    }

    local statTooltips = {
        L["TT_PROF_ATTENTION_DESC"], L["TT_PROF_CHARACTERS_DESC"], L["TT_PROF_PRIMARY_PROFS_DESC"], L["TT_PROF_SECONDARY_PROFS_DESC"], L["TT_PROF_MAX_LEVEL_DESC"],
        L["TT_PROF_NO_PROFESSIONS_DESC"], L["TT_PROF_INCOMPLETE_SECONDARY_DESC"], L["TT_PROF_MISSING_EQUIPMENT_DESC"], L["TT_PROF_RECIPES_DESC"], L["TT_PROF_TOOLS_MISSING_DESC"]
    }

    local statValues = {
        "0", "0", "0/11", "0/3", "0",
        "0", "0", "0", "0/0", "0"
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
        {key = "faction", label = L["COL_FACTION"], width = 25, fixed = true, ttTitle = L["TT_COL_FACTION"], ttDesc = L["PROF_TT_FACTION_DESC"]},
        {key = "mail", label = L["COL_MAIL"], width = 35, fixed = true, ttTitle = L["TT_COL_MAIL"], ttDesc = L["PROF_TT_MAIL_DESC"]},
        {key = "name", label = L["COL_CHARACTER"], width = 135, fixed = false, ttTitle = L["TT_COL_CHARACTER"], ttDesc = L["PROF_TT_CHAR_NAME_DESC"]},
        {key = "level", label = L["COL_LEVEL"], width = 40, fixed = true, ttTitle = L["TT_COL_LEVEL"], ttDesc = L["PROF_TT_CHAR_LEVEL_DESC"]},
        {key = "primary1", label = L["PROF_COL_PRIMARY_1"], width = 90, fixed = false, ttTitle = L["PROF_COL_PRIMARY_1"], ttDesc = L["PROF_TT_PRIMARY_1_DESC"]},
        {key = "conc1", label = L["PROF_COL_CONC"], width = 40, fixed = true, ttTitle = L["PROF_COL_CONC"], ttDesc = L["PROF_TT_CONC_DESC"]},
        {key = "primary2", label = L["PROF_COL_PRIMARY_2"], width = 90, fixed = false, ttTitle = L["PROF_COL_PRIMARY_2"], ttDesc = L["PROF_TT_PRIMARY_2_DESC"]},
        {key = "conc2", label = L["PROF_COL_CONC"], width = 40, fixed = true, ttTitle = L["PROF_COL_CONC"], ttDesc = L["PROF_TT_CONC_DESC"]},
        {key = "cooking", label = L["PROF_COL_COOKING"], width = 60, fixed = false, ttTitle = L["PROF_COL_COOKING"], ttDesc = L["PROF_TT_COOKING_DESC"]},
        {key = "fishing", label = L["PROF_COL_FISHING"], width = 60, fixed = false, ttTitle = L["PROF_COL_FISHING"], ttDesc = L["PROF_TT_FISHING_DESC"]},
        {key = "archeology", label = L["PROF_COL_ARCHEOLOGY"], width = 80, fixed = false, ttTitle = L["PROF_COL_ARCHEOLOGY"], ttDesc = L["PROF_TT_ARCHAEOLOGY_DESC"]},
        {key = "gear", label = L["PROF_COL_GEAR"], width = 50, fixed = false, ttTitle = L["PROF_COL_GEAR"], ttDesc = L["PROF_TT_GEAR_DESC"]}
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
                ns.UI.RefreshProfessionsTab(parent)
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
        if ns.UI.RefreshProfessionsTab then
            ns.UI.RefreshProfessionsTab(parent)
        end
    end)
end

local ProfessionsModule = nil

local function GetProfessionsModule()
    if not ProfessionsModule then
        ProfessionsModule = ns.ProfessionsModule
    end
    return ProfessionsModule
end

local function GetSkillColor(current, max)
    local percent = max > 0 and (current / max * 100) or 0
    if percent >= 100 then
        return 0.30, 0.69, 0.31
    elseif percent >= 75 then
        return 0, 0.74, 0.83
    elseif percent >= 50 then
        return 1, 0.84, 0
    else
        return 1, 0.34, 0.13
    end
end

local CONCENTRATION_RATE = 1 / 360

local function GetEstimatedConcentration(concData)
    if not concData or not concData.value then return nil end
    local timeSince = time() - (concData.ts or time())
    local estimated = math.min(concData.max or 0, math.floor(concData.value + (timeSince * CONCENTRATION_RATE)))
    return estimated, concData.max or 0, concData.value, concData.ts or time()
end

local function AddConcentrationTooltip(frame, concData, profName, L)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(profName or L["PROF_COL_CONC"], 1, 1, 1)
        if concData and concData.value then
            local current, max, stored, ts = GetEstimatedConcentration(concData)
            local r, g, b = GetSkillColor(current, max)
            GameTooltip:AddDoubleLine(L["PROF_TT_CONC_CURRENT"], string.format("%d / %d", current, max), 1, 1, 1, r, g, b)
            if current < max then
                local remaining = (max - current) / CONCENTRATION_RATE
                GameTooltip:AddDoubleLine(L["PROF_TT_CONC_TIME_TO_FULL"], SecondsToTime(remaining), 1, 1, 1, 0.8, 0.8, 0.8)
            else
                GameTooltip:AddDoubleLine(L["PROF_TT_CONC_TIME_TO_FULL"], L["PROF_TT_CONC_FULL"], 1, 1, 1, 0.30, 0.69, 0.31)
            end
        else
            GameTooltip:AddLine(L["PROF_TT_CONC_NO_DATA"], 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

local function AddProfessionTooltip(frame, profData, profRecipes)
    if not profData or not profData.name then return end

    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(profData.name, 1, 1, 1)

        local totalCurrent = profData.currentSkill or 0
        local totalMax = profData.maxSkill or 0
        local expansionData = profData.expansions or {}

        if #expansionData > 0 then
            totalCurrent = 0
            totalMax = 0
            for _, expansion in ipairs(expansionData) do
                totalCurrent = totalCurrent + (expansion.currentSkill or 0)
                totalMax = totalMax + (expansion.maxSkill or 0)
            end
        end

        local r, g, b = GetSkillColor(totalCurrent, totalMax)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L["PROF_LABEL_TOTAL_SKILL"], string.format("%d / %d", totalCurrent, totalMax), 1, 1, 1, r, g, b)

        if #expansionData > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["PROF_LABEL_BY_EXPANSION"], 1, 0.82, 0)

            for _, expansion in ipairs(expansionData) do
                local curSkill = expansion.currentSkill or 0
                local maxSkill = expansion.maxSkill or 0
                local expR, expG, expB = GetSkillColor(curSkill, maxSkill)
                GameTooltip:AddDoubleLine(
                    expansion.name or L["PROF_VALUE_UNKNOWN"],
                    string.format("%d / %d", curSkill, maxSkill),
                    1, 1, 1,
                    expR, expG, expB
                )
            end
        end

        if profRecipes and type(profRecipes) == "table" then
            local totalRecipes = 0
            local totalLearned = 0
            for expansionID, expData in pairs(profRecipes) do
                if type(expData) == "table" then
                    totalRecipes = totalRecipes + (expData.totalRecipes or 0)
                    totalLearned = totalLearned + (expData.learnedRecipes or 0)
                end
            end

            if totalRecipes > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format(L["PROF_RECIPES_FORMAT"], totalLearned, totalRecipes), 0.8, 0.8, 0.8)
            end
        end

        if #expansionData == 0 and (not profRecipes or not next(profRecipes)) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["PROF_NO_EXPANSION_DATA"], 0.7, 0.7, 0.7)
            GameTooltip:AddLine(L["PROF_OPEN_TO_SCAN"], 0.6, 0.6, 0.6)
        end

        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

function ns.UI.RefreshProfessionsTab(professionsTab)
    if not professionsTab then return end

    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return end

    local ProfModule = GetProfessionsModule()
    if not ProfModule then return end

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
            elseif currentSortColumn == "primary1" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aProf = aProfData.professions and aProfData.professions.Primary1
                local bProf = bProfData.professions and bProfData.professions.Primary1
                aVal = (aProf and aProf.currentSkill) or 0
                bVal = (bProf and bProf.currentSkill) or 0
            elseif currentSortColumn == "primary2" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aProf = aProfData.professions and aProfData.professions.Primary2
                local bProf = bProfData.professions and bProfData.professions.Primary2
                aVal = (aProf and aProf.currentSkill) or 0
                bVal = (bProf and bProf.currentSkill) or 0
            elseif currentSortColumn == "cooking" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aProf = aProfData.professions and aProfData.professions.Cooking
                local bProf = bProfData.professions and bProfData.professions.Cooking
                aVal = (aProf and aProf.currentSkill) or 0
                bVal = (bProf and bProf.currentSkill) or 0
            elseif currentSortColumn == "fishing" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aProf = aProfData.professions and aProfData.professions.Fishing
                local bProf = bProfData.professions and bProfData.professions.Fishing
                aVal = (aProf and aProf.currentSkill) or 0
                bVal = (bProf and bProf.currentSkill) or 0
            elseif currentSortColumn == "archeology" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aProf = aProfData.professions and aProfData.professions.Archaeology
                local bProf = bProfData.professions and bProfData.professions.Archaeology
                aVal = (aProf and aProf.currentSkill) or 0
                bVal = (bProf and bProf.currentSkill) or 0
            elseif currentSortColumn == "conc1" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aConc = aProfData.concentration and aProfData.concentration.Primary1
                local bConc = bProfData.concentration and bProfData.concentration.Primary1
                aVal = (aConc and aConc.value) or 0
                bVal = (bConc and bConc.value) or 0
            elseif currentSortColumn == "conc2" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aConc = aProfData.concentration and aProfData.concentration.Primary2
                local bConc = bProfData.concentration and bProfData.concentration.Primary2
                aVal = (aConc and aConc.value) or 0
                bVal = (bConc and bConc.value) or 0
            elseif currentSortColumn == "gear" then
                aVal = 0
                bVal = 0
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

    local scrollContent = professionsTab.scrollContent
    if not scrollContent then return end

    for _, row in ipairs(characterRows) do
        if row.expandedFrame then
            row.expandedFrame:Hide()
            row.expandedFrame:SetParent(nil)
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

        local professionData = ProfModule:GetCharacterProfessions(charKey)
        local professions = professionData.professions or {}
        local professionEquipment = professionData.professionEquipment or {}
        local recipesByExpansion = professionData.recipesByExpansion or {}
        local concentration = professionData.concentration or {}

        local charRow = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        charRow:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
        charRow:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        charRow:SetHeight(rowHeight)
        charRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        charRow:SetBackdropColor(T("BG_TERTIARY"))
        charRow.charKey = charKey
        charRow.cells = {}
        charRow.professionData = professionData

        local expandBtn = CreateFrame("Button", nil, charRow)
        expandBtn:SetSize(25, rowHeight)
        local expandIcon = expandBtn:CreateTexture(nil, "ARTWORK")
        expandIcon:SetSize(14, 14)
        expandIcon:SetPoint("CENTER")
        expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
        expandBtn.icon = expandIcon
        table.insert(charRow.cells, expandBtn)

        local function CreateExpandedDetails()
            if charRow.expandedFrame then return end

            local expandedHeight = 300

            charRow.expandedFrame = CreateFrame("ScrollFrame", nil, scrollContent, "UIPanelScrollFrameTemplate")
            charRow.expandedFrame:SetPoint("TOPLEFT", charRow, "BOTTOMLEFT", 0, -2)
            charRow.expandedFrame:SetPoint("TOPRIGHT", charRow, "BOTTOMRIGHT", 0, -2)
            charRow.expandedFrame:SetHeight(expandedHeight)

            local scrollChild = CreateFrame("Frame", nil, charRow.expandedFrame, "BackdropTemplate")
            scrollChild:SetWidth(charRow.expandedFrame:GetWidth() - 20)
            charRow.expandedFrame:SetScrollChild(scrollChild)

            scrollChild:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1
            })
            scrollChild:SetBackdropColor(T("BG_SECONDARY"))
            scrollChild:SetBackdropBorderColor(T("BORDER_SUBTLE"))

            local hasProfessions = false
            if professions then
                for slotName, profData in pairs(professions) do
                    if profData and profData.name and profData.name ~= "" then
                        hasProfessions = true
                        break
                    end
                end
            end

            if not hasProfessions then
                local noProfText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                noProfText:SetPoint("CENTER", scrollChild, "CENTER", 0, 0)
                noProfText:SetText(L["PROF_NO_PROFESSIONS_LEARNED"])
                noProfText:SetTextColor(T("TEXT_SECONDARY"))
                scrollChild:SetHeight(50)
                charRow.expandedFrame:Show()
                return
            end

            local colWidth = (scrollChild:GetWidth() - 30) / 3
            local col1X = 10
            local col2X = col1X + colWidth + 5
            local col3X = col2X + colWidth + 5

            local header1 = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header1:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", col1X, -10)
            header1:SetText(L["PROF_EXPANDED_PROFESSIONS"])
            header1:SetTextColor(T("ACCENT_PRIMARY"))

            local header2 = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header2:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", col2X, -10)
            header2:SetText(L["PROF_EXPANDED_EQUIPMENT"])
            header2:SetTextColor(T("ACCENT_PRIMARY"))

            local header3 = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header3:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", col3X, -10)
            header3:SetText(L["PROF_EXPANDED_RECIPE_DATA"])
            header3:SetTextColor(T("ACCENT_PRIMARY"))

            local col1Y = -30
            local col2Y = -30
            local col3Y = -30

            local function AddProfessionSkills(profData, xPos, yPos)
                if not profData or not profData.name then return yPos end

                local iconPath = ns.ProfessionData:GetIcon(profData.name)
                local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 16, 16, 0, 1, 0, 1)

                local nameText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                nameText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xPos, yPos)
                nameText:SetText(iconMarkup .. " " .. profData.name)
                nameText:SetTextColor(1, 1, 1)
                yPos = yPos - 16

                local skillLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                skillLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xPos + 5, yPos)
                skillLabel:SetText(L["PROF_LABEL_SKILL"])
                skillLabel:SetTextColor(T("TEXT_SECONDARY"))

                local totalCurrent = profData.currentSkill or 0
                local totalMax = profData.maxSkill or 0

                if profData.expansions and #profData.expansions > 0 then
                    totalCurrent = 0
                    totalMax = 0
                    for _, exp in ipairs(profData.expansions) do
                        totalCurrent = totalCurrent + (exp.currentSkill or 0)
                        totalMax = totalMax + (exp.maxSkill or 0)
                    end
                end

                local skillValue = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                skillValue:SetPoint("LEFT", skillLabel, "RIGHT", 5, 0)
                skillValue:SetText(string.format("%d / %d", totalCurrent, totalMax))

                local r, g, b = GetSkillColor(totalCurrent, totalMax)
                skillValue:SetTextColor(r, g, b)

                return yPos - 20
            end

            local function AddProfessionEquipment(profData, profEquip, xPos, yPos)
                if not profData or not profData.name then return yPos end

                local iconPath = ns.ProfessionData:GetIcon(profData.name)
                local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 16, 16, 0, 1, 0, 1)

                local nameText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                nameText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xPos, yPos)
                nameText:SetText(iconMarkup .. " " .. profData.name)
                nameText:SetTextColor(1, 1, 1)
                yPos = yPos - 16

                local profEquipData = profEquip and profEquip[profData.name]

                local toolLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                toolLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xPos + 5, yPos)
                toolLabel:SetText(L["PROF_LABEL_TOOL"])
                toolLabel:SetTextColor(T("TEXT_SECONDARY"))

                local toolValue = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                toolValue:SetPoint("LEFT", toolLabel, "RIGHT", 5, 0)
                toolValue:SetWidth(colWidth - 60)
                toolValue:SetJustifyH("LEFT")
                toolValue:SetWordWrap(false)

                if profEquipData and profEquipData.tool then
                    local tool = profEquipData.tool
                    toolValue:SetText(tool.itemName or L["PROF_VALUE_UNKNOWN"])
                    local qualityColor = ITEM_QUALITY_COLORS[tool.itemQuality or 1]
                    if qualityColor then
                        toolValue:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)
                    else
                        toolValue:SetTextColor(1, 1, 1)
                    end
                else
                    toolValue:SetText(L["PROF_VALUE_NONE"])
                    toolValue:SetTextColor(1, 0.34, 0.13)
                end
                yPos = yPos - 16

                if profData.name ~= "Fishing" and profData.name ~= "Archaeology" then
                    local acc1Label = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    acc1Label:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xPos + 5, yPos)
                    local accLabelText = (profData.name == "Cooking") and L["PROF_LABEL_ACC"] or L["PROF_LABEL_ACC_1"]
                    acc1Label:SetText(accLabelText)
                    acc1Label:SetTextColor(T("TEXT_SECONDARY"))

                    local acc1Value = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    acc1Value:SetPoint("LEFT", acc1Label, "RIGHT", 5, 0)
                    acc1Value:SetWidth(colWidth - 60)
                    acc1Value:SetJustifyH("LEFT")
                    acc1Value:SetWordWrap(false)

                    if profEquipData and profEquipData.accessory1 then
                        local acc = profEquipData.accessory1
                        acc1Value:SetText(acc.itemName or L["PROF_VALUE_UNKNOWN"])
                        local qualityColor = ITEM_QUALITY_COLORS[acc.itemQuality or 1]
                        if qualityColor then
                            acc1Value:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)
                        else
                            acc1Value:SetTextColor(1, 1, 1)
                        end
                    else
                        acc1Value:SetText(L["PROF_VALUE_NONE"])
                        acc1Value:SetTextColor(1, 0.34, 0.13)
                    end
                    yPos = yPos - 16

                    if profData.name ~= "Cooking" then
                        local acc2Label = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        acc2Label:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xPos + 5, yPos)
                        acc2Label:SetText(L["PROF_LABEL_ACC_2"])
                        acc2Label:SetTextColor(T("TEXT_SECONDARY"))

                        local acc2Value = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        acc2Value:SetPoint("LEFT", acc2Label, "RIGHT", 5, 0)
                        acc2Value:SetWidth(colWidth - 60)
                        acc2Value:SetJustifyH("LEFT")
                        acc2Value:SetWordWrap(false)

                        if profEquipData and profEquipData.accessory2 then
                            local acc = profEquipData.accessory2
                            acc2Value:SetText(acc.itemName or L["PROF_VALUE_UNKNOWN"])
                            local qualityColor = ITEM_QUALITY_COLORS[acc.itemQuality or 1]
                            if qualityColor then
                                acc2Value:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)
                            else
                                acc2Value:SetTextColor(1, 1, 1)
                            end
                        else
                            acc2Value:SetText(L["PROF_VALUE_NONE"])
                            acc2Value:SetTextColor(1, 0.34, 0.13)
                        end
                        yPos = yPos - 16
                    end
                end

                return yPos
            end

            local function AddProfessionRecipes(profData, xPos, yPos)
                if not profData or not profData.name then return yPos end

                local iconPath = ns.ProfessionData:GetIcon(profData.name)
                local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 16, 16, 0, 1, 0, 1)

                local nameText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                nameText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xPos, yPos)
                nameText:SetText(iconMarkup .. " " .. profData.name)
                nameText:SetTextColor(1, 1, 1)
                yPos = yPos - 16

                local totalRecipes = 0
                local totalLearned = 0

                local profRecipeData = recipesByExpansion[profData.name]
                if profRecipeData and type(profRecipeData) == "table" then
                    for expansionID, expData in pairs(profRecipeData) do
                        if type(expData) == "table" then
                            totalRecipes = totalRecipes + (expData.totalRecipes or 0)
                            totalLearned = totalLearned + (expData.learnedRecipes or 0)
                        end
                    end
                end

                local totalLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                totalLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xPos + 5, yPos)
                totalLabel:SetText(L["PROF_LABEL_TOTAL"])
                totalLabel:SetTextColor(T("TEXT_SECONDARY"))

                local totalValue = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                totalValue:SetPoint("LEFT", totalLabel, "RIGHT", 5, 0)
                totalValue:SetText(tostring(totalRecipes))
                totalValue:SetTextColor(1, 1, 1)
                yPos = yPos - 16

                local knownLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                knownLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xPos + 5, yPos)
                knownLabel:SetText(L["PROF_LABEL_KNOWN"])
                knownLabel:SetTextColor(T("TEXT_SECONDARY"))

                local knownValue = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                knownValue:SetPoint("LEFT", knownLabel, "RIGHT", 5, 0)
                knownValue:SetText(tostring(totalLearned))

                local r, g, b = GetSkillColor(totalLearned, totalRecipes)
                knownValue:SetTextColor(r, g, b)
                yPos = yPos - 16

                local missingLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                missingLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xPos + 5, yPos)
                missingLabel:SetText(L["PROF_LABEL_MISSING"])
                missingLabel:SetTextColor(T("TEXT_SECONDARY"))

                local missingValue = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                missingValue:SetPoint("LEFT", missingLabel, "RIGHT", 5, 0)
                local missing = totalRecipes - totalLearned
                missingValue:SetText(tostring(missing))
                if missing > 0 then
                    missingValue:SetTextColor(1, 0.34, 0.13)
                else
                    missingValue:SetTextColor(0.30, 0.69, 0.31)
                end

                return yPos - 20
            end

            if professions.Primary1 and professions.Primary1.name then
                col1Y = AddProfessionSkills(professions.Primary1, col1X, col1Y)
                col2Y = AddProfessionEquipment(professions.Primary1, professionEquipment, col2X, col2Y)
                col3Y = AddProfessionRecipes(professions.Primary1, col3X, col3Y)
            end

            if professions.Primary2 and professions.Primary2.name then
                col1Y = AddProfessionSkills(professions.Primary2, col1X, col1Y)
                col2Y = AddProfessionEquipment(professions.Primary2, professionEquipment, col2X, col2Y)
                col3Y = AddProfessionRecipes(professions.Primary2, col3X, col3Y)
            end

            if professions.Cooking and professions.Cooking.name then
                col1Y = AddProfessionSkills(professions.Cooking, col1X, col1Y)
                col2Y = AddProfessionEquipment(professions.Cooking, professionEquipment, col2X, col2Y)
                col3Y = AddProfessionRecipes(professions.Cooking, col3X, col3Y)
            end

            if professions.Fishing and professions.Fishing.name then
                col1Y = AddProfessionSkills(professions.Fishing, col1X, col1Y)
                col2Y = AddProfessionEquipment(professions.Fishing, professionEquipment, col2X, col2Y)
                col3Y = AddProfessionRecipes(professions.Fishing, col3X, col3Y)
            end

            if professions.Archaeology and professions.Archaeology.name then
                col1Y = AddProfessionSkills(professions.Archaeology, col1X, col1Y)
            end

            local maxY = math.min(col1Y, col2Y, col3Y)
            scrollChild:SetHeight(math.abs(maxY) + 20)

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
        local hasMail = charData.hasNewMail or false
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

        local primary1Frame = CreateFrame("Frame", nil, charRow)
        primary1Frame:SetSize(90, rowHeight)
        local primary1Text = primary1Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        primary1Text:SetPoint("LEFT", primary1Frame, "LEFT", 0, 0)
        primary1Text:SetJustifyH("LEFT")
        local prof1 = professions.Primary1
        if prof1 and prof1.name then
            local totalCurrent = prof1.currentSkill or 0
            local totalMax = prof1.maxSkill or 0
            if prof1.expansions and #prof1.expansions > 0 then
                totalCurrent = 0
                totalMax = 0
                for _, exp in ipairs(prof1.expansions) do
                    totalCurrent = totalCurrent + (exp.currentSkill or 0)
                    totalMax = totalMax + (exp.maxSkill or 0)
                end
            end
            local iconPath = ns.ProfessionData:GetIcon(prof1.name)
            local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 14, 14, 0, 1, 0, 1)
            primary1Text:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(primary1Frame, prof1, recipesByExpansion[prof1.name])
        else
            primary1Text:SetText("--")
        end
        primary1Text:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, primary1Frame)

        local conc1Frame = CreateFrame("Frame", nil, charRow)
        conc1Frame:SetSize(40, rowHeight)
        local conc1Text = conc1Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        conc1Text:SetPoint("CENTER", conc1Frame, "CENTER", 0, 0)
        conc1Text:SetJustifyH("CENTER")
        local conc1Data = concentration.Primary1
        if prof1 and prof1.name and conc1Data and conc1Data.value then
            local current = GetEstimatedConcentration(conc1Data)
            conc1Text:SetText(tostring(current))
            local r, g, b = GetSkillColor(current, conc1Data.max or 0)
            conc1Text:SetTextColor(r, g, b)
            AddConcentrationTooltip(conc1Frame, conc1Data, prof1.name, L)
        else
            conc1Text:SetText("--")
            conc1Text:SetTextColor(T("TEXT_SECONDARY"))
        end
        table.insert(charRow.cells, conc1Frame)

        local primary2Frame = CreateFrame("Frame", nil, charRow)
        primary2Frame:SetSize(90, rowHeight)
        local primary2Text = primary2Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        primary2Text:SetPoint("LEFT", primary2Frame, "LEFT", 0, 0)
        primary2Text:SetJustifyH("LEFT")
        local prof2 = professions.Primary2
        if prof2 and prof2.name then
            local totalCurrent = prof2.currentSkill or 0
            local totalMax = prof2.maxSkill or 0
            if prof2.expansions and #prof2.expansions > 0 then
                totalCurrent = 0
                totalMax = 0
                for _, exp in ipairs(prof2.expansions) do
                    totalCurrent = totalCurrent + (exp.currentSkill or 0)
                    totalMax = totalMax + (exp.maxSkill or 0)
                end
            end
            local iconPath = ns.ProfessionData:GetIcon(prof2.name)
            local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 14, 14, 0, 1, 0, 1)
            primary2Text:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(primary2Frame, prof2, recipesByExpansion[prof2.name])
        else
            primary2Text:SetText("--")
        end
        primary2Text:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, primary2Frame)

        local conc2Frame = CreateFrame("Frame", nil, charRow)
        conc2Frame:SetSize(40, rowHeight)
        local conc2Text = conc2Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        conc2Text:SetPoint("CENTER", conc2Frame, "CENTER", 0, 0)
        conc2Text:SetJustifyH("CENTER")
        local conc2Data = concentration.Primary2
        if prof2 and prof2.name and conc2Data and conc2Data.value then
            local current = GetEstimatedConcentration(conc2Data)
            conc2Text:SetText(tostring(current))
            local r, g, b = GetSkillColor(current, conc2Data.max or 0)
            conc2Text:SetTextColor(r, g, b)
            AddConcentrationTooltip(conc2Frame, conc2Data, prof2.name, L)
        else
            conc2Text:SetText("--")
            conc2Text:SetTextColor(T("TEXT_SECONDARY"))
        end
        table.insert(charRow.cells, conc2Frame)

        local cookingFrame = CreateFrame("Frame", nil, charRow)
        cookingFrame:SetSize(60, rowHeight)
        local cookingText = cookingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cookingText:SetPoint("CENTER", cookingFrame, "CENTER", 0, 0)
        cookingText:SetJustifyH("CENTER")
        local cooking = professions.Cooking
        if cooking and cooking.name then
            local totalCurrent = cooking.currentSkill or 0
            local totalMax = cooking.maxSkill or 0
            if cooking.expansions and #cooking.expansions > 0 then
                totalCurrent = 0
                totalMax = 0
                for _, exp in ipairs(cooking.expansions) do
                    totalCurrent = totalCurrent + (exp.currentSkill or 0)
                    totalMax = totalMax + (exp.maxSkill or 0)
                end
            end
            local iconPath = ns.ProfessionData:GetIcon(cooking.name)
            local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 14, 14, 0, 1, 0, 1)
            cookingText:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(cookingFrame, cooking, recipesByExpansion["Cooking"])
        else
            cookingText:SetText("--")
        end
        cookingText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, cookingFrame)

        local fishingFrame = CreateFrame("Frame", nil, charRow)
        fishingFrame:SetSize(60, rowHeight)
        local fishingText = fishingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fishingText:SetPoint("CENTER", fishingFrame, "CENTER", 0, 0)
        fishingText:SetJustifyH("CENTER")
        local fishing = professions.Fishing
        if fishing and fishing.name then
            local totalCurrent = fishing.currentSkill or 0
            local totalMax = fishing.maxSkill or 0
            if fishing.expansions and #fishing.expansions > 0 then
                totalCurrent = 0
                totalMax = 0
                for _, exp in ipairs(fishing.expansions) do
                    totalCurrent = totalCurrent + (exp.currentSkill or 0)
                    totalMax = totalMax + (exp.maxSkill or 0)
                end
            end
            local iconPath = ns.ProfessionData:GetIcon(fishing.name)
            local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 14, 14, 0, 1, 0, 1)
            fishingText:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(fishingFrame, fishing, recipesByExpansion["Fishing"])
        else
            fishingText:SetText("--")
        end
        fishingText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, fishingFrame)

        local archeologyFrame = CreateFrame("Frame", nil, charRow)
        archeologyFrame:SetSize(80, rowHeight)
        local archeologyText = archeologyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        archeologyText:SetPoint("CENTER", archeologyFrame, "CENTER", 0, 0)
        archeologyText:SetJustifyH("CENTER")
        local archaeology = professions.Archaeology
        if archaeology and archaeology.name then
            local totalCurrent = archaeology.currentSkill or 0
            local totalMax = archaeology.maxSkill or 0
            if archaeology.expansions and #archaeology.expansions > 0 then
                totalCurrent = 0
                totalMax = 0
                for _, exp in ipairs(archaeology.expansions) do
                    totalCurrent = totalCurrent + (exp.currentSkill or 0)
                    totalMax = totalMax + (exp.maxSkill or 0)
                end
            end
            local iconPath = ns.ProfessionData:GetIcon(archaeology.name)
            local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 14, 14, 0, 1, 0, 1)
            archeologyText:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(archeologyFrame, archaeology, recipesByExpansion["Archaeology"])
        else
            archeologyText:SetText("--")
        end
        archeologyText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, archeologyFrame)

        local gearText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local gearEquipped = 0
        local gearTotal = 0

        local gearProfessions = {"Primary1", "Primary2", "Cooking", "Fishing"}
        for _, slotName in ipairs(gearProfessions) do
            if professions[slotName] and professions[slotName].name then
                local profName = professions[slotName].name
                gearTotal = gearTotal + 1
                if professionEquipment[profName] and professionEquipment[profName].tool then
                    gearEquipped = gearEquipped + 1
                end
                if slotName == "Primary1" or slotName == "Primary2" then
                    gearTotal = gearTotal + 2
                    if professionEquipment[profName] then
                        if professionEquipment[profName].accessory1 then gearEquipped = gearEquipped + 1 end
                        if professionEquipment[profName].accessory2 then gearEquipped = gearEquipped + 1 end
                    end
                elseif slotName == "Cooking" then
                    gearTotal = gearTotal + 1
                    if professionEquipment[profName] and professionEquipment[profName].accessory1 then
                        gearEquipped = gearEquipped + 1
                    end
                end
            end
        end

        if gearTotal > 0 then
            gearText:SetText(string.format("%d/%d", gearEquipped, gearTotal))
            if gearEquipped == gearTotal then
                gearText:SetTextColor(0.30, 0.69, 0.31)
            else
                gearText:SetTextColor(1, 0.84, 0)
            end
        else
            gearText:SetText("--")
            gearText:SetTextColor(T("TEXT_SECONDARY"))
        end
        gearText:SetJustifyH("LEFT")
        table.insert(charRow.cells, gearText)

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

        local headerRow = professionsTab.headerRow
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
                        if i == 5 or i == 7 or i == 9 then
                            cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
                        else
                            cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
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

    if professionsTab.statusText then
        professionsTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], #allChars, ""))
    end

    ns.UI.RefreshProfessionsStats(professionsTab)

    C_Timer.After(0.1, function()
        if professionsTab.headerRow then
            professionsTab.headerRow:GetScript("OnSizeChanged")(professionsTab.headerRow)
        end
    end)
end

function ns.UI.RefreshProfessionsStats(professionsTab)
    if not professionsTab or not professionsTab.statBoxes then return end

    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return end

    local ProfModule = GetProfessionsModule()
    if not ProfModule then return end

    local stats = {
        attention = 0,
        characters = 0,
        primaryProfs = 0,
        secondaryProfs = 0,
        maxLevelProfs = 0,
        noProfessions = 0,
        incompleteSecondary = 0,
        missingEquipment = 0,
        recipesKnown = 0,
        recipesTotal = 0,
        toolsMissing = 0
    }

    local allChars = {}
    for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
        table.insert(allChars, {
            key = charKey,
            data = charData
        })
    end
    stats.characters = #allChars

    local uniquePrimaryProfs = {}
    local uniqueSecondaryProfs = {}

    for _, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local professionData = ProfModule:GetCharacterProfessions(charKey)
        local professions = professionData.professions or {}
        local professionEquipment = professionData.professionEquipment or {}
        local charRecipesByExpansion = professionData.recipesByExpansion or {}

        local hasPrimary1 = false
        local hasPrimary2 = false
        local hasCooking = false
        local hasFishing = false

        if professions.Primary1 and professions.Primary1.name then
            hasPrimary1 = true
            uniquePrimaryProfs[professions.Primary1.name] = true

            local totalCurrent = professions.Primary1.currentSkill or 0
            local totalMax = professions.Primary1.maxSkill or 0
            if professions.Primary1.expansions and #professions.Primary1.expansions > 0 then
                totalCurrent = 0
                totalMax = 0
                for _, exp in ipairs(professions.Primary1.expansions) do
                    totalCurrent = totalCurrent + (exp.currentSkill or 0)
                    totalMax = totalMax + (exp.maxSkill or 0)
                end
            end
            if totalCurrent >= totalMax and totalMax > 0 then
                stats.maxLevelProfs = stats.maxLevelProfs + 1
            end

            local prof1Recipes = charRecipesByExpansion[professions.Primary1.name]
            if prof1Recipes and type(prof1Recipes) == "table" then
                for expansionID, expData in pairs(prof1Recipes) do
                    if type(expData) == "table" then
                        stats.recipesKnown = stats.recipesKnown + (expData.learnedRecipes or 0)
                        stats.recipesTotal = stats.recipesTotal + (expData.totalRecipes or 0)
                    end
                end
            end
        end

        if professions.Primary2 and professions.Primary2.name then
            hasPrimary2 = true
            uniquePrimaryProfs[professions.Primary2.name] = true

            local totalCurrent = professions.Primary2.currentSkill or 0
            local totalMax = professions.Primary2.maxSkill or 0
            if professions.Primary2.expansions and #professions.Primary2.expansions > 0 then
                totalCurrent = 0
                totalMax = 0
                for _, exp in ipairs(professions.Primary2.expansions) do
                    totalCurrent = totalCurrent + (exp.currentSkill or 0)
                    totalMax = totalMax + (exp.maxSkill or 0)
                end
            end
            if totalCurrent >= totalMax and totalMax > 0 then
                stats.maxLevelProfs = stats.maxLevelProfs + 1
            end

            local prof2Recipes = charRecipesByExpansion[professions.Primary2.name]
            if prof2Recipes and type(prof2Recipes) == "table" then
                for expansionID, expData in pairs(prof2Recipes) do
                    if type(expData) == "table" then
                        stats.recipesKnown = stats.recipesKnown + (expData.learnedRecipes or 0)
                        stats.recipesTotal = stats.recipesTotal + (expData.totalRecipes or 0)
                    end
                end
            end
        end

        if professions.Cooking and professions.Cooking.name then
            hasCooking = true
            uniqueSecondaryProfs["Cooking"] = true

            local cookingRecipes = charRecipesByExpansion["Cooking"]
            if cookingRecipes and type(cookingRecipes) == "table" then
                for expansionID, expData in pairs(cookingRecipes) do
                    if type(expData) == "table" then
                        stats.recipesKnown = stats.recipesKnown + (expData.learnedRecipes or 0)
                        stats.recipesTotal = stats.recipesTotal + (expData.totalRecipes or 0)
                    end
                end
            end
        end

        if professions.Fishing and professions.Fishing.name then
            hasFishing = true
            uniqueSecondaryProfs["Fishing"] = true

            local fishingRecipes = charRecipesByExpansion["Fishing"]
            if fishingRecipes and type(fishingRecipes) == "table" then
                for expansionID, expData in pairs(fishingRecipes) do
                    if type(expData) == "table" then
                        stats.recipesKnown = stats.recipesKnown + (expData.learnedRecipes or 0)
                        stats.recipesTotal = stats.recipesTotal + (expData.totalRecipes or 0)
                    end
                end
            end
        end

        if professions.Archaeology and professions.Archaeology.name then
            uniqueSecondaryProfs["Archaeology"] = true
        end

        if not hasPrimary1 or not hasPrimary2 then
            stats.noProfessions = stats.noProfessions + 1
            stats.attention = stats.attention + 1
        end

        if not hasCooking or not hasFishing then
            stats.incompleteSecondary = stats.incompleteSecondary + 1
        end

        local gatheringProfs = {
            ["Herbalism"] = true,
            ["Mining"] = true,
            ["Skinning"] = true
        }

        if professions.Primary1 and professions.Primary1.name and gatheringProfs[professions.Primary1.name] then
            if not (professionEquipment[professions.Primary1.name] and professionEquipment[professions.Primary1.name].tool) then
                stats.toolsMissing = stats.toolsMissing + 1
            end
        end

        if professions.Primary2 and professions.Primary2.name and gatheringProfs[professions.Primary2.name] then
            if not (professionEquipment[professions.Primary2.name] and professionEquipment[professions.Primary2.name].tool) then
                stats.toolsMissing = stats.toolsMissing + 1
            end
        end
    end

    local primaryCount = 0
    for _ in pairs(uniquePrimaryProfs) do
        primaryCount = primaryCount + 1
    end
    stats.primaryProfs = primaryCount

    local secondaryCount = 0
    for _ in pairs(uniqueSecondaryProfs) do
        secondaryCount = secondaryCount + 1
    end
    stats.secondaryProfs = secondaryCount

    local statBoxes = professionsTab.statBoxes
    if statBoxes then
        if statBoxes[1] then statBoxes[1].value:SetText(tostring(stats.attention)) end
        if statBoxes[2] then statBoxes[2].value:SetText(tostring(stats.characters)) end
        if statBoxes[3] then statBoxes[3].value:SetText(stats.primaryProfs .. "/11") end
        if statBoxes[4] then statBoxes[4].value:SetText(stats.secondaryProfs .. "/3") end
        if statBoxes[5] then statBoxes[5].value:SetText(tostring(stats.maxLevelProfs)) end
        if statBoxes[6] then statBoxes[6].value:SetText(tostring(stats.noProfessions)) end
        if statBoxes[7] then statBoxes[7].value:SetText(tostring(stats.incompleteSecondary)) end
        if statBoxes[8] then statBoxes[8].value:SetText(tostring(stats.missingEquipment)) end
        if statBoxes[9] then statBoxes[9].value:SetText(stats.recipesKnown .. "/" .. stats.recipesTotal) end
        if statBoxes[10] then statBoxes[10].value:SetText(tostring(stats.toolsMissing)) end
    end
end
