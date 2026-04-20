-- OneWoW Addon File
-- OneWoW_Catalog/UI/t-journal.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_EDGE = OneWoW_GUI.Constants.BACKDROP_EDGE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

ns.UI = ns.UI or {}

local selectedInstance = nil
local instanceListButtons = {}
local detailElements = {}
local searchText = ""
local expansionFilter = 0
local instanceTypeFilter = "all"
local selectedDifficulty = "all"
local expandedEncounters = {}
local dataAddon = nil

-- Multi-select Item Type filter: keys from ITEM_TYPE_DEFS map to item.special values.
-- Empty table = "Show All" (no filter applied).
local filterItemTypes = {}
local filterCollection = "all"
local hideNonCollectable = false

-- Ordered definition for the Item Type filter menu. Keys here drive both the menu rows
-- and the filterItemTypes set; the `special` field is what each entry matches against
-- item.special in ItemMatchesFilters.
local ITEM_TYPE_DEFS = {
    { key = "tmog",    special = "TMog",    labelKey = "JOURNAL_FILTER_TMOG"    },
    { key = "mounts",  special = "Mount",   labelKey = "JOURNAL_FILTER_MOUNTS"  },
    { key = "pets",    special = "Pet",     labelKey = "JOURNAL_FILTER_PETS"    },
    { key = "recipes", special = "Recipe",  labelKey = "JOURNAL_FILTER_RECIPES" },
    { key = "toys",    special = "Toy",     labelKey = "JOURNAL_FILTER_TOYS"    },
    { key = "quest",   special = "Quest",   labelKey = "JOURNAL_FILTER_QUEST"   },
    { key = "housing", special = "Housing", labelKey = "JOURNAL_FILTER_HOUSING" },
}

local function CountSelectedItemTypes()
    local n = 0
    for _ in pairs(filterItemTypes) do n = n + 1 end
    return n
end

local function GetItemTypeFilterLabel()
    local count = CountSelectedItemTypes()
    if count == 0 then
        return L["JOURNAL_FILTER_SHOW_ALL"]
    end
    if count == 1 then
        for _, def in ipairs(ITEM_TYPE_DEFS) do
            if filterItemTypes[def.key] then
                return L[def.labelKey] or def.key
            end
        end
    end
    return string.format(L["JOURNAL_FILTER_N_SELECTED"], count)
end

local function ResetItemTypeFilter()
    wipe(filterItemTypes)
end

local CARD_HEIGHT = 85
local ITEM_ROW_HEIGHT = 32

local SPECIAL_COLORS = ns.Constants.SPECIAL_COLORS

local SPECIAL_LABELS = {
    TMog    = "JOURNAL_SPECIAL_TMOG",
    Recipe  = "JOURNAL_SPECIAL_RECIPE",
    Mount   = "JOURNAL_SPECIAL_MOUNT",
    Pet     = "JOURNAL_SPECIAL_PET",
    Quest   = "JOURNAL_SPECIAL_QUEST",
    Toy     = "JOURNAL_SPECIAL_TOY",
    Housing = "JOURNAL_SPECIAL_HOUSING",
}

local diffAbbrev = {
    ["Normal"]              = "JOURNAL_DIFF_N",
    ["Heroic"]              = "JOURNAL_DIFF_H",
    ["Mythic"]              = "JOURNAL_DIFF_M",
    ["LFR"]                 = "JOURNAL_DIFF_LFR",
    ["Looking For Raid"]    = "JOURNAL_DIFF_LFR",
    ["Timewalking"]         = "JOURNAL_DIFF_TW",
    ["Mythic+"]             = "JOURNAL_DIFF_M+",
    ["10 Player"]           = "JOURNAL_DIFF_10N",
    ["25 Player"]           = "JOURNAL_DIFF_25N",
    ["10 Player (Heroic)"]  = "JOURNAL_DIFF_10H",
    ["25 Player (Heroic)"]  = "JOURNAL_DIFF_25H",
}

local ejBgCache = {}

local function GetInstanceBackground(instanceID)
    if ejBgCache[instanceID] ~= nil then
        return ejBgCache[instanceID]
    end
    if EJ_GetInstanceInfo then
        local _, _, bgImage = EJ_GetInstanceInfo(instanceID)
        ejBgCache[instanceID] = bgImage or false
        return bgImage or false
    end
    ejBgCache[instanceID] = false
    return false
end

local function GetDataAddon()
    if dataAddon then return dataAddon end
    if ns.Catalog and ns.Catalog.GetDataAddon then
        dataAddon = ns.Catalog:GetDataAddon("journal")
    end
    return dataAddon
end

local function FormatDifficulties(difficulties)
    if not difficulties or #difficulties == 0 then return "" end
    local parts = {}
    for _, diff in ipairs(difficulties) do
        local key = diffAbbrev[diff.name]
        if key then
            table.insert(parts, L[key] or diff.name)
        else
            table.insert(parts, diff.name or "?")
        end
    end
    return table.concat(parts, ", ")
end

