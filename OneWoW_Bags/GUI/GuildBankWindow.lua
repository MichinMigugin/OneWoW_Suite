local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankGUI = OneWoW_Bags.GuildBankGUI or {}
local GBGUI = OneWoW_Bags.GuildBankGUI
local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local OneWoW_GUI = OneWoW_Bags.GUILib

local GBWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil
local contentMode = "items"
local logEntryFrames = {}

local function T(key)
    return OneWoW_GUI:GetThemeColor(key)
end

local function S(key)
    return OneWoW_GUI:GetSpacing(key)
end

local function FormatNumber(n)
    local s = tostring(n)
    local pos = #s % 3
    if pos == 0 then pos = 3 end
    local parts = { s:sub(1, pos) }
    for i = pos + 1, #s, 3 do
        parts[#parts + 1] = s:sub(i, i + 2)
    end
    return table.concat(parts, ",")
end

local function FormatGold(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    if gold > 0 then
        return string.format("|cFFFFD100%sg|r |cFFC0C0C0%ds|r |cFFAD6A24%dc|r", FormatNumber(gold), silver, cop)
    elseif silver > 0 then
        return string.format("|cFFC0C0C0%ds|r |cFFAD6A24%dc|r", silver, cop)
    else
        return string.format("|cFFAD6A24%dc|r", cop)
    end
end

function GBGUI:InitWindow()
    if isInitialized then return end
    if not Constants or not Constants.GUI then return end

    local C = Constants.GUI
    local db = OneWoW_Bags.db
    local savedHeight = db and db.global and db.global.guildBankWindowHeight
    local windowHeight = savedHeight or C.WINDOW_HEIGHT
    local savedWidth = db and db.global and db.global.guildBankWindowWidth
    local windowWidth = savedWidth or C.WINDOW_WIDTH

    GBWindow = CreateFrame("Frame", "OneWoW_GuildBankMainWindow", UIParent, "BackdropTemplate")
    GBWindow:SetSize(windowWidth, windowHeight)
    GBWindow:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SOFT)

    if not GBWindow then return end

    GBWindow:SetBackdropColor(T("BG_PRIMARY"))
    GBWindow:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    GBWindow:SetPoint("CENTER")
    GBWindow:SetMovable(true)
    GBWindow:SetResizable(true)
    GBWindow:SetResizeBounds(300, 300, 1400, 1200)
    GBWindow:EnableMouse(true)
    GBWindow:RegisterForDrag("LeftButton")
    GBWindow:SetScript("OnDragStart", GBWindow.StartMoving)
    GBWindow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if db and db.global then
            local point, _, relPoint, x, y = self:GetPoint()
            db.global.guildBankWindowPosition = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    GBWindow:SetClampedToScreen(true)
    GBWindow:SetFrameStrata("MEDIUM")
    GBWindow:SetToplevel(true)

    GBWindow._ready = false
    GBWindow:SetScript("OnHide", function()
        if not GBWindow._ready then return end
        GBGUI:CleanupAllViews()
        if OneWoW_Bags.guildBankOpen then
            OneWoW_Bags.guildBankOpen = false
            if OneWoW_Bags.GuildBankSet then
                OneWoW_Bags.GuildBankSet:ReleaseAll()
            end
            CloseGuildBankFrame()
        end
    end)
    GBWindow:Hide()

    local guildName = GetGuildInfo("player") or L["GUILD_BANK_TITLE"]

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    titleBar = OneWoW_GUI:CreateTitleBar(GBWindow, {
        title = guildName,
        height = C.TITLEBAR_HEIGHT,
        showBrand = true,
        factionTheme = factionTheme,
        onClose = function() GBWindow:Hide() end,
    })

    local settingsBtn = OneWoW_GUI:CreateButton(titleBar, { text = "S", width = 20, height = 20 })
    settingsBtn:SetPoint("RIGHT", titleBar._closeBtn, "LEFT", -2, 0)
    settingsBtn:SetScript("OnClick", function()
        if OneWoW_Bags.Settings and OneWoW_Bags.Settings.Toggle then
            OneWoW_Bags.Settings:Toggle()
        end
    end)

    contentArea = CreateFrame("Frame", nil, GBWindow)
    contentArea:SetPoint("TOPLEFT", GBWindow, "TOPLEFT", S("XS"), -(S("XS") + C.TITLEBAR_HEIGHT + S("XS")))
    contentArea:SetPoint("BOTTOMRIGHT", GBWindow, "BOTTOMRIGHT", -S("XS"), S("XS"))

    local infoBar = OneWoW_Bags.GuildBankInfoBar:Create(contentArea)
    local bagsBar = OneWoW_Bags.GuildBankBagsBar:Create(contentArea)

    local scrollName = "OneWoW_GuildBankContentScroll"
    contentScrollFrame = CreateFrame("ScrollFrame", scrollName, contentArea, "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", infoBar, "BOTTOMLEFT", 0, -2)
    local hideScroll = db and db.global and db.global.hideScrollBar
    local scrollRightOffset = hideScroll and 0 or -16
    contentScrollFrame:SetPoint("BOTTOMRIGHT", bagsBar, "TOPRIGHT", scrollRightOffset, 2)

    OneWoW_GUI:StyleScrollBar(contentScrollFrame, { container = contentArea, offset = 0 })
    if hideScroll and contentScrollFrame.ScrollBar then
        contentScrollFrame.ScrollBar:SetAlpha(0)
        contentScrollFrame.ScrollBar:EnableMouse(false)
    end

    contentFrame = CreateFrame("Frame", scrollName .. "Content", contentScrollFrame)
    contentFrame:SetHeight(1)
    contentScrollFrame:SetScrollChild(contentFrame)

    C_Timer.After(0, function()
        if contentScrollFrame then contentFrame:SetWidth(contentScrollFrame:GetWidth()) end
    end)

    local resizeBtn = CreateFrame("Button", nil, GBWindow)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", GBWindow, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetFrameLevel(GBWindow:GetFrameLevel() + 10)
    resizeBtn:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then GBWindow:StartSizing("BOTTOMRIGHT") end
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        GBWindow:StopMovingOrSizing()
        if db and db.global then
            db.global.guildBankWindowHeight = GBWindow:GetHeight()
            db.global.guildBankWindowWidth = GBWindow:GetWidth()
        end
        if contentScrollFrame and contentFrame then
            contentFrame:SetWidth(contentScrollFrame:GetWidth())
        end
        GBGUI:RefreshLayout()
    end)


    tinsert(UISpecialFrames, "OneWoW_GuildBankMainWindow")
    isInitialized = true

    if db and db.global and db.global.guildBankWindowPosition then
        local pos = db.global.guildBankWindowPosition
        GBWindow:ClearAllPoints()
        GBWindow:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
