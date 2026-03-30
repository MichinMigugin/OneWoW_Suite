local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankLog = {}
local GuildBankLog = OneWoW_Bags.GuildBankLog
local OneWoW_GUI = OneWoW_Bags.GUILib
local T = OneWoW_Bags.T
local S = OneWoW_Bags.S

local logFrame = nil
local scrollFrame = nil
local textContent = nil
local logText = nil
local isInitialized = false
local currentMode = "items"

local PANEL_WIDTH = 420
local PANEL_HEIGHT = 420
local TITLEBAR_HEIGHT = 28

function GuildBankLog:Init()
    if isInitialized then return end
    local L = OneWoW_Bags.L

    logFrame = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_GuildBankLogFrame",
        width = PANEL_WIDTH,
        height = PANEL_HEIGHT,
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
    })
    if not logFrame then return end

    logFrame:SetMovable(true)
    logFrame:EnableMouse(true)
    logFrame:RegisterForDrag("LeftButton")
    logFrame:SetScript("OnDragStart", logFrame.StartMoving)
    logFrame:SetScript("OnDragStop", logFrame.StopMovingOrSizing)
    logFrame:SetClampedToScreen(true)
    logFrame:SetClampRectInsets(0, 0, 0, 0)
    logFrame:SetFrameStrata("DIALOG")
    logFrame:SetToplevel(true)
    logFrame:Hide()

    local titleBar = OneWoW_GUI:CreateTitleBar(logFrame, {
        title = L["GUILD_BANK_LOG"] or "Guild Bank Log",
        height = TITLEBAR_HEIGHT,
        showBrand = false,
        onClose = function() logFrame:Hide() end,
    })
    logFrame.titleBar = titleBar

    local filterArea = CreateFrame("Frame", nil, logFrame)
    filterArea:SetHeight(26)
    filterArea:SetPoint("TOPLEFT", logFrame, "TOPLEFT", S("XS"), -(S("XS") + TITLEBAR_HEIGHT + S("XS")))
    filterArea:SetPoint("TOPRIGHT", logFrame, "TOPRIGHT", -S("XS"), -(S("XS") + TITLEBAR_HEIGHT + S("XS")))

    local itemsBtn = OneWoW_GUI:CreateFitTextButton(filterArea, { text = L["GUILD_BANK_ITEMS_LOG"] or "Items", height = 22, minWidth = 50 })
    itemsBtn:SetPoint("TOPLEFT", filterArea, "TOPLEFT", 0, 0)
    itemsBtn:SetScript("OnClick", function()
        GuildBankLog:ShowItems()
    end)

    local goldBtn = OneWoW_GUI:CreateFitTextButton(filterArea, { text = L["GUILD_BANK_MONEY_LOG"] or "Gold", height = 22, minWidth = 50 })
    goldBtn:SetPoint("TOPLEFT", itemsBtn, "TOPRIGHT", 4, 0)
    goldBtn:SetScript("OnClick", function()
        GuildBankLog:ShowGold()
    end)

    logFrame.itemsBtn = itemsBtn
    logFrame.goldBtn = goldBtn

    local scrollName = "OneWoW_GuildBankLogScroll"
    scrollFrame = CreateFrame("ScrollFrame", scrollName, logFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", filterArea, "BOTTOMLEFT", 0, -S("XS"))
    scrollFrame:SetPoint("BOTTOMRIGHT", logFrame, "BOTTOMRIGHT", -S("XS") - 16, S("XS"))

    OneWoW_GUI:StyleScrollBar(scrollFrame, { container = logFrame, offset = 0 })

    textContent = CreateFrame("Frame", scrollName .. "Content", scrollFrame)
    textContent:SetHeight(1)
    scrollFrame:SetScrollChild(textContent)
    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        textContent:SetWidth(w)
        if logText then
            logText:SetWidth(w - 8)
        end
    end)

    logText = textContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    logText:SetPoint("TOPLEFT", textContent, "TOPLEFT", 4, -4)
    logText:SetWidth(PANEL_WIDTH - S("XS") - 16 - 8)
    logText:SetJustifyH("LEFT")
    logText:SetJustifyV("TOP")
    logText:SetNonSpaceWrap(true)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GUILDBANKLOG_UPDATE")
    eventFrame:SetScript("OnEvent", function(self, event)
        if logFrame and logFrame:IsShown() then
            GuildBankLog:Refresh()
        end
    end)

    _G["OneWoW_GuildBankLogFrame"] = logFrame
    isInitialized = true
    GuildBankLog:UpdateFilterButtons()
