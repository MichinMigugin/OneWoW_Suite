local _, OneWoW_Bags = ...

-- ============================================================================
-- SavedSearches
-- ============================================================================
-- Stores user-defined predicate shortcuts as displayName -> predicate string in
-- db.global.savedSearches. Expressions can reference them with SAVED(Name);
-- the reference is expanded before PredicateEngine sees the search.
--
-- Design rules:
--   - Names compare case-insensitively, but the display casing is preserved.
--   - Missing or cyclic references fail closed by expanding to a never-match
--     PredicateEngine keyword.
--   - Mutations invalidate categorization because custom categories may depend
--     on saved searches.

local strfind = string.find
local strgsub = string.gsub
local strlower = string.lower
local strmatch = string.match
local strtrim = strtrim
local type = type
local ipairs = ipairs
local pairs = pairs
local sort = sort
local tinsert = tinsert

OneWoW_Bags.SavedSearches = {}
local SavedSearches = OneWoW_Bags.SavedSearches

local MAX_EXPANSION_DEPTH = 5
-- PredicateEngine treats unknown #keywords as false, making this a safe
-- fail-closed expression for missing, invalid, or cyclic saved searches.
local NEVER_MATCH = "#onewow_saved_search_missing"

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local function GetStore()
    return GetDB().global.savedSearches
end

local function ReplaceReferences(self, text, oldName, newName)
    if type(text) ~= "string" or text == "" then return text end

    local oldLower = strlower(oldName)
    return strgsub(text, "SAVED%(([^%)]*)%)", function(name)
        local normalized = self:NormalizeName(name)
        if normalized and strlower(normalized) == oldLower then
            return "SAVED(" .. newName .. ")"
        end
        return "SAVED(" .. name .. ")"
    end)
end

local function ReplaceReferencesInDB(self, db, oldName, newName)
    for savedName, query in pairs(db.global.savedSearches) do
        db.global.savedSearches[savedName] = ReplaceReferences(self, query, oldName, newName)
    end

    for i, query in ipairs(db.global.searchHistory) do
        db.global.searchHistory[i] = ReplaceReferences(self, query, oldName, newName)
    end

    for _, categoryData in pairs(db.global.customCategoriesV2) do
        if categoryData.searchExpression then
            categoryData.searchExpression = ReplaceReferences(self, categoryData.searchExpression, oldName, newName)
        end
    end
end

-- Expands one SAVED(Name) token. The seen set prevents recursive references
-- from looping indefinitely while still allowing nested saved searches.
local function ExpandToken(self, name, depth, seen)
    local normalized = self:NormalizeName(name)
    if not normalized or depth > MAX_EXPANSION_DEPTH then return "(" .. NEVER_MATCH .. ")" end

    local key = self:FindKey(normalized)
    if not key or seen[strlower(key)] then return "(" .. NEVER_MATCH .. ")" end

    seen[strlower(key)] = true
    local expanded = self:Expand(GetStore()[key], depth + 1, seen)
    seen[strlower(key)] = nil
    return "(" .. expanded .. ")"
end

--- Normalize and validate a saved search display name.
--- Names may contain letters, numbers, spaces, hyphen, underscore, and plus.
---@param name string|nil
---@return string|nil normalizedName
---@return string|nil errorKey
function SavedSearches:NormalizeName(name)
    name = strtrim(name or "")
    if name == "" then return nil, "SAVED_SEARCH_INVALID_NAME" end
    if strfind(name, "[^%w %-%_%+]") then return nil, "SAVED_SEARCH_INVALID_NAME" end
    return name
end

--- Normalize and validate a predicate search string before saving it.
---@param query string|nil
---@return string|nil normalizedQuery
---@return string|nil errorKey
function SavedSearches:NormalizeQuery(query)
    query = strtrim(query or "")
    if query == "" then return nil, "SAVED_SEARCH_EMPTY_QUERY" end
    return query
end

--- Find the stored display key for a saved search name.
--- Lookup is case-insensitive and returns the preserved display casing.
---@param name string|nil
---@return string|nil key
function SavedSearches:FindKey(name)
    local normalized = self:NormalizeName(name)
    if not normalized then return nil end

    local wanted = strlower(normalized)
    for key in pairs(GetStore()) do
        if strlower(key) == wanted then
            return key
        end
    end
    return nil
end

--- Get a saved search predicate by name.
---@param name string
---@return string|nil query
---@return string|nil key Stored display key when found.
function SavedSearches:Get(name)
    local key = self:FindKey(name)
    if not key then return nil end
    return GetStore()[key], key