end

function GBGUI:CleanupAllViews()
    local GBSet = OneWoW_Bags.GuildBankSet
    if GBSet and GBSet.isBuilt then
        local allButtons = GBSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end
    if OneWoW_Bags.GuildBankCategoryManager then
        OneWoW_Bags.GuildBankCategoryManager:ReleaseAllSections()
    end
    GBGUI:ClearLogEntries()
end

function GBGUI:ClearLogEntries()
    for _, frame in ipairs(logEntryFrames) do
        frame:Hide()
        frame:ClearAllPoints()
    end
end

function GBGUI:AcquireLogEntry(index)
    if logEntryFrames[index] then
        logEntryFrames[index]:Show()
        return logEntryFrames[index]
    end
    local entry = CreateFrame("Frame", nil, contentFrame)
    entry:SetHeight(18)
    entry.text = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.text:SetPoint("LEFT", 4, 0)
    entry.text:SetPoint("RIGHT", -4, 0)
    entry.text:SetJustifyH("LEFT")
    entry.text:SetWordWrap(false)
    logEntryFrames[index] = entry
    return entry
end

function GBGUI:GetContentMode()
    return contentMode
end

function GBGUI:SetContentMode(mode)
    contentMode = mode or "items"
    if contentScrollFrame then
        contentScrollFrame:SetVerticalScroll(0)
    end
    if OneWoW_Bags.GuildBankBagsBar then
        OneWoW_Bags.GuildBankBagsBar:UpdateRow2Highlights()
    end

    if mode == "log" then
        local selectedTab = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.guildBankSelectedTab or 1
        QueryGuildBankLog(selectedTab)
        GBGUI:RefreshLayout()
        C_Timer.After(0.3, function() if contentMode == "log" then GBGUI:RefreshLayout() end end)
        C_Timer.After(0.8, function() if contentMode == "log" then GBGUI:RefreshLayout() end end)
    elseif mode == "moneylog" then
        QueryGuildBankLog(MAX_GUILDBANK_TABS + 1)
        GBGUI:RefreshLayout()
        C_Timer.After(0.3, function() if contentMode == "moneylog" then GBGUI:RefreshLayout() end end)
        C_Timer.After(0.8, function() if contentMode == "moneylog" then GBGUI:RefreshLayout() end end)
    elseif mode == "info" then
        local selectedTab = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.guildBankSelectedTab or 1
        QueryGuildBankText(selectedTab)
        GBGUI:RefreshLayout()
        C_Timer.After(0.3, function() if contentMode == "info" then GBGUI:RefreshLayout() end end)
        C_Timer.After(0.8, function() if contentMode == "info" then GBGUI:RefreshLayout() end end)
    else
        GBGUI:RefreshLayout()
    end
