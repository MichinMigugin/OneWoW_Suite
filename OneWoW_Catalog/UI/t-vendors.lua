local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local selectedVendor = nil
local vendorListButtons = {}
local detailElements = {}
local searchText = ""
local zoneFilter = nil
local currentZoneOnly = false
local dataAddon = nil

local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62, 1.0 },
    [1] = { 1.00, 1.00, 1.00, 1.0 },
    [2] = { 0.12, 1.00, 0.00, 1.0 },
    [3] = { 0.00, 0.44, 0.87, 1.0 },
    [4] = { 0.64, 0.21, 0.93, 1.0 },
    [5] = { 1.00, 0.50, 0.00, 1.0 },
    [6] = { 0.90, 0.80, 0.50, 1.0 },
    [7] = { 0.00, 0.80, 1.00, 1.0 },
}

local function FormatGold(copper)
    if not copper or copper <= 0 then return "" end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    local parts = {}
    if gold > 0 then table.insert(parts, gold .. "g") end
    if silver > 0 then table.insert(parts, silver .. "s") end
    if cop > 0 then table.insert(parts, cop .. "c") end
    return table.concat(parts, " ")
end

local function FormatCost(itemData)
    if itemData.currencies and #itemData.currencies > 0 then
        local parts = {}
        for _, curr in ipairs(itemData.currencies) do
            local name = curr.name
            if (not name or name == "") and curr.itemID then
                name = C_Item.GetItemNameByID(curr.itemID)
            end
            if (not name or name == "") and curr.currencyID then
                local currInfo = C_CurrencyInfo.GetCurrencyInfo(curr.currencyID)
                name = currInfo and currInfo.name
            end
            if not name or name == "" then
                name = L["VENDORS_CURRENCY"]
            end

            local icon = curr.texture
            if (not icon or icon == 0) and curr.itemID then
                icon = C_Item.GetItemIconByID(curr.itemID)
            end
            if (not icon or icon == 0) and curr.currencyID then
                local currInfo = C_CurrencyInfo.GetCurrencyInfo(curr.currencyID)
                if currInfo then icon = currInfo.iconFileID end
            end

            local iconStr = ""
            if icon and icon ~= 0 then
                iconStr = "|T" .. icon .. ":14:14|t "
            end

            table.insert(parts, "x" .. curr.amount .. " " .. iconStr)
        end
        return table.concat(parts, " - ")
    elseif itemData.cost and itemData.cost > 0 then
        return FormatGold(itemData.cost)
    end
    return L["VENDORS_PRICE_UNKNOWN"]
end

local function FormatTimestamp(timestamp)
    if not timestamp then return "" end
    return date("%Y-%m-%d %H:%M", timestamp)
end

local function GetDataAddon()
    if dataAddon then return dataAddon end
    if ns.Catalog and ns.Catalog.GetDataAddon then
        dataAddon = ns.Catalog:GetDataAddon("vendors")
    end
    return dataAddon
end

local function GetCurrentPlayerZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil end
    local info = C_Map.GetMapInfo(mapID)
    if not info then return nil, nil end
    return info.name, mapID
end

local function BuildZoneList()
    local addon = GetDataAddon()
    if not addon or not addon.VendorData then return {} end

    local allVendors = addon.VendorData:GetAllVendors()
    local zoneSet = {}
    for _, vendor in pairs(allVendors) do
        if vendor.locations then
            for _, loc in pairs(vendor.locations) do
                if loc.zone and loc.zone ~= "" then
                    zoneSet[loc.zone] = true
                end
            end
        end
    end

    local zones = {}
    for zone in pairs(zoneSet) do
        table.insert(zones, zone)
    end
    table.sort(zones)
    return zones
end

local function VendorMatchesZoneFilter(vendor, filterZone)
    if not filterZone then return true end
    if not vendor or not vendor.locations then return false end
    for _, loc in pairs(vendor.locations) do
        if loc.zone == filterZone then
            return true
        end
    end
    return false
end

