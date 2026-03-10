local addonName, ns = ...

ns.RoutinesData = {}
local RoutinesData = ns.RoutinesData

function RoutinesData:GenerateUniqueID()
    return string.format("r-%08x-%04x-%04x",
        GetServerTime(),
        math.random(0, 65535),
        math.random(0, 65535))
end

function RoutinesData:GetRoutinesDB()
    local addon = _G.OneWoW_Notes
    return addon.db.global.routines
end

function RoutinesData:GetProgressDB()
    local addon = _G.OneWoW_Notes
    return addon.db.char.routineProgress
end

function RoutinesData:GetAllRoutines()
    return self:GetRoutinesDB() or {}
end

function RoutinesData:GetRoutine(routineID)
    local db = self:GetRoutinesDB()
    if db and db[routineID] then
        return db[routineID]
    end
    return nil
end

function RoutinesData:AddRoutine(routineData)
    local addon = _G.OneWoW_Notes
    local db = self:GetRoutinesDB()
    if not db then
        addon.db.global.routines = {}
        db = addon.db.global.routines
    end

    local routineID = routineData.id or self:GenerateUniqueID()
    routineData.id = routineID
    routineData.title = routineData.title or ""
    routineData.sections = routineData.sections or {}
    routineData.created = routineData.created or GetServerTime()
    routineData.modified = routineData.modified or GetServerTime()
    routineData.pinned = routineData.pinned or false
    routineData.pinnedPosition = routineData.pinnedPosition or nil
    routineData.pinnedWidth = routineData.pinnedWidth or 280
    routineData.pinnedHeight = routineData.pinnedHeight or 400
    routineData.pinnedLocked = routineData.pinnedLocked or false
    routineData.hideComplete = routineData.hideComplete or false

    db[routineID] = routineData
    return routineID
end

function RoutinesData:RemoveRoutine(routineID)
    local db = self:GetRoutinesDB()
    if not db or not db[routineID] then return false end

    if ns.RoutinesEngine then
        ns.RoutinesEngine:UnpinRoutine(routineID)
    end

    db[routineID] = nil

    local progressDB = self:GetProgressDB()
    if progressDB and progressDB[routineID] then
        progressDB[routineID] = nil
    end

    return true
end

function RoutinesData:UpdateRoutine(routineID, changes)
    local routine = self:GetRoutine(routineID)
    if not routine then return false end

    for k, v in pairs(changes) do
        routine[k] = v
    end
    routine.modified = GetServerTime()
    return true
end

function RoutinesData:GetProgress(routineID, sectionKey, taskKey)
    local progressDB = self:GetProgressDB()
    if not progressDB then
        local addon = _G.OneWoW_Notes
        addon.db.char.routineProgress = {}
        progressDB = addon.db.char.routineProgress
    end
    if not progressDB[routineID] then
        progressDB[routineID] = {}
    end
    if not progressDB[routineID][sectionKey] then
        progressDB[routineID][sectionKey] = {}
    end
    return progressDB[routineID][sectionKey][taskKey] or 0
end

function RoutinesData:SetProgress(routineID, sectionKey, taskKey, value, maxVal)
    local progressDB = self:GetProgressDB()
    if not progressDB then
        local addon = _G.OneWoW_Notes
        addon.db.char.routineProgress = {}
        progressDB = addon.db.char.routineProgress
    end
    if not progressDB[routineID] then
        progressDB[routineID] = {}
    end
    if not progressDB[routineID][sectionKey] then
        progressDB[routineID][sectionKey] = {}
    end
    progressDB[routineID][sectionKey][taskKey] = math.max(0, math.min(value, maxVal or value))
end

function RoutinesData:BumpProgress(routineID, sectionKey, taskKey, delta, maxVal)
    local cur = self:GetProgress(routineID, sectionKey, taskKey)
    self:SetProgress(routineID, sectionKey, taskKey, cur + delta, maxVal)
end

function RoutinesData:ResetRoutineProgress(routineID)
    local progressDB = self:GetProgressDB()
    if progressDB then
        progressDB[routineID] = nil
    end
end

function RoutinesData:ResetSectionProgress(routineID, sectionKey)
    local progressDB = self:GetProgressDB()
    if progressDB and progressDB[routineID] then
        progressDB[routineID][sectionKey] = nil
    end
end

function RoutinesData:AddSection(routineID, sectionData)
    local routine = self:GetRoutine(routineID)
    if not routine then return nil end

    sectionData = sectionData or {}
    sectionData.key = sectionData.key or ("s-" .. string.format("%04x", math.random(0, 65535)))
    sectionData.label = sectionData.label or ""
    sectionData.type = sectionData.type or "custom"
    sectionData.resetType = sectionData.resetType or "weekly"
    sectionData.tasks = sectionData.tasks or {}
    sectionData.collapsed = sectionData.collapsed or false

    table.insert(routine.sections, sectionData)
    routine.modified = GetServerTime()
    return sectionData.key
end

function RoutinesData:RemoveSection(routineID, sectionIndex)
    local routine = self:GetRoutine(routineID)
    if not routine or not routine.sections[sectionIndex] then return false end
    local section = routine.sections[sectionIndex]
    self:ResetSectionProgress(routineID, section.key)
    table.remove(routine.sections, sectionIndex)
    routine.modified = GetServerTime()
    return true
end

function RoutinesData:AddTask(routineID, sectionIndex, taskData)
    local routine = self:GetRoutine(routineID)
    if not routine or not routine.sections[sectionIndex] then return nil end

    taskData = taskData or {}
    taskData.key = taskData.key or ("t-" .. string.format("%04x", math.random(0, 65535)))
    taskData.label = taskData.label or ""
    taskData.max = taskData.max or 1
    taskData.trackType = taskData.trackType or "manual"
    taskData.trackParams = taskData.trackParams or {}

    table.insert(routine.sections[sectionIndex].tasks, taskData)
    routine.modified = GetServerTime()
    return taskData.key
end

function RoutinesData:RemoveTask(routineID, sectionIndex, taskIndex)
    local routine = self:GetRoutine(routineID)
    if not routine or not routine.sections[sectionIndex] then return false end
    local tasks = routine.sections[sectionIndex].tasks
    if not tasks or not tasks[taskIndex] then return false end
    table.remove(tasks, taskIndex)
    routine.modified = GetServerTime()
    return true
end

function RoutinesData:GetCurrentWeekKey()
    local secondsUntilReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
    if not secondsUntilReset or secondsUntilReset <= 0 then return nil end
    return math.floor((GetServerTime() + secondsUntilReset) / 604800)
end

function RoutinesData:CheckWeeklyReset()
    local addon = _G.OneWoW_Notes
    local currentWeek = self:GetCurrentWeekKey()
    if not currentWeek then return end
    if addon.db.char.routineLastWeek ~= currentWeek then
        addon.db.char.routineLastWeek = currentWeek
        self:DoWeeklyReset()
    end
end

function RoutinesData:DoWeeklyReset()
    local routines = self:GetAllRoutines()
    for routineID, routine in pairs(routines) do
        if type(routine) == "table" and routine.sections then
            for _, section in ipairs(routine.sections) do
                if section.resetType == "weekly" then
                    local hasPermanentTask = false
                    for _, task in ipairs(section.tasks or {}) do
                        if task.resetType == "never" then
                            hasPermanentTask = true
                            break
                        end
                    end
                    if hasPermanentTask then
                        local progressDB = self:GetProgressDB()
                        if progressDB and progressDB[routineID] and progressDB[routineID][section.key] then
                            for _, task in ipairs(section.tasks or {}) do
                                if task.resetType ~= "never" then
                                    progressDB[routineID][section.key][task.key] = nil
                                end
                            end
                        end
                    else
                        self:ResetSectionProgress(routineID, section.key)
                    end
                end
            end
        end
    end
