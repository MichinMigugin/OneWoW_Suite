-- OneWoW Addon File
-- OneWoW_Catalog/UI/t-itemsearch.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

ns.UI = ns.UI or {}

local selectedItem   = nil
local currentSearch  = ""
local currentSource  = "all"
local panels         = nil
local listElements   = {}
local detailElements = {}
local sourceButtons  = {}
local searchBox      = nil
local emptyList      = nil
local emptyDetail    = nil
local searchTimer    = nil

local ITEM_ROW_HEIGHT  = 30
local SOURCE_BTN_H     = 22
local SOURCE_BTN_PAD_X = 10
local SOURCE_BTN_GAP   = 3
local HEADER_H         = 58

local QUALITY_COLORS = ns.Constants.QUALITY_COLORS

local SOURCE_DEFS = {
    { key = "all",     labelKey = "TT_IS_FILTER_ALL",     descKey = "TT_IS_FILTER_ALL_DESC"     },
    { key = "drops",   labelKey = "TT_IS_FILTER_DROPS",   descKey = "TT_IS_FILTER_DROPS_DESC"   },
    { key = "vendors", labelKey = "TT_IS_FILTER_VENDORS", descKey = "TT_IS_FILTER_VENDORS_DESC" },
    { key = "crafted", labelKey = "TT_IS_FILTER_CRAFTED", descKey = "TT_IS_FILTER_CRAFTED_DESC" },
    { key = "owned",   labelKey = "TT_IS_FILTER_OWNED",   descKey = "TT_IS_FILTER_OWNED_DESC"   },
}

local RefreshItemList
local ShowItemDetail

local function ClearListElements()
    for _, el in ipairs(listElements) do
        if el.Hide then el:Hide() end
        if el.SetParent then el:SetParent(nil) end
    end
    wipe(listElements)
end

local function ClearDetailElements()
    for _, el in ipairs(detailElements) do
        if el.Hide then el:Hide() end
        if el.SetParent then el:SetParent(nil) end
    end
    wipe(detailElements)
end

local function UpdateSourceButtonStates()
    for _, btn in ipairs(sourceButtons) do
        if btn.sourceKey == currentSource then
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn.highlight:Show()
        else
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            btn.highlight:Hide()
        end
    end
end

local function CreateSourceButton(parent, def)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(SOURCE_BTN_H)
    btn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(L[def.labelKey])
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local textWidth = label:GetStringWidth()
    btn:SetWidth(math.max(36, textWidth + SOURCE_BTN_PAD_X * 2))

    btn.label     = label
    btn.sourceKey = def.key

    btn.highlight = btn:CreateTexture(nil, "OVERLAY")
    btn.highlight:SetAllPoints()
    btn.highlight:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    btn.highlight:SetAlpha(0.15)
    btn.highlight:Hide()

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L[def.labelKey], 1, 1, 1)
        GameTooltip:AddLine(L[def.descKey], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        if self.sourceKey == currentSource then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        end
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self)
        currentSource = self.sourceKey
        selectedItem  = nil
        UpdateSourceButtonStates()
        ClearDetailElements()
        if emptyDetail then
            emptyDetail:SetText(L["ITEMSEARCH_SELECT"])
            emptyDetail:Show()
        end
        RefreshItemList()
    end)

    return btn
end

local function CreateItemRow(parent, result, yOffset, rowIdx, onClick)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(ITEM_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    row:SetBackdrop(BACKDROP_SIMPLE)

    if rowIdx % 2 == 0 then
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    else
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    end

    local iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
    iconFrame:SetSize(22, 22)
    iconFrame:SetPoint("LEFT", 4, 0)
    iconFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    iconFrame:SetBackdropColor(0, 0, 0, 1)
    iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    if result.icon then
        icon:SetTexture(result.icon)
    else
        icon:SetTexture(134400)
        local tsAddon = ns.Catalog and ns.Catalog:GetDataAddon("tradeskills")
        if tsAddon and tsAddon.DataLoader then
            tsAddon.DataLoader:LoadItemData(result.itemID, function(itemID, itemData)
                if row:IsVisible() and itemData and itemData.icon then
                    icon:SetTexture(itemData.icon)
                end
            end)
        end
    end

    local hasOwned        = result.ownedCount and result.ownedCount > 0
    local nameRightOffset = hasOwned and -42 or -6

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", nameRightOffset, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(result.name or ("Item #" .. result.itemID))

    local qc = QUALITY_COLORS[result.quality] or QUALITY_COLORS[1]
    nameText:SetTextColor(unpack(qc))

    if hasOwned then
        local badge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        badge:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        badge:SetText("x" .. result.ownedCount)
        badge:SetTextColor(0.2, 0.9, 0.2, 1.0)
    end

    row.result = result
    row.rowIdx = rowIdx

    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(result.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        if selectedItem and selectedItem.itemID == result.itemID then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        elseif self.rowIdx % 2 == 0 then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        end
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self)
        if onClick then onClick(self.result) end
    end)

    return row