local function VendorMatchesItemSearch(vendor, term, addon)
    if not vendor or not vendor.items or not term or term == "" then return false end
    if not addon or not addon.DataLoader then return false end
    for itemID in pairs(vendor.items) do
        local cached = addon.DataLoader:GetCachedItem(itemID)
        if cached and cached.name and cached.name:lower():find(term, 1, true) then
            return true
        end
    end
    return false
end

local function ClearDetailElements()
    for _, element in ipairs(detailElements) do
        if element.Hide then element:Hide() end
        if element.SetParent then element:SetParent(nil) end
    end
    wipe(detailElements)
end

local function ClearVendorList()
    for _, btn in ipairs(vendorListButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(vendorListButtons)
end

local function CreateVendorListEntry(parent, vendor, yOffset, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    btn:SetHeight(52)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    btn:SetBackdropColor(T("BG_SECONDARY"))

    local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -6)
    nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -8, -6)
    nameText:SetJustifyH("LEFT")
    if vendor.name then
        nameText:SetText(vendor.name)
        nameText:SetTextColor(T("ACCENT_PRIMARY"))
    else
        nameText:SetText("NPC #" .. (vendor.npcID or "?"))
        nameText:SetTextColor(T("TEXT_MUTED"))
    end

    local mapID, location = nil, nil
    if vendor.locations then
        for mID, loc in pairs(vendor.locations) do
            mapID = mID
            location = loc
            break
        end
    end

    local infoText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    infoText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -8, 0)
    infoText:SetJustifyH("LEFT")

    local zone = location and location.zone or L["VENDORS_UNKNOWN_LOCATION"]
    local itemCount = 0
    if vendor.items then
        for _ in pairs(vendor.items) do itemCount = itemCount + 1 end
    end
    infoText:SetText(zone .. "  |  " .. itemCount .. " " .. L["VENDORS_ITEMS_SHORT"])
    infoText:SetTextColor(T("TEXT_SECONDARY"))

    local scanText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scanText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 8, 5)
    scanText:SetJustifyH("LEFT")
    if vendor.lastScanned then
        scanText:SetText(FormatTimestamp(vendor.lastScanned))
    end
    scanText:SetTextColor(T("TEXT_MUTED"))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
    end)
    btn:SetScript("OnLeave", function(self)
        if selectedVendor and selectedVendor.npcID == vendor.npcID then
            self:SetBackdropColor(T("BG_ACTIVE"))
        else
            self:SetBackdropColor(T("BG_SECONDARY"))
        end
    end)
    btn:SetScript("OnClick", function()
        onClick(vendor)
    end)

    btn.vendor = vendor
    return btn
end

