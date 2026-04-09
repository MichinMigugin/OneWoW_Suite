local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.TrackerData = {}
local TD = ns.TrackerData

local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local tinsert, tremove, wipe, sort = tinsert, tremove, wipe, sort
local format, strsplit, strtrim, strlower = format, strsplit, strtrim, strlower
local time, date = time, date

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

local CATEGORIES = {
    "General",
    "Leveling",
    "Campaign",
    "Professions",
    "Gearing",
    "Gold Making",
    "Collections",
    "PvP",
    "Dungeons",
    "Raids",
    "Reputation",
    "Achievements",
    "Events",
    "Dailies",
    "Weeklies",
    "Farming",
    "Mounts",
    "Pets",
    "Toys",
    "Transmog",
    "Exploration",
}

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
function TD:GetCategories() return CATEGORIES end
function TD:GetTrackTypes() return TRACK_TYPES end
function TD:IsValidListType(t) return LIST_TYPE_SET[t] or false end
function TD:IsValidTrackType(t) return TRACK_TYPE_SET[t] or false end

local function GenerateID(prefix)
    local t = time()
    local r = math.random(100000, 999999)
    return format("%s-%08X-%06X", prefix, t, r)
end

local function GenerateKey(prefix)
    local r = math.random(10000, 99999)
    return format("%s-%d-%d", prefix, time(), r)
end

local function GetDB()
    local addon = _G.OneWoW_Trackers
    if not addon or not addon.db then return nil end
    return addon.db
end

function TD:GetListsDB()
    local db = GetDB()
    if not db then return {} end
    return db.global.trackerLists or {}
end

function TD:GetProgressDB()
    local db = GetDB()
    if not db then return {} end
    return db.char.trackerProgress or {}
end

function TD:GetGlobalProgressDB()
    local db = GetDB()
    if not db then return {} end
    db.global.trackerGlobalProgress = db.global.trackerGlobalProgress or {}
    return db.global.trackerGlobalProgress
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

function TD:GetDashboardDB()
    local db = GetDB()
    if not db then return {} end
    return db.char.trackerDashboard or {}
end

function TD:CreateList(opts)
    opts = opts or {}
    local db = GetDB()
    if not db then return nil end

    db.global.trackerLists = db.global.trackerLists or {}

    local list = {
        id            = GenerateID("tl"),
        title         = opts.title or "Untitled List",
        description   = opts.description or "",
        author        = opts.author or (UnitName("player") or "Unknown"),
        version       = 1,
        listType      = LIST_TYPE_SET[opts.listType] and opts.listType or "todo",
        category      = opts.category or "General",
        resetInterval = tonumber(opts.resetInterval) or nil,
        sections      = {},
        created       = time(),
        modified      = time(),
        favorite      = false,
        pinned        = false,
        pinnedPosition = nil,
        pinnedWidth   = 300,
        pinnedHeight  = 400,
        pinnedLocked  = false,
        accountWide   = opts.accountWide or false,
    }

    db.global.trackerLists[list.id] = list
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

    for k, v in pairs(changes) do
        if k ~= "id" and k ~= "created" and k ~= "sections" then
            list[k] = v
        end
    end
    list.modified = time()
    return true
end

function TD:RemoveList(listID)
    local db = GetDB()
    if not db then return false end
    if not db.global.trackerLists then return false end

    db.global.trackerLists[listID] = nil

    if db.char.trackerProgress then
        db.char.trackerProgress[listID] = nil
    end
    if db.global.trackerGlobalProgress then
        db.global.trackerGlobalProgress[listID] = nil
    end
    return true
end

function TD:DuplicateList(listID)
    local original = self:GetList(listID)
    if not original then return nil end

    local db = GetDB()
    if not db then return nil end

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

function TD:GetEffectiveResetType(list, section, step)
    if step and step.resetOverride then return step.resetOverride end
    if section and section.resetOverride then return section.resetOverride end
    if list then return list.listType end
    return "todo"
end

