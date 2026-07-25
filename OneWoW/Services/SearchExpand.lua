local _, ns = ...

-- ============================================================================
-- SearchExpand
-- ============================================================================
-- Suite-wide expand → compile pipeline for SAVED(Name) named expressions and
-- CATEGORY(Name) Bags category search rules. PE stays pure; callers use
-- SearchExpand:Compile / :CheckItem for user-facing expressions.
--
-- Design:
--   - Named expressions and keyword synonyms are entries in OneWoW.SearchCatalog
--     (kinds "saved" and "token"); this file is the expand/compile front end
--   - Renames are absorbed by catalog former-name redirects, so no stored
--     expression text is ever rewritten
--   - PE holds no user state: it calls back here for any #token it does not
--     recognize, so a token body can be any expression, not just one keyword
--   - CATEGORY resolves through the catalog too, over entries contributed by a
--     Bags-registered provider. With Bags absent the kind is simply empty and
--     every CATEGORY(...) fails closed, same as before

local strfind = string.find
local strgsub = string.gsub
local strlower = string.lower
local strmatch = string.match
local strtrim = strtrim
local type = type
local ipairs = ipairs
local pairs = pairs
local tinsert = tinsert

ns.SearchExpand = {}
local SearchExpand = ns.SearchExpand

local PE = ns.PredicateEngine
local SC = ns.SearchCatalog
local MAX_EXPANSION_DEPTH = 5

-- Never-match sentinels, distinct per kind *and* reason. `missing` is a typo or
-- a deleted entry; `empty` is an entry that exists but carries no rule, which
-- for CATEGORY means a type-mode Bags category. Collapsing the two would leave
-- the Phase 6 lint unable to tell "you referenced something that is gone" from
-- "that category matches by item type, so it cannot be referenced".
--
-- Cycles and depth overruns report as `missing`: they are a different class of
-- problem and get their own report rather than being inferred from expanded
-- text. SearchCatalog reserves the `onewow_` token prefix so a user-defined
-- token can never resolve one of these and turn a fail-closed into a match.
local NEVER_MATCH = {
    saved = {
        missing = "#onewow_saved_missing",
        empty   = "#onewow_saved_empty",
    },
    category = {
        missing = "#onewow_category_missing",
        empty   = "#onewow_category_empty",
    },
}

local function NeverMatch(kind, reason)
    return "(" .. NEVER_MATCH[kind][reason] .. ")"
end

-- The catalog speaks generic error keys; these map them onto the locale keys
-- the Search Shortcuts UI already renders per section.
local ALIAS_ERRORS = {
    CATALOG_INVALID_NAME   = "ALIAS_INVALID_NAME",
    CATALOG_DUPLICATE_NAME = "ALIAS_DUPLICATE",
    CATALOG_NAME_RESERVED  = "ALIAS_COLLIDES_BUILTIN",
    CATALOG_EMPTY_BODY     = "ALIAS_INVALID",
    CATALOG_NOT_FOUND      = "ALIAS_INVALID",
}

local SAVED_ERRORS = {
    CATALOG_INVALID_NAME   = "SAVED_SEARCH_INVALID_NAME",
    CATALOG_DUPLICATE_NAME = "SAVED_SEARCH_DUPLICATE_NAME",
    CATALOG_EMPTY_BODY     = "SAVED_SEARCH_EMPTY_QUERY",
    CATALOG_NOT_FOUND      = "SAVED_SEARCH_NOT_FOUND",
}

local changeCallbacks = {} ---@type table<string, fun()>

-- gsub returns (string, count); the extra parens drop the count so it cannot
-- land on strtrim's second parameter, which is a set of characters to trim.
local function StripHash(text)
    return strtrim((strgsub(text or "", "^#", "")))
end

local function FireChanged()
    for _, fn in pairs(changeCallbacks) do
        fn()
    end
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
    local entry = SC:Resolve("saved", name)
    return entry and entry.name or nil
end

---@param name string
---@return string|nil query
---@return string|nil key
function SearchExpand:GetSaved(name)
    local entry = SC:Resolve("saved", name)
    if not entry then return nil end
    return entry.body, entry.name
end

---@return table<string, string>
function SearchExpand:GetAllSaved()
    local copy = {}
    for _, entry in ipairs(SC:GetAll("saved")) do
        copy[entry.name] = entry.body
    end
    return copy
end

---@return string[]
function SearchExpand:GetSortedSavedNames()
    local names = {}
    for _, entry in ipairs(SC:GetAll("saved")) do
        tinsert(names, entry.name)
    end
    return names
end