end

--- Return a copy of all saved searches keyed by display name.
---@return table<string, string> savedSearches
function SavedSearches:GetAll()
    local copy = {}
    for name, query in pairs(GetStore()) do
        copy[name] = query
    end
    return copy
end

--- Return saved search display names sorted alphabetically.
---@return string[] names
function SavedSearches:GetSortedNames()
    local names = {}
    for name in pairs(GetStore()) do
        tinsert(names, name)
    end
    sort(names, function(a, b)
        return strlower(a) < strlower(b)
    end)
    return names
end

--- Create or overwrite a saved search.
--- Mutates SavedVariables and refreshes categorization/layout consumers.
---@param name string
---@param query string
---@return boolean ok
---@return string normalizedNameOrErrorKey
function SavedSearches:Set(name, query)
    local normalizedName, nameErr = self:NormalizeName(name)
    if not normalizedName then return false, nameErr end

    local normalizedQuery, queryErr = self:NormalizeQuery(query)
    if not normalizedQuery then return false, queryErr end

    local store = GetStore()
    local existingKey = self:FindKey(normalizedName)
    if existingKey and existingKey ~= normalizedName then
        store[existingKey] = nil
    end
    store[normalizedName] = normalizedQuery

    OneWoW_Bags:InvalidateCategorization()
    OneWoW_Bags:RequestLayoutRefresh("all")
    if OneWoW_Bags.Settings and OneWoW_Bags.Settings.RefreshSavedSearchRows then
        OneWoW_Bags.Settings:RefreshSavedSearchRows()
    end
    return true, normalizedName
end

--- Rename a saved search and update SAVED(oldName) references.
--- References are updated in saved searches, search history, and custom
--- category expressions.
---@param oldName string
---@param newName string
---@return boolean ok
---@return string normalizedNameOrErrorKey
function SavedSearches:Rename(oldName, newName)
    local existingQuery, existingKey = self:Get(oldName)
    if not existingKey then return false, "SAVED_SEARCH_NOT_FOUND" end

    local normalizedNewName, err = self:NormalizeName(newName)
    if not normalizedNewName then return false, err end

    local collisionKey = self:FindKey(normalizedNewName)
    if collisionKey and strlower(collisionKey) ~= strlower(existingKey) then
        return false, "SAVED_SEARCH_DUPLICATE_NAME"
    end

    local db = GetDB()
    local store = db.global.savedSearches
    store[existingKey] = nil
    store[normalizedNewName] = existingQuery
    ReplaceReferencesInDB(self, db, existingKey, normalizedNewName)

    OneWoW_Bags:InvalidateCategorization()
    OneWoW_Bags:RequestLayoutRefresh("all")
    if OneWoW_Bags.Settings and OneWoW_Bags.Settings.RefreshSavedSearchRows then
        OneWoW_Bags.Settings:RefreshSavedSearchRows()
    end
    return true, normalizedNewName
end

--- Delete a saved search by name.
--- Existing SAVED(Name) references are intentionally left as fail-closed terms.
---@param name string
---@return boolean ok
---@return string|nil errorKey
function SavedSearches:Delete(name)
    local key = self:FindKey(name)
    if not key then return false, "SAVED_SEARCH_NOT_FOUND" end

    GetStore()[key] = nil
    OneWoW_Bags:InvalidateCategorization()
    OneWoW_Bags:RequestLayoutRefresh("all")
    if OneWoW_Bags.Settings and OneWoW_Bags.Settings.RefreshSavedSearchRows then
        OneWoW_Bags.Settings:RefreshSavedSearchRows()
    end
    return true
end

--- Expand SAVED(Name) tokens into PredicateEngine expressions.
--- Public callers should pass only `query`; `depth` and `seen` are used for
--- recursive expansion and cycle detection.
---@param query string|nil
---@param depth integer|nil Internal recursion depth.
---@param seen table<string, boolean>|nil Internal recursion guard.
---@return string|nil expandedQuery
function SavedSearches:Expand(query, depth, seen)
    if type(query) ~= "string" or query == "" then return query end

    depth = depth or 1
    if depth > MAX_EXPANSION_DEPTH then return NEVER_MATCH end

    seen = seen or {}
    local expanded = strgsub(query, "SAVED%(([^%)]*)%)", function(name)
        return ExpandToken(self, strmatch(name or "", "^%s*(.-)%s*$"), depth, seen)
    end)

    return expanded
end
