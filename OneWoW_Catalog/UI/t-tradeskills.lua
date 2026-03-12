-- OneWoW Addon File
-- OneWoW_Catalog/UI/t-tradeskills.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local dataAddon = nil
local selectedProfession = nil
local selectedRecipe = nil
local currentSearch = ""
local panels = nil
local detailElements = {}
local listElements = {}
local profButtons = {}
local searchBox = nil
local emptyList = nil
local emptyDetail = nil
local searchTimer = nil
local controlPanel = nil
local recipeDetailCallbacks = {}
local filterKnownByMe = false
local filterKnownByAlts = false
local filterExpansion = nil

_G.OneWoW_Catalog_TradeskillAPI = {
    RegisterRecipeCallback = function(callback)
        table.insert(recipeDetailCallbacks, callback)
    end,
}

local RECIPE_ROW_HEIGHT = 30
local REAGENT_ROW_HEIGHT = 28
local PROF_BTN_HEIGHT = 22
local PROF_BTN_PAD_X = 8
local PROF_BTN_GAP = 3
local PROF_HEADER_H = 58

local QUALITY_COLORS = ns.Constants.QUALITY_COLORS

local EXPANSION_DISPLAY = {
    Classic = "Classic",
    BurningCrusade = "The Burning Crusade",
    WrathOfTheLichKing = "Wrath of the Lich King",
    Cataclysm = "Cataclysm",
    MistsOfPandaria = "Mists of Pandaria",
    WarlordsOfDraenor = "Warlords of Draenor",
    Legion = "Legion",
    BattleForAzeroth = "Battle for Azeroth",
    Shadowlands = "Shadowlands",
    Dragonflight = "Dragonflight",
    TheWarWithin = "The War Within",
    Midnight = "Midnight",
}

local expandedExpansions = {}

local RefreshRecipeList
local ShowRecipeDetail

local function GetDataAddon()
    if dataAddon then return dataAddon end
    if ns.Catalog and ns.Catalog.GetDataAddon then
        dataAddon = ns.Catalog:GetDataAddon("tradeskills")
    end
    return dataAddon
end

local function GetCurrentCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if name and realm then
        return realm .. "-" .. name
    end
    return nil
end

local function FilterByKnown(recipes, addon)
    if not filterKnownByMe and not filterKnownByAlts then return recipes end
    local charKey = GetCurrentCharKey()
    local filtered = {}
    for _, recipe in ipairs(recipes) do
        local knownBy = addon.TradeskillScanner:GetRecipeKnownBy(recipe.id)
        if knownBy and #knownBy > 0 then
            local knownByMe = false
            local knownByAlt = false
            for _, key in ipairs(knownBy) do
                if key == charKey then
                    knownByMe = true
                else
                    knownByAlt = true
                end
            end
            if (filterKnownByMe and knownByMe) or (filterKnownByAlts and knownByAlt) then
                table.insert(filtered, recipe)
            end
        end
    end
    return filtered
end

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

local function UpdateProfButtonStates()
    for _, btn in ipairs(profButtons) do
        local isActive = false
        if btn.isAllButton then
            isActive = (selectedProfession == nil)
        else
            isActive = (selectedProfession and btn.profName == selectedProfession.name)
        end
        if isActive then
            btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
            btn:SetBackdropColor(T("BG_ACTIVE"))
            btn.highlight:Show()
        else
            btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            btn:SetBackdropColor(T("BG_SECONDARY"))
            btn.highlight:Hide()
        end
    end
end

local function GetLocalizedProfName(profData)
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
        local name = C_TradeSkillUI.GetTradeSkillDisplayName(profData.id)
        if name and name ~= "" then return name end
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(profData.id)
        if info and info.professionName and info.professionName ~= "" then
            return info.professionName
        end
    end
    return profData.name
end

