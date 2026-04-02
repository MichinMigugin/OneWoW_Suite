local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_EDGE = OneWoW_GUI.Constants.BACKDROP_EDGE

ns.UI = ns.UI or {}

local selectedVendor = nil
local vendorListButtons = {}
local detailElements = {}
local searchText = ""
local zoneFilter = nil
local currentZoneOnly = false
local currencyFilter = nil
local dataAddon = nil

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

local function BuildCurrencyList()
    local addon = GetDataAddon()
    if not addon or not addon.VendorData then return {} end

    local allVendors = addon.VendorData:GetAllVendors()
    local seen = {}
    local currencies = {}

    for _, vendor in pairs(allVendors) do
        if vendor.items then
            for _, itemData in pairs(vendor.items) do
                if itemData.currencies then
                    for _, curr in ipairs(itemData.currencies) do
                        local key
                        if curr.currencyID then
                            key = "currency:" .. curr.currencyID
                        elseif curr.itemID then
                            key = "item:" .. curr.itemID
                        end
                        if key and not seen[key] then
                            seen[key] = true
                            local name = curr.name
                            if (not name or name == "") and curr.itemID then
                                name = C_Item.GetItemNameByID(curr.itemID)
                            end
                            if (not name or name == "") and curr.currencyID then
                                local info = C_CurrencyInfo.GetCurrencyInfo(curr.currencyID)
                                name = info and info.name
                            end
                            if name and name ~= "" then
                                table.insert(currencies, {
                                    key = key,
                                    name = name,
                                    currencyID = curr.currencyID,
                                    itemID = curr.itemID,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(currencies, function(a, b) return a.name < b.name end)
    return currencies
end

local function VendorMatchesCurrencyFilter(vendor, filter)
    if not filter then return true end
    if not vendor or not vendor.items then return false end
    for _, itemData in pairs(vendor.items) do
        if itemData.currencies then
            for _, curr in ipairs(itemData.currencies) do
                local key
                if curr.currencyID then
                    key = "currency:" .. curr.currencyID
                elseif curr.itemID then
                    key = "item:" .. curr.itemID
                end
                if key == filter then return true end
            end
        end
    end
    return false
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
    btn:SetBackdrop(BACKDROP_SIMPLE)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))

    local nameText = OneWoW_GUI:CreateFS(btn, 12)
    nameText:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -6)
    nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -8, -6)
    nameText:SetJustifyH("LEFT")
    if vendor.name then
        nameText:SetText(vendor.name)
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    else
        nameText:SetText("NPC #" .. (vendor.npcID or "?"))
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    local mapID, location = nil, nil
    if vendor.locations then
        for mID, loc in pairs(vendor.locations) do
            mapID = mID
            location = loc
            break
        end
    end

    local infoText = OneWoW_GUI:CreateFS(btn, 10)
    infoText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    infoText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -8, 0)
    infoText:SetJustifyH("LEFT")

    local zone = location and location.zone or L["VENDORS_UNKNOWN_LOCATION"]
    local itemCount = 0
    if vendor.items then
        for _ in pairs(vendor.items) do itemCount = itemCount + 1 end
    end
    infoText:SetText(zone .. "  |  " .. itemCount .. " " .. L["VENDORS_ITEMS_SHORT"])
    infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local scanText = OneWoW_GUI:CreateFS(btn, 10)
    scanText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 8, 5)
    scanText:SetJustifyH("LEFT")
    if vendor.lastScanned then
        scanText:SetText(FormatTimestamp(vendor.lastScanned))
    end
    scanText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
    end)
    btn:SetScript("OnLeave", function(self)
        if selectedVendor and selectedVendor.npcID == vendor.npcID then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
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

    local nameHeader = OneWoW_GUI:CreateFS(parent, 16)
    nameHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    nameHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    nameHeader:SetJustifyH("LEFT")
    if vendor.name then
        nameHeader:SetText(vendor.name)
        nameHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    else
        nameHeader:SetText("NPC #" .. (vendor.npcID or "?"))
        nameHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
    table.insert(detailElements, nameHeader)
    yOffset = yOffset - 22

    local infoLine = OneWoW_GUI:CreateFS(parent, 12)
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
    infoLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    table.insert(detailElements, infoLine)
    yOffset = yOffset - 18

    if vendor.locations then
        local locCount = 0
        for _ in pairs(vendor.locations) do locCount = locCount + 1 end

        for mapID, loc in pairs(vendor.locations) do
            local locLine = OneWoW_GUI:CreateFS(parent, 12)
            locLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
            locLine:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -60, yOffset)
            locLine:SetJustifyH("LEFT")
            local coordStr = ""
            if loc.x and loc.y and loc.x > 0 then
                coordStr = string.format(" (%.1f, %.1f)", loc.x, loc.y)
            end
            locLine:SetText(L["VENDORS_LOCATION"] .. ": " .. (loc.zone or "") .. coordStr)
            locLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            table.insert(detailElements, locLine)

            local wpBtn = OneWoW_GUI:CreateButton(parent, { text = L["VENDORS_WAYPOINT"], width = 50, height = 16 })
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
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    table.insert(detailElements, divider)
    yOffset = yOffset - 8

    local scanInfo = OneWoW_GUI:CreateFS(parent, 10)
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
    scanInfo:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    table.insert(detailElements, scanInfo)
    yOffset = yOffset - 20

    local itemsHeader = OneWoW_GUI:CreateFS(parent, 12)
    itemsHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    itemsHeader:SetJustifyH("LEFT")
    local itemCount = 0
    if vendor.items then
        for _ in pairs(vendor.items) do itemCount = itemCount + 1 end
    end
    itemsHeader:SetText(L["VENDORS_ITEM_COUNT"] .. ": " .. itemCount)
    itemsHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
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
            itemRow:SetBackdrop(BACKDROP_SIMPLE)
            itemRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            table.insert(detailElements, itemRow)

            local iconFrame = CreateFrame("Frame", nil, itemRow, "BackdropTemplate")
            iconFrame:SetSize(26, 26)
            iconFrame:SetPoint("LEFT", itemRow, "LEFT", 6, 0)
            iconFrame:SetBackdrop(BACKDROP_EDGE)
            iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            table.insert(detailElements, iconFrame)

            local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
            iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
            iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
            iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            table.insert(detailElements, iconTex)

            local itemName = OneWoW_GUI:CreateFS(itemRow, 12)
            itemName:SetPoint("LEFT", iconFrame, "RIGHT", 8, 0)
            itemName:SetPoint("RIGHT", itemRow, "RIGHT", -150, 0)
            itemName:SetJustifyH("LEFT")
            itemName:SetWordWrap(false)
            table.insert(detailElements, itemName)

            local costText = OneWoW_GUI:CreateFS(itemRow, 10)
            costText:SetPoint("RIGHT", itemRow, "RIGHT", -8, 0)
            costText:SetJustifyH("RIGHT")
            costText:SetText(FormatCost(itemData))
            costText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            table.insert(detailElements, costText)

            if itemData.limited then
                local limitTag = OneWoW_GUI:CreateFS(itemRow, 10)
                limitTag:SetPoint("RIGHT", costText, "LEFT", -6, 0)
                limitTag:SetText("[" .. L["VENDORS_LIMITED"] .. "]")
                limitTag:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
                table.insert(detailElements, limitTag)
            end

            local cachedItem = addon and addon.DataLoader and addon.DataLoader:GetCachedItem(itemID)
            if cachedItem and cachedItem.name then
                itemName:SetText(cachedItem.name)
                itemName:SetTextColor(OneWoW_GUI:GetItemQualityColor(cachedItem.quality))
                iconTex:SetTexture(cachedItem.icon)
                iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetItemQualityColor(cachedItem.quality))
            else
                itemName:SetText(L["VENDORS_LOADING"] .. " (" .. itemID .. ")")
                itemName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                iconTex:SetTexture(134400)

                if addon and addon.DataLoader then
                    addon.DataLoader:LoadItemData(itemID, function(loadedID, data)
                        if data and itemName:IsVisible() then
                            itemName:SetText(data.name or "")
                            itemName:SetTextColor(OneWoW_GUI:GetItemQualityColor(data.quality))
                            iconTex:SetTexture(data.icon)
                            iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetItemQualityColor(data.quality))
                        end
                    end)
                end
            end

            itemRow:EnableMouse(true)
            itemRow:SetScript("OnEnter", function(self)
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(itemID)
                GameTooltip:Show()
            end)
            itemRow:SetScript("OnLeave", function(self)
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
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

        local passesCurrency = VendorMatchesCurrencyFilter(vendor, currencyFilter)

        if passesZone and passesSearch and passesCurrency then
            table.insert(filtered, vendor)
        end
    end

    local stats = addon.VendorData:GetStats()
    if panels.statsText then
        panels.statsText:SetText(string.format(L["VENDORS_STATS"], stats.vendorCount, stats.uniqueItems))
    end

    local totalFiltered = #filtered
    local hasActiveFilter = activeZoneFilter or (searchText ~= "") or currencyFilter
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
                    b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                else
                    b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
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

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

function ns.UI.CreateVendorsTab(parent)
    local GAP    = ns.Constants.GUI.PANEL_GAP
    local HDR_H  = 42

    local headerBar = ns.UI.CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    headerBar:ClearAllPoints()
    headerBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    headerBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -GAP)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local panels = ns.UI.CreateSplitPanel(contentArea)
    panels.listTitle:SetText(L["VENDORS_LIST_TITLE"])
    panels.detailTitle:SetText(L["VENDORS_DETAIL_TITLE"])

    local searchBox = OneWoW_GUI:CreateEditBox(headerBar, {
        width = 280,
        height = 26,
        placeholderText = L["VENDORS_SEARCH"],
        onTextChanged = function(text)
            searchText = text
            if panels._searchTimer then panels._searchTimer:Cancel() end
            panels._searchTimer = C_Timer.NewTimer(0.3, function()
                RefreshVendorList(panels)
            end)
        end,
    })
    searchBox:SetPoint("TOPLEFT", headerBar, "TOPLEFT", 8, -8)

    local clearBtn = OneWoW_GUI:CreateFitTextButton(headerBar, { text = L["VENDORS_FILTER_CLEAR"], height = 26, minWidth = 34 })
    clearBtn:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)

    local chkBox = OneWoW_GUI:CreateCheckbox(headerBar, { label = L["VENDORS_ZONE_CURRENT"] })
    chkBox:SetPoint("TOPRIGHT", headerBar, "TOPRIGHT", -8, -13)

    local zoneDropdown, zoneDropdownText = OneWoW_GUI:CreateDropdown(headerBar, {
        width = 200,
        height = 26,
        text = L["VENDORS_ZONE_ALL"],
    })
    zoneDropdown:SetPoint("RIGHT", chkBox, "LEFT", -10, 0)

    OneWoW_GUI:AttachFilterMenu(zoneDropdown, {
        searchable = true,
        getActiveValue = function() return zoneFilter end,
        buildItems = function()
            local items = {}
            table.insert(items, { value = nil, text = L["VENDORS_ZONE_ALL"] })
            for _, zone in ipairs(BuildZoneList()) do
                table.insert(items, { value = zone, text = zone })
            end
            return items
        end,
        onSelect = function(zone, text)
            zoneFilter = zone
            zoneDropdownText:SetText(text)
            if zone then
                currentZoneOnly = false
                chkBox:SetChecked(false)
            end
            RefreshVendorList(panels)
        end,
    })

    local currencyDropdown, currencyDropdownText = OneWoW_GUI:CreateDropdown(headerBar, {
        width = 200,
        height = 26,
        text = L["VENDORS_CURRENCY_ALL"],
    })
    currencyDropdown:SetPoint("RIGHT", zoneDropdown, "LEFT", -10, 0)

    OneWoW_GUI:AttachFilterMenu(currencyDropdown, {
        searchable = true,
        maxVisible = 10,
        getActiveValue = function() return currencyFilter end,
        buildItems = function()
            local items = {}
            table.insert(items, { value = nil, text = L["VENDORS_CURRENCY_ALL"] })
            for _, curr in ipairs(BuildCurrencyList()) do
                local currCopy = curr
                table.insert(items, {
                    value = currCopy.key,
                    text = currCopy.name,
                    onEnter = function(btn)
                        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                        if currCopy.itemID then
                            GameTooltip:SetItemByID(currCopy.itemID)
                        elseif currCopy.currencyID then
                            GameTooltip:SetHyperlink("currency:" .. currCopy.currencyID)
                        end
                        GameTooltip:Show()
                    end,
                    onLeave = function()
                        GameTooltip:Hide()
                    end,
                })
            end
            return items
        end,
        onSelect = function(key, text)
            currencyFilter = key
            currencyDropdownText:SetText(text)
            RefreshVendorList(panels)
        end,
    })

    chkBox:HookScript("OnClick", function(self)
        currentZoneOnly = self:GetChecked()
        if currentZoneOnly then
            zoneFilter = nil
            zoneDropdownText:SetText(L["VENDORS_ZONE_ALL"])
        end
        RefreshVendorList(panels)
    end)

    clearBtn:SetScript("OnClick", function()
        searchText = ""
        zoneFilter = nil
        currentZoneOnly = false
        currencyFilter = nil
        searchBox:SetText(searchBox.placeholderText)
        searchBox:ClearFocus()
        zoneDropdownText:SetText(L["VENDORS_ZONE_ALL"])
        currencyDropdownText:SetText(L["VENDORS_CURRENCY_ALL"])
        chkBox:SetChecked(false)
        RefreshVendorList(panels)
    end)

    local emptyList = OneWoW_GUI:CreateFS(panels.listScrollChild, 12)
    emptyList:SetPoint("CENTER", panels.listScrollChild, "CENTER", 0, 0)
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyList = emptyList

    local emptyDetail = OneWoW_GUI:CreateFS(panels.detailPanel, 12)
    emptyDetail:SetPoint("CENTER", panels.detailPanel, "CENTER", 0, 0)
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
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
