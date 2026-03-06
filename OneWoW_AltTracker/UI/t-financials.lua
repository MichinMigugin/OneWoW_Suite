local addonName, ns = ...
local L = ns.L
local T = ns.T

ns.UI = ns.UI or {}

local transactionRows = {}
local currentSortColumn = "date"
local currentSortAscending = false
local loginServerTime = 0

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
    loginServerTime = GetServerTime()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

local function GetWeeklyResetTime()
    local now = GetServerTime()
    local currentDate = date("*t", now)
    local daysUntilTuesday = (3 - currentDate.wday + 7) % 7
    if daysUntilTuesday == 0 and currentDate.hour >= 15 then
        daysUntilTuesday = 7
    end
    local nextReset = now + (daysUntilTuesday * 86400)
    local resetDate = date("*t", nextReset)
    resetDate.hour = 15
    resetDate.min = 0
    resetDate.sec = 0
    return time(resetDate)
end

local function GetLastWeeklyReset()
    return GetWeeklyResetTime() - (7 * 86400)
end

function ns.UI.CreateFinancialsTab(parent)
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
    overviewTitle:SetText(L["FINANCIALS_OVERVIEW"] or "Financial Overview")
    overviewTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local statsContainer = CreateFrame("Frame", nil, overviewPanel)
    statsContainer:SetPoint("TOPLEFT", overviewTitle, "BOTTOMLEFT", 0, -8)
    statsContainer:SetPoint("BOTTOMRIGHT", overviewPanel, "BOTTOMRIGHT", -10, 6)

    local statBoxes = {}
    local statLabels = {"Income", "Expense", "Profit", "ROI", "Transactions"}

    for i = 1, 5 do
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
        value:SetText("0")
        value:SetTextColor(T("TEXT_PRIMARY"))

        statBox.label = label
        statBox.value = value

        statBox:EnableMouse(true)
        statBox:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)
        statBox:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
        end)

        table.insert(statBoxes, statBox)
    end

    statsContainer:SetScript("OnSizeChanged", function(self, width, height)
        local boxWidth = (width - 18) / 5
        local boxHeight = height - 6
        for i, box in ipairs(statBoxes) do
            local x = 3 + (i - 1) * (boxWidth + 3)
            box:SetSize(boxWidth, boxHeight)
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", self, "TOPLEFT", x, -3)
        end
    end)

    local filterPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    filterPanel:SetPoint("TOPLEFT", overviewPanel, "BOTTOMLEFT", 0, -8)
    filterPanel:SetPoint("TOPRIGHT", overviewPanel, "BOTTOMRIGHT", 0, -8)
    filterPanel:SetHeight(32)
    filterPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    filterPanel:SetBackdropColor(T("BG_SECONDARY"))
    filterPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    parent.timePeriod = "week"
    parent.typeFilter = "all"
    parent.characterFilter = nil
    parent.categoryFilter = nil

    local timePeriods = {
        {key = "login", label = "Session",
            tooltip = "Your current login session. Shows all transactions recorded since you logged in."},
        {key = "today", label = "Today",
            tooltip = "Resets at server midnight. Shows all transactions since the start of today on the WoW server calendar."},
        {key = "week", label = "Week",
            tooltip = "Resets on the weekly server reset. Shows all transactions since last Tuesday at 15:00 server time."},
        {key = "month", label = "Month",
            tooltip = "Resets on the 1st of the month. Shows all transactions since the 1st of this month by WoW server calendar."},
        {key = "reset", label = "Custom",
            tooltip = "Shows all transactions since you last clicked the Reset Data button."},
        {key = "all", label = "All",
            tooltip = "Shows every recorded transaction with no time limit."},
    }

    local periodDropdown = CreateFrame("Button", nil, filterPanel, "BackdropTemplate")
    periodDropdown:SetSize(120, 24)
    periodDropdown:SetPoint("LEFT", filterPanel, "LEFT", 8, 0)
    periodDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    periodDropdown:SetBackdropColor(T("BG_TERTIARY"))
    periodDropdown:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local periodLabel = periodDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    periodLabel:SetPoint("LEFT", periodDropdown, "LEFT", 8, 0)
    periodLabel:SetPoint("RIGHT", periodDropdown, "RIGHT", -22, 0)
    periodLabel:SetJustifyH("LEFT")
    periodLabel:SetText("Week")
    periodLabel:SetTextColor(T("TEXT_PRIMARY"))

    local arrow = periodDropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", periodDropdown, "RIGHT", -5, 0)
    arrow:SetAtlas("UI-HUD-ActionBar-PageDownArrow-Up", false)

    local periodMenu = nil
    periodDropdown:SetScript("OnClick", function(self)
        if periodMenu and periodMenu:IsShown() then periodMenu:Hide() return end
        if not periodMenu then
            periodMenu = CreateFrame("Frame", nil, self, "BackdropTemplate")
            periodMenu:SetFrameStrata("FULLSCREEN_DIALOG")
            periodMenu:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            periodMenu:SetBackdropColor(T("BG_PRIMARY"))
            periodMenu:SetBackdropBorderColor(T("BORDER_DEFAULT"))

            local optH = 24
            periodMenu:SetWidth(self:GetWidth())
            periodMenu:SetHeight(#timePeriods * optH + 4)
            periodMenu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)

            for i, period in ipairs(timePeriods) do
                local row = CreateFrame("Button", nil, periodMenu)
                row:SetPoint("TOPLEFT", periodMenu, "TOPLEFT", 2, -2 - (i - 1) * optH)
                row:SetSize(self:GetWidth() - 4, optH)
                local rowTx = row:CreateTexture(nil, "BACKGROUND")
                rowTx:SetAllPoints(row)
                rowTx:SetColorTexture(T("BG_SECONDARY"))
                rowTx:Hide()
                local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                rowLabel:SetPoint("LEFT", row, "LEFT", 6, 0)
                rowLabel:SetText(period.label)
                rowLabel:SetTextColor(T("TEXT_PRIMARY"))
                row:SetScript("OnEnter", function()
                    rowTx:Show()
                    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                    GameTooltip:SetText(period.label, 1, 1, 1)
                    GameTooltip:AddLine(period.tooltip, 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function()
                    rowTx:Hide()
                    GameTooltip:Hide()
                end)
                row:SetScript("OnClick", function()
                    parent.timePeriod = period.key
                    periodLabel:SetText(period.label)
                    periodMenu:Hide()
                    if ns.UI.RefreshFinancialsTab then
                        ns.UI.RefreshFinancialsTab(parent)
                    end
                end)
            end

            periodMenu:SetScript("OnUpdate", function(self, elapsed)
                if not MouseIsOver(self) and not MouseIsOver(periodDropdown) then
                    self.elapsed = (self.elapsed or 0) + elapsed
                    if self.elapsed > 0.5 then self:Hide() self.elapsed = 0 end
                else
                    self.elapsed = 0
                end
            end)
        end
        periodMenu:Show()
    end)

    periodDropdown:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
    end)

    periodDropdown:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
    end)

    local typeFilters = {
        {key = "all", label = "All"},
        {key = "income", label = "Income"},
        {key = "expense", label = "Expense"},
    }

    local typeButtons = {}
    for i, filter in ipairs(typeFilters) do
        local btn = CreateFrame("Button", nil, filterPanel, "BackdropTemplate")
        btn:SetSize(60, 24)

        if i == 1 then
            btn:SetPoint("LEFT", periodDropdown, "RIGHT", 25, 0)
        else
            btn:SetPoint("LEFT", typeButtons[i-1], "RIGHT", 4, 0)
        end
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnText:SetPoint("CENTER")
        btnText:SetText(filter.label)
        btn.text = btnText
        btn.filterKey = filter.key

        btn:SetScript("OnClick", function(self)
            parent.typeFilter = self.filterKey
            for _, b in ipairs(typeButtons) do
                if b.filterKey == parent.typeFilter then
                    b:SetBackdropColor(T("ACCENT_PRIMARY"))
                    b.text:SetTextColor(T("BG_PRIMARY"))
                else
                    b:SetBackdropColor(T("BG_TERTIARY"))
                    b.text:SetTextColor(T("TEXT_PRIMARY"))
                end
            end
            if ns.UI.RefreshFinancialsTab then
                ns.UI.RefreshFinancialsTab(parent)
            end
        end)

        if filter.key == "all" then
            btn:SetBackdropColor(T("ACCENT_PRIMARY"))
            btnText:SetTextColor(T("BG_PRIMARY"))
        else
            btn:SetBackdropColor(T("BG_TERTIARY"))
            btnText:SetTextColor(T("TEXT_PRIMARY"))
        end

        btn:SetBackdropBorderColor(T("BORDER_DEFAULT"))
        table.insert(typeButtons, btn)
    end

    local charLabel = filterPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    charLabel:SetPoint("LEFT", typeButtons[#typeButtons], "RIGHT", 25, 0)
    charLabel:SetText("Char:")
    charLabel:SetTextColor(T("TEXT_SECONDARY"))

    local charBtn = CreateFrame("Button", nil, filterPanel, "BackdropTemplate")
    charBtn:SetSize(60, 24)
    charBtn:SetPoint("LEFT", charLabel, "RIGHT", 2, 0)
    charBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    charBtn:SetBackdropColor(T("BG_TERTIARY"))
    charBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local charBtnText = charBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    charBtnText:SetPoint("CENTER")
    charBtnText:SetText("All")
    charBtnText:SetTextColor(T("TEXT_PRIMARY"))

    charBtn:SetScript("OnClick", function(self)
        if parent.characterFilter then
            parent.characterFilter = nil
            charBtnText:SetText("All")
        else
            local charKey = ns.AltTrackerFormatters:GetCurrentCharacterKey()
            parent.characterFilter = charKey
            local charName = charKey:match("^([^%-]+)")
            charBtnText:SetText(charName)
        end
        if ns.UI.RefreshFinancialsTab then
            ns.UI.RefreshFinancialsTab(parent)
        end
    end)

    charBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
    end)

    charBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
    end)

    local catLabel = filterPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    catLabel:SetPoint("LEFT", charBtn, "RIGHT", 25, 0)
    catLabel:SetText("Cat:")
    catLabel:SetTextColor(T("TEXT_SECONDARY"))

    local catBtn = CreateFrame("Button", nil, filterPanel, "BackdropTemplate")
    catBtn:SetSize(70, 24)
    catBtn:SetPoint("LEFT", catLabel, "RIGHT", 2, 0)
    catBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    catBtn:SetBackdropColor(T("BG_TERTIARY"))
    catBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local catBtnText = catBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    catBtnText:SetPoint("CENTER")
    catBtnText:SetText("All")
    catBtnText:SetTextColor(T("TEXT_PRIMARY"))

    catBtn:SetScript("OnClick", function(self)
        if parent.categoryFilter then
            parent.categoryFilter = nil
            catBtnText:SetText("All")
        else
            parent.categoryFilter = "auction_sale"
            catBtnText:SetText("Auctions")
        end
        if ns.UI.RefreshFinancialsTab then
            ns.UI.RefreshFinancialsTab(parent)
        end
    end)

    catBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
    end)

    catBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
    end)

    local resetBtn = CreateFrame("Button", nil, filterPanel, "BackdropTemplate")
    resetBtn:SetSize(80, 24)
    resetBtn:SetPoint("LEFT", catBtn, "RIGHT", 25, 0)
    resetBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    resetBtn:SetBackdropColor(0.3, 0.1, 0.1, 1)
    resetBtn:SetBackdropBorderColor(0.6, 0.2, 0.2, 1)

    local resetBtnText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetBtnText:SetPoint("CENTER")
    resetBtnText:SetText("Reset Data")
    resetBtnText:SetTextColor(1, 0.7, 0.7)

    resetBtn:SetScript("OnClick", function(self)
        StaticPopupDialogs["ONEWOW_RESET_FINANCIAL_DATA"] = {
            text = "This will permanently delete ALL financial transaction data. This cannot be undone.",
            button1 = "Reset All Data",
            button2 = "Cancel",
            OnAccept = function()
                if _G.OneWoW_AltTracker_Accounting_DB then
                    _G.OneWoW_AltTracker_Accounting_DB.transactions = {}
                    if _G.OneWoW_AltTracker_Accounting_DB.statistics then
                        _G.OneWoW_AltTracker_Accounting_DB.statistics.totalIncome = 0
                        _G.OneWoW_AltTracker_Accounting_DB.statistics.totalExpense = 0
                        _G.OneWoW_AltTracker_Accounting_DB.statistics.netProfit = 0
                        _G.OneWoW_AltTracker_Accounting_DB.statistics.lastCalculated = 0
                    end
                    if _G.OneWoW_AltTracker_Accounting_DB.settings then
                        _G.OneWoW_AltTracker_Accounting_DB.settings.resetDate = GetServerTime()
                    end
                end
                parent.timePeriod = "week"
                if ns.UI.RefreshFinancialsTab then
                    ns.UI.RefreshFinancialsTab(parent)
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("ONEWOW_RESET_FINANCIAL_DATA")
    end)

    resetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.4, 0.15, 0.15, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Reset All Financial Data", 1, 0.3, 0.3)
        GameTooltip:AddLine("Permanently deletes all transaction history", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)

    resetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.3, 0.1, 0.1, 1)
        GameTooltip:Hide()
    end)

    local guildPersonalLabel = filterPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guildPersonalLabel:SetPoint("RIGHT", filterPanel, "RIGHT", -10, 0)
    guildPersonalLabel:SetText(L["FIN_GUILD_AS_PERSONAL"])
    guildPersonalLabel:SetTextColor(T("TEXT_SECONDARY"))

    local guildPersonalCheck = CreateFrame("CheckButton", nil, filterPanel, "UICheckButtonTemplate")
    guildPersonalCheck:SetSize(22, 22)
    guildPersonalCheck:SetPoint("RIGHT", guildPersonalLabel, "LEFT", -4, 0)

    local function RefreshGuildPersonalCheckState()
        local val = _G.OneWoW_AltTracker_Accounting_DB and
                    _G.OneWoW_AltTracker_Accounting_DB.settings and
                    _G.OneWoW_AltTracker_Accounting_DB.settings.guildAsPersonal == true
        guildPersonalCheck:SetChecked(val)
    end
    C_Timer.After(0.6, RefreshGuildPersonalCheckState)

    guildPersonalCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["FIN_GUILD_AS_PERSONAL"], 1, 1, 1)
        GameTooltip:AddLine(L["FIN_GUILD_AS_PERSONAL_TT"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    guildPersonalCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    guildPersonalCheck:SetScript("OnClick", function(self)
        if _G.OneWoW_AltTracker_Accounting_DB and _G.OneWoW_AltTracker_Accounting_DB.settings then
            _G.OneWoW_AltTracker_Accounting_DB.settings.guildAsPersonal = self:GetChecked() and true or false
        end
    end)

    local rosterPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rosterPanel:SetPoint("TOPLEFT", filterPanel, "BOTTOMLEFT", 0, -5)
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
        {key = "date", label = "Date/Time", width = 100, fixed = false},
        {key = "character", label = "Character", width = 90, fixed = false},
        {key = "category", label = "Category", width = 100, fixed = false},
        {key = "item", label = "Item/Source", width = 130, fixed = false},
        {key = "amount", label = "Amount", width = 80, fixed = false},
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
        for i, col in ipairs(columns) do
            local btn = headerRow.columnButtons[i]
            if btn then
                local width = col.fixed and col.width or math.max(col.width, flexWidth)
                btn.columnWidth = width
                btn.columnX = xOffset
                btn:SetWidth(width)
                btn:ClearAllPoints()
                btn:SetPoint("LEFT", headerRow, "LEFT", xOffset, 0)
                xOffset = xOffset + width + colGap
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

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER")
        text:SetText(col.label)
        text:SetTextColor(T("TEXT_PRIMARY"))
        btn.text = text

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
            if btn.text then btn.text:SetTextColor(T("TEXT_ACCENT")) end
        end)

        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
            if btn.text then btn.text:SetTextColor(T("TEXT_PRIMARY")) end
        end)

        btn:SetScript("OnClick", function(self)
            if currentSortColumn == col.key then
                currentSortAscending = not currentSortAscending
            else
                currentSortColumn = col.key
                currentSortAscending = true
            end

            if parent then
                ns.UI.RefreshFinancialsTab(parent)
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
    statusText:SetText("0 transactions")
    statusText:SetTextColor(T("TEXT_SECONDARY"))

    C_Timer.After(0.2, function()
        UpdateColumnLayout()
    end)

    parent.overviewPanel = overviewPanel
    parent.statsContainer = statsContainer
    parent.statBoxes = statBoxes
    parent.filterPanel = filterPanel
    parent.rosterPanel = rosterPanel
    parent.listContainer = listContainer
    parent.headerRow = headerRow
    parent.scrollFrame = scrollFrame
    parent.scrollContent = scrollContent
    parent.statusBar = statusBar
    parent.statusText = statusText

    C_Timer.After(0.5, function()
        if ns.UI.RefreshFinancialsTab then
            ns.UI.RefreshFinancialsTab(parent)
        end
    end)

    local function SetupRefreshCallback()
        if not _G.OneWoW_AltTracker_Accounting then return end
        local refreshPending = false
        _G.OneWoW_AltTracker_Accounting.onNewTransaction = function()
            if refreshPending then return end
            refreshPending = true
            C_Timer.After(0.3, function()
                refreshPending = false
                if parent and parent:IsVisible() then
                    ns.UI.RefreshFinancialsTab(parent)
                end
            end)
        end
    end
    SetupRefreshCallback()
    C_Timer.After(1, SetupRefreshCallback)
end

function ns.UI.RefreshFinancialsTab(financialsTab)
    if not financialsTab then return end

    if not _G.OneWoW_AltTracker_Accounting_DB then
        if financialsTab.statusText then
            financialsTab.statusText:SetText("Install OneWoW_AltTracker_Accounting addon")
        end
        return
    end

    local scrollContent = financialsTab.scrollContent
    if not scrollContent then return end

    for _, row in ipairs(transactionRows) do
        if row.expandedFrame then
            row.expandedFrame:Hide()
            row.expandedFrame = nil
        end
        row:Hide()
        row:SetParent(nil)
    end
    wipe(transactionRows)

    local allTransactions = _G.OneWoW_AltTracker_Accounting_DB.transactions or {}
    local timePeriod = financialsTab.timePeriod or "week"
    local typeFilter = financialsTab.typeFilter or "all"
    local characterFilter = financialsTab.characterFilter

    local timeStart = 0
    local now = GetServerTime()
    if timePeriod == "login" then
        timeStart = loginServerTime
    elseif timePeriod == "today" then
        local hour, minute = GetGameTime()
        timeStart = now - ((hour * 3600) + (minute * 60))
    elseif timePeriod == "week" then
        timeStart = GetLastWeeklyReset()
    elseif timePeriod == "reset" then
        local customReset = _G.OneWoW_AltTracker_Accounting_DB and _G.OneWoW_AltTracker_Accounting_DB.settings and _G.OneWoW_AltTracker_Accounting_DB.settings.resetDate
        if customReset and customReset > 0 then
            timeStart = customReset
        else
            timeStart = GetLastWeeklyReset()
        end
    elseif timePeriod == "month" then
        local hour, minute = GetGameTime()
        local serverMidnight = now - ((hour * 3600) + (minute * 60))
        local d = date("*t", serverMidnight)
        d.day = 1
        d.hour = 0
        d.min = 0
        d.sec = 0
        timeStart = time(d)
    end

    local categoryFilter = financialsTab.categoryFilter

    local transactions = {}
    for _, tx in ipairs(allTransactions) do
        if tx.timestamp >= timeStart then
            if typeFilter == "all" or tx.type == typeFilter then
                if not characterFilter or tx.character == characterFilter then
                    if not categoryFilter or tx.category == categoryFilter then
                        table.insert(transactions, tx)
                    end
                end
            end
        end
    end

    if financialsTab.statBoxes and _G.OneWoW_AltTracker_Accounting then
        local stats = _G.OneWoW_AltTracker_Accounting:CalculateStatistics(timeStart, now, characterFilter, categoryFilter)

        if financialsTab.statBoxes[1] then
            financialsTab.statBoxes[1].value:SetText(ns.AltTrackerFormatters:FormatGold(stats.income))
            financialsTab.statBoxes[1].value:SetTextColor(0, 1, 0)

            local topIncome = {}
            for category, amount in pairs(stats.categories or {}) do
                if amount and type(amount) == "number" and amount > 0 then
                    table.insert(topIncome, {category = category, amount = amount})
                end
            end
            table.sort(topIncome, function(a, b) return (a.amount or 0) > (b.amount or 0) end)

            financialsTab.statBoxes[1]:SetScript("OnEnter", function(self)
                self:SetBackdropColor(T("BG_HOVER"))
                if #topIncome > 0 then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Top Income Sources", 1, 1, 1)
                    for i = 1, math.min(5, #topIncome) do
                        local cat = topIncome[i]
                        if cat and cat.amount and type(cat.amount) == "number" then
                            GameTooltip:AddLine(ns.UI.GetCategoryDisplayName(cat.category) .. ": " .. ns.AltTrackerFormatters:FormatGoldSimple(cat.amount), 0, 1, 0)
                        end
                    end
                    GameTooltip:Show()
                end
            end)
            financialsTab.statBoxes[1]:SetScript("OnLeave", function(self)
                self:SetBackdropColor(T("BG_TERTIARY"))
                GameTooltip:Hide()
            end)
        end

        if financialsTab.statBoxes[2] then
            financialsTab.statBoxes[2].value:SetText(ns.AltTrackerFormatters:FormatGold(stats.expense))
            financialsTab.statBoxes[2].value:SetTextColor(1, 0.5, 0.5)

            local topExpense = {}
            for category, amount in pairs(stats.categories or {}) do
                if amount and type(amount) == "number" and amount < 0 then
                    table.insert(topExpense, {category = category, amount = math.abs(amount)})
                end
            end
            table.sort(topExpense, function(a, b) return (a.amount or 0) > (b.amount or 0) end)

            financialsTab.statBoxes[2]:SetScript("OnEnter", function(self)
                self:SetBackdropColor(T("BG_HOVER"))
                if #topExpense > 0 then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Top Expenses", 1, 1, 1)
                    for i = 1, math.min(5, #topExpense) do
                        local cat = topExpense[i]
                        if cat and cat.amount and type(cat.amount) == "number" then
                            GameTooltip:AddLine(ns.UI.GetCategoryDisplayName(cat.category) .. ": " .. ns.AltTrackerFormatters:FormatGoldSimple(cat.amount), 1, 0.5, 0.5)
                        end
                    end
                    GameTooltip:Show()
                end
            end)
            financialsTab.statBoxes[2]:SetScript("OnLeave", function(self)
                self:SetBackdropColor(T("BG_TERTIARY"))
                GameTooltip:Hide()
            end)
        end

        if financialsTab.statBoxes[3] then
            financialsTab.statBoxes[3].value:SetText(ns.AltTrackerFormatters:FormatGold(stats.profit))
            if stats.profit >= 0 then
                financialsTab.statBoxes[3].value:SetTextColor(0, 1, 0)
            else
                financialsTab.statBoxes[3].value:SetTextColor(1, 0, 0)
            end
        end

        if financialsTab.statBoxes[4] then
            local roi = stats.expense > 0 and math.floor((stats.income / stats.expense) * 100) or 0
            financialsTab.statBoxes[4].value:SetText(roi .. "%")
        end

        if financialsTab.statBoxes[5] then
            financialsTab.statBoxes[5].value:SetText(tostring(stats.transactionCount))
        end
    end

    if #transactions == 0 then
        if financialsTab.statusText then
            if #allTransactions == 0 then
                financialsTab.statusText:SetText("No transactions yet - buy, sell, repair, or trade to start tracking")
            else
                financialsTab.statusText:SetText("No transactions match filters")
            end
        end
        return
    end

    table.sort(transactions, function(a, b)
        local aVal, bVal

        if currentSortColumn == "date" then
            aVal = a.timestamp or 0
            bVal = b.timestamp or 0
        elseif currentSortColumn == "character" then
            aVal = a.character or ""
            bVal = b.character or ""
        elseif currentSortColumn == "category" then
            aVal = a.category or ""
            bVal = b.category or ""
        elseif currentSortColumn == "item" then
            aVal = a.itemName or a.source or ""
            bVal = b.itemName or b.source or ""
        elseif currentSortColumn == "amount" then
            aVal = a.amount or 0
            bVal = b.amount or 0
        else
            aVal = a.timestamp or 0
            bVal = b.timestamp or 0
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
    end)

    local yOffset = -5
    local rowHeight = 28
    local rowGap = 2

    local function RepositionAllRows()
        local yOffset = -5

        for _, row in ipairs(transactionRows) do
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

    for i = 1, math.min(100, #transactions) do
        local tx = transactions[i]

        local txRow = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        txRow:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
        txRow:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        txRow:SetHeight(rowHeight)
        txRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        txRow:SetBackdropColor(T("BG_TERTIARY"))
        txRow.cells = {}

        local function ToggleExpanded()
            local isExpanded = txRow.isExpanded or false
            txRow.isExpanded = not isExpanded

            local needsResize = false

            if txRow.isExpanded then
                if not txRow.expandedFrame then
                    txRow.expandedFrame = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
                    txRow.expandedFrame:SetPoint("TOPLEFT", txRow, "BOTTOMLEFT", 0, -2)
                    txRow.expandedFrame:SetPoint("TOPRIGHT", txRow, "BOTTOMRIGHT", 0, -2)
                    txRow.expandedFrame:SetHeight(40)
                    txRow.expandedFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                    txRow.expandedFrame:SetBackdropColor(T("BG_SECONDARY"))

                    local detailsText = txRow.expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    detailsText:SetPoint("TOPLEFT", txRow.expandedFrame, "TOPLEFT", 15, -8)
                    detailsText:SetPoint("TOPRIGHT", txRow.expandedFrame, "TOPRIGHT", -15, -8)
                    detailsText:SetJustifyH("LEFT")
                    detailsText:SetJustifyV("TOP")
                    detailsText:SetWordWrap(true)
                    detailsText:SetTextColor(T("TEXT_PRIMARY"))
                    txRow.expandedFrame.detailsText = detailsText

                    local details = {}
                    table.insert(details, "ID: " .. (tx.id or "?") .. "  |  " .. date("%Y-%m-%d %H:%M:%S", tx.timestamp or 0))
                    if tx.quantity and tx.quantity > 1 then
                        table.insert(details, "Qty: " .. tx.quantity)
                    end
                    if tx.notes then
                        table.insert(details, tx.notes)
                    end

                    detailsText:SetText(table.concat(details, "\n"))
                    needsResize = true
                end
                txRow.expandedFrame:Show()
            else
                if txRow.expandedFrame then
                    txRow.expandedFrame:Hide()
                end
            end

            if needsResize then
                C_Timer.After(0, function()
                    if txRow.expandedFrame and txRow.expandedFrame.detailsText then
                        local h = txRow.expandedFrame.detailsText:GetStringHeight()
                        txRow.expandedFrame:SetHeight(math.max(40, h + 16))
                    end
                    RepositionAllRows()
                end)
            else
                RepositionAllRows()
            end
        end

        local dateText = txRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dateText:SetText(date("%m/%d %H:%M", tx.timestamp or 0))
        dateText:SetTextColor(T("TEXT_SECONDARY"))
        dateText:SetJustifyH("LEFT")
        table.insert(txRow.cells, dateText)

        local charText = txRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local charName = (tx.character or ""):match("^([^%-]+)")
        charText:SetText(charName or "?")
        charText:SetTextColor(T("TEXT_PRIMARY"))
        charText:SetJustifyH("LEFT")
        table.insert(txRow.cells, charText)

        local categoryText = txRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local categoryName = ns.UI.GetCategoryDisplayName(tx.category)
        categoryText:SetText(categoryName)
        categoryText:SetTextColor(T("TEXT_SECONDARY"))
        categoryText:SetJustifyH("LEFT")
        table.insert(txRow.cells, categoryText)

        local itemText = txRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemText:SetText(tx.itemName or tx.source or "")
        itemText:SetTextColor(T("TEXT_PRIMARY"))
        itemText:SetJustifyH("LEFT")
        table.insert(txRow.cells, itemText)

        local amountText = txRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local amountFormatted = ns.AltTrackerFormatters:FormatGold(tx.amount or 0)
        if tx.type == "income" then
            amountText:SetText("+" .. amountFormatted)
            amountText:SetTextColor(0, 1, 0)
        elseif tx.type == "transfer" then
            amountText:SetText(amountFormatted)
            amountText:SetTextColor(1, 0.82, 0)
        else
            amountText:SetText("-" .. amountFormatted)
            amountText:SetTextColor(1, 0.5, 0.5)
        end
        amountText:SetJustifyH("RIGHT")
        table.insert(txRow.cells, amountText)

        local headerRow = financialsTab.headerRow
        if headerRow and headerRow.columnButtons then
            for i, cell in ipairs(txRow.cells) do
                local btn = headerRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX

                    cell:ClearAllPoints()
                    cell:SetWidth(width - 6)

                    if i == #txRow.cells then
                        cell:SetPoint("RIGHT", txRow, "LEFT", x + width - 3, 0)
                    else
                        cell:SetPoint("LEFT", txRow, "LEFT", x + 3, 0)
                    end
                end
            end
        end

        txRow:EnableMouse(true)
        txRow:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)

        txRow:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
        end)

        txRow:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                ToggleExpanded()
            end
        end)

        txRow:Show()
        table.insert(transactionRows, txRow)
        yOffset = yOffset - (rowHeight + rowGap)
    end

    local newHeight = math.max(400, #transactionRows * (rowHeight + rowGap) + 10)
    scrollContent:SetHeight(newHeight)

    if financialsTab.statusText then
        financialsTab.statusText:SetText(#transactions .. " transactions")
    end

    C_Timer.After(0.1, function()
        if financialsTab.headerRow then
            financialsTab.headerRow:GetScript("OnSizeChanged")(financialsTab.headerRow)
        end
    end)
end

function ns.UI.GetCategoryDisplayName(category)
    local names = {
        vendor_purchase = "Vendor Buy",
        vendor_sale = "Vendor Sell",
        vendor_buyback = "Buyback",
        repair = "Repair",
        auction_sale = "Auction Sale",
        auction_purchase = "Auction Purchase",
        auction_deposit = "AH Deposit",
        trade_buy = "Trade Buy",
        trade_sale = "Trade Sale",
        money_transfer_in = "Gold Received",
        money_transfer_out = "Gold Sent",
        guild_bank_deposit = "Guild Deposit",
        guild_bank_withdraw = "Guild Withdraw",
        warband_bank_deposit = "Warband Deposit",
        warband_bank_withdraw = "Warband Withdraw",
        mail_send = "Mail Sent",
        mail_cod_send = "COD Sent",
        mail_postage = "Postage",
        quest_reward = "Quest Reward",
        loot_money = "Looted Gold",
        transmog = "Transmog",
        death_cost = "Death Cost",
        crafting_order = "Crafting Order",
        crafting_order_placed = "Order Placed",
        crafting_order_refund = "Order Refund",
        trainer_purchase = "Trainer Learn",
        mythicplus_reward = "Mythic+ Reward",
        bmah_purchase = "Black Market AH",
        detected_profit = "Detected Profit",
        detected_loss = "Detected Loss",
    }
    return names[category] or category
end
