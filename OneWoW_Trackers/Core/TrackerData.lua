local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

-- ============================================================================
-- TrackerData
-- ============================================================================
-- List/section/step/objective CRUD, progress, and roster. Daily/weekly timers
-- live in Core/Resets.lua; OWT1 + markup import in ImportExport/.
-- ============================================================================

ns.TrackerData = {}
local TD = ns.TrackerData

local pairs, ipairs, tonumber = pairs, ipairs, tonumber
local tinsert, tremove, wipe, sort = tinsert, tremove, wipe, sort
local format, strlower = format, strlower
local time = time

local LIST_TYPES = {
    "guide",
    "daily",
    "weekly",
    "todo",
    "repeating",
    "farmvalue",
}

local LIST_TYPE_SET = {}
for _, v in ipairs(LIST_TYPES) do LIST_TYPE_SET[v] = true end

-- Topic folders, not cadence. Daily/weekly/repeating live on listType.
-- Countable names are singular; General stays first, then A-Z.
local CATEGORIES = {
    "General",
    "Achievement",
    "Campaign",
    "Collection",
    "Dungeon",
    "Event",
    "Exploration",
    "Farming",
    "Gearing",
    "Gold Making",
    "Leveling",
    "Profession",
    "PvP",
    "Raid",
    "Reputation",
}

-- Saved/imported English strings from older category lists.
local CATEGORY_REMAP = {
    Dailies       = "General",
    Weeklies      = "General",
    Mounts        = "Collection",
    Pets          = "Collection",
    Toys          = "Collection",
    Transmog      = "Collection",
    Collections   = "Collection",
    Professions   = "Profession",
    Dungeons      = "Dungeon",
    Raids         = "Raid",
    Achievements  = "Achievement",
    Events        = "Event",
}

local DEFAULT_REPEAT_INTERVAL = 24 * 3600

local TRACK_TYPES = {
    "manual",
    "quest",
    "quest_account",
    "quest_pool",
    "quest_pool_account",
    "quest_progress",
    "quest_active",
    "quest_world",
    "level",
    "item",
    "currency",
    "achievement",
    "reputation",
    "renown",
    "spell_known",
    "ilvl",
    "location",
    "coordinates",
    "npc_interact",
    "enter_instance",
    "kill_creature",
    "kill_encounter",
    "loot_item",
    "toy",
    "mount",
    "pet",
    "transmog",
    "exploration",
    "vault_raid",
    "vault_dungeon",
    "vault_world",
    "prof_skill",
    "prof_concentration",
    "prof_knowledge",
    "prof_firstcraft",
    "prof_catchup",
    "rare_quest",
    "custom_timer",
    "campaign",
}

local TRACK_TYPE_SET = {}
for _, v in ipairs(TRACK_TYPES) do TRACK_TYPE_SET[v] = true end

function TD:GetListTypes() return LIST_TYPES end
function TD:GetTrackTypes() return TRACK_TYPES end
function TD:IsValidListType(t) return LIST_TYPE_SET[t] or false end
function TD:IsValidTrackType(t) return TRACK_TYPE_SET[t] or false end

--- Map a stored category string onto the current picker list.
--- Unknown custom strings are left as-is so they still display on the list.
---@param cat string|nil
---@return string
function TD:NormalizeCategory(cat)
    if type(cat) ~= "string" or cat == "" then
        return "General"
    end
    return CATEGORY_REMAP[cat] or cat
end

function TD:RemapStoredCategories()
    local lists = self:GetListsDB()
    for _, list in pairs(lists) do
        if type(list) == "table" then
            list.category = self:NormalizeCategory(list.category)
        end
    end
end