local function ItemMatchesFilters(item, addon)
    if next(filterItemTypes) ~= nil then
        -- When at least one Item Type is selected, an item must match one of the chosen
        -- specials; items with no special (e.g. regular gear) are excluded.
        local special = item.special
        if not special then return false end
        local matched = false
        for _, def in ipairs(ITEM_TYPE_DEFS) do
            if filterItemTypes[def.key] and special == def.special then
                matched = true
                break
            end
        end
        if not matched then return false end
    end

    if filterCollection ~= "all" and item.special then
        if addon and addon.JournalData then
            local isCollected = addon.JournalData:IsItemCollected(item.itemID, item.itemData, item.special)
            if isCollected ~= nil then
                if filterCollection == "collected" and not isCollected then return false end
                if filterCollection == "notcollected" and isCollected then return false end
            end
        end
    end

    if selectedDifficulty ~= "all" then
        if item.difficulties and #item.difficulties > 0 then
            local found = false
            for _, diff in ipairs(item.difficulties) do
                if tostring(diff.id) == tostring(selectedDifficulty) then found = true; break end
            end
            if not found then return false end
        end
    end

    if hideNonCollectable and not item.special then
        return false
    end

    return true
end

local function ClearDetailElements()
    for _, element in ipairs(detailElements) do
        if element.Hide then element:Hide() end
        if element.SetParent then element:SetParent(nil) end
    end
    wipe(detailElements)
end

local function ClearInstanceList()
    for _, btn in ipairs(instanceListButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(instanceListButtons)
end


local function CreateInstanceCard(parent, instData, yOffset, onClick)
    local capInstanceID = instData.instanceID

    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    card:SetHeight(CARD_HEIGHT)
    card:SetClipsChildren(true)
    card:SetBackdrop(BACKDROP_SIMPLE)
    card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    if card.SetPropagateMouseClicks then
        pcall(function()
            card:SetPropagateMouseClicks("LeftButton", false)
        end)
    end

    local bgImage = GetInstanceBackground(instData.instanceID)
    if bgImage and bgImage ~= false then
        local bgTex = card:CreateTexture(nil, "ARTWORK")
        bgTex:SetPoint("CENTER", card, "CENTER", 20, -5)
        bgTex:SetSize(380, 140)
        bgTex:SetDrawLayer("ARTWORK", -1)
        bgTex:SetTexture(bgImage)
        bgTex:SetAlpha(0.3)
        card.bgTex = bgTex
    end

    local nameText = OneWoW_GUI:CreateFS(card, 12)
    nameText:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
    nameText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -34, -6)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(instData.name)
    nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local favBtn = OneWoW_GUI:CreateFavoriteToggleButton(card, {
        size     = 20,
        favorite = ns.Favorites and ns.Favorites:IsFavorite("journal", capInstanceID) or false,
        tooltipTitle = L["CATALOG_FAVORITE"],
        tooltipText  = L["CATALOG_FAVORITE_TT"],
        onClick = function(_, on)
            if ns.Favorites then
                ns.Favorites:SetFavorite("journal", capInstanceID, on)
            end
            local p = panels_ref or ns.UI.journalPanels
            if p and _G.RefreshJournalList then
                -- Immediate refresh so remaining favorites compact to the top; unfavorite must reorder the list.
                _G.RefreshJournalList(p)
                C_Timer.After(0, function()
                    if (panels_ref or ns.UI.journalPanels) == p and _G.RefreshJournalList then
                        _G.RefreshJournalList(p)
                    end
                end)
            end
        end,
    })
    favBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -4)
    favBtn:SetFrameLevel((card:GetFrameLevel() or 0) + 10)

    local typeStr = instData.instanceType == "raid" and L["JOURNAL_CARD_RAID"]
                 or instData.instanceType == "party" and L["JOURNAL_CARD_DUNGEON"]
                 or ""
    local infoText = OneWoW_GUI:CreateFS(card, 10)
    infoText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    infoText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, 0)
    infoText:SetJustifyH("LEFT")
    infoText:SetText(instData.expansionName .. "  |  " .. typeStr)
    infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local encCount = #instData.encounters
    local countText = OneWoW_GUI:CreateFS(card, 10)
    countText:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", 0, -2)
    countText:SetJustifyH("LEFT")
    countText:SetText(string.format(L["JOURNAL_CARD_ENCOUNTERS"], encCount)
                      .. "  |  " .. string.format(L["JOURNAL_CARD_ITEMS"], instData.totalItems))
    countText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))

    local row1 = {
        { flag = instData.hasMounts,  label = L["JOURNAL_CARD_MOUNTS"],  color = SPECIAL_COLORS.Mount },
        { flag = instData.hasPets,    label = L["JOURNAL_CARD_PETS"],    color = SPECIAL_COLORS.Pet },
        { flag = instData.hasToys,    label = L["JOURNAL_CARD_TOYS"],    color = SPECIAL_COLORS.Toy },
    }
    local row2 = {
        { flag = instData.hasRecipes, label = L["JOURNAL_CARD_RECIPES"], color = SPECIAL_COLORS.Recipe },
        { flag = instData.hasHousing, label = L["JOURNAL_CARD_HOUSING"], color = SPECIAL_COLORS.Housing },
        { flag = instData.hasQuest,   label = L["JOURNAL_CARD_QUEST"],   color = SPECIAL_COLORS.Quest },
    }

    local colWidth = 80
    for i, cat in ipairs(row1) do
        local catText = OneWoW_GUI:CreateFS(card, 10)
        catText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 8 + ((i - 1) * colWidth), 18)
        catText:SetText(cat.label)
        if cat.flag then
            catText:SetTextColor(cat.color[1], cat.color[2], cat.color[3], 1.0)
        else
            catText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end
    for i, cat in ipairs(row2) do
        local catText = OneWoW_GUI:CreateFS(card, 10)
        catText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 8 + ((i - 1) * colWidth), 6)
        catText:SetText(cat.label)
        if cat.flag then
            catText:SetTextColor(cat.color[1], cat.color[2], cat.color[3], 1.0)
        else
            catText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    card:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        if self.bgTex then self.bgTex:SetAlpha(0.5) end
    end)
    card:SetScript("OnLeave", function(self)
        if selectedInstance and selectedInstance.instanceID == instData.instanceID then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        end
        if self.bgTex then self.bgTex:SetAlpha(0.3) end
    end)
    card:SetScript("OnClick", function()
        onClick(instData)
    end)

    card.instData = instData
    return card
