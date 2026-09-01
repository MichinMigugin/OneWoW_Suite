local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

ns.DatabaseDefaults = {
    characters = {},
    settings = {
        enableDataCollection = true,
        trackRecipes = true,
        trackEquipment = true,
    },
}

-- Bumps when recipe-bucket repair logic changes. Repair is retryable: the flag
-- only advances once a pass completes with an attribution source available, so a
-- login without the catalog / an open profession window defers to a later run.
local RECIPES_REPAIR_VERSION = 3

-- Attribute a stored recipe ID to a base profession name, preferring the
-- Blizzard-native lookup and falling back to the catalog data unit when loaded.
-- Returns nil when no attribution source can resolve it (leave it in place).
local function AttributeRecipe(recipeID)
    local info = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipeID)
    if info then
        local name = info.parentProfessionName or info.professionName
        if name and name ~= "" then
            return name
        end
    end
    local catalog = OneWoW:GetCatalogPackAPI("tradeskills")
    if catalog then
        return catalog.GetRecipeProfession(recipeID)
    end
    return nil
end

local function SlotNameFor(professions, profName)
    if not professions or not profName then return nil end
    for _, profData in pairs(professions) do
        if profData and profData.name == profName then
            return profData.name
        end
    end
    return nil
end

-- Best-effort, idempotent repair of legacy corruption: relocate IDs out of the
-- unattributable "" bucket to their real profession. The self-healing commit in
-- ProfessionRecipeCommit is the primary fix (it also drops "" on any resolved
-- commit); this only helps professions the player never reopens.
local function RepairRecipeBuckets()
    local db = OneWoW_AltTracker_Professions_DB
    if not db or not db.characters then return end
    if (db.recipesRepairedVersion or 0) >= RECIPES_REPAIR_VERSION then return end

    local fullyRepaired = true

    for _, charData in pairs(db.characters) do
        local recipes = charData.recipes
        local orphan = recipes and recipes[""]
        if orphan then
            local professions = charData.professions
            for recipeID in pairs(orphan) do
                local profName = AttributeRecipe(recipeID)
                local slotName = profName and SlotNameFor(professions, profName)
                if slotName then
                    recipes[slotName] = recipes[slotName] or {}
                    recipes[slotName][recipeID] = true
                    orphan[recipeID] = nil
                else
                    fullyRepaired = false
                end
            end
            if next(orphan) == nil then
                recipes[""] = nil
            end
        end
    end

    if fullyRepaired then
        db.recipesRepairedVersion = RECIPES_REPAIR_VERSION
    end
end

-- Defaults applied by BootStore (MergeMissing) before this runs, so only the
-- char-key normalizer and recipe-bucket repair remain here.
function ns:InitializeDatabase()
    local migrated = DB:ConsolidateCharacterKeys(OneWoW_AltTracker_Professions_DB.characters)
    if migrated > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW AltTracker:|r consolidated " .. migrated .. " duplicate character key(s) in professions data.")
        end)
    end

    RepairRecipeBuckets()
end
