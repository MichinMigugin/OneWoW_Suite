local addonName, ns = ...

ns.ProfessionCooldowns = {}
local Module = ns.ProfessionCooldowns

function Module:CollectData(charKey, charData, professionName)
    if not charKey or not charData or not professionName then return false end

    if not charData.recipes or not charData.recipes[professionName] then
        return false
    end

    if not charData.recipeCooldowns then
        charData.recipeCooldowns = {}
    end

    if not charData.recipeCooldowns[professionName] then
        charData.recipeCooldowns[professionName] = {}
    end

    local cooldowns = {}

    for recipeID, recipeData in pairs(charData.recipes[professionName]) do
        if recipeData.learned then
            local cooldown = C_TradeSkillUI.GetRecipeCooldown(recipeID)
            if cooldown and cooldown > 0 then
                cooldowns[recipeID] = {
                    recipeID = recipeID,
                    recipeName = recipeData.name,
                    cooldown = cooldown,
                    cooldownExpires = time() + cooldown,
                    scannedAt = time(),
                }
            end
        end
    end

    charData.recipeCooldowns[professionName] = cooldowns
    charData.lastUpdate = time()

    return true
end

function Module:GetActiveCooldowns(charKey, charData, professionName)
    if not charData or not charData.recipeCooldowns or not charData.recipeCooldowns[professionName] then
        return {}
    end

    local activeCooldowns = {}
    local currentTime = time()

    for recipeID, cooldownData in pairs(charData.recipeCooldowns[professionName]) do
        if cooldownData.cooldownExpires > currentTime then
            table.insert(activeCooldowns, cooldownData)
        end
    end

    return activeCooldowns
end

function Module:CleanExpiredCooldowns(charKey, charData, professionName)
    if not charData or not charData.recipeCooldowns or not charData.recipeCooldowns[professionName] then
        return false
    end

    local currentTime = time()
    local removed = 0

    for recipeID, cooldownData in pairs(charData.recipeCooldowns[professionName]) do
        if cooldownData.cooldownExpires <= currentTime then
            charData.recipeCooldowns[professionName][recipeID] = nil
            removed = removed + 1
        end
    end

    return removed > 0
end
