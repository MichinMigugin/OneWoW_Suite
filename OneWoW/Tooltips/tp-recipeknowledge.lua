local ADDON_NAME, OneWoW = ...

local PROFESSION_NAMES = {
    "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism",
    "Inscription", "Jewelcrafting", "Leatherworking", "Mining", "Skinning",
    "Tailoring", "Cooking", "Fishing", "First Aid", "Archaeology",
}

local PROFESSION_ABBR = {
    ["Alchemy"]        = "ALC",
    ["Blacksmithing"]  = "BS",
    ["Enchanting"]     = "ENCH",
    ["Engineering"]    = "ENG",
    ["Herbalism"]      = "HERB",
    ["Inscription"]    = "INSC",
    ["Jewelcrafting"]  = "JC",
    ["Leatherworking"] = "LW",
    ["Mining"]         = "MIN",
    ["Skinning"]       = "SKIN",
    ["Tailoring"]      = "TAIL",
    ["Cooking"]        = "COOK",
    ["Fishing"]        = "FISH",
    ["First Aid"]      = "FA",
    ["Archaeology"]    = "ARCH",
}

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
    local lastMatch = nil
    for _, line in ipairs(td.lines) do
        if line.leftText then
            local text = line.leftText
            if text:find("^Requires") and not text:find("^Requires Level") then
                for _, profName in ipairs(PROFESSION_NAMES) do
                    if text:find(profName, 1, true) then
                        lastMatch = profName
                        break
                    end
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

    local _, spellID = C_Item.GetItemSpell(context.itemID)
    if not spellID then return nil end

    local profName = DetectProfession(context.itemID)
    if not profName then return nil end

    local profsDB = _G.OneWoW_AltTracker_Professions_DB
    local charDB  = _G.OneWoW_AltTracker_Character_DB
    if not profsDB or not profsDB.characters then return nil end

    local L              = OneWoW.L
    local currentCharKey = UnitName("player") .. "-" .. GetRealmName()
    local currentKnows   = IsSpellKnown(spellID)

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
                    knowsRecipe = recipeSet and recipeSet[spellID] ~= nil
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
    local abbr  = PROFESSION_ABBR[profName] or profName

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

    local knownShow   = math.min(2, #knownBy)
    local unknownShow = math.min(5 - knownShow, #unknownBy)
    knownShow         = math.min(5 - unknownShow, #knownBy)

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
