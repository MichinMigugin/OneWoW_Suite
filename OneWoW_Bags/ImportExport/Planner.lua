local _, ns = ...

ns.ImportExport = ns.ImportExport or {}
ns.ImportExport.Planner = ns.ImportExport.Planner or {}
local Planner = ns.ImportExport.Planner

local Serializer = ns.ImportExport.Serializer
local Translators = ns.ImportExport.SyntaxTranslators
local Util = ns.ImportExport.Util
local L = ns.L

local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local tinsert = table.insert
local string_format = string.format

local normKey  = Util.NormKey
local deepCopy = Util.DeepCopy

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
        -- Core-owned catalog blob plus the per-entry plan PlanImport returns.
        catalogPayload = nil,
        catalogPlan = {},
        enableJunkCategory = nil,
        enableUpgradeCategory = nil,
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

--- Create an empty import plan shell for a source type.
---@param source string|nil
---@return table plan
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

    local SD = ns.SectionDefaults
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

--- Annotate plan sections/categories with conflict metadata against current DB.
---@param plan table
---@param db table
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

--- Recalculate category counts after callers change plan resolutions.
---@param plan table
function Planner:RecomputeEstimate(plan)
    recountEstimate(plan)
end

-- ------------------------------------------------------------------
-- FromOneWowString
-- ------------------------------------------------------------------

