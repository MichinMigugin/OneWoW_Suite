local _, ns = ...

-- Public, cross-addon read surface for the Professions unit. ns stays private.
OneWoW_AltTracker_Professions_API = {}

--- Stored profession data for a character.
---@param charKey string
---@return table|nil charData
function OneWoW_AltTracker_Professions_API.GetCharacterData(charKey)
    return ns.DataManager:GetCharacterData(charKey)
end

--- All stored characters keyed by character key.
---@return table characters charKey -> charData
function OneWoW_AltTracker_Professions_API.GetAllCharacters()
    return ns.DataManager:GetAllCharacters()
end

--- Character key for the logged-in player.
---@return string|nil charKey
function OneWoW_AltTracker_Professions_API.GetCurrentCharacterKey()
    return ns:GetCharacterKey()
end

--- Delete a character's stored profession data.
---@param charKey string
---@return boolean deleted
function OneWoW_AltTracker_Professions_API.DeleteCharacter(charKey)
    return ns.DataManager:DeleteCharacter(charKey)
end

--- Trigger a full rescan of the current character's profession data.
function OneWoW_AltTracker_Professions_API.ForceFullScan()
    return ns.DataManager:ForceFullScan()
end

--- Collect basic profession data for the current character.
function OneWoW_AltTracker_Professions_API.CollectBasicData()
    return ns.DataManager:CollectAllBasicData()
end

--- Stored equipment for a specific profession.
---@param charKey string
---@param professionName string
---@return table|nil equipment
function OneWoW_AltTracker_Professions_API.GetProfessionEquipment(charKey, professionName)
    local charData = ns.DataManager:GetCharacterData(charKey)
    if not charData then return nil end
    return ns.ProfessionEquipment:GetEquipmentForProfession(charKey, charData, professionName)
end

--- Active (unexpired) crafting cooldowns for a profession.
---@param charKey string
---@param professionName string
---@return table cooldowns
function OneWoW_AltTracker_Professions_API.GetActiveCooldowns(charKey, professionName)
    local charData = ns.DataManager:GetCharacterData(charKey)
    if not charData then return {} end
    return ns.ProfessionCooldowns:GetActiveCooldowns(charKey, charData, professionName)
end

--- Recently visited profession trainers for a character.
---@param charKey string
---@param count number|nil maximum entries to return
---@return table trainers
function OneWoW_AltTracker_Professions_API.GetRecentTrainers(charKey, count)
    local charData = ns.DataManager:GetCharacterData(charKey)
    if not charData then return {} end
    return ns.ProfessionTrainers:GetRecentTrainers(charKey, charData, count)
end

--- Concentration state for a profession slot.
---@param charKey string
---@param slotName string
---@return table|nil concentration
function OneWoW_AltTracker_Professions_API.GetConcentration(charKey, slotName)
    local charData = ns.DataManager:GetCharacterData(charKey)
    if not charData then return nil end
    return ns.ProfessionConcentration:GetConcentration(charData, slotName)
end

--- Number of known recipes for a profession.
---@param charKey string
---@param professionName string
---@return number count
function OneWoW_AltTracker_Professions_API.GetRecipeCount(charKey, professionName)
    local charData = ns.DataManager:GetCharacterData(charKey)
    if not charData then return 0 end
    return ns.ProfessionAdvanced:GetRecipeCount(charKey, charData, professionName)
end

--- Recipe progress for a profession. Stored known count is always available;
--- totals and the per-expansion breakdown require the resolved catalog
--- tradeskills pack to be loaded. When it is not, callers must degrade to
--- showing the stored count only (never a fake "Total 0 / Known 0").
---@param charKey string
---@param professionName string
---@return table progress { catalogLoaded, stored, known, total, byExpansion }
function OneWoW_AltTracker_Professions_API.GetRecipeProgress(charKey, professionName)
    local charData = ns.DataManager:GetCharacterData(charKey)

    local storedSet = charData and charData.recipes and charData.recipes[professionName]
    local stored = 0
    if storedSet then
        for _ in pairs(storedSet) do
            stored = stored + 1
        end
    end

    local progress = {
        catalogLoaded = false,
        stored = stored,
        known = stored,
        total = nil,
        byExpansion = {},
    }

    local catalog = OneWoW:GetCatalogPackAPI("tradeskills")
    if not catalog then
        return progress
    end

    local recipes = catalog.GetRecipesByProfession(professionName)
    if not recipes or #recipes == 0 then
        return progress
    end

    progress.catalogLoaded = true
    local byExpansion = {}
    local total, known = 0, 0
    for _, recipe in ipairs(recipes) do
        local expKey = recipe.exp or "Unknown"
        local entry = byExpansion[expKey]
        if not entry then
            entry = { totalRecipes = 0, learnedRecipes = 0 }
            byExpansion[expKey] = entry
        end
        entry.totalRecipes = entry.totalRecipes + 1
        total = total + 1
        if storedSet and storedSet[recipe.id] then
            entry.learnedRecipes = entry.learnedRecipes + 1
            known = known + 1
        end
    end

    progress.total = total
    progress.known = known
    progress.byExpansion = byExpansion
    return progress
end

--- Shared item -> recipe spell ID map, populated by the core RecipeKnownUtil
--- service from trade-skill data. Persisted in this unit's SavedVariables.
---@return table|nil map itemID -> recipeSpellID
function OneWoW_AltTracker_Professions_API.GetRecipeItemMap()
    return OneWoW_AltTracker_Professions_DB.recipeItemMap
end

--- Record a single item -> recipe spell ID mapping.
---@param itemID number
---@param recipeSpellID number|nil
function OneWoW_AltTracker_Professions_API.SetRecipeItemMapEntry(itemID, recipeSpellID)
    if not itemID then return end
    local db = OneWoW_AltTracker_Professions_DB
    db.recipeItemMap = db.recipeItemMap or {}
    db.recipeItemMap[itemID] = recipeSpellID
end