end

local GREAT_VAULT_TEMPLATE = {
    label = "Great Vault",
    type = "great_vault",
    resetType = "weekly",
    tasks = {
        { key = "vault_r2", label = "Raid: 2 Bosses",    max = 2, trackType = "vault_raid",    trackParams = { threshold = 2 } },
        { key = "vault_r4", label = "Raid: 4 Bosses",    max = 4, trackType = "vault_raid",    trackParams = { threshold = 4 } },
        { key = "vault_r6", label = "Raid: 6 Bosses",    max = 6, trackType = "vault_raid",    trackParams = { threshold = 6 } },
        { key = "vault_d1", label = "Dungeon: 1 Run",    max = 1, trackType = "vault_dungeon", trackParams = { threshold = 1 } },
        { key = "vault_d4", label = "Dungeons: 4 Runs",  max = 4, trackType = "vault_dungeon", trackParams = { threshold = 4 } },
        { key = "vault_d8", label = "Dungeons: 8 Runs",  max = 8, trackType = "vault_dungeon", trackParams = { threshold = 8 } },
        { key = "vault_w2", label = "World: 2 Activities",max = 2, trackType = "vault_world",   trackParams = { threshold = 2 } },
        { key = "vault_w4", label = "World: 4 Activities",max = 4, trackType = "vault_world",   trackParams = { threshold = 4 } },
        { key = "vault_w8", label = "World: 8 Activities",max = 8, trackType = "vault_world",   trackParams = { threshold = 8 } },
    },
}

