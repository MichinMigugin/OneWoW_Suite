local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.UI = ns.UI or {}

local currentSortColumn = nil
local currentSortAscending = true
local characterRows = {}
local selectedAltKey = nil

local columnsConfig = {
    {key = "expand", label = "", width = 25, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_EXPAND"], ttDesc = L["TT_COL_EXPAND_DESC"]},
    {key = "item", label = L["AUCTIONS_COL_ITEM"], width = 150, fixed = false, align = "left", ttTitle = L["TT_COL_ITEM"], ttDesc = L["TT_COL_ITEM_DESC"]},
    {key = "qty", label = L["AUCTIONS_COL_QTY"], width = 40, fixed = true, align = "center", ttTitle = L["TT_COL_QTY"], ttDesc = L["TT_COL_QTY_DESC"]},
    {key = "each", label = L["AUCTIONS_COL_EACH"], width = 60, fixed = false, align = "left", ttTitle = L["TT_COL_EACH"], ttDesc = L["TT_COL_EACH_DESC"]},
    {key = "total", label = L["AUCTIONS_COL_TOTAL"], width = 70, fixed = false, align = "left", ttTitle = L["TT_COL_TOTAL"], ttDesc = L["TT_COL_TOTAL_DESC"]},
    {key = "bid", label = L["AUCTIONS_COL_BID"], width = 60, fixed = false, align = "left", ttTitle = L["TT_COL_BID"], ttDesc = L["TT_COL_BID_DESC"]},
    {key = "time", label = L["AUCTIONS_COL_TIME"], width = 50, fixed = true, align = "center", ttTitle = L["TT_COL_TIME"], ttDesc = L["TT_COL_TIME_DESC"]},
    {key = "character", label = L["COL_CHARACTER"], width = 100, fixed = false, align = "left", ttTitle = L["TT_COL_CHARACTER_AUCTION"], ttDesc = L["TT_COL_CHARACTER_AUCTION_DESC"]},
    {key = "faction", label = L["COL_FACTION"], width = 25, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_FACTION"], ttDesc = L["TT_COL_FACTION_DESC"]},
    {key = "status", label = L["AUCTIONS_COL_STATUS"], width = 60, fixed = false, align = "left", ttTitle = L["TT_COL_AUCTION_STATUS"], ttDesc = L["TT_COL_AUCTION_STATUS_DESC"]},
    {key = "delete", label = L["AUCTIONS_COL_DELETE"], width = 50, fixed = true, align = "center", sortable = false, ttTitle = L["TT_COL_DELETE"], ttDesc = L["TT_COL_DELETE_DESC"]}
}

local onHeaderCreate = function(btn, col, index)
    if col.key == "expand" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("CENTER")
        icon:SetAtlas("Gamepad_Rev_Plus_64")
        btn.icon = icon
        if btn.text then btn.text:SetText("") end
    elseif col.key == "faction" then
        if btn.text then btn.text:SetText("") end
    end
end

function ns.UI.CreateAuctionsTab(parent)
    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

    local overview = OneWoW_GUI:CreateOverviewPanel(parent, {
        title = L["AUCTIONS_OVERVIEW"],
        height = 110,
        columns = 5,
        stats = {
            { label = L["AUCTIONS_ATTENTION"], value = "0", ttTitle = L["TT_AUCTIONS_ATTENTION"], ttDesc = L["TT_AUCTIONS_ATTENTION_DESC"] },
            { label = L["AUCTIONS_TOTAL"], value = "0", ttTitle = L["TT_AUCTIONS_TOTAL"], ttDesc = L["TT_AUCTIONS_TOTAL_DESC"] },
            { label = L["AUCTIONS_ACTIVE"], value = "0", ttTitle = L["TT_AUCTIONS_ACTIVE"], ttDesc = L["TT_AUCTIONS_ACTIVE_DESC"] },
            { label = L["AUCTIONS_LIKELY_SOLD"], value = "0", ttTitle = L["TT_AUCTIONS_LIKELY_SOLD"], ttDesc = L["TT_AUCTIONS_LIKELY_SOLD_DESC"] },
            { label = L["AUCTIONS_VALUE"], value = "0g", ttTitle = L["TT_AUCTIONS_VALUE"], ttDesc = L["TT_AUCTIONS_VALUE_DESC"] },
            { label = L["AUCTIONS_CHARACTERS"], value = "0", ttTitle = L["TT_AUCTIONS_CHARACTERS"], ttDesc = L["TT_AUCTIONS_CHARACTERS_DESC"] },
            { label = L["AUCTIONS_EXPIRING"], value = "0", ttTitle = L["TT_AUCTIONS_EXPIRING"], ttDesc = L["TT_AUCTIONS_EXPIRING_DESC"] },
            { label = L["AUCTIONS_EXPIRED"], value = "0", ttTitle = L["TT_AUCTIONS_EXPIRED"], ttDesc = L["TT_AUCTIONS_EXPIRED_DESC"] },
            { label = L["MAIL_GOLD_WAITING"], value = "Closed", ttTitle = L["TT_MAIL_GOLD_WAITING"], ttDesc = L["TT_MAIL_GOLD_WAITING_DESC"] },
            { label = L["HISTORY_GOLD_EARNED"], value = "0", ttTitle = L["TT_HISTORY_GOLD_EARNED"], ttDesc = L["TT_HISTORY_GOLD_EARNED_DESC"] },
        },
    })

    local filterPanel = OneWoW_GUI:CreateFilterBar(parent, { height = 32, anchorBelow = overview.panel, offset = -8 })

    parent.auctionFilter = "all"

    local mailIconButton = OneWoW_GUI:CreateButton(filterPanel, { text = "", width = 32, height = 32 })
    mailIconButton:SetPoint("LEFT", filterPanel, "LEFT", 8, 0)

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
            local mr, mg, mb = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
            mailIcon:SetVertexColor(mr, mg, mb, 1)
        else
            local mr, mg, mb = OneWoW_GUI:GetThemeColor("TEXT_MUTED")
            mailIcon:SetVertexColor(mr, mg, mb, 0.5)
        end
    end

    mailIconButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

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
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        GameTooltip:Hide()
    end)

    parent.mailIconButton = mailIconButton
    parent.UpdateMailIcon = UpdateMailIcon

    local altDropdown, altDropdownText = OneWoW_GUI:CreateDropdown(filterPanel, {
        width = 150, height = 28, text = L["AUCTIONS_ALL_ALTS"] or "All Alts"
    })
    altDropdown:SetPoint("LEFT", mailIconButton, "RIGHT", 4, 0)

    local filterButtons = {}
    local filterOptions = {
        {key = "all", label = L["AUCTIONS_FILTER_ALL"] or "All", tooltip = L["AUCTIONS_FILTER_ALL_DESC"] or "Show all auctions and bids"},
        {key = "auctions", label = L["AUCTIONS_FILTER_AUCTIONS"] or "My Auctions", tooltip = L["AUCTIONS_FILTER_AUCTIONS_DESC"] or "Show only items you are selling"},
        {key = "bids", label = L["AUCTIONS_FILTER_BIDS"] or "My Bids", tooltip = L["AUCTIONS_FILTER_BIDS_DESC"] or "Show only items you are bidding on"},
        {key = "expiring", label = L["AUCTIONS_FILTER_EXPIRING"] or "Expiring Soon", tooltip = L["AUCTIONS_FILTER_EXPIRING_DESC"] or "Show auctions expiring within 2 hours"},
        {key = "history", label = L["AUCTIONS_FILTER_HISTORY"] or "History", tooltip = L["AUCTIONS_FILTER_HISTORY_DESC"] or "Show auction history (sold, expired, canceled)"},
    }

    for i, option in ipairs(filterOptions) do
        local btn = OneWoW_GUI:CreateFitTextButton(filterPanel, { text = option.label, height = 24 })
        if i == 1 then
            btn:SetPoint("LEFT", altDropdown, "RIGHT", 4, 0)
        else
            btn:SetPoint("LEFT", filterButtons[i - 1], "RIGHT", 4, 0)
        end

        btn.filterKey = option.key

        btn:SetScript("OnClick", function(self)
            parent.auctionFilter = self.filterKey
            for _, b in ipairs(filterButtons) do
                if b.filterKey == parent.auctionFilter then
                    b:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    b.text:SetTextColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                else
                    b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    b.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end
            end
            if ns.UI.RefreshAuctionsTab then
                ns.UI.RefreshAuctionsTab(parent)
            end
        end)

        btn:SetScript("OnEnter", function(self)
            if self.filterKey ~= parent.auctionFilter then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(option.label, 1, 1, 1)
            GameTooltip:AddLine(option.tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function(self)
            if self.filterKey ~= parent.auctionFilter then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
            GameTooltip:Hide()
        end)

        if option.key == "all" then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        table.insert(filterButtons, btn)
    end

    local function InitializeAltDropdown()
        if not _G.OneWoW_AltTracker_Auctions_DB or not _G.OneWoW_AltTracker_Auctions_DB.characters then
            altDropdownText:SetText(L["AUCTIONS_ALL_ALTS"] or "All Alts")
            return
        end

        local altList = {}
        for charKey, auctionData in pairs(_G.OneWoW_AltTracker_Auctions_DB.characters) do
            local hasData = false
            if auctionData.activeAuctions and #auctionData.activeAuctions > 0 then hasData = true end
            if auctionData.activeBids and #auctionData.activeBids > 0 then hasData = true end
            if auctionData.auctionHistory and #auctionData.auctionHistory > 0 then hasData = true end
            if hasData then
                local charInfo = _G.OneWoW_AltTracker_Character_DB and
                                 _G.OneWoW_AltTracker_Character_DB.characters and
                                 _G.OneWoW_AltTracker_Character_DB.characters[charKey]
                local charName = (charInfo and charInfo.name) or charKey:match("^([^%-]+)") or charKey
                table.insert(altList, { key = charKey, name = charName })
            end
        end

        table.sort(altList, function(a, b) return a.name < b.name end)

        if not selectedAltKey then
            altDropdownText:SetText(L["AUCTIONS_ALL_ALTS"] or "All Alts")
        else
            local found = false
            for _, alt in ipairs(altList) do
                if alt.key == selectedAltKey then
                    altDropdownText:SetText(alt.name)
                    found = true
                    break
                end
            end
            if not found then
                selectedAltKey = nil
                altDropdownText:SetText(L["AUCTIONS_ALL_ALTS"] or "All Alts")
            end
        end

        OneWoW_GUI:AttachFilterMenu(altDropdown, {
            searchable = (#altList > 5),
            menuHeight = 314,
            buildItems = function()
                local items = {}
                table.insert(items, {
                    text = L["AUCTIONS_ALL_ALTS"] or "All Alts",
                    value = nil,
                })
                for _, alt in ipairs(altList) do
                    table.insert(items, {
                        text = alt.name,
                        value = alt.key,
                    })
                end
                return items
            end,
            getActiveValue = function()
                return selectedAltKey
            end,
            onSelect = function(value, text)
                selectedAltKey = value
                altDropdown._text:SetText(text)
                if ns.UI.RefreshAuctionsTab then
                    ns.UI.RefreshAuctionsTab(parent)
                end
            end,
        })
    end

    InitializeAltDropdown()
    parent.RebuildAltDropdown = InitializeAltDropdown
    parent.altDropdown = altDropdown

    local rosterPanel = OneWoW_GUI:CreateFrame(parent, {})
    rosterPanel:SetPoint("TOPLEFT", filterPanel, "BOTTOMLEFT", 0, -5)
    rosterPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 30)

    local dt
    dt = OneWoW_GUI:CreateDataTable(rosterPanel, {
        columns = columnsConfig,
        headerHeight = 26,
        onHeaderCreate = onHeaderCreate,
        onSort = function(sortColumn, sortAscending)
            currentSortColumn = sortColumn
            currentSortAscending = sortAscending
            ns.UI.RefreshAuctionsTab(parent)
            C_Timer.After(0.1, function() dt.UpdateSortIndicators() end)
        end,
    })

    local statusBar = OneWoW_GUI:CreateStatusBar(parent, rosterPanel, {
        text = string.format(L["CHARACTERS_TRACKED"], 1, ""),
    })

    parent.dataTable = dt
    parent.headerRow = dt.headerRow
    parent.scrollContent = dt.scrollContent
    parent.rosterPanel = rosterPanel
    parent.statBoxes = overview.statBoxes
    parent.statusText = statusBar.text
    parent.statusBar = statusBar.bar
    parent.filterPanel = filterPanel

    OneWoW_GUI:ApplyFontToFrame(parent)

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

    local dt = auctionsTab.dataTable
    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
    OneWoW_GUI:ClearDataRows(scrollContent)
    wipe(auctionRows)
    if dt then dt:ClearRows() end

    if auctionsTab.RebuildAltDropdown then
        auctionsTab.RebuildAltDropdown()
    end

    local currentFilter = auctionsTab.auctionFilter or "all"
    local allAuctions = {}

    for charKey, auctionData in pairs(_G.OneWoW_AltTracker_Auctions_DB.characters) do
        if not selectedAltKey or charKey == selectedAltKey then
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
    end

    if #allAuctions == 0 then
        if auctionsTab.statusText then
            auctionsTab.statusText:SetText(L["NO_AUCTIONS_FOUND"] or "No auctions found")
        end
        return
    end

    local rowHeight = 32
    local rowGap = 2

    for _, entry in ipairs(allAuctions) do
        local charKey = entry.charKey
        local charData = entry.charData
        local auction = entry.auction
        local bid = entry.bid
        local history = entry.history
        local itemData = auction or bid or history
        local isHistory = (entry.type == "history")

        local auctionRow = OneWoW_GUI:CreateDataRow(scrollContent, {
            rowHeight = rowHeight,
            expandedHeight = 50,
            rowGap = rowGap,
            data = { charKey = charKey, charData = charData, itemData = itemData, isHistory = isHistory },
            createDetails = function(ef, d)
                local text = OneWoW_GUI:CreateFS(ef, 12)
                text:SetPoint("CENTER")
                text:SetText(L["EXPANDED_DETAILS_SOON"])
                text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                OneWoW_GUI:ApplyFontToFrame(ef)
            end,
        })
        auctionRow.charKey = charKey

        if not isHistory and auction and auction.endsAt then
            local timeLeft = auction.endsAt - GetServerTime()
            if timeLeft > 0 and timeLeft < 1800 then
                local dr, dg, db = OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL")
                auctionRow.bg:SetColorTexture(dr, dg, db, 1)
                auctionRow.normalBgColor = {dr, dg, db, 1}
            elseif timeLeft > 0 and timeLeft < 3600 then
                local wr, wg, wb = OneWoW_GUI:GetThemeColor("BG_TERTIARY")
                auctionRow.bg:SetColorTexture(wr, wg, wb, 1)
                auctionRow.normalBgColor = {wr, wg, wb, 1}
            end
        end

        auctionRow:SetScript("OnEnter", function(self)
            local hR, hG, hB = OneWoW_GUI:GetThemeColor("BG_HOVER")
            self.bg:SetColorTexture(hR, hG, hB, 0.8)
        end)
        auctionRow:SetScript("OnLeave", function(self)
            if self.normalBgColor then
                self.bg:SetColorTexture(unpack(self.normalBgColor))
            else
                local bgR, bgG, bgB = OneWoW_GUI:GetThemeColor("BG_TERTIARY")
                self.bg:SetColorTexture(bgR, bgG, bgB, 0.6)
            end
        end)

        local itemContainer = CreateFrame("Frame", nil, auctionRow)
        itemContainer:SetHeight(rowHeight - 4)

        local iconFrame = OneWoW_GUI:CreateSkinnedIcon(itemContainer, {
            size = rowHeight - 4,
            preset = "clean",
            iconTexture = itemData.itemIcon,
            quality = itemData.itemRarity,
            showIlvl = (itemData.itemLevel and itemData.itemLevel > 0),
            itemLevel = itemData.itemLevel,
        })
        iconFrame:SetPoint("LEFT", itemContainer, "LEFT", 2, 0)

        local itemLinkFrame = CreateFrame("Button", nil, itemContainer)
        itemLinkFrame:SetPoint("LEFT", iconFrame, "RIGHT", 4, 0)
        itemLinkFrame:SetPoint("RIGHT", itemContainer, "RIGHT", -4, 0)
        itemLinkFrame:SetHeight(rowHeight - 4)

        local itemNameText = OneWoW_GUI:CreateFS(itemLinkFrame, 12)
        itemNameText:SetPoint("LEFT", itemLinkFrame, "LEFT", 0, 0)
        itemNameText:SetPoint("RIGHT", itemLinkFrame, "RIGHT", 0, 0)
        itemNameText:SetJustifyH("LEFT")
        itemNameText:SetWordWrap(false)
        itemNameText:SetText(itemData.itemName or L["AUCTION_UNKNOWN_ITEM"])
        if itemData.itemRarity and ITEM_QUALITY_COLORS[itemData.itemRarity] then
            local color = ITEM_QUALITY_COLORS[itemData.itemRarity]
            itemNameText:SetTextColor(color.r, color.g, color.b)
        else
            itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        if itemData.itemLink then
            itemLinkFrame:EnableMouse(true)
            itemLinkFrame:SetScript("OnEnter", function(self)
                itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(itemData.itemLink)
                GameTooltip:Show()
            end)
            itemLinkFrame:SetScript("OnLeave", function(self)
                if itemData.itemRarity and ITEM_QUALITY_COLORS[itemData.itemRarity] then
                    local color = ITEM_QUALITY_COLORS[itemData.itemRarity]
                    itemNameText:SetTextColor(color.r, color.g, color.b)
                else
                    itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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

        local qtyText = OneWoW_GUI:CreateFS(auctionRow, 12)
        local quantity = itemData.quantity or 1
        qtyText:SetText(tostring(quantity))
        qtyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(auctionRow.cells, qtyText)

        local eachText = OneWoW_GUI:CreateFS(auctionRow, 12)
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
        eachText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        eachText:SetJustifyH("LEFT")
        table.insert(auctionRow.cells, eachText)

        local totalText = OneWoW_GUI:CreateFS(auctionRow, 12)
        if isHistory then
            totalText:SetText(ns.AltTrackerFormatters:FormatGold(history.listPrice or 0))
        else
            local totalAmount = auction and auction.buyoutAmount or (bid and bid.bidAmount or 0)
            totalText:SetText(ns.AltTrackerFormatters:FormatGold(totalAmount))
        end
        totalText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        totalText:SetJustifyH("LEFT")
        table.insert(auctionRow.cells, totalText)

        local bidText = OneWoW_GUI:CreateFS(auctionRow, 12)
        if isHistory then
            if history.salePrice and history.salePrice > 0 then
                bidText:SetText(ns.AltTrackerFormatters:FormatGold(history.salePrice))
                bidText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                bidText:SetText("-")
                bidText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            end
        elseif auction then
            if auction.bidAmount > 0 then
                bidText:SetText(ns.AltTrackerFormatters:FormatGold(auction.bidAmount))
                bidText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                bidText:SetText("-")
                bidText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            end
        else
            bidText:SetText(ns.AltTrackerFormatters:FormatGold(bid.bidAmount))
            bidText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end
        bidText:SetJustifyH("LEFT")
        table.insert(auctionRow.cells, bidText)

        local timeContainer = CreateFrame("Frame", nil, auctionRow)
        timeContainer:SetHeight(rowHeight)

        local timeText = OneWoW_GUI:CreateFS(timeContainer, 12)
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
            timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        elseif auction then
            local timeLeft = auction.endsAt - GetServerTime()
            if timeLeft > 0 then
                if timeLeft < 1800 then
                    local mins = math.floor(timeLeft / 60)
                    timeText:SetText(mins .. "m")
                    timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))

                    local warningIcon = timeContainer:CreateTexture(nil, "OVERLAY")
                    warningIcon:SetSize(12, 12)
                    warningIcon:SetPoint("LEFT", timeText, "RIGHT", 2, 0)
                    warningIcon:SetAtlas("Raid-Icon-Evoker")
                    warningIcon:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
                elseif timeLeft < 3600 then
                    local mins = math.floor(timeLeft / 60)
                    timeText:SetText(mins .. "m")
                    timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
                elseif timeLeft < 7200 then
                    local hours = math.floor(timeLeft / 3600)
                    timeText:SetText(hours .. "h")
                    timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
                else
                    local hours = math.floor(timeLeft / 3600)
                    timeText:SetText(hours .. "h")
                    timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
                end
            else
                timeText:SetText(L["AUCTION_TIME_ENDED"])
                timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
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
            timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        table.insert(auctionRow.cells, timeContainer)

        local charNameText = OneWoW_GUI:CreateFS(auctionRow, 12)
        charNameText:SetText(charData.name or charKey)
        local classColor = RAID_CLASS_COLORS[charData.class]
        if classColor then
            charNameText:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            charNameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        charNameText:SetJustifyH("LEFT")
        table.insert(auctionRow.cells, charNameText)

        local factionCell = OneWoW_GUI:CreateFactionIcon(auctionRow, { faction = charData.faction })
        table.insert(auctionRow.cells, factionCell)

        local statusText = OneWoW_GUI:CreateFS(auctionRow, 12)
        if isHistory then
            if history.outcome == "sold" then
                statusText:SetText(L["OUTCOME_SOLD"])
                statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            elseif history.outcome == "expired" then
                statusText:SetText(L["OUTCOME_EXPIRED"])
                statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            elseif history.outcome == "canceled" then
                statusText:SetText(L["OUTCOME_CANCELED"])
                statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        elseif auction then
            statusText:SetText(L["STATUS_ACTIVE"])
            statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            statusText:SetText(L["STATUS_BIDDING"])
            statusText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end
        statusText:SetJustifyH("LEFT")
        table.insert(auctionRow.cells, statusText)

        local deleteBtn = OneWoW_GUI:CreateFitTextButton(auctionRow, { text = L["PLACEHOLDER_DELETE"], height = 22 })
        deleteBtn:SetScript("OnClick", function()
            if not _G.OneWoW_AltTracker_Auctions_DB or not _G.OneWoW_AltTracker_Auctions_DB.characters then return end
            local charAuctionData = _G.OneWoW_AltTracker_Auctions_DB.characters[charKey]
            if not charAuctionData then return end

            if isHistory and history then
                if charAuctionData.auctionHistory then
                    for idx, event in ipairs(charAuctionData.auctionHistory) do
                        if event.auctionID == history.auctionID and event.timestamp == history.timestamp then
                            table.remove(charAuctionData.auctionHistory, idx)
                            break
                        end
                    end
                end
            elseif entry.type == "bid" and bid then
                if charAuctionData.activeBids then
                    for idx, b in ipairs(charAuctionData.activeBids) do
                        if b.auctionID == bid.auctionID then
                            table.remove(charAuctionData.activeBids, idx)
                            charAuctionData.numActiveBids = #charAuctionData.activeBids
                            break
                        end
                    end
                end
            elseif auction then
                if charAuctionData.activeAuctions then
                    for idx, a in ipairs(charAuctionData.activeAuctions) do
                        if a.auctionID == auction.auctionID then
                            table.remove(charAuctionData.activeAuctions, idx)
                            charAuctionData.numActiveAuctions = #charAuctionData.activeAuctions
                            local totalValue = 0
                            for _, remaining in ipairs(charAuctionData.activeAuctions) do
                                totalValue = totalValue + (remaining.buyoutAmount or 0)
                            end
                            charAuctionData.totalAuctionValue = totalValue
                            break
                        end
                    end
                end
            end

            if ns.UI.RefreshAuctionsTab then
                ns.UI.RefreshAuctionsTab(auctionsTab)
            end
        end)
        table.insert(auctionRow.cells, deleteBtn)

        if dt and dt.headerRow and dt.headerRow.columnButtons and columnsConfig then
            for i, cell in ipairs(auctionRow.cells) do
                local btn = dt.headerRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX
                    local col = columnsConfig[i]
                    cell:ClearAllPoints()
                    if col and col.align == "icon" then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", auctionRow, "LEFT", x, 0)
                    elseif col and col.align == "center" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("CENTER", auctionRow, "LEFT", x + width / 2, 0)
                    elseif col and col.align == "right" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("RIGHT", auctionRow, "LEFT", x + width - 3, 0)
                    else
                        cell:SetWidth(width - 6)
                        cell:SetPoint("LEFT", auctionRow, "LEFT", x + 3, 0)
                    end
                end
            end
        end

        table.insert(auctionRows, auctionRow)
        if dt then dt:RegisterRow(auctionRow) end
    end

    OneWoW_GUI:LayoutDataRows(scrollContent)

    if auctionsTab.statusText then
        local totalItems = #allAuctions
        auctionsTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], totalItems, ""))
    end

    ns.UI.RefreshAuctionsStats(auctionsTab)

    if auctionsTab.UpdateMailIcon then
        auctionsTab.UpdateMailIcon()
    end

    OneWoW_GUI:ApplyFontToFrame(auctionsTab)

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
                statBoxes[9].value:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                statBoxes[9].value:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end
        if statBoxes[10] then
            local goldEarnedFormatted = ns.AltTrackerFormatters:FormatGold(stats.goldEarned)
            statBoxes[10].value:SetText(goldEarnedFormatted)
        end
    end
end
