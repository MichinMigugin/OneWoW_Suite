local _, ns = ...

ns.ImportExport = ns.ImportExport or {}
ns.ImportExport.Applier = ns.ImportExport.Applier or {}
local Applier = ns.ImportExport.Applier

local Backup = ns.ImportExport.Backup
local Util = ns.ImportExport.Util

local pairs, ipairs, type = pairs, ipairs, type
local tinsert = table.insert
local strtrim = strtrim

local normKey  = Util.NormKey
local deepCopy = Util.DeepCopy

local function existingSnapshot(db)
    local g = db.global
    local snap = {
        sectionsByName = {},
        categoriesByName = {},
    }
    for sid, sec in pairs(g.categorySections or {}) do
        if sec and sec.name then
            snap.sectionsByName[normKey(sec.name)] = { id = sid, data = sec }
        end
    end
    for cid, cat in pairs(g.customCategoriesV2 or {}) do
        if cat and cat.name then
            snap.categoriesByName[normKey(cat.name)] = { id = cid, data = cat }
        end
    end
    return snap
end

-- ------------------------------------------------------------------
-- Merge semantics
-- ------------------------------------------------------------------
-- Rules (plan doc, section 5):
--   items                     -> union (existing + imported)
--   filterMode search vs type -> search wins; imported search overwrites when both search
--   modifications fields      -> imported wins when present (sortMode, subSortMode,
--     sortDescending, subSortDescending, groupBy, subGroupBy, priority, color)
--   enabled                   -> imported=false overrides; otherwise existing stays
--   sortOrder                 -> existing preserved
local function mergeItems(existing, incoming)
    existing.items = existing.items or {}
    if type(incoming) ~= "table" then return end
    for k, v in pairs(incoming) do
        if v then existing.items[k] = true end
    end
end

local function mergeCategoryData(existing, imported)
    mergeItems(existing, imported.items)

    -- Matching is always the expression now; filterMode only says which editor a
    -- category opens. The precedence below is unchanged, but a type-based import
    -- has to be compiled into an expression on the way in, because a payload
    -- written before that change carries localized type names and no expression.
    local existingIsSearch = existing.filterMode == "search"
    local importedIsSearch = imported.filterMode == "search"

    if importedIsSearch then
        -- imported search always wins — whether over type or over existing search
        existing.filterMode       = "search"
        existing.searchExpression = imported.searchExpression
        existing.itemType         = nil
        existing.itemSubType      = nil
        existing.typeMatchMode    = nil
    elseif not existingIsSearch and imported.filterMode == "type" then
        -- both type-based: imported wins on rule fields
        existing.filterMode    = "type"
        existing.itemType      = imported.itemType
        existing.itemSubType   = imported.itemSubType
        existing.typeMatchMode = imported.typeMatchMode
        -- Resolved against *this* client's locale. A name the importer's locale
        -- knew and ours does not yields nil, leaving the category on its item
        -- pins and reported by the lint, which is the same outcome as a local
        -- category whose type names stopped resolving.
        existing.searchExpression = imported.searchExpression
            or ns.ItemTypeExpr:Build(imported.itemType, imported.itemSubType, imported.typeMatchMode)
    end
    -- existing search + imported type: leave existing alone (search > type)

    if imported.enabled == false then
        existing.enabled = false
    end
    -- never touch existing.sortOrder or name
    if imported.isTSM then existing.isTSM = true end
    if imported.isBaganator then existing.isBaganator = true end
end

local function mergeModifications(existingMod, importedMod)
    if type(importedMod) ~= "table" then return existingMod end
    existingMod = existingMod or {}

    for _, field in ipairs({ "sortMode", "subSortMode", "sortDescending", "subSortDescending", "groupBy", "subGroupBy", "priority", "color" }) do
        if importedMod[field] ~= nil then
            existingMod[field] = importedMod[field]
        end
    end

    if importedMod.appliesIn then
        existingMod.appliesIn = deepCopy(importedMod.appliesIn)
    end
    if importedMod.forceOwnLine then
        existingMod.forceOwnLine = existingMod.forceOwnLine or {}
        for k, v in pairs(importedMod.forceOwnLine) do
            if v then existingMod.forceOwnLine[k] = true end
        end
    end
    if importedMod.addedItems then
        existingMod.addedItems = existingMod.addedItems or {}
        for k, v in pairs(importedMod.addedItems) do
            if v then existingMod.addedItems[k] = true end
        end
    end
    return existingMod
end