end

ShowItemDetail = function(result)
    if not panels or not result then return end

    selectedItem = result
    ClearDetailElements()
    if emptyDetail then emptyDetail:Hide() end

    local child   = panels.detailScrollChild
    local yOffset = -8

    local headerFrame = CreateFrame("Frame", nil, child, "BackdropTemplate")
    headerFrame:SetHeight(50)
    headerFrame:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
    headerFrame:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
    headerFrame:SetBackdrop(BACKDROP_SIMPLE)
    headerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    table.insert(detailElements, headerFrame)

    local hIconFrame = CreateFrame("Button", nil, headerFrame, "BackdropTemplate")
    hIconFrame:SetSize(40, 40)
    hIconFrame:SetPoint("LEFT", 8, 0)
    hIconFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    hIconFrame:SetBackdropColor(0, 0, 0, 1)
    hIconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local hIcon = hIconFrame:CreateTexture(nil, "ARTWORK")
    hIcon:SetPoint("TOPLEFT", 1, -1)
    hIcon:SetPoint("BOTTOMRIGHT", -1, 1)
    hIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    hIcon:SetTexture(result.icon or 134400)

    hIconFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(result.itemID)
        GameTooltip:Show()
    end)
    hIconFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local itemName = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    itemName:SetPoint("TOPLEFT", hIconFrame, "TOPRIGHT", 8, -2)
    itemName:SetPoint("RIGHT", headerFrame, "RIGHT", -8, 0)
    itemName:SetJustifyH("LEFT")
    itemName:SetWordWrap(false)
    itemName:SetText(result.name or ("Item #" .. result.itemID))

    local qc = QUALITY_COLORS[result.quality] or QUALITY_COLORS[1]
    itemName:SetTextColor(unpack(qc))

    local itemIDText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemIDText:SetPoint("TOPLEFT", itemName, "BOTTOMLEFT", 0, -2)
    itemIDText:SetText(L["ITEMSEARCH_ITEM_ID"] .. ": " .. result.itemID)
    itemIDText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 58

    local detail = ns.ItemSearch and ns.ItemSearch:GetDetail(result.itemID)
        or { drops = {}, vendors = {}, crafted = {}, owned = {} }

    local function AddSectionHeader(titleKey)
        local sec = CreateFrame("Frame", nil, child, "BackdropTemplate")
        sec:SetHeight(24)
        sec:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
        sec:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
        sec:SetBackdrop(BACKDROP_SIMPLE)
        sec:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        table.insert(detailElements, sec)

        local title = sec:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("LEFT", 8, 0)
        title:SetText(L[titleKey])
        title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        yOffset = yOffset - 28
    end

    local function AddTextRow(text, indent, colorKey)
        local r = CreateFrame("Frame", nil, child)
        r:SetHeight(18)
        r:SetPoint("TOPLEFT", child, "TOPLEFT", indent or 12, yOffset)
        r:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
        table.insert(detailElements, r)

        local fs = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", 0, 0)
        fs:SetText(text)
        fs:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey or "TEXT_PRIMARY"))

        yOffset = yOffset - 18
    end

    AddSectionHeader("ITEMSEARCH_SECTION_DROPS")
    if #detail.drops > 0 then
        for _, drop in ipairs(detail.drops) do
            local line = drop.instanceName or ""
            if drop.encounterName then
                line = line .. "  -  " .. drop.encounterName
            end
            AddTextRow(line, 12, "TEXT_PRIMARY")
        end
    else
        AddTextRow(L["ITEMSEARCH_NO_DROPS"], 12, "TEXT_MUTED")
    end

    yOffset = yOffset - 6

    AddSectionHeader("ITEMSEARCH_SECTION_VENDORS")
    if #detail.vendors > 0 then
        for _, v in ipairs(detail.vendors) do
            local line = v.name or L["VENDORS_UNKNOWN"]
            if v.zone and v.zone ~= "" then
                line = line .. "  (" .. v.zone .. ")"
            end
            AddTextRow(line, 12, "TEXT_PRIMARY")
        end
    else
        AddTextRow(L["ITEMSEARCH_NO_VENDORS"], 12, "TEXT_MUTED")
    end

    yOffset = yOffset - 6

    AddSectionHeader("ITEMSEARCH_SECTION_CRAFTED")
    if #detail.crafted > 0 then
        for _, c in ipairs(detail.crafted) do
            AddTextRow(c.profName or "", 12, "TEXT_PRIMARY")
            if c.knownBy and #c.knownBy > 0 then
                for _, charKey in ipairs(c.knownBy) do
                    AddTextRow(charKey, 24, "TEXT_SECONDARY")
                end
            else
                AddTextRow(L["TRADESKILLS_NOT_SCANNED"], 24, "TEXT_MUTED")
            end
        end
    else
        AddTextRow(L["ITEMSEARCH_NO_CRAFTED"], 12, "TEXT_MUTED")
    end

    yOffset = yOffset - 6

    local locLabels = {
        bags    = L["ITEMSEARCH_LOC_BAGS"],
        bank    = L["ITEMSEARCH_LOC_BANK"],
        mail    = L["ITEMSEARCH_LOC_MAIL"],
        warband = L["ITEMSEARCH_LOC_WARBAND"],
        guild   = L["ITEMSEARCH_LOC_GUILD"],
        ah      = L["ITEMSEARCH_LOC_AH"],
    }

    AddSectionHeader("ITEMSEARCH_SECTION_INVENTORY")
    if #detail.owned > 0 then
        for _, owned in ipairs(detail.owned) do
            local locLabel = locLabels[owned.locLabel] or owned.locLabel
            local line = owned.charName .. "  -  " .. locLabel .. "  x" .. owned.count
            AddTextRow(line, 12, "TEXT_PRIMARY")
        end
    else
        AddTextRow(L["ITEMSEARCH_NO_INVENTORY"], 12, "TEXT_MUTED")
    end

    yOffset = yOffset - 10
    child:SetHeight(math.abs(yOffset) + 20)