local function ShowVendorDetail(panels, vendor)
    if not vendor then return end

    selectedVendor = vendor

    if panels.emptyDetail then panels.emptyDetail:Hide() end

    ClearDetailElements()

    local parent = panels.detailScrollChild
    local yOffset = -8

    local addon = GetDataAddon()

    local nameHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    nameHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    nameHeader:SetJustifyH("LEFT")
    if vendor.name then
        nameHeader:SetText(vendor.name)
        nameHeader:SetTextColor(T("ACCENT_PRIMARY"))
    else
        nameHeader:SetText("NPC #" .. (vendor.npcID or "?"))
        nameHeader:SetTextColor(T("TEXT_MUTED"))
    end
    table.insert(detailElements, nameHeader)
    yOffset = yOffset - 22

    local infoLine = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    infoLine:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    infoLine:SetJustifyH("LEFT")
    local infoParts = {}
    table.insert(infoParts, L["VENDORS_NPC_ID"] .. ": " .. (vendor.npcID or "?"))
    if vendor.level and vendor.level > 0 then
        table.insert(infoParts, L["VENDORS_LEVEL"] .. ": " .. vendor.level)
    end
    if vendor.creatureType and vendor.creatureType ~= "" then
        table.insert(infoParts, vendor.creatureType)
    end
    infoLine:SetText(table.concat(infoParts, "  |  "))
    infoLine:SetTextColor(T("TEXT_SECONDARY"))
    table.insert(detailElements, infoLine)
    yOffset = yOffset - 18

    if vendor.locations then
        local locCount = 0
        for _ in pairs(vendor.locations) do locCount = locCount + 1 end

        for mapID, loc in pairs(vendor.locations) do
            local locLine = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            locLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
            locLine:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -60, yOffset)
            locLine:SetJustifyH("LEFT")
            local coordStr = ""
            if loc.x and loc.y and loc.x > 0 then
                coordStr = string.format(" (%.1f, %.1f)", loc.x, loc.y)
            end
            locLine:SetText(L["VENDORS_LOCATION"] .. ": " .. (loc.zone or "") .. coordStr)
            locLine:SetTextColor(T("TEXT_SECONDARY"))
            table.insert(detailElements, locLine)

            local wpBtn = ns.UI.CreateButton(nil, parent, L["VENDORS_WAYPOINT"], 50, 16)
            wpBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
            table.insert(detailElements, wpBtn)

            local capturedMapID = mapID
            wpBtn:SetScript("OnClick", function()
                if addon and addon.VendorData then
                    addon.VendorData:CreateWaypoint(vendor, capturedMapID)
                end
            end)

            yOffset = yOffset - 18
        end
    end

    yOffset = yOffset - 4
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    divider:SetHeight(1)
    divider:SetColorTexture(T("BORDER_SUBTLE"))
    table.insert(detailElements, divider)
    yOffset = yOffset - 8

    local scanInfo = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scanInfo:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    scanInfo:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    scanInfo:SetJustifyH("LEFT")
    local scanParts = {}
    if vendor.firstSeen then
        table.insert(scanParts, L["VENDORS_FIRST_SEEN"] .. ": " .. FormatTimestamp(vendor.firstSeen))
    end
    if vendor.lastScanned then
        table.insert(scanParts, L["VENDORS_LAST_SCANNED"] .. ": " .. FormatTimestamp(vendor.lastScanned))
    end
    if vendor.scanCount then
        table.insert(scanParts, L["VENDORS_SCAN_COUNT"] .. ": " .. vendor.scanCount)
    end
    scanInfo:SetText(table.concat(scanParts, "  |  "))
    scanInfo:SetTextColor(T("TEXT_MUTED"))
    table.insert(detailElements, scanInfo)
    yOffset = yOffset - 20

    local itemsHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemsHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    itemsHeader:SetJustifyH("LEFT")
    local itemCount = 0
    if vendor.items then
        for _ in pairs(vendor.items) do itemCount = itemCount + 1 end
    end
    itemsHeader:SetText(L["VENDORS_ITEM_COUNT"] .. ": " .. itemCount)
    itemsHeader:SetTextColor(T("ACCENT_PRIMARY"))
    table.insert(detailElements, itemsHeader)
    yOffset = yOffset - 22

    if panels.rightStatusText then
        panels.rightStatusText:SetText((vendor.name or ("NPC #" .. (vendor.npcID or "?"))) .. " - " .. itemCount .. " " .. L["VENDORS_ITEMS_SHORT"])
    end

    if vendor.items then
        local sortedItems = {}
        for itemID, itemData in pairs(vendor.items) do
            table.insert(sortedItems, { id = itemID, data = itemData })
        end
        table.sort(sortedItems, function(a, b)
            return (a.data.cost or 0) > (b.data.cost or 0)
        end)

        for _, entry in ipairs(sortedItems) do
            local itemID = entry.id
            local itemData = entry.data

            local itemRow = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            itemRow:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
            itemRow:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
            itemRow:SetHeight(32)
            itemRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            itemRow:SetBackdropColor(T("BG_SECONDARY"))
            table.insert(detailElements, itemRow)

            local iconFrame = CreateFrame("Frame", nil, itemRow, "BackdropTemplate")
            iconFrame:SetSize(26, 26)
            iconFrame:SetPoint("LEFT", itemRow, "LEFT", 6, 0)
            iconFrame:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            iconFrame:SetBackdropBorderColor(1, 1, 1, 0.3)
            table.insert(detailElements, iconFrame)

            local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
            iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
            iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
            iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            table.insert(detailElements, iconTex)

            local itemName = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            itemName:SetPoint("LEFT", iconFrame, "RIGHT", 8, 0)
            itemName:SetPoint("RIGHT", itemRow, "RIGHT", -150, 0)
            itemName:SetJustifyH("LEFT")
            itemName:SetWordWrap(false)
            table.insert(detailElements, itemName)

            local costText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            costText:SetPoint("RIGHT", itemRow, "RIGHT", -8, 0)
            costText:SetJustifyH("RIGHT")
            costText:SetText(FormatCost(itemData))
            costText:SetTextColor(T("TEXT_SECONDARY"))
            table.insert(detailElements, costText)

            if itemData.limited then
                local limitTag = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                limitTag:SetPoint("RIGHT", costText, "LEFT", -6, 0)
                limitTag:SetText("[" .. L["VENDORS_LIMITED"] .. "]")
                limitTag:SetTextColor(0.9, 0.4, 0.4, 1.0)
                table.insert(detailElements, limitTag)
            end

            local cachedItem = addon and addon.DataLoader and addon.DataLoader:GetCachedItem(itemID)
            if cachedItem and cachedItem.name then
                itemName:SetText(cachedItem.name)
                local qColor = QUALITY_COLORS[cachedItem.quality] or QUALITY_COLORS[1]
                itemName:SetTextColor(unpack(qColor))
                iconTex:SetTexture(cachedItem.icon)
                iconFrame:SetBackdropBorderColor(unpack(qColor))
            else
                itemName:SetText(L["VENDORS_LOADING"] .. " (" .. itemID .. ")")
                itemName:SetTextColor(T("TEXT_MUTED"))
                iconTex:SetTexture(134400)

                if addon and addon.DataLoader then
                    addon.DataLoader:LoadItemData(itemID, function(loadedID, data)
                        if data and itemName:IsVisible() then
                            itemName:SetText(data.name or "")
                            local qColor = QUALITY_COLORS[data.quality] or QUALITY_COLORS[1]
                            itemName:SetTextColor(unpack(qColor))
                            iconTex:SetTexture(data.icon)
                            iconFrame:SetBackdropBorderColor(unpack(qColor))
                        end
                    end)
                end
            end

            itemRow:EnableMouse(true)
            itemRow:SetScript("OnEnter", function(self)
                self:SetBackdropColor(T("BG_HOVER"))
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(itemID)
                GameTooltip:Show()
            end)
            itemRow:SetScript("OnLeave", function(self)
                self:SetBackdropColor(T("BG_SECONDARY"))
                GameTooltip:Hide()
            end)

            yOffset = yOffset - 34
        end
    end

    parent:SetHeight(math.abs(yOffset) + 20)
    panels.UpdateDetailThumb()
