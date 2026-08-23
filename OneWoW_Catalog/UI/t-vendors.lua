local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_EDGE = OneWoW_GUI.Constants.BACKDROP_EDGE

local ipairs, pairs = ipairs, pairs
local tinsert, sort, wipe, tconcat = tinsert, sort, wipe, table.concat
local C_Item, C_CurrencyInfo, C_Map, C_Timer = C_Item, C_CurrencyInfo, C_Map, C_Timer
local SetPortraitTextureFromCreatureDisplayID = SetPortraitTextureFromCreatureDisplayID
local math = math

local L = ns.L
ns.UI = ns.UI or {}

local selectedVendor = nil
local vendorListAPI = nil
local listResults = {}
local detailElements = {}
local searchText = ""
local zoneFilter = nil
local currentZoneOnly = false
local currencyFilter = nil
local categoryFilter = nil
local pendingFocusNpcID = nil
local RefreshVendorList

-- List card stride includes inter-card gap; measured once so getRowHeight
-- stays cheap for the virtualizer prefix sums.
local VENDOR_CARD_TOP_PAD = 6
local VENDOR_CARD_BOTTOM_PAD = 6
local VENDOR_CARD_ROW_GAP = 2
local VENDOR_CARD_SIDE_PAD = 8
local VENDOR_CARD_FAV_RESERVE = 32
local VENDOR_CARD_GAP = 2
local vendorCardStride = 60
local vendorCardStrideMeasured = false

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

-- List card layout (portrait + 4 text rows):
--   NAME
--   Level | Humanoid
--   Zone | N items
--   Type category
local VENDOR_CARD_PORTRAIT = 40
local VENDOR_CARD_PORTRAIT_GAP = 8
local VENDOR_PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function EnsureVendorCardStride()
    if vendorCardStrideMeasured then
        return vendorCardStride
    end

    local probe = CreateFrame("Frame", nil, UIParent)
    probe:SetSize(1, 1)
    probe:Hide()

    local nameText = OneWoW_GUI:CreateFS(probe, 12)
    nameText:SetText("Ag")
    local metaText = OneWoW_GUI:CreateFS(probe, 11)
    metaText:SetText("Ag")
    local zoneText = OneWoW_GUI:CreateFS(probe, 11)
    zoneText:SetText("Ag")
    local categoryText = OneWoW_GUI:CreateFS(probe, 11)
    categoryText:SetText("Ag")

    local textH =
        VENDOR_CARD_TOP_PAD
        + nameText:GetStringHeight()
        + VENDOR_CARD_ROW_GAP
        + metaText:GetStringHeight()
        + VENDOR_CARD_ROW_GAP
        + zoneText:GetStringHeight()
        + VENDOR_CARD_ROW_GAP
        + categoryText:GetStringHeight()
        + VENDOR_CARD_BOTTOM_PAD

    local portraitH = VENDOR_CARD_TOP_PAD + VENDOR_CARD_PORTRAIT + VENDOR_CARD_BOTTOM_PAD
    vendorCardStride = math.max(textH, portraitH) + VENDOR_CARD_GAP

    probe:SetParent(nil)
    vendorCardStrideMeasured = true
    return vendorCardStride
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
    return OneWoW_CatalogData_Vendors_API
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
    if not addon then return {} end

    local allVendors = addon.GetAllVendors()
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
    if not addon then return {} end

    local allVendors = addon.GetAllVendors()
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
    if not addon then return false end
    for itemID in pairs(vendor.items) do
        local cached = addon.GetCachedItem(itemID)
        if cached and cached.name and cached.name:lower():find(term, 1, true) then
            return true
        end
    end
    return false
end

local function ApplyVendorRowChrome(row, selected, hover)
    ns.CardChrome.ApplyRowChrome(row, {
        selected = selected,
        hover = hover,
        borderKey = row._borderKey,
        fillTheme = row._chromeFill,
    })
end

