local _, ns = ...

ns.ImportExport = ns.ImportExport or {}
ns.ImportExport.ConfigCleanup = ns.ImportExport.ConfigCleanup or {}
local ConfigCleanup = ns.ImportExport.ConfigCleanup

local Backup = ns.ImportExport.Backup
local Util = ns.ImportExport.Util

local ipairs, pairs, type = ipairs, pairs, type
local tinsert, tremove = tinsert, tremove
local string_format = string.format

local normKey = Util.NormKey

local KIND_ORPHAN_MOD           = "orphan_modification"
local KIND_STALE_MEMBER         = "stale_section_member"
local KIND_STALE_SECTION_ORDER  = "stale_section_order"
local KIND_STALE_CATEGORY_ORDER = "stale_category_order"
local KIND_STALE_DISPLAY_ORDER  = "stale_display_order"

---@param g table
---@return table<string, boolean> validNames normKey -> true
local function buildValidNameSet(g)
    local valid = {}
    valid[normKey("Empty")] = true

    local SD = ns.SectionDefaults
    if SD and SD.GetEffectiveBuiltinNames then
        for _, name in ipairs(SD:GetEffectiveBuiltinNames(g)) do
            valid[normKey(name)] = true
        end
    end

    for _, cat in pairs(g.customCategoriesV2 or {}) do
        if cat and cat.name and cat.name ~= "" then
            valid[normKey(cat.name)] = true
        end
    end

    return valid
end

---@param validNames table<string, boolean>
---@param name string|nil
---@return boolean
local function isValidCategoryName(validNames, name)
    if type(name) ~= "string" or name == "" then return false end
    return validNames[normKey(name)] == true
end

local function isDisplayOrderCategoryEntry(entry)
    if type(entry) ~= "string" or entry == "" then return false end
    if entry == "section_end" then return false end
    if entry:sub(1, 8) == "section:" then return false end
    return true
end

local function newReport()
    return {
        items = {},
        counts = {
            orphan_modification = 0,
            stale_section_member = 0,
            stale_section_order = 0,
            stale_category_order = 0,
            stale_display_order = 0,
        },
        hasIssues = false,
    }
end

---@param report table
---@param kind string
---@param label string
---@param detail string|nil
---@param payload table
local function addFinding(report, kind, label, detail, payload)
    tinsert(report.items, {
        id = #report.items + 1,
        kind = kind,
        label = label,
        detail = detail or "",
        payload = payload,
        selected = true,
    })
    report.counts[kind] = (report.counts[kind] or 0) + 1
    report.hasIssues = true
end

--- Scan db.global for orphaned modifications and stale structural references.
---@param db table
---@return table report
function ConfigCleanup:Scan(db)
    local report = newReport()
    local g = db and db.global
    if not g then return report end

    local validNames = buildValidNameSet(g)

    for name in pairs(g.categoryModifications or {}) do
        if not isValidCategoryName(validNames, name) then
            addFinding(report, KIND_ORPHAN_MOD, name, nil, { categoryName = name })
        end
    end

    for sid, sec in pairs(g.categorySections or {}) do
        if sec and sec.categories then
            for idx, memberName in ipairs(sec.categories) do
                if not isValidCategoryName(validNames, memberName) then
                    local sectionLabel = sec.name or sid
                    addFinding(report, KIND_STALE_MEMBER, memberName,
                        string_format("%s (%s)", sectionLabel, sid),
                        { sectionId = sid, index = idx, categoryName = memberName })
                end
            end
        end
    end

    for idx, sid in ipairs(g.sectionOrder or {}) do
        if not g.categorySections[sid] then
            addFinding(report, KIND_STALE_SECTION_ORDER, sid, nil,
                { index = idx, sectionId = sid })
        end
    end

    for idx, name in ipairs(g.categoryOrder or {}) do
        if not isValidCategoryName(validNames, name) then
            addFinding(report, KIND_STALE_CATEGORY_ORDER, name, nil,
                { index = idx, categoryName = name })
        end
    end

    for idx, entry in ipairs(g.displayOrder or {}) do
        if isDisplayOrderCategoryEntry(entry) and not isValidCategoryName(validNames, entry) then
            addFinding(report, KIND_STALE_DISPLAY_ORDER, entry, nil,
                { index = idx, categoryName = entry })
        end
    end

    return report
end

--- Remove one stale section member by section id and category name.
---@param g table
---@param sectionId string
---@param categoryName string
---@return boolean removed
local function removeStaleSectionMember(g, sectionId, categoryName)
    local sec = g.categorySections and g.categorySections[sectionId]
    if not sec or not sec.categories then return false end
    for i = #sec.categories, 1, -1 do
        if sec.categories[i] == categoryName then
            tremove(sec.categories, i)
            return true
        end
    end
    return false
end

--- Remove first matching entry from an ordered list by value.
---@param list table|nil
---@param value string
---@return boolean removed
local function removeFirstFromList(list, value)
    if not list then return false end
    for i = #list, 1, -1 do
        if list[i] == value then
            tremove(list, i)
            return true
        end
    end
    return false
end

--- Apply selected cleanup findings from a scan report.
---@param report table
---@param db table
---@return table|nil result
---@return string|nil errorMessage
function ConfigCleanup:Apply(report, db)
    if not report or not db or not db.global then
        return nil, "missing args"
    end

    Backup:Snapshot("pre_cleanup", db)

    local g = db.global
    local removed = {
        orphan_modification = 0,
        stale_section_member = 0,
        stale_section_order = 0,
        stale_category_order = 0,
        stale_display_order = 0,
    }

    for _, item in ipairs(report.items or {}) do
        if item.selected then
            local payload = item.payload or {}
            if item.kind == KIND_ORPHAN_MOD and payload.categoryName then
                if g.categoryModifications and g.categoryModifications[payload.categoryName] then
                    g.categoryModifications[payload.categoryName] = nil
                    removed.orphan_modification = removed.orphan_modification + 1
                end
            elseif item.kind == KIND_STALE_MEMBER and payload.sectionId and payload.categoryName then
                if removeStaleSectionMember(g, payload.sectionId, payload.categoryName) then
                    removed.stale_section_member = removed.stale_section_member + 1
                end
            elseif item.kind == KIND_STALE_SECTION_ORDER and payload.sectionId then
                if removeFirstFromList(g.sectionOrder, payload.sectionId) then
                    removed.stale_section_order = removed.stale_section_order + 1
                end
            elseif item.kind == KIND_STALE_CATEGORY_ORDER and payload.categoryName then
                if removeFirstFromList(g.categoryOrder, payload.categoryName) then
                    removed.stale_category_order = removed.stale_category_order + 1
                end
            elseif item.kind == KIND_STALE_DISPLAY_ORDER and payload.categoryName then
                if removeFirstFromList(g.displayOrder, payload.categoryName) then
                    removed.stale_display_order = removed.stale_display_order + 1
                end
            end
        end
    end

    local SD = ns.SectionDefaults
    if SD and SD.SyncOnewowSectionCategories and g.categorySections[SD.SEC_ONEWOW_BAGS] then
        SD:SyncOnewowSectionCategories(g)
    end

    return { removed = removed }
end
