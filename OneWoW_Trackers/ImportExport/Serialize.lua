local _, ns = ...

-- ============================================================================
-- Tracker import/export (OWT1)
-- ============================================================================
-- Compact keyed serialize/deserialize plus import self-heal. Methods stay on
-- ns.TrackerData. See OneWoW_Trackers/Docs/ARCHITECTURE.md.
-- ============================================================================

local TD = ns.TrackerData

local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local tinsert = tinsert
local format, strtrim = format, strtrim
local time = time

local SERIALIZE_KEYS = {
    id = "i", title = "t", description = "d", author = "a", version = "v",
    listType = "lt", category = "c", resetInterval = "ri", sections = "s",
    label = "l", resetOverride = "ro", steps = "st", key = "k",
    trackType = "tt", trackParams = "tp", max = "m", noMax = "nm",
    rosterMode = "rm",
    optional = "o", faction = "f", mapID = "mi", coordX = "cx",
    coordY = "cy", waypointRadius = "wr", requiresSteps = "rs",
    objectives = "ob", type = "ty", params = "p",
    pick = "pk", objectiveIndex = "oi",
    professionRequired = "pr", eventRequired = "er",
    campaignID = "ci", questIDs = "qi",
    userNote = "un",
    accountWide = "aw",
    pinnedAutoHideWhenComplete = "pah",
}

local DESERIALIZE_KEYS = {}
for k, v in pairs(SERIALIZE_KEYS) do DESERIALIZE_KEYS[v] = k end

local function SerializeValue(val)
    if type(val) == "string" then
        return format("%q", val)
    elseif type(val) == "number" then
        return tostring(val)
    elseif type(val) == "boolean" then
        return val and "true" or "false"
    elseif type(val) == "table" then
        local parts = {}
        local isArray = #val > 0
        if isArray then
            for _, v in ipairs(val) do
                tinsert(parts, SerializeValue(v))
            end
        else
            for k, v in pairs(val) do
                local sk = SERIALIZE_KEYS[k] or k
                tinsert(parts, format("[%q]=%s", sk, SerializeValue(v)))
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "nil"
end

local function DeserializeValue(str)
    if not str or str == "" then return nil end
    local func = loadstring("return " .. str)
    if not func then return nil end

    local env = {}
    setfenv(func, env)
    local ok, result = pcall(func)
    if not ok then return nil end
    return result
end

local function ExpandKeys(tbl)
    if type(tbl) ~= "table" then return tbl end
    local result = {}
    for k, v in pairs(tbl) do
        local expandedKey = DESERIALIZE_KEYS[k] or k
        result[expandedKey] = ExpandKeys(v)
    end
    return result
end

function TD:ExportList(listID)
    local list = self:GetList(listID)
    if not list then return nil end

    local exportData = CopyTable(list)
    exportData.pinned = nil
    exportData.pinnedPosition = nil
    exportData.pinnedWidth          = nil
    exportData.pinnedHeight         = nil
    exportData.pinnedExpandedWidth  = nil
    exportData.pinnedExpandedHeight = nil
    exportData.pinnedCollapsed      = nil
    exportData.pinnedOpacity        = nil
    exportData.pinnedLockMove       = nil
    exportData.pinnedLockResize     = nil
    exportData.pinnedHideCompleted  = nil
    exportData.pinnedLocked         = nil
    exportData.pinScope             = nil
    exportData.favorite = nil

    return "OWT1:" .. SerializeValue(exportData)
end

