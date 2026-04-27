local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end
local PE = OneWoW_GUI.PredicateEngine

ns.UI = ns.UI or {}

local function MatchesSearch(itemData, searchText)
    if not searchText or searchText == "" then return true end
    if PE then
        local itemInfo = {
            hyperlink = itemData.itemLink,
            count = itemData.totalQty or 1,
            quality = itemData.quality,
        }
        if itemData.vendorPrice and itemData.vendorPrice > 0 then
            itemInfo.vendorprice = itemData.vendorPrice
        end
        local ok, matched = pcall(PE.CheckItem, PE, searchText, itemData.itemID, nil, nil, itemInfo)
        if ok then return matched == true end
    end
    local name = itemData.itemName
    return name and name:lower():find(searchText:lower(), 1, true) ~= nil
end

local itemRows = {}
local filterText = ""
local hidebound = false
local hideNoVendor = false
local currentSortColumn = "item"
local currentSortAscending = true

local columnsConfig = {
    {key = "expand", label = "",                      width = 25,  fixed = true,  align = "icon",   sortable = false, ttTitle = L["TT_COL_EXPAND"],          ttDesc = L["TT_COL_EXPAND_DESC"]},
    {key = "favorite", label = L["ITEMS_COL_FAVORITE"], width = 28, fixed = true, align = "center", sortable = false, ttTitle = L["TT_ITEMS_COL_FAVORITE"], ttDesc = L["TT_ITEMS_COL_FAVORITE_DESC"]},
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
    elseif col.key == "favorite" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("CENTER")
        OneWoW_GUI:SetFavoriteAtlasTexture(icon)
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

    local filterBar = OneWoW_GUI:CreateFilterBar(parent, { height = 32, anchorBelow = overview.panel, offset = -8 })

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

    if OneWoW_GUI.AttachSearchTooltip then
        OneWoW_GUI:AttachSearchTooltip(searchBox)
    end
    local searchHelpBtn
    if OneWoW_GUI.CreateKeywordHelpButton then
        searchHelpBtn = OneWoW_GUI:CreateKeywordHelpButton(filterBar, { editBox = searchBox, size = 20 })
        searchHelpBtn:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)
    end

    local checkBound = OneWoW_GUI:CreateCheckbox(filterBar, { label = L["ITEMS_FILTER_BOUND"] })
    if searchHelpBtn then
        checkBound:SetPoint("LEFT", searchHelpBtn, "RIGHT", 10, 1)
    else
        checkBound:SetPoint("LEFT", searchBox, "RIGHT", 15, 1)
    end
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

    local scanAHButton = OneWoW_GUI:CreateFitTextButton(filterBar, { text = L["ITEMS_SCAN_AH"], height = 20 })
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
            print(L["ADDON_CHAT_PREFIX"] .. " " .. L["ITEMS_AH_NOT_OPEN"])
            return
        end
        ns.UI:StartAHScan(parent, scanAHButton)
    end)

    parent.scanAHButton = scanAHButton

    local scanBarContainer = OneWoW_GUI:CreateFrame(parent, { height = 20, bgColor = "BG_SECONDARY", borderColor = "BORDER_SUBTLE" })
    scanBarContainer:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -3)
    scanBarContainer:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", 0, -3)
    scanBarContainer:Hide()

    local scanProgressBar = OneWoW_GUI:CreateProgressBar(scanBarContainer, { height = 14, min = 0, max = 1, value = 0 })
    scanProgressBar:SetPoint("TOPLEFT", scanBarContainer, "TOPLEFT", 4, -3)
    scanProgressBar:SetPoint("TOPRIGHT", scanBarContainer, "TOPRIGHT", -4, -3)

    parent.scanBarContainer = scanBarContainer
    parent.scanProgressBar = scanProgressBar

    local noticeBar = OneWoW_GUI:CreateFrame(parent, { height = 28, bgColor = "BG_SECONDARY", borderColor = "BORDER_SUBTLE" })
    noticeBar:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -5)
    noticeBar:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", 0, -5)
    parent.noticeBar = noticeBar

    local noticeText = OneWoW_GUI:CreateFS(noticeBar, 12)
    noticeText:SetPoint("LEFT", noticeBar, "LEFT", 12, 0)
    noticeText:SetPoint("RIGHT", noticeBar, "RIGHT", -12, 0)
    noticeText:SetJustifyH("LEFT")
    noticeText:SetWordWrap(true)
    noticeText:SetText(L["ITEMS_NOTICE"])
    noticeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))

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

    OneWoW_GUI:ApplyFontToFrame(parent)

    C_Timer.After(0.2, function()
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(parent)
        end
    end)
