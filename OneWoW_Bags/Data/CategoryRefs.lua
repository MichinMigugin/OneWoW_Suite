local _, ns = ...

-- ============================================================================
-- CategoryRefs / SearchExpand
-- ============================================================================
-- CATEGORY(Name) expands to a custom category's searchExpression before
-- PredicateEngine compiles the query. Builtin / type-mode / pin-only
-- categories are not eligible — missing or ineligible refs fail closed.
--
-- Semantics: matches the category's search rule, not GetItemCategory
-- assignment (priority, pins, and first-winner order still apply there).
--
-- ns.SearchExpand:Expand handles both SAVED() and CATEGORY() with shared
-- depth and separate cycle guards so the two nest correctly.

local strfind = string.find
local strgsub = string.gsub
local strlower = string.lower
local strmatch = string.match
local strtrim = strtrim
local type = type
local ipairs = ipairs
local pairs = pairs

ns.CategoryRefs = {}
local CategoryRefs = ns.CategoryRefs

ns.SearchExpand = {}
local SearchExpand = ns.SearchExpand

local MAX_EXPANSION_DEPTH = 5
-- PredicateEngine treats unknown #keywords as false.
local NEVER_MATCH_SAVED = "#onewow_saved_search_missing"
local NEVER_MATCH_CATEGORY = "#onewow_category_ref_missing"

local function GetDB()
    return ns:GetDB()
end

--- Trim a CATEGORY(Name) token. Empty names fail closed at expand time.
---@param name string|nil
---@return string|nil
local function NormalizeCategoryRefName(name)
    name = strtrim(name or "")
    if name == "" then return nil end
    return name
end

--- Find a custom search-mode category by display name (case-insensitive).
--- Returns the live searchExpression only when the category is filterMode
--- "search" (inferred) with a non-empty expression.
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
    return strgsub(text, "CATEGORY%(([^%)]*)%)", function(name)
        local normalized = NormalizeCategoryRefName(name)
        if normalized and strlower(normalized) == oldLower then
            return "CATEGORY(" .. newName .. ")"
        end
        return "CATEGORY(" .. name .. ")"
    end)
end

--- Rewrite CATEGORY(oldName) → CATEGORY(newName) in saved searches, search
--- history, and custom category search expressions.
---@param oldName string
---@param newName string
function CategoryRefs:ReplaceReferencesInDB(oldName, newName)
    if type(oldName) ~= "string" or type(newName) ~= "string" then return end
    if oldName == "" or newName == "" then return end

    local db = GetDB()
    for savedName, query in pairs(db.global.savedSearches) do
        db.global.savedSearches[savedName] = ReplaceCategoryReferences(query, oldName, newName)
    end

    for i, query in ipairs(db.global.searchHistory) do
        db.global.searchHistory[i] = ReplaceCategoryReferences(query, oldName, newName)
    end

    for _, categoryData in pairs(db.global.customCategoriesV2) do
        if categoryData.searchExpression then
            categoryData.searchExpression = ReplaceCategoryReferences(
                categoryData.searchExpression, oldName, newName)
        end
    end
end

local ExpandAll

local function ExpandSavedToken(name, depth, seenSaved, seenCat)
    local SS = ns.SavedSearches
    local normalized = SS and SS:NormalizeName(name)
    if not normalized or depth > MAX_EXPANSION_DEPTH then
        return "(" .. NEVER_MATCH_SAVED .. ")"
    end

    local key = SS:FindKey(normalized)
    if not key or seenSaved[strlower(key)] then
        return "(" .. NEVER_MATCH_SAVED .. ")"
    end

    local query = SS:Get(key)
    if type(query) ~= "string" or query == "" then
        return "(" .. NEVER_MATCH_SAVED .. ")"
    end

    seenSaved[strlower(key)] = true
    local expanded = ExpandAll(query, depth + 1, seenSaved, seenCat)
    seenSaved[strlower(key)] = nil
    return "(" .. expanded .. ")"
end

local function ExpandCategoryToken(name, depth, seenSaved, seenCat)
    local normalized = NormalizeCategoryRefName(name)
    if not normalized or depth > MAX_EXPANSION_DEPTH then
        return "(" .. NEVER_MATCH_CATEGORY .. ")"
    end

    local key = strlower(normalized)
    if seenCat[key] then
        return "(" .. NEVER_MATCH_CATEGORY .. ")"
    end

    local expr, displayName = CategoryRefs:FindSearchExpression(normalized)
    if not expr then
        return "(" .. NEVER_MATCH_CATEGORY .. ")"
    end

    -- Cycle guard uses the resolved display name so casing variants share a key.
    local seenKey = strlower(displayName or normalized)
    seenCat[seenKey] = true
    local expanded = ExpandAll(expr, depth + 1, seenSaved, seenCat)
    seenCat[seenKey] = nil
    return "(" .. expanded .. ")"
end

ExpandAll = function(query, depth, seenSaved, seenCat)
    if type(query) ~= "string" or query == "" then return query end

    depth = depth or 1
    if depth > MAX_EXPANSION_DEPTH then return NEVER_MATCH_CATEGORY end

    seenSaved = seenSaved or {}
    seenCat = seenCat or {}

    local expanded = query
    if strfind(expanded, "SAVED(", 1, true) then
        expanded = strgsub(expanded, "SAVED%(([^%)]*)%)", function(inner)
            return ExpandSavedToken(strmatch(inner or "", "^%s*(.-)%s*$"), depth, seenSaved, seenCat)
        end)
    end
    if strfind(expanded, "CATEGORY(", 1, true) then
        expanded = strgsub(expanded, "CATEGORY%(([^%)]*)%)", function(inner)
            return ExpandCategoryToken(strmatch(inner or "", "^%s*(.-)%s*$"), depth, seenSaved, seenCat)
        end)
    end
    return expanded
end

--- Expand SAVED(Name) and CATEGORY(Name) tokens into PredicateEngine expressions.
---@param query string|nil
---@return string|nil expandedQuery
function SearchExpand:Expand(query)
    return ExpandAll(query, 1, {}, {})
end

--- Expand CATEGORY(Name) only (tests / callers that already expanded SAVED).
---@param query string|nil
---@param depth integer|nil
---@param seen table<string, boolean>|nil
---@return string|nil
function CategoryRefs:Expand(query, depth, seen)
    if type(query) ~= "string" or query == "" then return query end

    depth = depth or 1
    if depth > MAX_EXPANSION_DEPTH then return NEVER_MATCH_CATEGORY end

    seen = seen or {}
    local expanded = strgsub(query, "CATEGORY%(([^%)]*)%)", function(inner)
        return ExpandCategoryToken(strmatch(inner or "", "^%s*(.-)%s*$"), depth, {}, seen)
    end)
    return expanded
end
