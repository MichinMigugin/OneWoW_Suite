local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

ns.UI = ns.UI or {}

local listEntries = {}
local expandedByTxId = {}
local listAPI = nil
local FIN_ROW_HEIGHT = 28
local FIN_ROW_GAP = 2
local FIN_DETAIL_HEIGHT = 52
local FIN_TX_STRIDE = FIN_ROW_HEIGHT + FIN_ROW_GAP
local FIN_DETAIL_STRIDE = FIN_DETAIL_HEIGHT + FIN_ROW_GAP
local currentSortColumn = "date"
local currentSortAscending = false
local loginServerTime = 0
local activeFinancialsTab = nil
local dashboardMode = false

local amountDialog
local itemDialog

local function ResolveWalletEndBalance(characterFilter)
    if characterFilter then
        local currentKey = ns.AltTrackerFormatters:GetCurrentCharacterKey()
        if characterFilter == currentKey then
            return GetMoney()
        end
        local charData = OneWoW_AltTracker_Character_API
            and OneWoW_AltTracker_Character_API.GetCharacterData(characterFilter)
        return (charData and charData.money) or 0
    end

    local total, found = 0, false
    if OneWoW_AltTracker_Character_API then
        for _, charData in pairs(OneWoW_AltTracker_Character_API.GetAllCharacters()) do
            if charData.money then
                total = total + charData.money
                found = true
            end
        end
    end
    if found then
        return total
    end
    return GetMoney()
end

local function FormatBucketDelta(series)
    if not series or #series < 2 then
        return nil, "neutral"
    end
    local diff = series[#series] - series[#series - 1]
    if diff == 0 then
        return ns.AltTrackerFormatters:FormatGold(0), "neutral"
    end
    local text = ns.AltTrackerFormatters:FormatGold(math.abs(diff))
    if diff > 0 then
        return "+" .. text, "up"
    end
    return "-" .. text, "down"
end

-- GoldWatcher catch-all itemNames; omitting them avoids "Uncategorized / Uncategorized Income".
local GENERIC_TOP_ITEMS = {
    ["Uncategorized Income"] = true,
    ["Uncategorized Expense"] = true,
}

local function FormatTopSubtitle(catEntry, itemEntry)
    if not catEntry then
        return nil
    end
    local catName = ns.UI.GetCategoryDisplayName(catEntry.key)
    local itemName = itemEntry and itemEntry.key
    if itemName and itemName ~= "" and not GENERIC_TOP_ITEMS[itemName] then
        return string.format(L["FIN_TOP_LINE_PAIR"], catName, itemName)
    end
    return string.format(L["FIN_TOP_LINE"], catName)
end

local function CreateSummaryChip(parent, labelText)
    local Constants = OneWoW_GUI.Constants
    local chip = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    chip:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    chip:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    chip:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local label = OneWoW_GUI:CreateFS(chip, 9)
    label:SetPoint("TOPLEFT", chip, "TOPLEFT", 6, -4)
    label:SetPoint("TOPRIGHT", chip, "TOPRIGHT", -6, -4)
    label:SetJustifyH("LEFT")
    label:SetText(labelText or "")
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    chip.label = label

    local value = OneWoW_GUI:CreateFS(chip, 11)
    value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    value:SetPoint("TOPRIGHT", chip, "TOPRIGHT", -6, 0)
    value:SetJustifyH("LEFT")
    value:SetText("0")
    value:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    chip.value = value

    local sub = OneWoW_GUI:CreateFS(chip, 9)
    sub:SetPoint("TOPLEFT", value, "BOTTOMLEFT", 0, -1)
    sub:SetPoint("TOPRIGHT", chip, "TOPRIGHT", -6, 0)
    sub:SetJustifyH("LEFT")
    sub:SetText("")
    sub:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    sub:Hide()
    chip.sub = sub

    function chip:SetValue(text, colorKey)
        self.value:SetText(text or "0")
        if colorKey then
            self.value:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey))
        else
            self.value:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    function chip:SetSub(text)
        if not text or text == "" then
            self.sub:SetText("")
            self.sub:Hide()
            return
        end
        self.sub:SetText(text)
        self.sub:Show()
    end

    return chip
end

