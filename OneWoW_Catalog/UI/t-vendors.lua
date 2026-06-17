local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_EDGE = OneWoW_GUI.Constants.BACKDROP_EDGE

local ipairs, pairs = ipairs, pairs
local tinsert, sort, tconcat = tinsert, sort, table.concat
local C_Item, C_CurrencyInfo, C_Map, C_Timer = C_Item, C_CurrencyInfo, C_Map, C_Timer

local L = ns.L
ns.UI = ns.UI or {}

local selectedVendor = nil
local vendorListButtons = {}
local detailElements = {}
local searchText = ""
local zoneFilter = nil
local currentZoneOnly = false
local currencyFilter = nil
local categoryFilter = nil
local dataAddon = nil
local pendingFocusNpcID = nil
local RefreshVendorList

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
                name = CURRENCY
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

            tinsert(parts, "x" .. curr.amount .. " " .. iconStr)
        end
        return tconcat(parts, " - ")
    elseif itemData.cost and itemData.cost > 0 then
        return OneWoW.Format.FormatGold(itemData.cost)
    end
    return L["VENDORS_PRICE_UNKNOWN"]
end

local function FormatTimestamp(timestamp)
    if not timestamp then return "" end
    return date("%Y-%m-%d %H:%M", timestamp)
end

local function HighlightVendorListEntry(npcID)
    for _, btn in ipairs(vendorListButtons) do
        if btn.vendor and btn.vendor.npcID == npcID then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end
    end
end

local function ClearVendorFilters(panels)
    searchText = ""
    zoneFilter = nil
    currentZoneOnly = false
    currencyFilter = nil
    categoryFilter = nil
    if not panels then return end
    if panels.searchBox then
        panels.searchBox:SetText("")
    end
    if panels.zoneDropdownText then
        panels.zoneDropdownText:SetText(L["QUESTS_ZONE_ALL"])
    end
    if panels.currencyDropdownText then
        panels.currencyDropdownText:SetText(L["VENDORS_CURRENCY_ALL"])
    end
    if panels.categoryDropdownText then
        panels.categoryDropdownText:SetText(L["VENDORS_CATEGORY_ALL"])
    end
    if panels.zoneCurrentCheckbox then
        panels.zoneCurrentCheckbox:SetChecked(false)
    end
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
        tinsert(zones, zone)
    end
    sort(zones)
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
                                tinsert(currencies, {
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

    sort(currencies, function(a, b) return a.name < b.name end)
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

local UNCATEGORIZED_KEY = "__none__"

local function VendorMatchesCategoryFilter(vendor, filterKey)
    if not filterKey then return true end
    if filterKey == UNCATEGORIZED_KEY then
        return not vendor.category or vendor.category == ""
    end
    return vendor.category == filterKey
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

-- List card layout (3 rows, dynamic heights):
--   Row 1: vendor name (favorite star sits on the right side of this row)
--   Row 2: zone (full width)
--   Row 3: category label (left) | item count (right)
-- Row heights come from FontString:GetStringHeight() after SetText so the card
-- scales correctly when the user runs a larger font size offset.
local function CreateVendorListEntry(parent, vendor, yOffset, panels, onClick)
    local TOP_PAD, BOTTOM_PAD, ROW_GAP = 6, 6, 2
    local SIDE_PAD = 8
    local FAV_RESERVE = 32

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    btn:SetBackdrop(BACKDROP_SIMPLE)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local nameText = OneWoW_GUI:CreateFS(btn, 12)
    nameText:SetPoint("TOPLEFT", btn, "TOPLEFT", SIDE_PAD, -TOP_PAD)
    nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -FAV_RESERVE, -TOP_PAD)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    if vendor.name and vendor.name ~= "" then
        nameText:SetText(vendor.name)
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    else
        nameText:SetText("NPC #" .. (vendor.npcID or "?"))
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    local primaryLoc
    if vendor.locations then
        for _, loc in pairs(vendor.locations) do
            primaryLoc = loc
            break
        end
    end

    local zoneText = OneWoW_GUI:CreateFS(btn, 11)
    zoneText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -ROW_GAP)
    zoneText:SetPoint("RIGHT", btn, "RIGHT", -SIDE_PAD, 0)
    zoneText:SetJustifyH("LEFT")
    zoneText:SetWordWrap(false)
    zoneText:SetText(primaryLoc and primaryLoc.zone or L["VENDORS_UNKNOWN_LOCATION"])
    zoneText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local itemCount = 0
    if vendor.items then
        for _ in pairs(vendor.items) do itemCount = itemCount + 1 end
    end

    local countText = OneWoW_GUI:CreateFS(btn, 11)
    countText:SetPoint("TOPRIGHT", zoneText, "BOTTOMRIGHT", 0, -ROW_GAP)
    countText:SetJustifyH("RIGHT")
    countText:SetWordWrap(false)
    countText:SetText(itemCount .. " " .. L["VENDORS_ITEMS_SHORT"])
    countText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local categoryText = OneWoW_GUI:CreateFS(btn, 11)
    categoryText:SetPoint("TOPLEFT", zoneText, "BOTTOMLEFT", 0, -ROW_GAP)
    categoryText:SetPoint("RIGHT", countText, "LEFT", -8, 0)
    categoryText:SetJustifyH("LEFT")
    categoryText:SetWordWrap(false)
    if vendor.category then
        categoryText:SetText(ns.VendorCategories:GetLabel(vendor.category))
        categoryText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    else
        categoryText:SetText(L["VENDORS_CATEGORY_NONE"])
        categoryText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    local rowH1 = nameText:GetStringHeight()
    local rowH2 = zoneText:GetStringHeight()
    local rowH3 = math.max(categoryText:GetStringHeight(), countText:GetStringHeight())
    local cardH = TOP_PAD + rowH1 + ROW_GAP + rowH2 + ROW_GAP + rowH3 + BOTTOM_PAD
    btn:SetHeight(cardH)

    if ns.Favorites and vendor.npcID then
        local favBtn = OneWoW_GUI:CreateFavoriteToggleButton(btn, {
            size     = 20,
            favorite = ns.Favorites:IsFavorite("vendors", vendor.npcID),
            tooltipTitle = L["CATALOG_FAVORITE"],
            tooltipText  = L["CATALOG_FAVORITE_TT"],
            onClick = function(_, on)
                ns.Favorites:SetFavorite("vendors", vendor.npcID, on)
                RefreshVendorList(panels)
            end,
        })
        favBtn:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -6, -4)
    end

    btn:SetScript("OnEnter", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)
    btn:SetScript("OnLeave", function(myself)
        if selectedVendor and selectedVendor.npcID == vendor.npcID then
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        else
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end
    end)
    btn:SetScript("OnClick", function()
        onClick(vendor)
    end)

    btn.vendor = vendor
    return btn, cardH