end

function GuildBankLog:UpdateFilterButtons()
    if not logFrame then return end
    local itemsBtn = logFrame.itemsBtn
    local goldBtn = logFrame.goldBtn
    if not itemsBtn or not goldBtn then return end

    if currentMode == "items" then
        itemsBtn:SetBackdropColor(T("BG_ACTIVE"))
        itemsBtn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
        itemsBtn.text:SetTextColor(T("TEXT_ACCENT"))
        goldBtn:SetBackdropColor(T("BTN_NORMAL"))
        goldBtn:SetBackdropBorderColor(T("BTN_BORDER"))
        goldBtn.text:SetTextColor(T("TEXT_PRIMARY"))
    else
        goldBtn:SetBackdropColor(T("BG_ACTIVE"))
        goldBtn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
        goldBtn.text:SetTextColor(T("TEXT_ACCENT"))
        itemsBtn:SetBackdropColor(T("BTN_NORMAL"))
        itemsBtn:SetBackdropBorderColor(T("BTN_BORDER"))
        itemsBtn.text:SetTextColor(T("TEXT_PRIMARY"))
    end
end

function GuildBankLog:SetText(msg)
    if not logText then return end
    logText:SetText(msg)
    if textContent then
        textContent:SetHeight(math.max(1, logText:GetStringHeight() + 8))
    end
    if scrollFrame then
        scrollFrame:SetVerticalScroll(0)
    end
end

function GuildBankLog:RefreshItems()
    local L = OneWoW_Bags.L
    local tab = GetCurrentGuildBankTab()
    local numTransactions = GetNumGuildBankTransactions(tab)
    local msg = ""

    for i = numTransactions, 1, -1 do
        local txType, name, itemLink, count, tab1, tab2, year, month, day, hour = GetGuildBankTransaction(tab, i)
        if not name then name = UNKNOWN end
        name = NORMAL_FONT_COLOR_CODE .. name .. FONT_COLOR_CODE_CLOSE
        if txType == "deposit" then
            msg = msg .. string.format(GUILDBANK_DEPOSIT_FORMAT, name, itemLink)
            if count > 1 then
                msg = msg .. string.format(GUILDBANK_LOG_QUANTITY, count)
            end
        elseif txType == "withdraw" then
            msg = msg .. string.format(GUILDBANK_WITHDRAW_FORMAT, name, itemLink)
            if count > 1 then
                msg = msg .. string.format(GUILDBANK_LOG_QUANTITY, count)
            end
        elseif txType == "move" then
            msg = msg .. string.format(GUILDBANK_MOVE_FORMAT, name, itemLink, count, GetGuildBankTabInfo(tab1), GetGuildBankTabInfo(tab2))
        end
        if GUILD_BANK_LOG_TIME then
            msg = msg .. GUILD_BANK_LOG_TIME:format(RecentTimeDate(year, month, day, hour))
        end
        msg = msg .. "\n"
    end

    if numTransactions == 0 then
        msg = L["GUILD_BANK_NO_LOG"] or "No transactions available."
    end

    GuildBankLog:SetText(msg)
end