local function RefreshDashboardPanels(financialsTab, allTransactions, timeStart, timeEnd, characterFilter, categoryFilter, typeFilter, stats)
    local api = OneWoW_AltTracker_Accounting_API
    local panels = financialsTab.metricPanels
    if not api or not panels then return end

    local flowTxs, walletTxs, summaryTxs = {}, {}, {}
    for _, tx in ipairs(allTransactions) do
        if (tx.timestamp or 0) >= timeStart then
            if not characterFilter or tx.character == characterFilter then
                if not categoryFilter or tx.category == categoryFilter then
                    if tx.type == "income" or tx.type == "expense" or tx.type == "transfer" then
                        table.insert(walletTxs, tx)
                    end
                    if tx.type == "income" or tx.type == "expense" then
                        table.insert(summaryTxs, tx)
                        if typeFilter == "all" or tx.type == typeFilter then
                            table.insert(flowTxs, tx)
                        end
                    end
                end
            end
        end
    end

    local series = api.BuildFlowSeries(flowTxs, timeStart, timeEnd)
    local summary = api.BuildDashboardSummary(summaryTxs, timeStart, timeEnd)
    local fmt = ns.AltTrackerFormatters
    local deltaLabelFmt = (series.bucketSeconds == 86400) and L["FIN_DELTA_DAY"] or L["FIN_DELTA_VS_PRIOR"]

    local function seriesHasSignal(values)
        if not values then return false end
        for _, v in ipairs(values) do
            if v ~= 0 then return true end
        end
        return false
    end

    local function setFlowPanel(panel, values, total, colorKey, bipolar)
        panel:SetValue(fmt:FormatGold(total or 0), { color = colorKey })
        local deltaText, tone = FormatBucketDelta(values)
        if panel == panels.expense then
            if tone == "up" then
                tone = "down"
            elseif tone == "down" then
                tone = "up"
            end
        end

        local tipLines = {
            { text = string.format(L["FIN_DASH_SAMPLES"], #flowTxs), r = 0.7, g = 0.7, b = 0.7 },
        }

        if panel == panels.profit then
            local roi = (stats and stats.expense and stats.expense > 0)
                and ((stats.income / stats.expense) * 100) or 0
            panel:SetDelta(string.format(L["FIN_ROI_DELTA"], string.format("%.2f%%", roi)), {
                tone = (roi >= 100 and "up") or (roi > 0 and "neutral") or "down",
            })
        elseif deltaText then
            panel:SetDelta(string.format(deltaLabelFmt, deltaText), { tone = tone })
            table.insert(tipLines, 1, {
                text = L["TT_FIN_DELTA_DESC"],
                r = 0.75, g = 0.75, b = 0.75,
                wrap = true,
            })
        else
            panel:SetDelta(nil)
        end

        if not seriesHasSignal(values) then
            panel:SetRange(nil, nil)
            panel:SetSparkline(nil)
        else
            local hi, lo = api.SeriesRange(values)
            panel:SetRange(
                string.format(L["FIN_HIGH"], fmt:FormatGoldSimple(hi)),
                string.format(L["FIN_LOW"], fmt:FormatGoldSimple(lo))
            )
            panel:SetSparkline(values, { bipolar = bipolar })
        end
        panel:SetTooltipExtra(tipLines)
    end

    setFlowPanel(panels.income, series.income, stats and stats.income or 0, "TEXT_FEATURES_ENABLED", false)
    setFlowPanel(panels.expense, series.expense, stats and stats.expense or 0, "TEXT_WARNING", false)
    local profitColor = (stats and stats.profit or 0) >= 0 and "TEXT_FEATURES_ENABLED" or "TEXT_FEATURES_DISABLED"
    setFlowPanel(panels.profit, series.profit, stats and stats.profit or 0, profitColor, true)

    local endBalance = ResolveWalletEndBalance(characterFilter)
    local wallet = api.BuildWalletSeries(walletTxs, {
        endBalance = endBalance,
        timeStart = timeStart,
        timeEnd = timeEnd,
        characterFilter = characterFilter,
    })
    panels.wallet:SetValue(fmt:FormatGold(endBalance), { color = "TEXT_PRIMARY" })
    panels.wallet:SetDelta(nil)
    if #walletTxs == 0 then
        panels.wallet:SetRange(nil, nil)
        panels.wallet:SetSparkline(nil)
    else
        panels.wallet:SetRange(
            string.format(L["FIN_HIGH"], fmt:FormatGoldSimple(wallet.high or endBalance)),
            string.format(L["FIN_LOW"], fmt:FormatGoldSimple(wallet.low or endBalance))
        )
        panels.wallet:SetSparkline(wallet.points)
    end
    panels.wallet:SetTooltipExtra({
        { text = L["TT_FIN_WALLET_LEDGER"], r = 0.85, g = 0.75, b = 0.4, wrap = true },
        { text = string.format(L["FIN_DASH_SAMPLES"], #walletTxs), r = 0.7, g = 0.7, b = 0.7 },
    })

    local strip = financialsTab.dashboardSummary
    if strip and strip.chips then
        local chips = strip.chips
        chips.earned:SetValue(fmt:FormatGoldSimple(summary.avgIncomePerDay or 0), "TEXT_FEATURES_ENABLED")
        chips.earned:SetSub(FormatTopSubtitle(summary.topIncomeCategory, summary.topItemSold))

        chips.spent:SetValue(fmt:FormatGoldSimple(summary.avgExpensePerDay or 0), "TEXT_WARNING")
        chips.spent:SetSub(FormatTopSubtitle(summary.topExpenseCategory, summary.topItemBought))

        local profitPerDay = summary.avgProfitPerDay or 0
        local profitDayColor = profitPerDay >= 0 and "TEXT_FEATURES_ENABLED" or "TEXT_FEATURES_DISABLED"
        chips.profit:SetValue(fmt:FormatGoldSimple(profitPerDay), profitDayColor)
        chips.profit:SetSub(nil)
    end
end

local function GetAmountDialog()
    if amountDialog then return amountDialog end

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_FinEditAmount",
        showBrand = true,
        title = L["FIN_EDIT_AMOUNT"],
        width = 300,
        height = 120,
        strata = "DIALOG",
        movable = true,
        escClose = true,
    })

    amountDialog = result.frame
    amountDialog:SetFrameLevel(500)
    amountDialog._titleBar = result.titleBar
    amountDialog._contentFrame = result.contentFrame

    local moneyBox = CreateFrame("Frame", "OneWoW_FinAmountInput", result.contentFrame, "MoneyInputFrameTemplate")
    moneyBox:SetPoint("TOP", result.contentFrame, "TOP", 0, -10)
    amountDialog.moneyBox = moneyBox

    local saveBtn = OneWoW_GUI:CreateFitTextButton(result.contentFrame, { text = ACCEPT, height = 26 })
    saveBtn:SetPoint("BOTTOM", result.contentFrame, "BOTTOM", 0, 10)
    amountDialog.saveBtn = saveBtn

    return amountDialog
end

local function ShowEditAmountDialog(tx)
    if not tx or not tx.id then return end
    local dialog = GetAmountDialog()
    dialog:Hide()
    MoneyInputFrame_ResetMoney(dialog.moneyBox)

    local currentGold = math.floor((tx.amount or 0) / 10000)
    local currentSilver = math.floor(((tx.amount or 0) % 10000) / 100)
    local currentCopper = (tx.amount or 0) % 100
    MoneyInputFrame_SetCopper(dialog.moneyBox, currentGold * 10000 + currentSilver * 100 + currentCopper)

    local function doSave()
        local copper = MoneyInputFrame_GetCopper(dialog.moneyBox)
        if copper >= 0 then
            if OneWoW_AltTracker_Accounting_API then
                OneWoW_AltTracker_Accounting_API.UpdateTransaction(tx.id, { amount = copper })
                if activeFinancialsTab and ns.UI.RefreshFinancialsTab then
                    ns.UI.RefreshFinancialsTab(activeFinancialsTab)
                end
            end
        end
        dialog:Hide()
    end

    dialog.saveBtn:SetScript("OnClick", doSave)
    dialog.moneyBox.gold:SetScript("OnEnterPressed", doSave)
    dialog.moneyBox.silver:SetScript("OnEnterPressed", doSave)
    dialog.moneyBox.copper:SetScript("OnEnterPressed", doSave)

    dialog:ClearAllPoints()
    dialog:SetPoint("CENTER")
    dialog:Show()
    dialog.moneyBox.gold:SetFocus()
end

local function GetItemDialog()
    if itemDialog then return itemDialog end

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_FinEditItem",
        showBrand = true,
        title = L["FIN_EDIT_ITEM"],
        width = 350,
        height = 110,
        strata = "DIALOG",
        movable = true,
        escClose = true,
    })

    itemDialog = result.frame
    itemDialog:SetFrameLevel(500)
    itemDialog._contentFrame = result.contentFrame

    local editBox = OneWoW_GUI:CreateEditBox(result.contentFrame, { width = 300, height = 22 })
    editBox:SetPoint("TOP", result.contentFrame, "TOP", 0, -10)
    itemDialog.editBox = editBox

    local saveBtn = OneWoW_GUI:CreateFitTextButton(result.contentFrame, { text = ACCEPT, height = 26 })
    saveBtn:SetPoint("BOTTOM", result.contentFrame, "BOTTOM", 0, 10)
    itemDialog.saveBtn = saveBtn

    return itemDialog
end

local function ShowEditItemNameDialog(tx)
    if not tx or not tx.id then return end
    local dialog = GetItemDialog()
    dialog:Hide()

    dialog.editBox:SetText(tx.itemName or tx.source or "")
    dialog.editBox:HighlightText()

    local function doSave()
        local newName = strtrim(dialog.editBox:GetText())
        if newName ~= "" then
            if OneWoW_AltTracker_Accounting_API then
                OneWoW_AltTracker_Accounting_API.UpdateTransaction(tx.id, { itemName = newName })
                if activeFinancialsTab and ns.UI.RefreshFinancialsTab then
                    ns.UI.RefreshFinancialsTab(activeFinancialsTab)
                end
            end
        end
        dialog:Hide()
    end

    dialog.saveBtn:SetScript("OnClick", doSave)
    dialog.editBox:SetScript("OnEnterPressed", doSave)
    dialog.editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)

    dialog:ClearAllPoints()
    dialog:SetPoint("CENTER")
    dialog:Show()
    dialog.editBox:SetFocus()
end

