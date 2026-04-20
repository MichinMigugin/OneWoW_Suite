local _, OneWoW_Bags = ...

OneWoW_Bags.ImportExport = OneWoW_Bags.ImportExport or {}
OneWoW_Bags.ImportExport.Planner = OneWoW_Bags.ImportExport.Planner or {}
local Planner = OneWoW_Bags.ImportExport.Planner

local Serializer = OneWoW_Bags.ImportExport.Serializer
local Translators = OneWoW_Bags.ImportExport.SyntaxTranslators

local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local tinsert = table.insert
local strtrim = strtrim or function(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end
local string_lower = string.lower
local string_format = string.format

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

local function addWarning(plan, severity, text, ref)
    tinsert(plan.warnings, { severity = severity, text = text, ref = ref })
end

local function newPlan(source)
    return {
        source        = source,
        warnings      = {},
        sections      = {},
        sectionOrder  = {},
        categories    = {},
        categoryOrder = {},
        modifications = {},
        displayOrder  = {},
        disabledCategories = {},
        unmappedDefaults   = {},
        estimate      = {
            sectionsNew = 0, sectionsMerge = 0,
            categoriesNew = 0, categoriesRenamed = 0,
            categoriesMerged = 0, categoriesSkipped = 0,
            itemsTotal = 0,
        },
        options       = {},
    }
end

function Planner:BuildEmpty(source)
    return newPlan(source or "unknown")
end

local function countItems(tbl)
    if type(tbl) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
end

-- ------------------------------------------------------------------
-- Existing-state snapshot for conflict detection
-- ------------------------------------------------------------------

local function existingSnapshot(db)
    local g = db.global
    local snapshot = {
        sectionsByName = {},
        categoriesByName = {},
        builtinNames = {},
    }
    for sid, sec in pairs(g.categorySections or {}) do
        if sec and sec.name then
            snapshot.sectionsByName[normKey(sec.name)] = { id = sid, data = sec }
        end
    end
    for cid, cat in pairs(g.customCategoriesV2 or {}) do
        if cat and cat.name then
            snapshot.categoriesByName[normKey(cat.name)] = { id = cid, data = cat }
        end
    end

    local SD = OneWoW_Bags.SectionDefaults
    if SD and SD.GetEffectiveBuiltinNames then
        for _, nm in ipairs(SD:GetEffectiveBuiltinNames(g)) do
            snapshot.builtinNames[normKey(nm)] = nm
        end
    end
    snapshot.builtinNames[normKey("Empty")] = "Empty"
    return snapshot
end

-- ------------------------------------------------------------------
-- Conflict detection
-- ------------------------------------------------------------------

function Planner:DetectConflicts(plan, db)
    local snap = existingSnapshot(db)

    for _, section in pairs(plan.sections) do
        local key = normKey(section.name)
        local existing = snap.sectionsByName[key]
        if existing then
            section.mergesWithExistingId = existing.id
            section.isNew = false
            section.conflictReason = "name"
            plan.estimate.sectionsMerge = plan.estimate.sectionsMerge + 1
        else
            section.isNew = true
            plan.estimate.sectionsNew = plan.estimate.sectionsNew + 1
        end
    end

    for _, category in pairs(plan.categories) do
        local key = normKey(category.name)
        local existingCustom = snap.categoriesByName[key]
        local existingBuiltin = snap.builtinNames[key]
        if existingCustom or existingBuiltin then
            category.conflictWith = existingCustom and existingCustom.id or nil
            category.conflictWithBuiltinName = existingBuiltin
            category.conflictReason = "name"
            category.isNew = false
            category.resolution = category.resolution or "rename"
        else
            category.isNew = true
            category.resolution = category.resolution or "create"
        end
    end
end

local function recountEstimate(plan)
    local e = plan.estimate
    e.categoriesNew = 0
    e.categoriesRenamed = 0
    e.categoriesMerged = 0
    e.categoriesSkipped = 0
    e.itemsTotal = 0
    for _, cat in pairs(plan.categories) do
        e.itemsTotal = e.itemsTotal + countItems(cat.items)
        if cat.isNew then
            e.categoriesNew = e.categoriesNew + 1
        elseif cat.resolution == "skip" then
            e.categoriesSkipped = e.categoriesSkipped + 1
        elseif cat.resolution == "merge" then
            e.categoriesMerged = e.categoriesMerged + 1
        elseif cat.resolution == "rename" then
            e.categoriesRenamed = e.categoriesRenamed + 1
        end
    end
end

function Planner:RecomputeEstimate(plan)
    recountEstimate(plan)
end

-- ------------------------------------------------------------------
-- FromOneWowString
-- ------------------------------------------------------------------

function Planner:FromOneWowString(text, db)
    local plan = newPlan("onewow_string")

    local payload, err = Serializer:Decode(text)
    if not payload then
        addWarning(plan, "error", "Could not decode OneWoW export: " .. tostring(err))
        return plan
    end
    if type(payload) ~= "table" then
        addWarning(plan, "error", "Decoded value was not a table")
        return plan
    end
    if payload.format ~= Serializer.FORMAT then
        addWarning(plan, "error", "Not a OneWoW_Bags export (format=" .. tostring(payload.format) .. ")")
        return plan
    end
    if tonumber(payload.version) ~= Serializer.VERSION then
        addWarning(plan, "warn",
            string_format("Export version %s, expected %d. Attempting best-effort import.",
                tostring(payload.version), Serializer.VERSION))
    end

    if payload.exportedLocale and GetLocale and payload.exportedLocale ~= GetLocale() then
        addWarning(plan, "info",
            string_format("Exported from '%s' client into '%s' client.",
                payload.exportedLocale, GetLocale()))
    end

    for sid, sec in pairs(payload.sections or {}) do
        plan.sections[sid] = {
            name         = sec.name,
            collapsed    = sec.collapsed,
            showHeader   = sec.showHeader,
            showHeaderBank = sec.showHeaderBank,
            categories   = deepCopy(sec.categories or {}),
            originalId   = sid,
        }
    end
    plan.sectionOrder = deepCopy(payload.sectionOrder) or {}

    for cid, cat in pairs(payload.categories or {}) do
        plan.categories[cid] = {
            name               = cat.name,
            enabled            = cat.enabled,
            sortOrder          = cat.sortOrder,
            filterMode         = cat.filterMode,
            searchExpression   = cat.searchExpression,
            itemType           = cat.itemType,
            itemSubType        = cat.itemSubType,
            typeMatchMode      = cat.typeMatchMode,
            items              = deepCopy(cat.items) or {},
            isTSM              = cat.isTSM,
            isBaganator        = cat.isBaganator,
            originalId         = cid,
        }
    end

    plan.modifications      = deepCopy(payload.modifications or {})
    plan.disabledCategories = deepCopy(payload.disabledCategories or {})
    plan.categoryOrder      = deepCopy(payload.categoryOrder) or {}
    plan.displayOrder       = deepCopy(payload.displayOrder) or {}

    self:DetectConflicts(plan, db)
    recountEstimate(plan)
    return plan
end

-- ------------------------------------------------------------------
-- Baganator shared helper: intermediate shape -> Plan
-- ------------------------------------------------------------------

local function pushDefaultSections(plan, intermediate, db)
    local BaganatorImport = OneWoW_Bags.Integrations.Baganator
    local sections, _loose = BaganatorImport:ResolveOrderToSections(intermediate.category_display_order or {})
    local defaultMap = OneWoW_Bags.BaganatorDefaultMap or {}
    local hints      = intermediate.display_hints or {}
    local displayHints = OneWoW_Bags.BaganatorDefaultDisplayHints or {}
    local customs    = intermediate.custom_categories or {}
    local sectionsMeta = intermediate.category_sections or {}

    local unmappedSet = {}

    local function resolveName(sourceId)
        if customs[sourceId] then
            return customs[sourceId].name, "custom"
        end
        local mapped = defaultMap[sourceId]
        if mapped then
            return mapped, "default_mapped"
        end
        -- unmapped default or unknown source id
        if sourceId:sub(1, 8) == "default_" then
            return hints[sourceId] or displayHints[sourceId] or sourceId, "default_unmapped"
        end
        return nil, "unknown"
    end

    -- Produce sections and populate their `categories` arrays with the names
    -- that the applier should wire up. Unmapped defaults emit plan.unmappedDefaults
    -- entries (applier creates placeholders in "Baganator Import" section).
    for bagIndex, sourceIDs in pairs(sections) do
        local meta = sectionsMeta[bagIndex] or sectionsMeta[tonumber(bagIndex)] or {}
        if meta.name then
            local planSid = "bag_sec_" .. tostring(bagIndex)
            local section = {
                name         = meta.name,
                collapsed    = meta.collapsed,
                showHeader   = meta.showHeader ~= false,
                categories   = {},
                originalId   = planSid,
            }
            for _, sourceId in ipairs(sourceIDs) do
                local nm, kind = resolveName(sourceId)
                if kind == "custom" or kind == "default_mapped" then
                    if nm and nm ~= "" then
                        tinsert(section.categories, nm)
                    end
                elseif kind == "default_unmapped" then
                    if not unmappedSet[sourceId] then
                        unmappedSet[sourceId] = true
                        tinsert(plan.unmappedDefaults, {
                            sourceId    = sourceId,
                            displayName = nm or sourceId,
                            sectionHint = meta.name,
                            resolution  = "ignore",
                        })
                    end
                end
            end
            plan.sections[planSid] = section
            tinsert(plan.sectionOrder, planSid)
        end
    end

    return unmappedSet
end

local function buildCategoriesFromCustom(plan, intermediate, options, context)
    local customs    = intermediate.custom_categories or {}
    local defaultMap = OneWoW_Bags.BaganatorDefaultMap or {}
    local BaganatorImport = OneWoW_Bags.Integrations.Baganator

    for sourceId, data in pairs(customs) do
        local name = data.name
        if name and name ~= "" then
            local planCid = "bag_cat_" .. sourceId
            local category = {
                name                    = name,
                enabled                 = true,
                items                   = deepCopy(data.items) or {},
                isBaganator             = true,
                originalId              = planCid,
                filterMode              = (data.search and data.search ~= "") and "search" or "items",
                originalSyntaxDialect   = (data.search and data.search ~= "") and "syndicator" or nil,
                originalSearchExpression = data.search,
                ruleHandling            = "use_translated",
            }

            -- Translate any Syndicator search expression via the registry.
            if data.search and data.search ~= "" and Translators and Translators.Registry then
                local result = Translators.Registry:Translate("syndicator", data.search, context)
                category.searchExpression         = result.expression
                category.searchTranslationWarnings = result.warnings or {}
                category.translatable              = result.translatable
                if not result.translatable then
                    category.ruleHandling = "skip_rule"
                end
            end

            -- Per-name category modifications (hideIn inversion + priority).
            if data.hideIn or data.priority then
                plan.modifications[name] = plan.modifications[name] or {}
                if data.hideIn then
                    plan.modifications[name].appliesIn = BaganatorImport:InvertHideIn(data.hideIn)
                end
                if type(data.priority) == "number" then
                    -- Baganator uses higher numbers for higher priority; clamp to OneWoW's -2..3.
                    local p = data.priority
                    if p > 3 then p = 3 elseif p < -2 then p = -2 end
                    plan.modifications[name].priority = p
                end
            end

            plan.categories[planCid] = category
        end
    end

    -- Mapped defaults that carry modifications (hideIn) in the Baganator payload.
    local catMods = intermediate.category_modifications or {}
    for sourceId, mod in pairs(catMods) do
        local mappedName = defaultMap[sourceId]
        if mappedName and type(mod) == "table" then
            plan.modifications[mappedName] = plan.modifications[mappedName] or {}
            if mod.hideIn then
                plan.modifications[mappedName].appliesIn = BaganatorImport:InvertHideIn(mod.hideIn)
            end
            if type(mod.priority) == "number" then
                local p = mod.priority
                if p > 3 then p = 3 elseif p < -2 then p = -2 end
                plan.modifications[mappedName].priority = p
            end
        end
    end
end

local function planFromBaganatorIntermediate(intermediate, db, options)
    local plan = newPlan(intermediate.source or "baganator")
    plan.options = options or {}

    local context = {
        locale         = intermediate.exportedLocale or (GetLocale and GetLocale() or "enUS"),
        liveSyndicator = rawget(_G, "Syndicator") ~= nil,
    }

    pushDefaultSections(plan, intermediate, db)
    buildCategoriesFromCustom(plan, intermediate, options, context)

    Planner:DetectConflicts(plan, db)
    recountEstimate(plan)
    return plan
end

function Planner:FromBaganatorDirect(db, options)
    local BaganatorImport = OneWoW_Bags.Integrations.Baganator
    local intermediate, err = BaganatorImport:DirectRead()
    if not intermediate then
        local plan = newPlan("baganator_direct")
        addWarning(plan, "error", err or "Baganator direct-read failed")
        return plan
    end
    return planFromBaganatorIntermediate(intermediate, db, options)
end

function Planner:FromBaganatorString(text, db, options)
    local BaganatorImport = OneWoW_Bags.Integrations.Baganator
    local intermediate, err = BaganatorImport:ParseString(text)
    if not intermediate then
        local plan = newPlan("baganator_string")
        addWarning(plan, "error", err or "Baganator string parse failed")
        return plan
    end
    return planFromBaganatorIntermediate(intermediate, db, options)
end

-- ------------------------------------------------------------------
-- FromTsmDirect
-- ------------------------------------------------------------------

function Planner:FromTsmDirect(db, options)
    local plan = newPlan("tsm_direct")
    plan.options = options or { tsmPrefix = true }

    local TSM = OneWoW_Bags.TSMIntegration
    if not TSM or not TSM.IsAvailable or not TSM:IsAvailable() then
        addWarning(plan, "error", "TSM is not available")
        return plan
    end
    if not TSM.BuildPlan then
        addWarning(plan, "error", "TSM integration does not expose BuildPlan")
        return plan
    end

    TSM:BuildPlan(plan, db, plan.options)
    self:DetectConflicts(plan, db)
    recountEstimate(plan)
    return plan
end