-- List card layout (portrait + 4 text rows):
--   NAME
--   Level | Humanoid
--   Zone | N items
--   Type category
local function CreateVendorListRow(parent, _)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(EnsureVendorCardStride())
    btn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    ns.CardChrome.Attach(btn, { skipBackground = true })
    ApplyVendorRowChrome(btn, false, false)

    local portrait = btn:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(VENDOR_CARD_PORTRAIT, VENDOR_CARD_PORTRAIT)
    portrait:SetPoint("TOPLEFT", btn, "TOPLEFT", VENDOR_CARD_SIDE_PAD, -VENDOR_CARD_TOP_PAD)
    -- Mask is applied in BindVendorListRow after the portrait/texture is set;
    -- SetPortraitTextureFromCreatureDisplayID on an already-masked placeholder
    -- does not repaint until the row is recreated (/reload).
    btn.portrait = portrait
    btn._portraitDisplayID = nil

    local textLeft = VENDOR_CARD_SIDE_PAD + VENDOR_CARD_PORTRAIT + VENDOR_CARD_PORTRAIT_GAP

    local nameText = OneWoW_GUI:CreateFS(btn, 12)
    nameText:SetPoint("TOPLEFT", btn, "TOPLEFT", textLeft, -VENDOR_CARD_TOP_PAD)
    nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -VENDOR_CARD_FAV_RESERVE, -VENDOR_CARD_TOP_PAD)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    btn.nameText = nameText

    local metaText = OneWoW_GUI:CreateFS(btn, 11)
    metaText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -VENDOR_CARD_ROW_GAP)
    metaText:SetPoint("RIGHT", btn, "RIGHT", -VENDOR_CARD_SIDE_PAD, 0)
    metaText:SetJustifyH("LEFT")
    metaText:SetWordWrap(false)
    btn.metaText = metaText

    local zoneText = OneWoW_GUI:CreateFS(btn, 11)
    zoneText:SetPoint("TOPLEFT", metaText, "BOTTOMLEFT", 0, -VENDOR_CARD_ROW_GAP)
    zoneText:SetPoint("RIGHT", btn, "RIGHT", -VENDOR_CARD_SIDE_PAD, 0)
    zoneText:SetJustifyH("LEFT")
    zoneText:SetWordWrap(false)
    btn.zoneText = zoneText

    local categoryText = OneWoW_GUI:CreateFS(btn, 11)
    categoryText:SetPoint("TOPLEFT", zoneText, "BOTTOMLEFT", 0, -VENDOR_CARD_ROW_GAP)
    categoryText:SetPoint("RIGHT", btn, "RIGHT", -VENDOR_CARD_SIDE_PAD, 0)
    categoryText:SetJustifyH("LEFT")
    categoryText:SetWordWrap(false)
    btn.categoryText = categoryText

    if ns.Favorites then
        local favBtn = OneWoW_GUI:CreateFavoriteToggleButton(btn, {
            size = 20,
            favorite = false,
            tooltipTitle = L["CATALOG_FAVORITE"],
            tooltipText = L["CATALOG_FAVORITE_TT"],
            onClick = function(_, on)
                local vendor = btn.vendor
                if not vendor or not vendor.npcID then
                    return
                end
                ns.Favorites:SetFavorite("vendors", vendor.npcID, on)
                local panels = ns.UI.vendorsPanels
                if panels then
                    RefreshVendorList(panels)
                end
            end,
        })
        favBtn:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -6, -4)
        btn.favBtn = favBtn
    end

    btn:SetScript("OnEnter", function(myself)
        ApplyVendorRowChrome(myself, myself._rowSelected, true)
    end)
    btn:SetScript("OnLeave", function(myself)
        ApplyVendorRowChrome(myself, myself._rowSelected, false)
    end)

    return btn
end

local function ApplyVendorPortrait(row, displayID)
    local tex = row.portrait
    local id = (displayID and displayID > 0) and displayID or nil
    if id and row._portraitDisplayID == id then
        return
    end
    row._portraitDisplayID = id

    -- SetPortraitTextureFromCreatureDisplayID paints a circular RT portrait and
    -- conflicts with Texture:SetMask — masking after it blanks the image until
    -- the row texture is recreated. Do not SetMask on live IDs.
    if id then
        SetPortraitTextureFromCreatureDisplayID(tex, id)
    else
        tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        tex:SetMask(VENDOR_PORTRAIT_MASK)
    end
