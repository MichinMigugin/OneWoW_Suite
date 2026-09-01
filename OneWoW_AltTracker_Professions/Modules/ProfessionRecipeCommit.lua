local _, ns = ...

-- Persists learned-recipe scan snapshots from the core OneWoW.ProfessionRecipe
-- funnel into this unit's SavedVariables. Canonical profession identity is
-- resolved HERE (where charData lives), keyed on the numeric profession skill
-- line rather than the raw name string: the empty/stale name string was the
-- exact surface that produced recipes[""] and cross-contaminated buckets.
--
-- Writes are monotonic (a partial/empty scan never shrinks a stored set) and
-- self-healing (a recipe authoritatively belongs to the resolved profession, so
-- it is pruned from every other bucket and the unattributable "" bucket is
-- dropped on any resolved commit).

ns.ProfessionRecipeCommit = {}
local Module = ns.ProfessionRecipeCommit

local OneWoW_GUI = OneWoW_GUI
local C_TradeSkillUI = C_TradeSkillUI
local pairs, next, time = pairs, next, time

local OWNER_ID = "AltTracker_Professions"
local subscribed = false

-- Resolution priority: numeric base skill line -> exact own-slot name match ->
-- per-recipe plurality (Blizzard-native, no catalog) -> catalog plurality (only
-- if that LoD unit happens to be loaded) -> nil (skip; never write recipes[""]).

local function ResolveBySkillLine(professions, skillLineID)
    if not skillLineID then return nil end
    for _, profData in pairs(professions) do
        if profData and profData.skillLine and profData.skillLine == skillLineID then
            return profData.name
        end
    end
    return nil
end

local function ResolveByName(professions, name)
    if not name or name == "" then return nil end
    for _, profData in pairs(professions) do
        if profData and profData.name == name then
            return profData.name
        end
    end
    return nil
end

local function ResolveByRecipes(professions, learned)
    if not learned then return nil end
    local tally = {}
    for recipeID in pairs(learned) do
        local info = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipeID)
        if info then
            local id = info.parentProfessionID or info.professionID
            if id then
                tally[id] = (tally[id] or 0) + 1
            end
        end
    end
    local bestID, bestCount = nil, 0
    for id, count in pairs(tally) do
        if count > bestCount then
            bestID, bestCount = id, count
        end
    end
    return ResolveBySkillLine(professions, bestID)
end

local function ResolveByCatalog(professions, learned)
    local api = OneWoW:GetCatalogPackAPI("tradeskills")
    if not api or not learned then return nil end
    local tally = {}
    for recipeID in pairs(learned) do
        local profName = api.GetRecipeProfession(recipeID)
        if profName then
            tally[profName] = (tally[profName] or 0) + 1
        end
    end
    local bestName, bestCount = nil, 0
    for name, count in pairs(tally) do
        if count > bestCount then
            bestName, bestCount = name, count
        end
    end
    return ResolveByName(professions, bestName)
end

--- Resolve the scan snapshot to one of this character's profession slot names.
---@param charData table
---@param scan table
---@return string|nil canonicalName
function Module:ResolveCanonicalName(charData, scan)
    local professions = charData.professions
    if not professions then return nil end
    local base = scan.baseInfo or {}
    return ResolveBySkillLine(professions, base.professionID)
        or ResolveByName(professions, base.professionName)
        or ResolveByRecipes(professions, scan.learned)
        or ResolveByCatalog(professions, scan.learned)
end

--- Monotonic + self-healing merge of a learned set into charData.recipes[name].
---@param charData table
---@param name string canonical profession name (never empty)
---@param learned table<number, boolean>
---@return boolean committed
function Module:CommitRecipeScan(charData, name, learned)
    if not name or name == "" then return false end
    if not learned or next(learned) == nil then return false end -- never shrink

    charData.recipes = charData.recipes or {}

    local bucket = charData.recipes[name]
    if not bucket then
        bucket = {}
        charData.recipes[name] = bucket
    end
    for recipeID in pairs(learned) do
        bucket[recipeID] = true
    end

    -- Self-healing: these IDs authoritatively belong to `name`, so strip them
    -- from any other bucket (repairs legacy cross-contamination) and drop the
    -- unattributable empty-string bucket outright.
    for key, set in pairs(charData.recipes) do
        if key ~= name then
            for recipeID in pairs(learned) do
                set[recipeID] = nil
            end
            if key == "" or next(set) == nil then
                charData.recipes[key] = nil
            end
        end
    end

    charData.lastUpdate = time()
    return true
end

local function OnScan(scan)
    if not scan then return end

    local charKey = scan.charKey or OneWoW_GUI:GetCharacterKey()
    if not charKey then return end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return end

    local name = Module:ResolveCanonicalName(charData, scan)
    if not name then return end -- unresolved: never write recipes[""]

    Module:CommitRecipeScan(charData, name, scan.learned)

    -- This unit owns SavedVariables persistence of the shared item->recipe map.
    if scan.itemMap then
        local db = OneWoW_AltTracker_Professions_DB
        if db then
            db.recipeItemMap = db.recipeItemMap or {}
            for itemID, recipeID in pairs(scan.itemMap) do
                db.recipeItemMap[itemID] = recipeID
            end
        end
    end
end

--- Subscribe/unsubscribe to the core funnel based on the trackRecipes setting.
---@param enabled boolean
function Module:SetEnabled(enabled)
    if enabled then
        if not subscribed then
            subscribed = true
            OneWoW.ProfessionRecipe.RegisterScanCallback(OWNER_ID, OnScan)
        end
    elseif subscribed then
        subscribed = false
        OneWoW.ProfessionRecipe.UnregisterCallback(OWNER_ID)
    end
end

function Module:Initialize()
    local settings = OneWoW_AltTracker_Professions_DB and OneWoW_AltTracker_Professions_DB.settings
    local enabled = not (settings and settings.trackRecipes == false)
    self:SetEnabled(enabled)
end