--- Build an import plan from a OneWoW_Bags export string.
---@param text string
---@param db table
---@return table plan
function Planner:FromOneWowString(text, db)
    local plan = newPlan("onewow_string")

    local payload, err = Serializer:Decode(text)
    if not payload then
        addWarning(plan, "error", string_format(L["IMPORT_WARN_DECODE_FAILED"], tostring(err)))
        return plan
    end
    if type(payload) ~= "table" then
        addWarning(plan, "error", L["IMPORT_WARN_NOT_TABLE"])
        return plan
    end
    if payload.format ~= Serializer.FORMAT then
        addWarning(plan, "error", string_format(L["IMPORT_WARN_NOT_OWB_EXPORT"], tostring(payload.format)))
        return plan
    end
    if tonumber(payload.version) ~= Serializer.VERSION then
        addWarning(plan, "warn",
            string_format(L["IMPORT_WARN_VERSION_MISMATCH"], tostring(payload.version), Serializer.VERSION))
    end

    if payload.exportedLocale and GetLocale and payload.exportedLocale ~= GetLocale() then
        addWarning(plan, "info",
            string_format(L["IMPORT_INFO_LOCALE_MISMATCH"], payload.exportedLocale, GetLocale()))
    end

    for sid, sec in pairs(payload.sections or {}) do
        plan.sections[sid] = {
            name           = sec.name,
            collapsed      = sec.collapsed,
            showHeader     = sec.showHeader,
            showHeaderBank = sec.showHeaderBank,
            categories     = deepCopy(sec.categories or {}),
            originalId     = sid,
            isBaganator    = sec.isBaganator,
            isTSM          = sec.isTSM,
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
    -- v3 carries a core-owned catalog blob covering every kind; v2 carried only
    -- saved searches keyed by name. Old payloads are lifted into the same shape
    -- so everything downstream sees one format.
    if type(payload.searchCatalog) == "table" then
        plan.catalogPayload = deepCopy(payload.searchCatalog)
    elseif type(payload.savedSearches) == "table" then
        local entries = {}
        for name, body in pairs(payload.savedSearches) do
            if type(name) == "string" and type(body) == "string" and body ~= "" then
                tinsert(entries, { kind = "saved", name = name, body = body })
            end
        end
        plan.catalogPayload = { version = 1, entries = entries }
    end

    plan.catalogPlan = OneWoW.SearchCatalog:PlanImport(plan.catalogPayload)

    for _, name in ipairs(payload.danglingCategories or {}) do
        addWarning(plan, "warn", string_format(L["IMPORT_WARN_DANGLING_CATEGORY"], tostring(name)))
    end
    if payload.enableJunkCategory ~= nil then
        plan.enableJunkCategory = payload.enableJunkCategory
    end
    if payload.enableUpgradeCategory ~= nil then
        plan.enableUpgradeCategory = payload.enableUpgradeCategory
    end

    self:DetectConflicts(plan, db)
    recountEstimate(plan)
    return plan
end

-- ------------------------------------------------------------------
-- Baganator shared helper: intermediate shape -> Plan
-- ------------------------------------------------------------------

local SECTION_END = "__end"

local function buildSourceIdResolver(intermediate)
    local defaultMap = ns.BaganatorDefaultMap or {}
    local hints = intermediate.display_hints or {}
    local displayHints = ns.BaganatorDefaultDisplayHints or {}
    local customs = intermediate.custom_categories or {}

    local function resolveName(sourceId)
        if customs[sourceId] then
            return customs[sourceId].name, "custom"
        end
        local mapped = defaultMap[sourceId]
        if mapped then
            return mapped, "default_mapped"
        end
        if type(sourceId) == "string" and sourceId:sub(1, 8) == "default_" then
            return hints[sourceId] or displayHints[sourceId] or sourceId, "default_unmapped"
        end
        return nil, "unknown"
    end

    return resolveName
end

local function pushDefaultSections(plan, intermediate, resolveName)
    local BaganatorImport = ns.Integrations.Baganator
    local order = intermediate.category_display_order or {}
    local sectionsByIndex = BaganatorImport:ResolveOrderToSections(order)
    local sectionsMeta = intermediate.category_sections or {}
    local unmappedSet = {}
    local sectionSeen = {}

    for _, entry in ipairs(order) do
        if entry:sub(1, 1) == "_" and entry ~= "----" and entry ~= SECTION_END then
            local bagIndex = entry:sub(2)
            if not sectionSeen[bagIndex] then
                sectionSeen[bagIndex] = true
                local meta = sectionsMeta[bagIndex] or sectionsMeta[tonumber(bagIndex)] or {}
                if meta.name then
                    local planSid = "bag_sec_" .. tostring(bagIndex)
                    local section = {
                        name         = meta.name,
                        collapsed    = meta.collapsed,
                        showHeader   = meta.showHeader ~= false,
                        categories   = {},
                        originalId   = planSid,
                        isBaganator  = true,
                    }
                    for _, sourceId in ipairs(sectionsByIndex[bagIndex] or {}) do
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
        end
    end

    return unmappedSet
end

local function clampPriority(p)
    if p > 3 then return 3 end
    if p < -2 then return -2 end
    return p
end

local function applyBaganatorModification(plan, displayName, mod, BaganatorImport, warnedOnce)
    if not displayName or type(mod) ~= "table" then return end

    plan.modifications[displayName] = plan.modifications[displayName] or {}
    local dest = plan.modifications[displayName]

    if mod.hideIn then
        dest.appliesIn = BaganatorImport:InvertHideIn(mod.hideIn)
    end
    if type(mod.priority) == "number" then
        dest.priority = clampPriority(mod.priority)
    end
    if type(mod.color) == "string" and #mod.color == 6 then
        dest.color = mod.color
    end
    if type(mod.group) == "string" then
        local mapped = BaganatorImport:MapGroupBy(mod.group)
        if mapped then
            dest.groupBy = mapped
        end
    end
    if mod.showGroupPrefix ~= nil and not warnedOnce.showGroupPrefix then
        warnedOnce.showGroupPrefix = true
        addWarning(plan, "info", L["IMPORT_WARN_BAGANATOR_SHOW_GROUP_PREFIX_SKIPPED"])
    end

    if type(mod.addedItems) == "table" then
        dest.addedItems = dest.addedItems or {}
        for key, val in pairs(mod.addedItems) do
            if val then
                if type(key) == "string" and key:sub(1, 2) == "p:" then
                    if not warnedOnce.petPin then
                        warnedOnce.petPin = true
                        addWarning(plan, "warn", L["IMPORT_WARN_BAGANATOR_PET_PIN_SKIPPED"])
                    end
                elseif type(key) == "string" and key:sub(1, 2) == "i:" then
                    local n = tonumber(key:sub(3))
                    if n then dest.addedItems[tostring(n)] = true end
                else
                    local n = tonumber(key)
                    if n then dest.addedItems[tostring(n)] = true end
                end
            end
        end
    end
end

local function buildCategoriesFromCustom(plan, intermediate, context, resolveName)
    local customs = intermediate.custom_categories or {}
    local BaganatorImport = ns.Integrations.Baganator
    local warnedOnce = {}

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

            if data.search and data.search ~= "" and Translators and Translators.Registry then
                local result = Translators.Registry:Translate("syndicator", data.search, context)
                category.searchExpression         = result.expression
                category.searchTranslationWarnings = result.warnings or {}
                category.translatable              = result.translatable
                if not result.translatable then
                    category.ruleHandling = "skip_rule"
                end
            end

            if data.hideIn or data.priority then
                applyBaganatorModification(plan, name, {
                    hideIn = data.hideIn,
                    priority = data.priority,
                }, BaganatorImport, warnedOnce)
            end

            plan.categories[planCid] = category
        end
    end

    local catMods = intermediate.category_modifications or {}
    for sourceId, mod in pairs(catMods) do
        local displayName = resolveName(sourceId)
        if displayName and type(mod) == "table" then
            applyBaganatorModification(plan, displayName, mod, BaganatorImport, warnedOnce)

            if customs[sourceId] and type(mod.addedItems) == "table" then
                local planCid = "bag_cat_" .. sourceId
                local category = plan.categories[planCid]
                if category then
                    for key, val in pairs(mod.addedItems) do
                        if val and type(key) == "string" and key:sub(1, 2) == "i:" then
                            local n = tonumber(key:sub(3))
                            if n then category.items[tostring(n)] = true end
                        end
                    end
                end
            end
        end
    end
end

local function mapHiddenCategories(plan, intermediate, resolveName)
    local hidden = intermediate.category_hidden or {}
    for sourceId in pairs(hidden) do
        local displayName, kind = resolveName(sourceId)
        if displayName and (kind == "custom" or kind == "default_mapped") then
            plan.disabledCategories[displayName] = true
        end
    end
end

local function buildDisplayOrderFromBaganator(plan, intermediate, resolveName)
    local BaganatorImport = ns.Integrations.Baganator
    local order = intermediate.category_display_order or {}
    local _, loose = BaganatorImport:ResolveOrderToSections(order)
    local looseSeen = {}
    local displayOrder = {}

    local function pushCategoryName(sourceId)
        local nm, kind = resolveName(sourceId)
        if kind == "custom" or kind == "default_mapped" then
            if nm and nm ~= "" then
                tinsert(displayOrder, nm)
            end
        end
    end

    for _, entry in ipairs(order) do
        if entry == SECTION_END then
            tinsert(displayOrder, "section_end")
        elseif entry == "----" then
            -- divider only
        elseif entry:sub(1, 1) == "_" then
            local bagIndex = entry:sub(2)
            tinsert(displayOrder, "section:bag_sec_" .. tostring(bagIndex))
        else
            pushCategoryName(entry)
            looseSeen[entry] = true
        end
    end

    for _, sourceId in ipairs(loose) do
        if not looseSeen[sourceId] then
            pushCategoryName(sourceId)
        end
    end

    if #displayOrder > 0 then
        plan.displayOrder = displayOrder
    end
end

local function buildCategoryOrderFromDisplay(plan, intermediate, resolveName)
    local customs = intermediate.custom_categories or {}
    local customNames = {}
    for sourceId in pairs(customs) do
        local nm = resolveName(sourceId)
        if nm then customNames[nm] = true end
    end

    local categoryOrder = {}
    for _, entry in ipairs(plan.displayOrder or {}) do
        if type(entry) == "string" and customNames[entry] then
            tinsert(categoryOrder, entry)
        end
    end
    if #categoryOrder > 0 then
        plan.categoryOrder = categoryOrder
    end
end

local function planFromBaganatorIntermediate(intermediate, db, options)
    local plan = newPlan(intermediate.source or "baganator")
    plan.options = options or {}

    for _, code in ipairs(intermediate.import_warnings or {}) do
        if code == "missing_addon" then
            addWarning(plan, "info", L["IMPORT_WARN_BAGANATOR_MISSING_ADDON"])
        end
    end

    local context = {
        locale         = intermediate.exportedLocale or (GetLocale and GetLocale() or "enUS"),
        liveSyndicator = rawget(_G, "Syndicator") ~= nil,
    }

    local resolveName = buildSourceIdResolver(intermediate)
    pushDefaultSections(plan, intermediate, resolveName)
    buildCategoriesFromCustom(plan, intermediate, context, resolveName)
    mapHiddenCategories(plan, intermediate, resolveName)
    buildDisplayOrderFromBaganator(plan, intermediate, resolveName)
    buildCategoryOrderFromDisplay(plan, intermediate, resolveName)

    Planner:DetectConflicts(plan, db)
    recountEstimate(plan)
    return plan
end

--- Build an import plan by reading Baganator data directly when available.
---@param db table
---@param options table|nil
---@return table plan
function Planner:FromBaganatorDirect(db, options)
    local BaganatorImport = ns.Integrations.Baganator
    local intermediate, err = BaganatorImport:DirectRead()
    if not intermediate then
        local plan = newPlan("baganator_direct")
        addWarning(plan, "error", err or L["IMPORT_WARN_BAGANATOR_DIRECT_FAILED"])
        return plan
    end
    return planFromBaganatorIntermediate(intermediate, db, options)
end

--- Build an import plan from a Baganator clipboard export string.
---@param text string
---@param db table
---@param options table|nil
---@return table plan
function Planner:FromBaganatorString(text, db, options)
    local BaganatorImport = ns.Integrations.Baganator
    local intermediate, err = BaganatorImport:ParseString(text)
    if not intermediate then
        local plan = newPlan("baganator_string")
        addWarning(plan, "error", err or L["IMPORT_WARN_BAGANATOR_STRING_FAILED"])
        return plan
    end
    return planFromBaganatorIntermediate(intermediate, db, options)
end

-- ------------------------------------------------------------------
-- FromTsmDirect
-- ------------------------------------------------------------------

--- Build an import plan from TradeSkillMaster group data.
---@param db table
---@param options table|nil
---@return table plan
function Planner:FromTsmDirect(db, options)
    local plan = newPlan("tsm_direct")
    plan.options = options or { tsmPrefix = true }

    local TSM = ns.TSMIntegration
    if not TSM or not TSM.IsAvailable or not TSM:IsAvailable() then
        addWarning(plan, "error", L["IMPORT_WARN_TSM_UNAVAILABLE"])
        return plan
    end
    if not TSM.BuildPlan then
        addWarning(plan, "error", L["IMPORT_WARN_TSM_NO_BUILDPLAN"])
        return plan
    end

    TSM:BuildPlan(plan, db, plan.options)
    self:DetectConflicts(plan, db)
    recountEstimate(plan)
    return plan
end