end

RefreshItemList = function()
    if not panels then return end
    ClearListElements()
    panels.listScrollFrame:SetVerticalScroll(0)

    if not ns.ItemSearch then
        panels.listScrollChild:SetHeight(100)
        if emptyList then emptyList:SetText(L["ITEMSEARCH_EMPTY"]); emptyList:Show() end
        return
    end

    local results, limitReached

    if currentSearch == "" or #currentSearch < 2 then
        results = ns.ItemSearch:GetDefaultItems(50)
        limitReached = false
        if not results or #results == 0 then
            panels.listScrollChild:SetHeight(100)
            if emptyList then emptyList:SetText(L["ITEMSEARCH_EMPTY"]); emptyList:Show() end
            if panels.leftStatusText then panels.leftStatusText:SetText("") end
            return
        end
    else
        results, limitReached = ns.ItemSearch:Query(currentSearch, currentSource)
        if not results or #results == 0 then
            panels.listScrollChild:SetHeight(100)
            if emptyList then emptyList:SetText(L["ITEMSEARCH_NO_RESULTS"]); emptyList:Show() end
            if panels.leftStatusText then panels.leftStatusText:SetText("") end
            return
        end
    end

    if emptyList then emptyList:Hide() end

    local yOffset = -4
    local rowIdx  = 0

    for _, result in ipairs(results) do
        local row = CreateItemRow(panels.listScrollChild, result, yOffset, rowIdx, function(r)
            selectedItem = r
            for _, el in ipairs(listElements) do
                if el.result and el.result.itemID == r.itemID then
                    el:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                elseif el.rowIdx and el.rowIdx % 2 == 0 then
                    el:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                else
                    el:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                end
            end
            ShowItemDetail(r)
        end)
        table.insert(listElements, row)
        yOffset = yOffset - ITEM_ROW_HEIGHT
        rowIdx  = rowIdx + 1
    end

    panels.listScrollChild:SetHeight(math.abs(yOffset) + 10)

    if panels.leftStatusText then
        local n = #results
        if currentSearch == "" or #currentSearch < 2 then
            panels.leftStatusText:SetText(string.format(L["ITEMSEARCH_BROWSE_DEFAULT"], n))
        elseif limitReached then
            panels.leftStatusText:SetText(string.format(L["ITEMSEARCH_RESULTS_CAPPED"], n))
        else
            panels.leftStatusText:SetText(string.format(L["ITEMSEARCH_RESULTS"], n))
        end
    end