local function BuildCategoryMenuItems(includeAll)
    local items = {}
    if includeAll then
        table.insert(items, { value = "all", text = ALL })
        table.insert(items, { type = "divider" })
    end
    table.insert(items, { type = "header", text = L["FIN_CAT_GROUP_VENDOR"] })
    table.insert(items, { value = "vendor_purchase", text = L["FIN_CAT_VENDOR_PURCHASE"] })
    table.insert(items, { value = "vendor_sale", text = L["FIN_CAT_VENDOR_SALE"] })
    table.insert(items, { value = "vendor_buyback", text = L["FIN_CAT_VENDOR_BUYBACK"] })
    table.insert(items, { value = "repair", text = L["FIN_CAT_REPAIR"] })
    table.insert(items, { value = "trainer_purchase", text = L["FIN_CAT_TRAINER"] })
    table.insert(items, { value = "transmog", text = L["FIN_CAT_TRANSMOG"] })
    table.insert(items, { type = "divider" })
    table.insert(items, { type = "header", text = L["FIN_CAT_GROUP_AUCTION"] })
    table.insert(items, { value = "auction_sale", text = L["FIN_CAT_AUCTION_SALE"] })
    table.insert(items, { value = "auction_purchase", text = L["FIN_CAT_AUCTION_PURCHASE"] })
    table.insert(items, { value = "auction_deposit", text = L["FIN_CAT_AUCTION_DEPOSIT"] })
    table.insert(items, { value = "auction_fee", text = L["FIN_CAT_AUCTION_FEE"] })
    table.insert(items, { value = "auction_refund", text = L["FIN_CAT_AUCTION_REFUND"] })
    table.insert(items, { value = "auction_cancel_fee", text = L["FIN_CAT_AUCTION_CANCEL"] })
    table.insert(items, { value = "bmah_purchase", text = L["FIN_CAT_BMAH"] })
    table.insert(items, { type = "divider" })
    table.insert(items, { type = "header", text = L["FIN_CAT_GROUP_TRADE"] })
    table.insert(items, { value = "trade_buy", text = L["FIN_CAT_TRADE_BUY"] })
    table.insert(items, { value = "trade_sale", text = L["FIN_CAT_TRADE_SALE"] })
    table.insert(items, { type = "divider" })
    table.insert(items, { type = "header", text = L["MAIL"] })
    table.insert(items, { value = "mail_send", text = L["FIN_CAT_MAIL_SEND"] })
    table.insert(items, { value = "mail_cod_send", text = L["FIN_CAT_MAIL_COD"] })
    table.insert(items, { value = "mail_postage", text = L["FIN_CAT_POSTAGE"] })
    table.insert(items, { type = "divider" })
    table.insert(items, { type = "header", text = L["FIN_CAT_GROUP_BANK"] })
    table.insert(items, { value = "guild_bank_deposit", text = L["FIN_CAT_GUILD_DEPOSIT"] })
    table.insert(items, { value = "guild_bank_withdraw", text = L["FIN_CAT_GUILD_WITHDRAW"] })
    table.insert(items, { value = "warband_bank_deposit", text = L["FIN_CAT_WARBAND_DEPOSIT"] })
    table.insert(items, { value = "warband_bank_withdraw", text = L["FIN_CAT_WARBAND_WITHDRAW"] })
    table.insert(items, { value = "bank_tab_purchase", text = L["FIN_CAT_BANK_TAB"] })
    table.insert(items, { type = "divider" })
    table.insert(items, { type = "header", text = L["FIN_CAT_GROUP_TRANSFER"] })
    table.insert(items, { value = "money_transfer_in", text = L["FIN_CAT_MONEY_IN"] })
    table.insert(items, { value = "money_transfer_out", text = L["FIN_CAT_MONEY_OUT"] })
    table.insert(items, { type = "divider" })
    table.insert(items, { type = "header", text = REWARDS })
    table.insert(items, { value = "quest_reward", text = L["FIN_CAT_QUEST_REWARD"] })
    table.insert(items, { value = "loot_money", text = L["FIN_CAT_LOOT_MONEY"] })
    table.insert(items, { value = "mythicplus_reward", text = L["FIN_CAT_MYTHICPLUS"] })
    table.insert(items, { type = "divider" })
    table.insert(items, { type = "header", text = L["FIN_CAT_GROUP_CRAFTING"] })
    table.insert(items, { value = "crafting_order", text = L["FIN_CAT_CRAFTING_ORDER"] })
    table.insert(items, { value = "crafting_order_placed", text = L["FIN_CAT_ORDER_PLACED"] })
    table.insert(items, { value = "crafting_order_refund", text = L["FIN_CAT_ORDER_REFUND"] })
    table.insert(items, { type = "divider" })
    table.insert(items, { type = "header", text = OTHER })
    table.insert(items, { value = "taxi", text = L["FIN_CAT_TAXI"] })
    table.insert(items, { value = "barber", text = L["FIN_CAT_BARBER"] })
    table.insert(items, { value = "death_cost", text = L["FIN_CAT_DEATH_COST"] })
    table.insert(items, { value = "offline_delta", text = L["FIN_CAT_OFFLINE"] })
    table.insert(items, { value = "uncategorized", text = L["FIN_CAT_UNCATEGORIZED"] })
    return items
end

local categoryChangeTx
local categoryChangeDropdown

local function ShowChangeCategoryMenu(tx)
    if not tx or not tx.id then return end
    categoryChangeTx = tx

    if not categoryChangeDropdown then
        categoryChangeDropdown = OneWoW_GUI:CreateDropdown(UIParent, { width = 220, height = 1 })
        categoryChangeDropdown:SetAlpha(0)
        categoryChangeDropdown:EnableMouse(false)
        categoryChangeDropdown:SetFrameStrata("HIGH")

        OneWoW_GUI:AttachFilterMenu(categoryChangeDropdown, {
            searchable = true,
            menuHeight = 400,
            getActiveValue = function()
                return categoryChangeTx and categoryChangeTx.category or nil
            end,
            buildItems = function()
                return BuildCategoryMenuItems(false)
            end,
            onSelect = function(value)
                if categoryChangeTx and categoryChangeTx.id then
                    if OneWoW_AltTracker_Accounting_API then
                        OneWoW_AltTracker_Accounting_API.UpdateTransaction(categoryChangeTx.id, { category = value })
                        if activeFinancialsTab and ns.UI.RefreshFinancialsTab then
                            ns.UI.RefreshFinancialsTab(activeFinancialsTab)
                        end
                    end
                end
            end,
        })
    end

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    categoryChangeDropdown:ClearAllPoints()
    categoryChangeDropdown:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    categoryChangeDropdown:Show()
    categoryChangeDropdown:GetScript("OnClick")(categoryChangeDropdown)
end

local function ShowDeleteConfirmation(tx)
    if not tx or not tx.id then return end
    local result = OneWoW_GUI:CreateConfirmDialog({
        title = L["FIN_DELETE_CONFIRM"],
        message = L["FIN_DELETE_CONFIRM"],
        buttons = {
            {
                text = DELETE,
                onClick = function(dialog)
                    if OneWoW_AltTracker_Accounting_API then
                        OneWoW_AltTracker_Accounting_API.DeleteTransaction(tx.id)
                        if activeFinancialsTab and ns.UI.RefreshFinancialsTab then
                            ns.UI.RefreshFinancialsTab(activeFinancialsTab)
                        end
                    end
                    dialog:Hide()
                end,
            },
            {
                text = CANCEL,
                onClick = function(dialog)
                    dialog:Hide()
                end,
            },
        },
    })
    result.frame:Show()