---@param name string
---@param query string
---@return boolean ok
---@return string normalizedNameOrErrorKey
function SearchExpand:SetSaved(name, query)
    local entry, err = SC:Set("saved", name, query)
    if not entry then return false, SAVED_ERRORS[err] or err end
    return true, entry.name
end

--- Rename a named expression. Expressions elsewhere that still say SAVED(old)
--- keep resolving through the catalog's former-name redirect, so nothing that
--- stores expression text has to be rewritten.
---@param oldName string
---@param newName string
---@return boolean ok
---@return string normalizedNameOrErrorKey
function SearchExpand:RenameSaved(oldName, newName)
    local entry = SC:Resolve("saved", oldName)
    if not entry then return false, "SAVED_SEARCH_NOT_FOUND" end

    local ok, err = SC:Rename("saved", entry.id, newName)
    if not ok then return false, SAVED_ERRORS[err] or err end
    return true, entry.name
end

---@param name string
---@return boolean ok
---@return string|nil errorKey
function SearchExpand:DeleteSaved(name)
    local entry = SC:Resolve("saved", name)
    if not entry then return false, "SAVED_SEARCH_NOT_FOUND" end
    SC:Delete("saved", entry.id)
    return true
end

-- ---- Tokens (#name): catalog entries, resolved on demand by PE ----
--
-- A keyword synonym is a catalog "token" entry whose body is the "#keyword" it
-- stands for, so tokens share the entry model with SAVED rather than needing a
-- separate target field. The engine no longer keeps an alias table of its own:
-- it calls the resolver below for any #token it does not recognize, which means
-- a token body may be an arbitrary expression, not just one built-in keyword.
--
-- The alias-shaped subset is still projected out for the current Search
-- Shortcuts UI, whose editor is a built-in-keyword dropdown.

---@param entry table
---@return string|nil keyword
local function AliasTargetOf(entry)
    return strmatch(entry.body or "", "^#([%w_]+)$")
end

--- Resolve a #token to an expression body for PredicateEngine. Catalog lookup
--- handles current *and* former names, so a renamed token keeps evaluating in
--- expressions written before the rename. The body is expanded here so it may
--- contain SAVED(...) / CATEGORY(...); nested #token is left for PE, which
--- compiles recursively and owns the cycle guard.
---@param name string lowercased token name, no leading #
---@return string|nil body
local function ResolveToken(name)
    local body = SC:GetBody("token", name)
    if not body then return nil end
    return SearchExpand:Expand(body)
end

--- Every token entry, sorted by name. Includes entries shadowed by a built-in
--- keyword — call `IsTokenShadowed` to tell them apart.
---@return table[]
function SearchExpand:GetTokens()
    return SC:GetAll("token")
end

--- True when a built-in keyword of the same name exists, which wins outright.
---
--- The catalog rejects reserved names at validation time, but #upgrade,
--- #combineready and #disenchantable register long after login, and migrations
--- run before any of them. So a token minted early can be shadowed later
--- through no fault of the user, and the result is a stored entry that silently
--- never matches. Surfaced rather than deleted: the body is still their data.
---@param name string|nil
---@return boolean
function SearchExpand:IsTokenShadowed(name)
    return PE:IsBuiltinKeyword(name)
end

--- Token entries currently shadowed by a built-in keyword, for lint and UI.
---@return table[]
function SearchExpand:GetShadowedTokens()
    local out = {}
    for _, entry in ipairs(SC:GetAll("token")) do
        if PE:IsBuiltinKeyword(entry.name) then tinsert(out, entry) end
    end
    return out
end

--- User tokens whose expression matches this item (alphabetically). The engine
--- counterpart, `PE:GetMatchingKeywords`, covers built-ins only.
---@param itemID number|nil
---@param bagID number|nil
---@param slotID number|nil
---@param itemInfo string|table|nil
---@return string[]
function SearchExpand:GetMatchingTokens(itemID, bagID, slotID, itemInfo)
    local results = {}
    if not itemID then return results end

    local props = PE:BuildProps(itemID, bagID, slotID, itemInfo)
    if not props then return results end

    for _, entry in ipairs(SC:GetAll("token")) do
        if not PE:IsBuiltinKeyword(entry.name) then
            local compiled = PE:Compile("#" .. entry.name)
            if compiled and PE:SafeEvaluate(compiled, props) then
                tinsert(results, entry.name)
            end
        end
    end
    return results
end

---@param alias string
---@param targetKeyword string
---@return boolean ok
---@return string|nil errorKey
function SearchExpand:SetAlias(alias, targetKeyword)
    local target = strlower(StripHash(targetKeyword))
    if target == "" then return false, "ALIAS_INVALID" end
    if not PE:IsBuiltinKeyword(target) then return false, "ALIAS_TARGET_MISSING" end

    local entry, err = SC:Set("token", StripHash(alias), "#" .. target)
    if not entry then return false, ALIAS_ERRORS[err] or err end
    return true
end

--- Rename an existing alias; the target keyword stays the same.
---@param oldAlias string
---@param newAlias string
---@return boolean ok
---@return string|nil errorKey
function SearchExpand:RenameAlias(oldAlias, newAlias)
    local entry = SC:Resolve("token", StripHash(oldAlias))
    if not entry then return false, "ALIAS_INVALID" end

    local ok, err = SC:Rename("token", entry.id, StripHash(newAlias))
    if not ok then return false, ALIAS_ERRORS[err] or err end
    return true
end

---@param alias string
---@return boolean ok
function SearchExpand:DeleteAlias(alias)
    local entry = SC:Resolve("token", StripHash(alias))
    if not entry then return false end
    return SC:Delete("token", entry.id)
end

---@return table<string, string>
function SearchExpand:GetAliases()
    local copy = {}
    for _, entry in ipairs(SC:GetAll("token")) do
        local target = AliasTargetOf(entry)
        if target then copy[entry.name] = target end
    end
    return copy
end

-- ---- Expand / Compile / CheckItem ----

local ExpandAll

--- Expand one SAVED(...) or CATEGORY(...) reference. Both kinds now resolve the
--- same way — through the catalog — so they share one implementation; the only
--- difference is which kind is looked up and which sentinels are emitted.
---
--- The recursion guard keys on kind + entry id rather than on the name text.
--- One entry can be referenced by its current name in one place and a former
--- name in another, and only an id-keyed guard sees those as the same entry.
---@param kind string "saved" | "category"
---@param name string
---@param depth number
---@param seen table<string, boolean>
---@return string
local function ExpandRef(kind, name, depth, seen)
    if depth > MAX_EXPANSION_DEPTH then
        return NeverMatch(kind, "missing")
    end

    local entry = SC:Resolve(kind, name)
    if not entry then return NeverMatch(kind, "missing") end

    local key = kind .. "\0" .. entry.id
    if seen[key] then return NeverMatch(kind, "missing") end

    if type(entry.body) ~= "string" or entry.body == "" then
        return NeverMatch(kind, "empty")
    end

    seen[key] = true
    local expanded = ExpandAll(entry.body, depth + 1, seen)
    seen[key] = nil
    return "(" .. expanded .. ")"
end

ExpandAll = function(query, depth, seen)
    if type(query) ~= "string" or query == "" then return query end

    depth = depth or 1
    if depth > MAX_EXPANSION_DEPTH then return NeverMatch("saved", "missing") end

    seen = seen or {}

    local expanded = query
    if strfind(expanded, "SAVED(", 1, true) then
        expanded = strgsub(expanded, "SAVED%(([^%)]*)%)", function(inner)
            return ExpandRef("saved", strtrim(inner or ""), depth, seen)
        end)
    end
    if strfind(expanded, "CATEGORY(", 1, true) then
        expanded = strgsub(expanded, "CATEGORY%(([^%)]*)%)", function(inner)
            return ExpandRef("category", strtrim(inner or ""), depth, seen)
        end)
    end
    return expanded
end

---@param query string|nil
---@return string|nil
function SearchExpand:Expand(query)
    return ExpandAll(query, 1, {})
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

--- One-time migrate Bags savedSearches into the core catalog.
---@param bagsSaved table<string, string>|nil
function SearchExpand:MigrateFromBagsSavedSearches(bagsSaved)
    if type(bagsSaved) ~= "table" then return end
    for name, query in pairs(bagsSaved) do
        if type(name) == "string" and type(query) == "string" and not SC:Resolve("saved", name) then
            SC:Set("saved", name, query)
        end
    end
end

-- The engine pulls token bodies through this resolver instead of being pushed a
-- map, so there is nothing to apply on login — the first #token that needs it
-- resolves on demand.
PE:SetKeywordResolver(ResolveToken)

-- Every mutation now lands in the catalog, including ones made by other units,
-- so subscribe once there rather than firing from each wrapper above. PE's
-- token and expression caches are dropped before subscribers run, so a
-- re-categorize compiles against the new bodies rather than the old ones.
SC:RegisterChangedCallback("SearchExpand", function()
    PE:InvalidateKeywordTokens()
    FireChanged()
end)