end

-- Detail panel layout uses font-height-driven spacing so larger user font
-- offsets don't cause overlap. Every row advances yOffset by the actual
-- rendered height of its content + ROW_GAP; rows that mix text and a fixed
-- widget (location + Pin button, type label + dropdown) advance by the
-- larger of the two.
local DETAIL_ROW_GAP = 4

local function StepRow(yOffset, height, gap)
    return yOffset - height - (gap or DETAIL_ROW_GAP)
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
    if vendor.name and vendor.name ~= "" then
        nameHeader:SetText(vendor.name)
        nameHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    else
        nameHeader:SetText("NPC #" .. (vendor.npcID or "?"))
        nameHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
    tinsert(detailElements, nameHeader)
    yOffset = StepRow(yOffset, nameHeader:GetStringHeight(), 6)

    local infoLine = OneWoW_GUI:CreateFS(parent, 12)
    infoLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    infoLine:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    infoLine:SetJustifyH("LEFT")
    local infoParts = {}
    tinsert(infoParts, L["VENDORS_NPC_ID"] .. ": " .. (vendor.npcID or "?"))
    if vendor.level and vendor.level > 0 then
        tinsert(infoParts, LEVEL .. ": " .. vendor.level)
    end
    if vendor.creatureType and vendor.creatureType ~= "" then
        tinsert(infoParts, vendor.creatureType)
    end
    infoLine:SetText(tconcat(infoParts, "  |  "))
    infoLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    tinsert(detailElements, infoLine)
    yOffset = StepRow(yOffset, infoLine:GetStringHeight())

    -- Type setter row: label + dropdown.
    local typeLabel = OneWoW_GUI:CreateFS(parent, 12)
    typeLabel:SetText(TYPE .. ":")
    typeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    typeLabel:SetJustifyH("LEFT")
    tinsert(detailElements, typeLabel)

    local DROPDOWN_H = 24
    local typeDropdown, typeDropdownText = OneWoW_GUI:CreateDropdown(parent, {
        width  = 220,
        height = DROPDOWN_H,
        text   = vendor.category and ns.VendorCategories:GetLabel(vendor.category)
                                  or L["VENDORS_CATEGORY_NONE"],
    })
    typeDropdown:SetPoint("TOPLEFT", parent, "TOPLEFT",
        10 + typeLabel:GetStringWidth() + 8, yOffset)
    typeLabel:SetPoint("RIGHT", typeDropdown, "LEFT", -6, 0)
    tinsert(detailElements, typeDropdown)

    OneWoW_GUI:AttachFilterMenu(typeDropdown, {
        searchable    = true,
        maxVisible    = 12,
        getActiveValue = function() return vendor.category end,
        buildItems = function()
            local items = { { value = nil, text = L["VENDORS_CATEGORY_NONE"] } }
            for _, key in ipairs(ns.VendorCategories:GetSortedKeys()) do
                tinsert(items, { value = key, text = ns.VendorCategories:GetLabel(key) })
            end
            return items
        end,
        onSelect = function(key, text)
            if addon and addon.VendorData then
                addon.VendorData:SetCategory(vendor.npcID, key)
            end
            vendor.category = key
            typeDropdownText:SetText(text)
            RefreshVendorList(panels)
        end,
    })

    yOffset = StepRow(yOffset, math.max(typeLabel:GetStringHeight(), DROPDOWN_H), 6)

    if vendor.locations then
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
            tinsert(detailElements, locLine)

            local WP_H = 18
            local wpBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = L["VENDORS_WAYPOINT"], height = WP_H, minWidth = 50 })
            wpBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
            tinsert(detailElements, wpBtn)

            local capturedMapID = mapID
            wpBtn:SetScript("OnClick", function()
                if addon and addon.VendorData then
                    addon.VendorData:CreateWaypoint(vendor, capturedMapID)
                end
            end)

            yOffset = StepRow(yOffset, math.max(locLine:GetStringHeight(), WP_H))
        end
    end

    yOffset = yOffset - 4
    local divider = OneWoW_GUI:CreateDivider(parent, { yOffset = yOffset })
    tinsert(detailElements, divider)
    yOffset = yOffset - 8

    local scanInfo = OneWoW_GUI:CreateFS(parent, 10)
    scanInfo:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    scanInfo:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    scanInfo:SetJustifyH("LEFT")
    scanInfo:SetWordWrap(true)
    local scanParts = {}
    if vendor.firstSeen then
        tinsert(scanParts, L["VENDORS_FIRST_SEEN"] .. ": " .. FormatTimestamp(vendor.firstSeen))
    end
    if vendor.lastScanned then
        tinsert(scanParts, L["VENDORS_LAST_SCANNED"] .. ": " .. FormatTimestamp(vendor.lastScanned))
    end
    if vendor.scanCount then
        tinsert(scanParts, L["VENDORS_SCAN_COUNT"] .. ": " .. vendor.scanCount)
    end
    scanInfo:SetText(tconcat(scanParts, "  |  "))
    scanInfo:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    tinsert(detailElements, scanInfo)
    yOffset = StepRow(yOffset, scanInfo:GetStringHeight(), 6)

    local itemsHeader = OneWoW_GUI:CreateFS(parent, 12)
    itemsHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    itemsHeader:SetJustifyH("LEFT")
    local itemCount = 0
    if vendor.items then
        for _ in pairs(vendor.items) do itemCount = itemCount + 1 end
    end
    itemsHeader:SetText(L["VENDORS_ITEM_COUNT"] .. ": " .. itemCount)
    itemsHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    tinsert(detailElements, itemsHeader)
    yOffset = StepRow(yOffset, itemsHeader:GetStringHeight(), 6)

    if panels.rightStatusText then
        panels.rightStatusText:SetText(((vendor.name and vendor.name ~= "") and vendor.name or ("NPC #" .. (vendor.npcID or "?"))) .. " - " .. itemCount .. " " .. L["VENDORS_ITEMS_SHORT"])
    end

    if vendor.items then
        local sortedItems = {}
        for itemID, itemData in pairs(vendor.items) do
            tinsert(sortedItems, { id = itemID, data = itemData })
        end
        sort(sortedItems, function(a, b)
            return (a.data.cost or 0) > (b.data.cost or 0)
        end)

        local ICON_SIZE = 26
        local ITEM_PAD  = 4

        for _, entry in ipairs(sortedItems) do
            local itemID = entry.id
            local itemData = entry.data

            local itemRow = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            itemRow:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
            itemRow:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
            itemRow:SetBackdrop(BACKDROP_SIMPLE)
            itemRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            itemRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            tinsert(detailElements, itemRow)

            local iconFrame = CreateFrame("Frame", nil, itemRow, "BackdropTemplate")
            iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
            iconFrame:SetPoint("LEFT", itemRow, "LEFT", 6, 0)
            iconFrame:SetBackdrop(BACKDROP_EDGE)
            iconFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
            iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            tinsert(detailElements, iconFrame)

            local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
            iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
            iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
            iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            tinsert(detailElements, iconTex)

            local itemName = OneWoW_GUI:CreateFS(itemRow, 12)
            itemName:SetPoint("LEFT", iconFrame, "RIGHT", 8, 0)
            itemName:SetPoint("RIGHT", itemRow, "RIGHT", -150, 0)
            itemName:SetJustifyH("LEFT")
            itemName:SetWordWrap(false)
            tinsert(detailElements, itemName)

            local costText = OneWoW_GUI:CreateFS(itemRow, 10)
            costText:SetPoint("RIGHT", itemRow, "RIGHT", -8, 0)
            costText:SetJustifyH("RIGHT")
            costText:SetText(FormatCost(itemData))
            costText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            tinsert(detailElements, costText)

            if itemData.limited then
                local limitTag = OneWoW_GUI:CreateFS(itemRow, 10)
                limitTag:SetPoint("RIGHT", costText, "LEFT", -6, 0)
                limitTag:SetText("[" .. L["VENDORS_LIMITED"] .. "]")
                limitTag:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
                tinsert(detailElements, limitTag)
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
                    addon.DataLoader:LoadItemData(itemID, function(_, data)
                        if data and itemName:IsVisible() then
                            itemName:SetText(data.name or "")
                            itemName:SetTextColor(OneWoW_GUI:GetItemQualityColor(data.quality))
                            iconTex:SetTexture(data.icon)
                            iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetItemQualityColor(data.quality))
                        end
                    end)
                end
            end

            local rowH = math.max(ICON_SIZE, itemName:GetStringHeight(), costText:GetStringHeight()) + ITEM_PAD * 2
            itemRow:SetHeight(rowH)

            itemRow:EnableMouse(true)
            itemRow:SetScript("OnEnter", function(myself)
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(itemID)
                GameTooltip:Show()
            end)
            itemRow:SetScript("OnLeave", function(myself)
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                GameTooltip:Hide()
            end)

            yOffset = yOffset - rowH - 2
        end
    end

    parent:SetHeight(math.abs(yOffset) + 20)
    panels.UpdateDetailThumb()
