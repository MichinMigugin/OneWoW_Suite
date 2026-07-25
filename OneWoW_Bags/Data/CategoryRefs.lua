local _, ns = ...

-- ============================================================================
-- CategoryRefs
-- ============================================================================
-- CATEGORY(Name) resolution for custom search-mode categories, plus rename
-- rewrites of CATEGORY() tokens inside Bags SV. Suite-wide expand lives in
-- OneWoW.SearchExpand; Bags registers FindSearchExpression as the resolver.

local strgsub = string.gsub
local strlower = string.lower
local strtrim = strtrim
local type = type
local ipairs = ipairs
local pairs = pairs

ns.CategoryRefs = {}
local CategoryRefs = ns.CategoryRefs

local categoryRulesChanged = {} ---@type table<string, fun()>

local function GetDB()
    return ns:GetDB()
end

local function NormalizeCategoryRefName(name)
    name = strtrim(name or "")
    if name == "" then return nil end
    return name
end

--- Find a custom search-mode category by display name (case-insensitive).
---@param name string|nil
---@return string|nil expression
---@return string|nil displayName
function CategoryRefs:FindSearchExpression(name)
    local normalized = NormalizeCategoryRefName(name)
    if not normalized then return nil end

    local wanted = strlower(normalized)
    local customs = GetDB().global.customCategoriesV2
    for _, categoryData in pairs(customs) do
        local displayName = categoryData and categoryData.name
        if displayName and strlower(strtrim(displayName)) == wanted then
            local fm = categoryData.filterMode
            if not fm then
                if categoryData.searchExpression and categoryData.searchExpression ~= "" then
                    fm = "search"
                else
                    fm = "type"
                end
            end
            if fm == "search" then
                local expr = categoryData.searchExpression
                if type(expr) == "string" and expr ~= "" then
                    return expr, displayName
                end
            end
            return nil, displayName
        end
    end
    return nil
end

local function ReplaceCategoryReferences(text, oldName, newName)
    if type(text) ~= "string" or text == "" then return text end

    local oldLower = strlower(oldName)
    return strgsub(text, "CATEGORY%(([^%)]*)%)", function(inner)
        local normalized = NormalizeCategoryRefName(inner)
        if normalized and strlower(normalized) == oldLower then
            return "CATEGORY(" .. newName .. ")"
        end
        return "CATEGORY(" .. inner .. ")"
    end)
end

--- Rewrite CATEGORY(oldName) → CATEGORY(newName) in Bags history/categories
--- and in core named expressions (via SearchExpand).
---@param oldName string
---@param newName string
function CategoryRefs:ReplaceReferencesInDB(oldName, newName)
    if type(oldName) ~= "string" or type(newName) ~= "string" then return end
    if oldName == "" or newName == "" then return end

    local db = GetDB()
    for i, query in ipairs(db.global.searchHistory) do
        db.global.searchHistory[i] = ReplaceCategoryReferences(query, oldName, newName)
    end

    for _, categoryData in pairs(db.global.customCategoriesV2) do
        if categoryData.searchExpression then
            categoryData.searchExpression = ReplaceCategoryReferences(
                categoryData.searchExpression, oldName, newName)
        end
    end

    local SE = OneWoW.SearchExpand
    local all = SE:GetAllSaved()
    for name, query in pairs(all) do
        local rewritten = ReplaceCategoryReferences(query, oldName, newName)
        if rewritten ~= query then
            SE:SetSaved(name, rewritten)
        end
    end
end

---@param id string
---@param fn fun()
function CategoryRefs:RegisterRulesChanged(id, fn)
    categoryRulesChanged[id] = fn
end

---@param id string
function CategoryRefs:UnregisterRulesChanged(id)
    categoryRulesChanged[id] = nil
end

function CategoryRefs:NotifyRulesChanged()
    for _, fn in pairs(categoryRulesChanged) do
        fn()
    end
end

--- Rewrite SAVED(old) → SAVED(new) inside Bags searchHistory + category exprs.
---@param oldName string
---@param newName string
function CategoryRefs:RewriteSavedReferences(oldName, newName)
    local db = GetDB()
    local SE = OneWoW.SearchExpand

    for i, query in ipairs(db.global.searchHistory) do
        db.global.searchHistory[i] = SE:ReplaceSavedReferencesInText(query, oldName, newName)
    end

    for _, categoryData in pairs(db.global.customCategoriesV2) do
        if categoryData.searchExpression then
            categoryData.searchExpression = SE:ReplaceSavedReferencesInText(
                categoryData.searchExpression, oldName, newName)
        end
    end
end
