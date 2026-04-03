local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.TrackerMigration = {}
local TM = ns.TrackerMigration

local pairs, ipairs, tinsert, time, format = pairs, ipairs, tinsert, time, format

local function GenerateKey(prefix)
    local r = math.random(10000, 99999)
    return format("%s-%d-%d", prefix, time(), r)
end

local function GenerateID(prefix)
    local t = time()
    local r = math.random(100000, 999999)
    return format("%s-%08X-%06X", prefix, t, r)
end

local GUIDE_OBJ_TYPE_MAP = {
    manual         = "manual",
    level          = "level",
    quest_complete = "quest",
    quest_active   = "quest_active",
    item_count     = "item",
    location       = "location",
    achievement    = "achievement",
    reputation     = "reputation",
    spell_known    = "spell_known",
    ilvl           = "ilvl",
    currency       = "currency",
}

local function MapGuideObjParams(oldType, oldParams)
    oldParams = oldParams or {}
    local newParams = {}

    if oldType == "quest_complete" or oldType == "quest_active" then
        newParams.questID = oldParams.questID
    elseif oldType == "level" then
        newParams.level = oldParams.level
    elseif oldType == "item_count" then
        newParams.itemID = oldParams.itemID
        newParams.count = oldParams.count or 1
    elseif oldType == "location" then
        newParams.mapID = oldParams.mapID
    elseif oldType == "achievement" then
        newParams.achievementID = oldParams.achievementID
    elseif oldType == "reputation" then
        newParams.factionID = oldParams.factionID
        newParams.standing = oldParams.standing
    elseif oldType == "spell_known" then
        newParams.spellID = oldParams.spellID
    elseif oldType == "ilvl" then
        newParams.ilvl = oldParams.ilvl
    elseif oldType == "currency" then
        newParams.currencyID = oldParams.currencyID
        newParams.amount = oldParams.amount
    end

    return newParams
end

local ROUTINE_TRACK_MAP = {
    manual           = "manual",
    quest            = "quest",
    currency         = "currency",
    spell            = "spell_cast",
    item             = "item",
    prof_skill       = "prof_skill",
    prof_concentration = "prof_concentration",
    prof_knowledge   = "prof_knowledge",
    prof_firstcraft  = "prof_firstcraft",
    prof_catchup     = "prof_catchup",
    vault_raid       = "vault_raid",
    vault_dungeon    = "vault_dungeon",
    vault_world      = "vault_world",
    renown           = "renown",
    reputation       = "reputation",
    rare_quest       = "rare_quest",
}

local function MapRoutineTrackParams(oldType, oldParams)
    oldParams = oldParams or {}
    local newParams = {}

    if oldType == "quest" or oldType == "rare_quest" then
        if oldParams.questIds then
            newParams.questIDs = oldParams.questIds
        elseif oldParams.questId then
            newParams.questID = oldParams.questId
        end
    elseif oldType == "currency" or oldType == "prof_concentration" or oldType == "prof_catchup" then
        newParams.currencyID = oldParams.currencyId
    elseif oldType == "spell" then
        newParams.spellID = oldParams.spellId
        newParams.count = oldParams.spellAmount or 1
    elseif oldType == "item" then
        newParams.itemID = oldParams.itemId
    elseif oldType == "prof_skill" then
        newParams.baseSkillLineID = oldParams.baseSkillLineID
    elseif oldType == "prof_knowledge" then
        newParams.skillLineVariantID = oldParams.skillLineVariantID
    elseif oldType == "prof_firstcraft" then
        newParams.spellIDs = oldParams.spellIds
    elseif oldType == "renown" then
        newParams.factionID = oldParams.factionId
    elseif oldType == "reputation" then
        newParams.factionID = oldParams.factionId
        newParams.standing = oldParams.standing
    end

    return newParams
end

