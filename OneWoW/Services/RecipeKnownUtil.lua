local _, ns = ...

local RecipeKnownUtil = {}
ns.RecipeKnownUtil = RecipeKnownUtil

local knownRecipeSpells = {}
local sessionMap = {}

-- Per-item tooltip hot-path memoization. Cleared on profession scan / learn so
-- Collections tooltips do not re-hit C_TradeSkillUI on every mouseover (that
-- path was firing SPELLS_CHANGED and thrashing LibRangeCheck / merchant paints).
local itemKnownCache = {}
local altKnownCache = {}
local professionNameByItem = {}

local C_TradeSkillUI = C_TradeSkillUI
local C_SpellBook = C_SpellBook
local C_Item = C_Item
local TooltipScanner = ns.TooltipScanner
local wipe = wipe

local SPELL_BANK_PLAYER = Enum.SpellBookSpellBank.Player
local ITEM_CLASS_RECIPE = Enum.ItemClass.Recipe

local function GetSavedMap()
    return OneWoW_AltTracker_Professions_API and OneWoW_AltTracker_Professions_API.GetRecipeItemMap()
end

local function SaveToMap(itemID, recipeSpellID)
    sessionMap[itemID] = recipeSpellID
    if OneWoW_AltTracker_Professions_API then
        OneWoW_AltTracker_Professions_API.SetRecipeItemMapEntry(itemID, recipeSpellID)
    end
end

local function InvalidateItemCaches()
    wipe(itemKnownCache)
    wipe(altKnownCache)
    wipe(professionNameByItem)
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
    InvalidateItemCaches()
end)

ns.ProfessionRecipe.RegisterLearnedCallback("RecipeKnownUtil", function(recipeID)
    if recipeID then
        knownRecipeSpells[recipeID] = true
    end
    InvalidateItemCaches()
end)

local function ResolveTooltipData(itemID, context)
    context = context or {}
    if not context.itemID then
        context.itemID = itemID
    end
    return TooltipScanner:ResolveItemData(context)
end