end

local function BindVendorListRow(row, _, vendor, state)
    row.vendor = vendor
    row._rowSelected = state.selected and true or false
    row._borderKey = ns.CardChrome.VendorBorderKey(vendor)
    ApplyVendorRowChrome(row, row._rowSelected, false)

    ApplyVendorPortrait(row, vendor.displayID)

    if vendor.name and vendor.name ~= "" then
        row.nameText:SetText(vendor.name)
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    else
        row.nameText:SetText("NPC #" .. (vendor.npcID or "?"))
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    local metaParts = {}
    if vendor.level and vendor.level > 0 then
        tinsert(metaParts, LEVEL .. " " .. vendor.level)
    end
    if vendor.creatureType and vendor.creatureType ~= "" then
        tinsert(metaParts, vendor.creatureType)
    end
    if #metaParts > 0 then
        row.metaText:SetText(tconcat(metaParts, " | "))
    else
        row.metaText:SetText("")
    end
    row.metaText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local primaryLoc
    if vendor.locations then
        for _, loc in pairs(vendor.locations) do
            primaryLoc = loc
            break
        end
    end
    local itemCount = 0
    if vendor.items then
        for _ in pairs(vendor.items) do
            itemCount = itemCount + 1
        end
    end
    local zoneLabel = primaryLoc and primaryLoc.zone or L["VENDORS_UNKNOWN_LOCATION"]
    row.zoneText:SetText(zoneLabel .. " | " .. itemCount .. " " .. L["VENDORS_ITEMS_SHORT"])
    row.zoneText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    if vendor.category then
        row.categoryText:SetText(ns.VendorCategories:GetLabel(vendor.category))
        row.categoryText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    else
        row.categoryText:SetText(L["VENDORS_CATEGORY_NONE"])
        row.categoryText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    if row.favBtn and ns.Favorites then
        if vendor.npcID then
            row.favBtn:Show()
            row.favBtn:SetFavorite(ns.Favorites:IsFavorite("vendors", vendor.npcID))
        else
            row.favBtn:Hide()
        end
    end
end

local function ClearDetailElements()
    for _, element in ipairs(detailElements) do
        if element.Hide then element:Hide() end
        if element.SetParent then element:SetParent(nil) end
    end
    wipe(detailElements)
end

-- Detail panel layout uses font-height-driven spacing so larger user font
-- offsets don't cause overlap. Every row advances yOffset by the actual
-- rendered height of its content + ROW_GAP; rows that mix text and a link
-- advance by the larger of the two.
local DETAIL_ROW_GAP = 4

local function StepRow(yOffset, height, gap)
    return yOffset - height - (gap or DETAIL_ROW_GAP)
end

local function BindVendorTypeControls(panels, vendor)
    local typeDropdown = panels.vendorTypeDropdown
    local typeDropdownText = panels.vendorTypeDropdownText
    local typeLabel = panels.vendorTypeLabel
    if not typeDropdown or not typeDropdownText then
        return
    end
    if not vendor then
        typeDropdown:Hide()
        if typeLabel then typeLabel:Hide() end
        return
    end
    if typeLabel then typeLabel:Show() end
    typeDropdown:Show()
    typeDropdownText:SetText(
        vendor.category and ns.VendorCategories:GetLabel(vendor.category)
            or L["VENDORS_CATEGORY_NONE"]
    )
    OneWoW_GUI:AttachFilterMenu(typeDropdown, {
        searchable     = true,
        maxVisible     = 12,
        getActiveValue = function()
            return selectedVendor and selectedVendor.category
        end,
        buildItems = function()
            local items = { { value = nil, text = L["VENDORS_CATEGORY_NONE"] } }
            for _, key in ipairs(ns.VendorCategories:GetSortedKeys()) do
                tinsert(items, { value = key, text = ns.VendorCategories:GetLabel(key) })
            end
            return items
        end,
        onSelect = function(key, text)
            local current = selectedVendor
            if not current then return end
            local addon = GetDataAddon()
            if addon then
                addon.SetCategory(current.npcID, key)
            end
            current.category = key
            typeDropdownText:SetText(text)
            RefreshVendorList(panels)
        end,
    })