local function CreateProfTextButton(parent, displayText, profData, isAllButton)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(PROF_BTN_HEIGHT)
    btn:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8x8",
        edgeFile = "Interface\\BUTTONS\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(T("BG_SECONDARY"))
    btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(displayText)
    label:SetTextColor(T("TEXT_PRIMARY"))

    local textWidth = label:GetStringWidth()
    btn:SetWidth(math.max(30, textWidth + PROF_BTN_PAD_X * 2))

    btn.label = label
    btn.isAllButton = isAllButton or false
    btn.profName = profData and profData.name or nil
    btn.profData = profData

    btn.highlight = btn:CreateTexture(nil, "OVERLAY")
    btn.highlight:SetAllPoints()
    btn.highlight:SetColorTexture(T("ACCENT_PRIMARY"))
    btn.highlight:SetAlpha(0.15)
    btn.highlight:Hide()

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
    end)
    btn:SetScript("OnLeave", function(self)
        local isActive = false
        if self.isAllButton then
            isActive = (selectedProfession == nil)
        else
            isActive = (selectedProfession and self.profName == selectedProfession.name)
        end
        if isActive then
            self:SetBackdropColor(T("BG_ACTIVE"))
        else
            self:SetBackdropColor(T("BG_SECONDARY"))
        end
    end)
    btn:SetScript("OnClick", function(self)
        if self.isAllButton then
            selectedProfession = nil
        else
            selectedProfession = self.profData
        end
        selectedRecipe = nil
        wipe(expandedExpansions)
        UpdateProfButtonStates()
        RefreshRecipeList()
        ClearDetailElements()
        if emptyDetail then
            emptyDetail:SetText(L["TRADESKILLS_SELECT"])
            emptyDetail:Show()
        end
        for _, cb in ipairs(recipeDetailCallbacks) do
            cb(nil, nil, panels)
        end
    end)

    return btn
end

local function CreateRecipeRow(parent, recipe, yOffset, rowIdx, onClick)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(RECIPE_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    row:SetBackdrop({bgFile = "Interface\\BUTTONS\\WHITE8x8"})

    if rowIdx % 2 == 0 then
        row:SetBackdropColor(T("BG_PRIMARY"))
    else
        row:SetBackdropColor(T("BG_SECONDARY"))
    end

    local iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
    iconFrame:SetSize(24, 24)
    iconFrame:SetPoint("LEFT", 4, 0)
    iconFrame:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8x8",
        edgeFile = "Interface\\BUTTONS\\WHITE8x8",
        edgeSize = 1,
    })
    iconFrame:SetBackdropColor(0, 0, 0, 1)
    iconFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)

    local addon = GetDataAddon()
    if addon and recipe.item and recipe.item > 0 then
        local cached = addon.DataLoader:GetCachedItem(recipe.item)
        if cached and cached.name then
            nameText:SetText(cached.name)
            local qc = QUALITY_COLORS[cached.quality] or QUALITY_COLORS[1]
            nameText:SetTextColor(unpack(qc))
            icon:SetTexture(cached.icon or recipe.icon)
        else
            nameText:SetText("...")
            nameText:SetTextColor(T("TEXT_MUTED"))
            icon:SetTexture(recipe.icon)
            addon.DataLoader:LoadItemData(recipe.item, function(itemID, itemData)
                if row:IsVisible() and itemData then
                    nameText:SetText(itemData.name)
                    local qc = QUALITY_COLORS[itemData.quality] or QUALITY_COLORS[1]
                    nameText:SetTextColor(unpack(qc))
                    if itemData.icon then
                        icon:SetTexture(itemData.icon)
                    end
                end
            end)
        end
    else
        icon:SetTexture(recipe.icon)
        if C_Spell and C_Spell.GetSpellName then
            local spellName = C_Spell.GetSpellName(recipe.id)
            nameText:SetText(spellName or ("Recipe #" .. recipe.id))
        else
            nameText:SetText("Recipe #" .. recipe.id)
        end
        nameText:SetTextColor(T("TEXT_PRIMARY"))
    end

    row.recipe = recipe
    row.rowIdx = rowIdx

    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        if recipe.item and recipe.item > 0 then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(recipe.item)
            GameTooltip:Show()
        elseif recipe.id then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(recipe.id)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        if selectedRecipe and selectedRecipe.id == recipe.id then
            self:SetBackdropColor(T("BG_ACTIVE"))
        else
            if self.rowIdx % 2 == 0 then
                self:SetBackdropColor(T("BG_PRIMARY"))
            else
                self:SetBackdropColor(T("BG_SECONDARY"))
            end
        end
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self)
        if onClick then onClick(self.recipe) end
    end)

    return row
end