end

local function FormatTimeAgo(years, months, days, hours)
    if years and years > 0 then return string.format("%dy ago", years) end
    if months and months > 0 then return string.format("%dmo ago", months) end
    if days and days > 0 then return string.format("%dd ago", days) end
    if hours and hours > 0 then return string.format("%dh ago", hours) end
    return "just now"
end

function GBGUI:RenderLog()
    if not contentFrame then return 1 end
    local db = OneWoW_Bags.db
    local selectedTab = db and db.global and db.global.guildBankSelectedTab or 1

    local numTransactions = GetNumGuildBankTransactions(selectedTab) or 0
    if numTransactions == 0 then
        local entry = GBGUI:AcquireLogEntry(1)
        entry:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
        entry:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
        entry.text:SetText(L["GUILD_BANK_LOG_EMPTY"])
        entry.text:SetTextColor(T("TEXT_SECONDARY"))
        return 20
    end

    local yOffset = 0
    local entryIndex = 0

    for i = numTransactions, 1, -1 do
        local ttype, name, itemLink, count, tab1, tab2, years, months, days, hours = GetGuildBankTransaction(selectedTab, i)
        if ttype then
            entryIndex = entryIndex + 1
            local entry = GBGUI:AcquireLogEntry(entryIndex)
            entry:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
            entry:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)

            local actionText = ""
            if ttype == "deposit" then actionText = L["GUILD_BANK_LOG_DEPOSITED"]
            elseif ttype == "withdraw" then actionText = L["GUILD_BANK_LOG_WITHDREW"]
            elseif ttype == "move" then actionText = L["GUILD_BANK_LOG_MOVED"]
            else actionText = ttype or ""
            end

            local countText = (count and count > 1) and (" x" .. count) or ""
            local timeText = " |cFF808080(" .. FormatTimeAgo(years, months, days, hours) .. ")|r"

            local line = string.format("|cFFFFD100%s|r %s %s%s%s", name or "Unknown", actionText, itemLink or "", countText, timeText)
            entry.text:SetText(line)
            entry.text:SetTextColor(T("TEXT_PRIMARY"))

            yOffset = yOffset + 18
        end
    end

    return math.max(yOffset, 1)
end

