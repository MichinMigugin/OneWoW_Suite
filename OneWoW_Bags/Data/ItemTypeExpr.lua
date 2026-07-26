local _, ns = ...

-- ============================================================================
-- ItemTypeExpr
-- ============================================================================
-- Converts a category's type-mode fields (itemType / itemSubType /
-- typeMatchMode) into a predicate expression over class and subclass ids.
--
-- Why this exists: type mode stored *localized* class names and compared them
-- to localized API output at match time, so changing client language silently
-- broke every type-mode category. Ids are locale-independent, and the predicate
-- engine already exposes them as `class` and `subclass`, so a type-mode
-- category is just an ordinary expression that the user happens to have built
-- with a different editor.
--
-- Names are resolved once, at edit or migration time, against the *current*
-- locale. A name that resolves to nothing cannot be converted — and was already
-- matching nothing before this change, since it did not match the API output
-- either. Those are reported rather than guessed at, with the typed strings
-- preserved so the user can see what to re-pick.

local C_Item = C_Item
local Enum = Enum
local pairs = pairs
local ipairs = ipairs
local type = type
local tinsert = tinsert
local tconcat = table.concat
local strlower = string.lower
local strtrim = strtrim
local format = string.format

ns.ItemTypeExpr = {}
local ItemTypeExpr = ns.ItemTypeExpr

-- Subclass ids are per-class and Blizzard exposes no single enum covering them,
-- so they are probed. Gaps are normal (retired weapon subclasses, for one) and
-- simply yield nil, which is skipped. The ceiling is well clear of the largest
-- live subclass table; a class that ever exceeds it loses only the tail, and
-- those categories then report as unconvertible rather than silently misfiling.
local MAX_SUBCLASS_PROBE = 32

local classByName    ---@type table<string, number>|nil          lowered name -> classID
local subsByClass    ---@type table<number, table<string, number>>|nil  classID -> lowered name -> subClassID

--- Build the localized-name -> id reverse maps, returning both. Session-scoped:
--- the client cannot change language without a full reload, so one build is
--- enough. Returned rather than read from the upvalues so callers hold
--- non-nil locals.
---@return table<string, number> classes
---@return table<number, table<string, number>> subs
local function EnsureMaps()
    if classByName and subsByClass then
        return classByName, subsByClass
    end

    local classes = {}
    local subs = {}

    for _, classID in pairs(Enum.ItemClass) do
        local className = C_Item.GetItemClassInfo(classID)
        if className then
            classes[strlower(className)] = classID

            local classSubs = {}
            for subClassID = 0, MAX_SUBCLASS_PROBE do
                local subName = C_Item.GetItemSubClassInfo(classID, subClassID)
                if subName then
                    classSubs[strlower(subName)] = subClassID
                end
            end
            subs[classID] = classSubs
        end
    end

    classByName = classes
    subsByClass = subs
    return classes, subs
end

--- Drop the cached maps. Only useful for tests and `/reload`-free debugging.
function ItemTypeExpr:InvalidateMaps()
    classByName = nil
    subsByClass = nil
end

--- Every (classID, subClassID) whose localized subclass name matches.
---
--- A subclass name is only unique *within* a class — "Cloth" is both an armor
--- subclass and a trade-goods subclass, with different ids. The old matcher
--- compared names against whatever class the item happened to be, so a
--- subtype-only rule matched across classes. Preserving that means a
--- disjunction over every pair, not a single `subclass=N`.
---@param subs table<number, table<string, number>>
---@param lowerName string
---@return table[] pairs array of { classID, subClassID }
local function SubclassPairs(subs, lowerName)
    local out = {}
    for classID, classSubs in pairs(subs) do
        local subClassID = classSubs[lowerName]
        if subClassID then
            tinsert(out, { classID = classID, subClassID = subClassID })
        end
    end
    return out
end

local function PairsToExpression(list)
    local terms = {}
    for _, p in ipairs(list) do
        tinsert(terms, format("(class=%d & subclass=%d)", p.classID, p.subClassID))
    end
    if #terms == 1 then return terms[1] end
    return "(" .. tconcat(terms, " | ") .. ")"
