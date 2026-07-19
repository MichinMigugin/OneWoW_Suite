local _, ns = ...

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

local ipairs = ipairs
local tinsert, sort = tinsert, sort
local C_TradeSkillUI, C_Spell, C_Timer = C_TradeSkillUI, C_Spell, C_Timer

local L = ns.L
ns.UI = ns.UI or {}

local selectedProfession = nil
local selectedRecipe = nil
local currentSearch = ""
local panels = nil
local detailElements = {}
local listEntries = {}
local recipeListAPI = nil
local profButtons = {}
local searchBox = nil
local emptyList = nil
local emptyDetail = nil
local searchTimer = nil
local recipeDetailCallbacks = {}
local filterKnownByMe = false
local filterKnownByAlts = false
local filterNotKnownByMe = false
local filterNotKnownByAlts = false
local filterExpansion = nil

OneWoW_Catalog_TradeskillAPI = {
    RegisterRecipeCallback = function(callback)
        tinsert(recipeDetailCallbacks, callback)
    end,
}

local RECIPE_ROW_HEIGHT = 30
local REAGENT_ROW_HEIGHT = 28
local PROF_BTN_HEIGHT = 22
local PROF_BTN_PAD_X = 8
local PROF_BTN_GAP = 3
local PROF_HEADER_H = 58
local LIST_ROW_STRIDE = RECIPE_ROW_HEIGHT

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
    return OneWoW_CatalogData_Tradeskills_API
end

local function FilterByKnown(recipes, addon)
    if not filterKnownByMe and not filterKnownByAlts
        and not filterNotKnownByMe and not filterNotKnownByAlts then
        return recipes
    end
    local charKey = OneWoW_GUI:BuildCharKey()
    local filtered = {}
    for _, recipe in ipairs(recipes) do
        local knownBy = addon.GetRecipeKnownBy(recipe.id)
        local knownByMe = false
        local knownByAlt = false
        if knownBy then
            for _, key in ipairs(knownBy) do
                if key == charKey then
                    knownByMe = true
                else
                    knownByAlt = true
                end
            end
        end

        local include = true
        if filterKnownByMe and not knownByMe then include = false end
        if filterNotKnownByMe and knownByMe then include = false end
        if filterKnownByAlts and not knownByAlt then include = false end
        if filterNotKnownByAlts and knownByAlt then include = false end

        if include then
            tinsert(filtered, recipe)
        end
    end
    return filtered
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

local function GetLocalizedProfName(profData)
    local name = C_TradeSkillUI.GetTradeSkillDisplayName(profData.id)
    if name and name ~= "" then return name end

    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(profData.id)
    if info and info.professionName and info.professionName ~= "" then
        return info.professionName
    end

    return profData.name
end

