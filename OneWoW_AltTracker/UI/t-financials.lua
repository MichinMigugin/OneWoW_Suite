local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

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

local categoryNames = {
    vendor_purchase = "FIN_CAT_VENDOR_PURCHASE",
    vendor_sale = "FIN_CAT_VENDOR_SALE",
    vendor_buyback = "FIN_CAT_VENDOR_BUYBACK",
    repair = "FIN_CAT_REPAIR",
    auction_sale = "FIN_CAT_AUCTION_SALE",
    auction_purchase = "FIN_CAT_AUCTION_PURCHASE",
    auction_deposit = "FIN_CAT_AUCTION_DEPOSIT",
    trade_buy = "FIN_CAT_TRADE_BUY",
    trade_sale = "FIN_CAT_TRADE_SALE",
    money_transfer_in = "FIN_CAT_MONEY_IN",
    money_transfer_out = "FIN_CAT_MONEY_OUT",
    guild_bank_deposit = "FIN_CAT_GUILD_DEPOSIT",
    guild_bank_withdraw = "FIN_CAT_GUILD_WITHDRAW",
    warband_bank_deposit = "FIN_CAT_WARBAND_DEPOSIT",
    warband_bank_withdraw = "FIN_CAT_WARBAND_WITHDRAW",
    mail_send = "FIN_CAT_MAIL_SEND",
    mail_cod_send = "FIN_CAT_MAIL_COD",
    mail_postage = "FIN_CAT_POSTAGE",
    quest_reward = "FIN_CAT_QUEST_REWARD",
    loot_money = "FIN_CAT_LOOT_MONEY",
    transmog = "FIN_CAT_TRANSMOG",
    death_cost = "FIN_CAT_DEATH_COST",
    crafting_order = "FIN_CAT_CRAFTING_ORDER",
    crafting_order_placed = "FIN_CAT_ORDER_PLACED",
    crafting_order_refund = "FIN_CAT_ORDER_REFUND",
    trainer_purchase = "FIN_CAT_TRAINER",
    mythicplus_reward = "FIN_CAT_MYTHICPLUS",
    bmah_purchase = "FIN_CAT_BMAH",
    uncategorized = "FIN_CAT_UNCATEGORIZED",
}

function ns.UI.GetCategoryDisplayName(category)
    local key = categoryNames[category]
    if key then return L[key] end
    return category
end

local columnsConfig = {
    {key = "expand",    label = "",                      width = 25,  fixed = true,  align = "icon",   sortable = false, ttTitle = L["TT_COL_EXPAND"],         ttDesc = L["TT_COL_EXPAND_DESC"]},
    {key = "date",      label = L["FIN_COL_DATE"],      width = 100, fixed = false, align = "left",  ttTitle = L["TT_FIN_COL_DATE"],      ttDesc = L["TT_FIN_COL_DATE_DESC"]},
    {key = "character", label = L["FIN_COL_CHARACTER"],  width = 90,  fixed = false, align = "left",  ttTitle = L["TT_FIN_COL_CHARACTER"],  ttDesc = L["TT_FIN_COL_CHARACTER_DESC"]},
    {key = "category",  label = L["FIN_COL_CATEGORY"],   width = 100, fixed = false, align = "left",  ttTitle = L["TT_FIN_COL_CATEGORY"],  ttDesc = L["TT_FIN_COL_CATEGORY_DESC"]},
    {key = "item",      label = L["FIN_COL_ITEM"],       width = 130, fixed = false, align = "left",  ttTitle = L["TT_FIN_COL_ITEM"],      ttDesc = L["TT_FIN_COL_ITEM_DESC"]},
    {key = "amount",    label = L["FIN_COL_AMOUNT"],     width = 80,  fixed = false, align = "right", ttTitle = L["TT_FIN_COL_AMOUNT"],    ttDesc = L["TT_FIN_COL_AMOUNT_DESC"]},
}

local onHeaderCreate = function(btn, col, index)
    if col.key == "expand" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("CENTER")
        icon:SetAtlas("Gamepad_Rev_Plus_64")
        btn.icon = icon
        if btn.text then btn.text:SetText("") end
    end