end

local function BuildCollectionsSummary(parent, instData, yOffset, addon)
    local counts = {
        TMog    = { total = 0, collected = 0 },
        Mount   = { total = 0, collected = 0 },
        Pet     = { total = 0, collected = 0 },
        Recipe  = { total = 0, collected = 0 },
        Toy     = { total = 0, collected = 0 },
        Quest   = { total = 0, collected = 0 },
        Housing = { total = 0, collected = 0 },
    }

    for _, enc in ipairs(instData.encounters) do
        for _, item in ipairs(enc.items) do
            if item.special and counts[item.special] then
                counts[item.special].total = counts[item.special].total + 1
                if addon and addon.JournalData then
                    local isCollected = addon.JournalData:IsItemCollected(item.itemID, item.itemData, item.special)
                    if isCollected then
                        counts[item.special].collected = counts[item.special].collected + 1
                    end
                end
            end
        end
    end

    local headerText = OneWoW_GUI:CreateFS(parent, 12)
    headerText:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    headerText:SetText(L["JOURNAL_COLLECTIONS"])
    headerText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    table.insert(detailElements, headerText)
    yOffset = yOffset - 18

    local catDefs = {
        { key = "TMog",    fmt = "JOURNAL_COL_TMOG",    color = SPECIAL_COLORS.TMog },
        { key = "Mount",   fmt = "JOURNAL_COL_MOUNTS",  color = SPECIAL_COLORS.Mount },
        { key = "Pet",     fmt = "JOURNAL_COL_PETS",     color = SPECIAL_COLORS.Pet },
        { key = "Recipe",  fmt = "JOURNAL_COL_RECIPES",  color = SPECIAL_COLORS.Recipe },
        { key = "Toy",     fmt = "JOURNAL_COL_TOYS",     color = SPECIAL_COLORS.Toy },
        { key = "Quest",   fmt = "JOURNAL_COL_QUEST",    color = SPECIAL_COLORS.Quest },
        { key = "Housing", fmt = "JOURNAL_COL_HOUSING",  color = SPECIAL_COLORS.Housing },
    }

    local xPos = 10
    for _, def in ipairs(catDefs) do
        local c = counts[def.key]
        local catLabel = OneWoW_GUI:CreateFS(parent, 10)
        catLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", xPos, yOffset)
        catLabel:SetJustifyH("LEFT")
        catLabel:SetText(string.format(L[def.fmt], c.collected, c.total))

        if c.total == 0 then
            catLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        elseif c.collected >= c.total then
            catLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            catLabel:SetTextColor(def.color[1], def.color[2], def.color[3], 1.0)
        end
        table.insert(detailElements, catLabel)

        xPos = xPos + catLabel:GetStringWidth() + 12
    end

    yOffset = yOffset - 16
    return yOffset - 4
end

local function GetUniqueDifficulties(instData)
    local seen = {}
    local result = {}
    for _, enc in ipairs(instData.encounters) do
        for _, item in ipairs(enc.items) do
            if item.difficulties then
                for _, diff in ipairs(item.difficulties) do
                    if diff.id and not seen[diff.id] then
                        seen[diff.id] = true
                        table.insert(result, { id = diff.id, name = diff.name })
                    end
                end
            end
        end
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

local panels_ref = nil

-- Base list from data (expensive); only refetch when filters change. Favorite sort uses a shallow copy.
local journalBaseListKey  = nil
local journalBaseList     = nil

local function JournalInstanceOrderKey(id)
    return id ~= nil and tostring(id) or ""
end

local function InvalidateJournalFilterCache()
    journalBaseListKey = nil
    journalBaseList = nil
end