end

local function ShowTransactionContextMenu(tx)
    if not tx then return end
    MenuUtil.CreateContextMenu(UIParent, function(_, rootDescription)
        rootDescription:CreateTitle(L["FIN_CONTEXT_TITLE"])

        if not tx.isRollup then
            rootDescription:CreateButton(L["FIN_EDIT_AMOUNT"], function()
                ShowEditAmountDialog(tx)
            end)

            rootDescription:CreateButton(L["FIN_EDIT_ITEM"], function()
                ShowEditItemNameDialog(tx)
            end)

            rootDescription:CreateButton(L["FIN_EDIT_CATEGORY"], function()
                ShowChangeCategoryMenu(tx)
            end)

            rootDescription:CreateDivider()
        end

        local deleteBtn = rootDescription:CreateButton(L["FIN_DELETE_TX"], function()
            ShowDeleteConfirmation(tx)
        end)
        deleteBtn:AddInitializer(function(button)
            button.fontString:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        end)
    end)
end

function ns.UI.SetLoginServerTime()
    loginServerTime = GetServerTime()
end

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
    auction_fee = "FIN_CAT_AUCTION_FEE",
    auction_refund = "FIN_CAT_AUCTION_REFUND",
    auction_cancel_fee = "FIN_CAT_AUCTION_CANCEL",
    trade_buy = "FIN_CAT_TRADE_BUY",
    trade_sale = "FIN_CAT_TRADE_SALE",
    money_transfer_in = "FIN_CAT_MONEY_IN",
    money_transfer_out = "FIN_CAT_MONEY_OUT",
    guild_bank_deposit = "FIN_CAT_GUILD_DEPOSIT",
    guild_bank_withdraw = "FIN_CAT_GUILD_WITHDRAW",
    warband_bank_deposit = "FIN_CAT_WARBAND_DEPOSIT",
    warband_bank_withdraw = "FIN_CAT_WARBAND_WITHDRAW",
    bank_tab_purchase = "FIN_CAT_BANK_TAB",
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
    taxi = "FIN_CAT_TAXI",
    barber = "FIN_CAT_BARBER",
    offline_delta = "FIN_CAT_OFFLINE",
    uncategorized = "FIN_CAT_UNCATEGORIZED",
}

function ns.UI.GetCategoryDisplayName(category)
    local key = categoryNames[category]
    if key then return L[key] end
    return category
end

local columnsConfig = {
    {key = "expand",    label = "",                      width = 25,  fixed = true,  align = "icon",   sortable = false, ttTitle = L["TT_COL_EXPAND"],         ttDesc = L["TT_COL_EXPAND_DESC"]},
    {key = "date",      label = L["FIN_COL_DATE"],      width = 100, fixed = false, align = "left",  ttTitle = L["FIN_COL_DATE"],      ttDesc = L["TT_FIN_COL_DATE_DESC"]},
    {key = "character", label = CHARACTER,  width = 90,  fixed = false, align = "left",  ttTitle = CHARACTER,  ttDesc = L["TT_FIN_COL_CHARACTER_DESC"]},
    {key = "category",  label = CATEGORY,   width = 100, fixed = false, align = "left",  ttTitle = CATEGORY,  ttDesc = L["TT_FIN_COL_CATEGORY_DESC"]},
    {key = "item",      label = L["FIN_COL_ITEM"],       width = 130, fixed = false, align = "left",  ttTitle = L["FIN_COL_ITEM"],      ttDesc = L["TT_FIN_COL_ITEM_DESC"]},
    {key = "amount",    label = L["FIN_COL_AMOUNT"],     width = 80,  fixed = false, align = "right", ttTitle = L["FIN_COL_AMOUNT"],    ttDesc = L["TT_FIN_COL_AMOUNT_DESC"]},
}

local onHeaderCreate = function(btn, col)
    if col.key == "expand" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("CENTER")
        icon:SetAtlas("Gamepad_Rev_Plus_64")
        btn.icon = icon
        if btn.text then btn.text:SetText("") end
    end
end

local function TxExpandKey(tx)
    if not tx then
        return ""
    end
    if tx.id ~= nil then
        return tostring(tx.id)
    end
    return table.concat({
        tostring(tx.timestamp or 0),
        tostring(tx.amount or 0),
        tostring(tx.character or ""),
        tostring(tx.itemName or tx.source or ""),
    }, "\031")
end

local function BuildFinancialListEntries(transactions)
    wipe(listEntries)
    for _, tx in ipairs(transactions or {}) do
        tinsert(listEntries, { type = "tx", tx = tx })
        local key = TxExpandKey(tx)
        if key ~= "" and expandedByTxId[key] then
            tinsert(listEntries, { type = "detail", tx = tx, key = key })
        end
    end
end

local function LayoutFinancialTxCells(row, dt)
    if not (dt and dt.headerRow and dt.headerRow.columnButtons and row.cells) then
        return
    end
    for ci, cell in ipairs(row.cells) do
        local btn = dt.headerRow.columnButtons[ci]
        if btn and btn.columnWidth and btn.columnX then
            local width = btn.columnWidth
            local x = btn.columnX
            local col = columnsConfig[ci]
            cell:ClearAllPoints()
            if col and col.align == "icon" then
                cell:SetSize(width, FIN_ROW_HEIGHT)
                cell:SetPoint("LEFT", row, "LEFT", x, 0)
            elseif col and col.align == "center" then
                cell:SetWidth(width - 6)
                cell:SetPoint("CENTER", row, "LEFT", x + width / 2, 0)
            elseif col and col.align == "right" then
                cell:SetWidth(width - 6)
                cell:SetPoint("RIGHT", row, "LEFT", x + width - 3, 0)
            else
                cell:SetWidth(width - 6)
                cell:SetPoint("LEFT", row, "LEFT", x + 3, 0)
            end
        end
    end
end

local function ToggleFinancialExpand(tx)
    local key = TxExpandKey(tx)
    if key == "" then
        return
    end
    expandedByTxId[key] = not expandedByTxId[key]
    local tab = activeFinancialsTab
    if not tab then
        return
    end
    BuildFinancialListEntries(tab._transactions)
    if listAPI then
        listAPI.Refresh()
    end
end