--- Localized label for a stored category. Stored values stay canonical English
--- so filtering, import, and remap keep comparing one vocabulary; only the
--- display text is translated. Unknown custom strings pass through unchanged.
---@param cat string|nil
---@return string
function TD:GetCategoryDisplayName(cat)
    local L = ns.L
    local names = {
        ["General"]     = GENERAL,
        ["Achievement"] = L["ACHIEVEMENT"],
        ["Campaign"]    = L["CAMPAIGN"],
        ["Collection"]  = L["COLLECTION"],
        ["Dungeon"]     = L["DUNGEON"],
        ["Event"]       = L["TRACKER_CAT_EVENT"],
        ["Exploration"] = L["TRACKER_TYPE_EXPLORATION"],
        ["Farming"]     = L["FARMING"],
        ["Gearing"]     = L["TRACKER_CAT_GEARING"],
        ["Gold Making"] = L["TRACKER_CAT_GOLD_MAKING"],
        ["Leveling"]    = L["TRACKER_CAT_LEVELING"],
        ["Profession"]  = L["PROFESSION"],
        -- CALENDAR_TYPE_PVP, not PVP: the koKR PVP global is "record" (the
        -- character-stats sense), not the content category.
        ["PvP"]         = CALENDAR_TYPE_PVP,
        ["Raid"]        = RAID,
        ["Reputation"]  = REPUTATION,
    }
    return names[cat] or cat or ""
end

--- Picker options for the category filter and the editor dropdowns.
--- `value` is the canonical English string that gets stored and filtered on;
--- `text` is localized. General leads, the rest sort by localized name so the
--- picker reads alphabetically in every language.
---@return table[]
function TD:GetCategoryOptions()
    local opts = {}
    for _, cat in ipairs(CATEGORIES) do
        if cat ~= "General" then
            tinsert(opts, { value = cat, text = self:GetCategoryDisplayName(cat) })
        end
    end
    sort(opts, function(a, b) return a.text < b.text end)
    tinsert(opts, 1, { value = "General", text = self:GetCategoryDisplayName("General") })
    return opts
end

--- Unique list id (`tl-...`).
---@param prefix string
---@return string
local function GenerateID(prefix)
    local t = time()
    local r = math.random(100000, 999999)
    return format("%s-%08X-%06X", prefix, t, r)
end

--- Unique section/step/objective key (`sec-...`).
---@param prefix string
---@return string
local function GenerateKey(prefix)
    local r = math.random(10000, 99999)
    return format("%s-%d-%d", prefix, time(), r)
end

TD.GenerateID = GenerateID
TD.GenerateKey = GenerateKey

local function GetDB()
    return ns.db
end

function TD:GetListsDB()
    return GetDB().global.trackerLists
end

function TD:GetProgressDB()
    return GetDB().char.trackerProgress
end

function TD:GetGlobalProgressDB()
    return GetDB().global.trackerGlobalProgress
end

-- ============================================================================
-- Per-character roster (rosterMode steps)
-- ============================================================================
-- A roster step reuses any existing trigger type. Instead of a single shared
-- checkbox, every character that satisfies the trigger this reset is recorded
-- under db.global.trackerRosters[listID][stepKey].completers, so the step shows
-- a class-colored "Name-Realm" list of who's done it. Recording is idempotent
-- and account-wide; the reset engine wipes completers on the step's effective
-- daily/weekly boundary (always against the account markers, since the roster
-- aggregates across the whole account).

--- Canonical "Name-Realm" key for the logged-in character, or nil pre-login.
---@return string|nil
function TD:GetCurrentCharKey()
    return OneWoW_GUI:GetCharacterKey()
end

--- Roster record for a step, optionally created on demand.
---@param listID string
---@param stepKey string
---@param create boolean|nil
---@return table|nil
function TD:GetRoster(listID, stepKey, create)
    local store = GetDB().global.trackerRosters
    local listRosters = store[listID]
    if not listRosters then
        if not create then return nil end
        listRosters = {}
        store[listID] = listRosters
    end
    local roster = listRosters[stepKey]
    if not roster then
        if not create then return nil end
        roster = { lastReset = time(), completers = {} }
        listRosters[stepKey] = roster
    end
    return roster
end

--- Records the current character as a completer of a roster step. Idempotent —
--- re-recording only refreshes the timestamp.
---@param listID string
---@param stepKey string
function TD:RecordRosterCompletion(listID, stepKey)
    local charKey = self:GetCurrentCharKey()
    if not charKey then return end
    local roster = self:GetRoster(listID, stepKey, true)
    roster.completers[charKey] = {
        name  = UnitName("player"),
        realm = GetRealmName(),
        class = select(2, UnitClass("player")),
        at    = time(),
    }
end

