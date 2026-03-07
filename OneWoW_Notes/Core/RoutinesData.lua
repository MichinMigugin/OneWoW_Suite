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
                    self:ResetSectionProgress(routineID, section.key)
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
        { key = "alch_weekly",   label = "Weekly Quest",      max = 1, trackType = "quest", trackParams = { questIds = { 93690 } } },
        { key = "alch_treatise", label = "Treatise",          max = 1, trackType = "quest", trackParams = { questIds = { 95127 } } },
        { key = "alch_dmf",      label = "Darkmoon Faire",    max = 1, trackType = "quest", trackParams = { questIds = { 29506 } } },
        { key = "alch_gather",   label = "Gathering (Catch-up)", max = 1, trackType = "manual" },
        { key = "alch_patron",   label = "Patron Orders (Catch-up)", max = 1, trackType = "manual" },
    }},
    { key = "blacksmithing",  label = "Blacksmithing",  skillLine = 2907, tasks = {
        { key = "bs_weekly",   label = "Weekly Quest",      max = 1, trackType = "quest", trackParams = { questIds = { 93691 } } },
        { key = "bs_treatise", label = "Treatise",          max = 1, trackType = "quest", trackParams = { questIds = { 95128 } } },
        { key = "bs_dmf",      label = "Darkmoon Faire",    max = 1, trackType = "quest", trackParams = { questIds = { 29508 } } },
        { key = "bs_gather",   label = "Gathering (Catch-up)", max = 1, trackType = "manual" },
        { key = "bs_patron",   label = "Patron Orders (Catch-up)", max = 1, trackType = "manual" },
    }},
    { key = "enchanting",     label = "Enchanting",     skillLine = 2909, tasks = {
        { key = "ench_weekly",   label = "Weekly Quest",   max = 1, trackType = "quest", trackParams = { questIds = { 93698, 93699 } } },
        { key = "ench_treatise", label = "Treatise",       max = 1, trackType = "quest", trackParams = { questIds = { 95129 } } },
        { key = "ench_dmf",      label = "Darkmoon Faire", max = 1, trackType = "quest", trackParams = { questIds = { 29510 } } },
        { key = "ench_gather",   label = "Gathering (Catch-up)", max = 1, trackType = "manual" },
        { key = "ench_patron",   label = "Patron Orders (Catch-up)", max = 1, trackType = "manual" },
    }},
    { key = "engineering",    label = "Engineering",    skillLine = 2910, tasks = {
        { key = "eng_weekly",   label = "Weekly Quest",      max = 1, trackType = "quest", trackParams = { questIds = { 93692 } } },
        { key = "eng_treatise", label = "Treatise",          max = 1, trackType = "quest", trackParams = { questIds = { 95138 } } },
        { key = "eng_dmf",      label = "Darkmoon Faire",    max = 1, trackType = "quest", trackParams = { questIds = { 29511 } } },
        { key = "eng_gather",   label = "Gathering (Catch-up)", max = 1, trackType = "manual" },
        { key = "eng_patron",   label = "Patron Orders (Catch-up)", max = 1, trackType = "manual" },
    }},
    { key = "herbalism",      label = "Herbalism",      skillLine = 2912, tasks = {
        { key = "herb_weekly",   label = "Weekly Quest",   max = 1, trackType = "quest", trackParams = { questIds = { 93700, 93702, 93703, 93704 } } },
        { key = "herb_treatise", label = "Treatise",       max = 1, trackType = "quest", trackParams = { questIds = { 95130 } } },
        { key = "herb_dmf",      label = "Darkmoon Faire", max = 1, trackType = "quest", trackParams = { questIds = { 29514 } } },
        { key = "herb_gather",   label = "Gathering (Catch-up)", max = 1, trackType = "manual" },
        { key = "herb_patron",   label = "Patron Orders (Catch-up)", max = 1, trackType = "manual" },
    }},
    { key = "inscription",    label = "Inscription",    skillLine = 2913, tasks = {
        { key = "insc_weekly",   label = "Weekly Quest",      max = 1, trackType = "quest", trackParams = { questIds = { 93693 } } },
        { key = "insc_treatise", label = "Treatise",          max = 1, trackType = "quest", trackParams = { questIds = { 95131 } } },
        { key = "insc_dmf",      label = "Darkmoon Faire",    max = 1, trackType = "quest", trackParams = { questIds = { 29515 } } },
        { key = "insc_gather",   label = "Gathering (Catch-up)", max = 1, trackType = "manual" },
        { key = "insc_patron",   label = "Patron Orders (Catch-up)", max = 1, trackType = "manual" },
    }},
    { key = "jewelcrafting",  label = "Jewelcrafting",  skillLine = 2914, tasks = {
        { key = "jc_weekly",   label = "Weekly Quest",      max = 1, trackType = "quest", trackParams = { questIds = { 93694 } } },
        { key = "jc_treatise", label = "Treatise",          max = 1, trackType = "quest", trackParams = { questIds = { 95133 } } },
        { key = "jc_dmf",      label = "Darkmoon Faire",    max = 1, trackType = "quest", trackParams = { questIds = { 29516 } } },
        { key = "jc_gather",   label = "Gathering (Catch-up)", max = 1, trackType = "manual" },
        { key = "jc_patron",   label = "Patron Orders (Catch-up)", max = 1, trackType = "manual" },
    }},
    { key = "leatherworking", label = "Leatherworking", skillLine = 2915, tasks = {
        { key = "lw_weekly",   label = "Weekly Quest",      max = 1, trackType = "quest", trackParams = { questIds = { 93695 } } },
        { key = "lw_treatise", label = "Treatise",          max = 1, trackType = "quest", trackParams = { questIds = { 95134 } } },
        { key = "lw_dmf",      label = "Darkmoon Faire",    max = 1, trackType = "quest", trackParams = { questIds = { 29517 } } },
        { key = "lw_gather",   label = "Gathering (Catch-up)", max = 1, trackType = "manual" },
        { key = "lw_patron",   label = "Patron Orders (Catch-up)", max = 1, trackType = "manual" },
    }},
    { key = "mining",         label = "Mining",         skillLine = 2916, tasks = {
        { key = "mine_weekly",   label = "Weekly Quest",   max = 1, trackType = "quest", trackParams = { questIds = { 93705, 93706, 93708, 93709 } } },
        { key = "mine_treatise", label = "Treatise",       max = 1, trackType = "quest", trackParams = { questIds = { 95135 } } },
        { key = "mine_dmf",      label = "Darkmoon Faire", max = 1, trackType = "quest", trackParams = { questIds = { 29518 } } },
        { key = "mine_gather",   label = "Gathering (Catch-up)", max = 1, trackType = "manual" },
        { key = "mine_patron",   label = "Patron Orders (Catch-up)", max = 1, trackType = "manual" },
    }},
    { key = "skinning",       label = "Skinning",       skillLine = 2917, tasks = {
        { key = "skin_weekly",   label = "Weekly Quest",   max = 1, trackType = "quest", trackParams = { questIds = { 93710, 93711, 93712, 93714 } } },
        { key = "skin_treatise", label = "Treatise",       max = 1, trackType = "quest", trackParams = { questIds = { 95136 } } },
        { key = "skin_dmf",      label = "Darkmoon Faire", max = 1, trackType = "quest", trackParams = { questIds = { 29519 } } },
        { key = "skin_gather",   label = "Gathering (Catch-up)", max = 1, trackType = "manual" },
        { key = "skin_patron",   label = "Patron Orders (Catch-up)", max = 1, trackType = "manual" },
    }},
    { key = "tailoring",      label = "Tailoring",      skillLine = 2918, tasks = {
        { key = "tail_weekly",   label = "Weekly Quest",      max = 1, trackType = "quest", trackParams = { questIds = { 93696 } } },
        { key = "tail_treatise", label = "Treatise",          max = 1, trackType = "quest", trackParams = { questIds = { 95137 } } },
        { key = "tail_dmf",      label = "Darkmoon Faire",    max = 1, trackType = "quest", trackParams = { questIds = { 29520 } } },
        { key = "tail_gather",   label = "Gathering (Catch-up)", max = 1, trackType = "manual" },
        { key = "tail_patron",   label = "Patron Orders (Catch-up)", max = 1, trackType = "manual" },
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