function GuildBankLog:RefreshGold()
    local L = OneWoW_Bags.L
    local numTransactions = GetNumGuildBankMoneyTransactions()
    local msg = ""

    for i = numTransactions, 1, -1 do
        local txType, name, amount, year, month, day, hour = GetGuildBankMoneyTransaction(i)
        if not name then name = UNKNOWN end
        name = NORMAL_FONT_COLOR_CODE .. name .. FONT_COLOR_CODE_CLOSE
        local money = GetMoneyString(amount, true)
        if txType == "deposit" then
            msg = msg .. string.format(GUILDBANK_DEPOSIT_MONEY_FORMAT, name, money)
        elseif txType == "withdraw" then
            msg = msg .. string.format(GUILDBANK_WITHDRAW_MONEY_FORMAT, name, money)
        elseif txType == "repair" then
            msg = msg .. string.format(GUILDBANK_REPAIR_MONEY_FORMAT, name, money)
        elseif txType == "withdrawForTab" then
            msg = msg .. string.format(GUILDBANK_WITHDRAWFORTAB_MONEY_FORMAT, name, money)
        elseif txType == "buyTab" then
            if amount > 0 then
                msg = msg .. string.format(GUILDBANK_BUYTAB_MONEY_FORMAT, name, money)
            else
                msg = msg .. string.format(GUILDBANK_UNLOCKTAB_FORMAT, name)
            end
        elseif txType == "depositSummary" then
            msg = msg .. string.format(GUILDBANK_AWARD_MONEY_SUMMARY_FORMAT, money)
        end
        if GUILD_BANK_LOG_TIME then
            msg = msg .. GUILD_BANK_LOG_TIME:format(RecentTimeDate(year, month, day, hour))
        end
        msg = msg .. "\n"
    end

    if numTransactions == 0 then
        msg = L["GUILD_BANK_NO_LOG"] or "No transactions available."
    end

    GuildBankLog:SetText(msg)
end

function GuildBankLog:Refresh()
    if currentMode == "items" then
        GuildBankLog:RefreshItems()
    else
        GuildBankLog:RefreshGold()
    end
end

function GuildBankLog:ShowItems()
    if not isInitialized then GuildBankLog:Init() end
    if not logFrame then return end
    currentMode = "items"
    GuildBankLog:UpdateFilterButtons()
    if not logFrame:IsShown() then
        GuildBankLog:PositionNearMainWindow()
        logFrame:Show()
    end
    QueryGuildBankLog(GetCurrentGuildBankTab())
    GuildBankLog:RefreshItems()
end

function GuildBankLog:ShowGold()
    if not isInitialized then GuildBankLog:Init() end
    if not logFrame then return end
    currentMode = "gold"
    GuildBankLog:UpdateFilterButtons()
    if not logFrame:IsShown() then
        GuildBankLog:PositionNearMainWindow()
        logFrame:Show()
    end
    QueryGuildBankLog(MAX_GUILDBANK_TABS + 1)
    GuildBankLog:RefreshGold()
end

function GuildBankLog:Toggle()
    if not isInitialized then GuildBankLog:Init() end
    if not logFrame then return end
    if logFrame:IsShown() then
        logFrame:Hide()
    else
        GuildBankLog:ShowItems()
    end
end

function GuildBankLog:OnTabChanged()
    if not logFrame or not logFrame:IsShown() then return end
    if currentMode == "items" then
        C_Timer.After(0.1, function()
            QueryGuildBankLog(GetCurrentGuildBankTab())
            GuildBankLog:RefreshItems()
        end)
    end
end

function GuildBankLog:PositionNearMainWindow()
    if not logFrame then return end
    local mainWindow = OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI:GetMainWindow()
    if mainWindow then
        logFrame:ClearAllPoints()
        logFrame:SetPoint("TOPLEFT", mainWindow, "TOPRIGHT", 4, 0)
    else
        logFrame:ClearAllPoints()
        logFrame:SetPoint("CENTER")
    end
end

function GuildBankLog:GetFrame()
    return logFrame
end

function GuildBankLog:Hide()
    if logFrame then
        logFrame:Hide()
    end
end

function GuildBankLog:Reset()
    if logFrame then
        logFrame:Hide()
        logFrame:SetParent(UIParent)
    end
    logFrame = nil
    scrollFrame = nil
    textContent = nil
    logText = nil
    isInitialized = false
    currentMode = "items"
end

function GuildBankLog:ApplyTheme()
    if not logFrame then return end
    logFrame:SetBackdropColor(T("BG_PRIMARY"))
    logFrame:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    GuildBankLog:UpdateFilterButtons()
end