end

--- Build the expression equivalent of a type-mode rule.
---
--- Returns nil plus a reason when the stored names do not resolve in the current
--- locale. `reason` is a stable key for reporting, never a user-facing string.
---@param itemType string|nil
---@param itemSubType string|nil
---@param typeMatchMode string|nil "or" means either side may match; anything else is AND
---@return string|nil expression
---@return string|nil reason "NO_FIELDS" | "UNKNOWN_TYPE" | "UNKNOWN_SUBTYPE" | "SUBTYPE_NOT_IN_TYPE"
function ItemTypeExpr:Build(itemType, itemSubType, typeMatchMode)
    local classes, subs = EnsureMaps()

    itemType = strtrim(itemType or "")
    itemSubType = strtrim(itemSubType or "")
    local hasType = itemType ~= ""
    local hasSubType = itemSubType ~= ""
    if not hasType and not hasSubType then return nil, "NO_FIELDS" end

    local classID
    if hasType then
        classID = classes[strlower(itemType)]
        if not classID then return nil, "UNKNOWN_TYPE" end
    end

    if not hasSubType then
        return format("class=%d", classID)
    end

    local matches = SubclassPairs(subs, strlower(itemSubType))
    if #matches == 0 then return nil, "UNKNOWN_SUBTYPE" end

    if not hasType then
        return PairsToExpression(matches)
    end

    -- AND: only the pair inside the named class can ever satisfy both sides, so
    -- the disjunction collapses to one term. If the subtype does not exist under
    -- that class the rule was unsatisfiable to begin with — report it rather
    -- than emit an expression that is deliberately always false.
    if typeMatchMode ~= "or" then
        local subClassID = subs[classID] and subs[classID][strlower(itemSubType)]
        if not subClassID then return nil, "SUBTYPE_NOT_IN_TYPE" end
        return format("class=%d & subclass=%d", classID, subClassID)
    end

    return format("(class=%d | %s)", classID, PairsToExpression(matches))
end

--- Convert every type-mode category in place, once.
---
--- Sets `searchExpression`, and pins `filterMode = "type"` so the category keeps
--- opening the type editor. `filterMode` is now only a UI hint — it says which
--- editor to show, never how matching works — so flipping it to "search" here
--- would silently take the type builder away from every category built with it.
---
--- `itemType` / `itemSubType` / `typeMatchMode` are deliberately kept: they are
--- what the type editor round-trips, and for a category that could not be
--- converted they are the only surviving record of what the user meant.
--- `dryRun` reports without writing, for the lint. Worth recomputing rather than
--- storing the migration's result: a client language change can break a category
--- that converted cleanly last session, and can equally repair one that did not,
--- so a stored report goes stale in exactly the case it matters.
---@param categories table<string, table> customCategoriesV2
---@param dryRun boolean|nil
---@return number converted
---@return table[] unconverted array of { id, name, itemType, itemSubType, reason }
function ItemTypeExpr:MigrateCategories(categories, dryRun)
    local converted = 0
    local unconverted = {}

    for id, rec in pairs(categories) do
        if type(rec) == "table" and rec.name and rec.filterMode ~= "search" then
            local hasType = rec.itemType and rec.itemType ~= ""
            local hasSubType = rec.itemSubType and rec.itemSubType ~= ""

            -- A record with neither field is an item-pin-only category, which is
            -- a legitimate mode with nothing to convert, not a failure.
            if hasType or hasSubType then
                local expr, reason = self:Build(rec.itemType, rec.itemSubType, rec.typeMatchMode)
                if expr then
                    if not dryRun then
                        rec.searchExpression = expr
                        rec.filterMode = "type"
                    end
                    converted = converted + 1
                else
                    tinsert(unconverted, {
                        id = id,
                        name = rec.name,
                        itemType = rec.itemType,
                        itemSubType = rec.itemSubType,
                        reason = reason,
                    })
                end
            end
        end
    end

    return converted, unconverted
end