ShowRecipeDetail = function(recipe)
    if not panels or not recipe then return end

    selectedRecipe = recipe
    ClearDetailElements()

    if emptyDetail then emptyDetail:Hide() end

    local addon = GetDataAddon()
    if not addon then return end

    local child = panels.detailScrollChild
    local yOffset = -8

    local headerFrame = CreateFrame("Frame", nil, child, "BackdropTemplate")
    headerFrame:SetHeight(50)
    headerFrame:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
    headerFrame:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
    headerFrame:SetBackdrop({bgFile = "Interface\\BUTTONS\\WHITE8x8"})
    headerFrame:SetBackdropColor(T("BG_SECONDARY"))
    table.insert(detailElements, headerFrame)

    local hIconFrame = CreateFrame("Button", nil, headerFrame, "BackdropTemplate")
    hIconFrame:SetSize(40, 40)
    hIconFrame:SetPoint("LEFT", 8, 0)
    hIconFrame:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8x8",
        edgeFile = "Interface\\BUTTONS\\WHITE8x8",
        edgeSize = 1,
    })
    hIconFrame:SetBackdropColor(0, 0, 0, 1)
    hIconFrame:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local hIcon = hIconFrame:CreateTexture(nil, "ARTWORK")
    hIcon:SetPoint("TOPLEFT", 1, -1)
    hIcon:SetPoint("BOTTOMRIGHT", -1, 1)
    hIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    hIconFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if recipe.item and recipe.item > 0 then
            GameTooltip:SetItemByID(recipe.item)
        elseif recipe.id then
            GameTooltip:SetSpellByID(recipe.id)
        end
        GameTooltip:Show()
    end)
    hIconFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local recipeName = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    recipeName:SetPoint("TOPLEFT", hIconFrame, "TOPRIGHT", 8, -2)
    recipeName:SetPoint("RIGHT", headerFrame, "RIGHT", -8, 0)
    recipeName:SetJustifyH("LEFT")
    recipeName:SetWordWrap(false)

    if recipe.item and recipe.item > 0 then
        local cached = addon.DataLoader:GetCachedItem(recipe.item)
        if cached and cached.name then
            recipeName:SetText(cached.name)
            local qc = QUALITY_COLORS[cached.quality] or QUALITY_COLORS[1]
            recipeName:SetTextColor(unpack(qc))
            hIcon:SetTexture(cached.icon or recipe.icon)
        else
            hIcon:SetTexture(recipe.icon)
            recipeName:SetText("...")
            recipeName:SetTextColor(T("TEXT_MUTED"))
            addon.DataLoader:LoadItemData(recipe.item, function(itemID, itemData)
                if headerFrame:IsVisible() and itemData then
                    recipeName:SetText(itemData.name)
                    local qc = QUALITY_COLORS[itemData.quality] or QUALITY_COLORS[1]
                    recipeName:SetTextColor(unpack(qc))
                    if itemData.icon then
                        hIcon:SetTexture(itemData.icon)
                    end
                end
            end)
        end
    else
        hIcon:SetTexture(recipe.icon)
        if C_Spell and C_Spell.GetSpellName then
            recipeName:SetText(C_Spell.GetSpellName(recipe.id) or ("Recipe #" .. recipe.id))
        else
            recipeName:SetText("Recipe #" .. recipe.id)
        end
        recipeName:SetTextColor(T("TEXT_PRIMARY"))
    end

    local subInfo = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subInfo:SetPoint("TOPLEFT", recipeName, "BOTTOMLEFT", 0, -2)
    local expDisplay = EXPANSION_DISPLAY[recipe.exp] or recipe.exp or ""
    subInfo:SetText(recipe.prof .. "  |  " .. expDisplay)
    subInfo:SetTextColor(T("TEXT_SECONDARY"))

    yOffset = yOffset - 58

    local function AddInfoRow(label, value)
        local row = CreateFrame("Frame", nil, child)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 8, yOffset)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
        table.insert(detailElements, row)

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", 0, 0)
        lbl:SetText(label .. ":")
        lbl:SetTextColor(T("TEXT_MUTED"))
        lbl:SetWidth(100)
        lbl:SetJustifyH("LEFT")

        local val = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        val:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
        val:SetText(value)
        val:SetTextColor(T("TEXT_PRIMARY"))

        yOffset = yOffset - 20
    end

    AddInfoRow(L["TRADESKILLS_RECIPE_ID"], tostring(recipe.id))
    if recipe.item then
        AddInfoRow(L["TRADESKILLS_ITEM_ID"], tostring(recipe.item))
    end
    AddInfoRow(L["TRADESKILLS_PROFESSION"], recipe.prof)
    AddInfoRow(L["TRADESKILLS_EXPANSION"], expDisplay)

    if recipe.qual then
        AddInfoRow(L["TRADESKILLS_QUALITY"], string.format(L["TRADESKILLS_QUALITY_FMT"], recipe.maxQ or 3))
    end
    if recipe.rank then
        AddInfoRow(L["TRADESKILLS_RANK"], string.format(L["TRADESKILLS_RANK"], recipe.rank))
    end

    yOffset = yOffset - 8

    local reagents, slots = addon.TradeskillData:GetRecipeReagents(recipe.id)

    if reagents and #reagents > 0 then
        local reagentHeader = CreateFrame("Frame", nil, child, "BackdropTemplate")
        reagentHeader:SetHeight(24)
        reagentHeader:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
        reagentHeader:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
        reagentHeader:SetBackdrop({bgFile = "Interface\\BUTTONS\\WHITE8x8"})
        reagentHeader:SetBackdropColor(T("BG_TERTIARY"))
        table.insert(detailElements, reagentHeader)

        local reagentTitle = reagentHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        reagentTitle:SetPoint("LEFT", 8, 0)
        reagentTitle:SetText(L["TRADESKILLS_REAGENTS"])
        reagentTitle:SetTextColor(T("ACCENT_PRIMARY"))

        yOffset = yOffset - 28

        for _, rg in ipairs(reagents) do
            local reagentItemID = rg[1]
            local reagentQty = rg[2]
            local reagentType = rg[3]

            local rgRow = CreateFrame("Frame", nil, child, "BackdropTemplate")
            rgRow:SetHeight(REAGENT_ROW_HEIGHT)
            rgRow:SetPoint("TOPLEFT", child, "TOPLEFT", 8, yOffset)
            rgRow:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
            rgRow:SetBackdrop({bgFile = "Interface\\BUTTONS\\WHITE8x8"})
            rgRow:SetBackdropColor(T("BG_PRIMARY"))
            table.insert(detailElements, rgRow)

            local rgIcon = CreateFrame("Frame", nil, rgRow, "BackdropTemplate")
            rgIcon:SetSize(22, 22)
            rgIcon:SetPoint("LEFT", 4, 0)
            rgIcon:SetBackdrop({
                bgFile = "Interface\\BUTTONS\\WHITE8x8",
                edgeFile = "Interface\\BUTTONS\\WHITE8x8",
                edgeSize = 1,
            })
            rgIcon:SetBackdropColor(0, 0, 0, 1)
            rgIcon:SetBackdropBorderColor(T("BORDER_SUBTLE"))

            local rgIconTex = rgIcon:CreateTexture(nil, "ARTWORK")
            rgIconTex:SetPoint("TOPLEFT", 1, -1)
            rgIconTex:SetPoint("BOTTOMRIGHT", -1, 1)
            rgIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            local rgName = rgRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rgName:SetPoint("LEFT", rgIcon, "RIGHT", 6, 0)
            rgName:SetPoint("RIGHT", rgRow, "RIGHT", -60, 0)
            rgName:SetJustifyH("LEFT")
            rgName:SetWordWrap(false)

            local rgQty = rgRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rgQty:SetPoint("RIGHT", rgRow, "RIGHT", -4, 0)
            rgQty:SetWidth(50)
            rgQty:SetJustifyH("RIGHT")
            rgQty:SetText("x" .. reagentQty)

            if reagentType == 0 then
                rgQty:SetTextColor(0.6, 0.8, 0.6, 1.0)
            elseif reagentType == 2 then
                rgQty:SetTextColor(0.4, 0.7, 1.0, 1.0)
            else
                rgQty:SetTextColor(T("TEXT_SECONDARY"))
            end

            local cached = addon.DataLoader:GetCachedItem(reagentItemID)
            if cached and cached.name then
                rgName:SetText(cached.name)
                rgIconTex:SetTexture(cached.icon)
                local qc = QUALITY_COLORS[cached.quality] or QUALITY_COLORS[1]
                rgName:SetTextColor(unpack(qc))
            else
                rgName:SetText("...")
                rgName:SetTextColor(T("TEXT_MUTED"))
                rgIconTex:SetTexture(134400)
                addon.DataLoader:LoadItemData(reagentItemID, function(itemID, itemData)
                    if rgRow:IsVisible() and itemData then
                        rgName:SetText(itemData.name)
                        rgIconTex:SetTexture(itemData.icon)
                        local qc = QUALITY_COLORS[itemData.quality] or QUALITY_COLORS[1]
                        rgName:SetTextColor(unpack(qc))
                    end
                end)
            end

            rgRow:SetScript("OnEnter", function(self)
                self:SetBackdropColor(T("BG_HOVER"))
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(reagentItemID)
                GameTooltip:Show()
            end)
            rgRow:SetScript("OnLeave", function(self)
                self:SetBackdropColor(T("BG_PRIMARY"))
                GameTooltip:Hide()
            end)

            yOffset = yOffset - REAGENT_ROW_HEIGHT
        end

        if slots and #slots > 0 then
            for _, sl in ipairs(slots) do
                local opts = sl[5]
                if opts and #opts > 1 then
                    yOffset = yOffset - 4
                    local slotLabel = CreateFrame("Frame", nil, child)
                    slotLabel:SetHeight(16)
                    slotLabel:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOffset)
                    slotLabel:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
                    table.insert(detailElements, slotLabel)

                    local slotText = slotLabel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    slotText:SetPoint("LEFT", 0, 0)
                    local reqStr = sl[3] and L["TRADESKILLS_REAGENT_REQ"] or L["TRADESKILLS_REAGENT_OPT"]
                    slotText:SetText("Slot " .. sl[1] .. " (" .. reqStr .. ", x" .. sl[2] .. ") - " .. #opts .. " options:")
                    slotText:SetTextColor(T("TEXT_MUTED"))
                    yOffset = yOffset - 18

                    for _, optItemID in ipairs(opts) do
                        local optRow = CreateFrame("Frame", nil, child)
                        optRow:SetHeight(18)
                        optRow:SetPoint("TOPLEFT", child, "TOPLEFT", 28, yOffset)
                        optRow:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
                        table.insert(detailElements, optRow)

                        local optName = optRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        optName:SetPoint("LEFT", 0, 0)

                        local optCached = addon.DataLoader:GetCachedItem(optItemID)
                        if optCached and optCached.name then
                            optName:SetText("- " .. optCached.name)
                            local qc = QUALITY_COLORS[optCached.quality] or QUALITY_COLORS[1]
                            optName:SetTextColor(unpack(qc))
                        else
                            optName:SetText("- ...")
                            optName:SetTextColor(T("TEXT_MUTED"))
                            addon.DataLoader:LoadItemData(optItemID, function(itemID, itemData)
                                if optRow:IsVisible() and itemData then
                                    optName:SetText("- " .. itemData.name)
                                    local qc = QUALITY_COLORS[itemData.quality] or QUALITY_COLORS[1]
                                    optName:SetTextColor(unpack(qc))
                                end
                            end)
                        end

                        optRow:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetItemByID(optItemID)
                            GameTooltip:Show()
                        end)
                        optRow:SetScript("OnLeave", function()
                            GameTooltip:Hide()
                        end)

                        yOffset = yOffset - 18
                    end
                end
            end
        end
    end

    yOffset = yOffset - 12

    local knownByHeader = CreateFrame("Frame", nil, child, "BackdropTemplate")
    knownByHeader:SetHeight(24)
    knownByHeader:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
    knownByHeader:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
    knownByHeader:SetBackdrop({bgFile = "Interface\\BUTTONS\\WHITE8x8"})
    knownByHeader:SetBackdropColor(T("BG_TERTIARY"))
    table.insert(detailElements, knownByHeader)

    local knownByTitle = knownByHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    knownByTitle:SetPoint("LEFT", 8, 0)
    knownByTitle:SetText(L["TRADESKILLS_KNOWN_BY"])
    knownByTitle:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - 28

    local knownBy = addon.TradeskillScanner:GetRecipeKnownBy(recipe.id)
    if knownBy and #knownBy > 0 then
        for _, charKey in ipairs(knownBy) do
            local charRow = CreateFrame("Frame", nil, child)
            charRow:SetHeight(18)
            charRow:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOffset)
            charRow:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
            table.insert(detailElements, charRow)

            local charText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            charText:SetPoint("LEFT", 0, 0)
            charText:SetText(charKey)
            charText:SetTextColor(T("TEXT_PRIMARY"))
            yOffset = yOffset - 18
        end
    else
        local noData = CreateFrame("Frame", nil, child)
        noData:SetHeight(18)
        noData:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOffset)
        noData:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
        table.insert(detailElements, noData)

        local noDataText = noData:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noDataText:SetPoint("LEFT", 0, 0)
        noDataText:SetText(L["TRADESKILLS_NOT_SCANNED"])
        noDataText:SetTextColor(T("TEXT_MUTED"))
        yOffset = yOffset - 18
    end

    yOffset = yOffset - 10
    child:SetHeight(math.abs(yOffset) + 20)

    for _, cb in ipairs(recipeDetailCallbacks) do
        cb(recipe, reagents, panels)
    end
