local _, ns = ...

local RecipeKnownUtil = {}
ns.RecipeKnownUtil = RecipeKnownUtil

local knownRecipeSpells = {}
local sessionMap = {}

local LEARN_LINE_TYPE = Enum.TooltipDataLineType.ItemSpellTriggerLearn

local function GetSavedMap()
    return OneWoW_AltTracker_Professions_API and OneWoW_AltTracker_Professions_API.GetRecipeItemMap()
end

local function SaveToMap(itemID, recipeSpellID)
    sessionMap[itemID] = recipeSpellID
    if OneWoW_AltTracker_Professions_API then
        OneWoW_AltTracker_Professions_API.SetRecipeItemMapEntry(itemID, recipeSpellID)
    end
end

-- Consume scan snapshots from the core ProfessionRecipe funnel instead of owning
-- a private TRADE_SKILL_* / NEW_RECIPE_LEARNED frame. The session recipe cache
-- and item->spell map are in-memory here; SavedVariables persistence of the item
-- map is owned by the AltTracker Professions unit (via SaveToMap on demand, and
-- its own commit module on scan) so this stays correct when that unit is absent.
ns.ProfessionRecipe.RegisterScanCallback("RecipeKnownUtil", function(scan)
    if not scan then return end
    if scan.learned then
        for recipeSpellID in pairs(scan.learned) do
            knownRecipeSpells[recipeSpellID] = true
        end
    end
    if scan.itemMap then
        for itemID, recipeSpellID in pairs(scan.itemMap) do
            sessionMap[itemID] = recipeSpellID
        end
    end
end)

local function GetSpellIDFromTooltip(itemID)
    local td = C_TooltipInfo.GetItemByID(itemID)
    if not td or not td.lines then return nil end
    for _, line in ipairs(td.lines) do
        if line.type == LEARN_LINE_TYPE and line.spellID then
            return line.spellID
        end
    end
    return nil
end

function RecipeKnownUtil:GetRecipeSpellID(itemID)
    if not itemID then return nil end

    local spellID = GetSpellIDFromTooltip(itemID)
    if spellID then
        SaveToMap(itemID, spellID)
        return spellID
    end

    if sessionMap[itemID] then return sessionMap[itemID] end

    local saved = GetSavedMap()
    if saved and saved[itemID] then
        sessionMap[itemID] = saved[itemID]
        return saved[itemID]
    end

    return nil
end

function RecipeKnownUtil:IsRecipeKnown(itemID)
    if not itemID then return nil end

    local recipeSpellID = self:GetRecipeSpellID(itemID)
    if not recipeSpellID then return nil end

    if knownRecipeSpells[recipeSpellID] then
        return true
    end

    if OneWoW_AltTracker_Professions_API then
        local OneWoW_GUI = OneWoW_GUI
        local charKey = OneWoW_GUI and OneWoW_GUI:BuildCharKey()
        local charData = charKey and OneWoW_AltTracker_Professions_API.GetCharacterData(charKey)
        if charData and charData.recipes then
            for _, recipeSet in pairs(charData.recipes) do
                if recipeSet[recipeSpellID] then
                    knownRecipeSpells[recipeSpellID] = true
                    return true
                end
            end
        end
    end

    local info = C_TradeSkillUI.GetRecipeInfo(recipeSpellID)
    if info and info.learned then
        knownRecipeSpells[recipeSpellID] = true
        return true
    end

    return nil
end

function RecipeKnownUtil:IsAltRecipeKnown(charRecipeSet, itemID)
    if not charRecipeSet or not itemID then return false end

    local recipeSpellID = self:GetRecipeSpellID(itemID)
    if recipeSpellID and charRecipeSet[recipeSpellID] then
        return true
    end

    return false
end

function RecipeKnownUtil:RegisterMapping(itemID, recipeSpellID)
    if itemID and recipeSpellID then
        SaveToMap(itemID, recipeSpellID)
    end
end

--- Resolve the learnable recipe-scroll item ID for a recipe spell ID.
--- Uses the live profession UI link when available, otherwise the item→spell map
--- built while professions are open (same map Recipe Knowledge tooltips use).
function RecipeKnownUtil:GetRecipeItemID(recipeSpellID)
    if not recipeSpellID then return nil end

    local link = C_TradeSkillUI.GetRecipeItemLink(recipeSpellID)
    if link then
        local itemID = tonumber(link:match("item:(%d+)"))
        if itemID then
            SaveToMap(itemID, recipeSpellID)
            return itemID
        end
    end

    for itemID, spellID in pairs(sessionMap) do
        if spellID == recipeSpellID then
            return itemID
        end
    end

    local saved = GetSavedMap()
    if saved then
        for itemID, spellID in pairs(saved) do
            if spellID == recipeSpellID then
                sessionMap[itemID] = spellID
                return itemID
            end
        end
    end

    return nil
end

function RecipeKnownUtil:IsCacheReady()
    local saved = GetSavedMap()
    return saved and next(saved) ~= nil
end

-- ---------------------------------------------------------------------------
-- Alt roster recipe checks (Recipe Knowledge altScope)
-- ---------------------------------------------------------------------------

local PROFESSION_SKILL_IDS = {
    171, 164, 333, 202, 182,
    773, 755, 165, 186, 393,
    197, 185, 356, 129, 794,
}

local professionNameCache = {}

local function GetLocalizedProfessionName(skillID)
    if professionNameCache[skillID] then return professionNameCache[skillID] end
    local name = C_TradeSkillUI.GetTradeSkillDisplayName(skillID)
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

local function DetectProfessionFromTooltip(itemID)
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

--- Profession name required to craft/learn a recipe item (subclass first, tooltip fallback).
function RecipeKnownUtil:GetRecipeProfessionName(itemID, subClassID)
    if subClassID then
        local name = C_Item.GetItemSubClassInfo(Enum.ItemClass.Recipe, subClassID)
        if name and name ~= "" then return name end
    end
    if not itemID then return nil end
    return DetectProfessionFromTooltip(itemID)
end

--- True when a scoped alt (not the logged-in character) knows the recipe and self does not.
--- `altScope` is the Recipe Knowledge tooltip altScope table.
function RecipeKnownUtil:IsRecipeKnownByScopedAlt(itemID, altScope)
    if not itemID or self:IsRecipeKnown(itemID) then return false end
    if not altScope or not OneWoW_AltTracker_Professions_API then return false end

    local profName = self:GetRecipeProfessionName(itemID)
    if not profName then return false end

    local OneWoW_GUI = OneWoW_GUI
    local currentCharKey = OneWoW_GUI and OneWoW_GUI:BuildCharKey()

    for charKey, charData in pairs(OneWoW_AltTracker_Professions_API.GetAllCharacters()) do
        if charKey ~= currentCharKey
            and OneWoW.AltScope:IsCharIncluded(charKey, altScope)
            and charData.professions
        then
            local hasProfession = false
            for _, profData in pairs(charData.professions) do
                if ProfNamesMatch(profData.name, profName) then
                    hasProfession = true
                    break
                end
            end
            if hasProfession then
                local recipeSet = FindRecipes(charData, profName)
                if recipeSet and self:IsAltRecipeKnown(recipeSet, itemID) then
                    return true
                end
            end
        end
    end

    return false
end
