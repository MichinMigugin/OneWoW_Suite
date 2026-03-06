-- OneWoW Addon File
-- OneWoW_Catalog/UI/t-journal.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

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

local filterItemType = "all"
local filterCollection = "all"
local hideNonCollectable = false

local CARD_HEIGHT = 85
local ITEM_ROW_HEIGHT = 32

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

local SPECIAL_COLORS = {
    TMog    = { 0.8, 0.4, 1.0 },
    Recipe  = { 1.0, 0.8, 0.2 },
    Mount   = { 0.4, 0.8, 1.0 },
    Pet     = { 1.0, 0.5, 0.5 },
    Quest   = { 1.0, 1.0, 0.2 },
    Toy     = { 1.0, 0.6, 0.8 },
    Housing = { 0.5, 1.0, 0.5 },
}

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
    if filterItemType ~= "all" then
        local special = item.special
        if filterItemType == "tmog"    and special ~= "TMog"    then return false end
        if filterItemType == "mounts"  and special ~= "Mount"   then return false end
        if filterItemType == "pets"    and special ~= "Pet"     then return false end
        if filterItemType == "recipes" and special ~= "Recipe"  then return false end
        if filterItemType == "toys"    and special ~= "Toy"     then return false end
        if filterItemType == "quest"   and special ~= "Quest"   then return false end
        if filterItemType == "housing" and special ~= "Housing" then return false end
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

local activeMenus = {}

local function HideAllMenus()
    for _, menu in ipairs(activeMenus) do
        if menu and menu:IsShown() then menu:Hide() end
    end
    wipe(activeMenus)
end

local function CreateThemedDropdown(parent, width, defaultText)
    local dropdown = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dropdown:SetSize(width, 26)
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropdown:SetBackdropColor(T("BG_TERTIARY"))
    dropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    dropdown.label = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropdown.label:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    dropdown.label:SetPoint("RIGHT", dropdown, "RIGHT", -20, 0)
    dropdown.label:SetJustifyH("LEFT")
    dropdown.label:SetWordWrap(false)
    dropdown.label:SetText(defaultText)
    dropdown.label:SetTextColor(T("TEXT_PRIMARY"))

    local arrow = dropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -4, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    dropdown:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
    end)
    dropdown:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    return dropdown
end

local function ShowDropdownMenu(dropdown, items, onSelect)
    HideAllMenus()

    local itemHeight = 24
    local padding = 6
    local menuHeight = (#items * itemHeight) + (padding * 2)
    local menuWidth = dropdown:GetWidth()
    if menuWidth < 160 then menuWidth = 160 end

    local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetSize(menuWidth, menuHeight)
    menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    menu:SetBackdropColor(0.08, 0.08, 0.08, 0.97)
    menu:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    menu:EnableMouse(true)

    table.insert(activeMenus, menu)

    local yPos = -padding
    for _, item in ipairs(items) do
        if item.isSeparator then
            local sep = menu:CreateTexture(nil, "ARTWORK")
            sep:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, yPos - (itemHeight / 2))
            sep:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, yPos - (itemHeight / 2))
            sep:SetHeight(1)
            sep:SetColorTexture(T("BORDER_SUBTLE"))
            yPos = yPos - itemHeight
        else
            local btn = CreateFrame("Button", nil, menu, "BackdropTemplate")
            btn:SetSize(menuWidth - 4, itemHeight)
            btn:SetPoint("TOP", menu, "TOP", 0, yPos)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            btn:SetBackdropColor(0, 0, 0, 0)

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", btn, "LEFT", 8, 0)
            text:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
            text:SetJustifyH("LEFT")
            text:SetText(item.text)

            if item.checked then
                text:SetTextColor(T("ACCENT_HIGHLIGHT"))
            else
                text:SetTextColor(T("TEXT_PRIMARY"))
            end

            btn:SetScript("OnEnter", function(self)
                self:SetBackdropColor(T("BG_HOVER"))
                text:SetTextColor(T("TEXT_ACCENT"))
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0, 0, 0, 0)
                if item.checked then
                    text:SetTextColor(T("ACCENT_HIGHLIGHT"))
                else
                    text:SetTextColor(T("TEXT_PRIMARY"))
                end
            end)
            btn:SetScript("OnClick", function()
                menu:Hide()
                if onSelect then
                    onSelect(item.value, item.text)
                end
            end)

            yPos = yPos - itemHeight
        end
    end

    local timeOutside = 0
    menu:SetScript("OnUpdate", function(self, elapsed)
        if not MouseIsOver(menu) and not MouseIsOver(dropdown) then
            timeOutside = timeOutside + elapsed
            if timeOutside > 0.5 then
                self:Hide()
                self:SetScript("OnUpdate", nil)
            end
        else
            timeOutside = 0
        end
    end)