end

local function RecipeClickHandler(recipeData)
    selectedRecipe = recipeData
    for _, el in ipairs(listElements) do
        if el.recipe and el.recipe.id == recipeData.id then
            el:SetBackdropColor(T("BG_ACTIVE"))
        else
            if el.rowIdx and el.rowIdx % 2 == 0 then
                el:SetBackdropColor(T("BG_PRIMARY"))
            else
                el:SetBackdropColor(T("BG_SECONDARY"))
            end
        end
    end
    ShowRecipeDetail(recipeData)
end

local function RefreshRecipeListFlat(recipes)
    local MAX_DISPLAY = 50
    local totalCount = #recipes
    local displayCount = math.min(totalCount, MAX_DISPLAY)

    local yOffset = -4
    local rowIdx = 0
    for i = 1, displayCount do
        local recipe = recipes[i]
        local row = CreateRecipeRow(panels.listScrollChild, recipe, yOffset, rowIdx, RecipeClickHandler)
        table.insert(listElements, row)
        yOffset = yOffset - RECIPE_ROW_HEIGHT
        rowIdx = rowIdx + 1
    end

    panels.listScrollChild:SetHeight(math.abs(yOffset) + 10)

    if panels.leftStatusText then
        if displayCount < totalCount then
            panels.leftStatusText:SetText(string.format(L["TRADESKILLS_RECIPES_FILTERED"], displayCount, totalCount))
        else
            panels.leftStatusText:SetText(string.format(L["TRADESKILLS_RECIPES"], totalCount))
        end
    end