-- Validates that an expanded table matches the current OneWoW Trackers export
-- shape. Foreign schemas (e.g. exports from other addons using `ts` instead of
-- `st` for steps) deserialize fine but don't pass this gate.
--
-- Returns the table (same reference, with safe defaults applied) on success,
-- or nil if the structure is too far off to be repaired without guessing.
local function ValidateAndNormalizeImport(expanded)
    if type(expanded) ~= "table" then return nil end
    if type(expanded.title) ~= "string" or strtrim(expanded.title) == "" then return nil end
    if type(expanded.sections) ~= "table" then return nil end

    for _, sec in ipairs(expanded.sections) do
        if type(sec) ~= "table" then return nil end
        if type(sec.steps) ~= "table" then return nil end
        for _, step in ipairs(sec.steps) do
            if type(step) ~= "table" then return nil end
            if step.objectives ~= nil and type(step.objectives) ~= "table" then return nil end
        end
    end

    expanded.listType    = TD:IsValidListType(expanded.listType) and expanded.listType or "todo"
    expanded.category    = TD:NormalizeCategory(expanded.category)
    expanded.description = type(expanded.description) == "string" and expanded.description or ""
    expanded.author      = type(expanded.author) == "string" and expanded.author or "Unknown"
    expanded.version     = tonumber(expanded.version) or 1

    for _, sec in ipairs(expanded.sections) do
        sec.label     = type(sec.label) == "string" and sec.label or "Section"
        sec.steps     = sec.steps or {}
        sec.collapsed = false
        for _, step in ipairs(sec.steps) do
            step.label       = type(step.label) == "string" and step.label or "Step"
            step.description = type(step.description) == "string" and step.description or ""
            step.trackType   = TD:IsValidTrackType(step.trackType) and step.trackType or "manual"
            step.trackParams = type(step.trackParams) == "table" and step.trackParams or {}
            step.max         = tonumber(step.max) or 1
            step.noMax       = step.noMax == true
            step.rosterMode  = step.rosterMode == true
            step.optional    = step.optional == true
            step.objectives  = type(step.objectives) == "table" and step.objectives or {}
            for _, obj in ipairs(step.objectives) do
                if type(obj) == "table" then
                    obj.type        = TD:IsValidTrackType(obj.type) and obj.type or "manual"
                    obj.description = type(obj.description) == "string" and obj.description or ""
                    obj.params      = type(obj.params) == "table" and obj.params or {}
                end
            end
        end
    end

    expanded.pinnedAutoHideWhenComplete = expanded.pinnedAutoHideWhenComplete and true or false
    expanded.pinScope = nil

    return expanded
end

function TD:ImportList(str)
    if not str or str == "" then return nil end

    str = strtrim(str)

    if str:sub(1, 5) == "OWT1:" then
        str = str:sub(6)
    end

    local raw = DeserializeValue(str)
    if not raw then return nil end

    local expanded = ValidateAndNormalizeImport(ExpandKeys(raw))
    if not expanded then return nil end

    local db = ns.db

    expanded.id = TD.GenerateID("tl")
    expanded.created = time()
    expanded.modified = time()
    expanded.favorite = false
    expanded.pinned = false
    expanded.pinnedPosition = nil
    expanded.pinnedWidth          = 300
    expanded.pinnedHeight         = 400
    expanded.pinnedExpandedWidth  = 300
    expanded.pinnedExpandedHeight = 400
    expanded.pinnedCollapsed      = false
    expanded.pinnedOpacity        = 1.0
    expanded.pinnedLockMove       = false
    expanded.pinnedLockResize     = false
    expanded.pinnedHideCompleted  = false

    for _, sec in ipairs(expanded.sections) do
        sec.key = TD.GenerateKey("sec")
        for _, step in ipairs(sec.steps) do
            step.key = TD.GenerateKey("stp")
            for _, obj in ipairs(step.objectives) do
                obj.key = TD.GenerateKey("obj")
            end
        end
    end

    db.global.trackerLists[expanded.id] = expanded
    return expanded
end