end

function ns.UI.CreateFinancialsTab(parent)
    local overview = OneWoW_GUI:CreateOverviewPanel(parent, {
        title = L["FINANCIALS_OVERVIEW"],
        height = 70,
        columns = 5,
        stats = {
            {label = L["FIN_INCOME"],       value = "0", ttTitle = L["TT_FIN_INCOME"],       ttDesc = L["TT_FIN_INCOME_DESC"]},
            {label = L["FIN_EXPENSE"],      value = "0", ttTitle = L["TT_FIN_EXPENSE"],      ttDesc = L["TT_FIN_EXPENSE_DESC"]},
            {label = L["FIN_PROFIT"],       value = "0", ttTitle = L["TT_FIN_PROFIT"],       ttDesc = L["TT_FIN_PROFIT_DESC"]},
            {label = L["FIN_SUCCESS_RATE"], value = "0", ttTitle = L["TT_FIN_ROI"],          ttDesc = L["TT_FIN_ROI_DESC"]},
            {label = L["FIN_TRANSACTIONS"], value = "0", ttTitle = L["TT_FIN_TRANSACTIONS"], ttDesc = L["TT_FIN_TRANSACTIONS_DESC"]},
        },
    })

    local filterPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    filterPanel:SetPoint("TOPLEFT", overview.panel, "BOTTOMLEFT", 0, -8)
    filterPanel:SetPoint("TOPRIGHT", overview.panel, "BOTTOMRIGHT", 0, -8)
    filterPanel:SetHeight(32)
    filterPanel:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    filterPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    filterPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    parent.timePeriod = "week"
    parent.typeFilter = "all"
    parent.characterFilter = nil
    parent.categoryFilter = nil

    local timePeriods = {
        {key = "login",  label = L["FIN_PERIOD_SESSION"], tooltip = L["FIN_PERIOD_SESSION_TT"]},
        {key = "today",  label = L["FIN_PERIOD_TODAY"],   tooltip = L["FIN_PERIOD_TODAY_TT"]},
        {key = "week",   label = L["FIN_PERIOD_WEEK"],    tooltip = L["FIN_PERIOD_WEEK_TT"]},
        {key = "month",  label = L["FIN_PERIOD_MONTH"],   tooltip = L["FIN_PERIOD_MONTH_TT"]},
        {key = "reset",  label = L["FIN_PERIOD_CUSTOM"],  tooltip = L["FIN_PERIOD_CUSTOM_TT"]},
        {key = "all",    label = L["FIN_PERIOD_ALL"],     tooltip = L["FIN_PERIOD_ALL_TT"]},
    }

    local periodDropdown, periodDropdownText = OneWoW_GUI:CreateDropdown(filterPanel, {
        width = 120,
        height = 24,
        text = L["FIN_PERIOD_WEEK"],
    })
    periodDropdown:SetPoint("LEFT", filterPanel, "LEFT", 8, 0)

    OneWoW_GUI:AttachFilterMenu(periodDropdown, {
        searchable = false,
        menuHeight = #timePeriods * 26 + 8,
        buildItems = function()
            local items = {}
            for _, period in ipairs(timePeriods) do
                table.insert(items, {
                    text = period.label,
                    value = period.key,
                    tooltip = period.tooltip,
                })
            end
            return items
        end,
        onSelect = function(value, text)
            parent.timePeriod = value
            periodDropdown._text:SetText(text)
            if ns.UI.RefreshFinancialsTab then
                ns.UI.RefreshFinancialsTab(parent)
            end
        end,
        getActiveValue = function()
            return parent.timePeriod
        end,
    })

    local typeFilters = {
        {key = "all",     label = L["FIN_FILTER_ALL"]},
        {key = "income",  label = L["FIN_FILTER_INCOME"]},
        {key = "expense", label = L["FIN_FILTER_EXPENSE"]},
    }

    local typeButtons = {}
    for i, filter in ipairs(typeFilters) do
        local btn = OneWoW_GUI:CreateButton(filterPanel, { text = filter.label, width = 60, height = 24 })

        if i == 1 then
            btn:SetPoint("LEFT", periodDropdown, "RIGHT", 25, 0)
        else
            btn:SetPoint("LEFT", typeButtons[i-1], "RIGHT", 4, 0)
        end

        btn.filterKey = filter.key

        btn:SetScript("OnClick", function(self)
            parent.typeFilter = self.filterKey
            for _, b in ipairs(typeButtons) do
                if b.filterKey == parent.typeFilter then
                    b:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    b.text:SetTextColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                else
                    b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    b.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end
            end
            if ns.UI.RefreshFinancialsTab then
                ns.UI.RefreshFinancialsTab(parent)
            end
        end)

        if filter.key == "all" then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        table.insert(typeButtons, btn)
    end

    local charLabel = filterPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    charLabel:SetPoint("LEFT", typeButtons[#typeButtons], "RIGHT", 25, 0)
    charLabel:SetText(L["FIN_CHAR_LABEL"])
    charLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local charBtn = OneWoW_GUI:CreateButton(filterPanel, { text = L["FIN_CHAR_ALL"], width = 60, height = 24 })
    charBtn:SetPoint("LEFT", charLabel, "RIGHT", 2, 0)

    charBtn:SetScript("OnClick", function(self)
        if parent.characterFilter then
            parent.characterFilter = nil
            self.text:SetText(L["FIN_CHAR_ALL"])
        else
            local charKey = ns.AltTrackerFormatters:GetCurrentCharacterKey()
            parent.characterFilter = charKey
            local charName = charKey:match("^([^%-]+)")
            self.text:SetText(charName)
        end
        if ns.UI.RefreshFinancialsTab then
            ns.UI.RefreshFinancialsTab(parent)
        end
    end)

    local catLabel = filterPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    catLabel:SetPoint("LEFT", charBtn, "RIGHT", 25, 0)
    catLabel:SetText(L["FIN_CAT_LABEL"])
    catLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local catBtn = OneWoW_GUI:CreateButton(filterPanel, { text = L["FIN_CAT_ALL"], width = 70, height = 24 })
    catBtn:SetPoint("LEFT", catLabel, "RIGHT", 2, 0)

    catBtn:SetScript("OnClick", function(self)
        if parent.categoryFilter then
            parent.categoryFilter = nil
            self.text:SetText(L["FIN_CAT_ALL"])
        else
            parent.categoryFilter = "auction_sale"
            self.text:SetText(L["FIN_CAT_AUCTIONS"])
        end
        if ns.UI.RefreshFinancialsTab then
            ns.UI.RefreshFinancialsTab(parent)
        end
    end)

    local resetBtn = OneWoW_GUI:CreateButton(filterPanel, { text = L["FIN_RESET_DATA"], width = 80, height = 24 })
    resetBtn:SetPoint("LEFT", catBtn, "RIGHT", 25, 0)
    resetBtn:SetBackdropColor(0.3, 0.1, 0.1, 1)
    resetBtn:SetBackdropBorderColor(0.6, 0.2, 0.2, 1)
    resetBtn.text:SetTextColor(1, 0.7, 0.7)

    resetBtn:SetScript("OnClick", function(self)
        StaticPopupDialogs["ONEWOW_RESET_FINANCIAL_DATA"] = {
            text = L["FIN_RESET_CONFIRM"],
            button1 = L["FIN_RESET_ACCEPT"],
            button2 = CANCEL,
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
        GameTooltip:SetText(L["FIN_RESET_TT"], 1, 0.3, 0.3)
        GameTooltip:AddLine(L["FIN_RESET_TT_DESC"], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)

    resetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.3, 0.1, 0.1, 1)
        GameTooltip:Hide()
    end)

    local guildPersonalCheck = OneWoW_GUI:CreateCheckbox(filterPanel, { label = L["FIN_GUILD_AS_PERSONAL"] })
    guildPersonalCheck:SetPoint("RIGHT", filterPanel, "RIGHT", -10 - guildPersonalCheck.label:GetStringWidth(), 0)

    C_Timer.After(0.6, function()
        local val = _G.OneWoW_AltTracker_Accounting_DB and
                    _G.OneWoW_AltTracker_Accounting_DB.settings and
                    _G.OneWoW_AltTracker_Accounting_DB.settings.guildAsPersonal == true
        guildPersonalCheck:SetChecked(val)
    end)

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

    local rosterPanel = OneWoW_GUI:CreateRosterPanel(parent, filterPanel)

    local dt
    dt = OneWoW_GUI:CreateDataTable(rosterPanel, {
        columns = columnsConfig,
        headerHeight = 26,
        onHeaderCreate = onHeaderCreate,
        onSort = function(sortColumn, sortAscending)
            currentSortColumn = sortColumn
            currentSortAscending = sortAscending
            ns.UI.RefreshFinancialsTab(parent)
            C_Timer.After(0.1, function() dt.UpdateSortIndicators() end)
        end,
    })

    local status = OneWoW_GUI:CreateStatusBar(parent, rosterPanel, {
        text = string.format(L["FIN_STATUS_COUNT"], 0),
    })

    parent.overviewPanel = overview.panel
    parent.statBoxes = overview.statBoxes
    parent.filterPanel = filterPanel
    parent.rosterPanel = rosterPanel
    parent.dataTable = dt
    parent.columnsConfig = columnsConfig
    parent.headerRow = dt.headerRow
    parent.scrollContent = dt.scrollContent
    parent.statusBar = status.bar
    parent.statusText = status.text

    C_Timer.After(0.5, function()
        if ns.UI.RefreshFinancialsTab then
            ns.UI.RefreshFinancialsTab(parent)
        end
    end)

    parent.financialsDirty = false

    local function SetupRefreshCallback()
        if not _G.OneWoW_AltTracker_Accounting then return false end
        local refreshPending = false
        _G.OneWoW_AltTracker_Accounting.onNewTransaction = function()
            if refreshPending then return end
            refreshPending = true
            C_Timer.After(0.3, function()
                refreshPending = false
                if parent and parent:IsVisible() then
                    ns.UI.RefreshFinancialsTab(parent)
                else
                    parent.financialsDirty = true
                end
            end)
        end
        return true
    end

    local function TrySetupCallback(attempt)
        if SetupRefreshCallback() then return end
        if attempt < 10 then
            C_Timer.After(1, function() TrySetupCallback(attempt + 1) end)
        end
    end
    TrySetupCallback(1)

    parent:HookScript("OnShow", function()
        if parent.financialsDirty then
            parent.financialsDirty = false
            ns.UI.RefreshFinancialsTab(parent)
        end
    end)

    ns.UI.ApplyFontToFrame(parent)
end

function ns.UI.RefreshFinancialsTab(financialsTab)
    if not financialsTab then return end

    if not _G.OneWoW_AltTracker_Accounting_DB then
        if financialsTab.statusText then
            financialsTab.statusText:SetText(L["FIN_INSTALL_ACCOUNTING"])
        end
        return
    end

    local scrollContent = financialsTab.scrollContent
    if not scrollContent then return end

    local dt = financialsTab.dataTable
    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

    OneWoW_GUI:ClearDataRows(scrollContent)
    wipe(transactionRows)
    if dt then dt:ClearRows() end

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

            financialsTab.statBoxes[1].extraTooltipLines = {}
            if #topIncome > 0 then
                table.insert(financialsTab.statBoxes[1].extraTooltipLines, {text = L["FIN_TOP_INCOME"], r = 1, g = 1, b = 1})
                for i = 1, math.min(5, #topIncome) do
                    local cat = topIncome[i]
                    if cat and cat.amount and type(cat.amount) == "number" then
                        table.insert(financialsTab.statBoxes[1].extraTooltipLines, {text = ns.UI.GetCategoryDisplayName(cat.category) .. ": " .. ns.AltTrackerFormatters:FormatGoldSimple(cat.amount), r = 0, g = 1, b = 0})
                    end
                end
            end
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

            financialsTab.statBoxes[2].extraTooltipLines = {}
            if #topExpense > 0 then
                table.insert(financialsTab.statBoxes[2].extraTooltipLines, {text = L["FIN_TOP_EXPENSES"], r = 1, g = 1, b = 1})
                for i = 1, math.min(5, #topExpense) do
                    local cat = topExpense[i]
                    if cat and cat.amount and type(cat.amount) == "number" then
                        table.insert(financialsTab.statBoxes[2].extraTooltipLines, {text = ns.UI.GetCategoryDisplayName(cat.category) .. ": " .. ns.AltTrackerFormatters:FormatGoldSimple(cat.amount), r = 1, g = 0.5, b = 0.5})
                    end
                end
            end
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
                financialsTab.statusText:SetText(L["FIN_NO_TRANSACTIONS"])
            else
                financialsTab.statusText:SetText(L["FIN_NO_MATCH"])
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
            if currentSortAscending then return aVal < bVal else return aVal > bVal end
        else
            if currentSortAscending then return aVal < bVal else return aVal > bVal end
        end
    end)

    local rowHeight = 28
    local rowGap = 2

    for i = 1, math.min(100, #transactions) do
        local tx = transactions[i]

        local txRow = OneWoW_GUI:CreateDataRow(scrollContent, {
            rowHeight = rowHeight,
            expandedHeight = 50,
            rowGap = rowGap,
            data = { tx = tx },
            createDetails = function(ef, d)
                local grid = OneWoW_GUI:CreateExpandedPanelGrid(ef, T)
                local p1 = grid:AddPanel(L["FIN_COL_DATE"])
                grid:AddLine(p1, L["FIN_EXPANDED_ID"] .. " " .. (d.tx.id or "?") .. "  |  " .. date("%Y-%m-%d %H:%M:%S", d.tx.timestamp or 0))
                if d.tx.quantity and d.tx.quantity > 1 then
                    grid:AddLine(p1, L["FIN_EXPANDED_QTY"] .. " " .. d.tx.quantity)
                end
                if d.tx.notes then
                    grid:AddLine(p1, d.tx.notes)
                end
                grid:Finish()
                ns.UI.ApplyFontToFrame(ef)
            end,
        })

        local dateText = txRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dateText:SetText(date("%m/%d %H:%M", tx.timestamp or 0))
        dateText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        dateText:SetJustifyH("LEFT")
        table.insert(txRow.cells, dateText)

        local charText = txRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local charName = (tx.character or ""):match("^([^%-]+)")
        charText:SetText(charName or "?")
        charText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        charText:SetJustifyH("LEFT")
        table.insert(txRow.cells, charText)

        local categoryText = txRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        categoryText:SetText(ns.UI.GetCategoryDisplayName(tx.category))
        categoryText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        categoryText:SetJustifyH("LEFT")
        table.insert(txRow.cells, categoryText)

        local itemText = txRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemText:SetText(tx.itemName or tx.source or "")
        itemText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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

        if dt and dt.headerRow and dt.headerRow.columnButtons and columnsConfig then
            for ci, cell in ipairs(txRow.cells) do
                local btn = dt.headerRow.columnButtons[ci]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX
                    local col = columnsConfig[ci]
                    cell:ClearAllPoints()
                    if col and col.align == "icon" then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", txRow, "LEFT", x, 0)
                    elseif col and col.align == "center" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("CENTER", txRow, "LEFT", x + width / 2, 0)
                    elseif col and col.align == "right" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("RIGHT", txRow, "LEFT", x + width - 3, 0)
                    else
                        cell:SetWidth(width - 6)
                        cell:SetPoint("LEFT", txRow, "LEFT", x + 3, 0)
                    end
                end
            end
        end

        table.insert(transactionRows, txRow)
        if dt then dt:RegisterRow(txRow) end
    end

    OneWoW_GUI:LayoutDataRows(scrollContent, { rowHeight = rowHeight, rowGap = rowGap })

    ns.UI.ApplyFontToFrame(financialsTab)

    if financialsTab.statusText then
        financialsTab.statusText:SetText(string.format(L["FIN_STATUS_COUNT"], #transactions))
    end
end
