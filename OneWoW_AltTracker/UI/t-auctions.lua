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

function ns.UI.CreateAuctionsTab(parent)
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
    overviewTitle:SetText(L["AUCTIONS_OVERVIEW"])
    overviewTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local statsContainer = CreateFrame("Frame", nil, overviewPanel)
    statsContainer:SetPoint("TOPLEFT", overviewTitle, "BOTTOMLEFT", 0, -8)
    statsContainer:SetPoint("BOTTOMRIGHT", overviewPanel, "BOTTOMRIGHT", -10, 6)

    local statLabels = {
        L["AUCTIONS_ATTENTION"], L["AUCTIONS_TOTAL"], L["AUCTIONS_ACTIVE"], L["AUCTIONS_LIKELY_SOLD"], L["AUCTIONS_VALUE"],
        L["AUCTIONS_CHARACTERS"], L["AUCTIONS_EXPIRING"], L["AUCTIONS_EXPIRED"], L["MAIL_GOLD_WAITING"], L["HISTORY_GOLD_EARNED"]
    }

    local statTooltipTitles = {
        L["TT_AUCTIONS_ATTENTION"], L["TT_AUCTIONS_TOTAL"], L["TT_AUCTIONS_ACTIVE"], L["TT_AUCTIONS_LIKELY_SOLD"], L["TT_AUCTIONS_VALUE"],
        L["TT_AUCTIONS_CHARACTERS"], L["TT_AUCTIONS_EXPIRING"], L["TT_AUCTIONS_EXPIRED"], L["TT_MAIL_GOLD_WAITING"], L["TT_HISTORY_GOLD_EARNED"]
    }

    local statTooltips = {
        L["TT_AUCTIONS_ATTENTION_DESC"], L["TT_AUCTIONS_TOTAL_DESC"], L["TT_AUCTIONS_ACTIVE_DESC"], L["TT_AUCTIONS_LIKELY_SOLD_DESC"], L["TT_AUCTIONS_VALUE_DESC"],
        L["TT_AUCTIONS_CHARACTERS_DESC"], L["TT_AUCTIONS_EXPIRING_DESC"], L["TT_AUCTIONS_EXPIRED_DESC"], L["TT_MAIL_GOLD_WAITING_DESC"], L["TT_HISTORY_GOLD_EARNED_DESC"]
    }

    local statValues = {
        "0", "0", "0", "0", "0g",
        "0", "0", "0", "Closed", "0"
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

    parent.auctionFilter = "all"

    local mailIconButton = CreateFrame("Button", nil, filterPanel, "BackdropTemplate")
    mailIconButton:SetSize(32, 32)
    mailIconButton:SetPoint("LEFT", filterPanel, "LEFT", 8, 0)
    mailIconButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    mailIconButton:SetBackdropColor(T("BG_TERTIARY"))
    mailIconButton:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local mailIcon = mailIconButton:CreateTexture(nil, "ARTWORK")
    mailIcon:SetSize(24, 24)
    mailIcon:SetPoint("CENTER")
    mailIcon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")

    local function UpdateMailIcon()
        if not _G.OneWoW_AltTracker_Storage_DB then return end

        local totalGold = 0
        for charKey, storageData in pairs(_G.OneWoW_AltTracker_Storage_DB.characters) do
            if storageData.mail and storageData.mail.mails then
                for mailID, mailData in pairs(storageData.mail.mails) do
                    if mailData.sender and (mailData.sender == "Auction House" or mailData.sender == "The Auction House") and mailData.money and mailData.money > 0 then
                        totalGold = totalGold + mailData.money
                    end
                end
            end
        end

        if totalGold > 0 then
            mailIcon:SetVertexColor(1, 0.84, 0, 1)
        else
            mailIcon:SetVertexColor(0.5, 0.5, 0.5, 0.5)
        end
    end

    mailIconButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))

        if not _G.OneWoW_AltTracker_Storage_DB then return end

        local hasAnyMail = false
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["MAIL_PENDING_PICKUP"] or "Mail Pending Pickup", 1, 1, 1)

        for charKey, storageData in pairs(_G.OneWoW_AltTracker_Storage_DB.characters) do
            if storageData.mail and storageData.mail.mails then
                local auctionGold = 0
                local auctionItems = {}

                for mailID, mailData in pairs(storageData.mail.mails) do
                    if (mailData.sender == "Auction House" or mailData.sender == "The Auction House") and mailData.money and mailData.money > 0 then
                        auctionGold = auctionGold + mailData.money

                        local itemName = mailData.subject and mailData.subject:match("Auction successful: (.+)")
                        if itemName then
                            itemName = itemName:match("^(.-)%s*%(%d+%)$") or itemName
                            table.insert(auctionItems, {
                                name = itemName,
                                gold = mailData.money
                            })
                        end
                    end
                end

                if auctionGold > 0 then
                    hasAnyMail = true
                    local charName = charKey:match("^([^%-]+)")
                    local goldFormatted = ns.AltTrackerFormatters:FormatGold(auctionGold)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(charName .. " - " .. goldFormatted, 1, 0.84, 0)

                    for _, item in ipairs(auctionItems) do
                        local itemGold = ns.AltTrackerFormatters:FormatGold(item.gold)
                        GameTooltip:AddLine("  " .. item.name .. " - " .. itemGold, 0.7, 0.7, 0.7)
                    end
                end
            end
        end

        if not hasAnyMail then
            GameTooltip:AddLine(L["NO_AUCTION_MAIL"] or "No auction gold waiting", 0.5, 0.5, 0.5)
        end

        GameTooltip:Show()
    end)

    mailIconButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
        GameTooltip:Hide()
    end)

    parent.mailIconButton = mailIconButton
    parent.UpdateMailIcon = UpdateMailIcon

    local filterButtons = {}
    local filterOptions = {
        {key = "all", label = L["AUCTIONS_FILTER_ALL"] or "All", tooltip = L["AUCTIONS_FILTER_ALL_DESC"] or "Show all auctions and bids"},
        {key = "auctions", label = L["AUCTIONS_FILTER_AUCTIONS"] or "My Auctions", tooltip = L["AUCTIONS_FILTER_AUCTIONS_DESC"] or "Show only items you are selling"},
        {key = "bids", label = L["AUCTIONS_FILTER_BIDS"] or "My Bids", tooltip = L["AUCTIONS_FILTER_BIDS_DESC"] or "Show only items you are bidding on"},
        {key = "expiring", label = L["AUCTIONS_FILTER_EXPIRING"] or "Expiring Soon", tooltip = L["AUCTIONS_FILTER_EXPIRING_DESC"] or "Show auctions expiring within 2 hours"},
        {key = "history", label = L["AUCTIONS_FILTER_HISTORY"] or "History", tooltip = L["AUCTIONS_FILTER_HISTORY_DESC"] or "Show auction history (sold, expired, canceled)"},
    }

    for i, option in ipairs(filterOptions) do
        local btn = CreateFrame("Button", nil, filterPanel, "BackdropTemplate")
        btn:SetSize(120, 24)
        btn:SetPoint("LEFT", filterPanel, "LEFT", 48 + (i - 1) * 124, 0)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnText:SetPoint("CENTER")
        btnText:SetText(option.label)

        btn.filterKey = option.key
        btn.text = btnText

        btn:SetScript("OnClick", function(self)
            parent.auctionFilter = self.filterKey
            for _, b in ipairs(filterButtons) do
                if b.filterKey == parent.auctionFilter then
                    b:SetBackdropColor(T("ACCENT_PRIMARY"))
                    b.text:SetTextColor(T("BG_PRIMARY"))
                else
                    b:SetBackdropColor(T("BG_TERTIARY"))
                    b.text:SetTextColor(T("TEXT_PRIMARY"))
                end
            end
            if ns.UI.RefreshAuctionsTab then
                ns.UI.RefreshAuctionsTab(parent)
            end
        end)

        btn:SetScript("OnEnter", function(self)
            if self.filterKey ~= parent.auctionFilter then
                self:SetBackdropColor(T("BG_HOVER"))
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(option.label, 1, 1, 1)
            GameTooltip:AddLine(option.tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function(self)
            if self.filterKey ~= parent.auctionFilter then
                if self.filterKey == parent.auctionFilter then
                    self:SetBackdropColor(T("ACCENT_PRIMARY"))
                else
                    self:SetBackdropColor(T("BG_TERTIARY"))
                end
            end
            GameTooltip:Hide()
        end)

        if option.key == "all" then
            btn:SetBackdropColor(T("ACCENT_PRIMARY"))
            btnText:SetTextColor(T("BG_PRIMARY"))
        else
            btn:SetBackdropColor(T("BG_TERTIARY"))
            btnText:SetTextColor(T("TEXT_PRIMARY"))
        end

        btn:SetBackdropBorderColor(T("BORDER_DEFAULT"))
        table.insert(filterButtons, btn)
    end

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
        {key = "item", label = L["AUCTIONS_COL_ITEM"], width = 150, fixed = false, ttTitle = L["TT_COL_ITEM"], ttDesc = L["TT_COL_ITEM_DESC"]},
        {key = "qty", label = L["AUCTIONS_COL_QTY"], width = 40, fixed = true, ttTitle = L["TT_COL_QTY"], ttDesc = L["TT_COL_QTY_DESC"]},
        {key = "each", label = L["AUCTIONS_COL_EACH"], width = 60, fixed = false, ttTitle = L["TT_COL_EACH"], ttDesc = L["TT_COL_EACH_DESC"]},
        {key = "total", label = L["AUCTIONS_COL_TOTAL"], width = 70, fixed = false, ttTitle = L["TT_COL_TOTAL"], ttDesc = L["TT_COL_TOTAL_DESC"]},
        {key = "bid", label = L["AUCTIONS_COL_BID"], width = 60, fixed = false, ttTitle = L["TT_COL_BID"], ttDesc = L["TT_COL_BID_DESC"]},
        {key = "time", label = L["AUCTIONS_COL_TIME"], width = 50, fixed = true, ttTitle = L["TT_COL_TIME"], ttDesc = L["TT_COL_TIME_DESC"]},
        {key = "character", label = L["COL_CHARACTER"], width = 100, fixed = false, ttTitle = L["TT_COL_CHARACTER_AUCTION"], ttDesc = L["TT_COL_CHARACTER_AUCTION_DESC"]},
        {key = "faction", label = L["COL_FACTION"], width = 25, fixed = true, ttTitle = L["TT_COL_FACTION"], ttDesc = L["TT_COL_FACTION_DESC"]},
        {key = "status", label = L["AUCTIONS_COL_STATUS"], width = 60, fixed = false, ttTitle = L["TT_COL_AUCTION_STATUS"], ttDesc = L["TT_COL_AUCTION_STATUS_DESC"]},
        {key = "delete", label = L["AUCTIONS_COL_DELETE"], width = 50, fixed = true, ttTitle = L["TT_COL_DELETE"], ttDesc = L["TT_COL_DELETE_DESC"]}
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
            if col.key == "expand" or col.key == "faction" or col.key == "mail" or col.key == "delete" then
                return
            end

            if currentSortColumn == col.key then
                currentSortAscending = not currentSortAscending
            else
                currentSortColumn = col.key
                currentSortAscending = true
            end

            if parent then
                ns.UI.RefreshAuctionsTab(parent)
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

    function UpdateRowLayout()
        if ns.UI.RefreshAuctionsTab and parent then
            C_Timer.After(0.05, function()
                if parent.headerRow then
                    parent.headerRow:GetScript("OnSizeChanged")(parent.headerRow)
                end
            end)
        end
    end

    headerRow:HookScript("OnSizeChanged", function()
        C_Timer.After(0.1, function()
            UpdateRowLayout()
        end)
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
        C_Timer.After(0.1, function()
            UpdateRowLayout()
        end)
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
        if ns.UI.RefreshAuctionsTab then
            ns.UI.RefreshAuctionsTab(parent)
        end
    end)
end

local auctionRows = {}

function ns.UI.RefreshAuctionsTab(auctionsTab)
    if not auctionsTab then return end
    if not _G.OneWoW_AltTracker_Auctions_DB or not _G.OneWoW_AltTracker_Auctions_DB.characters then return end

    local scrollContent = auctionsTab.scrollContent
    if not scrollContent then return end

    for _, row in ipairs(auctionRows) do
        if row.expandedFrame then
            row.expandedFrame:Hide()
            row.expandedFrame = nil
        end
        row:Hide()
        row:SetParent(nil)
    end
    wipe(auctionRows)

    local currentFilter = auctionsTab.auctionFilter or "all"
    local allAuctions = {}

    for charKey, auctionData in pairs(_G.OneWoW_AltTracker_Auctions_DB.characters) do
        local charInfo = _G.OneWoW_AltTracker_Character_DB and
                         _G.OneWoW_AltTracker_Character_DB.characters and
                         _G.OneWoW_AltTracker_Character_DB.characters[charKey]

        local charDisplayData = {
            name = (charInfo and charInfo.name) or charKey:match("^([^%-]+)"),
            class = (charInfo and charInfo.class) or "WARRIOR",
            faction = (charInfo and charInfo.faction) or "Alliance"
        }

        if currentFilter == "history" then
            if auctionData.auctionHistory then
                for _, historyEvent in ipairs(auctionData.auctionHistory) do
                    table.insert(allAuctions, {
                        charKey = charKey,
                        charData = charDisplayData,
                        history = historyEvent,
                        type = "history"
                    })
                end
            end
        elseif currentFilter == "expiring" then
            if auctionData.activeAuctions then
                local serverTime = GetServerTime()
                local twoHours = 7200
                for _, auction in ipairs(auctionData.activeAuctions) do
                    if auction.endsAt then
                        local timeLeft = auction.endsAt - serverTime
                        if timeLeft > 0 and timeLeft < twoHours then
                            table.insert(allAuctions, {
                                charKey = charKey,
                                charData = charDisplayData,
                                auction = auction,
                                type = "auction",
                                sortValue = timeLeft
                            })
                        end
                    end
                end
            end
        else
            if auctionData.activeAuctions and (currentFilter == "all" or currentFilter == "auctions") then
                for _, auction in ipairs(auctionData.activeAuctions) do
                    table.insert(allAuctions, {
                        charKey = charKey,
                        charData = charDisplayData,
                        auction = auction,
                        type = "auction"
                    })
                end
            end

            if auctionData.activeBids and (currentFilter == "all" or currentFilter == "bids") then
                for _, bid in ipairs(auctionData.activeBids) do
                    table.insert(allAuctions, {
                        charKey = charKey,
                        charData = charDisplayData,
                        bid = bid,
                        type = "bid"
                    })
                end
            end
        end
    end

    if #allAuctions == 0 then
        if auctionsTab.statusText then
            auctionsTab.statusText:SetText(L["NO_AUCTIONS_FOUND"] or "No auctions found")
        end
        return
    end

    local yOffset = -5
    local rowHeight = 32
    local rowGap = 2

    local function RepositionAllRows()
        local yOffset = -5

        for _, row in ipairs(auctionRows) do
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

    for _, entry in ipairs(allAuctions) do
        local charKey = entry.charKey
        local charData = entry.charData
        local auction = entry.auction
        local bid = entry.bid
        local history = entry.history
        local itemData = auction or bid or history
        local isHistory = (entry.type == "history")

        local auctionRow = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        auctionRow:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
        auctionRow:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        auctionRow:SetHeight(rowHeight)
        auctionRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

        if not isHistory and auction and auction.endsAt then
            local timeLeft = auction.endsAt - GetServerTime()
            if timeLeft > 0 and timeLeft < 1800 then
                auctionRow:SetBackdropColor(0.3, 0.1, 0.1, 1)
                auctionRow.normalBgColor = {0.3, 0.1, 0.1, 1}
            elseif timeLeft > 0 and timeLeft < 3600 then
                auctionRow:SetBackdropColor(0.3, 0.2, 0.1, 1)
                auctionRow.normalBgColor = {0.3, 0.2, 0.1, 1}
            else
                auctionRow:SetBackdropColor(T("BG_TERTIARY"))
                auctionRow.normalBgColor = {T("BG_TERTIARY")}
            end
        else
            auctionRow:SetBackdropColor(T("BG_TERTIARY"))
            auctionRow.normalBgColor = {T("BG_TERTIARY")}
        end

        auctionRow.charKey = charKey
        auctionRow.cells = {}

        local expandBtn = CreateFrame("Button", nil, auctionRow)
        expandBtn:SetSize(25, rowHeight)
        local expandIcon = expandBtn:CreateTexture(nil, "ARTWORK")
        expandIcon:SetSize(14, 14)
        expandIcon:SetPoint("CENTER")
        expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
        expandBtn.icon = expandIcon
        table.insert(auctionRow.cells, expandBtn)

        local function ToggleExpanded()
            local isExpanded = auctionRow.isExpanded or false
            auctionRow.isExpanded = not isExpanded

            if auctionRow.isExpanded then
                expandIcon:SetAtlas("Gamepad_Rev_Minus_64")
                if not auctionRow.expandedFrame then
                    auctionRow.expandedFrame = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
                    auctionRow.expandedFrame:SetPoint("TOPLEFT", auctionRow, "BOTTOMLEFT", 0, -2)
                    auctionRow.expandedFrame:SetPoint("TOPRIGHT", auctionRow, "BOTTOMRIGHT", 0, -2)
                    auctionRow.expandedFrame:SetHeight(50)
                    auctionRow.expandedFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                    auctionRow.expandedFrame:SetBackdropColor(T("BG_SECONDARY"))

                    local text = auctionRow.expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    text:SetPoint("CENTER")
                    text:SetText(L["EXPANDED_DETAILS_SOON"])
                    text:SetTextColor(T("TEXT_SECONDARY"))
                end
                auctionRow.expandedFrame:Show()
            else
                expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
                if auctionRow.expandedFrame then
                    auctionRow.expandedFrame:Hide()
                end
            end

            RepositionAllRows()
        end

        expandBtn:SetScript("OnClick", ToggleExpanded)

        local itemContainer = CreateFrame("Frame", nil, auctionRow)
        itemContainer:SetHeight(rowHeight - 4)

        local itemIcon = itemContainer:CreateTexture(nil, "ARTWORK")
        itemIcon:SetSize(rowHeight - 6, rowHeight - 6)
        itemIcon:SetPoint("LEFT", itemContainer, "LEFT", 2, 0)
        if itemData.itemIcon then
            itemIcon:SetTexture(itemData.itemIcon)
        else
            itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        local qualityBorder = itemContainer:CreateTexture(nil, "BORDER")
        qualityBorder:SetSize(rowHeight - 4, rowHeight - 4)
        qualityBorder:SetPoint("CENTER", itemIcon, "CENTER", 0, 0)
        qualityBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
        if itemData.itemRarity and ITEM_QUALITY_COLORS[itemData.itemRarity] then
            local color = ITEM_QUALITY_COLORS[itemData.itemRarity]
            qualityBorder:SetVertexColor(color.r, color.g, color.b, 0.8)
        else
            qualityBorder:SetVertexColor(0.5, 0.5, 0.5, 0.8)
        end
        qualityBorder:SetDrawLayer("BORDER", 1)

        local itemLevelText = itemContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemLevelText:SetPoint("BOTTOMRIGHT", itemIcon, "BOTTOMRIGHT", 0, 1)
        itemLevelText:SetDrawLayer("OVERLAY", 2)
        if itemData.itemLevel and itemData.itemLevel > 0 then
            itemLevelText:SetText(tostring(itemData.itemLevel))
            itemLevelText:SetTextColor(1, 1, 1)
            itemLevelText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        end

        local itemLinkFrame = CreateFrame("Button", nil, itemContainer)
        itemLinkFrame:SetPoint("LEFT", itemIcon, "RIGHT", 4, 0)
        itemLinkFrame:SetPoint("RIGHT", itemContainer, "RIGHT", -4, 0)
        itemLinkFrame:SetHeight(rowHeight - 4)

        local itemNameText = itemLinkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        itemNameText:SetPoint("LEFT", itemLinkFrame, "LEFT", 0, 0)
        itemNameText:SetPoint("RIGHT", itemLinkFrame, "RIGHT", 0, 0)
        itemNameText:SetJustifyH("LEFT")
        itemNameText:SetWordWrap(false)
        itemNameText:SetText(itemData.itemName or L["AUCTION_UNKNOWN_ITEM"])
        if itemData.itemRarity and ITEM_QUALITY_COLORS[itemData.itemRarity] then
            local color = ITEM_QUALITY_COLORS[itemData.itemRarity]
            itemNameText:SetTextColor(color.r, color.g, color.b)
        else
            itemNameText:SetTextColor(T("TEXT_PRIMARY"))
        end

        if itemData.itemLink then
            itemLinkFrame:EnableMouse(true)
            itemLinkFrame:SetScript("OnEnter", function(self)
                itemNameText:SetTextColor(1, 1, 0)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(itemData.itemLink)
                GameTooltip:Show()
            end)
            itemLinkFrame:SetScript("OnLeave", function(self)
                if itemData.itemRarity and ITEM_QUALITY_COLORS[itemData.itemRarity] then
                    local color = ITEM_QUALITY_COLORS[itemData.itemRarity]
                    itemNameText:SetTextColor(color.r, color.g, color.b)
                else
                    itemNameText:SetTextColor(T("TEXT_PRIMARY"))
                end
                GameTooltip:Hide()
            end)
            itemLinkFrame:SetScript("OnClick", function(self, button)
                if IsModifiedClick("CHATLINK") then
                    ChatEdit_InsertLink(itemData.itemLink)
                end
            end)
        end

        table.insert(auctionRow.cells, itemContainer)

        local qtyText = auctionRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local quantity = itemData.quantity or 1
        qtyText:SetText(tostring(quantity))
        qtyText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(auctionRow.cells, qtyText)

        local eachText = auctionRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if isHistory then
            local each = history.quantity > 0 and math.floor(history.listPrice / history.quantity) or 0
            eachText:SetText(ns.AltTrackerFormatters:FormatGold(each))
        elseif auction then
            local each = auction.quantity > 0 and math.floor(auction.buyoutAmount / auction.quantity) or 0
            eachText:SetText(ns.AltTrackerFormatters:FormatGold(each))
        else
            local each = bid.quantity > 0 and math.floor(bid.bidAmount / bid.quantity) or 0
            eachText:SetText(ns.AltTrackerFormatters:FormatGold(each))
        end
        eachText:SetTextColor(T("TEXT_PRIMARY"))
        eachText:SetJustifyH("LEFT")
        table.insert(auctionRow.cells, eachText)

        local totalText = auctionRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if isHistory then
            totalText:SetText(ns.AltTrackerFormatters:FormatGold(history.listPrice or 0))
        else
            local totalAmount = auction and auction.buyoutAmount or (bid and bid.bidAmount or 0)
            totalText:SetText(ns.AltTrackerFormatters:FormatGold(totalAmount))
        end
        totalText:SetTextColor(T("TEXT_PRIMARY"))
        totalText:SetJustifyH("LEFT")
        table.insert(auctionRow.cells, totalText)

        local bidText = auctionRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if isHistory then
            if history.salePrice and history.salePrice > 0 then
                bidText:SetText(ns.AltTrackerFormatters:FormatGold(history.salePrice))
                bidText:SetTextColor(0, 1, 0)
            else
                bidText:SetText("-")
                bidText:SetTextColor(T("TEXT_SECONDARY"))
            end
        elseif auction then
            if auction.bidAmount > 0 then
                bidText:SetText(ns.AltTrackerFormatters:FormatGold(auction.bidAmount))
                bidText:SetTextColor(1, 1, 0)
            else
                bidText:SetText("-")
                bidText:SetTextColor(T("TEXT_SECONDARY"))
            end
        else
            bidText:SetText(ns.AltTrackerFormatters:FormatGold(bid.bidAmount))
            bidText:SetTextColor(1, 1, 0)
        end
        bidText:SetJustifyH("LEFT")
        table.insert(auctionRow.cells, bidText)

        local timeContainer = CreateFrame("Frame", nil, auctionRow)
        timeContainer:SetHeight(rowHeight)

        local timeText = timeContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        timeText:SetPoint("CENTER")

        if isHistory then
            local timeSince = GetServerTime() - (history.timestamp or GetServerTime())
            if timeSince < 3600 then
                timeText:SetText(math.floor(timeSince / 60) .. "m ago")
            elseif timeSince < 86400 then
                timeText:SetText(math.floor(timeSince / 3600) .. "h ago")
            else
                timeText:SetText(math.floor(timeSince / 86400) .. "d ago")
            end
            timeText:SetTextColor(T("TEXT_SECONDARY"))
        elseif auction then
            local timeLeft = auction.endsAt - GetServerTime()
            if timeLeft > 0 then
                if timeLeft < 1800 then
                    local mins = math.floor(timeLeft / 60)
                    timeText:SetText(mins .. "m")
                    timeText:SetTextColor(1, 0, 0)

                    local warningIcon = timeContainer:CreateTexture(nil, "OVERLAY")
                    warningIcon:SetSize(12, 12)
                    warningIcon:SetPoint("LEFT", timeText, "RIGHT", 2, 0)
                    warningIcon:SetAtlas("Raid-Icon-Evoker")
                    warningIcon:SetVertexColor(1, 0, 0)
                elseif timeLeft < 3600 then
                    local mins = math.floor(timeLeft / 60)
                    timeText:SetText(mins .. "m")
                    timeText:SetTextColor(1, 0, 0)
                elseif timeLeft < 7200 then
                    local hours = math.floor(timeLeft / 3600)
                    timeText:SetText(hours .. "h")
                    timeText:SetTextColor(1, 0.5, 0)
                else
                    local hours = math.floor(timeLeft / 3600)
                    timeText:SetText(hours .. "h")
                    timeText:SetTextColor(0, 1, 0)
                end
            else
                timeText:SetText(L["AUCTION_TIME_ENDED"])
                timeText:SetTextColor(0.5, 0.5, 0.5)
            end

            timeContainer:EnableMouse(true)
            timeContainer:SetScript("OnEnter", function(self)
                if auction.endsAt then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Expires At", 1, 1, 1)
                    GameTooltip:AddLine(date("%Y-%m-%d %H:%M:%S", auction.endsAt), 1, 1, 1)
                    local timeLeft = auction.endsAt - GetServerTime()
                    if timeLeft > 0 then
                        GameTooltip:AddLine("Time Remaining: " .. math.floor(timeLeft/3600) .. "h " .. math.floor((timeLeft%3600)/60) .. "m", 0.7, 0.7, 0.7)
                    end
                    GameTooltip:Show()
                end
            end)
            timeContainer:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
        else
            timeText:SetText("-")
            timeText:SetTextColor(T("TEXT_SECONDARY"))
        end
        table.insert(auctionRow.cells, timeContainer)

        local charNameText = auctionRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        charNameText:SetText(charData.name or charKey)
        local classColor = RAID_CLASS_COLORS[charData.class]
        if classColor then
            charNameText:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            charNameText:SetTextColor(1, 1, 1)
        end
        charNameText:SetJustifyH("LEFT")
        table.insert(auctionRow.cells, charNameText)

        local factionIcon = auctionRow:CreateTexture(nil, "ARTWORK")
        factionIcon:SetSize(18, 18)
        if charData.faction == "Alliance" then
            factionIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
        elseif charData.faction == "Horde" then
            factionIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-Horde")
        else
            factionIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
            factionIcon:SetDesaturated(true)
        end
        table.insert(auctionRow.cells, factionIcon)

        local statusText = auctionRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if isHistory then
            if history.outcome == "sold" then
                statusText:SetText(L["OUTCOME_SOLD"])
                statusText:SetTextColor(0, 1, 0)
            elseif history.outcome == "expired" then
                statusText:SetText(L["OUTCOME_EXPIRED"])
                statusText:SetTextColor(1, 0.5, 0)
            elseif history.outcome == "canceled" then
                statusText:SetText(L["OUTCOME_CANCELED"])
                statusText:SetTextColor(0.7, 0.7, 0.7)
            end
        elseif auction then
            statusText:SetText(L["STATUS_ACTIVE"])
            statusText:SetTextColor(0, 1, 0)
        else
            statusText:SetText(L["STATUS_BIDDING"])
            statusText:SetTextColor(1, 1, 0)
        end
        statusText:SetJustifyH("LEFT")
        table.insert(auctionRow.cells, statusText)

        local deleteBtn = CreateFrame("Button", nil, auctionRow, "BackdropTemplate")
        deleteBtn:SetSize(40, 22)
        deleteBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        deleteBtn:SetBackdropColor(T("BG_TERTIARY"))
        deleteBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))
        local deleteText = deleteBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        deleteText:SetPoint("CENTER")
        deleteText:SetText(L["PLACEHOLDER_DELETE"])
        deleteText:SetTextColor(T("TEXT_PRIMARY"))
        deleteBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
            deleteText:SetTextColor(T("TEXT_ACCENT"))
        end)
        deleteBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
            deleteText:SetTextColor(T("TEXT_PRIMARY"))
        end)
        table.insert(auctionRow.cells, deleteBtn)

        auctionRow:EnableMouse(true)
        auctionRow:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)

        auctionRow:SetScript("OnLeave", function(self)
            if self.normalBgColor then
                self:SetBackdropColor(unpack(self.normalBgColor))
            else
                self:SetBackdropColor(T("BG_TERTIARY"))
            end
        end)

        auctionRow:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                ToggleExpanded()
            end
        end)

        local headerRow = auctionsTab.headerRow
        if headerRow and headerRow.columnButtons then
            for i, cell in ipairs(auctionRow.cells) do
                local btn = headerRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX

                    cell:ClearAllPoints()

                    if i == 1 then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", auctionRow, "LEFT", x, 0)
                    elseif i == 9 or i == 10 then
                        cell:SetPoint("CENTER", auctionRow, "LEFT", x + width/2, 0)
                    elseif i == 12 then
                        cell:SetSize(width - 6, 22)
                        cell:SetPoint("CENTER", auctionRow, "LEFT", x + width/2, 0)
                    else
                        cell:SetWidth(width - 6)
                        if i == 2 or i == 4 or i == 5 or i == 6 or i == 8 or i == 11 then
                            cell:SetPoint("LEFT", auctionRow, "LEFT", x + 3, 0)
                        else
                            cell:SetPoint("CENTER", auctionRow, "LEFT", x + width/2, 0)
                        end
                    end
                end
            end
        end

        auctionRow:Show()
        table.insert(auctionRows, auctionRow)
        yOffset = yOffset - (rowHeight + rowGap)
    end

    local newHeight = math.max(400, #auctionRows * (rowHeight + rowGap) + 10)
    scrollContent:SetHeight(newHeight)

    if auctionsTab.statusText then
        local totalItems = #allAuctions
        auctionsTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], totalItems, ""))
    end

    ns.UI.RefreshAuctionsStats(auctionsTab)

    if auctionsTab.UpdateMailIcon then
        auctionsTab.UpdateMailIcon()
    end

    C_Timer.After(0.1, function()
        if auctionsTab.headerRow then
            auctionsTab.headerRow:GetScript("OnSizeChanged")(auctionsTab.headerRow)
        end
    end)