-- Self-heal pass for lists that were imported under the previous lax validator.
-- Walks every list in the DB and applies the same safe-default normalization as
-- a fresh import, but in place — broken lists become viewable empty placeholders
-- the user can inspect and delete from the UI instead of crashing the sort /
-- render path.
--
-- Returns (normalizedCount, brokenCount) where `broken` are lists missing a
-- usable `sections[*].steps` structure (typically foreign-schema imports).
function TD:NormalizeAllLists()
    local lists = self:GetListsDB()
    local normalizedCount, brokenCount = 0, 0
    local brokenTitles = {}

    for listID, list in pairs(lists) do
        if type(list) ~= "table" then
            lists[listID] = nil
        else
            local wasBroken = false

            if list.id ~= listID then
                list.id = listID
            end

            if not TD:IsValidListType(list.listType) then
                list.listType = "todo"
                wasBroken = true
            end
            if type(list.title) ~= "string" or list.title == "" then
                list.title = ns.L["TRACKER_UNTITLED_LIST"]
                wasBroken = true
            end
            list.category = TD:NormalizeCategory(list.category)
            if type(list.description) ~= "string" then
                list.description = ""
            end
            if type(list.author) ~= "string" then
                list.author = "Unknown"
            end
            list.version = tonumber(list.version) or 1
            list.pinnedWidth  = tonumber(list.pinnedWidth)  or 300
            list.pinnedHeight = tonumber(list.pinnedHeight) or 400

            -- Pinned-window UI state introduced after the original pinned schema.
            -- Defaults are applied here so existing lists in the DB pick them up
            -- without needing a per-key bridge. Legacy `pinnedLocked` was a
            -- single combined lock; we split it into independent move/resize
            -- locks here for parity with the Notes pin.
            if list.pinnedLocked ~= nil then
                if list.pinnedLockMove   == nil then list.pinnedLockMove   = list.pinnedLocked and true or false end
                if list.pinnedLockResize == nil then list.pinnedLockResize = list.pinnedLocked and true or false end
                list.pinnedLocked = nil
            end
            list.pinnedExpandedWidth  = tonumber(list.pinnedExpandedWidth)  or list.pinnedWidth
            list.pinnedExpandedHeight = tonumber(list.pinnedExpandedHeight) or list.pinnedHeight
            list.pinnedCollapsed      = list.pinnedCollapsed and true or false
            list.pinnedOpacity        = tonumber(list.pinnedOpacity) or 1.0
            if list.pinnedOpacity < 0.1 then list.pinnedOpacity = 0.1
            elseif list.pinnedOpacity > 1.0 then list.pinnedOpacity = 1.0 end
            list.pinnedLockMove       = list.pinnedLockMove and true or false
            list.pinnedLockResize     = list.pinnedLockResize and true or false
            list.pinnedHideCompleted  = list.pinnedHideCompleted and true or false
            list.pinnedAutoHideWhenComplete = list.pinnedAutoHideWhenComplete and true or false
            list.pinScope             = TD:NormalizePinScope(list.pinScope)

            if type(list.sections) ~= "table" then
                list.sections = {}
                wasBroken = true
            end

            for _, sec in ipairs(list.sections) do
                if type(sec) == "table" then
                    if type(sec.label) ~= "string" then sec.label = "Section" end
                    if type(sec.key)   ~= "string" then sec.key   = TD.GenerateKey("sec") end
                    if type(sec.steps) ~= "table"  then
                        sec.steps = {}
                        wasBroken = true
                    end
                    for _, step in ipairs(sec.steps) do
                        if type(step) == "table" then
                            if type(step.label) ~= "string" then step.label = "Step" end
                            if type(step.key)   ~= "string" then step.key   = TD.GenerateKey("stp") end
                            if not TD:IsValidTrackType(step.trackType) then step.trackType = "manual" end
                            if type(step.trackParams) ~= "table" then step.trackParams = {} end
                            if type(step.objectives)  ~= "table" then step.objectives  = {} end
                            step.rosterMode = step.rosterMode == true
                            step.max = tonumber(step.max) or 1
                        end
                    end
                end
            end

            if wasBroken then
                normalizedCount = normalizedCount + 1
                if #list.sections == 0 or (#list.sections > 0 and #(list.sections[1].steps or {}) == 0) then
                    brokenCount = brokenCount + 1
                    tinsert(brokenTitles, list.title)
                end
            end
        end
    end

    return normalizedCount, brokenCount, brokenTitles
end
