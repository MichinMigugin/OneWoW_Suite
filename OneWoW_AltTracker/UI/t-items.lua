local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

ns.UI = ns.UI or {}

local itemRows = {}
local filterText = ""
local hidebound = false
local hideNoVendor = false
local currentSortColumn = "item"
local currentSortAscending = true

local columnsConfig = {
    {key = "expand", label = "",                      width = 25,  fixed = true,  align = "icon",   sortable = false, ttTitle = L["TT_COL_EXPAND"],          ttDesc = L["TT_COL_EXPAND_DESC"]},
    {key = "item",   label = L["ITEMS_COL_ITEM"],     width = 150, fixed = false, align = "left",                     ttTitle = L["TT_ITEMS_COL_ITEM"],     ttDesc = L["TT_ITEMS_COL_ITEM_DESC"]},
    {key = "total",  label = L["ITEMS_COL_TOTAL"],    width = 45,  fixed = true,  align = "center",                   ttTitle = L["TT_ITEMS_COL_TOTAL"],    ttDesc = L["TT_ITEMS_COL_TOTAL_DESC"]},
    {key = "vendor", label = L["ITEMS_COL_VENDOR"],   width = 80,  fixed = false, align = "right",                    ttTitle = L["TT_ITEMS_COL_VENDOR"],   ttDesc = L["TT_ITEMS_COL_VENDOR_DESC"]},
    {key = "ah",     label = L["ITEMS_COL_AH"],       width = 80,  fixed = false, align = "right",                    ttTitle = L["TT_ITEMS_COL_AH"],       ttDesc = L["TT_ITEMS_COL_AH_DESC"]},
    {key = "lastseen", label = L["ITEMS_COL_LAST_SEEN"], width = 85, fixed = true, align = "center",                  ttTitle = L["TT_ITEMS_COL_LAST_SEEN"], ttDesc = L["TT_ITEMS_COL_LAST_SEEN_DESC"]},
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

function ns.UI.CreateItemsTab(parent)
    local overview = OneWoW_GUI:CreateOverviewPanel(parent, {
        title = L["ITEMS_OVERVIEW"],
        height = 70,
        columns = 5,
        stats = {
            {label = L["ITEMS_STAT_UNIQUE"],       value = "0", ttTitle = L["TT_ITEMS_STAT_UNIQUE"],       ttDesc = L["TT_ITEMS_STAT_UNIQUE_DESC"]},
            {label = L["ITEMS_STAT_TOTAL_QTY"],    value = "0", ttTitle = L["TT_ITEMS_STAT_TOTAL_QTY"],    ttDesc = L["TT_ITEMS_STAT_TOTAL_QTY_DESC"]},
            {label = L["ITEMS_STAT_VENDOR_VALUE"],  value = "0", ttTitle = L["TT_ITEMS_STAT_VENDOR_VALUE"], ttDesc = L["TT_ITEMS_STAT_VENDOR_VALUE_DESC"]},
            {label = L["ITEMS_STAT_AH_VALUE"],     value = "0", ttTitle = L["TT_ITEMS_STAT_AH_VALUE"],     ttDesc = L["TT_ITEMS_STAT_AH_VALUE_DESC"]},
            {label = L["ITEMS_STAT_BOUND"],        value = "0", ttTitle = L["TT_ITEMS_STAT_BOUND"],        ttDesc = L["TT_ITEMS_STAT_BOUND_DESC"]},
        },
    })

    local filterBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    filterBar:SetPoint("TOPLEFT", overview.panel, "BOTTOMLEFT", 0, -8)
    filterBar:SetPoint("TOPRIGHT", overview.panel, "BOTTOMRIGHT", 0, -8)
    filterBar:SetHeight(32)
    filterBar:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    filterBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    filterBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local searchBox = OneWoW_GUI:CreateEditBox(filterBar, {
        height = 20,
        placeholderText = L["ITEMS_SEARCH_HINT"],
        onTextChanged = function(text)
            filterText = text
            if ns.UI.RefreshItemsTab then
                ns.UI.RefreshItemsTab(parent)
            end
        end,
    })
    searchBox:SetWidth(200)
    searchBox:SetPoint("LEFT", filterBar, "LEFT", 8, 0)

    local checkBound = OneWoW_GUI:CreateCheckbox(filterBar, { label = L["ITEMS_FILTER_BOUND"] })
    checkBound:SetPoint("LEFT", searchBox, "RIGHT", 15, 1)
    checkBound:SetScript("OnClick", function(self)
        hidebound = self:GetChecked()
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(parent)
        end
    end)

    local checkVendor = OneWoW_GUI:CreateCheckbox(filterBar, { label = L["ITEMS_FILTER_NO_VENDOR"] })
    checkVendor:SetPoint("LEFT", checkBound.label, "RIGHT", 15, 0)
    checkVendor:SetScript("OnClick", function(self)
        hideNoVendor = self:GetChecked()
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(parent)
        end
    end)

    local scanAHButton = OneWoW_GUI:CreateButton(filterBar, { text = L["ITEMS_SCAN_AH"], width = 100, height = 20 })
    scanAHButton:SetPoint("RIGHT", filterBar, "RIGHT", -8, 0)
    scanAHButton.isAHScanning = false
    scanAHButton:SetScript("OnClick", function(self)
        if self.isAHScanning then
            local Auctions = _G.OneWoW_AltTracker_Auctions
            if Auctions and Auctions.AHScanner then
                Auctions.AHScanner:StopScan()
            end
            return
        end
        if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
            print("|cFFFFD100OneWoW:|r " .. (L["ITEMS_AH_NOT_OPEN"] or "Open the Auction House first to scan prices."))
            return
        end
        ns.UI:StartAHScan(parent, scanAHButton)
    end)

    parent.scanAHButton = scanAHButton

    local scanBarContainer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    scanBarContainer:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -3)
    scanBarContainer:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", 0, -3)
    scanBarContainer:SetHeight(20)
    scanBarContainer:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    scanBarContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    scanBarContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    scanBarContainer:Hide()

    local scanProgressBar = OneWoW_GUI:CreateProgressBar(scanBarContainer, { height = 14, min = 0, max = 1, value = 0 })
    scanProgressBar:SetPoint("TOPLEFT", scanBarContainer, "TOPLEFT", 4, -3)
    scanProgressBar:SetPoint("TOPRIGHT", scanBarContainer, "TOPRIGHT", -4, -3)

    parent.scanBarContainer = scanBarContainer
    parent.scanProgressBar = scanProgressBar

    local noticeBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    noticeBar:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -5)
    noticeBar:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", 0, -5)
    noticeBar:SetHeight(28)
    parent.noticeBar = noticeBar
    noticeBar:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    noticeBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    noticeBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local noticeText = noticeBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noticeText:SetPoint("LEFT", noticeBar, "LEFT", 12, 0)
    noticeText:SetPoint("RIGHT", noticeBar, "RIGHT", -12, 0)
    noticeText:SetJustifyH("LEFT")
    noticeText:SetWordWrap(true)
    noticeText:SetText(L["ITEMS_NOTICE"])
    noticeText:SetTextColor(1, 0.2, 0.2)

    local rosterPanel = OneWoW_GUI:CreateRosterPanel(parent, noticeBar)

    local dt
    dt = OneWoW_GUI:CreateDataTable(rosterPanel, {
        columns = columnsConfig,
        headerHeight = 26,
        onHeaderCreate = onHeaderCreate,
        onSort = function(sortColumn, sortAscending)
            currentSortColumn = sortColumn
            currentSortAscending = sortAscending
            ns.UI.RefreshItemsTab(parent)
            C_Timer.After(0.1, function() dt.UpdateSortIndicators() end)
        end,
    })

    local status = OneWoW_GUI:CreateStatusBar(parent, rosterPanel, {
        text = "",
    })

    parent.overviewPanel = overview.panel
    parent.statBoxes = overview.statBoxes
    parent.filterBar = filterBar
    parent.searchBox = searchBox
    parent.checkBound = checkBound
    parent.checkVendor = checkVendor
    parent.rosterPanel = rosterPanel
    parent.dataTable = dt
    parent.columnsConfig = columnsConfig
    parent.headerRow = dt.headerRow
    parent.scrollContent = dt.scrollContent
    parent.statusBar = status.bar
    parent.statusText = status.text

    ns.UI.ApplyFontToFrame(parent)

    C_Timer.After(0.2, function()
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(parent)
        end
    end)