local function CreateProfTextButton(parent, displayText, profData, isAllButton)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(PROF_BTN_HEIGHT)
    btn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local label = OneWoW_GUI:CreateFS(btn, 10)
    label:SetPoint("CENTER", 0, 0)
    label:SetText(displayText)
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local textWidth = label:GetStringWidth()
    btn:SetWidth(math.max(30, textWidth + PROF_BTN_PAD_X * 2))

    btn.label = label
    btn.isAllButton = isAllButton or false
    btn.profName = profData and profData.name or nil
    btn.profData = profData

    btn.highlight = btn:CreateTexture(nil, "OVERLAY")
    btn.highlight:SetAllPoints()
    btn.highlight:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    btn.highlight:SetAlpha(0.15)
    btn.highlight:Hide()

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)
    btn:SetScript("OnLeave", function(self)
        local isActive = false
        if self.isAllButton then
            isActive = (selectedProfession == nil)
        else
            isActive = (selectedProfession and self.profName == selectedProfession.name)
        end
        if isActive then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
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

local function ApplyRecipeRowChrome(row, selected, zebraEven)
    if selected then
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
    elseif row.entry and row.entry.type == "header" then
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    else
        if zebraEven then
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        else
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        end
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end
end

local function CreateRecipeListRow(parent, _)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(LIST_ROW_STRIDE)
    row:SetBackdrop(BACKDROP_SIMPLE)
    ApplyRecipeRowChrome(row, false, false)

    local iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
    iconFrame:SetSize(24, 24)
    iconFrame:SetPoint("LEFT", 4, 0)
    iconFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    iconFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    row.iconFrame = iconFrame

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local nameText = OneWoW_GUI:CreateFS(row, 10)
    nameText:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local arrowText = OneWoW_GUI:CreateFS(row, 12)
    arrowText:SetPoint("LEFT", row, "LEFT", 8, 0)
    arrowText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    arrowText:Hide()
    row.arrowText = arrowText

    local headerName = OneWoW_GUI:CreateFS(row, 12)
    headerName:SetPoint("LEFT", arrowText, "RIGHT", 6, 0)
    headerName:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    headerName:Hide()
    row.headerName = headerName

    local countText = OneWoW_GUI:CreateFS(row, 10)
    countText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    countText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    countText:Hide()
    row.countText = countText

    row:SetScript("OnEnter", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        local entry = myself.entry
        if entry and entry.type == "recipe" and entry.recipe then
            local recipe = entry.recipe
            if recipe.item and recipe.item > 0 then
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(recipe.item)
                GameTooltip:Show()
            elseif recipe.id then
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(recipe.id)
                GameTooltip:Show()
            end
        end
    end)
    row:SetScript("OnLeave", function(myself)
        ApplyRecipeRowChrome(myself, myself._rowSelected, myself._zebraEven)
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(myself)
        local entry = myself.entry
        if not entry then
            return
        end
        if entry.type == "header" then
            expandedExpansions[entry.expKey] = not expandedExpansions[entry.expKey]
            RefreshRecipeList()
        elseif entry.type == "recipe" and recipeListAPI and myself.entryIndex then
            recipeListAPI.SetSelectedIndex(myself.entryIndex)
        end
    end)

    return row
end

local function BindRecipeListRow(row, index, entry, state)
    row.entry = entry
    row._rowSelected = state.selected and entry.type == "recipe" or false
    row._zebraEven = (index % 2 == 0)

    if entry.type == "header" then
        row.iconFrame:Hide()
        row.nameText:Hide()
        row.arrowText:Show()
        row.headerName:Show()
        row.countText:Show()
        row.arrowText:SetText(expandedExpansions[entry.expKey] and "v" or ">")
        row.headerName:SetText(entry.displayName or entry.expKey or "")
        row.countText:SetText(string.format(L["TRADESKILLS_RECIPES"], entry.count or 0))
        ApplyRecipeRowChrome(row, false, false)
        return
    end

    row.arrowText:Hide()
    row.headerName:Hide()
    row.countText:Hide()
    row.iconFrame:Show()
    row.nameText:Show()
    ApplyRecipeRowChrome(row, row._rowSelected, row._zebraEven)

    local recipe = entry.recipe
    local addon = GetDataAddon()
    local bindToken = recipe and recipe.id
    row._bindToken = bindToken

    if addon and recipe and recipe.item and recipe.item > 0 then
        local cached = addon.GetCachedItem(recipe.item)
        if cached and cached.name then
            row.nameText:SetText(cached.name)
            row.nameText:SetTextColor(OneWoW_GUI:GetItemQualityColor(cached.quality))
            row.icon:SetTexture(cached.icon or recipe.icon)
        else
            row.nameText:SetText("...")
            row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            row.icon:SetTexture(recipe.icon)
            addon.LoadItemData(recipe.item, function(_, itemData)
                if row:IsVisible() and row._bindToken == bindToken and itemData then
                    row.nameText:SetText(itemData.name)
                    row.nameText:SetTextColor(OneWoW_GUI:GetItemQualityColor(itemData.quality))
                    if itemData.icon then
                        row.icon:SetTexture(itemData.icon)
                    end
                end
            end)
        end
    else
        row.icon:SetTexture(recipe and recipe.icon)
        local spellName = recipe and C_Spell.GetSpellName(recipe.id)
        row.nameText:SetText(spellName or (recipe and ("Recipe #" .. recipe.id)) or "")
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
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
    headerFrame:SetBackdrop(BACKDROP_SIMPLE)
    headerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    headerFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    tinsert(detailElements, headerFrame)

    local hIconFrame = CreateFrame("Button", nil, headerFrame, "BackdropTemplate")
    hIconFrame:SetSize(40, 40)
    hIconFrame:SetPoint("LEFT", 8, 0)
    hIconFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    hIconFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    hIconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

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
    hIconFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local recipeName = OneWoW_GUI:CreateFS(headerFrame, 16)
    recipeName:SetPoint("TOPLEFT", hIconFrame, "TOPRIGHT", 8, -2)
    recipeName:SetPoint("RIGHT", headerFrame, "RIGHT", -8, 0)
    recipeName:SetJustifyH("LEFT")
    recipeName:SetWordWrap(false)

    if recipe.item and recipe.item > 0 then
        local cached = addon.GetCachedItem(recipe.item)
        if cached and cached.name then
            recipeName:SetText(cached.name)
            recipeName:SetTextColor(OneWoW_GUI:GetItemQualityColor(cached.quality))
            hIcon:SetTexture(cached.icon or recipe.icon)
        else
            hIcon:SetTexture(recipe.icon)
            recipeName:SetText("...")
            recipeName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            addon.LoadItemData(recipe.item, function(_, itemData)
                if headerFrame:IsVisible() and itemData then
                    recipeName:SetText(itemData.name)
                    recipeName:SetTextColor(OneWoW_GUI:GetItemQualityColor(itemData.quality))
                    if itemData.icon then
                        hIcon:SetTexture(itemData.icon)
                    end
                end
            end)
        end
    else
        hIcon:SetTexture(recipe.icon)
        recipeName:SetText(C_Spell.GetSpellName(recipe.id) or ("Recipe #" .. recipe.id))
        recipeName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end

    local subInfo = OneWoW_GUI:CreateFS(headerFrame, 10)
    subInfo:SetPoint("TOPLEFT", recipeName, "BOTTOMLEFT", 0, -2)
    local expDisplay = EXPANSION_DISPLAY[recipe.exp] or recipe.exp or ""
    subInfo:SetText(recipe.prof .. "  |  " .. expDisplay)
    subInfo:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 58

    local function AddInfoRow(label, value)
        local row = CreateFrame("Frame", nil, child)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 8, yOffset)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
        tinsert(detailElements, row)

        local lbl = OneWoW_GUI:CreateFS(row, 10)
        lbl:SetPoint("LEFT", 0, 0)
        lbl:SetText(label .. ":")
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        lbl:SetWidth(100)
        lbl:SetJustifyH("LEFT")

        local val = OneWoW_GUI:CreateFS(row, 10)
        val:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
        val:SetText(value)
        val:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        yOffset = yOffset - 20
    end

    AddInfoRow(L["TRADESKILLS_RECIPE_ID"], tostring(recipe.id))
    if recipe.item then
        AddInfoRow(L["TRADESKILLS_ITEM_ID"], tostring(recipe.item))
    end
    AddInfoRow(L["TRADESKILLS_PROFESSION"], recipe.prof)
    AddInfoRow(L["EXPANSION"], expDisplay)

    if recipe.qual then
        AddInfoRow(QUALITY, string.format(L["TRADESKILLS_QUALITY_FMT"], recipe.maxQ or 3))
    end
    if recipe.rank then
        AddInfoRow(L["TRADESKILLS_RANK"], string.format(L["TRADESKILLS_RANK"], recipe.rank))
    end

    yOffset = yOffset - 8

    -- Recipe scroll/book (not crafted output); SetItemByID feeds TooltipEngine + ATT.
    local recipeItemID = OneWoW.RecipeKnownUtil:GetRecipeItemID(recipe.id)
    if recipeItemID then
        local recipeItemHeader = CreateFrame("Frame", nil, child, "BackdropTemplate")
        recipeItemHeader:SetHeight(24)
        recipeItemHeader:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
        recipeItemHeader:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
        recipeItemHeader:SetBackdrop(BACKDROP_SIMPLE)
        recipeItemHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        recipeItemHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        tinsert(detailElements, recipeItemHeader)

        local recipeItemTitle = OneWoW_GUI:CreateFS(recipeItemHeader, 12)
        recipeItemTitle:SetPoint("LEFT", 8, 0)
        recipeItemTitle:SetText(L["TRADESKILLS_RECIPE_ITEM"])
        recipeItemTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        yOffset = yOffset - 28

        local riRow = CreateFrame("Frame", nil, child, "BackdropTemplate")
        riRow:SetHeight(REAGENT_ROW_HEIGHT)
        riRow:SetPoint("TOPLEFT", child, "TOPLEFT", 8, yOffset)
        riRow:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
        riRow:SetBackdrop(BACKDROP_SIMPLE)
        riRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        riRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        tinsert(detailElements, riRow)

        local riIcon = CreateFrame("Frame", nil, riRow, "BackdropTemplate")
        riIcon:SetSize(22, 22)
        riIcon:SetPoint("LEFT", 4, 0)
        riIcon:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        riIcon:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        riIcon:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local riIconTex = riIcon:CreateTexture(nil, "ARTWORK")
        riIconTex:SetPoint("TOPLEFT", 1, -1)
        riIconTex:SetPoint("BOTTOMRIGHT", -1, 1)
        riIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local riName = OneWoW_GUI:CreateFS(riRow, 10)
        riName:SetPoint("LEFT", riIcon, "RIGHT", 6, 0)
        riName:SetPoint("RIGHT", riRow, "RIGHT", -4, 0)
        riName:SetJustifyH("LEFT")
        riName:SetWordWrap(false)

        local riCached = addon.GetCachedItem(recipeItemID)
        if riCached and riCached.name then
            riName:SetText(riCached.name)
            riIconTex:SetTexture(riCached.icon)
            riName:SetTextColor(OneWoW_GUI:GetItemQualityColor(riCached.quality))
        else
            riName:SetText("...")
            riName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            riIconTex:SetTexture(134400)
            addon.LoadItemData(recipeItemID, function(_, itemData)
                if riRow:IsVisible() and itemData then
                    riName:SetText(itemData.name)
                    riIconTex:SetTexture(itemData.icon)
                    riName:SetTextColor(OneWoW_GUI:GetItemQualityColor(itemData.quality))
                end
            end)
        end

        riRow:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(recipeItemID)
            GameTooltip:Show()
        end)
        riRow:SetScript("OnLeave", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            GameTooltip:Hide()
        end)

        yOffset = yOffset - REAGENT_ROW_HEIGHT - 8
    end

    local reagents, slots = addon.GetRecipeReagents(recipe.id)

    if reagents and #reagents > 0 then
        local reagentHeader = CreateFrame("Frame", nil, child, "BackdropTemplate")
        reagentHeader:SetHeight(24)
        reagentHeader:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
        reagentHeader:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
        reagentHeader:SetBackdrop(BACKDROP_SIMPLE)
        reagentHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        reagentHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        tinsert(detailElements, reagentHeader)

        local reagentTitle = OneWoW_GUI:CreateFS(reagentHeader, 12)
        reagentTitle:SetPoint("LEFT", 8, 0)
        reagentTitle:SetText(L["TRADESKILLS_REAGENTS"])
        reagentTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        yOffset = yOffset - 28

        for _, rg in ipairs(reagents) do
            local reagentItemID = rg[1]
            local reagentQty = rg[2]
            local reagentType = rg[3]

            if reagentType == 0 then
                -- skip, displayed in slots section below
            else

            local rgRow = CreateFrame("Frame", nil, child, "BackdropTemplate")
            rgRow:SetHeight(REAGENT_ROW_HEIGHT)
            rgRow:SetPoint("TOPLEFT", child, "TOPLEFT", 8, yOffset)
            rgRow:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
            rgRow:SetBackdrop(BACKDROP_SIMPLE)
            rgRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
            rgRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            tinsert(detailElements, rgRow)

            local rgIcon = CreateFrame("Frame", nil, rgRow, "BackdropTemplate")
            rgIcon:SetSize(22, 22)
            rgIcon:SetPoint("LEFT", 4, 0)
            rgIcon:SetBackdrop(BACKDROP_INNER_NO_INSETS)
            rgIcon:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
            rgIcon:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local rgIconTex = rgIcon:CreateTexture(nil, "ARTWORK")
            rgIconTex:SetPoint("TOPLEFT", 1, -1)
            rgIconTex:SetPoint("BOTTOMRIGHT", -1, 1)
            rgIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            local rgName = OneWoW_GUI:CreateFS(rgRow, 10)
            rgName:SetPoint("LEFT", rgIcon, "RIGHT", 6, 0)
            rgName:SetPoint("RIGHT", rgRow, "RIGHT", -60, 0)
            rgName:SetJustifyH("LEFT")
            rgName:SetWordWrap(false)

            local rgQty = OneWoW_GUI:CreateFS(rgRow, 10)
            rgQty:SetPoint("RIGHT", rgRow, "RIGHT", -4, 0)
            rgQty:SetWidth(50)
            rgQty:SetJustifyH("RIGHT")
            rgQty:SetText("x" .. reagentQty)

            if reagentType == 0 then
                rgQty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            elseif reagentType == 2 then
                rgQty:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
            else
                rgQty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            end

            local cached = addon.GetCachedItem(reagentItemID)
            if cached and cached.name then
                rgName:SetText(cached.name)
                rgIconTex:SetTexture(cached.icon)
                rgName:SetTextColor(OneWoW_GUI:GetItemQualityColor(cached.quality))
            else
                rgName:SetText("...")
                rgName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                rgIconTex:SetTexture(134400)
                addon.LoadItemData(reagentItemID, function(_, itemData)
                    if rgRow:IsVisible() and itemData then
                        rgName:SetText(itemData.name)
                        rgIconTex:SetTexture(itemData.icon)
                        rgName:SetTextColor(OneWoW_GUI:GetItemQualityColor(itemData.quality))
                    end
                end)
            end

            rgRow:SetScript("OnEnter", function(self)
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(reagentItemID)
                GameTooltip:Show()
            end)
            rgRow:SetScript("OnLeave", function(self)
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                GameTooltip:Hide()
            end)

            yOffset = yOffset - REAGENT_ROW_HEIGHT

            end
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
                    tinsert(detailElements, slotLabel)

                    local slotText = OneWoW_GUI:CreateFS(slotLabel, 10)
                    slotText:SetPoint("LEFT", 0, 0)
                    local reqStr = sl[3] and L["TRADESKILLS_REAGENT_REQ"] or L["TRADESKILLS_REAGENT_OPT"]
                    slotText:SetText("Slot " .. sl[1] .. " (" .. reqStr .. ", x" .. sl[2] .. ") - " .. #opts .. " options:")
                    slotText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    yOffset = yOffset - 18

                    for _, optItemID in ipairs(opts) do
                        local optRow = CreateFrame("Frame", nil, child)
                        optRow:SetHeight(18)
                        optRow:SetPoint("TOPLEFT", child, "TOPLEFT", 28, yOffset)
                        optRow:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
                        tinsert(detailElements, optRow)

                        local optName = OneWoW_GUI:CreateFS(optRow, 10)
                        optName:SetPoint("LEFT", 0, 0)

                        local optCached = addon.GetCachedItem(optItemID)
                        if optCached and optCached.name then
                            optName:SetText("- " .. optCached.name)
                            optName:SetTextColor(OneWoW_GUI:GetItemQualityColor(optCached.quality))
                        else
                            optName:SetText("- ...")
                            optName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                            addon.LoadItemData(optItemID, function(_, itemData)
                                if optRow:IsVisible() and itemData then
                                    optName:SetText("- " .. itemData.name)
                                    optName:SetTextColor(OneWoW_GUI:GetItemQualityColor(itemData.quality))
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
    knownByHeader:SetBackdrop(BACKDROP_SIMPLE)
    knownByHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    knownByHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    tinsert(detailElements, knownByHeader)

    local knownByTitle = OneWoW_GUI:CreateFS(knownByHeader, 12)
    knownByTitle:SetPoint("LEFT", 8, 0)
    knownByTitle:SetText(L["TRADESKILLS_KNOWN_BY"])
    knownByTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - 28

    local knownBy = addon.GetRecipeKnownBy(recipe.id)
    if knownBy and #knownBy > 0 then
        for _, charKey in ipairs(knownBy) do
            local charRow = CreateFrame("Frame", nil, child)
            charRow:SetHeight(18)
            charRow:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOffset)
            charRow:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
            tinsert(detailElements, charRow)

            local charText = OneWoW_GUI:CreateFS(charRow, 10)
            charText:SetPoint("LEFT", 0, 0)
            charText:SetText(charKey)
            charText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            yOffset = yOffset - 18
        end
    else
        local noData = CreateFrame("Frame", nil, child)
        noData:SetHeight(18)
        noData:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOffset)
        noData:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
        tinsert(detailElements, noData)

        local noDataText = OneWoW_GUI:CreateFS(noData, 10)
        noDataText:SetPoint("LEFT", 0, 0)
        noDataText:SetText(L["TRADESKILLS_NOT_SCANNED"])
        noDataText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        yOffset = yOffset - 18
    end

    yOffset = yOffset - 10
    child:SetHeight(math.abs(yOffset) + 20)

    local requiredReagents = {}
    if reagents then
        for _, rg in ipairs(reagents) do
            if rg[3] ~= 0 then
                tinsert(requiredReagents, rg)
            end
        end
    end

    for _, cb in ipairs(recipeDetailCallbacks) do
        cb(recipe, requiredReagents, panels)
    end