--- Removes a character from a roster step (manual override).
---@param listID string
---@param stepKey string
---@param charKey string
function TD:RemoveRosterCompleter(listID, stepKey, charKey)
    local roster = self:GetRoster(listID, stepKey, false)
    if roster then roster.completers[charKey] = nil end
end

--- True if a character is currently recorded on a roster step.
---@param listID string
---@param stepKey string
---@param charKey string|nil
---@return boolean
function TD:IsRosterCompleter(listID, stepKey, charKey)
    if not charKey then return false end
    local roster = self:GetRoster(listID, stepKey, false)
    return (roster and roster.completers[charKey]) and true or false
end

--- Sorted (by completion time) array of completer records for display.
---@param listID string
---@param stepKey string
---@return table[]
function TD:GetRosterCompleters(listID, stepKey)
    local out = {}
    local roster = self:GetRoster(listID, stepKey, false)
    if not roster then return out end
    for charKey, info in pairs(roster.completers) do
        tinsert(out, {
            charKey = charKey,
            name    = info.name or charKey,
            realm   = info.realm,
            class   = info.class,
            at      = info.at or 0,
        })
    end
    sort(out, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.charKey < b.charKey
    end)
    return out
end

function TD:IsListAccountWide(listID)
    local list = self:GetList(listID)
    return list and list.accountWide or false
end

function TD:GetProgressDBForList(listID)
    if self:IsListAccountWide(listID) then
        return self:GetGlobalProgressDB()
    end
    return self:GetProgressDB()
end

function TD:CreateList(opts)
    opts = opts or {}
    local db = GetDB()

    local listType = LIST_TYPE_SET[opts.listType] and opts.listType or "todo"
    local resetInterval = nil
    if listType == "repeating" then
        resetInterval = tonumber(opts.resetInterval)
        if not resetInterval or resetInterval <= 0 then
            resetInterval = DEFAULT_REPEAT_INTERVAL
        end
    end

    local list = {
        id            = GenerateID("tl"),
        title         = opts.title or ns.L["TRACKER_UNTITLED_LIST"],
        description   = opts.description or "",
        author        = opts.author or (UnitName("player") or "Unknown"),
        version       = 1,
        listType      = listType,
        category      = self:NormalizeCategory(opts.category),
        resetInterval = resetInterval,
        sections      = {},
        created       = time(),
        modified      = time(),
        favorite      = false,
        pinned        = false,
        pinnedPosition       = nil,
        pinnedWidth          = 300,
        pinnedHeight         = 400,
        pinnedExpandedWidth  = 300,
        pinnedExpandedHeight = 400,
        pinnedCollapsed      = false,
        pinnedOpacity        = 1.0,
        pinnedLockMove       = false,
        pinnedLockResize     = false,
        pinnedHideCompleted  = false,
        accountWide   = opts.accountWide or false,
    }

    db.global.trackerLists[list.id] = list

    if listType == "repeating" then
        local prog = self:GetProgress(list.id)
        prog.lastReset = time()
    end

    return list
end

function TD:GetList(listID)
    local lists = self:GetListsDB()
    return lists[listID]
end

function TD:GetAllLists()
    return self:GetListsDB()
end

function TD:UpdateList(listID, changes)
    local list = self:GetList(listID)
    if not list then return false end

    if changes.category ~= nil then
        changes.category = self:NormalizeCategory(changes.category)
    end

    for k, v in pairs(changes) do
        if k ~= "id" and k ~= "created" and k ~= "sections" then
            list[k] = v
        end
    end

    if list.listType == "repeating" then
        local ri = tonumber(list.resetInterval)
        if not ri or ri <= 0 then
            list.resetInterval = DEFAULT_REPEAT_INTERVAL
        end
        local prog = self:GetProgress(listID)
        if (prog.lastReset or 0) == 0 then
            prog.lastReset = time()
        end
    else
        list.resetInterval = nil
    end

    list.modified = time()
    return true
end

function TD:RemoveList(listID)
    local db = GetDB()
    db.global.trackerLists[listID] = nil
    db.char.trackerProgress[listID] = nil
    db.global.trackerGlobalProgress[listID] = nil
    db.global.trackerRosters[listID] = nil
    return true
end