end

function ns.UI:StartAHScan(itemsTab, scanButton)
    local Auctions = _G.OneWoW_AltTracker_Auctions
    if not Auctions or not Auctions.AHScanner then
        return
    end

    if not _G.OneWoW_AltTracker_Storage_DB or not _G.OneWoW_AltTracker_Storage_DB.characters then
        return
    end

    local itemsToScan = {}
    local seenItems = {}

    for charKey, charData in pairs(_G.OneWoW_AltTracker_Storage_DB.characters) do
        if charData.bags then
            for bagID, bagInfo in pairs(charData.bags) do
                if bagInfo.slots then
                    for slotID, itemData in pairs(bagInfo.slots) do
                        if itemData and itemData.itemID and not seenItems[itemData.itemID] then
                            if not itemData.isBound then
                                table.insert(itemsToScan, {
                                    itemID = itemData.itemID,
                                    itemName = itemData.itemName,
                                    isBound = itemData.isBound,
                                })
                                seenItems[itemData.itemID] = true
                            end
                        end
                    end
                end
            end
        end

        if charData.personalBank and charData.personalBank.tabs then
            for tabIndex, tabInfo in pairs(charData.personalBank.tabs) do
                if tabInfo.items then
                    for slotID, itemData in pairs(tabInfo.items) do
                        if itemData and itemData.itemID and not seenItems[itemData.itemID] then
                            if not itemData.isBound then
                                table.insert(itemsToScan, {
                                    itemID = itemData.itemID,
                                    itemName = itemData.itemName,
                                    isBound = itemData.isBound,
                                })
                                seenItems[itemData.itemID] = true
                            end
                        end
                    end
                end
            end
        end

        if charData.mail and charData.mail.mails then
            for mailID, mailData in pairs(charData.mail.mails) do
                if mailData.items then
                    for attachmentIndex, itemData in pairs(mailData.items) do
                        if itemData and itemData.itemID and not seenItems[itemData.itemID] then
                            local isBound = itemData.canUse == false
                            if not isBound then
                                table.insert(itemsToScan, {
                                    itemID = itemData.itemID,
                                    itemName = itemData.itemName or itemData.name,
                                    isBound = isBound,
                                })
                                seenItems[itemData.itemID] = true
                            end
                        end
                    end
                end
            end
        end
    end

    if _G.OneWoW_AltTracker_Storage_DB.warbandBank and _G.OneWoW_AltTracker_Storage_DB.warbandBank.tabs then
        for tabIndex, tabInfo in pairs(_G.OneWoW_AltTracker_Storage_DB.warbandBank.tabs) do
            if tabInfo.items then
                for slotIndex, itemData in pairs(tabInfo.items) do
                    if itemData and itemData.itemID and not seenItems[itemData.itemID] then
                        table.insert(itemsToScan, {
                            itemID = itemData.itemID,
                            itemName = itemData.itemName,
                            isBound = false,
                        })
                        seenItems[itemData.itemID] = true
                    end
                end
            end
        end
    end

    if _G.OneWoW_AltTracker_Storage_DB.guildBanks then
        for guildName, guildBank in pairs(_G.OneWoW_AltTracker_Storage_DB.guildBanks) do
            if guildBank.tabs then
                for tabIndex, tabInfo in pairs(guildBank.tabs) do
                    if tabInfo.slots then
                        for slotID, itemData in pairs(tabInfo.slots) do
                            if itemData and itemData.itemID and not seenItems[itemData.itemID] then
                                table.insert(itemsToScan, {
                                    itemID = itemData.itemID,
                                    itemName = itemData.itemName,
                                    isBound = false,
                                })
                                seenItems[itemData.itemID] = true
                            end
                        end
                    end
                end
            end
        end
    end

    if #itemsToScan == 0 then
        print("|cFFFFD100Items Tab:|r No non-bound items to scan.")
        return
    end

    scanButton.isAHScanning = true
    scanButton:SetText(L["ITEMS_SCAN_STOPPED"] or "Stop")

    local progressBar = itemsTab.scanProgressBar
    local progressContainer = itemsTab.scanBarContainer
    local noticeBar = itemsTab.noticeBar

    local function ShowProgress(show)
        if show then
            progressContainer:Show()
            if noticeBar then
                noticeBar:SetPoint("TOPLEFT", progressContainer, "BOTTOMLEFT", 0, -3)
                noticeBar:SetPoint("TOPRIGHT", progressContainer, "BOTTOMRIGHT", 0, -3)
            end
        else
            progressContainer:Hide()
            if noticeBar then
                noticeBar:SetPoint("TOPLEFT", itemsTab.filterBar, "BOTTOMLEFT", 0, -5)
                noticeBar:SetPoint("TOPRIGHT", itemsTab.filterBar, "BOTTOMRIGHT", 0, -5)
            end
        end
    end

    local function ScanDone(pricesFound)
        scanButton.isAHScanning = false
        scanButton:SetText(L["ITEMS_SCAN_AH"])
        scanButton:SetEnabled(true)
        ShowProgress(false)
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(itemsTab)
        end
    end

    local lastRefreshIndex = 0

    Auctions.AHScanner:StartScan(itemsToScan, function(status, current, total, extra)
        if status == "scanStarted" then
            ShowProgress(true)
            if progressBar then
                progressBar:UpdateProgress(0, total)
                progressBar._text:SetText("0/" .. total .. " - " .. (L["ITEMS_SCANNING_STATUS"] or "Scanning..."))
            end
        elseif status == "itemScanned" then
            if progressBar then
                progressBar:UpdateProgress(current, total)
                local pricesFound = extra or 0
                progressBar._text:SetText(current .. "/" .. total .. "  (" .. pricesFound .. " " .. (L["ITEMS_PRICES_FOUND"] or "prices found") .. ")")
            end
            if current - lastRefreshIndex >= 25 then
                lastRefreshIndex = current
                if ns.UI.RefreshItemsTab then
                    ns.UI.RefreshItemsTab(itemsTab)
                end
            end
        elseif status == "scanCompleted" then
            local pricesFound = extra or 0
            if progressBar then
                progressBar:UpdateProgress(total, total)
                progressBar._text:SetText(L["ITEMS_SCAN_COMPLETE"] .. "  (" .. pricesFound .. " " .. (L["ITEMS_PRICES_FOUND"] or "prices found") .. ")")
            end
            C_Timer.After(3, function()
                ScanDone(pricesFound)
            end)
        elseif status == "scanStopped" then
            ScanDone(0)
        elseif status == "ahClosed" then
            if scanButton.isAHScanning then
                Auctions.AHScanner:StopScan()
            end
        end
    end)