end

local function PublishRecipeList(totalRecipes, statusText)
    local keepID = selectedRecipe and selectedRecipe.id
    local keepIndex = nil
    if keepID then
        for i, entry in ipairs(listEntries) do
            if entry.type == "recipe" and entry.recipe and entry.recipe.id == keepID then
                keepIndex = i
                break
            end
        end
    end

    if recipeListAPI then
        if keepIndex then
            recipeListAPI.SetSelectedIndex(keepIndex)
        else
            recipeListAPI.SetSelectedIndex(nil)
            recipeListAPI.Refresh()
        end
    end

    if panels.leftStatusText then
        panels.leftStatusText:SetText(statusText or string.format(L["TRADESKILLS_RECIPES"], totalRecipes or 0))
    end
end

local function BuildFlatRecipeEntries(recipes)
    wipe(listEntries)
    for _, recipe in ipairs(recipes) do
        tinsert(listEntries, { type = "recipe", recipe = recipe })
    end
    local totalCount = #recipes
    PublishRecipeList(totalCount, string.format(L["TRADESKILLS_RECIPES"], totalCount))
end

local function BuildGroupedRecipeEntries(recipes, addon)
    wipe(listEntries)
    local expansions = addon.GetExpansions()

    local grouped = {}
    for _, recipe in ipairs(recipes) do
        local key = recipe.exp or "Unknown"
        if not grouped[key] then grouped[key] = {} end
        tinsert(grouped[key], recipe)
    end

    local orderedGroups = {}
    for _, exp in ipairs(expansions) do
        if grouped[exp.key] and #grouped[exp.key] > 0 then
            tinsert(orderedGroups, { key = exp.key, order = exp.order, recipes = grouped[exp.key] })
        end
    end
    if grouped["Unknown"] and #grouped["Unknown"] > 0 then
        tinsert(orderedGroups, { key = "Unknown", order = 99, recipes = grouped["Unknown"] })
    end

    sort(orderedGroups, function(a, b) return a.order > b.order end)

    local totalRecipes = 0
    for _, group in ipairs(orderedGroups) do
        local expKey = group.key
        local expRecipes = group.recipes
        local count = #expRecipes
        totalRecipes = totalRecipes + count
        tinsert(listEntries, {
            type = "header",
            expKey = expKey,
            count = count,
            displayName = EXPANSION_DISPLAY[expKey] or expKey,
        })
        if expandedExpansions[expKey] then
            for _, recipe in ipairs(expRecipes) do
                tinsert(listEntries, { type = "recipe", recipe = recipe })
            end
        end
    end

    local profLabel = selectedProfession and selectedProfession.name or L["TRADESKILLS_ALL"]
    PublishRecipeList(totalRecipes, profLabel .. " - " .. string.format(L["TRADESKILLS_RECIPES"], totalRecipes))