end

function RefreshVendorList(panels)
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
        local passesCategory = VendorMatchesCategoryFilter(vendor, categoryFilter)

        if passesZone and passesSearch and passesCurrency and passesCategory then
            tinsert(filtered, vendor)
        end
    end

    if ns.Favorites and #filtered > 0 then
        local origOrder = {}
        for i, v in ipairs(filtered) do
            if v.npcID then origOrder[v.npcID] = i end
        end
        sort(filtered, function(a, b)
            local fa = a.npcID and ns.Favorites:IsFavorite("vendors", a.npcID)
            local fb = b.npcID and ns.Favorites:IsFavorite("vendors", b.npcID)
            if fa ~= fb then return fa end
            return (a.npcID and origOrder[a.npcID] or 0) < (b.npcID and origOrder[b.npcID] or 0)
        end)
    end

    local stats = addon.VendorData:GetStats()
    if panels.statsText then
        panels.statsText:SetText(string.format(L["VENDORS_STATS"], stats.vendorCount, stats.uniqueItems))
    end

    local totalFiltered = #filtered
    local hasActiveFilter = activeZoneFilter or (searchText ~= "") or currencyFilter or categoryFilter
    local displayLimit = nil
    if not hasActiveFilter and not pendingFocusNpcID then
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

    local displayVendors = {}
    if pendingFocusNpcID then
        local focusVendor
        for _, v in ipairs(filtered) do
            if v.npcID == pendingFocusNpcID then
                focusVendor = v
                break
            end
        end
        if focusVendor then
            tinsert(displayVendors, focusVendor)
        end
        local cap = displayLimit or totalFiltered
        for _, v in ipairs(filtered) do
            if v.npcID ~= pendingFocusNpcID then
                tinsert(displayVendors, v)
                if #displayVendors >= cap then break end
            end
        end
    else
        for i = 1, displayCount do
            tinsert(displayVendors, filtered[i])
        end
    end

    local yOffset = -4
    local CARD_GAP = 2
    for _, vendor in ipairs(displayVendors) do
        local btn, cardH = CreateVendorListEntry(panels.listScrollChild, vendor, yOffset, panels, function(v)
            HighlightVendorListEntry(v.npcID)
            ShowVendorDetail(panels, v)
        end)
        tinsert(vendorListButtons, btn)
        yOffset = yOffset - cardH - CARD_GAP
    end

    panels.listScrollChild:SetHeight(math.abs(yOffset) + 10)
    panels.UpdateListThumb()