end

local function FormatLastSeen(timestamp)
    if not timestamp or timestamp == 0 then return L["FMT_NEVER"] or "Never" end
    local hours = (time() - timestamp) / 3600
    if hours < 24 then
        return math.max(1, math.floor(hours)) .. " hr"
    else
        local days = math.floor(hours / 24)
        if days <= 365 then
            return days .. "d"
        else
            return "Over 1yr"
        end
    end
end

local function ResolveItemData(itemData)
    local itemName = itemData.itemName
    local texture  = itemData.texture
    local itemLink = itemData.itemLink
    local vendorPrice = itemData.sellPrice or 0

    if not itemName or not texture then
        local name, link, _, _, _, _, _, _, _, tex, sell = GetItemInfo(itemData.itemID)
        if name then
            itemName  = itemName  or name
            itemLink  = itemLink  or link
            texture   = texture   or tex
            if vendorPrice == 0 then vendorPrice = sell or 0 end
        end
    end

    return itemName, texture, itemLink, vendorPrice
end

local function AddToLocation(item, charName, location, qty)
    local locKey = charName .. "|" .. location
    if not item.locationIndex then item.locationIndex = {} end
    if item.locationIndex[locKey] then
        item.locationIndex[locKey].qty = item.locationIndex[locKey].qty + qty
    else
        local entry = { charName = charName, location = location, qty = qty }
        table.insert(item.locations, entry)
        item.locationIndex[locKey] = entry
    end