function GBGUI:RenderMoneyLog()
    if not contentFrame then return 1 end

    local numTransactions = GetNumGuildBankMoneyTransactions() or 0
    if numTransactions == 0 then
        local entry = GBGUI:AcquireLogEntry(1)
        entry:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
        entry:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
        entry.text:SetText(L["GUILD_BANK_LOG_EMPTY"])
        entry.text:SetTextColor(T("TEXT_SECONDARY"))
        return 20
    end

    local yOffset = 0
    local entryIndex = 0

    for i = numTransactions, 1, -1 do
        local ttype, name, amount, years, months, days, hours = GetGuildBankMoneyTransaction(i)
        if ttype then
            entryIndex = entryIndex + 1
            local entry = GBGUI:AcquireLogEntry(entryIndex)
            entry:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
            entry:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)

            local actionText = ""
            if ttype == "deposit" then actionText = L["GUILD_BANK_LOG_DEPOSITED"]
            elseif ttype == "withdrawal" then actionText = L["GUILD_BANK_LOG_WITHDREW"]
            elseif ttype == "repair" then actionText = L["GUILD_BANK_LOG_REPAIRED"]
            else actionText = ttype or ""
            end

            local goldText = FormatGold(amount or 0)
            local timeText = " |cFF808080(" .. FormatTimeAgo(years, months, days, hours) .. ")|r"

            local line = string.format("|cFFFFD100%s|r %s %s%s", name or "Unknown", actionText, goldText, timeText)
            entry.text:SetText(line)
            entry.text:SetTextColor(T("TEXT_PRIMARY"))

            yOffset = yOffset + 18
        end
    end

    return math.max(yOffset, 1)
end

function GBGUI:RenderInfo()
    if not contentFrame then return 1 end
    local db = OneWoW_Bags.db
    local selectedTab = db and db.global and db.global.guildBankSelectedTab or 1

    local infoText = GetGuildBankText(selectedTab) or ""
    if infoText == "" then
        infoText = L["GUILD_BANK_INFO_EMPTY"]
    end

    local entry = GBGUI:AcquireLogEntry(1)
    entry:SetHeight(0)
    entry:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 4, -4)
    entry:SetPoint("RIGHT", contentFrame, "RIGHT", -4, 0)
    entry.text:ClearAllPoints()
    entry.text:SetPoint("TOPLEFT")
    entry.text:SetPoint("TOPRIGHT")
    entry.text:SetWordWrap(true)
    entry.text:SetText(infoText)
    entry.text:SetTextColor(T("TEXT_PRIMARY"))

    local textHeight = entry.text:GetStringHeight() or 20
    entry:SetHeight(textHeight + 8)

    return textHeight + 16
end

function GBGUI:RefreshLayout()
    if not isInitialized or not GBWindow then return end
    if not GBWindow:IsShown() then return end

    GBGUI:CleanupAllViews()

    if contentMode == "log" then
        local layoutHeight = GBGUI:RenderLog()
        contentFrame:SetHeight(layoutHeight)

        local freeSlots = 0
        local totalSlots = 0
        local GBSet = OneWoW_Bags.GuildBankSet
        if GBSet and GBSet.isBuilt then
            freeSlots = GBSet:GetFreeSlotCount()
            totalSlots = GBSet:GetSlotCount()
        end
        OneWoW_Bags.GuildBankBagsBar:UpdateFreeSlots(freeSlots, totalSlots)
        OneWoW_Bags.GuildBankBagsBar:UpdateGold()
        return
    end

    if contentMode == "moneylog" then
        local layoutHeight = GBGUI:RenderMoneyLog()
        contentFrame:SetHeight(layoutHeight)
        OneWoW_Bags.GuildBankBagsBar:UpdateGold()
        return
    end

    if contentMode == "info" then
        local layoutHeight = GBGUI:RenderInfo()
        contentFrame:SetHeight(layoutHeight)
        return
    end

    local GBSet = OneWoW_Bags.GuildBankSet
    if not GBSet or not GBSet.isBuilt then return end

    if contentFrame then
        for tabID, tabSlots in pairs(GBSet.slots) do
            for slotID, button in pairs(tabSlots) do
                button:SetParent(contentFrame)
            end
        end
    end

    local allButtons = GBSet:GetAllButtons()
    local searchText = OneWoW_Bags.GuildBankInfoBar:GetSearchText()
    local filteredButtons = {}

    if searchText and searchText ~= "" then
        local searchLower = string.lower(searchText)
        for _, button in ipairs(allButtons) do
            if button.owb_hasItem and button.owb_itemInfo and button.owb_itemInfo.itemID then
                local itemName = C_Item.GetItemNameByID(button.owb_itemInfo.itemID)
                if itemName and string.find(string.lower(itemName), searchLower, 1, true) then
                    table.insert(filteredButtons, button)
                end
            end
        end
    else
        for _, button in ipairs(allButtons) do
            table.insert(filteredButtons, button)
        end
    end

    local viewMode = OneWoW_Bags.db and OneWoW_Bags.db.global.guildBankViewMode or "tabs"
    local contentWidth = contentFrame:GetWidth()
    if contentWidth < 10 then contentWidth = Constants.GUI.WINDOW_WIDTH - 40 end

    local layoutHeight = 100
    if viewMode == "tabs" then
        layoutHeight = OneWoW_Bags.GuildBankTabView:Layout(contentFrame, contentWidth, filteredButtons)
    elseif viewMode == "list" then
        layoutHeight = OneWoW_Bags.GuildBankListView:Layout(contentFrame, filteredButtons, contentWidth)
    end

    contentFrame:SetHeight(layoutHeight)

    local freeSlots = GBSet:GetFreeSlotCount()
    local totalSlots = GBSet:GetSlotCount()
    OneWoW_Bags.GuildBankBagsBar:UpdateFreeSlots(freeSlots, totalSlots)
    OneWoW_Bags.GuildBankBagsBar:UpdateGold()