-- ------------------------------------------------------------------
-- Section handling
-- ------------------------------------------------------------------

local function applySectionFlags(dbSec, section)
    if not dbSec or not section then return end
    if section.collapsed ~= nil then dbSec.collapsed = section.collapsed end
    if section.showHeader ~= nil then dbSec.showHeader = section.showHeader end
    if section.showHeaderBank ~= nil then dbSec.showHeaderBank = section.showHeaderBank end
    if section.isBaganator then dbSec.isBaganator = true end
    if section.isTSM then dbSec.isTSM = true end
end

local function ensureSection(section, controller, planIdToDbId)
    if section.mergesWithExistingId then
        planIdToDbId[section.originalId or section] = section.mergesWithExistingId
        local dbSec = controller:GetDB().global.categorySections[section.mergesWithExistingId]
        applySectionFlags(dbSec, section)
        return section.mergesWithExistingId
    end

    local name = strtrim(section.name or "")
    if name == "" then return nil end

    local newId, err = controller:CreateSection(name)
    if not newId then
        -- Section with same name was created earlier in this apply pass;
        -- try to resolve via live DB state.
        local snap = existingSnapshot(controller:GetDB())
        local hit = snap.sectionsByName[normKey(name)]
        if hit then
            planIdToDbId[section.originalId or section] = hit.id
            applySectionFlags(hit.data, section)
            return hit.id
        end
        return nil, err
    end

    applySectionFlags(controller:GetDB().global.categorySections[newId], section)
    planIdToDbId[section.originalId or section] = newId
    return newId
end

-- ------------------------------------------------------------------
-- Unmapped-defaults -> Baganator Import section
-- ------------------------------------------------------------------

local function ensureBaganatorImportSection(controller, catchAllLabel)
    local db = controller:GetDB()
    local snap = existingSnapshot(db)
    local hit = snap.sectionsByName[normKey(catchAllLabel)]
    if hit then return hit.id end
    local newId = controller:CreateSection(catchAllLabel)
    if newId then
        local dbSec = db.global.categorySections[newId]
        if dbSec then
            dbSec.isBaganator = true
        end
    end
    return newId
end

-- ------------------------------------------------------------------
-- Category resolution
-- ------------------------------------------------------------------

local function applyCategory(category, controller, nameRemap)
    local importedName = strtrim(category.name or "")
    if importedName == "" then
        return nil, "empty name"
    end

    local db = controller:GetDB()

    if category.isNew then
        local newId = controller:CreateCategory(importedName)
        if not newId then return nil, "create failed" end
        local entry = db.global.customCategoriesV2[newId]
        if entry then
            entry.items            = deepCopy(category.items) or {}
            if category.enabled ~= nil then entry.enabled = category.enabled end
            if category.filterMode ~= nil then entry.filterMode = category.filterMode end
            if category.searchExpression ~= nil then entry.searchExpression = category.searchExpression end
            if category.itemType ~= nil then entry.itemType = category.itemType end
            if category.itemSubType ~= nil then entry.itemSubType = category.itemSubType end
            if category.typeMatchMode ~= nil then entry.typeMatchMode = category.typeMatchMode end
            -- A payload written before type rules became expressions carries
            -- localized names and no expression; compile it against this
            -- client's locale so the category actually matches something.
            if not entry.searchExpression then
                entry.searchExpression = ns.ItemTypeExpr:Build(
                    entry.itemType, entry.itemSubType, entry.typeMatchMode)
            end
            if category.isTSM then entry.isTSM = true end
            if category.isBaganator then entry.isBaganator = true end
            if category.sortOrder ~= nil then entry.sortOrder = category.sortOrder end
        end
        nameRemap[importedName] = importedName
        return newId
    end

    if category.resolution == "skip" then
        return nil
    end

    if category.resolution == "merge" then
        local snap = existingSnapshot(db)
        local target = snap.categoriesByName[normKey(importedName)]
        if target then
            mergeCategoryData(target.data, category)
            nameRemap[importedName] = target.data.name
            return target.id
        end
        return nil, "merge target not found"
    end

    if category.resolution == "rename" then
        local prefix = category.renamePrefix or ""
        local suffix = category.renameSuffix or ""
        if prefix == "" and suffix == "" then
            prefix = category.isBaganator and "Bag: " or (category.isTSM and "TSM: " or "Imp: ")
        end
        local newName = strtrim(prefix .. importedName .. suffix)
        if newName == importedName then
            newName = newName .. " (import)"
        end
        -- If still colliding, add numeric suffix
        local snap = existingSnapshot(db)
        local candidate = newName
        local tries = 2
        while snap.categoriesByName[normKey(candidate)] do
            candidate = newName .. " (" .. tries .. ")"
            tries = tries + 1
        end

        local newId = controller:CreateCategory(candidate)
        if not newId then return nil, "rename create failed" end
        local entry = db.global.customCategoriesV2[newId]
        if entry then
            entry.items = deepCopy(category.items) or {}
            if category.enabled ~= nil then entry.enabled = category.enabled end
            if category.filterMode ~= nil then entry.filterMode = category.filterMode end
            if category.searchExpression ~= nil then entry.searchExpression = category.searchExpression end
            if category.itemType ~= nil then entry.itemType = category.itemType end
            if category.itemSubType ~= nil then entry.itemSubType = category.itemSubType end
            if category.typeMatchMode ~= nil then entry.typeMatchMode = category.typeMatchMode end
            -- A payload written before type rules became expressions carries
            -- localized names and no expression; compile it against this
            -- client's locale so the category actually matches something.
            if not entry.searchExpression then
                entry.searchExpression = ns.ItemTypeExpr:Build(
                    entry.itemType, entry.itemSubType, entry.typeMatchMode)
            end
            if category.isTSM then entry.isTSM = true end
            if category.isBaganator then entry.isBaganator = true end
            if category.sortOrder ~= nil then entry.sortOrder = category.sortOrder end
        end
        nameRemap[importedName] = candidate
        return newId
    end