function TD:DuplicateList(listID)
    local original = self:GetList(listID)
    if not original then return nil end

    local db = GetDB()
    local copy = CopyTable(original)
    copy.id = GenerateID("tl")
    copy.title = copy.title .. " (Copy)"
    copy.created = time()
    copy.modified = time()
    copy.favorite = false
    copy.pinned = false
    copy.pinnedPosition = nil

    for _, section in ipairs(copy.sections) do
        section.key = GenerateKey("sec")
        for _, step in ipairs(section.steps or {}) do
            step.key = GenerateKey("stp")
            for _, obj in ipairs(step.objectives or {}) do
                obj.key = GenerateKey("obj")
            end
        end
    end

    db.global.trackerLists[copy.id] = copy
    return copy
end

function TD:AddSection(listID, opts)
    local list = self:GetList(listID)
    if not list then return nil end

    opts = opts or {}
    local section = {
        key           = GenerateKey("sec"),
        label         = opts.label or "New Section",
        resetOverride = opts.resetOverride or nil,
        collapsed     = false,
        steps         = {},
        faction              = opts.faction or "both",
        professionRequired = tonumber(opts.professionRequired) or nil,
        eventRequired      = tonumber(opts.eventRequired) or nil,
    }

    tinsert(list.sections, section)
    list.modified = time()
    return section
end

function TD:GetSection(listID, sectionKey)
    local list = self:GetList(listID)
    if not list then return nil, nil end
    for i, sec in ipairs(list.sections) do
        if sec.key == sectionKey then return sec, i end
    end
    return nil, nil
end

function TD:UpdateSection(listID, sectionKey, changes)
    local sec = self:GetSection(listID, sectionKey)
    if not sec then return false end

    for k, v in pairs(changes) do
        if k ~= "key" and k ~= "steps" then
            sec[k] = v
        end
    end

    local list = self:GetList(listID)
    if list then list.modified = time() end
    return true
end

function TD:RemoveSection(listID, sectionKey)
    local list = self:GetList(listID)
    if not list then return false end

    for i, sec in ipairs(list.sections) do
        if sec.key == sectionKey then
            tremove(list.sections, i)
            list.modified = time()
            return true
        end
    end
    return false
end

function TD:MoveSection(listID, sectionKey, direction)
    local list = self:GetList(listID)
    if not list then return false end

    for i, sec in ipairs(list.sections) do
        if sec.key == sectionKey then
            local newIdx = (direction == "up") and (i - 1) or (i + 1)
            if newIdx < 1 or newIdx > #list.sections then return false end
            tremove(list.sections, i)
            tinsert(list.sections, newIdx, sec)
            list.modified = time()
            return true
        end
    end
    return false
end

