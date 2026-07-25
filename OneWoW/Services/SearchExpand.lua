local _, ns = ...

-- ============================================================================
-- SearchExpand
-- ============================================================================
-- Suite-wide expand → compile pipeline for SAVED(Name) named expressions and
-- CATEGORY(Name) Bags category search rules. PE stays pure; callers use
-- SearchExpand:Compile / :CheckItem for user-facing expressions.
--
-- Design:
--   - Named expressions live in OneWoW:GetCoreGlobal().searchShortcuts.saved
--   - Keyword synonyms live in searchShortcuts.aliases (pushed to PE)
--   - CATEGORY resolves via an injectable Bags hook (fail-closed when absent)
--   - External text rewriters (Bags searchHistory / category exprs) run on
--     SAVED rename so Bags DB stays consistent without owning the store

local strfind = string.find
local strgsub = string.gsub
local strlower = string.lower
local strmatch = string.match
local strtrim = strtrim
local type = type
local pairs = pairs
local tinsert = tinsert
local sort = sort

ns.SearchExpand = {}
local SearchExpand = ns.SearchExpand

local PE = ns.PredicateEngine
local MAX_EXPANSION_DEPTH = 5
local NEVER_MATCH_SAVED = "#onewow_saved_search_missing"
local NEVER_MATCH_CATEGORY = "#onewow_category_ref_missing"

local categoryResolver ---@type (fun(name: string): string|nil, string|nil)|nil
local externalTextRewriters = {} ---@type table<string, fun(text: string, oldName: string, newName: string): string>
local changeCallbacks = {} ---@type table<string, fun()>

local function GetShortcuts()
    local g = ns.db and ns.db.global
    if not g then return nil end
    local sc = g.searchShortcuts
    if not sc then
        sc = { aliases = {}, saved = {} }
        g.searchShortcuts = sc
    end
    sc.aliases = sc.aliases or {}
    sc.saved = sc.saved or {}
    return sc
end

local function GetSavedStore()
    local sc = GetShortcuts()
    return sc and sc.saved or nil
end

local function FireChanged()
    for _, fn in pairs(changeCallbacks) do
        fn()
    end
end

local function ReplaceSavedReferencesInText(text, oldName, newName)
    if type(text) ~= "string" or text == "" then return text end
    local oldLower = strlower(oldName)
    return strgsub(text, "SAVED%(([^%)]*)%)", function(name)
        local normalized = strtrim(name or "")
        if normalized ~= "" and strlower(normalized) == oldLower then
            return "SAVED(" .. newName .. ")"
        end
        return "SAVED(" .. name .. ")"
    end)
end

--- Register a Bags (or other) CATEGORY resolver.
---@param fn (fun(name: string): string|nil, string|nil)|nil
function SearchExpand:SetCategoryResolver(fn)
    categoryResolver = fn
end

--- Rewrite SAVED(old) → SAVED(new) inside an arbitrary string.
---@param text string|nil
---@param oldName string
---@param newName string
---@return string|nil
function SearchExpand:ReplaceSavedReferencesInText(text, oldName, newName)
    return ReplaceSavedReferencesInText(text, oldName, newName)
end

--- Bags (etc.) register to rewrite SAVED refs in their own SV on rename.
---@param id string
---@param fn fun(text: string, oldName: string, newName: string): string
function SearchExpand:RegisterExternalTextRewriter(id, fn)
    externalTextRewriters[id] = fn
end

---@param id string
function SearchExpand:UnregisterExternalTextRewriter(id)
    externalTextRewriters[id] = nil
end

---@param id string
---@param fn fun()
function SearchExpand:RegisterChangedCallback(id, fn)
    changeCallbacks[id] = fn
end

---@param id string
function SearchExpand:UnregisterChangedCallback(id)
    changeCallbacks[id] = nil
end