end

-- ------------------------------------------------------------------
-- Section membership wiring
-- ------------------------------------------------------------------

local function wireSectionMembership(plan, controller, planIdToDbId, nameRemap)
    local db = controller:GetDB()
    local g = db.global

    for planSid, section in pairs(plan.sections) do
        local dbSid = planIdToDbId[planSid]
        if dbSid and g.categorySections[dbSid] then
            -- Position matters: `categories` is an ordered array and the export
            -- carries it to say where each category sits. Appending happened to
            -- reproduce that when the section was built from scratch, but an
            -- import into a section that already exists — re-importing after
            -- deleting one category — dropped the restored one at the bottom
            -- instead of back where it came from.
            for index, rawName in ipairs(section.categories or {}) do
                local finalName = nameRemap[rawName] or rawName
                if finalName and finalName ~= "" then
                    controller:SetSectionMembership(dbSid, finalName, true, index)
                end
            end
        end
    end
end

-- ------------------------------------------------------------------
-- Modifications
-- ------------------------------------------------------------------

local function writeModifications(plan, db, nameRemap)
    local g = db.global
    g.categoryModifications = g.categoryModifications or {}

    for importedName, mod in pairs(plan.modifications or {}) do
        local effectiveName = nameRemap[importedName] or importedName
        if effectiveName and effectiveName ~= "" then
            g.categoryModifications[effectiveName] =
                mergeModifications(g.categoryModifications[effectiveName], mod)
        end
    end
end

-- ------------------------------------------------------------------
-- Display / category / section order
-- ------------------------------------------------------------------

local function buildSkippedNameSet(plan)
    local skipped = {}
    for _, cat in pairs(plan.categories or {}) do
        if cat.resolution == "skip" and cat.name then
            skipped[normKey(cat.name)] = true
        end
    end
    return skipped
end

local function categoryNameResolvable(finalName, g)
    local SD = ns.SectionDefaults
    if SD and SD.GetEffectiveBuiltinNames then
        for _, bn in ipairs(SD:GetEffectiveBuiltinNames(g)) do
            if bn == finalName then return true end
        end
    end
    for _, cat in pairs(g.customCategoriesV2 or {}) do
        if cat.name == finalName then return true end
    end
    return false
end

local function restoreSectionOrder(plan, db, planIdToDbId)
    local g = db.global
    if not plan.sectionOrder or #plan.sectionOrder == 0 then
        return false
    end

    local seen = {}
    local newOrder = {}
    for _, planSid in ipairs(plan.sectionOrder) do
        local dbSid = planIdToDbId[planSid] or planSid
        if g.categorySections[dbSid] and not seen[dbSid] then
            seen[dbSid] = true
            tinsert(newOrder, dbSid)
        end
    end
    for _, dbSid in ipairs(g.sectionOrder or {}) do
        if g.categorySections[dbSid] and not seen[dbSid] then
            seen[dbSid] = true
            tinsert(newOrder, dbSid)
        end
    end

    g.sectionOrder = newOrder
    return #newOrder > 0
end