end

local function ShowVendorDetail(panels, vendor)
    if not vendor then return end

    selectedVendor = vendor

    if panels.emptyDetail then panels.emptyDetail:Hide() end

    ClearDetailElements()
    BindVendorTypeControls(panels, vendor)

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
    yOffset = StepRow(yOffset, nameHeader:GetStringHeight(), 4)

    if vendor.subtitle and vendor.subtitle ~= "" then
        local subtitleLine = OneWoW_GUI:CreateFS(parent, 12)
        subtitleLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        subtitleLine:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
        subtitleLine:SetJustifyH("LEFT")
        subtitleLine:SetText("<" .. vendor.subtitle .. ">")
        subtitleLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        tinsert(detailElements, subtitleLine)
        yOffset = StepRow(yOffset, subtitleLine:GetStringHeight(), 6)
    else
        yOffset = yOffset - 2
    end

    local infoParts = {}
    tinsert(infoParts, L["VENDORS_NPC_ID"] .. ": " .. (vendor.npcID or "?"))

    local locPinHeight = 0
    if vendor.locations then
        local firstLoc = true
        for mapID, loc in pairs(vendor.locations) do
            local zonePart = loc.zone or ""
            local coordStr = ""
            if loc.x and loc.y and loc.x > 0 then
                coordStr = string.format(" (%.1f, %.1f)", loc.x, loc.y)
            end
            if firstLoc then
                tinsert(infoParts, zonePart .. coordStr)
                firstLoc = false

                local infoLine = OneWoW_GUI:CreateFS(parent, 12)
                infoLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
                infoLine:SetJustifyH("LEFT")
                infoLine:SetText(tconcat(infoParts, "  |  "))
                infoLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                tinsert(detailElements, infoLine)

                local capturedMapID = mapID
                local pinLink = OneWoW_GUI:CreateTextLink(parent, {
                    text = L["VENDORS_WAYPOINT"],
                    fontSize = 11,
                    onClick = function()
                        if addon then
                            addon.CreateWaypoint(vendor, capturedMapID)
                        end
                    end,
                })
                pinLink:SetPoint("LEFT", infoLine, "RIGHT", 8, 0)
                tinsert(detailElements, pinLink)
                locPinHeight = math.max(infoLine:GetStringHeight(), pinLink:GetHeight() or 12)
                yOffset = StepRow(yOffset, locPinHeight)
            else
                local locLine = OneWoW_GUI:CreateFS(parent, 12)
                locLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
                locLine:SetJustifyH("LEFT")
                locLine:SetText(zonePart .. coordStr)
                locLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                tinsert(detailElements, locLine)

                local capturedMapID = mapID
                local pinLink = OneWoW_GUI:CreateTextLink(parent, {
                    text = L["VENDORS_WAYPOINT"],
                    fontSize = 11,
                    onClick = function()
                        if addon then
                            addon.CreateWaypoint(vendor, capturedMapID)
                        end
                    end,
                })
                pinLink:SetPoint("LEFT", locLine, "RIGHT", 8, 0)
                tinsert(detailElements, pinLink)
                yOffset = StepRow(yOffset, math.max(locLine:GetStringHeight(), pinLink:GetHeight() or 12))
            end
        end
    else
        local infoLine = OneWoW_GUI:CreateFS(parent, 12)
        infoLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        infoLine:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
        infoLine:SetJustifyH("LEFT")
        infoLine:SetText(tconcat(infoParts, "  |  "))
        infoLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        tinsert(detailElements, infoLine)
        yOffset = StepRow(yOffset, infoLine:GetStringHeight())
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

    local itemCount = 0
    if vendor.items then
        for _ in pairs(vendor.items) do itemCount = itemCount + 1 end
    end

    yOffset = yOffset - 4
    local itemsDivider = OneWoW_GUI:CreateDivider(parent, { yOffset = yOffset })
    tinsert(detailElements, itemsDivider)
    yOffset = yOffset - 8

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

            local cachedItem = addon and addon.GetCachedItem(itemID)
            if cachedItem and cachedItem.name then
                itemName:SetText(cachedItem.name)
                itemName:SetTextColor(OneWoW_GUI:GetItemQualityColor(cachedItem.quality))
                iconTex:SetTexture(cachedItem.icon)
                iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetItemQualityColor(cachedItem.quality))
            else
                itemName:SetText(L["VENDORS_LOADING"] .. " (" .. itemID .. ")")
                itemName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                iconTex:SetTexture(134400)

                if addon then
                    addon.LoadItemData(itemID, function(_, data)
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
    wipe(listResults)
    EnsureVendorCardStride()

    local addon = GetDataAddon()
    if not addon then
        if panels.emptyList then
            panels.emptyList:Show()
        end
        if vendorListAPI then
            vendorListAPI.SetSelectedIndex(nil)
        end
        return
    end

    local sorted = addon.GetSortedVendors(nil)

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

    local stats = addon.GetStats()
    if panels.statsText then
        panels.statsText:SetText(string.format(L["VENDORS_STATS"], stats.vendorCount, stats.uniqueItems))
    end

    local totalFiltered = #filtered
    local hasActiveFilter = activeZoneFilter or (searchText ~= "") or currencyFilter or categoryFilter

    if panels.leftStatusText then
        if hasActiveFilter then
            panels.leftStatusText:SetText(
                string.format(L["VENDORS_STATS_SHOWING"], totalFiltered, stats.vendorCount)
            )
        else
            panels.leftStatusText:SetText(
                string.format(L["VENDORS_STATS"], stats.vendorCount, stats.uniqueItems)
            )
        end
    end

    if totalFiltered == 0 then
        if panels.emptyList then
            panels.emptyList:Show()
        end
        if vendorListAPI then
            vendorListAPI.SetSelectedIndex(nil)
        end
        return
    end

    if panels.emptyList then
        panels.emptyList:Hide()
    end

    if pendingFocusNpcID then
        local focusVendor
        for _, v in ipairs(filtered) do
            if v.npcID == pendingFocusNpcID then
                focusVendor = v
                break
            end
        end
        if focusVendor then
            tinsert(listResults, focusVendor)
        end
        for _, v in ipairs(filtered) do
            if v.npcID ~= pendingFocusNpcID then
                tinsert(listResults, v)
            end
        end
    else
        for i = 1, totalFiltered do
            listResults[i] = filtered[i]
        end
    end

    local keepNpcID = pendingFocusNpcID or (selectedVendor and selectedVendor.npcID)
    local keepIndex = nil
    if keepNpcID then
        for i, vendor in ipairs(listResults) do
            if vendor.npcID == keepNpcID then
                keepIndex = i
                break
            end
        end
    end

    if vendorListAPI then
        if keepIndex then
            vendorListAPI.SetSelectedIndex(keepIndex)
        else
            vendorListAPI.SetSelectedIndex(nil)
            vendorListAPI.Refresh()
        end
    end
end

local function SelectVendorByNpcID(panels, npcID)
    local addon = GetDataAddon()
    if not addon then return false end

    local vendor = addon.GetVendor(npcID)
    if not vendor then return false end

    pendingFocusNpcID = npcID
    ClearVendorFilters(panels)
    RefreshVendorList(panels)
    pendingFocusNpcID = nil
    return true
end

function ns.UI.OpenToVendor(npcID)
    npcID = tonumber(npcID)
    if not npcID then return end

    local addon = GetDataAddon()
    if not addon then
        ns.pendingVendorSelect = npcID
        return
    end

    if not addon.GetVendor(npcID) then return end

    OneWoW.UI:Show("catalog")
    OneWoW.UI:SelectSubTab("catalog", "vendors")

    local function trySelect()
        local panels = ns.UI.vendorsPanels
        if not panels then
            ns.pendingVendorSelect = npcID
            return false
        end
        ns.pendingVendorSelect = nil
        return SelectVendorByNpcID(panels, npcID)
    end

    if not trySelect() then
        C_Timer.After(0.15, trySelect)
        C_Timer.After(0.35, trySelect)
    end
end

function ns.UI.CreateVendorsTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP    = ns.Constants.GUI.PANEL_GAP
    local HDR_H  = 70  -- two filter rows on the right
    local DD_PAD = 8
    local DD_GAP = 6
    local ROW2_Y = -38

    local leftHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    leftHeader:ClearAllPoints()
    leftHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    leftHeader:SetWidth(LEFT_W)

    local rightHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    rightHeader:ClearAllPoints()
    rightHeader:SetPoint("TOPLEFT", leftHeader, "TOPRIGHT", GAP, 0)
    rightHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -GAP)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local panels = OneWoW_GUI:CreateSplitPanel(contentArea, { hideTitles = true })

    EnsureVendorCardStride()
    vendorListAPI = OneWoW_GUI:CreateVirtualizer(panels.listPanel, {
        name = "CatalogVendorsList",
        rowHeight = vendorCardStride,
        minRowHeight = vendorCardStride,
        numVisibleRows = 14,
        rowInset = 0,
        scrollFrame = panels.listScrollFrame,
        content = panels.listScrollChild,
        getCount = function()
            return #listResults
        end,
        getEntry = function(index)
            return listResults[index]
        end,
        getRowHeight = function(_)
            return EnsureVendorCardStride()
        end,
        onSelect = function(_, vendor)
            if vendor then
                ShowVendorDetail(panels, vendor)
            end
        end,
        createRow = CreateVendorListRow,
        bindRow = BindVendorListRow,
    })
    panels.virtualizedList = vendorListAPI

    local clearBtn = OneWoW_GUI:CreateFitTextButton(leftHeader, { text = L["VENDORS_FILTER_CLEAR"], height = 26, minWidth = 34 })
    clearBtn:SetPoint("TOPRIGHT", leftHeader, "TOPRIGHT", -8, -8)

    local searchBox = OneWoW_GUI:CreateEditBox(leftHeader, {
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
    searchBox:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", -4, 0)
    panels.searchBox = searchBox

    -- Right 2x2: [Currency] [Types] / [Zones] [Current Zone Only]
    local currencyDropdown, currencyDropdownText = OneWoW_GUI:CreateDropdown(rightHeader, {
        width = 10,
        height = 26,
        text = L["VENDORS_CURRENCY_ALL"],
    })
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

    local categoryDropdown, categoryDropdownText = OneWoW_GUI:CreateDropdown(rightHeader, {
        width = 10,
        height = 26,
        text = L["VENDORS_CATEGORY_ALL"],
    })
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

    local zoneDropdown, zoneDropdownText = OneWoW_GUI:CreateDropdown(rightHeader, {
        width = 10,
        height = 26,
        text = L["QUESTS_ZONE_ALL"],
    })
    panels.zoneDropdownText = zoneDropdownText

    local chkBox = OneWoW_GUI:CreateCheckbox(rightHeader, { label = L["VENDORS_ZONE_CURRENT"] })
    panels.zoneCurrentCheckbox = chkBox

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

    local function LayoutRightFilters(w)
        w = w or rightHeader:GetWidth() or 0
        if w < 1 then return end
        local chkGap = OneWoW_GUI:GetSpacing("XS")
        local chkLabelW = chkBox.label:GetStringWidth() or 0
        -- Checkbox frame is just the box; label sits to its right outside the frame.
        local chkInset = chkGap + chkLabelW

        local dropW = math.floor((w - (DD_PAD * 2) - DD_GAP) / 2)

        currencyDropdown:ClearAllPoints()
        currencyDropdown:SetSize(dropW, 26)
        currencyDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD, -8)

        categoryDropdown:ClearAllPoints()
        categoryDropdown:SetSize(dropW, 26)
        categoryDropdown:SetPoint("TOPLEFT", currencyDropdown, "TOPRIGHT", DD_GAP, 0)

        chkBox:ClearAllPoints()
        chkBox:SetPoint("TOPRIGHT", rightHeader, "TOPRIGHT", -DD_PAD - chkInset, ROW2_Y - 3)

        zoneDropdown:ClearAllPoints()
        zoneDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD, ROW2_Y)
        zoneDropdown:SetPoint("RIGHT", chkBox, "LEFT", -10, 0)
        zoneDropdown:SetHeight(26)
    end

    rightHeader:SetScript("OnSizeChanged", function(_, w)
        LayoutRightFilters(w)
    end)
    C_Timer.After(0, function()
        LayoutRightFilters(rightHeader:GetWidth())
    end)

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

    local emptyList = OneWoW_GUI:CreateFS(panels.listScrollFrame, 12)
    emptyList:SetPoint("CENTER", panels.listScrollFrame, "CENTER", 0, 0)
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyList = emptyList

    local emptyDetail = OneWoW_GUI:CreateFS(panels.detailPanel, 12)
    emptyDetail:SetPoint("CENTER", panels.detailPanel, "CENTER", 0, 0)
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyDetail = emptyDetail

    -- Type control stays fixed at the top of the detail panel (Journal difficulty pattern).
    local vendorTypeLabel = OneWoW_GUI:CreateFS(panels.detailPanel, 12)
    vendorTypeLabel:SetText(TYPE .. ":")
    vendorTypeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    vendorTypeLabel:Hide()
    panels.vendorTypeLabel = vendorTypeLabel

    local vendorTypeDropdown, vendorTypeDropdownText = OneWoW_GUI:CreateDropdown(panels.detailPanel, {
        width = 180,
        text = L["VENDORS_CATEGORY_NONE"],
    })
    vendorTypeDropdown:SetPoint("TOPLEFT", panels.detailPanel, "TOPLEFT",
        8 + vendorTypeLabel:GetStringWidth() + 8, -8)
    vendorTypeLabel:SetPoint("RIGHT", vendorTypeDropdown, "LEFT", -6, 0)
    vendorTypeDropdown:Hide()
    panels.vendorTypeDropdown = vendorTypeDropdown
    panels.vendorTypeDropdownText = vendorTypeDropdownText

    panels.detailScrollFrame:ClearAllPoints()
    panels.detailScrollFrame:SetPoint("TOPLEFT", panels.detailPanel, "TOPLEFT", 0, -38)
    panels.detailScrollFrame:SetPoint("BOTTOMRIGHT", panels.detailPanel, "BOTTOMRIGHT", -18, 8)

    -- Start in the no-data state; the data-ready watcher swaps to the live view
    -- once the Vendors data unit's data is queryable. Catch-up covers a tab opened
    -- after data was already ready; the signal covers a mid-session load. The
    -- `wired` guard keeps it idempotent (scan-callback registration is not
    -- dedup-safe, and catch-up + a later signal can both reach the handler).
    emptyList:SetText(L["VENDORS_NO_DATA"])
    emptyDetail:SetText(L["VENDORS_NO_DATA"])
    panels.listScrollChild:SetHeight(100)
    panels.detailScrollChild:SetHeight(100)

    local wired = false
    OneWoW:RegisterDataReadyWatcher("OneWoW_CatalogData_Vendors", function()
        if wired then return end
        local addon = GetDataAddon()
        if not addon then return end
        wired = true
        emptyList:SetText(L["VENDORS_EMPTY"])
        emptyDetail:SetText(L["VENDORS_SELECT"])
        panels.detailScrollChild:SetHeight(100)

        if addon.RegisterScanCallback then
            addon.RegisterScanCallback(function()
                RefreshVendorList(panels)
            end)
        end

        C_Timer.After(0.5, function()
            RefreshVendorList(panels)
        end)
    end)

    ns.UI.vendorsPanels = panels
    ns.UI.RefreshVendorsList = function()
        RefreshVendorList(panels)
    end

    function parent.SelectVendor(npcID)
        ns.UI.OpenToVendor(npcID)
    end

    parent:HookScript("OnShow", function()
        if ns.pendingVendorSelect then
            local id = ns.pendingVendorSelect
            ns.pendingVendorSelect = nil
            C_Timer.After(0.05, function()
                ns.UI.OpenToVendor(id)
            end)
        end
    end)
end