end

function GBGUI:OnSearchChanged(text)
    if contentMode ~= "items" then
        contentMode = "items"
        if OneWoW_Bags.GuildBankBagsBar then
            OneWoW_Bags.GuildBankBagsBar:UpdateRow2Highlights()
        end
    end
    self:RefreshLayout()
end

function GBGUI:Show()
    if not isInitialized then
        local ok, err = pcall(function() GBGUI:InitWindow() end)
        if not ok then
            print("|cFFFF0000[OneWoW_Bags] Guild Bank init error:|r " .. tostring(err))
            return
        end
    end
    if not GBWindow then return end

    contentMode = "items"

    GBWindow._ready = true
    GBWindow:Show()

    local GBSet = OneWoW_Bags.GuildBankSet
    if GBSet and not GBSet.isBuilt then
        GBSet:Build()
    end

    if OneWoW_Bags.GuildBankBagsBar then
        OneWoW_Bags.GuildBankBagsBar:BuildTabButtons()
        OneWoW_Bags.GuildBankBagsBar:UpdateTabHighlights()
        OneWoW_Bags.GuildBankBagsBar:UpdateRow2Highlights()
    end

    C_Timer.After(0, function()
        if not GBWindow or not GBWindow:IsShown() then return end
        if contentScrollFrame and contentFrame then
            local w = contentScrollFrame:GetWidth()
            if w and w > 10 then contentFrame:SetWidth(w) end
        end
        GBGUI:RefreshLayout()
    end)
end

function GBGUI:Hide()
    if GBWindow then GBWindow:Hide() end
end

function GBGUI:Toggle()
    if GBWindow and GBWindow:IsShown() then self:Hide() else self:Show() end
end

function GBGUI:IsShown() return GBWindow and GBWindow:IsShown() end

function GBGUI:FullReset()
    if OneWoW_Bags.GuildBankSet then OneWoW_Bags.GuildBankSet:ReleaseAll() end
    if OneWoW_Bags.GuildBankInfoBar and OneWoW_Bags.GuildBankInfoBar.Reset then OneWoW_Bags.GuildBankInfoBar:Reset() end
    if OneWoW_Bags.GuildBankBagsBar and OneWoW_Bags.GuildBankBagsBar.Reset then OneWoW_Bags.GuildBankBagsBar:Reset() end
    if GBWindow then GBWindow:Hide(); GBWindow = nil end
    titleBar = nil
    contentArea = nil
    contentScrollFrame = nil
    contentFrame = nil
    isInitialized = false
    contentMode = "items"
    logEntryFrames = {}
end

function GBGUI:GetMainWindow() return GBWindow end