local function restoreCategoryOrder(plan, db, nameRemap)
    local g = db.global
    if not plan.categoryOrder or #plan.categoryOrder == 0 then
        return false
    end

    local seen = {}
    local newOrder = {}
    for _, rawName in ipairs(plan.categoryOrder) do
        local finalName = nameRemap[rawName] or rawName
        local nk = normKey(finalName)
        if finalName ~= "" and not seen[nk] and categoryNameResolvable(finalName, g) then
            seen[nk] = true
            tinsert(newOrder, finalName)
        end
    end
    for _, existingName in ipairs(g.categoryOrder or {}) do
        local nk = normKey(existingName)
        if existingName ~= "" and not seen[nk] and categoryNameResolvable(existingName, g) then
            seen[nk] = true
            tinsert(newOrder, existingName)
        end
    end

    g.categoryOrder = newOrder
    return #newOrder > 0
end

--- Best-effort displayOrder restore; skips unresolvable entries instead of aborting.
---@return boolean restored
---@return number dropped
local function safeRestoreDisplayOrder(plan, db, planIdToDbId, nameRemap, skippedNames)
    local g = db.global
    if not plan.displayOrder or #plan.displayOrder == 0 then
        return false, 0
    end

    local newOrder = {}
    local dropped = 0
    local inSection = false

    for _, entry in ipairs(plan.displayOrder) do
        if type(entry) ~= "string" then
            dropped = dropped + 1
        elseif entry == "----" then
            -- obsolete separator; ignore
        elseif entry == "section_end" then
            if inSection then
                tinsert(newOrder, "section_end")
                inSection = false
            else
                dropped = dropped + 1
            end
        elseif entry:sub(1, 8) == "section:" then
            local planSid = entry:sub(9)
            local dbSid = planIdToDbId[planSid] or planSid
            if g.categorySections[dbSid] then
                tinsert(newOrder, "section:" .. dbSid)
                inSection = true
            else
                inSection = false
                dropped = dropped + 1
            end
        else
            local finalName = nameRemap[entry] or entry
            if skippedNames[normKey(entry)] or skippedNames[normKey(finalName)] then
                dropped = dropped + 1
            elseif categoryNameResolvable(finalName, g) then
                tinsert(newOrder, finalName)
            else
                dropped = dropped + 1
            end
        end
    end

    if #newOrder > 0 then
        g.displayOrder = newOrder
        return true, dropped
    end
    return false, dropped
end

--- Apply the catalog half of an import and record what it created.
---
--- The created list goes into the backup so an undo can reach it. Without that,
--- a rollback restores Bags' own tables and leaves the entries this import
--- minted behind as orphans — referenced by nothing, invisible in any list that
--- goes by category.
---@param plan table
---@param db table
---@return number applied
local function applyCatalogEntries(plan, db)
    local items = plan.catalogPlan
    if type(items) ~= "table" or #items == 0 then return 0 end

    local created = OneWoW.SearchCatalog:ApplyImportPlan(items)

    local backup = db.global.importBackup
    if backup then
        backup.createdCatalogEntries = created
    end

    return #created
end

local function applyOptionalCategoryToggles(plan, db)
    local g = db.global
    if plan.enableJunkCategory ~= nil then
        g.enableJunkCategory = plan.enableJunkCategory
    end
    if plan.enableUpgradeCategory ~= nil then
        g.enableUpgradeCategory = plan.enableUpgradeCategory
    end
end

-- ------------------------------------------------------------------
-- Unmapped default placeholders
-- ------------------------------------------------------------------

local function applyUnmappedDefaults(plan, controller, result)
    if not plan.unmappedDefaults or #plan.unmappedDefaults == 0 then return end

    local locales = ns.Locales or {}
    local loc = locales[GetLocale and GetLocale() or "enUS"] or locales["enUS"] or {}
    local catchAll = loc["IMPORT_BAGANATOR_CATCHALL_SECTION"]

    local kept = {}
    for _, def in ipairs(plan.unmappedDefaults) do
        if def.resolution == "keep" then tinsert(kept, def) end
    end
    if #kept == 0 then return end

    local sid = ensureBaganatorImportSection(controller, catchAll)
    if not sid then return end

    local db = controller:GetDB()
    for _, def in ipairs(kept) do
        local name = strtrim(def.displayName or def.sourceId or "")
        if name ~= "" then
            local snap = existingSnapshot(db)
            local candidate = name
            local tries = 2
            while snap.categoriesByName[normKey(candidate)] do
                candidate = name .. " (" .. tries .. ")"
                tries = tries + 1
            end
            local newId = controller:CreateCategory(candidate)
            if newId then
                local entry = db.global.customCategoriesV2[newId]
                if entry then
                    entry.isBaganator = true
                    entry.items = {}
                end
                controller:SetSectionMembership(sid, candidate, true)
                result.unmappedDefaultsKept = (result.unmappedDefaultsKept or 0) + 1
            end
        end
    end