end

local function SelectVendorByNpcID(panels, npcID)
    local addon = GetDataAddon()
    if not addon or not addon.VendorData then return false end

    local vendor = addon.VendorData:GetAllVendors()[npcID]
    if not vendor then return false end

    pendingFocusNpcID = npcID
    ClearVendorFilters(panels)
    RefreshVendorList(panels)
    ShowVendorDetail(panels, vendor)
    HighlightVendorListEntry(npcID)
    pendingFocusNpcID = nil
    return true
end

function ns.UI.OpenToVendor(npcID)
    npcID = tonumber(npcID)
    if not npcID then return end

    local addon = GetDataAddon()
    if not addon or not addon.VendorData then
        if OneWoW_Catalog then
            OneWoW_Catalog.pendingVendorSelect = npcID
        end
        return
    end

    if not addon.VendorData:GetAllVendors()[npcID] then return end

    if ns.oneWoWHubActive and OneWoW and OneWoW.UI then
        OneWoW.UI:Show("catalog")
        OneWoW.UI:SelectSubTab("catalog", "vendors")
    end

    local function trySelect()
        local panels = ns.UI.vendorsPanels
        if not panels then
            if OneWoW_Catalog then
                OneWoW_Catalog.pendingVendorSelect = npcID
            end
            return false
        end
        if OneWoW_Catalog then
            OneWoW_Catalog.pendingVendorSelect = nil
        end
        return SelectVendorByNpcID(panels, npcID)
    end

    if not trySelect() then
        C_Timer.After(0.15, trySelect)
        C_Timer.After(0.35, trySelect)
    end