end

function ns.UI.CreateItemSearchTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP    = ns.Constants.GUI.PANEL_GAP

    local searchHeader = ns.UI.CreateFilterBar(parent, { height = HEADER_H, offset = 0 })
    searchHeader:ClearAllPoints()
    searchHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    searchHeader:SetWidth(LEFT_W)

    local filterHeader = ns.UI.CreateFilterBar(parent, { height = HEADER_H, offset = 0 })
    filterHeader:ClearAllPoints()
    filterHeader:SetPoint("TOPLEFT", searchHeader, "TOPRIGHT", GAP, 0)
    filterHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local noticeBar = ns.UI.CreateFilterBar(parent, { height = 28, offset = 0 })
    noticeBar:ClearAllPoints()
    noticeBar:SetPoint("TOPLEFT", searchHeader, "BOTTOMLEFT", 0, -2)
    noticeBar:SetPoint("TOPRIGHT", filterHeader, "BOTTOMRIGHT", 0, -2)

    local noticeText = noticeBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noticeText:SetPoint("LEFT", noticeBar, "LEFT", 12, 0)
    noticeText:SetPoint("RIGHT", noticeBar, "RIGHT", -12, 0)
    noticeText:SetJustifyH("LEFT")
    noticeText:SetWordWrap(true)
    noticeText:SetText(L["ITEMSEARCH_NOTICE"])
    noticeText:SetTextColor(1, 0.2, 0.2)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", noticeBar, "BOTTOMLEFT", 0, -2)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    panels = ns.UI.CreateSplitPanel(contentArea)
    panels.listTitle:SetText(L["ITEMSEARCH_LIST_TITLE"])
    panels.detailTitle:SetText(L["ITEMSEARCH_DETAIL_TITLE"])

    for _, def in ipairs(SOURCE_DEFS) do
        local btn = CreateSourceButton(filterHeader, def)
        table.insert(sourceButtons, btn)
    end

    local containerWidth = filterHeader:GetWidth()
    if containerWidth < 100 then containerWidth = 900 end
    local padLeft = 6
    local padTop  = 5
    local xOff    = padLeft
    local btnRow  = 0
    for _, btn in ipairs(sourceButtons) do
        local btnWidth = btn:GetWidth()
        if xOff + btnWidth + SOURCE_BTN_GAP > containerWidth - padLeft and xOff > padLeft then
            btnRow = btnRow + 1
            xOff   = padLeft
        end
        local yOff = -padTop - (btnRow * (SOURCE_BTN_H + SOURCE_BTN_GAP))
        btn:SetPoint("TOPLEFT", filterHeader, "TOPLEFT", xOff, yOff)
        xOff = xOff + btnWidth + SOURCE_BTN_GAP
    end

    searchBox = OneWoW_GUI:CreateEditBox(searchHeader, {
        height = 26,
        maxLetters = 50,
        placeholderText = L["ITEMSEARCH_PLACEHOLDER"],
        onTextChanged = function(text)
            if searchTimer then searchTimer:Cancel() end
            searchTimer = C_Timer.NewTimer(0.3, function()
                currentSearch = text
                selectedItem = nil
                ClearDetailElements()
                if emptyDetail then
                    emptyDetail:SetText(L["ITEMSEARCH_SELECT"])
                    emptyDetail:Show()
                end
                RefreshItemList()
            end)
        end,
    })
    searchBox:SetPoint("TOPLEFT", searchHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", searchHeader, "TOPRIGHT", -8, -8)

    emptyList = panels.listScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyList:SetPoint("CENTER", panels.listScrollChild, "CENTER", 0, 0)
    emptyList:SetText(L["ITEMSEARCH_EMPTY"])
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    emptyDetail = panels.detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyDetail:SetPoint("CENTER", panels.detailScrollChild, "CENTER", 0, 0)
    emptyDetail:SetText(L["ITEMSEARCH_SELECT"])
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    panels.detailScrollChild:SetHeight(100)

    UpdateSourceButtonStates()
    RefreshItemList()
end
