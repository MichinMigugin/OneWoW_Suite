local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local itemRows = {}
local filterText = ""
local hidebound = false
local hideNoVendor = false

function ns.UI.CreateItemsTab(parent)
    local contentPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    contentPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    contentPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    contentPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    contentPanel:SetBackdropColor(T("BG_PRIMARY"))
    contentPanel:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local filterBar = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    filterBar:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 0, 0)
    filterBar:SetPoint("TOPRIGHT", contentPanel, "TOPRIGHT", 0, 0)
    filterBar:SetHeight(32)
    filterBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    filterBar:SetBackdropColor(T("BG_SECONDARY"))
    filterBar:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local searchBox = CreateFrame("EditBox", nil, filterBar, "InputBoxTemplate")
    searchBox:SetSize(200, 20)
    searchBox:SetPoint("LEFT", filterBar, "LEFT", 8, 0)
    searchBox:SetMaxLetters(50)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        filterText = self:GetText()
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(parent)
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        filterText = ""
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(parent)
        end
        self:ClearFocus()
    end)

    local checkBound = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    checkBound:SetSize(18, 18)
    checkBound:SetPoint("LEFT", searchBox, "RIGHT", 15, 1)
    checkBound.text = checkBound:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkBound.text:SetPoint("LEFT", checkBound, "RIGHT", 3, 0)
    checkBound.text:SetText(L["ITEMS_FILTER_BOUND"])
    checkBound.text:SetTextColor(T("TEXT_PRIMARY"))
    checkBound:SetScript("OnClick", function(self)
        hidebound = self:GetChecked()
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(parent)
        end
    end)

    local checkVendor = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    checkVendor:SetSize(18, 18)
    checkVendor:SetPoint("LEFT", checkBound.text, "RIGHT", 15, 0)
    checkVendor.text = checkVendor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkVendor.text:SetPoint("LEFT", checkVendor, "RIGHT", 3, 0)
    checkVendor.text:SetText(L["ITEMS_FILTER_NO_VENDOR"])
    checkVendor.text:SetTextColor(T("TEXT_PRIMARY"))
    checkVendor:SetScript("OnClick", function(self)
        hideNoVendor = self:GetChecked()
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(parent)
        end
    end)

    local scanAHButton = ns.UI.CreateButton(nil, filterBar, L["ITEMS_SCAN_AH"] or "SCAN AH", 100, 20)
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

    local noticeBar = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    noticeBar:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -5)
    noticeBar:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", 0, -5)
    noticeBar:SetHeight(28)
    noticeBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    noticeBar:SetBackdropColor(T("BG_SECONDARY"))
    noticeBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local noticeText = noticeBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noticeText:SetPoint("LEFT", noticeBar, "LEFT", 12, 0)
    noticeText:SetPoint("RIGHT", noticeBar, "RIGHT", -12, 0)
    noticeText:SetJustifyH("LEFT")
    noticeText:SetWordWrap(true)
    noticeText:SetText(L["ITEMS_NOTICE"])
    noticeText:SetTextColor(1, 0.2, 0.2)

    local rosterPanel = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    rosterPanel:SetPoint("TOPLEFT", noticeBar, "BOTTOMLEFT", 0, -5)
    rosterPanel:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", -5, 8)
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
        {key = "expand", label = "", width = 25, fixed = true},
        {key = "item", label = L["TT_COL_ITEM"] or "Item", width = 150, fixed = false},
        {key = "total", label = L["AUCTIONS_COL_QTY"] or "Total", width = 45, fixed = true},
        {key = "vendor", label = L["ITEMS_COL_VENDOR"] or "Vendor$", width = 80, fixed = false},
        {key = "ah", label = L["ITEMS_COL_AH"] or "AH$", width = 80, fixed = false},
        {key = "lastseen", label = L["COL_LAST_SEEN"] or "Last Seen", width = 85, fixed = true},
    }

    local colGap = 4
    headerRow.columnButtons = {}
    headerRow.columns = columns

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

        if col.key ~= "expand" then
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("CENTER")
            text:SetText(col.label)
            text:SetTextColor(T("TEXT_PRIMARY"))
            btn.text = text
        end

        table.insert(headerRow.columnButtons, btn)
    end

    headerRow:SetScript("OnSizeChanged", function()
        C_Timer.After(0.1, function()
            UpdateColumnLayout()
        end)
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, listContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", 0, 30)
    scrollFrame:EnableMouseWheel(true)

    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", -2, -5)
        scrollBar:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -2, 30)
        scrollBar:SetWidth(10)
        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:Hide()
            scrollBar.ScrollUpButton:SetAlpha(0)
            scrollBar.ScrollUpButton:EnableMouse(false)
        end
        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:Hide()
            scrollBar.ScrollDownButton:SetAlpha(0)
            scrollBar.ScrollDownButton:EnableMouse(false)
        end
        if scrollBar.Background then
            scrollBar.Background:SetColorTexture(T("BG_TERTIARY"))
        end
        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetWidth(8)
            scrollBar.ThumbTexture:SetColorTexture(T("ACCENT_PRIMARY"))
        end
    end

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetHeight(400)
    scrollFrame:SetScrollChild(scrollContent)

    scrollFrame:HookScript("OnSizeChanged", function(self, width, height)
        scrollContent:SetWidth(width)
    end)

    local statusBar = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
    statusBar:SetPoint("BOTTOMLEFT", listContainer, "BOTTOMLEFT", 0, 0)
    statusBar:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", 0, 0)
    statusBar:SetHeight(28)
    statusBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    statusBar:SetBackdropColor(T("BG_SECONDARY"))
    statusBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", statusBar, "LEFT", 12, 0)
    statusText:SetText("")
    statusText:SetTextColor(T("TEXT_SECONDARY"))

    parent.contentPanel = contentPanel
    parent.filterBar = filterBar
    parent.searchBox = searchBox
    parent.checkBound = checkBound
    parent.checkVendor = checkVendor
    parent.rosterPanel = rosterPanel
    parent.listContainer = listContainer
    parent.headerRow = headerRow
    parent.scrollFrame = scrollFrame
    parent.scrollContent = scrollContent
    parent.statusBar = statusBar
    parent.statusText = statusText

    C_Timer.After(0.2, function()
        UpdateColumnLayout()
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(parent)
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
            scanButton:SetText(L["ITEMS_SCAN_AH"] or "SCAN AH")
            scanButton:SetEnabled(true)
            if ns.UI.RefreshItemsTab then
                ns.UI.RefreshItemsTab(itemsTab)
            end
        elseif status == "scanStopped" then
            scanButton.isAHScanning = false
            scanButton:SetText(L["ITEMS_SCAN_AH"] or "SCAN AH")
            scanButton:SetEnabled(true)
        elseif status == "ahClosed" then
            if scanButton.isAHScanning then
                Storage.AHScanner:StopScan()
            end
        end
    end)
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

    for _, row in ipairs(itemRows) do
        if row.expandedFrame then
            row.expandedFrame:Hide()
            row.expandedFrame = nil
        end
        row:Hide()
        row:SetParent(nil)
    end
    wipe(itemRows)

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
                                location = L["BANK_BAGS"] or "Bags",
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
                                location = L["BANK_PERSONAL"] or "Bank",
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
                                location = L["ITEMS_LOCATION_MAIL"] or "Mail",
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
                        items[itemID].totalQty = items[itemID].totalQty + (itemData.count or 1)
                        table.insert(items[itemID].locations, {
                            charName = "Account",
                            location = L["BANK_WARBAND"] or "Warband",
                            qty = itemData.count or 1,
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
                                    location = L["BANK_GUILD"] or "Guild",
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
                            location = L["ITEMS_LOCATION_AH"] or "AH",
                            qty = auction.quantity or 1,
                        })
                    end
                end
            end
        end
    end

    local filteredItems = {}
    for itemID, itemData in pairs(items) do
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
            table.insert(filteredItems, itemData)
        end
    end

    table.sort(filteredItems, function(a, b)
        return (a.itemName or "") < (b.itemName or "")
    end)

    local isUnfiltered = not filterText or filterText == "" and not hidebound and not hideNoVendor
    if isUnfiltered and #filteredItems > 100 then
        for i = #filteredItems, 101, -1 do
            table.remove(filteredItems, i)
        end
    end

    if #filteredItems == 0 then
        local noItemsText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noItemsText:SetPoint("CENTER", scrollContent, "CENTER", 0, 0)
        noItemsText:SetText(L["ITEMS_NO_ITEMS"] or "No items found")
        noItemsText:SetTextColor(T("TEXT_SECONDARY"))
        scrollContent:SetHeight(100)
        if itemsTab.statusText then
            itemsTab.statusText:SetText("0 items")
        end
        return
    end

    local yOffset = -5
    local rowHeight = 30
    local rowGap = 2

    local function RepositionAllRows()
        local yOffset = -5
        for _, row in ipairs(itemRows) do
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

    for _, itemData in ipairs(filteredItems) do
        local itemRow = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        itemRow:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
        itemRow:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        itemRow:SetHeight(rowHeight)
        itemRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        itemRow:SetBackdropColor(T("BG_TERTIARY"))
        itemRow.cells = {}

        local expandBtn = CreateFrame("Button", nil, itemRow)
        expandBtn:SetSize(25, rowHeight)
        local expandIcon = expandBtn:CreateTexture(nil, "ARTWORK")
        expandIcon:SetSize(14, 14)
        expandIcon:SetPoint("CENTER")
        expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
        expandBtn.icon = expandIcon
        table.insert(itemRow.cells, expandBtn)

        local function ToggleExpanded()
            local isExpanded = itemRow.isExpanded or false
            itemRow.isExpanded = not isExpanded

            if itemRow.isExpanded then
                expandIcon:SetAtlas("Gamepad_Rev_Minus_64")
                if not itemRow.expandedFrame then
                    itemRow.expandedFrame = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
                    itemRow.expandedFrame:SetPoint("TOPLEFT", itemRow, "BOTTOMLEFT", 0, -2)
                    itemRow.expandedFrame:SetPoint("TOPRIGHT", itemRow, "BOTTOMRIGHT", 0, -2)
                    itemRow.expandedFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                    itemRow.expandedFrame:SetBackdropColor(T("BG_SECONDARY"))

                    local numLocations = #itemData.locations
                    local expandHeight = (numLocations * 20) + 20
                    itemRow.expandedFrame:SetHeight(expandHeight)

                    local locYOffset = -8
                    for _, locData in ipairs(itemData.locations) do
                        local locText = itemRow.expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        locText:SetPoint("TOPLEFT", itemRow.expandedFrame, "TOPLEFT", 15, locYOffset)
                        locText:SetText(locData.charName .. " - " .. locData.location .. " x" .. locData.qty)
                        locText:SetTextColor(T("TEXT_PRIMARY"))
                        locYOffset = locYOffset - 18
                    end
                end
                itemRow.expandedFrame:Show()
            else
                expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
                if itemRow.expandedFrame then
                    itemRow.expandedFrame:Hide()
                end
            end

            RepositionAllRows()
        end

        expandBtn:SetScript("OnClick", ToggleExpanded)

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
        qualityBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
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
                if itemData.quality and ITEM_QUALITY_COLORS[itemData.quality] then
                    local color = ITEM_QUALITY_COLORS[itemData.quality]
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

        table.insert(itemRow.cells, itemContainer)

        local totalText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        totalText:SetText(tostring(itemData.totalQty))
        totalText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(itemRow.cells, totalText)

        local vendorText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if itemData.vendorPrice and itemData.vendorPrice > 0 then
            vendorText:SetText(ns.AltTrackerFormatters:FormatGold(itemData.vendorPrice))
            vendorText:SetTextColor(T("TEXT_PRIMARY"))
        else
            vendorText:SetText(L["ITEMS_NO_VALUE"] or "NO VALUE")
            vendorText:SetTextColor(T("TEXT_SECONDARY"))
        end
        table.insert(itemRow.cells, vendorText)

        local ahText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if itemData.ahPrice and itemData.ahPrice > 0 then
            ahText:SetText(ns.AltTrackerFormatters:FormatGold(itemData.ahPrice))
            ahText:SetTextColor(T("TEXT_PRIMARY"))
        else
            ahText:SetText(L["ITEMS_NO_VALUE"] or "NO VALUE")
            ahText:SetTextColor(T("TEXT_SECONDARY"))
        end
        table.insert(itemRow.cells, ahText)

        local lastSeenText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lastSeenText:SetText(FormatLastSeen(itemData.lastSeenTime))
        lastSeenText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(itemRow.cells, lastSeenText)

        itemRow:EnableMouse(true)
        itemRow:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)
        itemRow:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
        end)
        itemRow:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                ToggleExpanded()
            end
        end)

        local headerRow = itemsTab.headerRow
        if headerRow and headerRow.columnButtons then
            for i, cell in ipairs(itemRow.cells) do
                local btn = headerRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX

                    cell:ClearAllPoints()

                    if i == 1 then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", itemRow, "LEFT", x, 0)
                    else
                        cell:SetWidth(width - 6)
                        if i == 2 then
                            cell:SetPoint("LEFT", itemRow, "LEFT", x + 3, 0)
                        else
                            cell:SetPoint("CENTER", itemRow, "LEFT", x + width/2, 0)
                        end
                    end
                end
            end
        end

        itemRow:Show()
        table.insert(itemRows, itemRow)
        yOffset = yOffset - (rowHeight + rowGap)
    end

    RepositionAllRows()

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
            itemsTab.statusText:SetText(#filteredItems .. " of " .. totalCount .. " items" .. filterState)
        else
            itemsTab.statusText:SetText(#filteredItems .. " items" .. filterState)
        end
    end

    C_Timer.After(0.1, function()
        if itemsTab.headerRow then
            itemsTab.headerRow:GetScript("OnSizeChanged")(itemsTab.headerRow)
        end
    end)

end
