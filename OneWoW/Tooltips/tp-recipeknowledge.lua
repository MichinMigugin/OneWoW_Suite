local ADDON_NAME, OneWoW = ...

local PROFESSION_SKILL_IDS = {
    171, 164, 333, 202, 182,
    773, 755, 165, 186, 393,
    197, 185, 356, 129, 794,
}

local PROFESSION_ABBR_BY_ID = {
    [171] = "ALC",
    [164] = "BS",
    [333] = "ENCH",
    [202] = "ENG",
    [182] = "HERB",
    [773] = "INSC",
    [755] = "JC",
    [165] = "LW",
    [186] = "MIN",
    [393] = "SKIN",
    [197] = "TAIL",
    [185] = "COOK",
    [356] = "FISH",
    [129] = "FA",
    [794] = "ARCH",
}

local professionNameCache = {}

local function GetLocalizedProfessionName(skillID)
    if professionNameCache[skillID] then return professionNameCache[skillID] end
    local name = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName and C_TradeSkillUI.GetTradeSkillDisplayName(skillID)
    if not name or name == "" then
        local fallback = {
            [171]="Alchemy", [164]="Blacksmithing", [333]="Enchanting", [202]="Engineering",
            [182]="Herbalism", [773]="Inscription", [755]="Jewelcrafting", [165]="Leatherworking",
            [186]="Mining", [393]="Skinning", [197]="Tailoring", [185]="Cooking",
            [356]="Fishing", [129]="First Aid", [794]="Archaeology",
        }
        name = fallback[skillID] or tostring(skillID)
    end
    professionNameCache[skillID] = name
    return name
end