end

local function RefreshVendorList(panels)
    ClearVendorList()

    local addon = GetDataAddon()
    if not addon or not addon.VendorData then
        panels.listScrollChild:SetHeight(100)
        panels.UpdateListThumb()
        return
    end

    local sorted = addon.VendorData:GetSortedVendors(nil)

    local activeZoneFilter = nil
    if currentZoneOnly then
        local playerZone = GetCurrentPlayerZone()
        activeZoneFilter = playerZone
    elseif zoneFilter then
        activeZoneFilter = zoneFilter
    end

    local filtered = {}
    local term = searchText ~= "" and searchText:lower() or nil
    for _, vendor in ipairs(sorted) do
        local passesZone = true
        if activeZoneFilter then
            passesZone = VendorMatchesZoneFilter(vendor, activeZoneFilter)
        end

        local passesSearch = true
        if term then
            local nameMatch = vendor.name and vendor.name:lower():find(term, 1, true)
            local zoneMatch = false
            if vendor.locations then
                for _, loc in pairs(vendor.locations) do
                    if loc.zone and loc.zone:lower():find(term, 1, true) then
                        zoneMatch = true
                        break
                    end
                end
            end
            local itemMatch = VendorMatchesItemSearch(vendor, term, addon)
            passesSearch = nameMatch or zoneMatch or itemMatch
        end

        if passesZone and passesSearch then
            table.insert(filtered, vendor)
        end
    end

    local stats = addon.VendorData:GetStats()
    if panels.statsText then
        panels.statsText:SetText(string.format(L["VENDORS_STATS"], stats.vendorCount, stats.uniqueItems))
    end

    local totalFiltered = #filtered
    local hasActiveFilter = activeZoneFilter or (searchText ~= "")
    local displayLimit = nil
    if not hasActiveFilter then
        displayLimit = 50
    end
    local displayCount = displayLimit and math.min(totalFiltered, displayLimit) or totalFiltered

    if panels.leftStatusText then
        if displayLimit and totalFiltered > displayLimit then
            panels.leftStatusText:SetText(string.format(L["VENDORS_STATS_SHOWING"], displayCount, totalFiltered))
        else
            panels.leftStatusText:SetText(string.format(L["VENDORS_STATS"], stats.vendorCount, stats.uniqueItems))
        end
    end

    if totalFiltered == 0 then
        panels.emptyList:Show()
        panels.listScrollChild:SetHeight(100)
        panels.UpdateListThumb()
        return
    end

    panels.emptyList:Hide()

    local yOffset = -4
    for i = 1, displayCount do
        local vendor = filtered[i]
        local btn = CreateVendorListEntry(panels.listScrollChild, vendor, yOffset, function(v)
            for _, b in ipairs(vendorListButtons) do
                if b.vendor and b.vendor.npcID == v.npcID then
                    b:SetBackdropColor(T("BG_ACTIVE"))
                else
                    b:SetBackdropColor(T("BG_SECONDARY"))
                end
            end
            ShowVendorDetail(panels, v)
        end)
        table.insert(vendorListButtons, btn)
        yOffset = yOffset - 54
    end

    panels.listScrollChild:SetHeight(math.abs(yOffset) + 10)
    panels.UpdateListThumb()