function TD:AddStep(listID, sectionKey, opts)
    local sec = self:GetSection(listID, sectionKey)
    if not sec then return nil end

    opts = opts or {}
    sec.steps = sec.steps or {}

    local step = {
        key           = GenerateKey("stp"),
        label         = opts.label or "New Step",
        description   = opts.description or "",
        trackType     = TRACK_TYPE_SET[opts.trackType] and opts.trackType or "manual",
        trackParams   = opts.trackParams or {},
        max           = tonumber(opts.max) or 1,
        noMax         = opts.noMax or false,
        rosterMode    = opts.rosterMode or false,
        resetOverride = opts.resetOverride or nil,
        optional      = opts.optional or false,
        userNote      = opts.userNote or "",
        faction       = opts.faction or "both",
        mapID         = tonumber(opts.mapID) or nil,
        coordX        = tonumber(opts.coordX) or nil,
        coordY        = tonumber(opts.coordY) or nil,
        waypointRadius = tonumber(opts.waypointRadius) or 15,
        requiresSteps = opts.requiresSteps or {},
        objectives    = {},
        sortOrder     = opts.sortOrder or (#sec.steps + 1),
        professionRequired = tonumber(opts.professionRequired) or nil,
        eventRequired      = tonumber(opts.eventRequired) or nil,
    }

    tinsert(sec.steps, step)
    local list = self:GetList(listID)
    if list then list.modified = time() end
    return step
end

function TD:GetStep(listID, sectionKey, stepKey)
    local sec = self:GetSection(listID, sectionKey)
    if not sec or not sec.steps then return nil, nil end
    for i, step in ipairs(sec.steps) do
        if step.key == stepKey then return step, i end
    end
    return nil, nil
end

function TD:UpdateStep(listID, sectionKey, stepKey, changes)
    local step = self:GetStep(listID, sectionKey, stepKey)
    if not step then return false end

    for k, v in pairs(changes) do
        if k ~= "key" and k ~= "objectives" then
            step[k] = v
        end
    end

    local list = self:GetList(listID)
    if list then list.modified = time() end
    return true
end

function TD:RemoveStep(listID, sectionKey, stepKey)
    local sec = self:GetSection(listID, sectionKey)
    if not sec or not sec.steps then return false end

    for i, step in ipairs(sec.steps) do
        if step.key == stepKey then
            tremove(sec.steps, i)
            local listRosters = GetDB().global.trackerRosters[listID]
            if listRosters then listRosters[stepKey] = nil end
            local list = self:GetList(listID)
            if list then list.modified = time() end
            return true
        end
    end
    return false
end

function TD:MoveStep(listID, sectionKey, stepKey, direction)
    local sec = self:GetSection(listID, sectionKey)
    if not sec or not sec.steps then return false end

    for i, step in ipairs(sec.steps) do
        if step.key == stepKey then
            local newIdx = (direction == "up") and (i - 1) or (i + 1)
            if newIdx < 1 or newIdx > #sec.steps then return false end
            tremove(sec.steps, i)
            tinsert(sec.steps, newIdx, step)
            local list = self:GetList(listID)
            if list then list.modified = time() end
            return true
        end
    end
    return false
end

function TD:ReorderSection(listID, sectionKey, targetIndex)
    local list = self:GetList(listID)
    if not list then return false end
    for i, sec in ipairs(list.sections) do
        if sec.key == sectionKey then
            if i == targetIndex then return false end
            tremove(list.sections, i)
            tinsert(list.sections, targetIndex, sec)
            list.modified = time()
            return true
        end
    end
    return false
end

function TD:ReorderStep(listID, sectionKey, stepKey, targetIndex)
    local sec = self:GetSection(listID, sectionKey)
    if not sec or not sec.steps then return false end
    for i, step in ipairs(sec.steps) do
        if step.key == stepKey then
            if i == targetIndex then return false end
            tremove(sec.steps, i)
            tinsert(sec.steps, targetIndex, step)
            local list = self:GetList(listID)
            if list then list.modified = time() end
            return true
        end
    end
    return false
end

--- Move a step within or across sections, migrating progress with it.
--- destIndex is the insert slot in dest as it exists before the source is removed (1 .. n+1).
---@param listID string
---@param fromSectionKey string
---@param stepKey string
---@param destSectionKey string
---@param destIndex number
---@return boolean
function TD:MoveStepToSection(listID, fromSectionKey, stepKey, destSectionKey, destIndex)
    local step, fromIdx = self:GetStep(listID, fromSectionKey, stepKey)
    if not step or not fromIdx then return false end
    local destSec = self:GetSection(listID, destSectionKey)
    if not destSec then return false end
    destSec.steps = destSec.steps or {}

    destIndex = tonumber(destIndex) or 1
    if destIndex < 1 then destIndex = 1 end

    if fromSectionKey == destSectionKey then
        if destIndex > fromIdx then destIndex = destIndex - 1 end
        if destIndex > #destSec.steps then destIndex = #destSec.steps end
        if destIndex < 1 then destIndex = 1 end
        return self:ReorderStep(listID, fromSectionKey, stepKey, destIndex)
    end

    local destLen = #destSec.steps
    if destIndex > destLen + 1 then destIndex = destLen + 1 end

    local srcSec = self:GetSection(listID, fromSectionKey)
    tremove(srcSec.steps, fromIdx)
    tinsert(destSec.steps, destIndex, step)

    local prog = self:GetProgress(listID)
    prog.sections = prog.sections or {}
    local srcBucket = prog.sections[fromSectionKey]
    local blob = srcBucket and srcBucket.steps and srcBucket.steps[stepKey]
    if blob then
        srcBucket.steps[stepKey] = nil
        prog.sections[destSectionKey] = prog.sections[destSectionKey] or { steps = {} }
        prog.sections[destSectionKey].steps = prog.sections[destSectionKey].steps or {}
        prog.sections[destSectionKey].steps[stepKey] = blob
    end

    local list = self:GetList(listID)
    if list then list.modified = time() end
    return true
end

function TD:AddObjective(listID, sectionKey, stepKey, opts)
    local step = self:GetStep(listID, sectionKey, stepKey)
    if not step then return nil end

    step.objectives = step.objectives or {}
    opts = opts or {}

    local obj = {
        key         = GenerateKey("obj"),
        type        = TRACK_TYPE_SET[opts.type] and opts.type or "manual",
        description = opts.description or "",
        params      = opts.params or {},
    }

    tinsert(step.objectives, obj)
    local list = self:GetList(listID)
    if list then list.modified = time() end
    return obj
end

function TD:UpdateObjective(listID, sectionKey, stepKey, objKey, changes)
    local step = self:GetStep(listID, sectionKey, stepKey)
    if not step or not step.objectives then return false end

    for _, obj in ipairs(step.objectives) do
        if obj.key == objKey then
            for k, v in pairs(changes) do
                if k ~= "key" then
                    obj[k] = v
                end
            end
            local list = self:GetList(listID)
            if list then list.modified = time() end
            return true
        end
    end
    return false
end

function TD:RemoveObjective(listID, sectionKey, stepKey, objKey)
    local step = self:GetStep(listID, sectionKey, stepKey)
    if not step or not step.objectives then return false end

    for i, obj in ipairs(step.objectives) do
        if obj.key == objKey then
            tremove(step.objectives, i)
            local list = self:GetList(listID)
            if list then list.modified = time() end
            return true
        end
    end
    return false
end

function TD:GetProgress(listID)
    local progress = self:GetProgressDBForList(listID)
    if not progress[listID] then
        progress[listID] = {
            currentStep = 1,
            completed = false,
            lastReset = 0,
            sections = {},
        }
    end
    return progress[listID]
end

function TD:GetStepProgress(listID, sectionKey, stepKey)
    local prog = self:GetProgress(listID)
    prog.sections = prog.sections or {}
    prog.sections[sectionKey] = prog.sections[sectionKey] or { steps = {} }
    prog.sections[sectionKey].steps = prog.sections[sectionKey].steps or {}

    if not prog.sections[sectionKey].steps[stepKey] then
        prog.sections[sectionKey].steps[stepKey] = {
            current = 0,
            completed = false,
            objectives = {},
        }
    end
    return prog.sections[sectionKey].steps[stepKey]
end

function TD:SetStepProgress(listID, sectionKey, stepKey, current, max)
    local sp = self:GetStepProgress(listID, sectionKey, stepKey)
    sp.current = current or sp.current
    if max and current and current >= max then
        if not sp.completed then sp.lastCompleted = time() end
        sp.completed = true
    end
    return sp
end

function TD:BumpStepProgress(listID, sectionKey, stepKey, amount, max)
    local sp = self:GetStepProgress(listID, sectionKey, stepKey)
    amount = amount or 1
    sp.current = (sp.current or 0) + amount
    if max and sp.current >= max then
        if not sp.completed then sp.lastCompleted = time() end
        sp.completed = true
        sp.current = max
    end
    return sp
end

function TD:ToggleStepComplete(listID, sectionKey, stepKey)
    local sp = self:GetStepProgress(listID, sectionKey, stepKey)
    sp.completed = not sp.completed
    sp.current = sp.completed and 1 or 0
    if sp.completed then sp.lastCompleted = time() end
    return sp
end

function TD:GetObjectiveProgress(listID, sectionKey, stepKey, objKey)
    local sp = self:GetStepProgress(listID, sectionKey, stepKey)
    sp.objectives = sp.objectives or {}
    return sp.objectives[objKey] or false
end

function TD:SetObjectiveComplete(listID, sectionKey, stepKey, objKey, complete)
    local sp = self:GetStepProgress(listID, sectionKey, stepKey)
    sp.objectives = sp.objectives or {}
    sp.objectives[objKey] = complete and true or false
    return sp.objectives[objKey]
end

function TD:IsStepComplete(listID, sectionKey, stepKey)
    local step = self:GetStep(listID, sectionKey, stepKey)
    if step and step.rosterMode then
        return self:IsRosterCompleter(listID, stepKey, self:GetCurrentCharKey())
    end
    local sp = self:GetStepProgress(listID, sectionKey, stepKey)
    return sp.completed or false
end

function TD:GetListCompletion(listID)
    local list = self:GetList(listID)
    if not list then return 0, 0 end

    local total, done = 0, 0
    for _, sec in ipairs(list.sections) do
        for _, step in ipairs(sec.steps or {}) do
            if not step.optional then
                total = total + 1
                if self:IsStepComplete(listID, sec.key, step.key) then
                    done = done + 1
                end
            end
        end
    end
    return done, total
end

function TD:GetSectionCompletion(listID, sectionKey)
    local sec = self:GetSection(listID, sectionKey)
    if not sec then return 0, 0 end

    local total, done = 0, 0
    for _, step in ipairs(sec.steps or {}) do
        if not step.optional then
            total = total + 1
            if self:IsStepComplete(listID, sec.key, step.key) then
                done = done + 1
            end
        end
    end
    return done, total
end

function TD:ResetProgress(listID, sectionKey)
    local progressDB = self:GetProgressDBForList(listID)

    if sectionKey then
        local prog = progressDB[listID]
        if prog and prog.sections and prog.sections[sectionKey] then
            wipe(prog.sections[sectionKey])
            prog.sections[sectionKey] = { steps = {} }
        end
    else
        progressDB[listID] = {
            currentStep = 1,
            completed = false,
            lastReset = time(),
            sections = {},
        }
    end
end

function TD:GetSortedLists(filterType, filterCategory, searchText)
    local lists = self:GetListsDB()
    local result = {}

    for _, list in pairs(lists) do
        local pass = true

        if filterType and filterType ~= "all" and list.listType ~= filterType then
            pass = false
        end

        if filterCategory and filterCategory ~= "All" and list.category ~= filterCategory then
            pass = false
        end

        if searchText and searchText ~= "" then
            local lower = strlower(searchText)
            local titleMatch = strlower(list.title or ""):find(lower, 1, true)
            local authorMatch = strlower(list.author or ""):find(lower, 1, true)
            if not titleMatch and not authorMatch then
                pass = false
            end
        end

        if pass then
            tinsert(result, list)
        end
    end

    sort(result, function(a, b)
        if a.favorite ~= b.favorite then return a.favorite end
        if a.listType ~= b.listType then return a.listType < b.listType end
        return (a.title or "") < (b.title or "")
    end)

    return result
end

function TD:GetStepCount(listID)
    local list = self:GetList(listID)
    if not list then return 0 end
    local count = 0
    for _, sec in ipairs(list.sections) do
        count = count + #(sec.steps or {})
    end
    return count
end

function TD:FindStepByKey(listID, stepKey)
    local list = self:GetList(listID)
    if not list then return nil, nil end
    for _, sec in ipairs(list.sections) do
        for _, step in ipairs(sec.steps or {}) do
            if step.key == stepKey then
                return step, sec.key
            end
        end
    end
    return nil, nil
end

function TD:GetAllStepsFlat(listID)
    local list = self:GetList(listID)
    if not list then return {} end
    local result = {}
    for _, sec in ipairs(list.sections) do
        for _, step in ipairs(sec.steps or {}) do
            tinsert(result, { step = step, sectionKey = sec.key, sectionLabel = sec.label })
        end
    end
    return result
end

function TD:AreStepDependenciesMet(listID, step)
    if not step.requiresSteps or #step.requiresSteps == 0 then return true end
    for _, reqKey in ipairs(step.requiresSteps) do
        local reqStep, reqSecKey = self:FindStepByKey(listID, reqKey)
        if reqStep and reqSecKey then
            if not self:IsStepComplete(listID, reqSecKey, reqKey) then
                return false
            end
        end
    end
    return true
end

--- User-initiated check-off only. Engine session bumps do not consult this.
---@param listID string
---@param sectionKey string
---@param stepKey string
---@return boolean
function TD:CanCompleteStep(listID, sectionKey, stepKey)
    local step = self:GetStep(listID, sectionKey, stepKey)
    if not step then return false end
    return self:AreStepDependenciesMet(listID, step)
end

function TD:SetActiveList(listID)
    GetDB().char.trackerActiveList = listID
end

function TD:GetActiveList()
    return GetDB().char.trackerActiveList
end
