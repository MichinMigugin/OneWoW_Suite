local _, ns = ...

-- ============================================================================
-- CategoryRefs
-- ============================================================================
-- Bags' contribution of custom categories to OneWoW.SearchCatalog as the
-- "category" kind, which is what makes CATEGORY(Name) resolve. Category records
-- stay in Bags SavedVariables (customCategoriesV2) and are presented to the
-- catalog through the provider below, so the optional-load-unit boundary holds
-- and Bags import/export stays self-contained.
--
-- Renaming a category rewrites nothing. The catalog keeps the old name in the
-- record's formerNames and keeps resolving it to the same entry, so expressions
-- in Bags history, other categories, core overlays, Mail, QoL and DirectDeposit
-- all keep working without anyone being notified.

local strtrim = strtrim
local type = type
local pairs = pairs
local tinsert = tinsert

ns.CategoryRefs = {}
local CategoryRefs = ns.CategoryRefs

local CATEGORY_KIND = "category"

local categoryRulesChanged = {} ---@type table<string, fun()>

local function GetDB()
    return ns:GetDB()
end

local function NormalizeCategoryRefName(name)
    name = strtrim(name or "")
    if name == "" then return nil end
    return name
end

--- The search expression a category contributes, or nil when it has none.
---
--- Every rule is an expression now, including ones built with the type editor,
--- so `filterMode` is not consulted: it only says which editor to show. An
--- empty body means the category matches purely by its item pins, or that its
--- stored type names did not resolve in this locale. The catalog reports both
--- as `empty` rather than `missing`, which is how a lint can tell "you
--- referenced a category with no rule" from "you referenced nothing".
---@param rec table
---@return string|nil
local function SearchExpressionOf(rec)
    local expr = rec.searchExpression
    if type(expr) ~= "string" or expr == "" then return nil end
    return expr
end

--- Present a category record as a SearchCatalog entry.
---
--- An adapter, not the record: the catalog's field names (`body`) and the
--- record's (`searchExpression`) differ, and the id is the table key rather
--- than a stored field. So nothing written to the adapter reaches the record —
--- which is why the provider supplies `SetName`.
---
--- `formerNames` is the one exception, passed by reference so the catalog's
--- rename bookkeeping writes straight into the record. It is created here when
--- absent rather than only on rename: the alternative is handing the catalog a
--- nil, which it would fill with a table on the throwaway adapter, silently
--- discarding the rename. An empty table per category is a cheap price for
--- making the contract impossible to violate.
---@param id string
---@param rec table
---@return table
local function ToCatalogEntry(id, rec)
    rec.formerNames = rec.formerNames or {}
    return {
        id = id,
        kind = CATEGORY_KIND,
        name = rec.name,
        formerNames = rec.formerNames,
        body = SearchExpressionOf(rec),
    }
end

--- SearchCatalog provider: every custom category, as catalog entries.
---@return table[]
function CategoryRefs:EnumerateCatalogEntries()
    local out = {}
    for id, rec in pairs(GetDB().global.customCategoriesV2) do
        if rec and rec.name then
            tinsert(out, ToCatalogEntry(id, rec))
        end
    end
    return out
end

--- SearchCatalog provider: one category by id.
---@param id string
---@return table|nil
function CategoryRefs:GetCatalogEntry(id)
    local rec = GetDB().global.customCategoriesV2[id]
    if not rec or not rec.name then return nil end
    return ToCatalogEntry(id, rec)
end

--- SearchCatalog provider: write a renamed display name back to the record.
--- Only the name — the catalog does not own anything else about a category, and
--- the Bags-internal rekeying that a rename also needs stays in
--- CategoryController where the rest of that bookkeeping lives.
---@param id string
---@param name string
function CategoryRefs:SetCatalogEntryName(id, name)
    local rec = GetDB().global.customCategoriesV2[id]
    if rec then rec.name = name end
end

--- Find a custom search-mode category by display name (case-insensitive).
--- Resolves through the catalog, so a former name works here too.
---@param name string|nil
---@return string|nil expression
---@return string|nil displayName
function CategoryRefs:FindSearchExpression(name)
    local normalized = NormalizeCategoryRefName(name)
    if not normalized then return nil end

    local entry = OneWoW.SearchCatalog:Resolve(CATEGORY_KIND, normalized)
    if not entry then return nil end
    return entry.body, entry.name
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
    -- Category names and expressions back the catalog's kind-scoped name index,
    -- and the catalog cannot see a write to Bags SavedVariables. Without this,
    -- CATEGORY(...) keeps resolving against the names as they were.
    OneWoW.SearchCatalog:InvalidateKind(CATEGORY_KIND)
    for _, fn in pairs(categoryRulesChanged) do
        fn()
    end
end