end

local EXP_HEADER_HEIGHT = 28

local function RefreshRecipeListGrouped(recipes, addon)
    local expansions = addon.TradeskillData:GetExpansions()

    local grouped = {}
    for _, recipe in ipairs(recipes) do
        local key = recipe.exp or "Unknown"
        if not grouped[key] then grouped[key] = {} end
        table.insert(grouped[key], recipe)
    end

    local orderedGroups = {}
    for _, exp in ipairs(expansions) do
        if grouped[exp.key] and #grouped[exp.key] > 0 then
            table.insert(orderedGroups, { key = exp.key, order = exp.order, recipes = grouped[exp.key] })
        end
    end
    if grouped["Unknown"] and #grouped["Unknown"] > 0 then
        table.insert(orderedGroups, { key = "Unknown", order = 99, recipes = grouped["Unknown"] })
    end

    table.sort(orderedGroups, function(a, b) return a.order > b.order end)

    if next(expandedExpansions) == nil then
        if #orderedGroups > 0 then
            expandedExpansions[orderedGroups[1].key] = true
        end
    end

    local yOffset = -4
    local totalRecipes = 0

    for _, group in ipairs(orderedGroups) do
        local expKey = group.key
        local expRecipes = group.recipes
        local count = #expRecipes
        totalRecipes = totalRecipes + count
        local isExpanded = expandedExpansions[expKey]
        local displayName = EXPANSION_DISPLAY[expKey] or expKey

        local hdrBtn = CreateFrame("Button", nil, panels.listScrollChild, "BackdropTemplate")
        hdrBtn:SetPoint("TOPLEFT", panels.listScrollChild, "TOPLEFT", 0, yOffset)
        hdrBtn:SetPoint("TOPRIGHT", panels.listScrollChild, "TOPRIGHT", 0, yOffset)
        hdrBtn:SetHeight(EXP_HEADER_HEIGHT)
        hdrBtn:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8x8" })
        hdrBtn:SetBackdropColor(T("BG_TERTIARY"))
        table.insert(listElements, hdrBtn)

        local arrowText = hdrBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        arrowText:SetPoint("LEFT", hdrBtn, "LEFT", 8, 0)
        arrowText:SetText(isExpanded and "v" or ">")
        arrowText:SetTextColor(T("TEXT_MUTED"))

        local expName = hdrBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        expName:SetPoint("LEFT", arrowText, "RIGHT", 6, 0)
        expName:SetText(displayName)
        expName:SetTextColor(T("ACCENT_PRIMARY"))

        local countText = hdrBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        countText:SetPoint("RIGHT", hdrBtn, "RIGHT", -8, 0)
        countText:SetText(string.format(L["TRADESKILLS_RECIPES"], count))
        countText:SetTextColor(T("TEXT_MUTED"))

        local capturedKey = expKey
        hdrBtn:SetScript("OnClick", function()
            expandedExpansions[capturedKey] = not expandedExpansions[capturedKey]
            RefreshRecipeList()
        end)
        hdrBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)
        hdrBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
        end)

        yOffset = yOffset - EXP_HEADER_HEIGHT - 2

        if isExpanded then
            local rowIdx = 0
            for _, recipe in ipairs(expRecipes) do
                local row = CreateRecipeRow(panels.listScrollChild, recipe, yOffset, rowIdx, RecipeClickHandler)
                table.insert(listElements, row)
                yOffset = yOffset - RECIPE_ROW_HEIGHT
                rowIdx = rowIdx + 1
            end
        end

        yOffset = yOffset - 4
    end

    panels.listScrollChild:SetHeight(math.abs(yOffset) + 10)

    if panels.leftStatusText then
        local profLabel = selectedProfession and selectedProfession.name or L["TRADESKILLS_ALL"]
        panels.leftStatusText:SetText(profLabel .. " - " .. string.format(L["TRADESKILLS_RECIPES"], totalRecipes))
    end