function TD:CheckResets()
    local db = GetDB()
    if not db then return end

    local now = GetServerTime()

    local lastWeekly = db.char.trackerLastWeeklyReset or 0
    local lastDaily  = db.char.trackerLastDailyReset or 0

    local secondsUntilDaily = C_DateAndTime.GetSecondsUntilDailyReset()
    local lastDailyReset = now + secondsUntilDaily - 86400

    local needsDailyReset = false
    if lastDaily < lastDailyReset then
        needsDailyReset = true
        db.char.trackerLastDailyReset = now
    end

    local secondsUntilWeekly = C_DateAndTime.GetSecondsUntilWeeklyReset()
    local lastWeeklyReset = now + secondsUntilWeekly - 604800

    local needsWeeklyReset = false
    if lastWeekly < lastWeeklyReset then
        needsWeeklyReset = true
        db.char.trackerLastWeeklyReset = now
    end

    if not needsDailyReset and not needsWeeklyReset then return end

    local lists = self:GetListsDB()

    for listID, list in pairs(lists) do
        local progress = self:GetProgressDBForList(listID)
        if progress[listID] then
            for _, sec in ipairs(list.sections) do
                for _, step in ipairs(sec.steps or {}) do
                    local resetType = self:GetEffectiveResetType(list, sec, step)
                    local shouldReset = false

                    if resetType == "daily" and needsDailyReset then
                        shouldReset = true
                    elseif resetType == "weekly" and needsWeeklyReset then
                        shouldReset = true
                    end

                    if shouldReset then
                        local sp = self:GetStepProgress(listID, sec.key, step.key)
                        sp.current = 0
                        sp.completed = false
                        wipe(sp.objectives or {})
                    end
                end
            end

            if (list.listType == "daily" and needsDailyReset) or
               (list.listType == "weekly" and needsWeeklyReset) then
                progress[listID].completed = false
                progress[listID].currentStep = 1
                progress[listID].lastReset = now
            end
        end
    end

    if needsWeeklyReset then
        print("|cFFFFD100OneWoW Trackers:|r Tracker weekly progress has been reset.")
    end
    if needsDailyReset then
        print("|cFFFFD100OneWoW Trackers:|r Tracker daily progress has been reset.")
    end
end

function TD:CheckCustomTimerResets()
    local db = GetDB()
    if not db then return end
    local now = time()

    local lists = self:GetListsDB()

    for listID, list in pairs(lists) do
        local progress = self:GetProgressDBForList(listID)
        if list.listType == "repeating" and list.resetInterval and progress[listID] then
            local prog = progress[listID]
            local lastReset = prog.lastReset or 0
            if (now - lastReset) >= list.resetInterval then
                self:ResetProgress(listID)
            end
        end

        for _, sec in ipairs(list.sections) do
            for _, step in ipairs(sec.steps or {}) do
                if step.trackType == "custom_timer" and step.trackParams then
                    local interval = tonumber(step.trackParams.interval) or 0
                    if interval > 0 then
                        local sp = self:GetStepProgress(listID, sec.key, step.key)
                        local lastComplete = sp.lastComplete or 0
                        if sp.completed and (now - lastComplete) >= interval then
                            sp.current = 0
                            sp.completed = false
                        end
                    end
                end
            end
        end
    end
end