-- Legacy profession books (e.g. Master Cookbook) expose a teach *spell* on the
-- tooltip, while AltTracker / GetRecipeInfo use trade-skill *recipe* IDs. Gather
-- every candidate ID we might match against.
-- Prefer session/saved maps before any C_TradeSkillUI call so tooltip hover stays
-- off the TradeSkill hot path when the mapping is already known.
---@param itemID number
---@param context table|nil
---@param allowTradeSkillResolve boolean|nil when false, skip GetRecipeInfoForSkillLineAbility
---@return number[]
local function GetRecipeIDCandidates(itemID, context, allowTradeSkillResolve)
    local candidates = {}
    local seen = {}

    local function add(id)
        id = tonumber(id)
        if id and id > 0 and not seen[id] then
            seen[id] = true
            candidates[#candidates + 1] = id
        end
    end

    if sessionMap[itemID] then add(sessionMap[itemID]) end
    local saved = GetSavedMap()
    if saved and saved[itemID] then add(saved[itemID]) end

    local td = ResolveTooltipData(itemID, context)
    local teachSpellID = TooltipScanner:GetLearnSpellID(td)
    if teachSpellID then
        add(teachSpellID)
        -- Only ask TradeSkill to map teach-spell → recipeID when we do not
        -- already have an item→recipe mapping (tooltip hot path sets
        -- allowTradeSkillResolve=false entirely).
        local mapped = sessionMap[itemID] or (saved and saved[itemID])
        if allowTradeSkillResolve ~= false and not mapped then
            local info = C_TradeSkillUI.GetRecipeInfoForSkillLineAbility(teachSpellID)
            if info and info.recipeID then
                add(info.recipeID)
            end
        end
    end

    return candidates
end

local function IsRecipeIDLearned(recipeID, allowTradeSkillResolve)
    if knownRecipeSpells[recipeID] then return true end

    -- Spellbook first: avoids C_TradeSkillUI on the common learned-spell case.
    if C_SpellBook.IsSpellKnown(recipeID, SPELL_BANK_PLAYER) then
        knownRecipeSpells[recipeID] = true
        return true
    end

    if allowTradeSkillResolve == false then
        return false
    end

    local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
    if info and info.learned then
        knownRecipeSpells[recipeID] = true
        return true
    end

    return false
end

-- Match alt/current recipe sets by candidate IDs only. Do not call
-- GetRecipeItemLink here — that is a TradeSkill hot-path that thrash-loads
-- profession data during tooltip decoration.
local function CharRecipeSetHasItem(charRecipeSet, candidates)
    if not charRecipeSet then return false end

    for i = 1, #candidates do
        if charRecipeSet[candidates[i]] then
            return true
        end
    end

    return false
end

function RecipeKnownUtil:GetRecipeSpellID(itemID, context)
    if not itemID then return nil end

    local candidates = GetRecipeIDCandidates(itemID, context, true)
    if candidates[1] then return candidates[1] end

    return nil
end

--- @param context table|nil may set `light=true` to skip C_TradeSkillUI resolves (tooltip hover)
function RecipeKnownUtil:IsRecipeKnown(itemID, context)
    if not itemID then return nil end

    local light = context and context.light == true
    local cached = itemKnownCache[itemID]
    if cached ~= nil then
        return cached or nil
    end

    local td = ResolveTooltipData(itemID, context)
    if TooltipScanner:IsAlreadyKnown(td) then
        itemKnownCache[itemID] = true
        return true
    end

    local candidates = GetRecipeIDCandidates(itemID, context, not light)
    if #candidates == 0 then
        -- Unresolved: do not cache, so a later pass with warm data can succeed.
        return nil
    end

    for i = 1, #candidates do
        if IsRecipeIDLearned(candidates[i], not light) then
            itemKnownCache[itemID] = true
            return true
        end
    end

    if OneWoW_AltTracker_Professions_API then
        local OneWoW_GUI = OneWoW_GUI
        local charKey = OneWoW_GUI and OneWoW_GUI:BuildCharKey()
        local charData = charKey and OneWoW_AltTracker_Professions_API.GetCharacterData(charKey)
        if charData and charData.recipes then
            for _, recipeSet in pairs(charData.recipes) do
                if CharRecipeSetHasItem(recipeSet, candidates) then
                    itemKnownCache[itemID] = true
                    return true
                end
            end
        end
    end

    -- Light path may only have a teach-spell ID (no TradeSkill recipeID map).
    -- Do not sticky-cache "unknown" until we have a real item→recipe mapping.
    if light then
        local mapped = sessionMap[itemID] or (GetSavedMap() and GetSavedMap()[itemID])
        if not mapped then
            return nil
        end
    end

    itemKnownCache[itemID] = false
    return nil
end

function RecipeKnownUtil:IsAltRecipeKnown(charRecipeSet, itemID, context)
    if not charRecipeSet or not itemID then return false end

    local light = context and context.light == true
    return CharRecipeSetHasItem(charRecipeSet, GetRecipeIDCandidates(itemID, context, not light))
end

function RecipeKnownUtil:RegisterMapping(itemID, recipeSpellID)
    if itemID and recipeSpellID then
        SaveToMap(itemID, recipeSpellID)
        itemKnownCache[itemID] = nil
        altKnownCache[itemID] = nil
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
    local td = TooltipScanner:GetItemByIDData(itemID)
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
    if itemID and professionNameByItem[itemID] then
        return professionNameByItem[itemID]
    end

    if not subClassID and itemID then
        local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(itemID)
        if classID == ITEM_CLASS_RECIPE then
            subClassID = subID
        end
    end

    if subClassID then
        local name = C_Item.GetItemSubClassInfo(ITEM_CLASS_RECIPE, subClassID)
        if name and name ~= "" then
            if itemID then professionNameByItem[itemID] = name end
            return name
        end
    end
    if not itemID then return nil end
    local detected = DetectProfessionFromTooltip(itemID)
    if detected then
        professionNameByItem[itemID] = detected
    end
    return detected
end

--- True when a scoped alt (not the logged-in character) knows the recipe and self does not.
--- `altScope` is the Recipe Knowledge tooltip altScope table.
--- @param context table|nil may set `light=true` for tooltip hover (no TradeSkill resolves)
function RecipeKnownUtil:IsRecipeKnownByScopedAlt(itemID, altScope, context)
    if not itemID then return false end

    local cached = altKnownCache[itemID]
    if cached ~= nil then
        return cached
    end

    local light = context and context.light == true
    if self:IsRecipeKnown(itemID, context) then
        altKnownCache[itemID] = false
        return false
    end
    if not altScope or not OneWoW_AltTracker_Professions_API then
        altKnownCache[itemID] = false
        return false
    end

    local profName = self:GetRecipeProfessionName(itemID)
    if not profName then
        -- Profession name unresolved (cold tooltip): do not sticky-cache.
        return false
    end

    local OneWoW_GUI = OneWoW_GUI
    local currentCharKey = OneWoW_GUI and OneWoW_GUI:BuildCharKey()
    local found = false

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
                if recipeSet and self:IsAltRecipeKnown(recipeSet, itemID, context) then
                    found = true
                    break
                end
            end
        end
    end

    if found then
        altKnownCache[itemID] = true
        return true
    end

    -- Same light caveat as IsRecipeKnown: without an item→recipe map, "not on
    -- any alt" may be a false negative from teach-spell-only candidates.
    if light then
        local mapped = sessionMap[itemID] or (GetSavedMap() and GetSavedMap()[itemID])
        if not mapped then
            return false
        end
    end

    altKnownCache[itemID] = false
    return false
end
