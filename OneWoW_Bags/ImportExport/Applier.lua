local _, OneWoW_Bags = ...

OneWoW_Bags.ImportExport = OneWoW_Bags.ImportExport or {}
OneWoW_Bags.ImportExport.Applier = OneWoW_Bags.ImportExport.Applier or {}
local Applier = OneWoW_Bags.ImportExport.Applier

local Backup = OneWoW_Bags.ImportExport.Backup

local pairs, ipairs, type, next = pairs, ipairs, type, next
local tinsert, tremove = table.insert, table.remove
local strtrim = strtrim or function(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end
local string_lower = string.lower

-- ------------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------------

local function normKey(name)
    if type(name) ~= "string" then return "" end
    return string_lower(strtrim(name))
end

local function deepCopy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local out = {}
    seen[v] = out
    for k, vv in pairs(v) do
        out[k] = deepCopy(vv, seen)
    end
    return out
end

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
--   modifications fields      -> imported wins when present
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

    for _, field in ipairs({ "sortMode", "groupBy", "priority", "color" }) do
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

local function ensureSection(g, section, controller, planIdToDbId)
    if section.mergesWithExistingId then
        planIdToDbId[section.originalId or section] = section.mergesWithExistingId
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
            return hit.id
        end
        return nil, err
    end

    -- Apply section-level flags that CreateSection doesn't set.
    local g2 = controller:GetDB().global
    local dbSec = g2.categorySections[newId]
    if dbSec then
        if section.collapsed ~= nil then dbSec.collapsed = section.collapsed end
        if section.showHeader ~= nil then dbSec.showHeader = section.showHeader end
        if section.showHeaderBank ~= nil then dbSec.showHeaderBank = section.showHeaderBank end
    end
    planIdToDbId[section.originalId or section] = newId
    return newId
end

-- ------------------------------------------------------------------
-- Unmapped-defaults -> Baganator Import section
-- ------------------------------------------------------------------

local function ensureBaganatorImportSection(controller, catchAllLabel)
    local db = controller:GetDB()
    local g = db.global
    local snap = existingSnapshot(db)
    local hit = snap.sectionsByName[normKey(catchAllLabel)]
    if hit then return hit.id end
    local newId = controller:CreateSection(catchAllLabel)
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
            if category.isTSM then entry.isTSM = true end
            if category.isBaganator then entry.isBaganator = true end
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
            if category.isTSM then entry.isTSM = true end
            if category.isBaganator then entry.isBaganator = true end
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
    local SD = OneWoW_Bags.SectionDefaults

    for planSid, section in pairs(plan.sections) do
        local dbSid = planIdToDbId[planSid]
        if dbSid and g.categorySections[dbSid] then
            for _, rawName in ipairs(section.categories or {}) do
                local finalName = nameRemap[rawName] or rawName
                if finalName and finalName ~= "" then
                    controller:SetSectionMembership(dbSid, finalName, true)
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

local function safeRestoreDisplayOrder(plan, db, planIdToDbId, nameRemap)
    local g = db.global
    if not plan.displayOrder or #plan.displayOrder == 0 then
        return false
    end

    local newOrder = {}
    for _, entry in ipairs(plan.displayOrder) do
        if type(entry) == "string" then
            if entry == "----" or entry == "section_end" then
                tinsert(newOrder, entry)
            elseif entry:sub(1, 8) == "section:" then
                local planSid = entry:sub(9)
                local dbSid = planIdToDbId[planSid] or planSid
                if g.categorySections[dbSid] then
                    tinsert(newOrder, "section:" .. dbSid)
                else
                    return false
                end
            else
                local finalName = nameRemap[entry] or entry
                local SD = OneWoW_Bags.SectionDefaults
                local builtin = false
                if SD and SD.GetEffectiveBuiltinNames then
                    for _, bn in ipairs(SD:GetEffectiveBuiltinNames(g)) do
                        if bn == finalName then builtin = true; break end
                    end
                end
                local customFound = false
                for _, cat in pairs(g.customCategoriesV2 or {}) do
                    if cat.name == finalName then customFound = true; break end
                end
                if builtin or customFound then
                    tinsert(newOrder, finalName)
                else
                    return false
                end
            end
        end
    end

    g.displayOrder = newOrder
    return true
end

-- ------------------------------------------------------------------
-- Unmapped default placeholders
-- ------------------------------------------------------------------

local function applyUnmappedDefaults(plan, controller, result)
    if not plan.unmappedDefaults or #plan.unmappedDefaults == 0 then return end

    local locales = OneWoW_Bags.Locales or {}
    local loc = locales[GetLocale and GetLocale() or "enUS"] or locales["enUS"] or {}
    local catchAll = loc["IMPORT_BAGANATOR_CATCHALL_SECTION"] or "Baganator Import"

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
    }

    -- 1. Sections (create new, resolve existing)
    for planSid, section in pairs(plan.sections) do
        section.originalId = section.originalId or planSid
        local dbSid, err = ensureSection(db.global, section, controller, planIdToDbId)
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
        db.global.disabledCategories = db.global.disabledCategories or {}
        for importedName, v in pairs(plan.disabledCategories) do
            if v then
                local finalName = nameRemap[importedName] or importedName
                db.global.disabledCategories[finalName] = true
            end
        end
    end

    -- 7. displayOrder best-effort restore
    local restored = safeRestoreDisplayOrder(plan, db, planIdToDbId, nameRemap)
    if not restored then
        db.global.displayOrder = {}
    end

    -- 8. Sync ONEWOW BAGS section and refresh
    local SD = OneWoW_Bags.SectionDefaults
    if SD and SD.SyncOnewowSectionCategories then
        SD:SyncOnewowSectionCategories(db.global)
    end

    controller:RefreshUI()
    if OneWoW_Bags.InvalidateCategorization then
        OneWoW_Bags:InvalidateCategorization()
    end

    return result
end