--- True when the expression may contain SAVED( or CATEGORY(.
---@param expression string|nil
---@return boolean
function SearchExpand:NeedsExpand(expression)
    return type(expression) == "string"
        and (strfind(expression, "SAVED(", 1, true) ~= nil
            or strfind(expression, "CATEGORY(", 1, true) ~= nil)
end

--- Normalize and validate a saved-expression display name.
---@param name string|nil
---@return string|nil normalizedName
---@return string|nil errorKey
function SearchExpand:NormalizeSavedName(name)
    name = strtrim(name or "")
    if name == "" then return nil, "SAVED_SEARCH_INVALID_NAME" end
    if strfind(name, "[^%w %-%_%+]") then return nil, "SAVED_SEARCH_INVALID_NAME" end
    return name
end

---@param query string|nil
---@return string|nil normalizedQuery
---@return string|nil errorKey
function SearchExpand:NormalizeSavedQuery(query)
    query = strtrim(query or "")
    if query == "" then return nil, "SAVED_SEARCH_EMPTY_QUERY" end
    return query
end

---@param name string|nil
---@return string|nil key
function SearchExpand:FindSavedKey(name)
    local normalized = self:NormalizeSavedName(name)
    if not normalized then return nil end
    local store = GetSavedStore()
    if not store then return nil end
    local wanted = strlower(normalized)
    for key in pairs(store) do
        if strlower(key) == wanted then
            return key
        end
    end
    return nil
end

---@param name string
---@return string|nil query
---@return string|nil key
function SearchExpand:GetSaved(name)
    local key = self:FindSavedKey(name)
    if not key then return nil end
    local store = GetSavedStore()
    return store[key], key
end

---@return table<string, string>
function SearchExpand:GetAllSaved()
    local copy = {}
    local store = GetSavedStore()
    if not store then return copy end
    for name, query in pairs(store) do
        copy[name] = query
    end
    return copy
end

---@return string[]
function SearchExpand:GetSortedSavedNames()
    local names = {}
    local store = GetSavedStore()
    if not store then return names end
    for name in pairs(store) do
        tinsert(names, name)
    end
    sort(names, function(a, b)
        return strlower(a) < strlower(b)
    end)
    return names
end

---@param name string
---@param query string
---@return boolean ok
---@return string normalizedNameOrErrorKey
function SearchExpand:SetSaved(name, query)
    local normalizedName, nameErr = self:NormalizeSavedName(name)
    if not normalizedName then return false, nameErr end
    local normalizedQuery, queryErr = self:NormalizeSavedQuery(query)
    if not normalizedQuery then return false, queryErr end

    local store = GetSavedStore()
    if not store then return false, "SAVED_SEARCH_INVALID_NAME" end

    local existingKey = self:FindSavedKey(normalizedName)
    if existingKey and existingKey ~= normalizedName then
        store[existingKey] = nil
    end
    store[normalizedName] = normalizedQuery
    FireChanged()
    return true, normalizedName
end

---@param oldName string
---@param newName string
---@return boolean ok
---@return string normalizedNameOrErrorKey
function SearchExpand:RenameSaved(oldName, newName)
    local existingQuery, existingKey = self:GetSaved(oldName)
    if not existingKey then return false, "SAVED_SEARCH_NOT_FOUND" end

    local normalizedNewName, err = self:NormalizeSavedName(newName)
    if not normalizedNewName then return false, err end

    local collisionKey = self:FindSavedKey(normalizedNewName)
    if collisionKey and strlower(collisionKey) ~= strlower(existingKey) then
        return false, "SAVED_SEARCH_DUPLICATE_NAME"
    end

    local store = GetSavedStore()
    store[existingKey] = nil
    store[normalizedNewName] = existingQuery

    for savedName, query in pairs(store) do
        store[savedName] = ReplaceSavedReferencesInText(query, existingKey, normalizedNewName)
    end

    for _, rewriter in pairs(externalTextRewriters) do
        rewriter(existingKey, normalizedNewName)
    end

    FireChanged()
    return true, normalizedNewName
end

---@param name string
---@return boolean ok
---@return string|nil errorKey
function SearchExpand:DeleteSaved(name)
    local key = self:FindSavedKey(name)
    if not key then return false, "SAVED_SEARCH_NOT_FOUND" end
    GetSavedStore()[key] = nil
    FireChanged()
    return true
end

-- ---- Alias persistence (SV ↔ PE) ----

--- Push searchShortcuts.aliases into PE and return the live map.
function SearchExpand:ApplyAliasesFromDB()
    local sc = GetShortcuts()
    PE:RegisterAliases(sc.aliases)
end

---@param alias string
---@param targetKeyword string
---@return boolean ok
---@return string|nil errorKey
function SearchExpand:SetAlias(alias, targetKeyword)
    local ok, err = PE:RegisterAlias(alias, targetKeyword)
    if not ok then return false, err end
    local sc = GetShortcuts()
    local key = strlower(strtrim(alias:gsub("^#", "")))
    local target = strlower(strtrim(targetKeyword:gsub("^#", "")))
    sc.aliases[key] = target
    -- Drop any prior casing variant
    for k in pairs(sc.aliases) do
        if k ~= key and strlower(k) == key then
            sc.aliases[k] = nil
        end
    end
    FireChanged()
    return true
end

--- Rename an existing alias key; target stays the same.
---@param oldAlias string
---@param newAlias string
---@return boolean ok
---@return string|nil errorKey
function SearchExpand:RenameAlias(oldAlias, newAlias)
    local sc = GetShortcuts()
    local oldKey = strlower(strtrim((oldAlias or ""):gsub("^#", "")))
    local newKey = strlower(strtrim((newAlias or ""):gsub("^#", "")))
    if oldKey == "" or not sc.aliases[oldKey] then return false, "ALIAS_INVALID" end
    if newKey == "" then return false, "ALIAS_INVALID" end
    if not string.match(newKey, "^[%w_]+$") then return false, "ALIAS_INVALID_NAME" end
    if newKey == oldKey then return true end
    if PE:IsBuiltinKeyword(newKey) then return false, "ALIAS_COLLIDES_BUILTIN" end
    if sc.aliases[newKey] then return false, "ALIAS_DUPLICATE" end

    local target = sc.aliases[oldKey]
    local ok, err = PE:RegisterAlias(newKey, target)
    if not ok then return false, err end
    sc.aliases[oldKey] = nil
    sc.aliases[newKey] = target
    PE:RegisterAliases(sc.aliases)
    FireChanged()
    return true
end

---@param alias string
---@return boolean ok
function SearchExpand:DeleteAlias(alias)
    local sc = GetShortcuts()
    local key = strlower(strtrim((alias or ""):gsub("^#", "")))
    if key == "" or not sc.aliases[key] then return false end
    sc.aliases[key] = nil
    PE:RegisterAliases(sc.aliases)
    FireChanged()
    return true
end

---@return table<string, string>
function SearchExpand:GetAliases()
    local sc = GetShortcuts()
    local copy = {}
    for k, v in pairs(sc.aliases) do
        copy[k] = v
    end
    return copy
end

-- ---- Expand / Compile / CheckItem ----

local ExpandAll

local function ExpandSavedToken(name, depth, seenSaved, seenCat)
    local normalized = SearchExpand:NormalizeSavedName(name)
    if not normalized or depth > MAX_EXPANSION_DEPTH then
        return "(" .. NEVER_MATCH_SAVED .. ")"
    end

    local key = SearchExpand:FindSavedKey(normalized)
    if not key or seenSaved[strlower(key)] then
        return "(" .. NEVER_MATCH_SAVED .. ")"
    end

    local query = GetSavedStore()[key]
    if type(query) ~= "string" or query == "" then
        return "(" .. NEVER_MATCH_SAVED .. ")"
    end

    seenSaved[strlower(key)] = true
    local expanded = ExpandAll(query, depth + 1, seenSaved, seenCat)
    seenSaved[strlower(key)] = nil
    return "(" .. expanded .. ")"
end

local function ExpandCategoryToken(name, depth, seenSaved, seenCat)
    local normalized = strtrim(name or "")
    if normalized == "" or depth > MAX_EXPANSION_DEPTH then
        return "(" .. NEVER_MATCH_CATEGORY .. ")"
    end

    local key = strlower(normalized)
    if seenCat[key] then
        return "(" .. NEVER_MATCH_CATEGORY .. ")"
    end

    if not categoryResolver then
        return "(" .. NEVER_MATCH_CATEGORY .. ")"
    end

    local expr, displayName = categoryResolver(normalized)
    if not expr then
        return "(" .. NEVER_MATCH_CATEGORY .. ")"
    end

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

---@param query string|nil
---@return string|nil
function SearchExpand:Expand(query)
    return ExpandAll(query, 1, {}, {})
end

---@param expr string|nil
---@return (fun(props: table): boolean)|nil
---@return string|nil errorMessage
function SearchExpand:Compile(expr)
    if not expr or expr == "" then return nil end
    local expanded = self:Expand(expr)
    return PE:Compile(expanded)
end

---@param expr string|nil
---@param itemID number|nil
---@param bagID number|nil
---@param slotID number|nil
---@param itemInfo string|table|nil
---@return boolean
function SearchExpand:CheckItem(expr, itemID, bagID, slotID, itemInfo)
    if not expr or expr == "" or not itemID then return false end
    local expanded = self:Expand(expr)
    return PE:CheckItem(expanded, itemID, bagID, slotID, itemInfo)
end

--- One-time migrate Bags savedSearches into core store.
---@param bagsSaved table<string, string>|nil
function SearchExpand:MigrateFromBagsSavedSearches(bagsSaved)
    if type(bagsSaved) ~= "table" then return end
    local store = GetSavedStore()
    if not store then return end
    for name, query in pairs(bagsSaved) do
        if type(name) == "string" and type(query) == "string" and name ~= "" and query ~= "" then
            local existing = self:FindSavedKey(name)
            if not existing then
                store[name] = query
            end
        end
    end
end

ns:RegisterCoreLoginHandler("SearchExpand.ApplyAliases", function()
    SearchExpand:ApplyAliasesFromDB()
end)