end

RefreshRecipeList = function()
    if not panels then return end
    wipe(listEntries)

    local addon = GetDataAddon()
    if not addon then
        if emptyList then
            emptyList:SetText(L["TRADESKILLS_NO_DATA"])
            emptyList:Show()
        end
        if recipeListAPI then
            recipeListAPI.SetSelectedIndex(nil)
        end
        return
    end

    local isSearching = currentSearch ~= "" and currentSearch ~= nil
    local recipes

    if selectedProfession then
        recipes = addon.GetRecipesByProfession(
            selectedProfession.name,
            filterExpansion,
            isSearching and currentSearch or nil
        )
    else
        recipes = {}
        local professions = addon.GetProfessions()
        for _, prof in ipairs(professions) do
            if prof.hasData then
                local profRecipes = addon.GetRecipesByProfession(
                    prof.name,
                    filterExpansion,
                    isSearching and currentSearch or nil
                )
                if profRecipes then
                    for _, r in ipairs(profRecipes) do
                        tinsert(recipes, r)
                    end
                end
            end
        end
    end

    if (filterKnownByMe or filterKnownByAlts or filterNotKnownByMe or filterNotKnownByAlts) and recipes then
        recipes = FilterByKnown(recipes, addon)
    end

    if not recipes or #recipes == 0 then
        if emptyList then
            emptyList:SetText(L["TRADESKILLS_EMPTY"])
            emptyList:Show()
        end
        if recipeListAPI then
            recipeListAPI.SetSelectedIndex(nil)
        end
        return
    end

    if emptyList then emptyList:Hide() end

    if isSearching or not selectedProfession then
        BuildFlatRecipeEntries(recipes)
    else
        BuildGroupedRecipeEntries(recipes, addon)
    end