function TM:MigrateGuide(oldGuide)
    if not oldGuide then return nil end
    local TD = ns.TrackerData
    if not TD then return nil end

    local db = _G.OneWoW_Trackers and _G.OneWoW_Trackers.db
    if not db then return nil end
    db.global.trackerLists = db.global.trackerLists or {}

    local newList = {
        id            = GenerateID("tl"),
        title         = oldGuide.title or "Migrated Guide",
        description   = oldGuide.description or "",
        author        = oldGuide.author or "Unknown",
        version       = oldGuide.version or 1,
        listType      = "guide",
        category      = oldGuide.category or "General",
        resetInterval = nil,
        sections      = {},
        created       = oldGuide.created or time(),
        modified      = time(),
        favorite      = oldGuide.favorite or false,
        pinned        = false,
        pinnedPosition = nil,
        pinnedWidth   = 300,
        pinnedHeight  = 400,
        pinnedLocked  = false,
        accountWide   = false,
        _migratedFrom = "guide:" .. (oldGuide.id or "unknown"),
    }

    local section = {
        key   = GenerateKey("sec"),
        label = "Steps",
        steps = {},
    }

    for _, oldStep in ipairs(oldGuide.steps or {}) do
        local newStep = {
            key           = GenerateKey("stp"),
            label         = oldStep.title or "Step",
            description   = oldStep.description or "",
            trackType     = "manual",
            trackParams   = {},
            max           = 1,
            noMax         = false,
            optional      = oldStep.optional or false,
            faction       = oldStep.faction or "both",
            objectives    = {},
        }

        for _, oldObj in ipairs(oldStep.objectives or {}) do
            local newType = GUIDE_OBJ_TYPE_MAP[oldObj.type] or "manual"
            local newParams = MapGuideObjParams(oldObj.type, oldObj.params)

            tinsert(newStep.objectives, {
                key         = GenerateKey("obj"),
                type        = newType,
                description = oldObj.description or "",
                params      = newParams,
            })
        end

        tinsert(section.steps, newStep)
    end

    tinsert(newList.sections, section)
    db.global.trackerLists[newList.id] = newList

    local oldProgress = db.char.guideProgress and db.char.guideProgress[oldGuide.id]
    if oldProgress then
        local newProg = TD:GetProgress(newList.id)
        newProg.currentStep = oldProgress.currentStep or 1
        newProg.completed = oldProgress.completed or false

        if oldProgress.objectives then
            for stepIdx, stepObjs in pairs(oldProgress.objectives) do
                local stepInSection = section.steps[stepIdx]
                if stepInSection then
                    for objIdx, complete in pairs(stepObjs) do
                        local objInStep = stepInSection.objectives[objIdx]
                        if objInStep and complete then
                            TD:SetObjectiveComplete(newList.id, section.key, stepInSection.key, objInStep.key, true)
                        end
                    end
                end
            end
        end
    end

    return newList
end

function TM:MigrateRoutine(oldRoutine)
    if not oldRoutine then return nil end
    local TD = ns.TrackerData
    if not TD then return nil end

    local db = _G.OneWoW_Trackers and _G.OneWoW_Trackers.db
    if not db then return nil end
    db.global.trackerLists = db.global.trackerLists or {}

    local hasWeekly = false
    local hasDaily = false
    for _, sec in ipairs(oldRoutine.sections or {}) do
        if sec.resetType == "weekly" then hasWeekly = true end
        if sec.resetType == "daily" then hasDaily = true end
    end
    local listType = hasWeekly and "weekly" or (hasDaily and "daily" or "todo")

    local newList = {
        id            = GenerateID("tl"),
        title         = oldRoutine.title or "Migrated Routine",
        description   = "",
        author        = UnitName("player") or "Unknown",
        version       = 1,
        listType      = listType,
        category      = "General",
        resetInterval = nil,
        sections      = {},
        created       = oldRoutine.created or time(),
        modified      = time(),
        favorite      = false,
        pinned        = oldRoutine.pinned or false,
        pinnedPosition = oldRoutine.pinnedPosition,
        pinnedWidth   = oldRoutine.pinnedWidth or 300,
        pinnedHeight  = oldRoutine.pinnedHeight or 400,
        pinnedLocked  = oldRoutine.pinnedLocked or false,
        accountWide   = false,
        _migratedFrom = "routine:" .. (oldRoutine.id or "unknown"),
    }

    for _, oldSec in ipairs(oldRoutine.sections or {}) do
        local newSection = {
            key           = GenerateKey("sec"),
            label         = oldSec.label or "Section",
            resetOverride = nil,
            collapsed     = false,
            steps         = {},
        }

        if oldSec.resetType and oldSec.resetType ~= listType then
            newSection.resetOverride = oldSec.resetType
        end

        for _, oldTask in ipairs(oldSec.tasks or {}) do
            local newTrackType = ROUTINE_TRACK_MAP[oldTask.trackType] or "manual"
            local newTrackParams = MapRoutineTrackParams(oldTask.trackType, oldTask.trackParams)

            local newStep = {
                key           = GenerateKey("stp"),
                label         = oldTask.label or "Task",
                description   = "",
                trackType     = newTrackType,
                trackParams   = newTrackParams,
                max           = oldTask.max or 1,
                noMax         = oldTask.noMax or false,
                resetOverride = nil,
                optional      = false,
                faction       = "both",
                objectives    = {},
            }

            if oldTask.resetType and oldTask.resetType ~= oldSec.resetType then
                newStep.resetOverride = oldTask.resetType
            end

            tinsert(newSection.steps, newStep)
        end

        tinsert(newList.sections, newSection)
    end

    db.global.trackerLists[newList.id] = newList

    local oldProgress = db.char.routineProgress and db.char.routineProgress[oldRoutine.id]
    if oldProgress then
        for oldSecKey, oldSecProg in pairs(oldProgress) do
            for newSecIdx, newSec in ipairs(newList.sections) do
                local oldSec = oldRoutine.sections[newSecIdx]
                if oldSec and oldSec.key == oldSecKey then
                    for oldTaskKey, oldTaskProg in pairs(oldSecProg) do
                        if type(oldTaskProg) == "table" then
                            for newStepIdx, newStep in ipairs(newSec.steps) do
                                local oldTask = oldSec.tasks and oldSec.tasks[newStepIdx]
                                if oldTask and oldTask.key == oldTaskKey then
                                    local sp = TD:GetStepProgress(newList.id, newSec.key, newStep.key)
                                    sp.current = oldTaskProg.current or 0
                                    local max = newStep.noMax and 0 or (newStep.max or 1)
                                    if max > 0 and sp.current >= max then
                                        sp.completed = true
                                    end
                                    break
                                end
                            end
                        end
                    end
                    break
                end
            end
        end
    end

    return newList