local function CreateFinancialListRow(parent, _)
    local row = CreateFrame("Frame", nil, parent)
    row:EnableMouse(true)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    bg:SetAlpha(0.6)
    row.bg = bg

    local expandBtn = CreateFrame("Button", nil, row)
    expandBtn:SetSize(25, FIN_ROW_HEIGHT)
    local expandIcon = expandBtn:CreateTexture(nil, "ARTWORK")
    expandIcon:SetSize(14, 14)
    expandIcon:SetPoint("CENTER")
    expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
    expandBtn.icon = expandIcon
    row.expandBtn = expandBtn

    expandBtn:SetScript("OnClick", function()
        local entry = row.entry
        if entry and entry.tx then
            ToggleFinancialExpand(entry.tx)
        end
    end)

    local dateText = OneWoW_GUI:CreateFS(row, 10)
    dateText:SetJustifyH("LEFT")
    row.dateText = dateText

    local charText = OneWoW_GUI:CreateFS(row, 10)
    charText:SetJustifyH("LEFT")
    row.charText = charText

    local categoryText = OneWoW_GUI:CreateFS(row, 10)
    categoryText:SetJustifyH("LEFT")
    row.categoryText = categoryText

    local itemText = OneWoW_GUI:CreateFS(row, 10)
    itemText:SetJustifyH("LEFT")
    row.itemText = itemText

    local amountText = OneWoW_GUI:CreateFS(row, 12)
    amountText:SetJustifyH("RIGHT")
    row.amountText = amountText

    row.cells = { expandBtn, dateText, charText, categoryText, itemText, amountText }

    local detailLine1 = OneWoW_GUI:CreateFS(row, 10)
    detailLine1:SetJustifyH("LEFT")
    detailLine1:SetWordWrap(false)
    detailLine1:Hide()
    row.detailLine1 = detailLine1

    local detailLine2 = OneWoW_GUI:CreateFS(row, 10)
    detailLine2:SetJustifyH("LEFT")
    detailLine2:SetWordWrap(false)
    detailLine2:Hide()
    row.detailLine2 = detailLine2

    row:SetScript("OnEnter", function(myself)
        if myself.entry and myself.entry.type == "tx" then
            myself.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            GameTooltip:SetOwner(myself, "ANCHOR_TOP")
            GameTooltip:SetText(L["RIGHT_CLICK_FOR_MORE_OPTIONS"], 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(myself)
        if myself.entry and myself.entry.type == "detail" then
            myself.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            myself.bg:SetAlpha(0.7)
        else
            myself.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            myself.bg:SetAlpha(0.6)
        end
        GameTooltip:Hide()
    end)
    row:SetScript("OnMouseDown", function(myself, button)
        if button == "RightButton" and myself.entry and myself.entry.tx then
            ShowTransactionContextMenu(myself.entry.tx)
        end
    end)

    return row
end

local function BindFinancialListRow(row, _, entry, _)
    row.entry = entry
    local tab = activeFinancialsTab
    local dt = tab and tab.dataTable
    local tx = entry.tx

    if entry.type == "detail" then
        for _, cell in ipairs(row.cells) do
            cell:Hide()
        end
        row.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        row.bg:SetAlpha(0.7)

        local line1 = L["ID"] .. " " .. (tx.id or "?") .. "  |  " .. date("%Y-%m-%d %H:%M:%S", tx.timestamp or 0)
        row.detailLine1:ClearAllPoints()
        row.detailLine1:SetPoint("TOPLEFT", row, "TOPLEFT", 28, -8)
        row.detailLine1:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -8)
        row.detailLine1:SetText(line1)
        row.detailLine1:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.detailLine1:Show()

        local extras = {}
        if tx.isRollup and tx.rolledCount then
            tinsert(extras, string.format(L["FIN_ROLLED_COUNT"], tx.rolledCount))
        end
        if tx.quantity and tx.quantity > 1 then
            tinsert(extras, L["FIN_EXPANDED_QTY"] .. " " .. tx.quantity)
        end
        if tx.notes then
            tinsert(extras, tx.notes)
        end
        if #extras > 0 then
            row.detailLine2:ClearAllPoints()
            row.detailLine2:SetPoint("TOPLEFT", row.detailLine1, "BOTTOMLEFT", 0, -4)
            row.detailLine2:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, 0)
            row.detailLine2:SetText(table.concat(extras, "  |  "))
            row.detailLine2:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            row.detailLine2:Show()
        else
            row.detailLine2:Hide()
        end
        return
    end

    row.detailLine1:Hide()
    row.detailLine2:Hide()
    row.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    row.bg:SetAlpha(tx.isRollup and 0.35 or 0.6)

    for _, cell in ipairs(row.cells) do
        cell:Show()
    end

    local key = TxExpandKey(tx)
    if row.expandBtn.icon then
        row.expandBtn.icon:SetAtlas(expandedByTxId[key] and "Gamepad_Rev_Minus_64" or "Gamepad_Rev_Plus_64")
    end

    local secondaryColor = tx.isRollup and "TEXT_MUTED" or "TEXT_SECONDARY"
    local primaryColor = tx.isRollup and "TEXT_MUTED" or "TEXT_PRIMARY"

    row.dateText:SetText(date("%m/%d %H:%M", tx.timestamp or 0))
    row.dateText:SetTextColor(OneWoW_GUI:GetThemeColor(secondaryColor))

    local charName = (tx.character or ""):match("^([^%-]+)")
    row.charText:SetText(charName or "?")
    row.charText:SetTextColor(OneWoW_GUI:GetThemeColor(primaryColor))

    row.categoryText:SetText(ns.UI.GetCategoryDisplayName(tx.category))
    row.categoryText:SetTextColor(OneWoW_GUI:GetThemeColor(secondaryColor))

    local itemLabel = tx.itemName or tx.source or ""
    if tx.isRollup then
        itemLabel = L["FIN_SOURCE_DAILY_ROLLUP"]
    end
    row.itemText:SetText(itemLabel)
    row.itemText:SetTextColor(OneWoW_GUI:GetThemeColor(primaryColor))

    local amountFormatted = ns.AltTrackerFormatters:FormatGold(tx.amount or 0)
    if tx.type == "income" then
        row.amountText:SetText("+" .. amountFormatted)
        row.amountText:SetTextColor(OneWoW_GUI:GetThemeColor(tx.isRollup and "TEXT_MUTED" or "TEXT_FEATURES_ENABLED"))
    elseif tx.type == "transfer" then
        row.amountText:SetText(amountFormatted)
        row.amountText:SetTextColor(OneWoW_GUI:GetThemeColor(tx.isRollup and "TEXT_MUTED" or "ACCENT_PRIMARY"))
    else
        row.amountText:SetText("-" .. amountFormatted)
        row.amountText:SetTextColor(OneWoW_GUI:GetThemeColor(tx.isRollup and "TEXT_MUTED" or "TEXT_WARNING"))
    end

    LayoutFinancialTxCells(row, dt)
end