local function RefreshDetailView(isSecondRefresh)
    if not panels_ref or not selectedInstance then return end

    local panels = panels_ref
    local instData = selectedInstance
    local addon = GetDataAddon()

    if panels.emptyDetail then panels.emptyDetail:Hide() end
    ClearDetailElements()

    local parent = panels.detailScrollChild
    local yOffset = -8

    local nameHeader = OneWoW_GUI:CreateFS(parent, 16)
    nameHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    nameHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    nameHeader:SetJustifyH("LEFT")
    nameHeader:SetText(instData.name)
    nameHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    table.insert(detailElements, nameHeader)
    yOffset = yOffset - 22

    local typeStr = instData.instanceType == "raid" and L["JOURNAL_CARD_RAID"]
                 or instData.instanceType == "party" and L["JOURNAL_CARD_DUNGEON"]
                 or ""
    local infoLine = OneWoW_GUI:CreateFS(parent, 12)
    infoLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    infoLine:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    infoLine:SetJustifyH("LEFT")
    local infoParts = {}
    table.insert(infoParts, L["JOURNAL_DETAIL_EXPANSION"] .. ": " .. instData.expansionName)
    table.insert(infoParts, L["JOURNAL_DETAIL_TYPE"] .. ": " .. typeStr)
    table.insert(infoParts, L["JOURNAL_DETAIL_INST_ID"] .. ": " .. instData.instanceID)
    if instData.mapID then
        table.insert(infoParts, L["JOURNAL_DETAIL_MAP_ID"] .. ": " .. instData.mapID)
    end
    infoLine:SetText(table.concat(infoParts, "  |  "))
    infoLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    table.insert(detailElements, infoLine)
    yOffset = yOffset - 20

    local divider1 = OneWoW_GUI:CreateDivider(parent, { yOffset = yOffset })
    table.insert(detailElements, divider1)
    yOffset = yOffset - 8

    yOffset = BuildCollectionsSummary(parent, instData, yOffset, addon)

    local divider2 = OneWoW_GUI:CreateDivider(parent, { yOffset = yOffset })
    table.insert(detailElements, divider2)
    yOffset = yOffset - 10

    local colHdrFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    colHdrFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    colHdrFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
    colHdrFrame:SetHeight(20)
    colHdrFrame:SetBackdrop(BACKDROP_SIMPLE)
    colHdrFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    table.insert(detailElements, colHdrFrame)

    local COL_DIFF_RIGHT    = -220
    local COL_SPECIAL_RIGHT = -130
    local COL_STATUS_RIGHT  = -8

    local hdrItem = OneWoW_GUI:CreateFS(colHdrFrame, 10)
    hdrItem:SetPoint("LEFT", colHdrFrame, "LEFT", 8, 0)
    hdrItem:SetText(L["JOURNAL_COL_HDR_ITEM"])
    hdrItem:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local hdrDiff = OneWoW_GUI:CreateFS(colHdrFrame, 10)
    hdrDiff:SetPoint("RIGHT", colHdrFrame, "RIGHT", COL_DIFF_RIGHT, 0)
    hdrDiff:SetText(L["JOURNAL_COL_HDR_DIFFICULTY"])
    hdrDiff:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    hdrDiff:SetJustifyH("RIGHT")

    local hdrSpecial = OneWoW_GUI:CreateFS(colHdrFrame, 10)
    hdrSpecial:SetPoint("RIGHT", colHdrFrame, "RIGHT", COL_SPECIAL_RIGHT, 0)
    hdrSpecial:SetText(L["JOURNAL_COL_HDR_SPECIAL"])
    hdrSpecial:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    hdrSpecial:SetJustifyH("RIGHT")

    local hdrStatus = OneWoW_GUI:CreateFS(colHdrFrame, 10)
    hdrStatus:SetPoint("RIGHT", colHdrFrame, "RIGHT", COL_STATUS_RIGHT, 0)
    hdrStatus:SetText(L["JOURNAL_COL_HDR_STATUS"])
    hdrStatus:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    hdrStatus:SetJustifyH("RIGHT")

    yOffset = yOffset - 24

    for _, encounter in ipairs(instData.encounters) do
        local isExpanded = expandedEncounters[encounter.encounterID]
        if isExpanded == nil then
            expandedEncounters[encounter.encounterID] = true
            isExpanded = true
        end

        local filteredItems = {}
        for _, item in ipairs(encounter.items) do
            if ItemMatchesFilters(item, addon) then
                table.insert(filteredItems, item)
            end
        end

        local encBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        encBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
        encBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
        encBtn:SetHeight(28)
        encBtn:SetBackdrop(BACKDROP_SIMPLE)
        encBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        table.insert(detailElements, encBtn)

        local arrowText = OneWoW_GUI:CreateFS(encBtn, 12)
        arrowText:SetPoint("LEFT", encBtn, "LEFT", 8, 0)
        arrowText:SetText(isExpanded and "v" or ">")
        arrowText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local encName = OneWoW_GUI:CreateFS(encBtn, 12)
        encName:SetPoint("LEFT", arrowText, "RIGHT", 6, 0)
        encName:SetText(encounter.name)
        encName:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        local itemCountStr = string.format(L["JOURNAL_ITEMS_COUNT"], #filteredItems)
        if #filteredItems ~= #encounter.items then
            itemCountStr = string.format(L["JOURNAL_ITEMS_FILTERED"], #filteredItems, #encounter.items)
        end
        local encCount = OneWoW_GUI:CreateFS(encBtn, 10)
        encCount:SetPoint("RIGHT", encBtn, "RIGHT", -8, 0)
        encCount:SetText(itemCountStr)
        encCount:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local capturedEncID = encounter.encounterID
        encBtn:SetScript("OnClick", function()
            expandedEncounters[capturedEncID] = not expandedEncounters[capturedEncID]
            RefreshDetailView(false)
        end)
        encBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        end)
        encBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        end)

        yOffset = yOffset - 30

        if isExpanded and #filteredItems > 0 then
            for _, item in ipairs(filteredItems) do
                local itemRow = CreateFrame("Frame", nil, parent, "BackdropTemplate")
                itemRow:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
                itemRow:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
                itemRow:SetHeight(ITEM_ROW_HEIGHT)
                itemRow:SetBackdrop(BACKDROP_SIMPLE)
                itemRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                table.insert(detailElements, itemRow)

                local iconFrame = CreateFrame("Frame", nil, itemRow, "BackdropTemplate")
                iconFrame:SetSize(26, 26)
                iconFrame:SetPoint("LEFT", itemRow, "LEFT", 6, 0)
                iconFrame:SetBackdrop(BACKDROP_EDGE)
                iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetItemQualityColor(item.quality))
                table.insert(detailElements, iconFrame)

                local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
                iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
                iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
                iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                iconTex:SetTexture(item.icon or 134400)

                local itemName = OneWoW_GUI:CreateFS(itemRow, 12)
                itemName:SetPoint("LEFT", iconFrame, "RIGHT", 8, 0)
                itemName:SetPoint("RIGHT", itemRow, "RIGHT", COL_DIFF_RIGHT - 10, 0)
                itemName:SetJustifyH("LEFT")
                itemName:SetWordWrap(false)
                local displayName = item.name
                if item.fromLiveEJ then
                    displayName = displayName .. " |cff888888(" .. L["JOURNAL_LIVE_EJ_TAG"] .. ")|r"
                end
                itemName:SetText(displayName)
                itemName:SetTextColor(OneWoW_GUI:GetItemQualityColor(item.quality))

                local diffText = OneWoW_GUI:CreateFS(itemRow, 10)
                diffText:SetPoint("RIGHT", itemRow, "RIGHT", COL_DIFF_RIGHT, 0)
                diffText:SetJustifyH("RIGHT")
                diffText:SetText(FormatDifficulties(item.difficulties))
                diffText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                local specialText = OneWoW_GUI:CreateFS(itemRow, 10)
                specialText:SetPoint("RIGHT", itemRow, "RIGHT", COL_SPECIAL_RIGHT, 0)
                specialText:SetJustifyH("RIGHT")
                if item.special then
                    local labelKey = SPECIAL_LABELS[item.special]
                    specialText:SetText(labelKey and L[labelKey] or item.special)
                    local sc = SPECIAL_COLORS[item.special]
                    if sc then
                        specialText:SetTextColor(sc[1], sc[2], sc[3], 1.0)
                    end
                else
                    specialText:SetText("")
                end

                local statusText = OneWoW_GUI:CreateFS(itemRow, 10)
                statusText:SetPoint("RIGHT", itemRow, "RIGHT", COL_STATUS_RIGHT, 0)
                statusText:SetJustifyH("RIGHT")
                if item.special and addon and addon.JournalData then
                    local status = addon.JournalData:DetermineItemStatus(item.itemID, item.itemData, item.special)
                    if status then
                        statusText:SetText(status)
                        local isCollected = addon.JournalData:IsItemCollected(item.itemID, item.itemData, item.special)
                        if isCollected then
                            statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
                        else
                            statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
                        end
                    else
                        statusText:SetText("")
                    end
                else
                    statusText:SetText("")
                end

                itemRow:EnableMouse(true)
                itemRow:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(item.itemID)
                    GameTooltip:Show()
                end)
                itemRow:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                    GameTooltip:Hide()
                end)

                yOffset = yOffset - (ITEM_ROW_HEIGHT + 2)
            end
        end

        yOffset = yOffset - 4
    end

    parent:SetHeight(math.abs(yOffset) + 20)
    panels.UpdateDetailThumb()

    if panels.rightStatusText and instData then
        panels.rightStatusText:SetText(instData.name .. " - " .. string.format(L["JOURNAL_CARD_ENCOUNTERS"], #instData.encounters) .. ", " .. string.format(L["JOURNAL_CARD_ITEMS"], instData.totalItems))
    end

    if not isSecondRefresh then
        C_Timer.After(0.1, function()
            if panels and panels.detailScrollChild:IsVisible() and selectedInstance then
                RefreshDetailView(true)
            end
        end)
    end
end

local function ShowInstanceDetail(panels, instData)
    if not instData then return end
    selectedInstance = instData
    expandedEncounters = {}
    panels_ref = panels

    if panels.diffDropdown then
        local diffs = GetUniqueDifficulties(instData)
        if #diffs > 0 then
            panels.diffDropdown:Show()
            panels.diffText:SetText(L["JOURNAL_DIFF_ALL"])

            OneWoW_GUI:AttachFilterMenu(panels.diffDropdown, {
                searchable = false,
                getActiveValue = function() return selectedDifficulty end,
                buildItems = function()
                    local items = { { value = "all", text = L["JOURNAL_DIFF_ALL"] } }
                    local curDiffs = GetUniqueDifficulties(selectedInstance)
                    for _, diff in ipairs(curDiffs) do
                        table.insert(items, {
                            value = diff.id,
                            text  = diff.name or "?",
                        })
                    end
                    return items
                end,
                onSelect = function(value, text)
                    selectedDifficulty = value
                    panels.diffText:SetText(value == "all" and L["JOURNAL_DIFF_ALL"] or text)
                    RefreshDetailView(false)
                end,
            })
        else
            panels.diffDropdown:Hide()
        end
    end

    selectedDifficulty = "all"
    RefreshDetailView(false)
end

function RefreshJournalList(panels)
    ClearInstanceList()
    if panels.listScrollFrame and panels.listScrollFrame.SetVerticalScroll then
        panels.listScrollFrame:SetVerticalScroll(0)
    end

    local addon = GetDataAddon()
    if not addon or not addon.JournalData then
        panels.listScrollChild:SetHeight(100)
        panels.UpdateListThumb()
        return
    end

    local filtKey = string.format("%d\0%s\0%s", expansionFilter, searchText or "", tostring(instanceTypeFilter or "all"))
    if journalBaseListKey ~= filtKey or not journalBaseList then
        journalBaseList = addon.JournalData:GetSortedInstances(expansionFilter, searchText, instanceTypeFilter)
        journalBaseListKey = filtKey
    end

    local sorted = {}
    for i = 1, #journalBaseList do
        sorted[i] = journalBaseList[i]
    end

    if ns.Favorites then
        local keyFn = JournalInstanceOrderKey
        local origOrder = {}
        for i, inst in ipairs(sorted) do
            origOrder[keyFn(inst.instanceID)] = i
        end
        local function cmpBaseOrder(a, b)
            return (origOrder[keyFn(a.instanceID)] or 0) < (origOrder[keyFn(b.instanceID)] or 0)
        end
        local favInsts, restInsts = {}, {}
        for _, inst in ipairs(sorted) do
            if ns.Favorites:IsFavorite("journal", inst.instanceID) then
                table.insert(favInsts, inst)
            else
                table.insert(restInsts, inst)
            end
        end
        table.sort(favInsts, cmpBaseOrder)
        table.sort(restInsts, cmpBaseOrder)
        local pos = 0
        for _, inst in ipairs(favInsts) do
            pos = pos + 1
            sorted[pos] = inst
        end
        for _, inst in ipairs(restInsts) do
            pos = pos + 1
            sorted[pos] = inst
        end
    end

    local totalSorted = #sorted
    local displayLimit = nil
    if expansionFilter == 0 then
        displayLimit = 10
    end
    local displayCount = displayLimit and math.min(totalSorted, displayLimit) or totalSorted

    if totalSorted == 0 then
        panels.emptyList:Show()
        panels.listScrollChild:SetHeight(100)
        panels.UpdateListThumb()
        if panels.leftStatusText then
            panels.leftStatusText:SetText("")
        end
        return
    end

    panels.emptyList:Hide()

    local yOffset = -4
    for i = 1, displayCount do
        local instData = sorted[i]
        local card = CreateInstanceCard(panels.listScrollChild, instData, yOffset, function(inst)
            for _, btn in ipairs(instanceListButtons) do
                if btn.instData and btn.instData.instanceID == inst.instanceID then
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                else
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                end
            end
            ShowInstanceDetail(panels, inst)
        end)
        table.insert(instanceListButtons, card)
        yOffset = yOffset - (CARD_HEIGHT + 2)
    end

    panels.listScrollChild:SetHeight(math.abs(yOffset) + 10)
    panels.UpdateListThumb()

    if panels.leftStatusText then
        if displayLimit and totalSorted > displayLimit then
            panels.leftStatusText:SetText(string.format(L["JOURNAL_STATS_SHOWING"], displayCount, totalSorted))
        else
            panels.leftStatusText:SetText(string.format(L["JOURNAL_STATS"], totalSorted))
        end
    end
end

_G.RefreshJournalList = RefreshJournalList

local function InitializeDropdowns(panels)
    local addon = GetDataAddon()
    if not addon then return end

    if panels.expDropdown then
        panels.expText:SetText(L["JOURNAL_EXPANSION_ALL"])
        OneWoW_GUI:AttachFilterMenu(panels.expDropdown, {
            searchable = false,
            getActiveValue = function() return expansionFilter end,
            buildItems = function()
                local items = { { value = 0, text = L["JOURNAL_EXPANSION_ALL"] } }
                local da = GetDataAddon()
                if da and da.JournalData then
                    local expansions = da.JournalData:GetAvailableExpansions()
                    for _, exp in ipairs(expansions) do
                        table.insert(items, {
                            value = exp.expansionID,
                            text  = exp.displayName,
                        })
                    end
                end
                return items
            end,
            onSelect = function(value, text)
                expansionFilter = value
                panels.expText:SetText(value == 0 and L["JOURNAL_EXPANSION_ALL"] or text)
                RefreshJournalList(panels)
            end,
        })
    end

    if panels.itemFilterDropdown then
        panels.itemFilterText:SetText(GetItemTypeFilterLabel())
        OneWoW_GUI:AttachFilterMenu(panels.itemFilterDropdown, {
            searchable = false,
            buildItems = function()
                local items = {}
                for _, def in ipairs(ITEM_TYPE_DEFS) do
                    local capKey = def.key
                    table.insert(items, {
                        type    = "checkbox",
                        text    = L[def.labelKey] or def.key,
                        checked = filterItemTypes[capKey] == true,
                        onToggle = function(checked)
                            filterItemTypes[capKey] = checked and true or nil
                            panels.itemFilterText:SetText(GetItemTypeFilterLabel())
                            if selectedInstance then
                                RefreshDetailView(false)
                            end
                        end,
                    })
                end
                table.insert(items, { type = "divider" })
                table.insert(items, {
                    value = "__reset__",
                    text  = L["JOURNAL_FILTER_RESET"],
                })
                return items
            end,
            onSelect = function(value)
                if value == "__reset__" then
                    ResetItemTypeFilter()
                    panels.itemFilterText:SetText(GetItemTypeFilterLabel())
                    if selectedInstance then
                        RefreshDetailView(false)
                    end
                end
            end,
        })
    end

    if panels.collectionFilterDropdown then
        panels.collectionFilterText:SetText(L["JOURNAL_FILTER_SHOW_ALL"])
        OneWoW_GUI:AttachFilterMenu(panels.collectionFilterDropdown, {
            searchable = false,
            getActiveValue = function() return filterCollection end,
            buildItems = function()
                return {
                    { value = "all",          text = L["JOURNAL_FILTER_SHOW_ALL"]      },
                    { value = "collected",    text = L["JOURNAL_FILTER_COLLECTED"]     },
                    { value = "notcollected", text = L["JOURNAL_FILTER_NOT_COLLECTED"] },
                }
            end,
            onSelect = function(value, text)
                filterCollection = value
                panels.collectionFilterText:SetText(value == "all" and L["JOURNAL_FILTER_SHOW_ALL"] or text)
                if selectedInstance then
                    RefreshDetailView(false)
                end
            end,
        })
    end
end

function ns.UI.CreateJournalTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP    = ns.Constants.GUI.PANEL_GAP
    local HDR_H  = 86  -- was 80; adds bottom padding for expansion dropdown

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

    local panels = OneWoW_GUI:CreateSplitPanel(contentArea)
    panels.listTitle:SetText(L["JOURNAL_LIST_TITLE"])
    panels.detailTitle:SetText(L["JOURNAL_DETAIL_TITLE"])

    local clearBtn = OneWoW_GUI:CreateFitTextButton(leftHeader, { text = L["JOURNAL_FILTER_CLEAR"], height = 26, minWidth = 34 })
    clearBtn:SetPoint("TOPRIGHT", leftHeader, "TOPRIGHT", -8, -8)

    local searchBox = OneWoW_GUI:CreateEditBox(leftHeader, {
        height = 26,
        placeholderText = L["JOURNAL_SEARCH"],
        onTextChanged = function(text)
            searchText = text
            if panels._searchTimer then panels._searchTimer:Cancel() end
            panels._searchTimer = C_Timer.NewTimer(0.3, function()
                RefreshJournalList(panels)
            end)
        end,
    })
    searchBox:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", -4, 0)

    -- LEFT HEADER: Row 2 - Expansion label + dropdown
    local expLabel = OneWoW_GUI:CreateFS(leftHeader, 10)
    expLabel:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -38)
    expLabel:SetText(L["JOURNAL_LABEL_EXPANSION"])
    expLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local expDropdown, expText = OneWoW_GUI:CreateDropdown(leftHeader, { width = LEFT_W - 16, text = L["JOURNAL_EXPANSION_ALL"] })
    expDropdown:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -54)

    -- RIGHT HEADER: Row 1 left - Instance Type label + [All][Raids][Dungeons] buttons
    local typeLabel = OneWoW_GUI:CreateFS(rightHeader, 10)
    typeLabel:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", 8, -8)
    typeLabel:SetText(L["JOURNAL_LABEL_INST_TYPE"])
    typeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local typeButtonDefs = {
        { text = L["JOURNAL_TYPE_ALL"],      value = "all"   },
        { text = L["JOURNAL_TYPE_RAIDS"],    value = "raid"  },
        { text = L["JOURNAL_TYPE_DUNGEONS"], value = "party" },
    }
    local typeButtons = {}
    local BTN_PAD_X = 8
    local BTN_H     = 22
    local BTN_GAP   = 3
    local xOff      = 8
    for _, def in ipairs(typeButtonDefs) do
        local btn = CreateFrame("Button", nil, rightHeader, "BackdropTemplate")
        btn:SetHeight(BTN_H)
        btn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local lbl = OneWoW_GUI:CreateFS(btn, 10)
        lbl:SetPoint("CENTER", 0, 0)
        lbl:SetText(def.text)
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        btn:SetWidth(math.max(30, lbl:GetStringWidth() + BTN_PAD_X * 2))

        btn.highlight = btn:CreateTexture(nil, "OVERLAY")
        btn.highlight:SetAllPoints()
        btn.highlight:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        btn.highlight:SetAlpha(0.15)
        btn.highlight:Hide()

        btn:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", xOff, -22)
        xOff = xOff + btn:GetWidth() + BTN_GAP

        btn.value = def.value
        btn.label = lbl
        table.insert(typeButtons, btn)

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        end)
        btn:SetScript("OnLeave", function(self)
            if instanceTypeFilter == self.value then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            else
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            end
        end)
        btn:SetScript("OnClick", function(self)
            instanceTypeFilter = self.value
            for _, b in ipairs(typeButtons) do
                if b.value == instanceTypeFilter then
                    b:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                    b.highlight:Show()
                else
                    b:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                    b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    b.highlight:Hide()
                end
            end
            RefreshJournalList(panels)
        end)
    end

    -- Set initial active state on All button
    for _, b in ipairs(typeButtons) do
        if b.value == "all" then
            b:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            b.highlight:Show()
        end
    end

    -- RIGHT HEADER: Row 1 right - Collection + Item Type dropdowns with labels
    local collectionFilterDropdown, collectionFilterText = OneWoW_GUI:CreateDropdown(rightHeader, { width = 130, text = L["JOURNAL_FILTER_SHOW_ALL"] })
    collectionFilterDropdown:SetPoint("TOPRIGHT", rightHeader, "TOPRIGHT", -8, -22)

    local collLabel = OneWoW_GUI:CreateFS(rightHeader, 10)
    collLabel:SetPoint("BOTTOMLEFT", collectionFilterDropdown, "TOPLEFT", 0, 2)
    collLabel:SetText(L["JOURNAL_LABEL_COLLECTION"])
    collLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local itemFilterDropdown, itemFilterText = OneWoW_GUI:CreateDropdown(rightHeader, { width = 130, text = L["JOURNAL_FILTER_SHOW_ALL"] })
    itemFilterDropdown:SetPoint("TOPRIGHT", collectionFilterDropdown, "TOPLEFT", -6, 0)

    local itemTypeLabel = OneWoW_GUI:CreateFS(rightHeader, 10)
    itemTypeLabel:SetPoint("BOTTOMLEFT", itemFilterDropdown, "TOPLEFT", 0, 2)
    itemTypeLabel:SetText(L["JOURNAL_LABEL_ITEM_TYPE"])
    itemTypeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local chkBox = OneWoW_GUI:CreateCheckbox(rightHeader, {
        label = L["JOURNAL_HIDE_NON_COLLECTABLE"],
        checked = false,
        onClick = function(self)
            hideNonCollectable = not hideNonCollectable
            if selectedInstance then
                RefreshDetailView(false)
            end
        end,
    })
    chkBox:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", 8, -54)

    -- Clear button resets all filters
    clearBtn:SetScript("OnClick", function()
        searchText         = ""
        expansionFilter    = 0
        instanceTypeFilter = "all"
        ResetItemTypeFilter()
        filterCollection   = "all"
        hideNonCollectable = false
        searchBox:SetText("")
        searchBox:ClearFocus()
        expText:SetText(L["JOURNAL_EXPANSION_ALL"])
        itemFilterText:SetText(GetItemTypeFilterLabel())
        collectionFilterText:SetText(L["JOURNAL_FILTER_SHOW_ALL"])
        chkBox:SetChecked(false)
        for _, b in ipairs(typeButtons) do
            if b.value == "all" then
                b:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                b.highlight:Show()
            else
                b:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                b.highlight:Hide()
            end
        end
        RefreshJournalList(panels)
        if selectedInstance then
            RefreshDetailView(false)
        end
    end)

    -- Empty state labels
    local emptyList = OneWoW_GUI:CreateFS(panels.listScrollChild, 12)
    emptyList:SetPoint("CENTER", panels.listScrollChild, "CENTER", 0, 0)
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyList = emptyList

    local emptyDetail = OneWoW_GUI:CreateFS(panels.detailPanel, 12)
    emptyDetail:SetPoint("CENTER", panels.detailPanel, "CENTER", 0, 0)
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyDetail = emptyDetail

    -- Difficulty dropdown stays in detail panel
    local diffDropdown, diffText = OneWoW_GUI:CreateDropdown(panels.detailPanel, { width = 180, text = L["JOURNAL_DIFF_ALL"] })
    diffDropdown:SetPoint("TOPLEFT", panels.detailPanel, "TOPLEFT", 8, -28)
    diffDropdown:Hide()
    panels.diffDropdown = diffDropdown
    panels.diffText = diffText

    panels.detailScrollFrame:ClearAllPoints()
    panels.detailScrollFrame:SetPoint("TOPLEFT", panels.detailPanel, "TOPLEFT", 0, -58)
    panels.detailScrollFrame:SetPoint("BOTTOMRIGHT", panels.detailPanel, "BOTTOMRIGHT", -18, 8)

    panels.expDropdown              = expDropdown
    panels.expText                  = expText
    panels.itemFilterDropdown       = itemFilterDropdown
    panels.itemFilterText           = itemFilterText
    panels.collectionFilterDropdown = collectionFilterDropdown
    panels.collectionFilterText     = collectionFilterText

    ns.UI.journalPanels = panels
    panels_ref = panels

    local addon = GetDataAddon()
    if addon then
        emptyList:SetText(L["JOURNAL_EMPTY"])
        emptyDetail:SetText(L["JOURNAL_SELECT"])
        panels.detailScrollChild:SetHeight(100)

        if addon.RegisterScanCallback then
            addon:RegisterScanCallback(function()
                InvalidateJournalFilterCache()
                if ns.UI.journalPanels then
                    RefreshJournalList(ns.UI.journalPanels)
                end
            end)
        end

        C_Timer.After(0.1, function()
            InitializeDropdowns(panels)
            RefreshJournalList(panels)
        end)
    else
        emptyList:SetText(L["JOURNAL_NO_DATA"])
        emptyDetail:SetText(L["JOURNAL_NO_DATA"])
        panels.listScrollChild:SetHeight(100)
        panels.detailScrollChild:SetHeight(100)

        C_Timer.After(2.0, function()
            local retryAddon = GetDataAddon()
            if retryAddon then
                dataAddon = retryAddon
                emptyList:SetText(L["JOURNAL_EMPTY"])
                emptyDetail:SetText(L["JOURNAL_SELECT"])
                if retryAddon.RegisterScanCallback then
                    retryAddon:RegisterScanCallback(function()
                        InvalidateJournalFilterCache()
                        RefreshJournalList(ns.UI.journalPanels)
                    end)
                end
                InitializeDropdowns(panels)
                RefreshJournalList(panels)
            end
        end)
    end