end

function TM:MigrateAll()
    local db = _G.OneWoW_Trackers and _G.OneWoW_Trackers.db
    if not db then return 0, 0 end

    if db.global.guidesRoutinesCleanedUp then
        return 0, 0
    end

    local guideCount = 0
    local routineCount = 0

    local hasGuides = db.global.guides and next(db.global.guides)
    local hasRoutines = db.global.routines and next(db.global.routines)

    if hasGuides or hasRoutines then
        local existingLists = db.global.trackerLists or {}
        local alreadyMigrated = {}
        for _, list in pairs(existingLists) do
            if list._migratedFrom then
                alreadyMigrated[list._migratedFrom] = true
            end
        end

        if hasGuides then
            for guideID, guide in pairs(db.global.guides) do
                if guide.author ~= "OneWoW" then
                    local migKey = "guide:" .. (guide.id or guideID)
                    if not alreadyMigrated[migKey] then
                        local result = self:MigrateGuide(guide)
                        if result then
                            guideCount = guideCount + 1
                        end
                    end
                end
            end
        end

        if hasRoutines then
            for routineID, routine in pairs(db.global.routines) do
                if routine.title ~= "Getting Started with Routines" then
                    local migKey = "routine:" .. (routine.id or routineID)
                    if not alreadyMigrated[migKey] then
                        local result = self:MigrateRoutine(routine)
                        if result then
                            routineCount = routineCount + 1
                        end
                    end
                end
            end
        end

        if guideCount > 0 or routineCount > 0 then
            print(format("|cFFFFD100OneWoW Trackers:|r Migrated %d guides and %d routines to the Tracker system.", guideCount, routineCount))
        end
    end

    for listID, list in pairs(db.global.trackerLists or {}) do
        if list._migratedFrom then
            local mType = list._migratedFrom:match("^(%w+):")
            if mType == "guide" and list.author == "OneWoW" then
                db.global.trackerLists[listID] = nil
                if db.char.trackerProgress then
                    db.char.trackerProgress[listID] = nil
                end
            elseif mType == "routine" and list.title == "Getting Started with Routines" then
                db.global.trackerLists[listID] = nil
                if db.char.trackerProgress then
                    db.char.trackerProgress[listID] = nil
                end
            end
        end
    end

    db.global.guides = nil
    db.global.routines = nil
    db.global.guideTrackerPosition = nil
    db.global.bundledGuidesVersion = nil
    db.global.bundledGuidesLoaded = nil
    db.global.bundledRoutinesLoaded = nil
    db.global.trackerMigrationDone = nil
    db.char.guideProgress = nil
    db.char.routineProgress = nil
    db.char.routineLastWeek = nil

    db.global.guidesRoutinesCleanedUp = true

    return guideCount, routineCount
end
