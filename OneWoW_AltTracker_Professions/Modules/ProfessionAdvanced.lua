local _, ns = ...

ns.ProfessionAdvanced = {}
local Module = ns.ProfessionAdvanced

-- Recipe collection and SavedVariables writes now live in the core
-- OneWoW.ProfessionRecipe funnel + ProfessionRecipeCommit. This module retains
-- only the stored-count helper used by the public API.

function Module:GetRecipeCount(_, charData, professionName)
    if not charData or not charData.recipes or not charData.recipes[professionName] then
        return 0
    end

    local count = 0
    for _ in pairs(charData.recipes[professionName]) do
        count = count + 1
    end

    return count
end