local function GetAllProfessionNames()
    local names = {}
    for _, skillID in ipairs(PROFESSION_SKILL_IDS) do
        names[#names + 1] = GetLocalizedProfessionName(skillID)
    end
    return names
end

local function GetProfessionAbbr(profName)
    for skillID, abbr in pairs(PROFESSION_ABBR_BY_ID) do
        if GetLocalizedProfessionName(skillID) == profName then
            return abbr
        end
    end
    return profName
end

local function ProfNamesMatch(storedName, searchName)
    if not storedName or not searchName then return false end
    if storedName == searchName then return true end
    return storedName:sub(-(#searchName + 1)) == " " .. searchName
end

local function FindRecipes(charData, profName)
    if not charData.recipes then return nil end
    if charData.recipes[profName] then return charData.recipes[profName] end
    local suffix = " " .. profName
    for key, recipes in pairs(charData.recipes) do
        if key:sub(-#suffix) == suffix then return recipes end
    end
    return nil
end

local GetClassColor = OneWoW.GetClassColor

local function DetectProfession(itemID)
    local td = C_TooltipInfo.GetItemByID(itemID)
    if not td or not td.lines then return nil end
    local profNames = GetAllProfessionNames()
    local lastMatch = nil
    for _, line in ipairs(td.lines) do
        if line.leftText then
            local text = line.leftText
            for _, profName in ipairs(profNames) do
                if text:find(profName, 1, true) then
                    lastMatch = profName
                    break
                end
            end
        end
    end
    return lastMatch
end

local function RecipeKnowledgeProvider(tooltip, context)
    if not context.itemID then return nil end

    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(context.itemID)
    if classID ~= Enum.ItemClass.Recipe then return nil end

    local profName = DetectProfession(context.itemID)
    if not profName then return nil end

    local profsDB = _G.OneWoW_AltTracker_Professions_DB
    local charDB  = _G.OneWoW_AltTracker_Character_DB
    if not profsDB or not profsDB.characters then return nil end

    local Util           = OneWoW.RecipeKnownUtil
    local L              = OneWoW.L
    local currentCharKey = UnitName("player") .. "-" .. GetRealmName()
    local currentKnows   = Util and Util:IsRecipeKnown(context.itemID)

    local knownBy  = {}
    local unknownBy = {}

    for charKey, charData in pairs(profsDB.characters) do
        if charData.professions then
            local hasProfession = false
            for _, profData in pairs(charData.professions) do
                if ProfNamesMatch(profData.name, profName) then
                    hasProfession = true
                    break
                end
            end

            if hasProfession then
                local meta  = charDB and charDB.characters and charDB.characters[charKey]
                local name  = meta and meta.name  or charKey
                local realm = meta and meta.realm or ""
                local class = meta and meta.class

                local knowsRecipe
                if charKey == currentCharKey then
                    knowsRecipe = currentKnows
                else
                    local recipeSet = FindRecipes(charData, profName)
                    if recipeSet and Util then
                        knowsRecipe = Util:IsAltRecipeKnown(recipeSet, context.itemID)
                    else
                        knowsRecipe = false
                    end
                end

                local entry = {
                    name         = name,
                    realm        = realm,
                    class        = class,
                    knowsRecipe  = knowsRecipe,
                    isCurrentChar = (charKey == currentCharKey),
                }

                if knowsRecipe then
                    table.insert(knownBy, entry)
                else
                    table.insert(unknownBy, entry)
                end
            end
        end
    end

    if #knownBy == 0 and #unknownBy == 0 then return nil end

    local function sortByName(a, b)
        if a.name == b.name then return (a.realm or "") < (b.realm or "") end
        return (a.name or "") < (b.name or "")
    end
    table.sort(knownBy, sortByName)
    table.sort(unknownBy, sortByName)

    local lines = {}
    local abbr  = GetProfessionAbbr(profName)

    local currentInKnown   = false
    local currentInUnknown = false
    for _, entry in ipairs(knownBy) do
        if entry.isCurrentChar then currentInKnown = true break end
    end
    for _, entry in ipairs(unknownBy) do
        if entry.isCurrentChar then currentInUnknown = true break end
    end

    if currentInKnown then
        table.insert(lines, {
            type = "text",
            text = "  " .. L["TIPS_RECIPEKNOWLEDGE_YOU_KNOW"],
            r = 0.4, g = 0.8, b = 0.4,
        })
    elseif currentInUnknown then
        table.insert(lines, {
            type = "text",
            text = "  " .. L["TIPS_RECIPEKNOWLEDGE_YOU_NEED"],
            r = 0.8, g = 0.4, b = 0.4,
        })
    end

    local totalSlots = 5
    local knownShow   = math.min(#knownBy, totalSlots)
    local unknownShow = math.min(#unknownBy, totalSlots - knownShow)

    local function addGroup(list, limit, colorHex, statusKey)
        local total = #list
        for i, entry in ipairs(list) do
            if i > limit then break end
            local r, g, b = GetClassColor(entry.class)
            local nameStr = entry.name
            if entry.realm and entry.realm ~= "" then
                nameStr = nameStr .. "-" .. entry.realm
            end
            local leftStr  = "  " .. nameStr
            if i == limit and total > limit then
                leftStr = leftStr .. " |cFFAAAAAA(+" .. (total - limit) .. ")|r"
            end
            table.insert(lines, {
                type  = "double",
                left  = leftStr,
                right = colorHex .. L[statusKey] .. "|r  " .. abbr,
                lr = r,   lg = g,   lb = b,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })
        end
    end

    addGroup(knownBy,   knownShow,   "|cFF66CC66", "TIPS_RECIPEKNOWLEDGE_KNOWN")
    addGroup(unknownBy, unknownShow, "|cFFCC6666", "TIPS_RECIPEKNOWLEDGE_UNKNOWN")

    if #lines == 0 then return nil end
    return lines
end

OneWoW.TooltipEngine:RegisterProvider({
    id           = "recipeknowledge",
    order        = 21,
    featureId    = "recipeknowledge",
    tooltipTypes = {"item"},
    callback     = RecipeKnowledgeProvider,
})