end

function ns.UI:StartAHScan(itemsTab, scanButton)
    local Auctions = OneWoW_AltTracker_Auctions
    if not Auctions or not Auctions.AHScanner then
        return
    end

    if not OneWoW_AltTracker_Storage_DB or not OneWoW_AltTracker_Storage_DB.characters then
        return
    end

    local itemsToScan = {}
    local seenItems = {}

    for charKey, charData in pairs(OneWoW_AltTracker_Storage_DB.characters) do
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
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["ITEMS_NONE_TO_SCAN"])
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

    -- Prefer a link-based live lookup so the vendor price reflects the
    -- per-variant sell price (bonus IDs, item level, crafted quality),
    -- matching the OneWoW Tooltips "Value" line.
    local lookupKey = itemLink or itemData.itemID
    if lookupKey then
        local name, link, _, _, _, _, _, _, _, tex, sell = C_Item.GetItemInfo(lookupKey)
        if name then
            itemName = itemName or name
            itemLink = itemLink or link
            texture  = texture  or tex
            if sell and sell > 0 then
                vendorPrice = sell
            end
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
    if not OneWoW_AltTracker_Storage_DB or not OneWoW_AltTracker_Storage_DB.characters then return end

    do
        local hideScan = _G.OneWoW and _G.OneWoW.ItemPrices and _G.OneWoW.ItemPrices:IsAuctionatorAHSourceActive()
        if itemsTab.scanAHButton then
            itemsTab.scanAHButton:SetShown(not hideScan)
        end
        if itemsTab.noticeText then
            itemsTab.noticeText:SetText(hideScan and (L["ITEMS_NOTICE_AUCTIONATOR"] or L["ITEMS_NOTICE"]) or L["ITEMS_NOTICE"])
        end
    end

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
                                local iName, iTex, iLink, iVend = ResolveItemData(itemData)
                                items[itemID] = {
                                    itemID = itemID,
                                    itemName = iName or itemData.name or "Unknown",
                                    texture = iTex or itemData.texture,
                                    quality = itemData.quality,
                                    itemLink = iLink,
                                    vendorPrice = iVend,
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

    if OneWoW_AltTracker_Auctions_DB and OneWoW_AltTracker_Auctions_DB.characters then
        for charKey, charData in pairs(OneWoW_AltTracker_Auctions_DB.characters) do
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
            if not MatchesSearch(itemData, filterText) then
                shouldInclude = false
            end
        end

        if shouldInclude then
            local ow = _G.OneWoW
            if ow and ow.ItemPrices then
                local p, meta = ow.ItemPrices:GetUnitAHPrice(itemID, itemData.itemLink)
                if p and p > 0 then
                    itemData.ahPrice = p
                    itemData.ahTime = (meta and meta.timestamp) or 0
                else
                    itemData.ahPrice = 0
                    itemData.ahTime = 0
                end
            else
                local priceDB = _G.OneWoW_AHPrices
                if priceDB and priceDB[itemID] then
                    itemData.ahPrice = priceDB[itemID].price or 0
                    itemData.ahTime = priceDB[itemID].timestamp or 0
                else
                    itemData.ahPrice = 0
                    itemData.ahTime = 0
                end
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

    local function sortWithFavoritesFirst(inner)
        table.sort(filteredItems, function(a, b)
            local fa, fb = ns.IsFavoriteItem(a.itemID), ns.IsFavoriteItem(b.itemID)
            if fa ~= fb then return fa end
            return inner(a, b)
        end)
    end

    if currentSortColumn == "item" then
        sortWithFavoritesFirst(function(a, b)
            if currentSortAscending then return (a.itemName or "") < (b.itemName or "")
            else return (a.itemName or "") > (b.itemName or "") end
        end)
    elseif currentSortColumn == "total" then
        sortWithFavoritesFirst(function(a, b)
            if currentSortAscending then return (a.totalQty or 0) < (b.totalQty or 0)
            else return (a.totalQty or 0) > (b.totalQty or 0) end
        end)
    elseif currentSortColumn == "vendor" then
        sortWithFavoritesFirst(function(a, b)
            if currentSortAscending then return (a.vendorPrice or 0) < (b.vendorPrice or 0)
            else return (a.vendorPrice or 0) > (b.vendorPrice or 0) end
        end)
    elseif currentSortColumn == "ah" then
        sortWithFavoritesFirst(function(a, b)
            if currentSortAscending then return (a.ahPrice or 0) < (b.ahPrice or 0)
            else return (a.ahPrice or 0) > (b.ahPrice or 0) end
        end)
    elseif currentSortColumn == "lastseen" then
        sortWithFavoritesFirst(function(a, b)
            if currentSortAscending then return (a.lastSeenTime or 0) < (b.lastSeenTime or 0)
            else return (a.lastSeenTime or 0) > (b.lastSeenTime or 0) end
        end)
    else
        sortWithFavoritesFirst(function(a, b)
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
                local grid = OneWoW_GUI:CreateExpandedPanelGrid(ef)
                local p1 = grid:AddPanel(d.itemData.itemName or "")
                for _, locData in ipairs(d.itemData.locations) do
                    grid:AddLine(p1, locData.charName .. " - " .. locData.location .. " x" .. locData.qty)
                end
                grid:Finish()
                OneWoW_GUI:ApplyFontToFrame(ef)
            end,
        })

        local capturedItemID = itemData.itemID
        local favBtn = OneWoW_GUI:CreateFavoriteToggleButton(itemRow, {
            size = 18,
            favorite = ns.IsFavoriteItem(capturedItemID),
            tooltipTitle = L["TT_ITEMS_COL_FAVORITE"],
            tooltipText = L["TT_ITEMS_COL_FAVORITE_DESC"],
            onClick = function(_, isFav)
                ns.SetFavoriteItem(capturedItemID, isFav)
                ns.UI.RefreshItemsTab(itemsTab)
            end,
        })
        table.insert(itemRow.cells, 2, favBtn)

        local itemContainer = CreateFrame("Frame", nil, itemRow)
        itemContainer:SetHeight(rowHeight - 4)

        local iconFrame = OneWoW_GUI:CreateSkinnedIcon(itemContainer, {
            size = rowHeight - 4,
            preset = "clean",
            iconTexture = itemData.texture,
            quality = itemData.quality,
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
                itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
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

        local totalText = OneWoW_GUI:CreateFS(itemRow, 12)
        totalText:SetText(tostring(itemData.totalQty))
        totalText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(itemRow.cells, totalText)

        local vendorText = OneWoW_GUI:CreateFS(itemRow, 12)
        if itemData.vendorPrice and itemData.vendorPrice > 0 then
            vendorText:SetText(ns.AltTrackerFormatters:FormatGold(itemData.vendorPrice))
            vendorText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            vendorText:SetText(L["ITEMS_NO_VALUE"])
            vendorText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        table.insert(itemRow.cells, vendorText)

        local ahText = OneWoW_GUI:CreateFS(itemRow, 12)
        if itemData.ahPrice and itemData.ahPrice > 0 then
            ahText:SetText(ns.AltTrackerFormatters:FormatGold(itemData.ahPrice))
            ahText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            ahText:SetText(L["ITEMS_NO_VALUE"])
            ahText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        table.insert(itemRow.cells, ahText)

        local lastSeenText = OneWoW_GUI:CreateFS(itemRow, 12)
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

    OneWoW_GUI:ApplyFontToFrame(itemsTab)

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