end

function ns.UI.RefreshAuctionsStats(auctionsTab)
    if not auctionsTab or not auctionsTab.statBoxes then return end
    if not _G.OneWoW_AltTracker_Auctions_DB then return end

    local stats = {
        attention = 0,
        total = 0,
        active = 0,
        likelySold = 0,
        value = 0,
        characters = 0,
        expiring = 0,
        expired = 0,
        ahStatus = L["AUCTION_AH_CLOSED"],
        bids = 0,
        goldEarned = 0,
        successRate = 0,
        goldWaiting = 0,
    }

    local charactersWithAuctions = {}
    local totalSold = 0
    local totalPosted = 0

    for charKey, auctionData in pairs(_G.OneWoW_AltTracker_Auctions_DB.characters) do
        local hasAuctions = false

        if auctionData.activeAuctions and #auctionData.activeAuctions > 0 then
            hasAuctions = true
            stats.active = stats.active + #auctionData.activeAuctions
            stats.value = stats.value + (auctionData.totalAuctionValue or 0)

            local serverTime = GetServerTime()
            local twoHours = 7200
            for _, auction in ipairs(auctionData.activeAuctions) do
                if auction.endsAt then
                    local timeLeft = auction.endsAt - serverTime
                    if timeLeft > 0 and timeLeft < twoHours then
                        stats.expiring = stats.expiring + 1
                    end
                end
            end
        end

        if auctionData.activeBids and #auctionData.activeBids > 0 then
            hasAuctions = true
            stats.bids = stats.bids + #auctionData.activeBids
        end

        local storageData = _G.OneWoW_AltTracker_Storage_DB and _G.OneWoW_AltTracker_Storage_DB.characters and _G.OneWoW_AltTracker_Storage_DB.characters[charKey]
        if storageData and storageData.mail and storageData.mail.mails then
            for mailID, mailData in pairs(storageData.mail.mails) do
                if mailData.sender and (mailData.sender == "Auction House" or mailData.sender == "The Auction House") and mailData.money and mailData.money > 0 then
                    stats.goldWaiting = stats.goldWaiting + mailData.money
                    hasAuctions = true
                end
            end
        end

        if auctionData.auctionHistory then
            for _, event in ipairs(auctionData.auctionHistory) do
                if event.outcome == "sold" then
                    totalSold = totalSold + 1
                    stats.goldEarned = stats.goldEarned + (event.salePrice or 0)
                    stats.likelySold = stats.likelySold + 1
                elseif event.outcome == "expired" then
                    stats.expired = stats.expired + 1
                end
                totalPosted = totalPosted + 1
            end
        end

        if hasAuctions then
            charactersWithAuctions[charKey] = true
        end
    end

    stats.total = stats.active + stats.bids
    stats.characters = 0
    for _ in pairs(charactersWithAuctions) do
        stats.characters = stats.characters + 1
    end

    if totalPosted > 0 then
        stats.successRate = math.floor((totalSold / totalPosted) * 100)
    end

    stats.attention = stats.expiring + stats.expired

    if C_AuctionHouse and C_AuctionHouse.IsAuctionHouseOpen and C_AuctionHouse.IsAuctionHouseOpen() then
        stats.ahStatus = L["AUCTION_AH_OPEN"]
    end

    local statBoxes = auctionsTab.statBoxes
    if statBoxes then
        if statBoxes[1] then statBoxes[1].value:SetText(tostring(stats.attention)) end
        if statBoxes[2] then statBoxes[2].value:SetText(tostring(stats.total)) end
        if statBoxes[3] then statBoxes[3].value:SetText(tostring(stats.active)) end
        if statBoxes[4] then
            local displayText = tostring(stats.likelySold)
            if stats.successRate > 0 then
                displayText = displayText .. " (" .. stats.successRate .. "%)"
            end
            statBoxes[4].value:SetText(displayText)
        end
        if statBoxes[5] then
            local goldFormatted = ns.AltTrackerFormatters:FormatGold(stats.value)
            statBoxes[5].value:SetText(goldFormatted)
        end
        if statBoxes[6] then statBoxes[6].value:SetText(tostring(stats.characters)) end
        if statBoxes[7] then statBoxes[7].value:SetText(tostring(stats.expiring)) end
        if statBoxes[8] then statBoxes[8].value:SetText(tostring(stats.expired)) end
        if statBoxes[9] then
            local goldWaitingFormatted = ns.AltTrackerFormatters:FormatGold(stats.goldWaiting)
            statBoxes[9].value:SetText(goldWaitingFormatted)
            if stats.goldWaiting > 0 then
                statBoxes[9].value:SetTextColor(1, 0.84, 0)
            else
                statBoxes[9].value:SetTextColor(T("TEXT_PRIMARY"))
            end
        end
        if statBoxes[10] then
            local goldEarnedFormatted = ns.AltTrackerFormatters:FormatGold(stats.goldEarned)
            statBoxes[10].value:SetText(goldEarnedFormatted)
        end
    end
end