end

local function CreateSearchableZoneDropdown(parent, dropdown, dropdownText, onSelect)
    dropdown:SetScript("OnClick", function(self)
        if self._menu and self._menu:IsShown() then
            self._menu:Hide()
            return
        end

        local zones = BuildZoneList()

        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        self._menu = menu
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(self:GetWidth() + 20, 314)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        menu:SetBackdropColor(T("BG_SECONDARY"))
        menu:SetBackdropBorderColor(T("BORDER_DEFAULT"))
        menu:EnableMouse(true)

        local searchBox = CreateFrame("EditBox", nil, menu, "BackdropTemplate")
        searchBox:SetSize(menu:GetWidth() - 15, 28)
        searchBox:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
        searchBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        searchBox:SetBackdropColor(T("BG_TERTIARY"))
        searchBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        searchBox:SetFontObject(GameFontHighlight)
        searchBox:SetTextInsets(8, 8, 0, 0)
        searchBox:SetAutoFocus(false)
        searchBox:SetMaxLetters(50)
        searchBox:SetTextColor(T("TEXT_PRIMARY"))
        searchBox:SetScript("OnEditFocusGained", function(s)
            s:SetBackdropBorderColor(T("BORDER_FOCUS"))
        end)
        searchBox:SetScript("OnEditFocusLost", function(s)
            s:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        end)

        local separator = menu:CreateTexture(nil, "ARTWORK")
        separator:SetSize(menu:GetWidth() - 4, 1)
        separator:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -32)
        separator:SetColorTexture(T("BORDER_DEFAULT"))

        local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
        scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -36)
        scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -13, 2)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(scrollFrame:GetWidth())
        scrollFrame:SetScrollChild(scrollChild)

        local scrollBar = CreateFrame("Slider", nil, menu, "BackdropTemplate")
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 1, 0)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 1, 0)
        scrollBar:SetWidth(10)
        scrollBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        scrollBar:SetBackdropColor(T("BG_TERTIARY"))
        scrollBar:SetMinMaxValues(0, 1)
        scrollBar:SetValue(0)
        scrollBar:SetScript("OnValueChanged", function(s, value)
            scrollFrame:SetVerticalScroll(value)
        end)

        local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(8, 30)
        thumb:SetColorTexture(T("ACCENT_PRIMARY"))
        scrollBar:SetThumbTexture(thumb)

        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(sf, direction)
            local current = scrollFrame:GetVerticalScroll()
            local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
            local new = math.max(0, math.min(maxScroll, current - (direction * 28)))
            scrollFrame:SetVerticalScroll(new)
            scrollBar:SetValue(new)
        end)

        local buttons = {}

        local allBtn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        allBtn:SetSize(scrollFrame:GetWidth() - 4, 26)
        allBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        if not zoneFilter then
            allBtn:SetBackdropColor(T("ACCENT_PRIMARY"))
        else
            allBtn:SetBackdropColor(T("BG_TERTIARY"))
        end
        local allTxt = allBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        allTxt:SetPoint("LEFT", allBtn, "LEFT", 8, 0)
        allTxt:SetPoint("RIGHT", allBtn, "RIGHT", -4, 0)
        allTxt:SetJustifyH("LEFT")
        allTxt:SetText(L["VENDORS_ZONE_ALL"])
        allTxt:SetTextColor(T("TEXT_PRIMARY"))
        allBtn.filterKey = L["VENDORS_ZONE_ALL"]:lower()
        allBtn:SetScript("OnEnter", function(b)
            if zoneFilter then
                b:SetBackdropColor(T("BG_HOVER"))
                allTxt:SetTextColor(T("TEXT_ACCENT"))
            end
        end)
        allBtn:SetScript("OnLeave", function(b)
            if zoneFilter then
                b:SetBackdropColor(T("BG_TERTIARY"))
                allTxt:SetTextColor(T("TEXT_PRIMARY"))
            end
        end)
        allBtn:SetScript("OnClick", function()
            menu:Hide()
            onSelect(nil, L["VENDORS_ZONE_ALL"])
        end)
        allBtn:Hide()
        table.insert(buttons, allBtn)

        for _, zone in ipairs(zones) do
            local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            btn:SetSize(scrollFrame:GetWidth() - 4, 26)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            if zoneFilter == zone then
                btn:SetBackdropColor(T("ACCENT_PRIMARY"))
            else
                btn:SetBackdropColor(T("BG_TERTIARY"))
            end

            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            txt:SetPoint("LEFT", btn, "LEFT", 8, 0)
            txt:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
            txt:SetJustifyH("LEFT")
            txt:SetText(zone)
            txt:SetTextColor(T("TEXT_PRIMARY"))

            btn:SetScript("OnEnter", function(b)
                if zoneFilter ~= zone then
                    b:SetBackdropColor(T("BG_HOVER"))
                    txt:SetTextColor(T("TEXT_ACCENT"))
                end
            end)
            btn:SetScript("OnLeave", function(b)
                if zoneFilter ~= zone then
                    b:SetBackdropColor(T("BG_TERTIARY"))
                    txt:SetTextColor(T("TEXT_PRIMARY"))
                end
            end)
            btn:SetScript("OnClick", function()
                menu:Hide()
                onSelect(zone, zone)
            end)

            btn.filterKey = zone:lower()
            btn:Hide()
            table.insert(buttons, btn)
        end

        local function renderList(filter)
            local yPos = -2
            local shown = 0
            for _, btn in ipairs(buttons) do
                if filter == "" or string.find(btn.filterKey, filter, 1, true) then
                    if shown < 20 or filter ~= "" then
                        btn:ClearAllPoints()
                        btn:SetPoint("TOP", scrollChild, "TOP", 0, yPos)
                        btn:Show()
                        yPos = yPos - 28
                        shown = shown + 1
                    else
                        btn:Hide()
                    end
                else
                    btn:Hide()
                end
            end
            local totalH = math.max(28, math.abs(yPos) + 2)
            scrollChild:SetHeight(totalH)
            local maxScroll = math.max(0, totalH - scrollFrame:GetHeight())
            scrollBar:SetMinMaxValues(0, maxScroll)
            scrollFrame:SetVerticalScroll(0)
            scrollBar:SetValue(0)
        end

        renderList("")

        searchBox:SetScript("OnTextChanged", function(s)
            renderList(s:GetText():lower())
        end)
        searchBox:SetScript("OnEscapePressed", function(s)
            if s:GetText() ~= "" then
                s:SetText("")
                renderList("")
            else
                menu:Hide()
            end
        end)

        menu:SetScript("OnShow", function(m)
            local timeOutside = 0
            m:SetScript("OnUpdate", function(m2, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(self) and not searchBox:HasFocus() then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 0.5 then
                        m2:Hide()
                        m2:SetScript("OnUpdate", nil)
                    end
                else
                    timeOutside = 0
                end
            end)
        end)

        menu:Show()
        searchBox:SetFocus()
    end)