end

function ns.UI.OpenToInstance(mapID)
    local journalNS = _G.OneWoW_CatalogData_Journal
    if not journalNS or not journalNS.JournalData then return end
    local JournalData = journalNS.JournalData
    JournalData:BuildJournalCache()
    if not JournalData.journalCache then return end

    local instData
    for _, data in pairs(JournalData.journalCache) do
        if data.mapID == mapID then
            instData = data
            break
        end
    end
    if not instData then return end

    if _G.OneWoW and _G.OneWoW.GUI then
        _G.OneWoW.GUI:Show("catalog")
        _G.OneWoW.GUI:SelectSubTab("catalog", "journal")
    end

    C_Timer.After(0.15, function()
        if not panels_ref then return end
        expansionFilter    = instData.expansionID
        searchText         = ""
        instanceTypeFilter = "all"
        if panels_ref.searchBox then
            panels_ref.searchBox:SetText("")
        end
        if panels_ref.expText then
            panels_ref.expText:SetText(instData.expansionName)
        end
        RefreshJournalList(panels_ref)
        ShowInstanceDetail(panels_ref, instData)
        for _, btn in ipairs(instanceListButtons) do
            if btn.instData and btn.instData.instanceID == instData.instanceID then
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            else
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            end
        end
    end)
end