local SERIALIZE_KEYS = {
    id = "i", title = "t", description = "d", author = "a", version = "v",
    listType = "lt", category = "c", resetInterval = "ri", sections = "s",
    label = "l", resetOverride = "ro", steps = "st", key = "k",
    trackType = "tt", trackParams = "tp", max = "m", noMax = "nm",
    optional = "o", faction = "f", mapID = "mi", coordX = "cx",
    coordY = "cy", waypointRadius = "wr", requiresSteps = "rs",
    objectives = "ob", type = "ty", params = "p",
    pick = "pk", objectiveIndex = "oi",
    professionRequired = "pr", eventRequired = "er",
    campaignID = "ci", questIDs = "qi",
    userNote = "un",
    accountWide = "aw",
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
    exportData.pinnedWidth = nil
    exportData.pinnedHeight = nil
    exportData.pinnedLocked = nil
    exportData.favorite = nil

    return "OWT1:" .. SerializeValue(exportData)
end

function TD:ImportList(str)
    if not str or str == "" then return nil end

    str = strtrim(str)

    if str:sub(1, 5) == "OWT1:" then
        str = str:sub(6)
    end

    local raw = DeserializeValue(str)
    if not raw then return nil end

    local expanded = ExpandKeys(raw)
    if not expanded or not expanded.title then return nil end

    local db = GetDB()
    if not db then return nil end
    db.global.trackerLists = db.global.trackerLists or {}

    expanded.id = GenerateID("tl")
    expanded.created = time()
    expanded.modified = time()
    expanded.favorite = false
    expanded.pinned = false
    expanded.pinnedPosition = nil
    expanded.pinnedWidth = 300
    expanded.pinnedHeight = 400
    expanded.pinnedLocked = false

    for _, sec in ipairs(expanded.sections or {}) do
        sec.key = GenerateKey("sec")
        for _, step in ipairs(sec.steps or {}) do
            step.key = GenerateKey("stp")
            for _, obj in ipairs(step.objectives or {}) do
                obj.key = GenerateKey("obj")
            end
        end
    end

    db.global.trackerLists[expanded.id] = expanded
    return expanded
end

function TD:ParseMarkup(text, opts)
    if not text or text == "" then return nil end
    opts = opts or {}

    local list = {
        title = opts.title or "Imported Guide",
        description = "",
        listType = opts.listType or "guide",
        category = opts.category or "General",
        sections = {},
    }

    local currentSection = nil
    local currentStep = nil
    local descLines = {}

    for line in text:gmatch("[^\r\n]+") do
        line = strtrim(line)

        if line:sub(1, 2) == "# " and line:sub(1, 3) ~= "## " then
            list.title = strtrim(line:sub(3))

        elseif line:sub(1, 4) == "### " then
            if not currentSection then
                currentSection = {
                    key = GenerateKey("sec"),
                    label = "Steps",
                    steps = {},
                }
                tinsert(list.sections, currentSection)
            end

            if currentStep and #descLines > 0 then
                currentStep.description = table.concat(descLines, "\n")
                wipe(descLines)
            end

            currentStep = {
                key = GenerateKey("stp"),
                label = strtrim(line:sub(5)),
                description = "",
                trackType = "manual",
                trackParams = {},
                max = 1,
                objectives = {},
            }
            tinsert(currentSection.steps, currentStep)

        elseif line:sub(1, 3) == "## " then
            if currentStep and #descLines > 0 then
                currentStep.description = table.concat(descLines, "\n")
                wipe(descLines)
            end
            currentStep = nil

            local secLine = strtrim(line:sub(4))
            local secProfReq = nil
            local secEventReq = nil
            local profMatch = secLine:match("@prof:(%d+)")
            if profMatch then
                secProfReq = tonumber(profMatch)
                secLine = strtrim(secLine:gsub("@prof:%d+", ""))
            end
            local eventMatch = secLine:match("@event:(%d+)")
            if eventMatch then
                secEventReq = tonumber(eventMatch)
                secLine = strtrim(secLine:gsub("@event:%d+", ""))
            end

            currentSection = {
                key = GenerateKey("sec"),
                label = secLine,
                steps = {},
                professionRequired = secProfReq,
                eventRequired = secEventReq,
            }
            tinsert(list.sections, currentSection)

        elseif line:sub(1, 2) == "> " then
            local descText = strtrim(line:sub(3))
            if currentStep then
                tinsert(descLines, descText)
            else
                if list.description ~= "" then
                    list.description = list.description .. "\n"
                end
                list.description = list.description .. descText
            end

        elseif line:sub(1, 1) == "[" then
            local bracket, rest = line:match("^(%b[])%s*(.*)")
            if bracket and currentStep then
                local inner = bracket:sub(2, -2)
                local objType, paramStr = strsplit(":", inner, 2)
                objType = strtrim(objType)

                local obj = {
                    key = GenerateKey("obj"),
                    type = TRACK_TYPE_SET[objType] and objType or "manual",
                    description = rest or "",
                    params = {},
                }

                if paramStr then
                    local parts = { strsplit(":", paramStr) }
                    if objType == "quest" or objType == "quest_account" or objType == "quest_active" or objType == "rare_quest" then
                        obj.params.questID = tonumber(parts[1])
                    elseif objType == "quest_pool" or objType == "quest_pool_account" then
                        local ids = {}
                        if parts[1] then
                            for id in parts[1]:gmatch("(%d+)") do
                                tinsert(ids, tonumber(id))
                            end
                        end
                        obj.params.questIDs = ids
                        obj.params.pick = tonumber(parts[2]) or #ids
                    elseif objType == "quest_progress" then
                        obj.params.questID = tonumber(parts[1])
                        obj.params.objectiveIndex = tonumber(parts[2]) or 1
                    elseif objType == "campaign" then
                        obj.params.campaignID = tonumber(parts[1])
                    elseif objType == "quest_world" then
                        obj.params.questID = tonumber(parts[1])
                    elseif objType == "level" then
                        obj.params.level = tonumber(parts[1])
                    elseif objType == "item" then
                        obj.params.itemID = tonumber(parts[1])
                        obj.params.count = tonumber(parts[2]) or 1
                    elseif objType == "currency" then
                        obj.params.currencyID = tonumber(parts[1])
                        obj.params.amount = tonumber(parts[2]) or 1
                    elseif objType == "achievement" then
                        obj.params.achievementID = tonumber(parts[1])
                    elseif objType == "reputation" then
                        obj.params.factionID = tonumber(parts[1])
                        obj.params.standing = tonumber(parts[2]) or 6
                    elseif objType == "renown" then
                        obj.params.factionID = tonumber(parts[1])
                        obj.params.level = tonumber(parts[2]) or 1
                    elseif objType == "spell_known" then
                        obj.params.spellID = tonumber(parts[1])
                    elseif objType == "ilvl" then
                        obj.params.ilvl = tonumber(parts[1])
                    elseif objType == "location" then
                        obj.params.mapID = tonumber(parts[1])
                    elseif objType == "coordinates" then
                        obj.params.mapID = tonumber(parts[1])
                        obj.params.x = tonumber(parts[2])
                        obj.params.y = tonumber(parts[3])
                        obj.params.radius = tonumber(parts[4]) or 15
                    elseif objType == "npc_interact" then
                        obj.params.npcID = tonumber(parts[1])
                    elseif objType == "toy" then
                        obj.params.itemID = tonumber(parts[1])
                    elseif objType == "mount" then
                        obj.params.mountID = tonumber(parts[1])
                    elseif objType == "pet" then
                        obj.params.speciesID = tonumber(parts[1])
                    elseif objType == "transmog" then
                        obj.params.itemModifiedAppearanceID = tonumber(parts[1])
                    elseif objType == "exploration" then
                        obj.params.areaID = tonumber(parts[1])
                    elseif objType == "loot_item" then
                        obj.params.itemID = tonumber(parts[1])
                    elseif objType == "vault_raid" then
                        obj.params = {}
                    elseif objType == "vault_dungeon" then
                        obj.params = {}
                    elseif objType == "vault_world" then
                        obj.params = {}
                    elseif objType == "prof_skill" then
                        obj.params.baseSkillLineID = tonumber(parts[1])
                    elseif objType == "prof_concentration" then
                        obj.params.currencyID = tonumber(parts[1])
                    elseif objType == "prof_knowledge" then
                        obj.params.skillLineVariantID = tonumber(parts[1])
                    elseif objType == "custom_timer" then
                        obj.params.interval = tonumber(parts[1]) or 3600
                    end
                end

                tinsert(currentStep.objectives, obj)
            end

        elseif line ~= "" and currentStep then
            if line:sub(1, 2) == "- " then
                local obj = {
                    key = GenerateKey("obj"),
                    type = "manual",
                    description = strtrim(line:sub(3)),
                    params = {},
                }
                tinsert(currentStep.objectives, obj)
            else
                tinsert(descLines, line)
            end
        end
    end

    if currentStep and #descLines > 0 then
        currentStep.description = table.concat(descLines, "\n")
    end

    if #list.sections == 0 then
        return nil
    end

    return list
end

function TD:CreateListFromParsed(parsed)
    if not parsed then return nil end

    local db = GetDB()
    if not db then return nil end
    db.global.trackerLists = db.global.trackerLists or {}

    local list = self:CreateList({
        title = parsed.title,
        description = parsed.description,
        listType = parsed.listType or "guide",
        category = parsed.category or "General",
    })
    if not list then return nil end

    for _, parsedSec in ipairs(parsed.sections) do
        local sec = self:AddSection(list.id, {
            label = parsedSec.label,
            resetOverride = parsedSec.resetOverride,
            professionRequired = parsedSec.professionRequired,
            eventRequired = parsedSec.eventRequired,
        })
        if sec then
            for _, parsedStep in ipairs(parsedSec.steps or {}) do
                local step = self:AddStep(list.id, sec.key, {
                    label = parsedStep.label,
                    description = parsedStep.description,
                    trackType = parsedStep.trackType,
                    trackParams = parsedStep.trackParams,
                    max = parsedStep.max,
                    noMax = parsedStep.noMax,
                    optional = parsedStep.optional,
                    faction = parsedStep.faction,
                    mapID = parsedStep.mapID,
                    coordX = parsedStep.coordX,
                    coordY = parsedStep.coordY,
                    waypointRadius = parsedStep.waypointRadius,
                })
                if step then
                    for _, parsedObj in ipairs(parsedStep.objectives or {}) do
                        self:AddObjective(list.id, sec.key, step.key, {
                            type = parsedObj.type,
                            description = parsedObj.description,
                            params = parsedObj.params,
                        })
                    end
                end
            end
        end
    end

    return list
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

function TD:SetActiveList(listID)
    local db = GetDB()
    if not db then return end
    db.char.trackerActiveList = listID
end

function TD:GetActiveList()
    local db = GetDB()
    if not db then return nil end
    return db.char.trackerActiveList
end