local function BuildPreyQuestIds(startId, endId, step)
    local ids = {}
    for qid = startId, endId, (step or 1) do
        ids[#ids + 1] = qid
    end
    return ids
end

local PREY_TEMPLATE = {
    label = "Prey System",
    type = "prey",
    resetType = "weekly",
    tasks = {
        { key = "prey_normal",    label = "Normal Hunts",      max = 4,     trackType = "quest", trackParams = { questIds = BuildPreyQuestIds(91095, 91124) } },
        { key = "prey_hard",      label = "Hard Hunts",        max = 4,     trackType = "quest", trackParams = { questIds = (function()
            local ids = {}
            for qid = 91210, 91242, 2 do ids[#ids+1] = qid end
            for qid = 91243, 91255 do ids[#ids+1] = qid end
            return ids
        end)() } },
        { key = "prey_nightmare", label = "Nightmare Hunts",   max = 4,     trackType = "quest", trackParams = { questIds = (function()
            local ids = {}
            for qid = 91211, 91241, 2 do ids[#ids+1] = qid end
            for qid = 91256, 91269 do ids[#ids+1] = qid end
            return ids
        end)() } },
        { key = "prey_remnants",  label = "Remnants of Anguish", max = 99999, trackType = "currency", trackParams = { currencyId = 3392 }, noMax = true },
    },
}

local WEEKLY_TASKS_TEMPLATE = {
    label = "Season Weeklies",
    type = "weekly_tasks",
    resetType = "weekly",
    tasks = {
        { key = "abundance",       label = "Abundance",            max = 1, trackType = "quest", trackParams = { questIds = { 89507 } } },
        { key = "lost_legends",    label = "Lost Legends",         max = 1, trackType = "quest", trackParams = { questIds = { 89268 } } },
        { key = "high_esteem",     label = "High Esteem",          max = 1, trackType = "quest", trackParams = { questIds = { 91629 } } },
        { key = "favor_of_court",  label = "Favor of the Court",   max = 1, trackType = "quest", trackParams = { questIds = { 89289 } } },
        { key = "soiree",          label = "Saltheril's Soiree",   max = 1, trackType = "quest", trackParams = { questIds = { 93889, 91966 } } },
        { key = "fortify",         label = "Fortify Runestones",   max = 1, trackType = "quest", trackParams = { questIds = { 90575, 90576, 90574, 90573 } } },
        { key = "stand_ground",    label = "Stand Your Ground",    max = 1, trackType = "quest", trackParams = { questIds = { 94581 } } },
        { key = "unity_void",      label = "Unity Against the Void", max = 1, trackType = "quest", trackParams = { questIds = { 93744, 93909, 93911, 93912, 93910 } } },
        { key = "special_assign",  label = "Special Assignment",   max = 1, trackType = "quest", trackParams = { questIds = { 91390, 91796, 92063, 92139, 92145, 93013, 93244, 93438 } } },
    },
}

local PROFESSION_TEMPLATES = {
    { key = "alchemy",        label = "Alchemy",        skillLine = 2906, tasks = {
        { key = "alch_skill",   label = "Skill",         max = 100, resetType = "never", trackType = "prof_skill",         trackParams = { skillLineVariantID = 2906, baseSkillLineID = 171 } },
        { key = "alch_conc",    label = "Concentration", max = 0,   resetType = "never", trackType = "prof_concentration", trackParams = { currencyId = 3161 } },
        { key = "alch_know",    label = "Knowledge",     max = 0,   resetType = "never", trackType = "prof_knowledge",     trackParams = { skillLineVariantID = 2906 } },
        { key = "alch_uniq",    label = "Uniques",       max = 9,   resetType = "never", trackType = "quest", trackParams = { questIds = { 89115,89117,89114,89116,89113,89112,89111,89118,93794 } } },
        { key = "alch_fc",      label = "First Crafts",  max = 34,  resetType = "never", trackType = "prof_firstcraft", trackParams = { spellIds = { 1230856,1230887,1230888,1230889,1230890,1230855,1230891,1230892,1230893,1230854,1230859,1230864,1230867,1230860,1230862,1230866,1230886,1230868,1230858,1230863,1230865,1230869,1230872,1230870,1230873,1230875,1230876,1230877,1230878,1230861,1230885,1230883,1230857,1230874 } } },
        { key = "alch_treatise",label = "Treatise",      max = 1,   trackType = "quest", trackParams = { questIds = { 95127 } } },
        { key = "alch_weekly",  label = "Weekly Quest",  max = 1,   trackType = "quest", trackParams = { questIds = { 93690 } } },
        { key = "alch_treasure",label = "Treasures",     max = 2,   resetType = "never", trackType = "quest", trackParams = { questIds = { 93528,93529 } } },
        { key = "alch_dmf",     label = "Darkmoon Faire",max = 1,   trackType = "quest", trackParams = { questIds = { 29506 } } },
        { key = "alch_catchup", label = "Catch-up",      max = 0,   resetType = "never", trackType = "prof_catchup",       trackParams = { currencyId = 3189 } },
    }},
    { key = "blacksmithing",  label = "Blacksmithing",  skillLine = 2907, tasks = {
        { key = "bs_skill",     label = "Skill",         max = 100, resetType = "never", trackType = "prof_skill",         trackParams = { skillLineVariantID = 2907, baseSkillLineID = 164 } },
        { key = "bs_conc",      label = "Concentration", max = 0,   resetType = "never", trackType = "prof_concentration", trackParams = { currencyId = 3162 } },
        { key = "bs_know",      label = "Knowledge",     max = 0,   resetType = "never", trackType = "prof_knowledge",     trackParams = { skillLineVariantID = 2907 } },
        { key = "bs_uniq",      label = "Uniques",       max = 9,   resetType = "never", trackType = "quest", trackParams = { questIds = { 89177,89178,89179,89180,89181,89182,89183,89184,93795 } } },
        { key = "bs_fc",        label = "First Crafts",  max = 90,  resetType = "never", trackType = "prof_firstcraft", trackParams = { spellIds = { 1230769,1262899,1262905,1262919,1264644,1264645,1264646,1264651,1229598,1229599,1229600,1229601,1229602,1229603,1229604,1229605,1229606,1229607,1229608,1229609,1229610,1229611,1229612,1229613,1229646,1229647,1229648,1229649,1229650,1229651,1229652,1229653,1229654,1229655,1229656,1229657,1229658,1229659,1230768,1229614,1229615,1229616,1229617,1229618,1229619,1229620,1229660,1229661,1229662,1229663,1229664,1229665,1229666,1229667,1229668,1230766,1230767,1229621,1229622,1229623,1229624,1229625,1229626,1229627,1229628,1229629,1229630,1229631,1229632,1229633,1229634,1229635,1229636,1229637,1229638,1229639,1229640,1229641,1229642,1229643,1229644,1229645,1230758,1230759,1230760,1230761,1230762,1230763,1230764,1265906 } } },
        { key = "bs_treatise",  label = "Treatise",      max = 1,   trackType = "quest", trackParams = { questIds = { 95128 } } },
        { key = "bs_weekly",    label = "Weekly Quest",  max = 1,   trackType = "quest", trackParams = { questIds = { 93691 } } },
        { key = "bs_treasure",  label = "Treasures",     max = 2,   resetType = "never", trackType = "quest", trackParams = { questIds = { 93530,93531 } } },
        { key = "bs_dmf",       label = "Darkmoon Faire",max = 1,   trackType = "quest", trackParams = { questIds = { 29508 } } },
        { key = "bs_catchup",   label = "Catch-up",      max = 0,   resetType = "never", trackType = "prof_catchup",       trackParams = { currencyId = 3199 } },
    }},
    { key = "enchanting",     label = "Enchanting",     skillLine = 2909, tasks = {
        { key = "ench_skill",   label = "Skill",         max = 100, resetType = "never", trackType = "prof_skill",         trackParams = { skillLineVariantID = 2909, baseSkillLineID = 333 } },
        { key = "ench_conc",    label = "Concentration", max = 0,   resetType = "never", trackType = "prof_concentration", trackParams = { currencyId = 3163 } },
        { key = "ench_know",    label = "Knowledge",     max = 0,   resetType = "never", trackType = "prof_knowledge",     trackParams = { skillLineVariantID = 2909 } },
        { key = "ench_uniq",    label = "Uniques",       max = 10,  resetType = "never", trackType = "quest", trackParams = { questIds = { 89100,89101,89102,89103,89104,89105,89106,89107,92374,92186 } } },
        { key = "ench_fc",      label = "First Crafts",  max = 79,  resetType = "never", trackType = "prof_firstcraft", trackParams = { spellIds = { 1236069,1236054,1236082,1236068,1236070,1236055,1236083,1236071,1236056,1236084,1236057,1236072,1236085,1236058,1236073,1236087,1236086,1236060,1236088,1236059,1236074,1236089,1236090,1236061,1236075,1236091,1236062,1236076,1236066,1236080,1236097,1236067,1236079,1236094,1236065,1236081,1236095,1236092,1236064,1236077,1236063,1236078,1236093,1236098,1236099,1236100,1236464,1236473,1236474,1236467,1236468,1236478,1236480,1236463,1236469,1236472,1236471,1236485,1236483,1236484,1236482,1236476,1236479,1236465,1236470,1236477,1236481,1236466,1236594,1236461,1236475,1236486,1236487,1236488,1236489,1236490,1236491,1236492,1236493 } } },
        { key = "ench_treatise",label = "Treatise",      max = 1,   trackType = "quest", trackParams = { questIds = { 95129 } } },
        { key = "ench_weekly",  label = "Weekly Quest",  max = 1,   trackType = "quest", trackParams = { questIds = { 93698,93699 } } },
        { key = "ench_gather",  label = "Gathering",     max = 6,   resetType = "never", trackType = "quest", trackParams = { questIds = { 95048,95049,95050,95051,95052,95053 } } },
        { key = "ench_treasure",label = "Treasures",     max = 2,   resetType = "never", trackType = "quest", trackParams = { questIds = { 93532,93533 } } },
        { key = "ench_dmf",     label = "Darkmoon Faire",max = 1,   trackType = "quest", trackParams = { questIds = { 29510 } } },
        { key = "ench_catchup", label = "Catch-up",      max = 0,   resetType = "never", trackType = "prof_catchup",       trackParams = { currencyId = 3198 } },
    }},
    { key = "engineering",    label = "Engineering",    skillLine = 2910, tasks = {
        { key = "eng_skill",    label = "Skill",         max = 100, resetType = "never", trackType = "prof_skill",         trackParams = { skillLineVariantID = 2910, baseSkillLineID = 202 } },
        { key = "eng_conc",     label = "Concentration", max = 0,   resetType = "never", trackType = "prof_concentration", trackParams = { currencyId = 3164 } },
        { key = "eng_know",     label = "Knowledge",     max = 0,   resetType = "never", trackType = "prof_knowledge",     trackParams = { skillLineVariantID = 2910 } },
        { key = "eng_uniq",     label = "Uniques",       max = 9,   resetType = "never", trackType = "quest", trackParams = { questIds = { 89133,89134,89135,89136,89137,89138,89139,89140,93796 } } },
        { key = "eng_fc",       label = "First Crafts",  max = 93,  resetType = "never", trackType = "prof_firstcraft", trackParams = { spellIds = { 1229755,1229853,1229856,1229857,1229858,1229859,1282456,1282455,1282457,1229870,1229871,1229872,1229873,1229874,1229875,1229876,1229877,1229878,1229879,1229880,1229881,1229862,1229863,1229864,1229865,1229866,1229867,1229868,1229869,1229935,1229936,1229937,1229938,1229882,1229883,1229884,1229885,1229886,1229887,1229888,1229889,1229890,1229891,1229892,1229893,1229908,1229909,1229910,1229911,1229912,1229913,1229914,1229915,1261490,1261491,1261492,1261493,1264523,1264524,1264525,1264526,1264527,1264528,1264529,1229894,1229897,1229902,1229903,1229905,1229907,1229906,1229895,1229896,1229898,1229899,1229900,1229901,1229904,1229921,1229924,1229917,1229922,1261945,1229926,1229916,1229919,1229928,1229923,1229927,1261866,1261893,1261895,1261913 } } },
        { key = "eng_treatise", label = "Treatise",      max = 1,   trackType = "quest", trackParams = { questIds = { 95138 } } },
        { key = "eng_weekly",   label = "Weekly Quest",  max = 1,   trackType = "quest", trackParams = { questIds = { 93692 } } },
        { key = "eng_treasure", label = "Treasures",     max = 2,   resetType = "never", trackType = "quest", trackParams = { questIds = { 93534,93535 } } },
        { key = "eng_dmf",      label = "Darkmoon Faire",max = 1,   trackType = "quest", trackParams = { questIds = { 29511 } } },
        { key = "eng_catchup",  label = "Catch-up",      max = 0,   resetType = "never", trackType = "prof_catchup",       trackParams = { currencyId = 3197 } },
    }},
    { key = "herbalism",      label = "Herbalism",      skillLine = 2912, tasks = {
        { key = "herb_skill",   label = "Skill",         max = 100, resetType = "never", trackType = "prof_skill",     trackParams = { skillLineVariantID = 2912, baseSkillLineID = 182 } },
        { key = "herb_know",    label = "Knowledge",     max = 0,   resetType = "never", trackType = "prof_knowledge", trackParams = { skillLineVariantID = 2912 } },
        { key = "herb_uniq",    label = "Uniques",       max = 10,  resetType = "never", trackType = "quest", trackParams = { questIds = { 89162,89161,89160,89159,89158,89157,89156,89155,93411,92174 } } },
        { key = "herb_fc",      label = "First Crafts",  max = 30,  resetType = "never", trackType = "prof_firstcraft", trackParams = { spellIds = { 1223099,1223148,1224883,1224898,1224888,1224893,1223135,1223151,1224886,1224901,1224891,1224896,1223137,1223150,1224885,1224900,1224890,1224895,1223138,1223146,1224882,1224897,1224887,1224892,1223139,1224884,1223149,1224899,1224889,1224894 } } },
        { key = "herb_treatise",label = "Treatise",      max = 1,   trackType = "quest", trackParams = { questIds = { 95130 } } },
        { key = "herb_weekly",  label = "Weekly Quest",  max = 1,   trackType = "quest", trackParams = { questIds = { 93700,93702,93703,93704 } } },
        { key = "herb_gather",  label = "Gathering",     max = 6,   resetType = "never", trackType = "quest", trackParams = { questIds = { 81425,81426,81427,81428,81429,81430 } } },
        { key = "herb_dmf",     label = "Darkmoon Faire",max = 1,   trackType = "quest", trackParams = { questIds = { 29514 } } },
        { key = "herb_catchup", label = "Catch-up",      max = 0,   resetType = "never", trackType = "prof_catchup",   trackParams = { currencyId = 3196 } },
    }},
    { key = "inscription",    label = "Inscription",    skillLine = 2913, tasks = {
        { key = "insc_skill",   label = "Skill",         max = 100, resetType = "never", trackType = "prof_skill",         trackParams = { skillLineVariantID = 2913, baseSkillLineID = 773 } },
        { key = "insc_conc",    label = "Concentration", max = 0,   resetType = "never", trackType = "prof_concentration", trackParams = { currencyId = 3165 } },
        { key = "insc_know",    label = "Knowledge",     max = 0,   resetType = "never", trackType = "prof_knowledge",     trackParams = { skillLineVariantID = 2913 } },
        { key = "insc_uniq",    label = "Uniques",       max = 9,   resetType = "never", trackType = "quest", trackParams = { questIds = { 89067,89068,89069,89070,89071,89072,89073,89074,93412 } } },
        { key = "insc_fc",      label = "First Crafts",  max = 65,  resetType = "never", trackType = "prof_firstcraft", trackParams = { spellIds = { 1230016,1230017,1230018,1230019,1230020,1230021,1230022,1230023,1230024,1230025,1264550,1264551,1264552,1230026,1230027,1230028,1230029,1230030,1230031,1230032,1230033,1230034,1230035,1230036,1230037,1230038,1230039,1230040,1230041,1230042,1230043,1230044,1230045,1230046,1230047,1230048,1230049,1230050,1230051,1230052,1230053,1230054,1230055,1230056,1230057,1230058,1230059,1230060,1230061,1230062,1230064,1230065,1230066,1230067,1230068,1230069,1260760,1230070,1230071,1230072,1230073,1230074,1230075,1230076,1230077 } } },
        { key = "insc_treatise",label = "Treatise",      max = 1,   trackType = "quest", trackParams = { questIds = { 95131 } } },
        { key = "insc_weekly",  label = "Weekly Quest",  max = 1,   trackType = "quest", trackParams = { questIds = { 93693 } } },
        { key = "insc_treasure",label = "Treasures",     max = 2,   resetType = "never", trackType = "quest", trackParams = { questIds = { 93536,93537 } } },
        { key = "insc_dmf",     label = "Darkmoon Faire",max = 1,   trackType = "quest", trackParams = { questIds = { 29515 } } },
        { key = "insc_catchup", label = "Catch-up",      max = 0,   resetType = "never", trackType = "prof_catchup",       trackParams = { currencyId = 3195 } },
    }},
    { key = "jewelcrafting",  label = "Jewelcrafting",  skillLine = 2914, tasks = {
        { key = "jc_skill",     label = "Skill",         max = 100, resetType = "never", trackType = "prof_skill",         trackParams = { skillLineVariantID = 2914, baseSkillLineID = 755 } },
        { key = "jc_conc",      label = "Concentration", max = 0,   resetType = "never", trackType = "prof_concentration", trackParams = { currencyId = 3166 } },
        { key = "jc_know",      label = "Knowledge",     max = 0,   resetType = "never", trackType = "prof_knowledge",     trackParams = { skillLineVariantID = 2914 } },
        { key = "jc_uniq",      label = "Uniques",       max = 9,   resetType = "never", trackType = "quest", trackParams = { questIds = { 89122,89123,89124,89125,89126,89127,89128,89129,93222 } } },
        { key = "jc_fc",        label = "First Crafts",  max = 71,  resetType = "never", trackType = "prof_firstcraft", trackParams = { spellIds = { 1230474,1230475,1230476,1230477,1230478,1230437,1230439,1230440,1230441,1230442,1230443,1230444,1230445,1230446,1230447,1230448,1230449,1230450,1230451,1230452,1230453,1230454,1230455,1230456,1230457,1230458,1230459,1230460,1230461,1230462,1230463,1230464,1230465,1230466,1230467,1230468,1230469,1230470,1230471,1230472,1230473,1230481,1230482,1230483,1230484,1230485,1230479,1230487,1230489,1230486,1230488,1251983,1230490,1230491,1230492,1230493,1230494,1230495,1230496,1230497,1230498,1242461,1242462,1242463,1242464,1230499,1230500,1230501,1230502,1230503,1230504 } } },
        { key = "jc_treatise",  label = "Treatise",      max = 1,   trackType = "quest", trackParams = { questIds = { 95133 } } },
        { key = "jc_weekly",    label = "Weekly Quest",  max = 1,   trackType = "quest", trackParams = { questIds = { 93694 } } },
        { key = "jc_treasure",  label = "Treasures",     max = 2,   resetType = "never", trackType = "quest", trackParams = { questIds = { 93539,93538 } } },
        { key = "jc_dmf",       label = "Darkmoon Faire",max = 1,   trackType = "quest", trackParams = { questIds = { 29516 } } },
        { key = "jc_catchup",   label = "Catch-up",      max = 0,   resetType = "never", trackType = "prof_catchup",       trackParams = { currencyId = 3194 } },
    }},
    { key = "leatherworking", label = "Leatherworking", skillLine = 2915, tasks = {
        { key = "lw_skill",     label = "Skill",         max = 100, resetType = "never", trackType = "prof_skill",         trackParams = { skillLineVariantID = 2915, baseSkillLineID = 165 } },
        { key = "lw_conc",      label = "Concentration", max = 0,   resetType = "never", trackType = "prof_concentration", trackParams = { currencyId = 3167 } },
        { key = "lw_know",      label = "Knowledge",     max = 0,   resetType = "never", trackType = "prof_knowledge",     trackParams = { skillLineVariantID = 2915 } },
        { key = "lw_uniq",      label = "Uniques",       max = 9,   resetType = "never", trackType = "quest", trackParams = { questIds = { 89089,89090,89091,89092,89093,89094,89095,89096,92371 } } },
        { key = "lw_fc",        label = "First Crafts",  max = 93,  resetType = "never", trackType = "prof_firstcraft", trackParams = { spellIds = { 1237490,1237491,1237492,1237493,1237494,1237495,1237496,1237497,1237499,1237500,1237501,1237502,1237503,1237504,1237505,1237506,1237507,1237508,1237509,1237510,1237511,1237512,1237513,1237514,1237486,1237487,1237488,1237489,1237498,1237520,1237521,1237522,1237523,1237524,1237525,1237526,1237527,1237528,1237529,1237530,1237531,1237532,1237533,1237534,1237535,1237536,1237537,1237538,1237539,1237540,1237541,1237542,1237543,1237515,1237516,1237517,1237518,1237519,1237544,1237545,1237546,1237547,1237548,1237549,1237550,1237551,1237552,1237553,1237554,1237555,1237556,1237557,1237558,1237559,1237560,1237561,1237562,1237563,1237564,1237565,1237566,1237567,1237568,1237569,1237570,1237571,1237572,1237573,1237574,1237575,1237577,1237578,1237579 } } },
        { key = "lw_treatise",  label = "Treatise",      max = 1,   trackType = "quest", trackParams = { questIds = { 95134 } } },
        { key = "lw_weekly",    label = "Weekly Quest",  max = 1,   trackType = "quest", trackParams = { questIds = { 93695 } } },
        { key = "lw_treasure",  label = "Treasures",     max = 2,   resetType = "never", trackType = "quest", trackParams = { questIds = { 93540,93541 } } },
        { key = "lw_dmf",       label = "Darkmoon Faire",max = 1,   trackType = "quest", trackParams = { questIds = { 29517 } } },
        { key = "lw_catchup",   label = "Catch-up",      max = 0,   resetType = "never", trackType = "prof_catchup",       trackParams = { currencyId = 3193 } },
    }},
    { key = "mining",         label = "Mining",         skillLine = 2916, tasks = {
        { key = "mine_skill",   label = "Skill",         max = 100, resetType = "never", trackType = "prof_skill",     trackParams = { skillLineVariantID = 2916, baseSkillLineID = 186 } },
        { key = "mine_know",    label = "Knowledge",     max = 0,   resetType = "never", trackType = "prof_knowledge", trackParams = { skillLineVariantID = 2916 } },
        { key = "mine_uniq",    label = "Uniques",       max = 10,  resetType = "never", trackType = "quest", trackParams = { questIds = { 89144,89145,89146,89147,89148,89149,89150,89151,92372,92187 } } },
        { key = "mine_fc",      label = "First Crafts",  max = 21,  resetType = "never", trackType = "prof_firstcraft", trackParams = { spellIds = { 1225343,1225349,1225350,1225354,1225351,1225353,1225352,1225347,1225365,1225366,1225369,1225367,1225368,1225370,1225348,1225355,1225357,1225361,1225359,1225363,1225362 } } },
        { key = "mine_treatise",label = "Treatise",      max = 1,   trackType = "quest", trackParams = { questIds = { 95135 } } },
        { key = "mine_weekly",  label = "Weekly Quest",  max = 1,   trackType = "quest", trackParams = { questIds = { 93705,93706,93708,93709 } } },
        { key = "mine_gather",  label = "Gathering",     max = 6,   resetType = "never", trackType = "quest", trackParams = { questIds = { 88673,88674,88675,88676,88677,88678 } } },
        { key = "mine_dmf",     label = "Darkmoon Faire",max = 1,   trackType = "quest", trackParams = { questIds = { 29518 } } },
        { key = "mine_catchup", label = "Catch-up",      max = 0,   resetType = "never", trackType = "prof_catchup",   trackParams = { currencyId = 3192 } },
    }},
    { key = "skinning",       label = "Skinning",       skillLine = 2917, tasks = {
        { key = "skin_skill",   label = "Skill",         max = 100, resetType = "never", trackType = "prof_skill",     trackParams = { skillLineVariantID = 2917, baseSkillLineID = 393 } },
        { key = "skin_know",    label = "Knowledge",     max = 0,   resetType = "never", trackType = "prof_knowledge", trackParams = { skillLineVariantID = 2917 } },
        { key = "skin_uniq",    label = "Uniques",       max = 10,  resetType = "never", trackType = "quest", trackParams = { questIds = { 89166,89167,89168,89169,89170,89171,89172,89173,92373,92188 } } },
        { key = "skin_treatise",label = "Treatise",      max = 1,   trackType = "quest", trackParams = { questIds = { 95136 } } },
        { key = "skin_weekly",  label = "Weekly Quest",  max = 1,   trackType = "quest", trackParams = { questIds = { 93710,93711,93712,93714 } } },
        { key = "skin_gather",  label = "Gathering",     max = 6,   resetType = "never", trackType = "quest", trackParams = { questIds = { 88534,88549,88537,88536,88530,88529 } } },
        { key = "skin_dmf",     label = "Darkmoon Faire",max = 1,   trackType = "quest", trackParams = { questIds = { 29519 } } },
        { key = "skin_catchup", label = "Catch-up",      max = 0,   resetType = "never", trackType = "prof_catchup",   trackParams = { currencyId = 3191 } },
    }},
    { key = "tailoring",      label = "Tailoring",      skillLine = 2918, tasks = {
        { key = "tail_skill",   label = "Skill",         max = 100, resetType = "never", trackType = "prof_skill",         trackParams = { skillLineVariantID = 2918, baseSkillLineID = 197 } },
        { key = "tail_conc",    label = "Concentration", max = 0,   resetType = "never", trackType = "prof_concentration", trackParams = { currencyId = 3168 } },
        { key = "tail_know",    label = "Knowledge",     max = 0,   resetType = "never", trackType = "prof_knowledge",     trackParams = { skillLineVariantID = 2918 } },
        { key = "tail_uniq",    label = "Uniques",       max = 9,   resetType = "never", trackType = "quest", trackParams = { questIds = { 89078,89079,89080,89081,89082,89083,89084,89085,93201 } } },
        { key = "tail_fc",      label = "First Crafts",  max = 73,  resetType = "never", trackType = "prof_firstcraft", trackParams = { spellIds = { 1227926,1228060,1228939,1228940,1228941,1228981,1228982,1228983,1228987,1228984,1228985,1228986,1228988,1228942,1228943,1228944,1228945,1228946,1228947,1228948,1228949,1228950,1228951,1228952,1228953,1228954,1228955,1228956,1228957,1228958,1228959,1228989,1228990,1228991,1228992,1228993,1228994,1228995,1228996,1228997,1280541,1280542,1280543,1280544,1280545,1280546,1228960,1228961,1279123,1279124,1279125,1279128,1279129,1228962,1228963,1228964,1228965,1228966,1228967,1228968,1228969,1228970,1228971,1228972,1228973,1228974,1228975,1228976,1228977,1228978,1228979,1228980 } } },
        { key = "tail_treatise",label = "Treatise",      max = 1,   trackType = "quest", trackParams = { questIds = { 95137 } } },
        { key = "tail_weekly",  label = "Weekly Quest",  max = 1,   trackType = "quest", trackParams = { questIds = { 93696 } } },
        { key = "tail_treasure",label = "Treasures",     max = 2,   resetType = "never", trackType = "quest", trackParams = { questIds = { 93542,93543 } } },
        { key = "tail_dmf",     label = "Darkmoon Faire",max = 1,   trackType = "quest", trackParams = { questIds = { 29520 } } },
        { key = "tail_catchup", label = "Catch-up",      max = 0,   resetType = "never", trackType = "prof_catchup",       trackParams = { currencyId = 3190 } },
    }},
}

local UNIQUE_ITEMS_TEMPLATES = {
    { key = "alchemy", label = "Alchemy", tasks = {
        { key = "alch_u1",  label = "Alchemy Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89115 }, itemId = 238536 } },
        { key = "alch_u2",  label = "Alchemy Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89117 }, itemId = 238538 } },
        { key = "alch_u3",  label = "Alchemy Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89114 }, itemId = 238535 } },
        { key = "alch_u4",  label = "Alchemy Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89116 }, itemId = 238537 } },
        { key = "alch_u5",  label = "Alchemy Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89113 }, itemId = 238534 } },
        { key = "alch_u6",  label = "Alchemy Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89112 }, itemId = 238533 } },
        { key = "alch_u7",  label = "Alchemy Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89111 }, itemId = 238532 } },
        { key = "alch_u8",  label = "Alchemy Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89118 }, itemId = 238539 } },
        { key = "alch_u9",  label = "Alchemy Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 93794 }, itemId = 262645 } },
    }},
    { key = "blacksmithing", label = "Blacksmithing", tasks = {
        { key = "bs_u1",  label = "Blacksmithing Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89177 }, itemId = 238540 } },
        { key = "bs_u2",  label = "Blacksmithing Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89178 }, itemId = 238541 } },
        { key = "bs_u3",  label = "Blacksmithing Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89179 }, itemId = 238542 } },
        { key = "bs_u4",  label = "Blacksmithing Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89180 }, itemId = 238543 } },
        { key = "bs_u5",  label = "Blacksmithing Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89181 }, itemId = 238544 } },
        { key = "bs_u6",  label = "Blacksmithing Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89182 }, itemId = 238545 } },
        { key = "bs_u7",  label = "Blacksmithing Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89183 }, itemId = 238546 } },
        { key = "bs_u8",  label = "Blacksmithing Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89184 }, itemId = 238547 } },
        { key = "bs_u9",  label = "Blacksmithing Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 93795 }, itemId = 262644 } },
    }},
    { key = "enchanting", label = "Enchanting", tasks = {
        { key = "ench_u1",  label = "Enchanting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89100 }, itemId = 238548 } },
        { key = "ench_u2",  label = "Enchanting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89101 }, itemId = 238549 } },
        { key = "ench_u3",  label = "Enchanting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89102 }, itemId = 238550 } },
        { key = "ench_u4",  label = "Enchanting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89103 }, itemId = 238551 } },
        { key = "ench_u5",  label = "Enchanting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89104 }, itemId = 238552 } },
        { key = "ench_u6",  label = "Enchanting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89105 }, itemId = 238553 } },
        { key = "ench_u7",  label = "Enchanting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89106 }, itemId = 238554 } },
        { key = "ench_u8",  label = "Enchanting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89107 }, itemId = 238555 } },
        { key = "ench_u9",  label = "Enchanting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 92374 }, itemId = 257600 } },
        { key = "ench_u10", label = "Enchanting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 92186 }, itemId = 250445 } },
    }},
    { key = "engineering", label = "Engineering", tasks = {
        { key = "eng_u1",  label = "Engineering Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89133 }, itemId = 238556 } },
        { key = "eng_u2",  label = "Engineering Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89134 }, itemId = 238557 } },
        { key = "eng_u3",  label = "Engineering Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89135 }, itemId = 238558 } },
        { key = "eng_u4",  label = "Engineering Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89136 }, itemId = 238559 } },
        { key = "eng_u5",  label = "Engineering Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89137 }, itemId = 238560 } },
        { key = "eng_u6",  label = "Engineering Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89138 }, itemId = 238561 } },
        { key = "eng_u7",  label = "Engineering Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89139 }, itemId = 238562 } },
        { key = "eng_u8",  label = "Engineering Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89140 }, itemId = 238563 } },
        { key = "eng_u9",  label = "Engineering Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 93796 }, itemId = 262646 } },
    }},
    { key = "herbalism", label = "Herbalism", tasks = {
        { key = "herb_u1",  label = "Herbalism Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89162 }, itemId = 238468 } },
        { key = "herb_u2",  label = "Herbalism Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89161 }, itemId = 238469 } },
        { key = "herb_u3",  label = "Herbalism Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89160 }, itemId = 238470 } },
        { key = "herb_u4",  label = "Herbalism Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89159 }, itemId = 238471 } },
        { key = "herb_u5",  label = "Herbalism Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89158 }, itemId = 238472 } },
        { key = "herb_u6",  label = "Herbalism Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89157 }, itemId = 238473 } },
        { key = "herb_u7",  label = "Herbalism Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89156 }, itemId = 238474 } },
        { key = "herb_u8",  label = "Herbalism Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89155 }, itemId = 238475 } },
        { key = "herb_u9",  label = "Herbalism Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 93411 }, itemId = 258410 } },
        { key = "herb_u10", label = "Herbalism Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 92174 }, itemId = 250443 } },
    }},
    { key = "inscription", label = "Inscription", tasks = {
        { key = "insc_u1",  label = "Inscription Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89067 }, itemId = 238572 } },
        { key = "insc_u2",  label = "Inscription Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89068 }, itemId = 238573 } },
        { key = "insc_u3",  label = "Inscription Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89069 }, itemId = 238574 } },
        { key = "insc_u4",  label = "Inscription Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89070 }, itemId = 238575 } },
        { key = "insc_u5",  label = "Inscription Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89071 }, itemId = 238576 } },
        { key = "insc_u6",  label = "Inscription Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89072 }, itemId = 238577 } },
        { key = "insc_u7",  label = "Inscription Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89073 }, itemId = 238578 } },
        { key = "insc_u8",  label = "Inscription Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89074 }, itemId = 238579 } },
        { key = "insc_u9",  label = "Inscription Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 93412 }, itemId = 258411 } },
    }},
    { key = "jewelcrafting", label = "Jewelcrafting", tasks = {
        { key = "jc_u1",  label = "Jewelcrafting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89122 }, itemId = 238580 } },
        { key = "jc_u2",  label = "Jewelcrafting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89123 }, itemId = 238581 } },
        { key = "jc_u3",  label = "Jewelcrafting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89124 }, itemId = 238582 } },
        { key = "jc_u4",  label = "Jewelcrafting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89125 }, itemId = 238583 } },
        { key = "jc_u5",  label = "Jewelcrafting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89126 }, itemId = 238584 } },
        { key = "jc_u6",  label = "Jewelcrafting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89127 }, itemId = 238585 } },
        { key = "jc_u7",  label = "Jewelcrafting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89128 }, itemId = 238586 } },
        { key = "jc_u8",  label = "Jewelcrafting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89129 }, itemId = 238587 } },
        { key = "jc_u9",  label = "Jewelcrafting Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 93222 }, itemId = 257599 } },
    }},
    { key = "leatherworking", label = "Leatherworking", tasks = {
        { key = "lw_u1",  label = "Leatherworking Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89089 }, itemId = 238588 } },
        { key = "lw_u2",  label = "Leatherworking Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89090 }, itemId = 238589 } },
        { key = "lw_u3",  label = "Leatherworking Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89091 }, itemId = 238590 } },
        { key = "lw_u4",  label = "Leatherworking Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89092 }, itemId = 238591 } },
        { key = "lw_u5",  label = "Leatherworking Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89093 }, itemId = 238592 } },
        { key = "lw_u6",  label = "Leatherworking Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89094 }, itemId = 238593 } },
        { key = "lw_u7",  label = "Leatherworking Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89095 }, itemId = 238594 } },
        { key = "lw_u8",  label = "Leatherworking Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89096 }, itemId = 238595 } },
        { key = "lw_u9",  label = "Leatherworking Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 92371 }, itemId = 250922 } },
    }},
    { key = "mining", label = "Mining", tasks = {
        { key = "mine_u1",  label = "Mining Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89144 }, itemId = 238596 } },
        { key = "mine_u2",  label = "Mining Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89145 }, itemId = 238597 } },
        { key = "mine_u3",  label = "Mining Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89146 }, itemId = 238598 } },
        { key = "mine_u4",  label = "Mining Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89147 }, itemId = 238599 } },
        { key = "mine_u5",  label = "Mining Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89148 }, itemId = 238600 } },
        { key = "mine_u6",  label = "Mining Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89149 }, itemId = 238601 } },
        { key = "mine_u7",  label = "Mining Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89150 }, itemId = 238602 } },
        { key = "mine_u8",  label = "Mining Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89151 }, itemId = 238603 } },
        { key = "mine_u9",  label = "Mining Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 92372 }, itemId = 250924 } },
        { key = "mine_u10", label = "Mining Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 92187 }, itemId = 250444 } },
    }},
    { key = "skinning", label = "Skinning", tasks = {
        { key = "skin_u1",  label = "Skinning Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89166 }, itemId = 238628 } },
        { key = "skin_u2",  label = "Skinning Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89167 }, itemId = 238629 } },
        { key = "skin_u3",  label = "Skinning Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89168 }, itemId = 238630 } },
        { key = "skin_u4",  label = "Skinning Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89169 }, itemId = 238631 } },
        { key = "skin_u5",  label = "Skinning Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89170 }, itemId = 238632 } },
        { key = "skin_u6",  label = "Skinning Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89171 }, itemId = 238633 } },
        { key = "skin_u7",  label = "Skinning Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89172 }, itemId = 238634 } },
        { key = "skin_u8",  label = "Skinning Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89173 }, itemId = 238635 } },
        { key = "skin_u9",  label = "Skinning Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 92373 }, itemId = 250923 } },
        { key = "skin_u10", label = "Skinning Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 92188 }, itemId = 250360 } },
    }},
    { key = "tailoring", label = "Tailoring", tasks = {
        { key = "tail_u1",  label = "Tailoring Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89078 }, itemId = 238612 } },
        { key = "tail_u2",  label = "Tailoring Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89079 }, itemId = 238613 } },
        { key = "tail_u3",  label = "Tailoring Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89080 }, itemId = 238614 } },
        { key = "tail_u4",  label = "Tailoring Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89081 }, itemId = 238615 } },
        { key = "tail_u5",  label = "Tailoring Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89082 }, itemId = 238616 } },
        { key = "tail_u6",  label = "Tailoring Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89083 }, itemId = 238617 } },
        { key = "tail_u7",  label = "Tailoring Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89084 }, itemId = 238618 } },
        { key = "tail_u8",  label = "Tailoring Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 89085 }, itemId = 238619 } },
        { key = "tail_u9",  label = "Tailoring Unique",  max = 1, trackType = "quest", trackParams = { questIds = { 93201 }, itemId = 257601 } },
    }},
}

local EVERSONG_WOODS_TEMPLATE = {
    title = "Eversong Woods - Rares & Treasures",
    sections = {
        {
            label = "Rares",
            type = "custom",
            resetType = "weekly",
            tasks = {
                { label = "Warden of Weeds", max = 1, trackType = "manual" },
                { label = "Overfester Hydra", max = 1, trackType = "manual" },
                { label = "Cre'van", max = 1, trackType = "manual" },
                { label = "Lady Liminus", max = 1, trackType = "manual" },
                { label = "Bad Zed", max = 1, trackType = "manual" },
                { label = "Banuran", max = 1, trackType = "manual" },
                { label = "Duskburn", max = 1, trackType = "manual" },
                { label = "Dame Bloodshed", max = 1, trackType = "manual" },
                { label = "Harried Hawkstrider", max = 1, trackType = "manual" },
                { label = "Bloated Snapdragon", max = 1, trackType = "manual" },
                { label = "Coralfang", max = 1, trackType = "manual" },
                { label = "Terrinor", max = 1, trackType = "manual" },
                { label = "Waverly", max = 1, trackType = "manual" },
                { label = "Lost Guardian", max = 1, trackType = "manual" },
                { label = "Malfunctioning Construct", max = 1, trackType = "manual" },
            },
        },
        {
            label = "Treasures",
            type = "custom",
            resetType = "never",
            tasks = {
                { label = "Rookery Cache", max = 1, trackType = "manual" },
                { label = "Gift of the Phoenix", max = 1, trackType = "manual" },
                { label = "Gilded Armillary Sphere", max = 1, trackType = "manual" },
                { label = "Farstrider's Lost Quiver", max = 1, trackType = "manual" },
                { label = "Burbling Paint Pot", max = 1, trackType = "manual" },
                { label = "Triple-Locked Safebox", max = 1, trackType = "manual" },
                { label = "Forgotten Ink and Quill", max = 1, trackType = "manual" },
                { label = "Antique Nobleman's Signet Ring", max = 1, trackType = "manual" },
                { label = "Stone Vat of Wine", max = 1, trackType = "manual" },
            },
        },
    },
}

local RENOWN_FACTIONS = {
    { key = "silvermoon", label = "Silvermoon Court",  factionId = 2710, maxRenown = 20 },
    { key = "amani",      label = "Amani Tribe",       factionId = 2696, maxRenown = 20 },
    { key = "harati",     label = "Harati",            factionId = 2704, maxRenown = 20 },
    { key = "singularity",label = "The Singularity",   factionId = 2699, maxRenown = 20 },
}

function RoutinesData:GetSectionTemplates()
    return {
        { key = "custom",        label = "Custom Section" },
        { key = "great_vault",   label = "Great Vault" },
        { key = "prey",          label = "Prey System" },
        { key = "weekly_tasks",  label = "Season Weeklies" },
        { key = "renown",        label = "Renown Tracking" },
        { key = "professions",   label = "Professions" },
        { key = "prof_uniques",  label = "Track Uniques" },
    }
end

function RoutinesData:GetProfessionTemplates()
    return PROFESSION_TEMPLATES
end

function RoutinesData:GetUniqueItemsTemplates()
    return UNIQUE_ITEMS_TEMPLATES
end

function RoutinesData:CreateSectionFromTemplate(templateKey, options)
    if templateKey == "great_vault" then
        local section = {}
        for k, v in pairs(GREAT_VAULT_TEMPLATE) do
            if k == "tasks" then
                section.tasks = {}
                for _, t in ipairs(v) do
                    local task = {}
                    for tk, tv in pairs(t) do task[tk] = tv end
                    table.insert(section.tasks, task)
                end
            else
                section[k] = v
            end
        end
        section.key = "s-" .. string.format("%04x", math.random(0, 65535))
        return section

    elseif templateKey == "prey" then
        local section = {}
        for k, v in pairs(PREY_TEMPLATE) do
            if k == "tasks" then
                section.tasks = {}
                for _, t in ipairs(v) do
                    local task = {}
                    for tk, tv in pairs(t) do task[tk] = tv end
                    table.insert(section.tasks, task)
                end
            else
                section[k] = v
            end
        end
        section.key = "s-" .. string.format("%04x", math.random(0, 65535))
        return section

    elseif templateKey == "weekly_tasks" then
        local section = {}
        for k, v in pairs(WEEKLY_TASKS_TEMPLATE) do
            if k == "tasks" then
                section.tasks = {}
                for _, t in ipairs(v) do
                    local task = {}
                    for tk, tv in pairs(t) do task[tk] = tv end
                    table.insert(section.tasks, task)
                end
            else
                section[k] = v
            end
        end
        section.key = "s-" .. string.format("%04x", math.random(0, 65535))
        return section

    elseif templateKey == "renown" then
        local section = {
            key = "s-" .. string.format("%04x", math.random(0, 65535)),
            label = "Renown",
            type = "renown",
            resetType = "never",
            tasks = {},
        }
        local selected = (options and options.factions) or RENOWN_FACTIONS
        for _, fac in ipairs(selected) do
            table.insert(section.tasks, {
                key = "renown_" .. fac.key,
                label = fac.label,
                max = fac.maxRenown,
                trackType = "renown",
                trackParams = { factionId = fac.factionId, maxRenown = fac.maxRenown },
            })
        end
        return section

    elseif templateKey == "professions" then
        local profKey = options and options.professionKey
        if not profKey then return nil end
        local profTemplate = nil
        for _, pt in ipairs(PROFESSION_TEMPLATES) do
            if pt.key == profKey then profTemplate = pt; break end
        end
        if not profTemplate then return nil end
        local section = {
            key = "s-" .. string.format("%04x", math.random(0, 65535)),
            label = profTemplate.label,
            type = "professions",
            resetType = "weekly",
            tasks = {},
        }
        for _, t in ipairs(profTemplate.tasks) do
            local task = {}
            for tk, tv in pairs(t) do task[tk] = tv end
            table.insert(section.tasks, task)
        end
        return section

    elseif templateKey == "prof_uniques" then
        local profKey = options and options.professionKey
        if not profKey then return nil end
        local uniqueTemplate = nil
        for _, ut in ipairs(UNIQUE_ITEMS_TEMPLATES) do
            if ut.key == profKey then uniqueTemplate = ut; break end
        end
        if not uniqueTemplate then return nil end
        local section = {
            key = "s-" .. string.format("%04x", math.random(0, 65535)),
            label = uniqueTemplate.label .. " - Uniques",
            type = "prof_uniques",
            resetType = "never",
            tasks = {},
        }
        for _, t in ipairs(uniqueTemplate.tasks) do
            local task = {}
            for tk, tv in pairs(t) do task[tk] = tv end
            table.insert(section.tasks, task)
        end
        return section

    elseif templateKey == "custom" then
        return {
            key = "s-" .. string.format("%04x", math.random(0, 65535)),
            label = (options and options.label) or "",
            type = "custom",
            resetType = (options and options.resetType) or "weekly",
            tasks = {},
        }
    end

    return nil
end

function RoutinesData:GetRenownFactions()
    return RENOWN_FACTIONS
end

function RoutinesData:ExportRoutine(routineID)
    local routine = self:GetRoutine(routineID)
    if not routine then return nil end

    local exportData = {
        t = routine.title,
        s = {},
    }

    for _, section in ipairs(routine.sections) do
        local secExport = {
            l = section.label,
            y = section.type,
            r = section.resetType,
            k = section.key,
            ts = {},
        }
        for _, task in ipairs(section.tasks or {}) do
            table.insert(secExport.ts, {
                k = task.key,
                l = task.label,
                m = task.max,
                tt = task.trackType,
                tp = task.trackParams,
                nm = task.noMax,
            })
        end
        table.insert(exportData.s, secExport)
    end

    return ns.GuidesData:SerializeTable(exportData)
end

function RoutinesData:ImportRoutine(importString)
    if not importString or importString == "" then return nil, "Empty string" end

    local data = ns.GuidesData:DeserializeTable(importString)
    if not data or type(data) ~= "table" then return nil, "Invalid format" end
    if not data.t or not data.s then return nil, "Missing routine data" end

    local routineData = {
        title = data.t,
        sections = {},
    }

    for _, secData in ipairs(data.s) do
        local section = {
            key = secData.k or ("s-" .. string.format("%04x", math.random(0, 65535))),
            label = secData.l or "",
            type = secData.y or "custom",
            resetType = secData.r or "weekly",
            tasks = {},
        }
        for _, taskData in ipairs(secData.ts or {}) do
            table.insert(section.tasks, {
                key = taskData.k or ("t-" .. string.format("%04x", math.random(0, 65535))),
                label = taskData.l or "",
                max = taskData.m or 1,
                trackType = taskData.tt or "manual",
                trackParams = taskData.tp or {},
                noMax = taskData.nm,
            })
        end
        table.insert(routineData.sections, section)
    end

    local routineID = self:AddRoutine(routineData)
    return routineID
end

function RoutinesData:CreateZoneRoutineFromTemplate(templateData)
    if not templateData or not templateData.title then return nil end

    local routineData = {
        title = templateData.title,
        sections = {},
    }

    for _, sectionTemplate in ipairs(templateData.sections or {}) do
        local section = {
            key = "s-" .. string.format("%04x", math.random(0, 65535)),
            label = sectionTemplate.label or "",
            type = sectionTemplate.type or "custom",
            resetType = sectionTemplate.resetType or "weekly",
            tasks = {},
        }

        for _, taskTemplate in ipairs(sectionTemplate.tasks or {}) do
            local task = {
                key = "t-" .. string.format("%04x", math.random(0, 65535)),
                label = taskTemplate.label or "",
                max = taskTemplate.max or 1,
                trackType = taskTemplate.trackType or "manual",
                trackParams = taskTemplate.trackParams or {},
                noMax = taskTemplate.noMax,
            }
            table.insert(section.tasks, task)
        end

        table.insert(routineData.sections, section)
    end

    return self:AddRoutine(routineData)
end

function RoutinesData:GetEversongWoodsRoutine()
    return EVERSONG_WOODS_TEMPLATE
end

function RoutinesData:CreateEversongWoodsRoutine()
    return self:CreateZoneRoutineFromTemplate(EVERSONG_WOODS_TEMPLATE)
end


local GETTING_STARTED_ROUTINE = {
    title = "Getting Started with Routines",
    sections = {
        {
            label = "Learn the Basics",
            type = "custom",
            resetType = "never",
            tasks = {
                { label = "Create your first routine using the New Routine button", max = 1, trackType = "manual" },
                { label = "Edit the routine title by clicking on it in the detail panel", max = 1, trackType = "manual" },
                { label = "Add a Custom Section and give it a label", max = 1, trackType = "manual" },
                { label = "Add a task to your custom section", max = 1, trackType = "manual" },
                { label = "Click a task to mark it complete", max = 1, trackType = "manual" },
            },
        },
        {
            label = "Try the Presets",
            type = "custom",
            resetType = "never",
            tasks = {
                { label = "Add a Great Vault section to see raid, dungeon, and world tracking", max = 1, trackType = "manual" },
                { label = "Add a Professions section and pick your profession", max = 1, trackType = "manual" },
                { label = "Add a Season Weeklies section to track weekly quests", max = 1, trackType = "manual" },
                { label = "Add a Renown Tracking section for Midnight factions", max = 1, trackType = "manual" },
                { label = "Add a Prey System section for hunt tracking", max = 1, trackType = "manual" },
            },
        },
        {
            label = "Pin and Share",
            type = "custom",
            resetType = "never",
            tasks = {
                { label = "Pin a routine to your screen using the Pin button", max = 1, trackType = "manual" },
                { label = "Drag the pinned window to reposition it", max = 1, trackType = "manual" },
                { label = "Export a routine using the Export button", max = 1, trackType = "manual" },
                { label = "Try importing a routine from the Import button", max = 1, trackType = "manual" },
                { label = "Visit the OneWoW Discord to share or find routines", max = 1, trackType = "manual" },
            },
        },
        {
            label = "Advanced Features",
            type = "custom",
            resetType = "never",
            tasks = {
                { label = "Set a section to Weekly reset so it clears on server reset", max = 1, trackType = "manual" },
                { label = "Create a task with a max higher than 1 for counter-style tracking", max = 1, trackType = "manual" },
                { label = "Use Reset Progress to clear all progress on a routine", max = 1, trackType = "manual" },
                { label = "Delete a routine you no longer need", max = 1, trackType = "manual" },
            },
        },
    },
}

function RoutinesData:LoadBundledRoutines(force)
    local addon = _G.OneWoW_Notes
    if not force and addon.db.global.bundledRoutinesLoaded then return end

    self:CreateZoneRoutineFromTemplate(GETTING_STARTED_ROUTINE)

    addon.db.global.bundledRoutinesLoaded = true
    return true
end