end

RefreshRecipeList = function()
    if not panels then return end
    ClearListElements()

    local addon = GetDataAddon()
    if not addon then
        if emptyList then
            emptyList:SetText(L["TRADESKILLS_NO_DATA"])
            emptyList:Show()
        end
        panels.listScrollChild:SetHeight(100)
        return
    end

    local isSearching = currentSearch ~= "" and currentSearch ~= nil
    local recipes

    if selectedProfession then
        recipes = addon.TradeskillData:GetRecipesByProfession(
            selectedProfession.name,
            filterExpansion,
            isSearching and currentSearch or nil
        )
    else
        recipes = {}
        local professions = addon.TradeskillData:GetProfessions()
        for _, prof in ipairs(professions) do
            if prof.hasData then
                local profRecipes = addon.TradeskillData:GetRecipesByProfession(
                    prof.name,
                    filterExpansion,
                    isSearching and currentSearch or nil
                )
                if profRecipes then
                    for _, r in ipairs(profRecipes) do
                        table.insert(recipes, r)
                    end
                end
            end
        end
    end

    if (filterKnownByMe or filterKnownByAlts) and recipes then
        recipes = FilterByKnown(recipes, addon)
    end

    if not recipes or #recipes == 0 then
        if emptyList then
            emptyList:SetText(L["TRADESKILLS_EMPTY"])
            emptyList:Show()
        end
        panels.listScrollChild:SetHeight(100)
        return
    end

    if emptyList then emptyList:Hide() end

    if isSearching or not selectedProfession then
        RefreshRecipeListFlat(recipes)
    else
        RefreshRecipeListGrouped(recipes, addon)
    end