end

local function CreateInstanceCard(parent, instData, yOffset, onClick)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    card:SetHeight(CARD_HEIGHT)
    card:SetClipsChildren(true)
    card:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    card:SetBackdropColor(T("BG_SECONDARY"))

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

    local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
    nameText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -6)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(instData.name)
    nameText:SetTextColor(T("ACCENT_PRIMARY"))

    local typeStr = instData.instanceType == "raid" and L["JOURNAL_CARD_RAID"]
                 or instData.instanceType == "party" and L["JOURNAL_CARD_DUNGEON"]
                 or ""
    local infoText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    infoText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, 0)
    infoText:SetJustifyH("LEFT")
    infoText:SetText(instData.expansionName .. "  |  " .. typeStr)
    infoText:SetTextColor(T("TEXT_SECONDARY"))

    local encCount = #instData.encounters
    local countText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", 0, -2)
    countText:SetJustifyH("LEFT")
    countText:SetText(string.format(L["JOURNAL_CARD_ENCOUNTERS"], encCount)
                      .. "  |  " .. string.format(L["JOURNAL_CARD_ITEMS"], instData.totalItems))
    countText:SetTextColor(0.6, 0.8, 1.0, 1.0)

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
        local catText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        catText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 8 + ((i - 1) * colWidth), 18)
        catText:SetText(cat.label)
        if cat.flag then
            catText:SetTextColor(cat.color[1], cat.color[2], cat.color[3], 1.0)
        else
            catText:SetTextColor(0.35, 0.35, 0.35, 1.0)
        end
    end
    for i, cat in ipairs(row2) do
        local catText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        catText:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 8 + ((i - 1) * colWidth), 6)
        catText:SetText(cat.label)
        if cat.flag then
            catText:SetTextColor(cat.color[1], cat.color[2], cat.color[3], 1.0)
        else
            catText:SetTextColor(0.35, 0.35, 0.35, 1.0)
        end
    end

    card:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        if self.bgTex then self.bgTex:SetAlpha(0.5) end
    end)
    card:SetScript("OnLeave", function(self)
        if selectedInstance and selectedInstance.instanceID == instData.instanceID then
            self:SetBackdropColor(T("BG_ACTIVE"))
        else
            self:SetBackdropColor(T("BG_SECONDARY"))
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

    local headerText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerText:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    headerText:SetText(L["JOURNAL_COLLECTIONS"])
    headerText:SetTextColor(T("ACCENT_PRIMARY"))
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
        local catLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        catLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", xPos, yOffset)
        catLabel:SetJustifyH("LEFT")
        catLabel:SetText(string.format(L[def.fmt], c.collected, c.total))

        if c.total == 0 then
            catLabel:SetTextColor(0.35, 0.35, 0.35, 1.0)
        elseif c.collected >= c.total then
            catLabel:SetTextColor(0.2, 1.0, 0.2, 1.0)
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

local function RefreshDetailView(isSecondRefresh)
    if not panels_ref or not selectedInstance then return end

    local panels = panels_ref
    local instData = selectedInstance
    local addon = GetDataAddon()

    if panels.emptyDetail then panels.emptyDetail:Hide() end
    ClearDetailElements()

    local parent = panels.detailScrollChild
    local yOffset = -8

    local nameHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    nameHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    nameHeader:SetJustifyH("LEFT")
    nameHeader:SetText(instData.name)
    nameHeader:SetTextColor(T("ACCENT_PRIMARY"))
    table.insert(detailElements, nameHeader)
    yOffset = yOffset - 22

    local typeStr = instData.instanceType == "raid" and L["JOURNAL_CARD_RAID"]
                 or instData.instanceType == "party" and L["JOURNAL_CARD_DUNGEON"]
                 or ""
    local infoLine = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
    infoLine:SetTextColor(T("TEXT_SECONDARY"))
    table.insert(detailElements, infoLine)
    yOffset = yOffset - 20

    local divider1 = parent:CreateTexture(nil, "ARTWORK")
    divider1:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    divider1:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    divider1:SetHeight(1)
    divider1:SetColorTexture(T("BORDER_SUBTLE"))
    table.insert(detailElements, divider1)
    yOffset = yOffset - 8

    yOffset = BuildCollectionsSummary(parent, instData, yOffset, addon)

    local divider2 = parent:CreateTexture(nil, "ARTWORK")
    divider2:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    divider2:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    divider2:SetHeight(1)
    divider2:SetColorTexture(T("BORDER_SUBTLE"))
    table.insert(detailElements, divider2)
    yOffset = yOffset - 10

    local colHdrFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    colHdrFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    colHdrFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
    colHdrFrame:SetHeight(20)
    colHdrFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    colHdrFrame:SetBackdropColor(T("BG_TERTIARY"))
    table.insert(detailElements, colHdrFrame)

    local COL_DIFF_RIGHT    = -220
    local COL_SPECIAL_RIGHT = -130
    local COL_STATUS_RIGHT  = -8

    local hdrItem = colHdrFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrItem:SetPoint("LEFT", colHdrFrame, "LEFT", 8, 0)
    hdrItem:SetText(L["JOURNAL_COL_HDR_ITEM"])
    hdrItem:SetTextColor(T("TEXT_MUTED"))

    local hdrDiff = colHdrFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrDiff:SetPoint("RIGHT", colHdrFrame, "RIGHT", COL_DIFF_RIGHT, 0)
    hdrDiff:SetText(L["JOURNAL_COL_HDR_DIFFICULTY"])
    hdrDiff:SetTextColor(T("TEXT_MUTED"))
    hdrDiff:SetJustifyH("RIGHT")

    local hdrSpecial = colHdrFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrSpecial:SetPoint("RIGHT", colHdrFrame, "RIGHT", COL_SPECIAL_RIGHT, 0)
    hdrSpecial:SetText(L["JOURNAL_COL_HDR_SPECIAL"])
    hdrSpecial:SetTextColor(T("TEXT_MUTED"))
    hdrSpecial:SetJustifyH("RIGHT")

    local hdrStatus = colHdrFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrStatus:SetPoint("RIGHT", colHdrFrame, "RIGHT", COL_STATUS_RIGHT, 0)
    hdrStatus:SetText(L["JOURNAL_COL_HDR_STATUS"])
    hdrStatus:SetTextColor(T("TEXT_MUTED"))
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
        encBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        encBtn:SetBackdropColor(T("BG_SECONDARY"))
        table.insert(detailElements, encBtn)

        local arrowText = encBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        arrowText:SetPoint("LEFT", encBtn, "LEFT", 8, 0)
        arrowText:SetText(isExpanded and "v" or ">")
        arrowText:SetTextColor(T("TEXT_MUTED"))

        local encName = encBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        encName:SetPoint("LEFT", arrowText, "RIGHT", 6, 0)
        encName:SetText(encounter.name)
        encName:SetTextColor(T("ACCENT_PRIMARY"))

        local itemCountStr = string.format(L["JOURNAL_ITEMS_COUNT"], #filteredItems)
        if #filteredItems ~= #encounter.items then
            itemCountStr = string.format(L["JOURNAL_ITEMS_FILTERED"], #filteredItems, #encounter.items)
        end
        local encCount = encBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        encCount:SetPoint("RIGHT", encBtn, "RIGHT", -8, 0)
        encCount:SetText(itemCountStr)
        encCount:SetTextColor(T("TEXT_MUTED"))

        local capturedEncID = encounter.encounterID
        encBtn:SetScript("OnClick", function()
            expandedEncounters[capturedEncID] = not expandedEncounters[capturedEncID]
            RefreshDetailView(false)
        end)
        encBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)
        encBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_SECONDARY"))
        end)

        yOffset = yOffset - 30

        if isExpanded and #filteredItems > 0 then
            for _, item in ipairs(filteredItems) do
                local itemRow = CreateFrame("Frame", nil, parent, "BackdropTemplate")
                itemRow:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
                itemRow:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
                itemRow:SetHeight(ITEM_ROW_HEIGHT)
                itemRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                itemRow:SetBackdropColor(T("BG_PRIMARY"))
                table.insert(detailElements, itemRow)

                local iconFrame = CreateFrame("Frame", nil, itemRow, "BackdropTemplate")
                iconFrame:SetSize(26, 26)
                iconFrame:SetPoint("LEFT", itemRow, "LEFT", 6, 0)
                iconFrame:SetBackdrop({
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
                local qColor = QUALITY_COLORS[item.quality] or QUALITY_COLORS[1]
                iconFrame:SetBackdropBorderColor(qColor[1], qColor[2], qColor[3], 0.6)
                table.insert(detailElements, iconFrame)

                local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
                iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
                iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
                iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                iconTex:SetTexture(item.icon or 134400)

                local itemName = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                itemName:SetPoint("LEFT", iconFrame, "RIGHT", 8, 0)
                itemName:SetPoint("RIGHT", itemRow, "RIGHT", COL_DIFF_RIGHT - 10, 0)
                itemName:SetJustifyH("LEFT")
                itemName:SetWordWrap(false)
                itemName:SetText(item.name)
                itemName:SetTextColor(qColor[1], qColor[2], qColor[3], 1.0)

                local diffText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                diffText:SetPoint("RIGHT", itemRow, "RIGHT", COL_DIFF_RIGHT, 0)
                diffText:SetJustifyH("RIGHT")
                diffText:SetText(FormatDifficulties(item.difficulties))
                diffText:SetTextColor(T("TEXT_MUTED"))

                local specialText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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

                local statusText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                statusText:SetPoint("RIGHT", itemRow, "RIGHT", COL_STATUS_RIGHT, 0)
                statusText:SetJustifyH("RIGHT")
                if item.special and addon and addon.JournalData then
                    local status = addon.JournalData:DetermineItemStatus(item.itemID, item.itemData, item.special)
                    if status then
                        statusText:SetText(status)
                        local isCollected = addon.JournalData:IsItemCollected(item.itemID, item.itemData, item.special)
                        if isCollected then
                            statusText:SetTextColor(0.2, 1.0, 0.2, 1.0)
                        else
                            statusText:SetTextColor(0.8, 0.3, 0.3, 1.0)
                        end
                    else
                        statusText:SetText("")
                    end
                else
                    statusText:SetText("")
                end

                itemRow:EnableMouse(true)
                itemRow:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(T("BG_HOVER"))
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(item.itemID)
                    GameTooltip:Show()
                end)
                itemRow:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(T("BG_PRIMARY"))
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
            panels.diffDropdown.label:SetText(L["JOURNAL_DIFF_ALL"])

            panels.diffDropdown:SetScript("OnClick", function(self)
                local menuItems = {
                    { text = L["JOURNAL_DIFF_ALL"], value = "all", checked = (selectedDifficulty == "all") },
                }
                for _, diff in ipairs(diffs) do
                    table.insert(menuItems, {
                        text = diff.name or "?",
                        value = diff.id,
                        checked = (tostring(selectedDifficulty) == tostring(diff.id)),
                    })
                end
                ShowDropdownMenu(self, menuItems, function(value, text)
                    selectedDifficulty = value
                    self.label:SetText(text)
                    RefreshDetailView(false)
                end)
            end)
        else
            panels.diffDropdown:Hide()
        end
    end

    selectedDifficulty = "all"
    RefreshDetailView(false)
end

local function RefreshJournalList(panels)
    ClearInstanceList()

    local addon = GetDataAddon()
    if not addon or not addon.JournalData then
        panels.listScrollChild:SetHeight(100)
        panels.UpdateListThumb()
        return
    end

    local sorted = addon.JournalData:GetSortedInstances(expansionFilter, searchText, instanceTypeFilter)

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
                    btn:SetBackdropColor(T("BG_ACTIVE"))
                else
                    btn:SetBackdropColor(T("BG_SECONDARY"))
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

local function InitializeDropdowns(panels)
    local addon = GetDataAddon()
    if not addon then return end

    if panels.expDropdown then
        panels.expDropdown.label:SetText(L["JOURNAL_EXPANSION_ALL"])
        panels.expDropdown:SetScript("OnClick", function(self)
            local menuItems = {
                { text = L["JOURNAL_EXPANSION_ALL"], value = 0, checked = (expansionFilter == 0) },
            }
            local expansions = addon.JournalData:GetAvailableExpansions()
            for _, exp in ipairs(expansions) do
                table.insert(menuItems, {
                    text = exp.displayName,
                    value = exp.expansionID,
                    checked = (expansionFilter == exp.expansionID),
                })
            end
            ShowDropdownMenu(self, menuItems, function(value, text)
                expansionFilter = value
                self.label:SetText(text)
                RefreshJournalList(panels)
            end)
        end)
    end

    if panels.itemFilterDropdown then
        panels.itemFilterDropdown.label:SetText(L["JOURNAL_FILTER_SHOW_ALL"])
        panels.itemFilterDropdown:SetScript("OnClick", function(self)
            local menuItems = {
                { text = L["JOURNAL_FILTER_SHOW_ALL"], value = "all",     checked = (filterItemType == "all") },
                { isSeparator = true },
                { text = L["JOURNAL_FILTER_TMOG"],     value = "tmog",    checked = (filterItemType == "tmog") },
                { text = L["JOURNAL_FILTER_MOUNTS"],   value = "mounts",  checked = (filterItemType == "mounts") },
                { text = L["JOURNAL_FILTER_PETS"],     value = "pets",    checked = (filterItemType == "pets") },
                { text = L["JOURNAL_FILTER_RECIPES"],  value = "recipes", checked = (filterItemType == "recipes") },
                { text = L["JOURNAL_FILTER_TOYS"],     value = "toys",    checked = (filterItemType == "toys") },
                { text = L["JOURNAL_FILTER_QUEST"],    value = "quest",   checked = (filterItemType == "quest") },
                { text = L["JOURNAL_FILTER_HOUSING"],  value = "housing", checked = (filterItemType == "housing") },
            }
            ShowDropdownMenu(self, menuItems, function(value, text)
                filterItemType = value
                self.label:SetText(text)
                if selectedInstance then
                    RefreshDetailView(false)
                end
            end)
        end)
    end

    if panels.collectionFilterDropdown then
        panels.collectionFilterDropdown.label:SetText(L["JOURNAL_FILTER_SHOW_ALL"])
        panels.collectionFilterDropdown:SetScript("OnClick", function(self)
            local menuItems = {
                { text = L["JOURNAL_FILTER_SHOW_ALL"],        value = "all",          checked = (filterCollection == "all") },
                { text = L["JOURNAL_FILTER_COLLECTED"],       value = "collected",    checked = (filterCollection == "collected") },
                { text = L["JOURNAL_FILTER_NOT_COLLECTED"],   value = "notcollected", checked = (filterCollection == "notcollected") },
            }
            ShowDropdownMenu(self, menuItems, function(value, text)
                filterCollection = value
                self.label:SetText(text)
                if selectedInstance then
                    RefreshDetailView(false)
                end
            end)
        end)
    end
end

function ns.UI.CreateJournalTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP    = ns.Constants.GUI.PANEL_GAP
    local HDR_H  = 80

    local leftHeader = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    leftHeader:SetHeight(HDR_H)
    leftHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    leftHeader:SetWidth(LEFT_W)
    leftHeader:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    leftHeader:SetBackdropColor(T("BG_TERTIARY"))
    leftHeader:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local rightHeader = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rightHeader:SetHeight(HDR_H)
    rightHeader:SetPoint("TOPLEFT", leftHeader, "TOPRIGHT", GAP, 0)
    rightHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    rightHeader:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    rightHeader:SetBackdropColor(T("BG_TERTIARY"))
    rightHeader:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -GAP)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local panels = ns.UI.CreateSplitPanel(contentArea)
    panels.listTitle:SetText(L["JOURNAL_LIST_TITLE"])
    panels.detailTitle:SetText(L["JOURNAL_DETAIL_TITLE"])

    -- LEFT HEADER: Row 1 - Search + Clear button
    local searchBox = CreateFrame("EditBox", nil, leftHeader, "BackdropTemplate")
    searchBox:SetHeight(26)
    searchBox:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", leftHeader, "TOPRIGHT", -42, -8)
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
    placeholder:SetText(L["JOURNAL_SEARCH"])
    placeholder:SetTextColor(T("TEXT_MUTED"))

    local clearBtn = CreateFrame("Button", nil, leftHeader, "BackdropTemplate")
    clearBtn:SetSize(34, 26)
    clearBtn:SetPoint("TOPLEFT", searchBox, "TOPRIGHT", 4, 0)
    clearBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    clearBtn:SetBackdropColor(T("BG_SECONDARY"))
    clearBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    local clearBtnText = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clearBtnText:SetPoint("CENTER")
    clearBtnText:SetText(L["JOURNAL_FILTER_CLEAR"])
    clearBtnText:SetTextColor(T("TEXT_PRIMARY"))
    clearBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
        clearBtnText:SetTextColor(T("TEXT_ACCENT"))
    end)
    clearBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        clearBtnText:SetTextColor(T("TEXT_PRIMARY"))
    end)

    -- LEFT HEADER: Row 2 - Expansion label + dropdown
    local expLabel = leftHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expLabel:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -38)
    expLabel:SetText(L["JOURNAL_LABEL_EXPANSION"])
    expLabel:SetTextColor(T("TEXT_MUTED"))

    local expDropdown = CreateThemedDropdown(leftHeader, LEFT_W - 16, L["JOURNAL_EXPANSION_ALL"])
    expDropdown:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -54)

    -- RIGHT HEADER: Row 1 left - Instance Type label + [All][Raids][Dungeons] buttons
    local typeLabel = rightHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", 8, -8)
    typeLabel:SetText(L["JOURNAL_LABEL_INST_TYPE"])
    typeLabel:SetTextColor(T("TEXT_MUTED"))

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
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(T("BG_SECONDARY"))
        btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("CENTER", 0, 0)
        lbl:SetText(def.text)
        lbl:SetTextColor(T("TEXT_PRIMARY"))
        btn:SetWidth(math.max(30, lbl:GetStringWidth() + BTN_PAD_X * 2))

        btn.highlight = btn:CreateTexture(nil, "OVERLAY")
        btn.highlight:SetAllPoints()
        btn.highlight:SetColorTexture(T("ACCENT_PRIMARY"))
        btn.highlight:SetAlpha(0.15)
        btn.highlight:Hide()

        btn:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", xOff, -22)
        xOff = xOff + btn:GetWidth() + BTN_GAP

        btn.value = def.value
        btn.label = lbl
        table.insert(typeButtons, btn)

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)
        btn:SetScript("OnLeave", function(self)
            if instanceTypeFilter == self.value then
                self:SetBackdropColor(T("BG_ACTIVE"))
            else
                self:SetBackdropColor(T("BG_SECONDARY"))
            end
        end)
        btn:SetScript("OnClick", function(self)
            instanceTypeFilter = self.value
            for _, b in ipairs(typeButtons) do
                if b.value == instanceTypeFilter then
                    b:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                    b:SetBackdropColor(T("BG_ACTIVE"))
                    b.highlight:Show()
                else
                    b:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                    b:SetBackdropColor(T("BG_SECONDARY"))
                    b.highlight:Hide()
                end
            end
            RefreshJournalList(panels)
        end)
    end

    -- Set initial active state on All button
    for _, b in ipairs(typeButtons) do
        if b.value == "all" then
            b:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
            b:SetBackdropColor(T("BG_ACTIVE"))
            b.highlight:Show()
        end
    end

    -- RIGHT HEADER: Row 1 right - Collection + Item Type dropdowns with labels
    local collectionFilterDropdown = CreateThemedDropdown(rightHeader, 130, L["JOURNAL_FILTER_SHOW_ALL"])
    collectionFilterDropdown:SetPoint("TOPRIGHT", rightHeader, "TOPRIGHT", -8, -22)

    local collLabel = rightHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collLabel:SetPoint("BOTTOMLEFT", collectionFilterDropdown, "TOPLEFT", 0, 2)
    collLabel:SetText(L["JOURNAL_LABEL_COLLECTION"])
    collLabel:SetTextColor(T("TEXT_MUTED"))

    local itemFilterDropdown = CreateThemedDropdown(rightHeader, 130, L["JOURNAL_FILTER_SHOW_ALL"])
    itemFilterDropdown:SetPoint("TOPRIGHT", collectionFilterDropdown, "TOPLEFT", -6, 0)

    local itemTypeLabel = rightHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemTypeLabel:SetPoint("BOTTOMLEFT", itemFilterDropdown, "TOPLEFT", 0, 2)
    itemTypeLabel:SetText(L["JOURNAL_LABEL_ITEM_TYPE"])
    itemTypeLabel:SetTextColor(T("TEXT_MUTED"))

    -- RIGHT HEADER: Row 2 - Hide Non-Collectable checkbox
    local chkBox = CreateFrame("Button", nil, rightHeader, "BackdropTemplate")
    chkBox:SetSize(16, 16)
    chkBox:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", 8, -54)
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

    local chkLabel = rightHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chkLabel:SetPoint("LEFT", chkBox, "RIGHT", 6, 0)
    chkLabel:SetText(L["JOURNAL_HIDE_NON_COLLECTABLE"])
    chkLabel:SetTextColor(T("TEXT_PRIMARY"))

    chkBox:SetScript("OnClick", function(self)
        hideNonCollectable = not hideNonCollectable
        if hideNonCollectable then
            chkMark:Show()
            self:SetBackdropBorderColor(T("BORDER_FOCUS"))
        else
            chkMark:Hide()
            self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        end
        if selectedInstance then
            RefreshDetailView(false)
        end
    end)

    -- Clear button resets all filters
    clearBtn:SetScript("OnClick", function()
        searchText         = ""
        expansionFilter    = 0
        instanceTypeFilter = "all"
        filterItemType     = "all"
        filterCollection   = "all"
        hideNonCollectable = false
        searchBox:SetText("")
        placeholder:Show()
        expDropdown.label:SetText(L["JOURNAL_EXPANSION_ALL"])
        itemFilterDropdown.label:SetText(L["JOURNAL_FILTER_SHOW_ALL"])
        collectionFilterDropdown.label:SetText(L["JOURNAL_FILTER_SHOW_ALL"])
        chkMark:Hide()
        chkBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        for _, b in ipairs(typeButtons) do
            if b.value == "all" then
                b:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                b:SetBackdropColor(T("BG_ACTIVE"))
                b.highlight:Show()
            else
                b:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                b:SetBackdropColor(T("BG_SECONDARY"))
                b.highlight:Hide()
            end
        end
        RefreshJournalList(panels)
        if selectedInstance then
            RefreshDetailView(false)
        end
    end)

    -- Search box behavior
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
            RefreshJournalList(panels)
        end)
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    -- Empty state labels
    local emptyList = panels.listScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyList:SetPoint("CENTER", panels.listScrollChild, "CENTER", 0, 0)
    emptyList:SetTextColor(T("TEXT_MUTED"))
    panels.emptyList = emptyList

    local emptyDetail = panels.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyDetail:SetPoint("CENTER", panels.detailPanel, "CENTER", 0, 0)
    emptyDetail:SetTextColor(T("TEXT_MUTED"))
    panels.emptyDetail = emptyDetail

    -- Difficulty dropdown stays in detail panel
    local diffDropdown = CreateThemedDropdown(panels.detailPanel, 180, L["JOURNAL_DIFF_ALL"])
    diffDropdown:SetPoint("TOPLEFT", panels.detailPanel, "TOPLEFT", 8, -28)
    diffDropdown:Hide()
    panels.diffDropdown = diffDropdown

    panels.detailScrollFrame:ClearAllPoints()
    panels.detailScrollFrame:SetPoint("TOPLEFT", panels.detailPanel, "TOPLEFT", 0, -58)
    panels.detailScrollFrame:SetPoint("BOTTOMRIGHT", panels.detailPanel, "BOTTOMRIGHT", -18, 8)

    panels.expDropdown             = expDropdown
    panels.itemFilterDropdown      = itemFilterDropdown
    panels.collectionFilterDropdown = collectionFilterDropdown

    ns.UI.journalPanels = panels
    panels_ref = panels

    local addon = GetDataAddon()
    if addon then
        emptyList:SetText(L["JOURNAL_EMPTY"])
        emptyDetail:SetText(L["JOURNAL_SELECT"])
        panels.detailScrollChild:SetHeight(100)

        if addon.RegisterScanCallback then
            addon:RegisterScanCallback(function()
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
        if panels_ref.expDropdown then
            panels_ref.expDropdown.label:SetText(instData.expansionName)
        end
        RefreshJournalList(panels_ref)
        ShowInstanceDetail(panels_ref, instData)
        for _, btn in ipairs(instanceListButtons) do
            if btn.instData and btn.instData.instanceID == instData.instanceID then
                btn:SetBackdropColor(T("BG_ACTIVE"))
            else
                btn:SetBackdropColor(T("BG_SECONDARY"))
            end
        end
    end)
end
