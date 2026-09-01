local _, ns = ...

-- ============================================================================
-- TradeSkillDB loader
-- ============================================================================
-- Emit agents call:
--   ns:RegisterProfessionData{ pid = 171, name = "Alchemy", icon = ..., r = {} }
--   ns:RegisterRecipeData{ [recipeID] = { ... } }
--   ns.Professions     [name] = profession header
--   ns.Recipes         [recipeID] = recipe record
--   ns.RecipesByItem   [itemID] = { recipe, ... }
-- ============================================================================

local pairs = pairs
local tinsert = tinsert

ns.Professions = ns.Professions or {}
ns.Recipes = ns.Recipes or {}
ns.RecipesByItem = ns.RecipesByItem or {}

local function IndexItem(itemID, recipe)
    if type(itemID) ~= "number" or itemID <= 0 then return end
    local list = ns.RecipesByItem[itemID]
    if not list then
        list = {}
        ns.RecipesByItem[itemID] = list
    end
    tinsert(list, recipe)
end

--- Merge one profession header (optional recipe map in .r).
---@param source table
function ns:RegisterProfessionData(source)
    if type(source) ~= "table" then return end
    local name = source.name
    if type(name) == "string" and name ~= "" then
        ns.Professions[name] = source
    end
    if type(source.r) == "table" then
        ns:RegisterRecipeData(source.r)
    end
end

--- Merge recipe rows keyed by recipeID.
---@param source table<number, table>
function ns:RegisterRecipeData(source)
    if type(source) ~= "table" then return end

    for recipeID, recipe in pairs(source) do
        if type(recipeID) == "number" and type(recipe) == "table" then
            ns.Recipes[recipeID] = recipe
            IndexItem(recipe.item, recipe)
            if recipe.items then
                for _, altID in pairs(recipe.items) do
                    IndexItem(altID, recipe)
                end
            end
        end
    end
end