function ns.UI.CreateFinancialsTab(parent)
    local topHost = CreateFrame("Frame", nil, parent)
    topHost:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    topHost:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local overview = OneWoW_GUI:CreateOverviewPanel(topHost, {
        height = 70,
        columns = 5,
        stats = {
            {label = L["FIN_INCOME"],       value = "0", ttTitle = L["FIN_INCOME"],       ttDesc = L["TT_FIN_INCOME_DESC"]},
            {label = L["FIN_EXPENSE"],      value = "0", ttTitle = L["FIN_EXPENSE"],      ttDesc = L["TT_FIN_EXPENSE_DESC"]},
            {label = L["FIN_PROFIT"],       value = "0", ttTitle = L["FIN_PROFIT"],       ttDesc = L["TT_FIN_PROFIT_DESC"]},
            {label = L["FIN_SUCCESS_RATE"], value = "0", ttTitle = L["TT_FIN_ROI"],          ttDesc = L["TT_FIN_ROI_DESC"]},
            {label = L["FIN_TRANSACTIONS"], value = "0", ttTitle = L["FIN_TRANSACTIONS"], ttDesc = L["TT_FIN_TRANSACTIONS_DESC"]},
        },
    })

    local fontOffset = OneWoW_GUI:GetFontSizeOffset() or 0
    local metricHeight = 88
    local summaryHeight = 44 + math.max(0, fontOffset) * 4
    local dashInnerHeight = metricHeight + math.max(0, fontOffset) * 6 + 4 + summaryHeight
    local overviewHostHeight = (overview.panel._baseHeight or 70) + math.max(0, fontOffset) * 8 + 10
    local dashHostHeight = dashInnerHeight + 10
    topHost:SetHeight(overviewHostHeight)

    local dashHost = CreateFrame("Frame", nil, topHost)
    dashHost:SetPoint("TOPLEFT", topHost, "TOPLEFT", 5, -5)
    dashHost:SetPoint("TOPRIGHT", topHost, "TOPRIGHT", -5, -5)
    dashHost:SetHeight(dashInnerHeight)
    dashHost:Hide()

    local metricDefs = {
        { key = "income",  label = L["FIN_INCOME"],  ttDesc = L["TT_FIN_INCOME_DESC"] },
        { key = "expense", label = L["FIN_EXPENSE"], ttDesc = L["TT_FIN_EXPENSE_DESC"] },
        { key = "profit",  label = L["FIN_PROFIT"],  ttDesc = L["TT_FIN_PROFIT_DESC"] },
        { key = "wallet",  label = L["FIN_WALLET"],  ttDesc = L["TT_FIN_WALLET_DESC"] },
    }
    local metricPanels = {}
    local metricList = {}
    for _, def in ipairs(metricDefs) do
        local panel = OneWoW_GUI:CreateMetricPanel(dashHost, {
            label = def.label,
            height = metricHeight,
            ttTitle = def.label,
            ttDesc = def.ttDesc,
        })
        metricPanels[def.key] = panel
        table.insert(metricList, panel)
    end

    local summaryChips = {
        CreateSummaryChip(dashHost, L["FIN_CHIP_EARNED"]),
        CreateSummaryChip(dashHost, L["FIN_CHIP_SPENT"]),
        CreateSummaryChip(dashHost, L["FIN_CHIP_PROFIT"]),
    }
    local summaryByKey = {
        earned = summaryChips[1],
        spent = summaryChips[2],
        profit = summaryChips[3],
    }

    local function LayoutMetricRow()
        local width = dashHost:GetWidth()
        if width <= 0 then return end
        local gap = 6
        local panelW = (width - gap * (#metricList - 1)) / #metricList
        for i, panel in ipairs(metricList) do
            panel:ClearAllPoints()
            panel:SetWidth(panelW)
            if i == 1 then
                panel:SetPoint("TOPLEFT", dashHost, "TOPLEFT", 0, 0)
            else
                panel:SetPoint("TOPLEFT", metricList[i - 1], "TOPRIGHT", gap, 0)
            end
        end
        for i, chip in ipairs(summaryChips) do
            chip:ClearAllPoints()
            chip:SetHeight(summaryHeight)
            chip:SetPoint("TOPLEFT", metricList[i], "BOTTOMLEFT", 0, -4)
            chip:SetPoint("TOPRIGHT", metricList[i], "BOTTOMRIGHT", 0, -4)
        end
    end
    dashHost:SetScript("OnSizeChanged", LayoutMetricRow)
    LayoutMetricRow()

    local filterPanel = OneWoW_GUI:CreateFilterBar(parent, { height = 32, anchorBelow = topHost, offset = -8 })

    parent.timePeriod = "week"
    parent.typeFilter = "all"
    parent.characterFilter = nil
    parent.categoryFilter = nil

    local timePeriods = {
        {key = "login",  label = L["SESSION"], tooltip = L["FIN_PERIOD_SESSION_TT"]},
        {key = "today",  label = L["FIN_PERIOD_TODAY"],   tooltip = L["FIN_PERIOD_TODAY_TT"]},
        {key = "week",   label = L["FIN_PERIOD_WEEK"],    tooltip = L["FIN_PERIOD_WEEK_TT"]},
        {key = "month",  label = L["FIN_PERIOD_MONTH"],   tooltip = L["FIN_PERIOD_MONTH_TT"]},
        {key = "reset",  label = CUSTOM,  tooltip = L["FIN_PERIOD_CUSTOM_TT"]},
        {key = "all",    label = ALL,     tooltip = L["FIN_PERIOD_ALL_TT"]},
    }

    local periodDropdown = OneWoW_GUI:CreateDropdown(filterPanel, {
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
        {key = "all",     label = ALL},
        {key = "income",  label = L["FIN_INCOME"]},
        {key = "expense", label = L["FIN_EXPENSE"]},
    }

    local typeDropdown = OneWoW_GUI:CreateDropdown(filterPanel, {
        width = 110,
        height = 24,
        text = ALL,
    })
    typeDropdown:SetPoint("LEFT", periodDropdown, "RIGHT", 25, 0)

    OneWoW_GUI:AttachFilterMenu(typeDropdown, {
        searchable = false,
        menuHeight = #typeFilters * 26 + 8,
        buildItems = function()
            local items = {}
            for _, filter in ipairs(typeFilters) do
                table.insert(items, {
                    text = filter.label,
                    value = filter.key,
                })
            end
            return items
        end,
        onSelect = function(value, text)
            parent.typeFilter = value
            typeDropdown._text:SetText(text)
            if ns.UI.RefreshFinancialsTab then
                ns.UI.RefreshFinancialsTab(parent)
            end
        end,
        getActiveValue = function()
            return parent.typeFilter
        end,
    })

    local charLabel = OneWoW_GUI:CreateFS(filterPanel, 10)
    charLabel:SetPoint("LEFT", typeDropdown, "RIGHT", 25, 0)
    charLabel:SetText(L["FIN_CHAR_LABEL"])
    charLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local charBtn = OneWoW_GUI:CreateFitTextButton(filterPanel, { text = ALL, height = 24 })
    charBtn:SetPoint("LEFT", charLabel, "RIGHT", 2, 0)

    charBtn:SetScript("OnClick", function(self)
        if parent.characterFilter then
            parent.characterFilter = nil
            self:SetFitText(ALL)
        else
            local charKey = ns.AltTrackerFormatters:GetCurrentCharacterKey()
            parent.characterFilter = charKey
            local charName = charKey:match("^([^%-]+)")
            self:SetFitText(charName or "?")
        end
        if ns.UI.RefreshFinancialsTab then
            ns.UI.RefreshFinancialsTab(parent)
        end
    end)

    local catLabel = OneWoW_GUI:CreateFS(filterPanel, 10)
    catLabel:SetPoint("LEFT", charBtn, "RIGHT", 25, 0)
    catLabel:SetText(CATEGORY)
    catLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local catDropdown = OneWoW_GUI:CreateDropdown(filterPanel, { width = 140, height = 24, text = ALL })
    catDropdown:SetPoint("LEFT", catLabel, "RIGHT", 2, 0)

    OneWoW_GUI:AttachFilterMenu(catDropdown, {
        searchable = true,
        menuHeight = 400,
        getActiveValue = function()
            return parent.categoryFilter or "all"
        end,
        buildItems = function()
            return BuildCategoryMenuItems(true)
        end,
        onSelect = function(value, text)
            if value == "all" then
                parent.categoryFilter = nil
                catDropdown._text:SetText(ALL)
            else
                parent.categoryFilter = value
                catDropdown._text:SetText(text)
            end
            if ns.UI.RefreshFinancialsTab then
                ns.UI.RefreshFinancialsTab(parent)
            end
        end,
    })

    local dashboardBtn = OneWoW_GUI:CreateFitTextButton(filterPanel, {
        text = L["FIN_DASHBOARD"],
        height = 24,
        toggleable = true,
    })
    dashboardBtn:SetPoint("LEFT", catDropdown, "RIGHT", 25, 0)

    local settingsBtn = OneWoW_GUI:CreateAtlasIconButton(filterPanel, {
        atlas = "mechagon-projects",
        width = 24,
        height = 24,
    })
    settingsBtn:SetPoint("RIGHT", filterPanel, "RIGHT", -10, 0)

    local optionsPanel = OneWoW_GUI:CreateFilterBar(parent, {
        height = 32,
        anchorBelow = filterPanel,
        offset = -4,
    })

    local RETENTION_DAYS = { 0, 30, 60, 90, 180, 365 }

    local function RetentionLabel(days)
        if not days or days <= 0 then
            return OFF
        end
        return string.format(L["FIN_RETENTION_DAYS"], days)
    end

    local retentionLabel = OneWoW_GUI:CreateFS(optionsPanel, 10)
    retentionLabel:SetPoint("LEFT", optionsPanel, "LEFT", 8, 0)
    retentionLabel:SetText(L["FIN_DETAIL_RETENTION"])
    retentionLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local retentionDropdown = OneWoW_GUI:CreateDropdown(optionsPanel, {
        width = 100,
        height = 24,
        text = RetentionLabel(0),
    })
    retentionDropdown:SetPoint("LEFT", retentionLabel, "RIGHT", 4, 0)

    OneWoW_GUI:AttachFilterMenu(retentionDropdown, {
        menuHeight = #RETENTION_DAYS * 26 + 8,
        getActiveValue = function()
            return OneWoW_AltTracker_Accounting_API
                and OneWoW_AltTracker_Accounting_API.GetDetailRetentionDays()
                or 0
        end,
        buildItems = function()
            local items = {}
            for i = 1, #RETENTION_DAYS do
                local days = RETENTION_DAYS[i]
                tinsert(items, { value = days, text = RetentionLabel(days) })
            end
            return items
        end,
        onSelect = function(value, text)
            if OneWoW_AltTracker_Accounting_API then
                OneWoW_AltTracker_Accounting_API.SetDetailRetentionDays(value)
            end
            retentionDropdown._text:SetText(text)
        end,
    })

    retentionDropdown:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(L["FIN_DETAIL_RETENTION"], 1, 1, 1)
        GameTooltip:AddLine(L["FIN_DETAIL_RETENTION_TT"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    retentionDropdown:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local guildPersonalCheck = OneWoW_GUI:CreateCheckbox(optionsPanel, { label = L["FIN_GUILD_AS_PERSONAL"] })
    guildPersonalCheck:SetPoint("LEFT", retentionDropdown, "RIGHT", 20, 0)

    guildPersonalCheck:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(L["FIN_GUILD_AS_PERSONAL"], 1, 1, 1)
        GameTooltip:AddLine(L["FIN_GUILD_AS_PERSONAL_TT"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    guildPersonalCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    guildPersonalCheck:SetScript("OnClick", function(myself)
        if OneWoW_AltTracker_Accounting_API then
            OneWoW_AltTracker_Accounting_API.SetGuildAsPersonal(myself:GetChecked() and true or false)
        end
    end)

    local resetBtn = OneWoW_GUI:CreateFitTextButton(optionsPanel, { text = L["FIN_RESET_DATA"], height = 24 })
    resetBtn:SetPoint("RIGHT", optionsPanel, "RIGHT", -10, 0)
    resetBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
    resetBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
    resetBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))

    resetBtn:SetScript("OnClick", function()
        local result = OneWoW_GUI:CreateConfirmDialog({
            title = L["FIN_RESET_CONFIRM"],
            message = L["FIN_RESET_CONFIRM"],
            buttons = {
                {
                    text = L["FIN_RESET_ACCEPT"],
                    onClick = function(dialog)
                        if OneWoW_AltTracker_Accounting_API then
                            OneWoW_AltTracker_Accounting_API.ResetAll()
                        end
                        parent.timePeriod = "week"
                        if ns.UI.RefreshFinancialsTab then
                            ns.UI.RefreshFinancialsTab(parent)
                        end
                        dialog:Hide()
                    end,
                },
                {
                    text = CANCEL,
                    onClick = function(dialog)
                        dialog:Hide()
                    end,
                },
            },
        })
        result.frame:Show()
    end)

    resetBtn:SetScript("OnEnter", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER"))
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(L["FIN_RESET_TT"], 1, 0.3, 0.3)
        GameTooltip:AddLine(L["FIN_RESET_TT_DESC"], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)

    resetBtn:SetScript("OnLeave", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
        GameTooltip:Hide()
    end)

    C_Timer.After(0.6, function()
        if OneWoW_AltTracker_Accounting_API then
            retentionDropdown._text:SetText(
                RetentionLabel(OneWoW_AltTracker_Accounting_API.GetDetailRetentionDays())
            )
            guildPersonalCheck:SetChecked(OneWoW_AltTracker_Accounting_API.GetGuildAsPersonal())
        end
    end)

    local rosterPanel = OneWoW_GUI:CreateRosterPanel(parent, filterPanel)

    local function SyncSettingsBtn(open)
        settingsBtn.isActive = open and true or false
        if open then
            settingsBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            settingsBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            settingsBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            settingsBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        end
    end

    local function ApplyOptionsOpen(open, persist)
        open = open and true or false
        parent.optionsOpen = open
        if persist and OneWoW_AltTracker_Accounting_API then
            OneWoW_AltTracker_Accounting_API.SetFinancialsOptionsOpen(open)
        end
        SyncSettingsBtn(open)
        if open then
            optionsPanel:SetHeight(32)
            optionsPanel:Show()
            rosterPanel:ClearAllPoints()
            rosterPanel:SetPoint("TOPLEFT", optionsPanel, "BOTTOMLEFT", 0, -8)
            rosterPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 30)
        else
            optionsPanel:Hide()
            optionsPanel:SetHeight(1)
            rosterPanel:ClearAllPoints()
            rosterPanel:SetPoint("TOPLEFT", filterPanel, "BOTTOMLEFT", 0, -8)
            rosterPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 30)
        end
    end

    settingsBtn:SetScript("OnClick", function()
        ApplyOptionsOpen(not parent.optionsOpen, true)
    end)
    settingsBtn:HookScript("OnEnter", function(myself)
        if myself.isActive then
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        else
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        end
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(SETTINGS, 1, 1, 1)
        GameTooltip:AddLine(L["FIN_OPTIONS_TT"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    settingsBtn:HookScript("OnLeave", function()
        SyncSettingsBtn(parent.optionsOpen)
        GameTooltip:Hide()
    end)

    local function SetDashboardMode(on)
        dashboardMode = on and true or false
        parent.dashboardMode = dashboardMode
        if OneWoW_AltTracker_Accounting_API then
            OneWoW_AltTracker_Accounting_API.SetFinancialsDashboard(dashboardMode)
        end
        dashboardBtn:SetActive(dashboardMode)
        if dashboardMode then
            overview.panel:Hide()
            dashHost:Show()
            topHost:SetHeight(dashHostHeight)
            LayoutMetricRow()
        else
            dashHost:Hide()
            overview.panel:Show()
            topHost:SetHeight(overviewHostHeight)
        end
        if ns.UI.RefreshFinancialsTab then
            ns.UI.RefreshFinancialsTab(parent)
        end
    end

    dashboardBtn:SetScript("OnClick", function()
        SetDashboardMode(not dashboardMode)
    end)
    dashboardBtn:SetScript("OnEnter", function(self)
        if self.isActive then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
            self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["FIN_DASHBOARD"], 1, 1, 1)
        GameTooltip:AddLine(L["TT_FIN_DASHBOARD"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    dashboardBtn:SetScript("OnLeave", function(self)
        self:SetActive(self.isActive)
        GameTooltip:Hide()
    end)

    -- Initial options row state (default closed; restore after Accounting is ready).
    ApplyOptionsOpen(false, false)
    C_Timer.After(0.6, function()
        local open = OneWoW_AltTracker_Accounting_API
            and OneWoW_AltTracker_Accounting_API.GetFinancialsOptionsOpen()
        ApplyOptionsOpen(open, false)
    end)

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

    listAPI = OneWoW_GUI:CreateVirtualizer(rosterPanel, {
        name = "AltTrackerFinancialsList",
        rowHeight = FIN_TX_STRIDE,
        minRowHeight = FIN_TX_STRIDE,
        numVisibleRows = 16,
        selectOnClick = false,
        scrollFrame = dt.scrollFrame,
        content = dt.scrollContent,
        getCount = function()
            return #listEntries
        end,
        getEntry = function(index)
            return listEntries[index]
        end,
        getRowHeight = function(index)
            local entry = listEntries[index]
            if entry and entry.type == "detail" then
                return FIN_DETAIL_STRIDE
            end
            return FIN_TX_STRIDE
        end,
        createRow = CreateFinancialListRow,
        bindRow = BindFinancialListRow,
    })

    local origUpdateColumnLayout = dt.UpdateColumnLayout
    dt.UpdateColumnLayout = function(...)
        origUpdateColumnLayout(...)
        if listAPI then
            listAPI.Refresh()
        end
    end

    local status = OneWoW_GUI:CreateStatusBar(parent, rosterPanel, {
        text = string.format(L["FIN_STATUS_COUNT"], 0),
    })

    parent.overviewPanel = overview.panel
    parent.statBoxes = overview.statBoxes
    parent.topHost = topHost
    parent.dashHost = dashHost
    parent.metricPanels = metricPanels
    parent.dashboardSummary = { chips = summaryByKey }
    parent.dashboardBtn = dashboardBtn
    parent.filterPanel = filterPanel
    parent.optionsPanel = optionsPanel
    parent.settingsBtn = settingsBtn
    parent.rosterPanel = rosterPanel
    parent.dataTable = dt
    parent.columnsConfig = columnsConfig
    parent.headerRow = dt.headerRow
    parent.scrollContent = dt.scrollContent
    parent.scrollFrame = dt.scrollFrame
    parent.listAPI = listAPI
    parent.statusBar = status.bar
    parent.statusText = status.text
    parent.dashboardMode = false

    parent.financialsDirty = false
    activeFinancialsTab = parent

    -- Accounting is LoD; wire the live listener and first paint when its data
    -- boundary fires (catch-up if already ready). Replaces the old timed poll.
    local listenerWired = false
    local function WireAccountingListener()
        if listenerWired or not OneWoW_AltTracker_Accounting_API then return end
        listenerWired = true
        local refreshPending = false
        OneWoW_AltTracker_Accounting_API.SetTransactionListener(function()
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
        end)
    end

    local function OnAccountingReady()
        WireAccountingListener()
        local saved = OneWoW_AltTracker_Accounting_API
            and OneWoW_AltTracker_Accounting_API.GetFinancialsDashboard()
        if saved then
            SetDashboardMode(true)
        elseif ns.UI.RefreshFinancialsTab then
            ns.UI.RefreshFinancialsTab(parent)
        end
    end

    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Accounting", OnAccountingReady)
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Character", function()
        if OneWoW_AltTracker_Accounting_API and ns.UI.RefreshFinancialsTab then
            ns.UI.RefreshFinancialsTab(parent)
        end
    end)

    parent:HookScript("OnShow", function()
        if parent.financialsDirty then
            parent.financialsDirty = false
            ns.UI.RefreshFinancialsTab(parent)
        elseif parent.dataTable then
            -- First open after a create-time refresh can bind rows before column
            -- geometry exists; re-run layout (wrap also refreshes the list).
            C_Timer.After(0.1, function()
                if parent:IsShown() and parent.dataTable then
                    parent.dataTable.UpdateColumnLayout()
                end
            end)
        end
    end)

    OneWoW_GUI:ApplyFontToFrame(parent)
end

function ns.UI.RefreshFinancialsTab(financialsTab)
    if not financialsTab then return end

    if not OneWoW_AltTracker_Accounting_API then
        wipe(listEntries)
        if listAPI then
            listAPI.Refresh()
        end
        if financialsTab.statusText then
            financialsTab.statusText:SetText(L["FIN_INSTALL_ACCOUNTING"])
        end
        return
    end

    if not financialsTab.scrollContent then return end

    local allTransactions = OneWoW_AltTracker_Accounting_API.GetTransactions()
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
        local customReset = OneWoW_AltTracker_Accounting_API.GetCustomResetDate()
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

    if financialsTab.statBoxes and OneWoW_AltTracker_Accounting_API then
        local stats = OneWoW_AltTracker_Accounting_API.CalculateStatistics(timeStart, now, characterFilter, categoryFilter)

        if financialsTab.dashboardMode or dashboardMode then
            RefreshDashboardPanels(
                financialsTab,
                allTransactions,
                timeStart,
                now,
                characterFilter,
                categoryFilter,
                typeFilter,
                stats
            )
        end

        if financialsTab.statBoxes[1] then
            financialsTab.statBoxes[1].value:SetText(ns.AltTrackerFormatters:FormatGold(stats.income))
            financialsTab.statBoxes[1].value:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))

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
            financialsTab.statBoxes[2].value:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))

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
                financialsTab.statBoxes[3].value:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                financialsTab.statBoxes[3].value:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            end
        end

        if financialsTab.statBoxes[4] then
            local roi = stats.expense > 0 and ((stats.income / stats.expense) * 100) or 0
            financialsTab.statBoxes[4].value:SetText(string.format("%.2f%%", roi))
        end

        if financialsTab.statBoxes[5] then
            financialsTab.statBoxes[5].value:SetText(tostring(stats.transactionCount))
        end
    end

    if #transactions == 0 then
        financialsTab._transactions = transactions
        wipe(listEntries)
        if listAPI then
            listAPI.Refresh()
        end
        if financialsTab.statusText then
            if #allTransactions == 0 then
                financialsTab.statusText:SetText(L["FIN_NO_TRANSACTIONS"])
            else
                financialsTab.statusText:SetText(L["FIN_NO_MATCH"])
            end
        end
        C_Timer.After(0.1, function()
            if financialsTab.dataTable then
                financialsTab.dataTable.UpdateColumnLayout()
            end
        end)
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

    financialsTab._transactions = transactions
    BuildFinancialListEntries(transactions)
    if listAPI then
        listAPI.Refresh()
    end

    OneWoW_GUI:ApplyFontToFrame(financialsTab)

    if financialsTab.statusText then
        financialsTab.statusText:SetText(string.format(L["FIN_STATUS_COUNT"], #transactions))
    end

    -- Mirror Summary: deferred layout through the wrapped API so virtualizer
    -- rows rebind after columnWidth/columnX exist (first paint race).
    C_Timer.After(0.1, function()
        if financialsTab.dataTable then
            financialsTab.dataTable.UpdateColumnLayout()
        end
    end)
end