end

function ns.UI.CreateTradeskillsTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP = ns.Constants.GUI.PANEL_GAP

    local SEARCH_HEADER_H = PROF_HEADER_H + 88
    local KNOWN_FILTER_COL_OFFSET = 148

    local searchHeader = OneWoW_GUI:CreateFilterBar(parent, { height = SEARCH_HEADER_H, offset = 0 })
    searchHeader:ClearAllPoints()
    searchHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    searchHeader:SetWidth(LEFT_W)

    local profHeader = OneWoW_GUI:CreateFilterBar(parent, { height = SEARCH_HEADER_H, offset = 0 })
    profHeader:ClearAllPoints()
    profHeader:SetPoint("TOPLEFT", searchHeader, "TOPRIGHT", GAP, 0)
    profHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", searchHeader, "BOTTOMLEFT", 0, -2)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    panels = OneWoW_GUI:CreateSplitPanel(contentArea)
    panels.listTitle:SetText(L["TRADESKILLS_LIST_TITLE"])
    panels.detailTitle:SetText(L["TRADESKILLS_DETAIL_TITLE"])

    recipeListAPI = OneWoW_GUI:CreateVirtualizer(panels.listPanel, {
        name = "CatalogTradeskillsList",
        rowHeight = LIST_ROW_STRIDE,
        minRowHeight = LIST_ROW_STRIDE,
        numVisibleRows = 20,
        rowInset = 0,
        selectOnClick = false,
        scrollFrame = panels.listScrollFrame,
        content = panels.listScrollChild,
        getCount = function()
            return #listEntries
        end,
        getEntry = function(index)
            return listEntries[index]
        end,
        onSelect = function(_, entry)
            if entry and entry.type == "recipe" and entry.recipe then
                ShowRecipeDetail(entry.recipe)
            end
        end,
        createRow = CreateRecipeListRow,
        bindRow = BindRecipeListRow,
    })
    panels.virtualizedList = recipeListAPI

    local buttonList = {}

    local function LayoutProfButtons()
        local w = profHeader:GetWidth()
        if not w or w < 100 then return end
        local padLeft = 6
        local padTop = 5
        local xOff = padLeft
        local row = 0
        for _, btn in ipairs(buttonList) do
            local btnWidth = btn:GetWidth()
            if xOff + btnWidth + PROF_BTN_GAP > w - padLeft and xOff > padLeft then
                row = row + 1
                xOff = padLeft
            end
            local yOff = -padTop - (row * (PROF_BTN_HEIGHT + PROF_BTN_GAP))
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", profHeader, "TOPLEFT", xOff, yOff)
            xOff = xOff + btnWidth + PROF_BTN_GAP
        end
    end

    -- (Re)build the profession filter buttons from current data. Tradeskills data
    -- registers in onLogin (after the tab may have been rebuilt on the load
    -- boundary), so the data-ready watcher calls this again to surface the
    -- profession list without a reload.
    local function BuildProfButtons()
        for _, btn in ipairs(profButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
        wipe(profButtons)
        wipe(buttonList)

        local addon = GetDataAddon()
        local professions = addon and addon.GetProfessions() or {}

        local allBtn = CreateProfTextButton(profHeader, L["TRADESKILLS_ALL"], nil, true)
        tinsert(profButtons, allBtn)
        tinsert(buttonList, allBtn)

        for _, prof in ipairs(professions) do
            if prof.hasData then
                local displayName = GetLocalizedProfName(prof)
                local btn = CreateProfTextButton(profHeader, displayName, prof, false)
                tinsert(profButtons, btn)
                tinsert(buttonList, btn)
            end
        end

        LayoutProfButtons()
    end

    BuildProfButtons()

    profHeader:SetScript("OnSizeChanged", function()
        LayoutProfButtons()
    end)
    C_Timer.After(0, function()
        LayoutProfButtons()
    end)

    searchBox = OneWoW_GUI:CreateEditBox(searchHeader, {
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
    searchBox:SetPoint("TOPLEFT", searchHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", searchHeader, "TOPRIGHT", -8, -8)

    local knownMeCheck = OneWoW_GUI:CreateCheckbox(searchHeader, { label = L["TRADESKILLS_SHOW_KNOWN_ME"] })
    knownMeCheck:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -4)
    knownMeCheck:SetChecked(false)

    local notKnownMeCheck = OneWoW_GUI:CreateCheckbox(searchHeader, { label = L["TRADESKILLS_SHOW_NOT_KNOWN_ME"] })
    notKnownMeCheck:SetPoint("LEFT", knownMeCheck, "LEFT", KNOWN_FILTER_COL_OFFSET, 0)
    notKnownMeCheck:SetChecked(false)

    local knownAltsCheck = OneWoW_GUI:CreateCheckbox(searchHeader, { label = L["TRADESKILLS_SHOW_KNOWN_ALTS"] })
    knownAltsCheck:SetPoint("TOPLEFT", knownMeCheck, "BOTTOMLEFT", 0, -2)
    knownAltsCheck:SetChecked(false)

    local notKnownAltsCheck = OneWoW_GUI:CreateCheckbox(searchHeader, { label = L["TRADESKILLS_SHOW_NOT_KNOWN_ALTS"] })
    notKnownAltsCheck:SetPoint("LEFT", knownAltsCheck, "LEFT", KNOWN_FILTER_COL_OFFSET, 0)
    notKnownAltsCheck:SetChecked(false)

    local function WireKnownFilterPair(knownCheck, notKnownCheck, setKnown, setNotKnown)
        knownCheck:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            setKnown(checked)
            if checked then
                setNotKnown(false)
                notKnownCheck:SetChecked(false)
            end
            RefreshRecipeList()
        end)
        notKnownCheck:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            setNotKnown(checked)
            if checked then
                setKnown(false)
                knownCheck:SetChecked(false)
            end
            RefreshRecipeList()
        end)
    end

    WireKnownFilterPair(knownMeCheck, notKnownMeCheck,
        function(v) filterKnownByMe = v end,
        function(v) filterNotKnownByMe = v end)
    WireKnownFilterPair(knownAltsCheck, notKnownAltsCheck,
        function(v) filterKnownByAlts = v end,
        function(v) filterNotKnownByAlts = v end)

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

    local expDropdown, expDropText = OneWoW_GUI:CreateDropdown(searchHeader, {
        width = 10,
        height = 22,
        text = L["TRADESKILLS_ALL_EXPANSIONS"],
    })
    expDropdown:SetPoint("TOPLEFT", knownAltsCheck, "BOTTOMLEFT", 0, -4)
    expDropdown:SetPoint("RIGHT", searchHeader, "RIGHT", -8, 0)

    OneWoW_GUI:AttachFilterMenu(expDropdown, {
        searchable = false,
        getActiveValue = function() return filterExpansion end,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(EXPANSION_OPTIONS) do
                tinsert(items, { value = opt.key, text = opt.label })
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

    emptyList = OneWoW_GUI:CreateFS(panels.listScrollFrame, 12)
    emptyList:SetPoint("CENTER", panels.listScrollFrame, "CENTER", 0, 0)
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    emptyDetail = OneWoW_GUI:CreateFS(panels.detailScrollChild, 12)
    emptyDetail:SetPoint("CENTER", panels.detailScrollChild, "CENTER", 0, 0)
    emptyDetail:SetText(L["TRADESKILLS_SELECT"])
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.detailScrollChild:SetHeight(100)

    ns.UI.tradeskillsPanels = panels

    -- Start in the no-data state; the data-ready watcher swaps to the live view,
    -- rebuilds the profession buttons, and wires the scan callback once the
    -- Tradeskills data unit's data is queryable. Catch-up covers a tab opened
    -- after data was already ready; the signal covers a mid-session load. `wired`
    -- keeps scan-callback registration idempotent.
    if GetDataAddon() then
        emptyList:SetText(L["TRADESKILLS_SELECT"])
    else
        emptyList:SetText(L["TRADESKILLS_NO_DATA"])
        panels.listScrollChild:SetHeight(100)
    end

    local wired = false
    OneWoW:RegisterDataReadyWatcher("OneWoW_CatalogData_Tradeskills", function()
        local addon = GetDataAddon()
        if not addon then return end
        emptyList:SetText(L["TRADESKILLS_SELECT"])
        BuildProfButtons()
        if not wired then
            wired = true
            addon.RegisterScanCallback(function()
                if selectedProfession and RefreshRecipeList then
                    RefreshRecipeList()
                end
            end)
        end
    end)

    parent:SetScript("OnShow", function()
        selectedProfession = nil
        selectedRecipe = nil
        currentSearch = ""
        filterKnownByMe = false
        filterKnownByAlts = false
        filterNotKnownByMe = false
        filterNotKnownByAlts = false
        filterExpansion = nil
        wipe(expandedExpansions)

        if searchBox then searchBox:SetText("") end
        if knownMeCheck then knownMeCheck:SetChecked(false) end
        if knownAltsCheck then knownAltsCheck:SetChecked(false) end
        if notKnownMeCheck then notKnownMeCheck:SetChecked(false) end
        if notKnownAltsCheck then notKnownAltsCheck:SetChecked(false) end
        if expDropText then expDropText:SetText(L["TRADESKILLS_ALL_EXPANSIONS"]) end

        UpdateProfButtonStates()
        ClearDetailElements()
        if emptyDetail then
            emptyDetail:SetText(L["TRADESKILLS_SELECT"])
            emptyDetail:Show()
        end
        if RefreshRecipeList then RefreshRecipeList() end
    end)
end