end

-- ------------------------------------------------------------------
-- Public entry point
-- ------------------------------------------------------------------

--- Apply an import plan to the live category database.
--- Creates an undo snapshot before mutating data and returns import counts.
---@param plan table
---@param controller table CategoryController-like object.
---@param db table|nil Database handle; defaults from controller when omitted.
---@return table|nil result
---@return string|nil errorMessage
function Applier:Apply(plan, controller, db)
    db = db or (controller and controller:GetDB())
    if not plan or not controller or not db then
        return nil, "missing args"
    end

    Backup:Snapshot("pre_import", db)

    local planIdToDbId = {}
    local nameRemap    = {}
    local result = {
        sectionsNew = 0, sectionsMerged = 0,
        categoriesNew = 0, categoriesRenamed = 0,
        categoriesMerged = 0, categoriesSkipped = 0,
        unmappedDefaultsKept = 0,
        savedSearchesMerged = 0,
        displayOrderDropped = 0,
        displayOrderRestored = false,
        sectionOrderRestored = false,
        categoryOrderRestored = false,
    }

    -- 1. Sections (create new, resolve existing)
    for planSid, section in pairs(plan.sections) do
        section.originalId = section.originalId or planSid
        local dbSid = ensureSection(section, controller, planIdToDbId)
        if dbSid then
            if section.isNew then
                result.sectionsNew = result.sectionsNew + 1
            else
                result.sectionsMerged = result.sectionsMerged + 1
            end
        end
    end

    -- 2. Unmapped-defaults placeholders (creates the catch-all section first)
    applyUnmappedDefaults(plan, controller, result)

    -- 3. Categories (apply resolution per-row)
    for _, category in pairs(plan.categories) do
        local res = category.resolution
        local ok = applyCategory(category, controller, nameRemap)
        if category.isNew and ok then
            result.categoriesNew = result.categoriesNew + 1
        elseif res == "rename" and ok then
            result.categoriesRenamed = result.categoriesRenamed + 1
        elseif res == "merge" and ok then
            result.categoriesMerged = result.categoriesMerged + 1
        elseif res == "skip" then
            result.categoriesSkipped = result.categoriesSkipped + 1
        end
    end

    -- 4. Section membership
    wireSectionMembership(plan, controller, planIdToDbId, nameRemap)

    -- 5. Modifications (re-keyed via nameRemap)
    writeModifications(plan, db, nameRemap)

    -- 6. disabledCategories re-key
    if plan.disabledCategories then
        for importedName, v in pairs(plan.disabledCategories) do
            if v then
                local finalName = nameRemap[importedName] or importedName
                db.global.disabledCategories[finalName] = true
            end
        end
    end

    -- 7. Optional builtin toggles (before ordering restore / ONEWOW sync)
    applyOptionalCategoryToggles(plan, db)

    -- 8. Named expressions referenced by imported categories. v3 payloads carry
    -- a core-owned catalog blob; v2 carried saved searches only, and the planner
    -- lifts those into the same shape, so both land here.
    result.savedSearchesMerged = applyCatalogEntries(plan, db)

    -- 9. Section and category order (exported first, local extras appended)
    result.sectionOrderRestored = restoreSectionOrder(plan, db, planIdToDbId)
    result.categoryOrderRestored = restoreCategoryOrder(plan, db, nameRemap)

    -- 10. displayOrder best-effort restore (skip bad entries)
    local skippedNames = buildSkippedNameSet(plan)
    local restored, dropped = safeRestoreDisplayOrder(plan, db, planIdToDbId, nameRemap, skippedNames)
    result.displayOrderRestored = restored
    result.displayOrderDropped = dropped
    if not restored then
        db.global.displayOrder = {}
    end

    -- 11. Sync ONEWOW BAGS section and refresh
    local SD = ns.SectionDefaults
    if SD and SD.SyncOnewowSectionCategories then
        SD:SyncOnewowSectionCategories(db.global)
    end

    controller:RefreshUI()
    if ns.InvalidateCategorization then
        ns:InvalidateCategorization()
    end

    return result
end