end

function ns.UI.RefreshItemsTab(itemsTab)
    if not itemsTab then return end
    if not _G.OneWoW_AltTracker_Storage_DB or not _G.OneWoW_AltTracker_Storage_DB.characters then return end

    local scrollContent = itemsTab.scrollContent
    if not scrollContent then return end

    local dt = itemsTab.dataTable
    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

    OneWoW_GUI:ClearDataRows(scrollContent)
    wipe(itemRows)
    if dt then dt:ClearRows() end

    local items = {}

    for charKey, charData in pairs(_G.OneWoW_AltTracker_Storage_DB.characters) do
        local charName = charKey:match("^([^%-]+)")

        if charData.bags then
            local ts = charData.bagsLastUpdate or 0
            for bagID, bagInfo in pairs(charData.bags) do
                if bagInfo.slots then
                    for slotID, itemData in pairs(bagInfo.slots) do
                        if itemData and itemData.itemID then
                            local itemID = itemData.itemID
                            if not items[itemID] then
                                local iName, iTex, iLink, iVend = ResolveItemData(itemData)
                                items[itemID] = {
                                    itemID = itemID,
                                    itemName = iName,
                                    texture = iTex,
                                    quality = itemData.quality,
                                    itemLink = iLink,
                                    vendorPrice = iVend,
                                    totalQty = 0,
                                    isBound = false,
                                    locations = {},
                                    lastSeenTime = 0,
                                }
                            end
                            items[itemID].totalQty = items[itemID].totalQty + (itemData.stackCount or 1)
                            if ts > (items[itemID].lastSeenTime or 0) then items[itemID].lastSeenTime = ts end
                            if itemData.isBound then items[itemID].isBound = true end
                            AddToLocation(items[itemID], charName, L["BANK_BAGS"], itemData.stackCount or 1)
                        end
                    end
                end
            end
        end

        if charData.personalBank and charData.personalBank.tabs then
            local ts = charData.personalBankLastUpdate or 0
            for tabIndex, tabInfo in pairs(charData.personalBank.tabs) do
                if tabInfo.items then
                    for slotID, itemData in pairs(tabInfo.items) do
                        if itemData and itemData.itemID then
                            local itemID = itemData.itemID
                            if not items[itemID] then
                                local iName, iTex, iLink, iVend = ResolveItemData(itemData)
                                items[itemID] = {
                                    itemID = itemID,
                                    itemName = iName,
                                    texture = iTex,
                                    quality = itemData.quality,
                                    itemLink = iLink,
                                    vendorPrice = iVend,
                                    totalQty = 0,
                                    isBound = false,
                                    locations = {},
                                    lastSeenTime = 0,
                                }
                            end
                            items[itemID].totalQty = items[itemID].totalQty + (itemData.stackCount or 1)
                            if ts > (items[itemID].lastSeenTime or 0) then items[itemID].lastSeenTime = ts end
                            if itemData.isBound then items[itemID].isBound = true end
                            AddToLocation(items[itemID], charName, L["BANK_PERSONAL"], itemData.stackCount or 1)
                        end
                    end
                end
            end
        end

        if charData.mail and charData.mail.mails then
            local ts = charData.mailLastUpdate or 0
            for mailID, mailData in pairs(charData.mail.mails) do
                if mailData.items then
                    for attachmentIndex, itemData in pairs(mailData.items) do
                        if itemData and itemData.itemID then
                            local itemID = itemData.itemID
                            if not items[itemID] then
                                items[itemID] = {
                                    itemID = itemID,
                                    itemName = itemData.itemName or itemData.name or "Unknown",
                                    texture = itemData.texture,
                                    quality = itemData.quality,
                                    itemLink = itemData.itemLink,
                                    vendorPrice = itemData.sellPrice or 0,
                                    totalQty = 0,
                                    isBound = false,
                                    locations = {},
                                    lastSeenTime = 0,
                                }
                            end
                            items[itemID].totalQty = items[itemID].totalQty + (itemData.count or 1)
                            if ts > (items[itemID].lastSeenTime or 0) then items[itemID].lastSeenTime = ts end
                            if itemData.canUse == false then
                                items[itemID].isBound = true
                            end
                            AddToLocation(items[itemID], charName, L["ITEMS_LOCATION_MAIL"], itemData.count or 1)
                        end
                    end
                end
            end
        end
    end

    if _G.OneWoW_AltTracker_Storage_DB.warbandBank and _G.OneWoW_AltTracker_Storage_DB.warbandBank.tabs then
        local ts = _G.OneWoW_AltTracker_Storage_DB.warbandBank.lastUpdateTime or 0
        for tabIndex, tabInfo in pairs(_G.OneWoW_AltTracker_Storage_DB.warbandBank.tabs) do
            if tabInfo.items then
                for slotIndex, itemData in pairs(tabInfo.items) do
                    if itemData and itemData.itemID then
                        local itemID = itemData.itemID
                        if not items[itemID] then
                            local iName, iTex, iLink, iVend = ResolveItemData(itemData)
                            items[itemID] = {
                                itemID = itemID,
                                itemName = iName,
                                texture = iTex,
                                quality = itemData.quality,
                                itemLink = iLink,
                                vendorPrice = iVend,
                                totalQty = 0,
                                isBound = false,
                                locations = {},
                                lastSeenTime = 0,
                            }
                        end
                        items[itemID].totalQty = items[itemID].totalQty + (itemData.stackCount or 1)
                        if ts > (items[itemID].lastSeenTime or 0) then items[itemID].lastSeenTime = ts end
                        AddToLocation(items[itemID], "Account", L["BANK_WARBAND"], itemData.stackCount or 1)
                    end
                end
            end
        end
    end

    if _G.OneWoW_AltTracker_Storage_DB.guildBanks then
        for guildName, guildBank in pairs(_G.OneWoW_AltTracker_Storage_DB.guildBanks) do
            local ts = guildBank.lastUpdateTime or 0
            if guildBank.tabs then
                for tabIndex, tabInfo in pairs(guildBank.tabs) do
                    if tabInfo.slots then
                        for slotID, itemData in pairs(tabInfo.slots) do
                            if itemData and itemData.itemID then
                                local itemID = itemData.itemID
                                if not items[itemID] then
                                    local iName, iTex, iLink, iVend = ResolveItemData(itemData)
                                    items[itemID] = {
                                        itemID = itemID,
                                        itemName = iName,
                                        texture = iTex,
                                        quality = itemData.quality,
                                        itemLink = iLink,
                                        vendorPrice = iVend,
                                        totalQty = 0,
                                        isBound = false,
                                        locations = {},
                                        lastSeenTime = 0,
                                    }
                                end
                                items[itemID].totalQty = items[itemID].totalQty + (itemData.stackCount or 1)
                                if ts > (items[itemID].lastSeenTime or 0) then items[itemID].lastSeenTime = ts end
                                AddToLocation(items[itemID], guildName, L["BANK_GUILD"], itemData.stackCount or 1)
                            end
                        end
                    end
                end
            end
        end
    end

    if _G.OneWoW_AltTracker_Auctions_DB and _G.OneWoW_AltTracker_Auctions_DB.characters then
        for charKey, charData in pairs(_G.OneWoW_AltTracker_Auctions_DB.characters) do
            local charName = charKey:match("^([^%-]+)")
            local ts = charData.lastAuctionUpdate or 0
            if charData.activeAuctions then
                for _, auction in ipairs(charData.activeAuctions) do
                    local itemID = auction.itemID
                    if itemID then
                        if not items[itemID] then
                            items[itemID] = {
                                itemID = itemID,
                                itemName = auction.itemName or "Unknown",
                                texture = auction.itemIcon,
                                quality = auction.itemRarity,
                                itemLink = auction.itemLink,
                                vendorPrice = 0,
                                totalQty = 0,
                                isBound = false,
                                locations = {},
                                lastSeenTime = 0,
                            }
                        end
                        items[itemID].totalQty = items[itemID].totalQty + (auction.quantity or 1)
                        if ts > (items[itemID].lastSeenTime or 0) then items[itemID].lastSeenTime = ts end
                        AddToLocation(items[itemID], charName, L["ITEMS_LOCATION_AH"], auction.quantity or 1)
                    end
                end
            end
        end
    end

    local filteredItems = {}
    local totalUniqueItems = 0
    local totalQuantity = 0
    local totalVendorValue = 0
    local totalAHValue = 0
    local totalBoundItems = 0

    for itemID, itemData in pairs(items) do
        totalUniqueItems = totalUniqueItems + 1
        totalQuantity = totalQuantity + itemData.totalQty
        if itemData.vendorPrice and itemData.vendorPrice > 0 then
            totalVendorValue = totalVendorValue + (itemData.vendorPrice * itemData.totalQty)
        end
        if itemData.isBound then totalBoundItems = totalBoundItems + 1 end

        local shouldInclude = true

        if itemData.isBound and hidebound then
            shouldInclude = false
        end

        if shouldInclude then
            local hasVendorPrice = itemData.vendorPrice and itemData.vendorPrice > 0
            if hideNoVendor and not hasVendorPrice then
                shouldInclude = false
            end
        end

        if shouldInclude and filterText and filterText ~= "" then
            if not (itemData.itemName and itemData.itemName:lower():find(filterText:lower(), 1, true)) then
                shouldInclude = false
            end
        end

        if shouldInclude then
            local priceDB = _G.OneWoW_AHPrices
            if priceDB and priceDB[itemID] then
                itemData.ahPrice = priceDB[itemID].price or 0
                itemData.ahTime = priceDB[itemID].timestamp or 0
            else
                itemData.ahPrice = 0
                itemData.ahTime = 0
            end
            if itemData.ahPrice and itemData.ahPrice > 0 then
                totalAHValue = totalAHValue + (itemData.ahPrice * itemData.totalQty)
            end
            table.insert(filteredItems, itemData)
        end
    end

    if itemsTab.statBoxes then
        if itemsTab.statBoxes[1] then
            itemsTab.statBoxes[1].value:SetText(tostring(totalUniqueItems))
        end
        if itemsTab.statBoxes[2] then
            itemsTab.statBoxes[2].value:SetText(tostring(totalQuantity))
        end
        if itemsTab.statBoxes[3] then
            itemsTab.statBoxes[3].value:SetText(ns.AltTrackerFormatters:FormatGold(totalVendorValue))
        end
        if itemsTab.statBoxes[4] then
            itemsTab.statBoxes[4].value:SetText(ns.AltTrackerFormatters:FormatGold(totalAHValue))
        end
        if itemsTab.statBoxes[5] then
            itemsTab.statBoxes[5].value:SetText(tostring(totalBoundItems))
        end
    end

    if currentSortColumn == "item" then
        table.sort(filteredItems, function(a, b)
            if currentSortAscending then return (a.itemName or "") < (b.itemName or "")
            else return (a.itemName or "") > (b.itemName or "") end
        end)
    elseif currentSortColumn == "total" then
        table.sort(filteredItems, function(a, b)
            if currentSortAscending then return (a.totalQty or 0) < (b.totalQty or 0)
            else return (a.totalQty or 0) > (b.totalQty or 0) end
        end)
    elseif currentSortColumn == "vendor" then
        table.sort(filteredItems, function(a, b)
            if currentSortAscending then return (a.vendorPrice or 0) < (b.vendorPrice or 0)
            else return (a.vendorPrice or 0) > (b.vendorPrice or 0) end
        end)
    elseif currentSortColumn == "ah" then
        table.sort(filteredItems, function(a, b)
            if currentSortAscending then return (a.ahPrice or 0) < (b.ahPrice or 0)
            else return (a.ahPrice or 0) > (b.ahPrice or 0) end
        end)
    elseif currentSortColumn == "lastseen" then
        table.sort(filteredItems, function(a, b)
            if currentSortAscending then return (a.lastSeenTime or 0) < (b.lastSeenTime or 0)
            else return (a.lastSeenTime or 0) > (b.lastSeenTime or 0) end
        end)
    else
        table.sort(filteredItems, function(a, b)
            return (a.itemName or "") < (b.itemName or "")
        end)
    end

    local isUnfiltered = (not filterText or filterText == "") and not hidebound and not hideNoVendor
    if isUnfiltered and #filteredItems > 100 then
        for i = #filteredItems, 101, -1 do
            table.remove(filteredItems, i)
        end
    end

    if #filteredItems == 0 then
        if itemsTab.statusText then
            itemsTab.statusText:SetText(L["ITEMS_NO_ITEMS"])
        end
        return
    end

    local rowHeight = 30
    local rowGap = 2

    for _, itemData in ipairs(filteredItems) do
        local itemRow = OneWoW_GUI:CreateDataRow(scrollContent, {
            rowHeight = rowHeight,
            expandedHeight = 60,
            rowGap = rowGap,
            data = { itemData = itemData },
            createDetails = function(ef, d)
                local grid = OneWoW_GUI:CreateExpandedPanelGrid(ef, T)
                local p1 = grid:AddPanel(d.itemData.itemName or "")
                for _, locData in ipairs(d.itemData.locations) do
                    grid:AddLine(p1, locData.charName .. " - " .. locData.location .. " x" .. locData.qty)
                end
                grid:Finish()
                ns.UI.ApplyFontToFrame(ef)
            end,
        })

        local itemContainer = CreateFrame("Frame", nil, itemRow)
        itemContainer:SetHeight(rowHeight - 4)

        local itemIcon = itemContainer:CreateTexture(nil, "ARTWORK")
        itemIcon:SetSize(rowHeight - 6, rowHeight - 6)
        itemIcon:SetPoint("LEFT", itemContainer, "LEFT", 2, 0)
        if itemData.texture then
            itemIcon:SetTexture(itemData.texture)
        else
            itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        local qualityBorder = itemContainer:CreateTexture(nil, "BORDER")
        qualityBorder:SetSize(rowHeight - 4, rowHeight - 4)
        qualityBorder:SetPoint("CENTER", itemIcon, "CENTER", 0, 0)
        qualityBorder:SetTexture(BACKDROP_SIMPLE.bgFile)
        if itemData.quality and ITEM_QUALITY_COLORS[itemData.quality] then
            local color = ITEM_QUALITY_COLORS[itemData.quality]
            qualityBorder:SetVertexColor(color.r, color.g, color.b, 0.3)
        else
            qualityBorder:SetVertexColor(0.5, 0.5, 0.5, 0.3)
        end
        qualityBorder:SetDrawLayer("BORDER", 0)

        local itemLinkFrame = CreateFrame("Button", nil, itemContainer)
        itemLinkFrame:SetPoint("LEFT", itemIcon, "RIGHT", 4, 0)
        itemLinkFrame:SetPoint("RIGHT", itemContainer, "RIGHT", -4, 0)
        itemLinkFrame:SetHeight(rowHeight - 4)

        local itemNameText = itemLinkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        itemNameText:SetPoint("LEFT", itemLinkFrame, "LEFT", 0, 0)
        itemNameText:SetPoint("RIGHT", itemLinkFrame, "RIGHT", 0, 0)
        itemNameText:SetJustifyH("LEFT")
        itemNameText:SetWordWrap(false)
        itemNameText:SetText(itemData.itemName or "Unknown")
        if itemData.quality and ITEM_QUALITY_COLORS[itemData.quality] then
            local color = ITEM_QUALITY_COLORS[itemData.quality]
            itemNameText:SetTextColor(color.r, color.g, color.b)
        else
            itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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
                if itemData.quality and ITEM_QUALITY_COLORS[itemData.quality] then
                    local color = ITEM_QUALITY_COLORS[itemData.quality]
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

        table.insert(itemRow.cells, itemContainer)

        local totalText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        totalText:SetText(tostring(itemData.totalQty))
        totalText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(itemRow.cells, totalText)

        local vendorText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if itemData.vendorPrice and itemData.vendorPrice > 0 then
            vendorText:SetText(ns.AltTrackerFormatters:FormatGold(itemData.vendorPrice))
            vendorText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            vendorText:SetText(L["ITEMS_NO_VALUE"])
            vendorText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        table.insert(itemRow.cells, vendorText)

        local ahText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if itemData.ahPrice and itemData.ahPrice > 0 then
            ahText:SetText(ns.AltTrackerFormatters:FormatGold(itemData.ahPrice))
            ahText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            ahText:SetText(L["ITEMS_NO_VALUE"])
            ahText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        table.insert(itemRow.cells, ahText)

        local lastSeenText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lastSeenText:SetText(FormatLastSeen(itemData.lastSeenTime))
        lastSeenText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(itemRow.cells, lastSeenText)

        if dt and dt.headerRow and dt.headerRow.columnButtons and columnsConfig then
            for i, cell in ipairs(itemRow.cells) do
                local btn = dt.headerRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX
                    local col = columnsConfig[i]
                    cell:ClearAllPoints()
                    if col and col.align == "icon" then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", itemRow, "LEFT", x, 0)
                    elseif col and col.align == "center" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("CENTER", itemRow, "LEFT", x + width / 2, 0)
                    elseif col and col.align == "right" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("RIGHT", itemRow, "LEFT", x + width - 3, 0)
                    else
                        cell:SetWidth(width - 6)
                        cell:SetPoint("LEFT", itemRow, "LEFT", x + 3, 0)
                    end
                end
            end
        end

        table.insert(itemRows, itemRow)
        if dt then dt:RegisterRow(itemRow) end
    end

    OneWoW_GUI:LayoutDataRows(scrollContent, { rowHeight = rowHeight, rowGap = rowGap })

    ns.UI.ApplyFontToFrame(itemsTab)

    if itemsTab.statusText then
        local filterState = ""
        if hidebound or hideNoVendor then
            if hidebound and hideNoVendor then
                filterState = " (Bound & No Vendor hidden)"
            elseif hidebound then
                filterState = " (Bound hidden)"
            else
                filterState = " (No Vendor hidden)"
            end
        end
        if filterText and filterText ~= "" then
            filterState = filterState .. " - Search: '" .. filterText .. "'"
        end
        local totalCount = 0
        for _ in pairs(items) do
            totalCount = totalCount + 1
        end
        if totalCount > #filteredItems then
            itemsTab.statusText:SetText(string.format(L["ITEMS_STATUS_FILTERED"], #filteredItems, totalCount) .. filterState)
        else
            itemsTab.statusText:SetText(string.format(L["ITEMS_STATUS"], #filteredItems) .. filterState)
        end
    end
end