end

function ns.UI.CreateVendorsTab(parent)
    local GAP    = ns.Constants.GUI.PANEL_GAP
    local HDR_H  = 42

    local headerBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    headerBar:SetHeight(HDR_H)
    headerBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    headerBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    headerBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    headerBar:SetBackdropColor(T("BG_TERTIARY"))
    headerBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -GAP)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local panels = ns.UI.CreateSplitPanel(contentArea)
    panels.listTitle:SetText(L["VENDORS_LIST_TITLE"])
    panels.detailTitle:SetText(L["VENDORS_DETAIL_TITLE"])

    local searchBox = CreateFrame("EditBox", nil, headerBar, "BackdropTemplate")
    searchBox:SetHeight(26)
    searchBox:SetPoint("TOPLEFT", headerBar, "TOPLEFT", 8, -8)
    searchBox:SetWidth(280)
    searchBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    searchBox:SetBackdropColor(T("BG_SECONDARY"))
    searchBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    searchBox:SetFontObject(GameFontNormal)
    searchBox:SetTextColor(T("TEXT_PRIMARY"))
    searchBox:SetTextInsets(8, 8, 0, 0)
    searchBox:SetAutoFocus(false)

    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
    placeholder:SetText(L["VENDORS_SEARCH"])
    placeholder:SetTextColor(T("TEXT_MUTED"))

    local clearBtn = CreateFrame("Button", nil, headerBar, "BackdropTemplate")
    clearBtn:SetSize(34, 26)
    clearBtn:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)
    clearBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    clearBtn:SetBackdropColor(T("BG_SECONDARY"))
    clearBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    local clearBtnText = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clearBtnText:SetPoint("CENTER")
    clearBtnText:SetText(L["VENDORS_FILTER_CLEAR"])
    clearBtnText:SetTextColor(T("TEXT_PRIMARY"))
    clearBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
        clearBtnText:SetTextColor(T("TEXT_ACCENT"))
    end)
    clearBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        clearBtnText:SetTextColor(T("TEXT_PRIMARY"))
    end)

    local chkBox = CreateFrame("Button", nil, headerBar, "BackdropTemplate")
    chkBox:SetSize(16, 16)
    chkBox:SetPoint("TOPRIGHT", headerBar, "TOPRIGHT", -8, -13)
    chkBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    chkBox:SetBackdropColor(T("BG_SECONDARY"))
    chkBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local chkMark = chkBox:CreateTexture(nil, "OVERLAY")
    chkMark:SetPoint("TOPLEFT", chkBox, "TOPLEFT", 2, -2)
    chkMark:SetPoint("BOTTOMRIGHT", chkBox, "BOTTOMRIGHT", -2, 2)
    chkMark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    chkMark:Hide()
    panels.chkMark = chkMark
    panels.chkBox = chkBox

    local chkLabel = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chkLabel:SetPoint("RIGHT", chkBox, "LEFT", -6, 0)
    chkLabel:SetText(L["VENDORS_ZONE_CURRENT"])
    chkLabel:SetTextColor(T("TEXT_PRIMARY"))

    local zoneDropdown = CreateFrame("Button", nil, headerBar, "BackdropTemplate")
    zoneDropdown:SetHeight(26)
    zoneDropdown:SetWidth(200)
    zoneDropdown:SetPoint("RIGHT", chkLabel, "LEFT", -10, 0)
    zoneDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    zoneDropdown:SetBackdropColor(T("BG_SECONDARY"))
    zoneDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local zoneDropdownText = zoneDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneDropdownText:SetPoint("LEFT", zoneDropdown, "LEFT", 8, 0)
    zoneDropdownText:SetPoint("RIGHT", zoneDropdown, "RIGHT", -20, 0)
    zoneDropdownText:SetJustifyH("LEFT")
    zoneDropdownText:SetWordWrap(false)
    zoneDropdownText:SetText(L["VENDORS_ZONE_ALL"])
    zoneDropdownText:SetTextColor(T("TEXT_PRIMARY"))

    local zoneArrow = zoneDropdown:CreateTexture(nil, "OVERLAY")
    zoneArrow:SetSize(12, 12)
    zoneArrow:SetPoint("RIGHT", zoneDropdown, "RIGHT", -4, 0)
    zoneArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    zoneDropdown:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
    end)
    zoneDropdown:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    CreateSearchableZoneDropdown(headerBar, zoneDropdown, zoneDropdownText, function(zone, text)
        zoneFilter = zone
        zoneDropdownText:SetText(text)
        if zone then
            currentZoneOnly = false
            chkMark:Hide()
            chkBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        end
        RefreshVendorList(panels)
    end)

    chkBox:SetScript("OnClick", function(self)
        currentZoneOnly = not currentZoneOnly
        if currentZoneOnly then
            chkMark:Show()
            self:SetBackdropBorderColor(T("BORDER_FOCUS"))
            zoneFilter = nil
            zoneDropdownText:SetText(L["VENDORS_ZONE_ALL"])
        else
            chkMark:Hide()
            self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        end
        RefreshVendorList(panels)
    end)

    clearBtn:SetScript("OnClick", function()
        searchText = ""
        zoneFilter = nil
        currentZoneOnly = false
        searchBox:SetText("")
        placeholder:Show()
        zoneDropdownText:SetText(L["VENDORS_ZONE_ALL"])
        chkMark:Hide()
        chkBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        RefreshVendorList(panels)
    end)

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text and text ~= "" then
            placeholder:Hide()
        else
            placeholder:Show()
        end
        searchText = text or ""
        if panels._searchTimer then
            panels._searchTimer:Cancel()
        end
        panels._searchTimer = C_Timer.NewTimer(0.3, function()
            RefreshVendorList(panels)
        end)
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    local emptyList = panels.listScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyList:SetPoint("CENTER", panels.listScrollChild, "CENTER", 0, 0)
    emptyList:SetTextColor(T("TEXT_MUTED"))
    panels.emptyList = emptyList

    local emptyDetail = panels.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyDetail:SetPoint("CENTER", panels.detailPanel, "CENTER", 0, 0)
    emptyDetail:SetTextColor(T("TEXT_MUTED"))
    panels.emptyDetail = emptyDetail

    local addon = GetDataAddon()
    if addon then
        emptyList:SetText(L["VENDORS_EMPTY"])
        emptyDetail:SetText(L["VENDORS_SELECT"])
        panels.detailScrollChild:SetHeight(100)

        if addon.RegisterScanCallback then
            addon:RegisterScanCallback(function()
                RefreshVendorList(panels)
            end)
        end

        C_Timer.After(0.5, function()
            RefreshVendorList(panels)
        end)
    else
        emptyList:SetText(L["VENDORS_NO_DATA"])
        emptyDetail:SetText(L["VENDORS_NO_DATA"])
        panels.listScrollChild:SetHeight(100)
        panels.detailScrollChild:SetHeight(100)

        C_Timer.After(2.0, function()
            local retryAddon = GetDataAddon()
            if retryAddon then
                emptyList:SetText(L["VENDORS_EMPTY"])
                emptyDetail:SetText(L["VENDORS_SELECT"])
                if retryAddon.RegisterScanCallback then
                    retryAddon:RegisterScanCallback(function()
                        RefreshVendorList(panels)
                    end)
                end
                RefreshVendorList(panels)
            end
        end)
    end

    ns.UI.vendorsPanels = panels
end
