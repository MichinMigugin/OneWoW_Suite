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
    scanAHButton:SetEnabled(false)
    scanAHButton.isAHScanning = false
    scanAHButton:SetScript("OnClick", function(self)
        if not self.isAHScanning then
            ns.UI:StartAHScan(parent, scanAHButton)
        end
    end)

    parent.ahCheckFrame = CreateFrame("Frame")
    parent.ahCheckFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    parent.ahCheckFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    parent.ahCheckFrame:SetScript("OnEvent", function(self, event)
        if event == "AUCTION_HOUSE_SHOW" then
            C_Timer.After(0.1, function()
                scanAHButton:SetEnabled(true)
            end)
        elseif event == "AUCTION_HOUSE_CLOSED" then
            scanAHButton:SetEnabled(false)
        end
    end)

    parent.scanAHButton = scanAHButton

    local noticeBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    noticeBar:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -5)
    noticeBar:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", 0, -5)
    noticeBar:SetHeight(28)
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
    local Storage = _G.OneWoW_AltTracker_Storage
    if not Storage or not Storage.AHScanner then
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
    scanButton:SetEnabled(false)

    Storage.AHScanner:StartScan(itemsToScan, function(status, current, total, itemName)
        if status == "scanStarted" then
            print("|cFFFFD100Items Tab:|r Starting AH price scan for " .. total .. " items...")
        elseif status == "itemScanning" then
            scanButton:SetText(current .. "/" .. total)
        elseif status == "scanCompleted" then
            print("|cFFFFD100Items Tab:|r AH scan complete!")
            scanButton.isAHScanning = false
            scanButton:SetText(L["ITEMS_SCAN_AH"])
            scanButton:SetEnabled(true)
            if ns.UI.RefreshItemsTab then
                ns.UI.RefreshItemsTab(itemsTab)
            end
        elseif status == "scanStopped" then
            scanButton.isAHScanning = false
            scanButton:SetText(L["ITEMS_SCAN_AH"])
            scanButton:SetEnabled(true)
        elseif status == "ahClosed" then
            if scanButton.isAHScanning then
                Storage.AHScanner:StopScan()
            end
        end
    end)
end

local function FormatLastSeen(timestamp)
    if not timestamp or timestamp == 0 then return L["FMT_NEVER"] or "Never" end
    local hoursSince = (time() - timestamp) / 3600
    if hoursSince < 245 then
        return date("%H:%M", timestamp)
    else
        return date("%Y%m%d", timestamp)
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
                                }
                            end
                            items[itemID].totalQty = items[itemID].totalQty + (itemData.stackCount or 1)
                            if itemData.isBound then items[itemID].isBound = true end
                            table.insert(items[itemID].locations, {
                                charName = charName,
                                location = L["BANK_BAGS"],
                                qty = itemData.stackCount or 1,
                            })
                        end
                    end
                end
            end
        end

        if charData.personalBank and charData.personalBank.tabs then
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
                                }
                            end
                            items[itemID].totalQty = items[itemID].totalQty + (itemData.stackCount or 1)
                            if itemData.isBound then items[itemID].isBound = true end
                            table.insert(items[itemID].locations, {
                                charName = charName,
                                location = L["BANK_PERSONAL"],
                                qty = itemData.stackCount or 1,
                            })
                        end
                    end
                end
            end
        end

        if charData.mail and charData.mail.mails then
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
                                }
                            end
                            items[itemID].totalQty = items[itemID].totalQty + (itemData.count or 1)
                            if itemData.canUse == false then
                                items[itemID].isBound = true
                            end
                            table.insert(items[itemID].locations, {
                                charName = charName,
                                location = L["ITEMS_LOCATION_MAIL"],
                                qty = itemData.count or 1,
                            })
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
                            }
                        end
                        items[itemID].totalQty = items[itemID].totalQty + (itemData.stackCount or 1)
                        table.insert(items[itemID].locations, {
                            charName = "Account",
                            location = L["BANK_WARBAND"],
                            qty = itemData.stackCount or 1,
                        })
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
                                    }
                                end
                                items[itemID].totalQty = items[itemID].totalQty + (itemData.stackCount or 1)
                                table.insert(items[itemID].locations, {
                                    charName = guildName,
                                    location = L["BANK_GUILD"],
                                    qty = itemData.stackCount or 1,
                                })
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
                            }
                        end
                        items[itemID].totalQty = items[itemID].totalQty + (auction.quantity or 1)
                        table.insert(items[itemID].locations, {
                            charName = charName,
                            location = L["ITEMS_LOCATION_AH"],
                            qty = auction.quantity or 1,
                        })
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
            local Storage = _G.OneWoW_AltTracker_Storage
            if Storage and Storage.AHScanner then
                local ahPrice, ahTime = Storage.AHScanner:GetAHPrice(itemID)
                if ahPrice then
                    itemData.ahPrice = ahPrice
                    itemData.ahTime = ahTime or 0
                else
                    itemData.ahPrice = 0
                    itemData.ahTime = 0
                end
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