end

function ns.UI.CreateVendorsTab(parent)
    local GAP    = ns.Constants.GUI.PANEL_GAP
    local HDR_H  = 42

    local headerBar = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    headerBar:ClearAllPoints()
    headerBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    headerBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -GAP)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local panels = OneWoW_GUI:CreateSplitPanel(contentArea)
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
    panels.searchBox = searchBox

    local clearBtn = OneWoW_GUI:CreateFitTextButton(headerBar, { text = L["VENDORS_FILTER_CLEAR"], height = 26, minWidth = 34 })
    clearBtn:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)

    local chkBox = OneWoW_GUI:CreateCheckbox(headerBar, { label = L["VENDORS_ZONE_CURRENT"] })
    -- CreateCheckbox sizes the frame to just the box; its label fontstring is anchored
    -- LEFT-to-RIGHT outside the frame, so anchoring the box's TOPRIGHT alone leaves the
    -- localized label spilling past the parent. Inset by (label gap + measured label
    -- width) so the entire checkbox+label fits regardless of locale string length.
    local chkLabelGap   = OneWoW_GUI:GetSpacing("XS")
    local chkLabelWidth = chkBox.label:GetStringWidth()
    chkBox:SetPoint("TOPRIGHT", headerBar, "TOPRIGHT", -8 - chkLabelGap - chkLabelWidth, -13)
    panels.zoneCurrentCheckbox = chkBox

    local zoneDropdown, zoneDropdownText = OneWoW_GUI:CreateDropdown(headerBar, {
        width = 200,
        height = 26,
        text = L["QUESTS_ZONE_ALL"],
    })
    zoneDropdown:SetPoint("RIGHT", chkBox, "LEFT", -10, 0)
    panels.zoneDropdownText = zoneDropdownText

    OneWoW_GUI:AttachFilterMenu(zoneDropdown, {
        searchable = true,
        getActiveValue = function() return zoneFilter end,
        buildItems = function()
            local items = {}
            tinsert(items, { value = nil, text = L["QUESTS_ZONE_ALL"] })
            for _, zone in ipairs(BuildZoneList()) do
                tinsert(items, { value = zone, text = zone })
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

    local categoryDropdown, categoryDropdownText = OneWoW_GUI:CreateDropdown(headerBar, {
        width = 180,
        height = 26,
        text = L["VENDORS_CATEGORY_ALL"],
    })
    categoryDropdown:SetPoint("RIGHT", zoneDropdown, "LEFT", -10, 0)
    panels.categoryDropdownText = categoryDropdownText

    OneWoW_GUI:AttachFilterMenu(categoryDropdown, {
        searchable    = true,
        maxVisible    = 12,
        getActiveValue = function() return categoryFilter end,
        buildItems = function()
            local items = {
                { value = nil, text = L["VENDORS_CATEGORY_ALL"] },
                { value = UNCATEGORIZED_KEY, text = L["VENDORS_CATEGORY_NONE"] },
            }
            for _, key in ipairs(ns.VendorCategories:GetSortedKeys()) do
                tinsert(items, { value = key, text = ns.VendorCategories:GetLabel(key) })
            end
            return items
        end,
        onSelect = function(key, text)
            categoryFilter = key
            categoryDropdownText:SetText(text)
            RefreshVendorList(panels)
        end,
    })

    local currencyDropdown, currencyDropdownText = OneWoW_GUI:CreateDropdown(headerBar, {
        width = 200,
        height = 26,
        text = L["VENDORS_CURRENCY_ALL"],
    })
    currencyDropdown:SetPoint("RIGHT", categoryDropdown, "LEFT", -10, 0)
    panels.currencyDropdownText = currencyDropdownText

    OneWoW_GUI:AttachFilterMenu(currencyDropdown, {
        searchable = true,
        maxVisible = 10,
        getActiveValue = function() return currencyFilter end,
        buildItems = function()
            local items = {}
            tinsert(items, { value = nil, text = L["VENDORS_CURRENCY_ALL"] })
            for _, curr in ipairs(BuildCurrencyList()) do
                local currCopy = curr
                tinsert(items, {
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
            zoneDropdownText:SetText(L["QUESTS_ZONE_ALL"])
        end
        RefreshVendorList(panels)
    end)

    clearBtn:SetScript("OnClick", function()
        searchText = ""
        zoneFilter = nil
        currentZoneOnly = false
        currencyFilter = nil
        categoryFilter = nil
        searchBox:SetText(searchBox.placeholderText)
        searchBox:ClearFocus()
        zoneDropdownText:SetText(L["QUESTS_ZONE_ALL"])
        currencyDropdownText:SetText(L["VENDORS_CURRENCY_ALL"])
        categoryDropdownText:SetText(L["VENDORS_CATEGORY_ALL"])
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
    ns.UI.RefreshVendorsList = function()
        RefreshVendorList(panels)
    end

    function parent.SelectVendor(npcID)
        ns.UI.OpenToVendor(npcID)
    end

    parent:HookScript("OnShow", function()
        if OneWoW_Catalog and OneWoW_Catalog.pendingVendorSelect then
            local id = OneWoW_Catalog.pendingVendorSelect
            OneWoW_Catalog.pendingVendorSelect = nil
            C_Timer.After(0.05, function()
                ns.UI.OpenToVendor(id)
            end)
        end
    end)
end