end

function ns.UI.CreateTradeskillsTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP = ns.Constants.GUI.PANEL_GAP

    local SEARCH_HEADER_H = PROF_HEADER_H + 46

    local searchHeader = ns.UI.CreateFilterBar(parent, { height = SEARCH_HEADER_H, offset = 0 })
    searchHeader:ClearAllPoints()
    searchHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    searchHeader:SetWidth(LEFT_W)

    local profHeader = ns.UI.CreateFilterBar(parent, { height = SEARCH_HEADER_H, offset = 0 })
    profHeader:ClearAllPoints()
    profHeader:SetPoint("TOPLEFT", searchHeader, "TOPRIGHT", GAP, 0)
    profHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", searchHeader, "BOTTOMLEFT", 0, -2)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    panels = ns.UI.CreateSplitPanel(contentArea)
    panels.listTitle:SetText(L["TRADESKILLS_LIST_TITLE"])
    panels.detailTitle:SetText(L["TRADESKILLS_DETAIL_TITLE"])

    local addon = GetDataAddon()
    local professions = addon and addon.TradeskillData:GetProfessions() or {}

    local allBtn = CreateProfTextButton(profHeader, L["TRADESKILLS_ALL"], nil, true)
    table.insert(profButtons, allBtn)

    local buttonList = {allBtn}
    for _, prof in ipairs(professions) do
        if prof.hasData then
            local displayName = GetLocalizedProfName(prof)
            local btn = CreateProfTextButton(profHeader, displayName, prof, false)
            table.insert(profButtons, btn)
            table.insert(buttonList, btn)
        end
    end

    local containerWidth = profHeader:GetWidth()
    if containerWidth < 100 then containerWidth = 900 end
    local padLeft = 6
    local padTop = 5
    local xOff = padLeft
    local row = 0
    for _, btn in ipairs(buttonList) do
        local btnWidth = btn:GetWidth()
        if xOff + btnWidth + PROF_BTN_GAP > containerWidth - padLeft and xOff > padLeft then
            row = row + 1
            xOff = padLeft
        end
        local yOff = -padTop - (row * (PROF_BTN_HEIGHT + PROF_BTN_GAP))
        btn:SetPoint("TOPLEFT", profHeader, "TOPLEFT", xOff, yOff)
        xOff = xOff + btnWidth + PROF_BTN_GAP
    end

    searchBox = ns.UI.CreateEditBox(nil, searchHeader, {
        height = 26,
        placeholderText = L["TRADESKILLS_SEARCH"],
        onTextChanged = function(text)
            if searchTimer then searchTimer:Cancel() end
            searchTimer = C_Timer.NewTimer(0.3, function()
                currentSearch = text
                if RefreshRecipeList then RefreshRecipeList() end
            end)
        end,
    })
    searchBox:SetPoint("TOPLEFT", searchHeader, "TOPLEFT", 8, -16)
    searchBox:SetPoint("TOPRIGHT", searchHeader, "TOPRIGHT", -8, -16)

    local knownMeCheck = ns.UI.CreateCheckbox(nil, searchHeader, L["TRADESKILLS_SHOW_KNOWN_ME"])
    knownMeCheck:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -4)
    knownMeCheck:SetChecked(false)
    knownMeCheck:SetScript("OnClick", function(self)
        filterKnownByMe = self:GetChecked()
        RefreshRecipeList()
    end)

    local knownAltsCheck = ns.UI.CreateCheckbox(nil, searchHeader, L["TRADESKILLS_SHOW_KNOWN_ALTS"])
    knownAltsCheck:SetPoint("LEFT", knownMeCheck.label, "RIGHT", 10, 0)
    knownAltsCheck:SetChecked(false)
    knownAltsCheck:SetScript("OnClick", function(self)
        filterKnownByAlts = self:GetChecked()
        RefreshRecipeList()
    end)

    local EXPANSION_OPTIONS = {
        {key = nil,                 label = L["TRADESKILLS_ALL_EXPANSIONS"]},
        {key = "Midnight",          label = EXPANSION_DISPLAY["Midnight"]},
        {key = "TheWarWithin",      label = EXPANSION_DISPLAY["TheWarWithin"]},
        {key = "Dragonflight",      label = EXPANSION_DISPLAY["Dragonflight"]},
        {key = "Shadowlands",       label = EXPANSION_DISPLAY["Shadowlands"]},
        {key = "BattleForAzeroth",  label = EXPANSION_DISPLAY["BattleForAzeroth"]},
        {key = "Legion",            label = EXPANSION_DISPLAY["Legion"]},
        {key = "WarlordsOfDraenor", label = EXPANSION_DISPLAY["WarlordsOfDraenor"]},
        {key = "MistsOfPandaria",   label = EXPANSION_DISPLAY["MistsOfPandaria"]},
        {key = "Cataclysm",         label = EXPANSION_DISPLAY["Cataclysm"]},
        {key = "WrathOfTheLichKing",label = EXPANSION_DISPLAY["WrathOfTheLichKing"]},
        {key = "BurningCrusade",    label = EXPANSION_DISPLAY["BurningCrusade"]},
        {key = "Classic",           label = EXPANSION_DISPLAY["Classic"]},
    }

    local expDropdown, expDropText = ns.UI.CreateDropdown(searchHeader, {
        width = 10,
        height = 22,
        text = L["TRADESKILLS_ALL_EXPANSIONS"],
    })
    expDropdown:SetPoint("TOPLEFT", knownMeCheck, "BOTTOMLEFT", 0, -4)
    expDropdown:SetPoint("RIGHT", searchHeader, "RIGHT", -8, 0)

    ns.UI.AttachFilterMenu(expDropdown, expDropText, {
        searchable = false,
        getActiveValue = function() return filterExpansion end,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(EXPANSION_OPTIONS) do
                table.insert(items, { value = opt.key, text = opt.label })
            end
            return items
        end,
        onSelect = function(value, text)
            filterExpansion = value
            expDropText:SetText(value and text or L["TRADESKILLS_ALL_EXPANSIONS"])
            wipe(expandedExpansions)
            RefreshRecipeList()
        end,
    })

    emptyList = panels.listScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyList:SetPoint("CENTER", panels.listScrollChild, "CENTER", 0, 0)
    emptyList:SetTextColor(T("TEXT_MUTED"))

    emptyDetail = panels.detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyDetail:SetPoint("CENTER", panels.detailScrollChild, "CENTER", 0, 0)
    emptyDetail:SetText(L["TRADESKILLS_SELECT"])
    emptyDetail:SetTextColor(T("TEXT_MUTED"))
    panels.detailScrollChild:SetHeight(100)

    ns.UI.tradeskillsPanels = panels

    if addon then
        emptyList:SetText(L["TRADESKILLS_SELECT"])
        addon:RegisterScanCallback(function()
            if selectedProfession and RefreshRecipeList then
                RefreshRecipeList()
            end
        end)

        if professions and #professions > 0 then
            for _, prof in ipairs(professions) do
                if prof.hasData then
                    selectedProfession = prof
                    break
                end
            end
            UpdateProfButtonStates()
            C_Timer.After(0.1, function()
                if RefreshRecipeList then RefreshRecipeList() end
            end)
        end
    else
        emptyList:SetText(L["TRADESKILLS_NO_DATA"])
        panels.listScrollChild:SetHeight(100)
        C_Timer.After(2.0, function()
            local retryAddon = GetDataAddon()
            if retryAddon then
                emptyList:SetText(L["TRADESKILLS_SELECT"])
                retryAddon:RegisterScanCallback(function()
                    if selectedProfession and RefreshRecipeList then RefreshRecipeList() end
                end)
                local profs = retryAddon.TradeskillData:GetProfessions()
                if profs and #profs > 0 then
                    for _, prof in ipairs(profs) do
                        if prof.hasData then
                            selectedProfession = prof
                            break
                        end
                    end
                    UpdateProfButtonStates()
                    if RefreshRecipeList then RefreshRecipeList() end
                end
            end
        end)
    end
end
