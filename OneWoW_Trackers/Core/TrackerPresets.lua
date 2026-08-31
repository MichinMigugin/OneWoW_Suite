local _, ns = ...
local L = ns.L

ns.TrackerPresets = {}
local TP = ns.TrackerPresets

local tinsert, wipe, ipairs, sort, format = tinsert, wipe, ipairs, sort, format
local C_Map = C_Map

local SECTION_PRESETS = {
    {
        id = "farm_value",
        label = "Farm value",
        listType = "farmvalue",
        category = "Farming",
        sections = {},
    },
    {
        id = "great_vault",
        label = "Great Vault",
        listType = "weekly",
        category = "Gearing",
        sections = {
            {
                label = "Great Vault",
                steps = {
                    { label = "Raid Bosses",    trackType = "vault_raid",    max = 8 },
                    { label = "Mythic Dungeons", trackType = "vault_dungeon", max = 8 },
                    { label = "World Content",   trackType = "vault_world",   max = 8 },
                },
            },
        },
    },
    {
        id = "midnight_weeklies",
        label = "Midnight Weeklies",
        listType = "weekly",
        category = "General",
        sections = {
            {
                label = "Weekly Quests",
                steps = {
                    { label = "Abundance",       trackType = "quest", trackParams = { questIDs = { 86387 } }, max = 1 },
                    { label = "Lost Legends",    trackType = "quest", trackParams = { questIDs = { 86388 } }, max = 1 },
                    { label = "Theater Troupe",  trackType = "quest", trackParams = { questIDs = { 83240 } }, max = 1 },
                    { label = "Spreading the Light", trackType = "quest", trackParams = { questIDs = { 82946 } }, max = 1 },
                    { label = "World Boss",      trackType = "quest", trackParams = { questIDs = { 86389 } }, max = 1 },
                },
            },
        },
    },
    {
        id = "midnight_rares",
        titleKey = "TRACKER_QS_MIDNIGHT_RARES_TITLE",
        listType = "daily",
        category = "General",
    },
    {
        id = "prey_system",
        label = "Prey System",
        listType = "weekly",
        category = "General",
        sections = {
            {
                label = "Hunts",
                steps = {
                    { label = "Normal Hunt",    trackType = "quest", trackParams = { questIDs = { 86313 } }, max = 1 },
                    { label = "Hard Hunt",      trackType = "quest", trackParams = { questIDs = { 86314 } }, max = 1 },
                    { label = "Nightmare Hunt", trackType = "quest", trackParams = { questIDs = { 86315 } }, max = 1 },
                },
            },
            {
                label = "Remnants",
                steps = {
                    { label = "Remnant Currency", trackType = "currency", trackParams = { currencyID = 3220 }, max = 0, noMax = true },
                },
            },
        },
    },
    {
        id = "renown_tracking",
        label = "Renown Tracking",
        listType = "weekly",
        category = "Reputation",
        sections = {
            {
                label = "Midnight Factions",
                steps = {
                    { label = "Silvermoon Court",    trackType = "renown", trackParams = { factionID = 2710 }, max = 0, noMax = true },
                    { label = "Dawnfall",            trackType = "renown", trackParams = { factionID = 2711 }, max = 0, noMax = true },
                    { label = "Lamplighters",        trackType = "renown", trackParams = { factionID = 2712 }, max = 0, noMax = true },
                    { label = "Nightwatch",          trackType = "renown", trackParams = { factionID = 2713 }, max = 0, noMax = true },
                },
            },
        },
    },
    {
        id = "daily_tasks",
        label = "Daily Tasks Template",
        listType = "daily",
        category = "General",
        sections = {
            {
                label = "Daily Tasks",
                steps = {
                    { label = "Daily Quest Hub", trackType = "manual", max = 1 },
                    { label = "World Quests",    trackType = "manual", max = 4 },
                    { label = "Dungeon Run",     trackType = "manual", max = 1 },
                    { label = "Profession CDs",  trackType = "manual", max = 1 },
                },
            },
        },
    },
    {
        id = "todo_template",
        label = "To-Do List Template",
        listType = "todo",
        category = "General",
        sections = {
            {
                label = "Tasks",
                steps = {
                    { label = "Task 1", trackType = "manual", max = 1 },
                    { label = "Task 2", trackType = "manual", max = 1 },
                    { label = "Task 3", trackType = "manual", max = 1 },
                },
            },
        },
    },
}

local PROFESSION_PRESETS = {
    { name = "Alchemy",        baseSkillLineID = 171,  currencyConc = 2871, skillVariant = 2823 },
    { name = "Blacksmithing",  baseSkillLineID = 164,  currencyConc = 2872, skillVariant = 2822 },
    { name = "Enchanting",     baseSkillLineID = 333,  currencyConc = 2874, skillVariant = 2825 },
    { name = "Engineering",    baseSkillLineID = 202,  currencyConc = 2875, skillVariant = 2827 },
    { name = "Herbalism",      baseSkillLineID = 182,  currencyConc = 2876, skillVariant = 2832 },
    { name = "Inscription",    baseSkillLineID = 773,  currencyConc = 2877, skillVariant = 2828 },
    { name = "Jewelcrafting",  baseSkillLineID = 755,  currencyConc = 2878, skillVariant = 2829 },
    { name = "Leatherworking", baseSkillLineID = 165,  currencyConc = 2879, skillVariant = 2830 },
    { name = "Mining",         baseSkillLineID = 186,  currencyConc = 2880, skillVariant = 2833 },
    { name = "Skinning",       baseSkillLineID = 393,  currencyConc = 2881, skillVariant = 2834 },
    { name = "Tailoring",      baseSkillLineID = 197,  currencyConc = 2882, skillVariant = 2831 },
    { name = "Cooking",        baseSkillLineID = 185,  currencyConc = nil,  skillVariant = nil },
}

local function RareStepLabel(lock)
    local name = OneWoW.Collectibles.ResolveNPCName(lock.npcID)
    if name then return name end
    return format(L["TRACKER_RARE_FALLBACK"], lock.npcID)
end

local function RareStep(lock)
    local step = {
        label = RareStepLabel(lock),
        trackType = "rare_quest",
        trackParams = { questIDs = { lock.questID } },
        max = 1,
    }
    if lock.mapID and lock.x and lock.y then
        step.mapID = lock.mapID
        step.coordX = lock.x
        step.coordY = lock.y
    end
    return step
end

local function MapName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or nil
end

local function BuildMidnightRareSections()
    local locks = OneWoW.Collectibles.GetRareLocks({ expansion = Enum.ExpansionLevel.Midnight })
    local dailyByMap = {}
    local dailyOrder = {}
    local weekly = {}
    local noMap = {}
    for _, lock in ipairs(locks) do
        if lock.reset == "weekly" then
            tinsert(weekly, lock)
        elseif lock.mapID then
            if not dailyByMap[lock.mapID] then
                dailyByMap[lock.mapID] = {}
                tinsert(dailyOrder, lock.mapID)
            end
            tinsert(dailyByMap[lock.mapID], lock)
        else
            tinsert(noMap, lock)
        end
    end
    sort(dailyOrder, function(a, b)
        return (MapName(a) or "") < (MapName(b) or "")
    end)

    local sections = {}
    for _, mapID in ipairs(dailyOrder) do
        local steps = {}
        for _, lock in ipairs(dailyByMap[mapID]) do
            tinsert(steps, RareStep(lock))
        end
        tinsert(sections, {
            label = MapName(mapID) or L["TRACKER_PRESET_RARES_OTHER_ZONE"],
            steps = steps,
        })
    end
    if #noMap > 0 then
        local steps = {}
        for _, lock in ipairs(noMap) do
            tinsert(steps, RareStep(lock))
        end
        tinsert(sections, {
            label = L["TRACKER_PRESET_RARES_OTHER_ZONE"],
            steps = steps,
        })
    end
    if #weekly > 0 then
        local steps = {}
        for _, lock in ipairs(weekly) do
            tinsert(steps, RareStep(lock))
        end
        tinsert(sections, {
            label = L["TRACKER_PRESET_MIDNIGHT_RARES_WEEKLY"],
            steps = steps,
        })
    end
    return sections
end

for _, preset in ipairs(SECTION_PRESETS) do
    if preset.id == "midnight_rares" then
        preset.buildSections = BuildMidnightRareSections
        break
    end
end

function TP:GetSectionPresets()
    return SECTION_PRESETS
end

function TP:GetProfessionPresets()
    return PROFESSION_PRESETS
end

function TP:BuildProfessionSection(profName)
    for _, prof in ipairs(PROFESSION_PRESETS) do
        if prof.name == profName then
            local section = {
                label = prof.name,
                steps = {
                    {
                        label = prof.name .. " Skill",
                        trackType = "prof_skill",
                        trackParams = { baseSkillLineID = prof.baseSkillLineID },
                        max = 100,
                        noMax = true,
                    },
                },
            }

            if prof.currencyConc then
                tinsert(section.steps, {
                    label = "Concentration",
                    trackType = "prof_concentration",
                    trackParams = { currencyID = prof.currencyConc },
                    max = 1000,
                    noMax = true,
                })
            end

            if prof.skillVariant then
                tinsert(section.steps, {
                    label = "Knowledge Points",
                    trackType = "prof_knowledge",
                    trackParams = { skillLineVariantID = prof.skillVariant },
                    max = 0,
                    noMax = true,
                })
            end

            tinsert(section.steps, {
                label = "Weekly Quest",
                trackType = "manual",
                max = 1,
                resetOverride = "weekly",
            })

            tinsert(section.steps, {
                label = "Treatise",
                trackType = "manual",
                max = 1,
                resetOverride = "weekly",
            })

            return section
        end
    end
    return nil
end

function TP:CreateListFromPreset(presetID)
    local TD = ns.TrackerData
    if not TD then return nil end

    for _, preset in ipairs(SECTION_PRESETS) do
        if preset.id == presetID then
            local title = preset.titleKey and L[preset.titleKey] or preset.label
            local list = TD:CreateList({
                title = title,
                listType = preset.listType,
                category = preset.category or "General",
            })
            if not list then return nil end

            local sections = preset.sections or {}
            if preset.buildSections then
                sections = preset.buildSections()
            end
            for _, secData in ipairs(sections) do
                local sec = TD:AddSection(list.id, { label = secData.label })
                if sec then
                    for _, stepData in ipairs(secData.steps or {}) do
                        TD:AddStep(list.id, sec.key, {
                            label = stepData.label,
                            description = stepData.description,
                            trackType = stepData.trackType or "manual",
                            trackParams = stepData.trackParams or {},
                            max = stepData.max or 1,
                            noMax = stepData.noMax or false,
                            resetOverride = stepData.resetOverride,
                            mapID = stepData.mapID,
                            coordX = stepData.coordX,
                            coordY = stepData.coordY,
                        })
                    end
                end
            end

            if preset.listType == "farmvalue" then
                list.farmPanel = { mode = "watchlist", items = {} }
            end

            return list
        end
    end
    return nil
end

function TP:CreateProfessionList(professions)
    local TD = ns.TrackerData
    if not TD then return nil end
    if not professions or #professions == 0 then return nil end

    local list = TD:CreateList({
        title = "Profession Tracker",
        listType = "weekly",
        category = "Profession",
    })
    if not list then return nil end

    for _, profName in ipairs(professions) do
        local secData = self:BuildProfessionSection(profName)
        if secData then
            local sec = TD:AddSection(list.id, { label = secData.label })
            if sec then
                for _, stepData in ipairs(secData.steps or {}) do
                    TD:AddStep(list.id, sec.key, {
                        label = stepData.label,
                        trackType = stepData.trackType or "manual",
                        trackParams = stepData.trackParams or {},
                        max = stepData.max or 1,
                        noMax = stepData.noMax or false,
                        resetOverride = stepData.resetOverride,
                    })
                end
            end
        end
    end

    return list
end

local function BuildQuestIDRange(startID, endID, step)
    step = step or 1
    local ids = {}
    for qid = startID, endID, step do
        ids[#ids + 1] = qid
    end
    return ids
end

local function MergeQuestIDs(...)
    local result = {}
    for i = 1, select("#", ...) do
        local tbl = select(i, ...)
        for _, id in ipairs(tbl) do
            result[#result + 1] = id
        end
    end
    return result
end

local PREY_NORMAL_QUESTS = BuildQuestIDRange(91095, 91124)
local PREY_HARD_QUESTS = MergeQuestIDs(BuildQuestIDRange(91210, 91242, 2), BuildQuestIDRange(91243, 91255))
local PREY_NIGHTMARE_QUESTS = MergeQuestIDs(BuildQuestIDRange(91211, 91241, 2), BuildQuestIDRange(91256, 91269))

local BUNDLED_GUIDES = {
    {
        id = "bundled_tracker_howto",
        version = 1,
        data = {
            title = "How to Use the Tracker",
            description = "Learn how to create and use lists, guides, dailies, weeklies, and more.",
            listType = "guide",
            category = "General",
            sections = {
                {
                    label = "Getting Started",
                    steps = {
                        {
                            label = "Understanding List Types",
                            description = "The Tracker supports five list types:\n- Guide: Step-by-step walkthroughs\n- Daily: Resets every day\n- Weekly: Resets on your region's weekly reset day\n- To-Do: Never resets, check off manually\n- Repeating: Custom interval reset",
                            trackType = "manual",
                            max = 1,
                            objectives = {},
                        },
                        {
                            label = "Creating Your First List",
                            description = "Click 'New' and choose a list type. Add sections to group related tasks, then add steps to each section.",
                            trackType = "manual",
                            max = 1,
                            objectives = {},
                        },
                        {
                            label = "Auto-Tracking",
                            description = "Steps can auto-detect completion using quest IDs, currency amounts, item counts, coordinates, and more. Set the Track Type when adding a step.",
                            trackType = "manual",
                            max = 1,
                            objectives = {},
                        },
                    },
                },
                {
                    label = "Advanced Features",
                    steps = {
                        {
                            label = "Pinned Windows",
                            description = "Pin any list to show a floating window on screen. Drag to reposition, resize from the corner, and lock to prevent accidental moves.",
                            trackType = "manual",
                            max = 1,
                            objectives = {},
                        },
                        {
                            label = "Map Waypoints",
                            description = "Steps with coordinates show pins on your world map and minimap. Walk near the pin to auto-complete the step.",
                            trackType = "manual",
                            max = 1,
                            objectives = {},
                        },
                        {
                            label = "Import and Export",
                            description = "Share lists with other players. Export produces a text string, Import reads it back. Use the markup format to write guides quickly.",
                            trackType = "manual",
                            max = 1,
                            objectives = {},
                        },
                        {
                            label = "Presets",
                            description = "Use New to quickly add common tracking setups: Great Vault, Renown, Professions, Weeklies, and more.",
                            trackType = "manual",
                            max = 1,
                            objectives = {},
                        },
                    },
                },
            },
        },
    },
    {
        id = "bundled_moth_tracker",
        version = 2,
        data = {
            title = "Dusting for Moths - Collection Tracker",
            description = "Track all 120 Glowing Moths for the Dusting for Moths achievement. Auto-tracks warband-wide completion. Click any moth to set a waypoint. Renown gates show if you have unlocked each tier.",
            listType = "guide",
            category = "Collection",
            author = "OneWoW",
            sections = {
                {
                    label = "Renown 1 (40 Moths)",
                    steps = {
                        { label = "Reach Harati Renown 1", description = "You must reach Renown 1 with the Harati to collect these moths", trackType = "renown", trackParams = { factionID = 2704, level = 1 }, max = 1 },
                        { label = "Moth #1", description = "36.35, 48.39", trackType = "quest_account", trackParams = { questID = 92196 }, max = 1, mapID = 2413, coordX = 36.35, coordY = 48.39 },
                        { label = "Moth #3", description = "38.33, 47.44", trackType = "quest_account", trackParams = { questID = 92207 }, max = 1, mapID = 2413, coordX = 38.33, coordY = 47.44 },
                        { label = "Moth #5", description = "33.95, 44.04", trackType = "quest_account", trackParams = { questID = 92208 }, max = 1, mapID = 2413, coordX = 33.95, coordY = 44.04 },
                        { label = "Moth #6", description = "41.61, 40.12", trackType = "quest_account", trackParams = { questID = 92230 }, max = 1, mapID = 2413, coordX = 41.61, coordY = 40.12 },
                        { label = "Moth #13", description = "50.35, 33.6", trackType = "quest_account", trackParams = { questID = 92232 }, max = 1, mapID = 2413, coordX = 50.35, coordY = 33.6 },
                        { label = "Moth #15", description = "55.14, 32.88", trackType = "quest_account", trackParams = { questID = 92227 }, max = 1, mapID = 2413, coordX = 55.14, coordY = 32.88 },
                        { label = "Moth #17", description = "55.0, 27.55", trackType = "quest_account", trackParams = { questID = 92199 }, max = 1, mapID = 2413, coordX = 55, coordY = 27.55 },
                        { label = "Moth #21", description = "49.88, 25.51", trackType = "quest_account", trackParams = { questID = 92198 }, max = 1, mapID = 2413, coordX = 49.88, coordY = 25.51 },
                        { label = "Moth #23", description = "46.38, 24.88", trackType = "quest_account", trackParams = { questID = 92225 }, max = 1, mapID = 2413, coordX = 46.38, coordY = 24.88 },
                        { label = "Moth #25", description = "41.59, 27.44", trackType = "quest_account", trackParams = { questID = 92301 }, max = 1, mapID = 2413, coordX = 41.59, coordY = 27.44 },
                        { label = "Moth #29", description = "36.11, 26.39", trackType = "quest_account", trackParams = { questID = 92197 }, max = 1, mapID = 2413, coordX = 36.11, coordY = 26.39 },
                        { label = "Moth #30", description = "40.44, 34.46", trackType = "quest_account", trackParams = { questID = 92300 }, max = 1, mapID = 2413, coordX = 40.44, coordY = 34.46 },
                        { label = "Moth #32", description = "47.63, 46.96", trackType = "quest_account", trackParams = { questID = 92231 }, max = 1, mapID = 2413, coordX = 47.63, coordY = 46.96 },
                        { label = "Moth #35", description = "52.93, 50.65", trackType = "quest_account", trackParams = { questID = 92214 }, max = 1, mapID = 2413, coordX = 52.93, coordY = 50.65 },
                        { label = "Moth #38", description = "53.76, 59.1", trackType = "quest_account", trackParams = { questID = 92229 }, max = 1, mapID = 2413, coordX = 53.76, coordY = 59.1 },
                        { label = "Moth #40", description = "59.44, 54.33", trackType = "quest_account", trackParams = { questID = 92206 }, max = 1, mapID = 2413, coordX = 59.44, coordY = 54.33 },
                        { label = "Moth #43", description = "60.34, 48.58", trackType = "quest_account", trackParams = { questID = 92209 }, max = 1, mapID = 2413, coordX = 60.34, coordY = 48.58 },
                        { label = "Moth #46", description = "59.98, 43.05", trackType = "quest_account", trackParams = { questID = 92305 }, max = 1, mapID = 2413, coordX = 59.98, coordY = 43.05 },
                        { label = "Moth #54", description = "56.58, 47.65", trackType = "quest_account", trackParams = { questID = 92299 }, max = 1, mapID = 2413, coordX = 56.58, coordY = 47.65 },
                        { label = "Moth #56", description = "50.63, 40.62", trackType = "quest_account", trackParams = { questID = 92302 }, max = 1, mapID = 2413, coordX = 50.63, coordY = 40.62 },
                        { label = "Moth #58", description = "62.34, 37.14", trackType = "quest_account", trackParams = { questID = 92226 }, max = 1, mapID = 2413, coordX = 62.34, coordY = 37.14 },
                        { label = "Moth #61", description = "69.03, 31.2", trackType = "quest_account", trackParams = { questID = 92304 }, max = 1, mapID = 2413, coordX = 69.03, coordY = 31.2 },
                        { label = "Moth #63", description = "65.43, 27.12", trackType = "quest_account", trackParams = { questID = 92303 }, max = 1, mapID = 2413, coordX = 65.43, coordY = 27.12 },
                        { label = "Moth #68", description = "68.69, 36.33", trackType = "quest_account", trackParams = { questID = 92233 }, max = 1, mapID = 2413, coordX = 68.69, coordY = 36.33 },
                        { label = "Moth #76", description = "71.38, 58.63", trackType = "quest_account", trackParams = { questID = 92215 }, max = 1, mapID = 2413, coordX = 71.38, coordY = 58.63 },
                        { label = "Moth #79", description = "66.3, 62.82", trackType = "quest_account", trackParams = { questID = 92200 }, max = 1, mapID = 2413, coordX = 66.3, coordY = 62.82 },
                        { label = "Moth #83", description = "66.96, 56.57", trackType = "quest_account", trackParams = { questID = 92228 }, max = 1, mapID = 2413, coordX = 66.96, coordY = 56.57 },
                        { label = "Moth #86", description = "67.73, 68.86", trackType = "quest_account", trackParams = { questID = 92306 }, max = 1, mapID = 2413, coordX = 67.73, coordY = 68.86 },
                        { label = "Moth #89", description = "50.26, 69.66", trackType = "quest_account", trackParams = { questID = 92234 }, max = 1, mapID = 2413, coordX = 50.26, coordY = 69.66 },
                        { label = "Moth #92", description = "49.26, 75.52", trackType = "quest_account", trackParams = { questID = 92235 }, max = 1, mapID = 2413, coordX = 49.26, coordY = 75.52 },
                        { label = "Moth #95", description = "52.41, 80.78", trackType = "quest_account", trackParams = { questID = 92205 }, max = 1, mapID = 2413, coordX = 52.41, coordY = 80.78 },
                        { label = "Moth #98", description = "42.19, 66.51", trackType = "quest_account", trackParams = { questID = 92204 }, max = 1, mapID = 2413, coordX = 42.19, coordY = 66.51 },
                        { label = "Moth #103", description = "32.06, 67.08", trackType = "quest_account", trackParams = { questID = 92213 }, max = 1, mapID = 2413, coordX = 32.06, coordY = 67.08 },
                        { label = "Moth #106", description = "30.31, 73.39", trackType = "quest_account", trackParams = { questID = 92211 }, max = 1, mapID = 2413, coordX = 30.31, coordY = 73.39 },
                        { label = "Moth #107", description = "33.37, 75.61", trackType = "quest_account", trackParams = { questID = 92202 }, max = 1, mapID = 2413, coordX = 33.37, coordY = 75.61 },
                        { label = "Moth #110", description = "31.84, 81.76", trackType = "quest_account", trackParams = { questID = 92203 }, max = 1, mapID = 2413, coordX = 31.84, coordY = 81.76 },
                        { label = "Moth #111", description = "32.62, 84.77", trackType = "quest_account", trackParams = { questID = 92212 }, max = 1, mapID = 2413, coordX = 32.62, coordY = 84.77 },
                        { label = "Moth #114", description = "33.37, 63.49", trackType = "quest_account", trackParams = { questID = 92201 }, max = 1, mapID = 2413, coordX = 33.37, coordY = 63.49 },
                        { label = "Moth #118", description = "43.21, 53.65", trackType = "quest_account", trackParams = { questID = 92210 }, max = 1, mapID = 2413, coordX = 43.21, coordY = 53.65 },
                        { label = "Moth #120", description = "48.54, 55.35", trackType = "quest_account", trackParams = { questID = 92307 }, max = 1, mapID = 2413, coordX = 48.54, coordY = 55.35 },
                    },
                },
                {
                    label = "Renown 4 (40 Moths)",
                    steps = {
                        { label = "Reach Harati Renown 4", description = "You must reach Renown 4 with the Harati to collect these moths", trackType = "renown", trackParams = { factionID = 2704, level = 4 }, max = 4 },
                        { label = "Moth #2", description = "36.97, 48.3", trackType = "quest_account", trackParams = { questID = 92256 }, max = 1, mapID = 2413, coordX = 36.97, coordY = 48.3 },
                        { label = "Moth #7", description = "43.06, 39.45", trackType = "quest_account", trackParams = { questID = 92224 }, max = 1, mapID = 2413, coordX = 43.06, coordY = 39.45 },
                        { label = "Moth #8", description = "43.26, 40.35", trackType = "quest_account", trackParams = { questID = 92242 }, max = 1, mapID = 2413, coordX = 43.26, coordY = 40.35 },
                        { label = "Moth #9", description = "44.02, 38.12", trackType = "quest_account", trackParams = { questID = 92223 }, max = 1, mapID = 2413, coordX = 44.02, coordY = 38.12 },
                        { label = "Moth #10", description = "41.95, 37.72", trackType = "quest_account", trackParams = { questID = 92241 }, max = 1, mapID = 2413, coordX = 41.95, coordY = 37.72 },
                        { label = "Moth #11", description = "44.78, 35.69", trackType = "quest_account", trackParams = { questID = 92236 }, max = 1, mapID = 2413, coordX = 44.78, coordY = 35.69 },
                        { label = "Moth #16", description = "58.67, 30.2", trackType = "quest_account", trackParams = { questID = 92238 }, max = 1, mapID = 2413, coordX = 58.67, coordY = 30.2 },
                        { label = "Moth #26", description = "42.19, 22.26", trackType = "quest_account", trackParams = { questID = 92259 }, max = 1, mapID = 2413, coordX = 42.19, coordY = 22.26 },
                        { label = "Moth #33", description = "46.86, 48.47", trackType = "quest_account", trackParams = { questID = 92243 }, max = 1, mapID = 2413, coordX = 46.86, coordY = 48.47 },
                        { label = "Moth #34", description = "48.27, 50.58", trackType = "quest_account", trackParams = { questID = 92251 }, max = 1, mapID = 2413, coordX = 48.27, coordY = 50.58 },
                        { label = "Moth #36", description = "54.49, 52.06", trackType = "quest_account", trackParams = { questID = 92258 }, max = 1, mapID = 2413, coordX = 54.49, coordY = 52.06 },
                        { label = "Moth #42", description = "61.24, 50.46", trackType = "quest_account", trackParams = { questID = 92252 }, max = 1, mapID = 2413, coordX = 61.24, coordY = 50.46 },
                        { label = "Moth #44", description = "60.72, 45.4", trackType = "quest_account", trackParams = { questID = 92253 }, max = 1, mapID = 2413, coordX = 60.72, coordY = 45.4 },
                        { label = "Moth #45", description = "62.49, 44.32", trackType = "quest_account", trackParams = { questID = 92254 }, max = 1, mapID = 2413, coordX = 62.49, coordY = 44.32 },
                        { label = "Moth #47", description = "62.43, 40.85", trackType = "quest_account", trackParams = { questID = 92245 }, max = 1, mapID = 2413, coordX = 62.43, coordY = 40.85 },
                        { label = "Moth #48", description = "63.74, 41.45", trackType = "quest_account", trackParams = { questID = 92216 }, max = 1, mapID = 2413, coordX = 63.74, coordY = 41.45 },
                        { label = "Moth #49", description = "65.89, 44.71", trackType = "quest_account", trackParams = { questID = 92261 }, max = 1, mapID = 2413, coordX = 65.89, coordY = 44.71 },
                        { label = "Moth #53", description = "63.99, 48.63", trackType = "quest_account", trackParams = { questID = 92262 }, max = 1, mapID = 2413, coordX = 63.99, coordY = 48.63 },
                        { label = "Moth #55", description = "54.49, 38.85", trackType = "quest_account", trackParams = { questID = 92255 }, max = 1, mapID = 2413, coordX = 54.49, coordY = 38.85 },
                        { label = "Moth #57", description = "61.42, 37.12", trackType = "quest_account", trackParams = { questID = 92244 }, max = 1, mapID = 2413, coordX = 61.42, coordY = 37.12 },
                        { label = "Moth #59", description = "61.28, 35.17", trackType = "quest_account", trackParams = { questID = 92217 }, max = 1, mapID = 2413, coordX = 61.28, coordY = 35.17 },
                        { label = "Moth #64", description = "67.97, 19.99", trackType = "quest_account", trackParams = { questID = 92257 }, max = 1, mapID = 2413, coordX = 67.97, coordY = 19.99 },
                        { label = "Moth #65", description = "60.34, 17.77", trackType = "quest_account", trackParams = { questID = 92222 }, max = 1, mapID = 2413, coordX = 60.34, coordY = 17.77 },
                        { label = "Moth #67", description = "51.38, 20.32", trackType = "quest_account", trackParams = { questID = 92237 }, max = 1, mapID = 2413, coordX = 51.38, coordY = 20.32 },
                        { label = "Moth #70", description = "72.87, 37.19", trackType = "quest_account", trackParams = { questID = 92260 }, max = 1, mapID = 2413, coordX = 72.87, coordY = 37.19 },
                        { label = "Moth #74", description = "74.0, 57.23", trackType = "quest_account", trackParams = { questID = 92220 }, max = 1, mapID = 2413, coordX = 74, coordY = 57.23 },
                        { label = "Moth #75", description = "71.71, 58.82", trackType = "quest_account", trackParams = { questID = 92221 }, max = 1, mapID = 2413, coordX = 71.71, coordY = 58.82 },
                        { label = "Moth #77", description = "73.71, 61.73", trackType = "quest_account", trackParams = { questID = 92240 }, max = 1, mapID = 2413, coordX = 73.71, coordY = 61.73 },
                        { label = "Moth #81", description = "62.49, 58.67", trackType = "quest_account", trackParams = { questID = 92263 }, max = 1, mapID = 2413, coordX = 62.49, coordY = 58.67 },
                        { label = "Moth #82", description = "65.3, 57.74", trackType = "quest_account", trackParams = { questID = 92264 }, max = 1, mapID = 2413, coordX = 65.3, coordY = 57.74 },
                        { label = "Moth #85", description = "73.71, 68.3", trackType = "quest_account", trackParams = { questID = 92239 }, max = 1, mapID = 2413, coordX = 73.71, coordY = 68.3 },
                        { label = "Moth #87", description = "55.79, 66.64", trackType = "quest_account", trackParams = { questID = 92218 }, max = 1, mapID = 2413, coordX = 55.79, coordY = 66.64 },
                        { label = "Moth #88", description = "55.61, 64.29", trackType = "quest_account", trackParams = { questID = 92219 }, max = 1, mapID = 2413, coordX = 55.61, coordY = 64.29 },
                        { label = "Moth #93", description = "51.88, 76.62", trackType = "quest_account", trackParams = { questID = 92250 }, max = 1, mapID = 2413, coordX = 51.88, coordY = 76.62 },
                        { label = "Moth #99", description = "41.34, 66.13", trackType = "quest_account", trackParams = { questID = 92246 }, max = 1, mapID = 2413, coordX = 41.34, coordY = 66.13 },
                        { label = "Moth #101", description = "41.34, 68.07", trackType = "quest_account", trackParams = { questID = 92265 }, max = 1, mapID = 2413, coordX = 41.34, coordY = 68.07 },
                        { label = "Moth #108", description = "35.89, 74.26", trackType = "quest_account", trackParams = { questID = 92247 }, max = 1, mapID = 2413, coordX = 35.89, coordY = 74.26 },
                        { label = "Moth #109", description = "36.09, 81.44", trackType = "quest_account", trackParams = { questID = 92249 }, max = 1, mapID = 2413, coordX = 36.09, coordY = 81.44 },
                        { label = "Moth #113", description = "30.8, 63.65", trackType = "quest_account", trackParams = { questID = 92248 }, max = 1, mapID = 2413, coordX = 30.8, coordY = 63.65 },
                        { label = "Moth #116", description = "39.09, 55.1", trackType = "quest_account", trackParams = { questID = 92266 }, max = 1, mapID = 2413, coordX = 39.09, coordY = 55.1 },
                    },
                },
                {
                    label = "Renown 9 (40 Moths)",
                    steps = {
                        { label = "Reach Harati Renown 9", description = "You must reach Renown 9 with the Harati to collect these moths", trackType = "renown", trackParams = { factionID = 2704, level = 9 }, max = 9 },
                        { label = "Moth #4", description = "34.61, 48.54", trackType = "quest_account", trackParams = { questID = 92295 }, max = 1, mapID = 2413, coordX = 34.61, coordY = 48.54 },
                        { label = "Moth #12", description = "47.73, 32.85", trackType = "quest_account", trackParams = { questID = 92268 }, max = 1, mapID = 2413, coordX = 47.73, coordY = 32.85 },
                        { label = "Moth #14", description = "54.54, 31.76", trackType = "quest_account", trackParams = { questID = 92270 }, max = 1, mapID = 2413, coordX = 54.54, coordY = 31.76 },
                        { label = "Moth #18", description = "52.42, 29.21", trackType = "quest_account", trackParams = { questID = 92269 }, max = 1, mapID = 2413, coordX = 52.42, coordY = 29.21 },
                        { label = "Moth #19", description = "48.49, 28.27", trackType = "quest_account", trackParams = { questID = 92283 }, max = 1, mapID = 2413, coordX = 48.49, coordY = 28.27 },
                        { label = "Moth #20", description = "48.55, 26.23", trackType = "quest_account", trackParams = { questID = 92293 }, max = 1, mapID = 2413, coordX = 48.55, coordY = 26.23 },
                        { label = "Moth #22", description = "47.76, 23.38", trackType = "quest_account", trackParams = { questID = 92284 }, max = 1, mapID = 2413, coordX = 47.76, coordY = 23.38 },
                        { label = "Moth #24", description = "43.18, 27.34", trackType = "quest_account", trackParams = { questID = 92278 }, max = 1, mapID = 2413, coordX = 43.18, coordY = 27.34 },
                        { label = "Moth #27", description = "39.21, 18.35", trackType = "quest_account", trackParams = { questID = 92297 }, max = 1, mapID = 2413, coordX = 39.21, coordY = 18.35 },
                        { label = "Moth #28", description = "34.63, 24.22", trackType = "quest_account", trackParams = { questID = 92285 }, max = 1, mapID = 2413, coordX = 34.63, coordY = 24.22 },
                        { label = "Moth #31", description = "44.43, 45.18", trackType = "quest_account", trackParams = { questID = 92286 }, max = 1, mapID = 2413, coordX = 44.43, coordY = 45.18 },
                        { label = "Moth #37", description = "53.01, 55.98", trackType = "quest_account", trackParams = { questID = 92277 }, max = 1, mapID = 2413, coordX = 53.01, coordY = 55.98 },
                        { label = "Moth #39", description = "56.58, 57.16", trackType = "quest_account", trackParams = { questID = 92309 }, max = 1, mapID = 2413, coordX = 56.58, coordY = 57.16 },
                        { label = "Moth #41", description = "62.51, 53.75", trackType = "quest_account", trackParams = { questID = 92311 }, max = 1, mapID = 2413, coordX = 62.51, coordY = 53.75 },
                        { label = "Moth #50", description = "67.04, 48.39", trackType = "quest_account", trackParams = { questID = 92272 }, max = 1, mapID = 2413, coordX = 67.04, coordY = 48.39 },
                        { label = "Moth #51", description = "69.44, 48.98", trackType = "quest_account", trackParams = { questID = 92315 }, max = 1, mapID = 2413, coordX = 69.44, coordY = 48.98 },
                        { label = "Moth #52", description = "65.14, 50.85", trackType = "quest_account", trackParams = { questID = 92289 }, max = 1, mapID = 2413, coordX = 65.14, coordY = 50.85 },
                        { label = "Moth #60", description = "66.5, 33.1", trackType = "quest_account", trackParams = { questID = 92279 }, max = 1, mapID = 2413, coordX = 66.5, coordY = 33.1 },
                        { label = "Moth #62", description = "68.25, 27.78", trackType = "quest_account", trackParams = { questID = 92281 }, max = 1, mapID = 2413, coordX = 68.25, coordY = 27.78 },
                        { label = "Moth #66", description = "56.02, 24.52", trackType = "quest_account", trackParams = { questID = 92282 }, max = 1, mapID = 2413, coordX = 56.02, coordY = 24.52 },
                        { label = "Moth #69", description = "71.17, 39.1", trackType = "quest_account", trackParams = { questID = 92271 }, max = 1, mapID = 2413, coordX = 71.17, coordY = 39.1 },
                        { label = "Moth #71", description = "72.04, 33.14", trackType = "quest_account", trackParams = { questID = 92280 }, max = 1, mapID = 2413, coordX = 72.04, coordY = 33.14 },
                        { label = "Moth #72", description = "75.83, 50.15", trackType = "quest_account", trackParams = { questID = 92316 }, max = 1, mapID = 2413, coordX = 75.83, coordY = 50.15 },
                        { label = "Moth #73", description = "74.09, 53.39", trackType = "quest_account", trackParams = { questID = 92310 }, max = 1, mapID = 2413, coordX = 74.09, coordY = 53.39 },
                        { label = "Moth #78", description = "69.35, 62.94", trackType = "quest_account", trackParams = { questID = 92292 }, max = 1, mapID = 2413, coordX = 69.35, coordY = 62.94 },
                        { label = "Moth #80", description = "62.57, 64.63", trackType = "quest_account", trackParams = { questID = 92290 }, max = 1, mapID = 2413, coordX = 62.57, coordY = 64.63 },
                        { label = "Moth #84", description = "71.73, 67.45", trackType = "quest_account", trackParams = { questID = 92291 }, max = 1, mapID = 2413, coordX = 71.73, coordY = 67.45 },
                        { label = "Moth #90", description = "49.04, 70.69", trackType = "quest_account", trackParams = { questID = 92294 }, max = 1, mapID = 2413, coordX = 49.04, coordY = 70.69 },
                        { label = "Moth #91", description = "46.1, 71.84", trackType = "quest_account", trackParams = { questID = 92276 }, max = 1, mapID = 2413, coordX = 46.1, coordY = 71.84 },
                        { label = "Moth #94", description = "50.1, 80.17", trackType = "quest_account", trackParams = { questID = 92275 }, max = 1, mapID = 2413, coordX = 50.1, coordY = 80.17 },
                        { label = "Moth #96", description = "54.0, 73.03", trackType = "quest_account", trackParams = { questID = 92274 }, max = 1, mapID = 2413, coordX = 54, coordY = 73.03 },
                        { label = "Moth #97", description = "47.24, 66.1", trackType = "quest_account", trackParams = { questID = 92267 }, max = 1, mapID = 2413, coordX = 47.24, coordY = 66.1 },
                        { label = "Moth #100", description = "41.06, 67.35", trackType = "quest_account", trackParams = { questID = 92314 }, max = 1, mapID = 2413, coordX = 41.06, coordY = 67.35 },
                        { label = "Moth #102", description = "34.48, 68.99", trackType = "quest_account", trackParams = { questID = 92296 }, max = 1, mapID = 2413, coordX = 34.48, coordY = 68.99 },
                        { label = "Moth #104", description = "28.83, 66.91", trackType = "quest_account", trackParams = { questID = 92312 }, max = 1, mapID = 2413, coordX = 28.83, coordY = 66.91 },
                        { label = "Moth #105", description = "27.39, 70.32", trackType = "quest_account", trackParams = { questID = 92287 }, max = 1, mapID = 2413, coordX = 27.39, coordY = 70.32 },
                        { label = "Moth #112", description = "29.84, 87.65", trackType = "quest_account", trackParams = { questID = 92288 }, max = 1, mapID = 2413, coordX = 29.84, coordY = 87.65 },
                        { label = "Moth #115", description = "39.36, 61.37", trackType = "quest_account", trackParams = { questID = 92308 }, max = 1, mapID = 2413, coordX = 39.36, coordY = 61.37 },
                        { label = "Moth #117", description = "40.88, 51.52", trackType = "quest_account", trackParams = { questID = 92313 }, max = 1, mapID = 2413, coordX = 40.88, coordY = 51.52 },
                        { label = "Moth #119", description = "45.01, 58.08", trackType = "quest_account", trackParams = { questID = 92273 }, max = 1, mapID = 2413, coordX = 45.01, coordY = 58.08 },
                    },
                },
            },
        },
    },
    {
        id = "bundled_midnight_routine",
        version = 4,
        data = {
            title = "Campaign Weekly Tracker: Midnight",
            description = "Comprehensive weekly checklist for Midnight expansion content. Tracks weekly quests, Great Vault, crests, hunts, delves, PvP, and renown.",
            listType = "weekly",
            category = "General",
            author = "OneWoW",
            sections = {
                {
                    label = "Weekly Quests",
                    steps = {
                        { label = "Abundance", trackType = "quest", trackParams = { questID = 89507 }, max = 1 },
                        { label = "Lost Legends", trackType = "quest", trackParams = { questID = 89268 }, max = 1 },
                        { label = "High Esteem", trackType = "quest", trackParams = { questID = 91629 }, max = 1 },
                        { label = "Favor of the Court", description = "Complete the Silvermoon Court favor quest", trackType = "quest", trackParams = { questID = 89289 }, max = 1 },
                        { label = "Saltheril's Soiree", trackType = "quest_pool", trackParams = { questIDs = { 93889, 91966 }, pick = 1 }, max = 1 },
                        { label = "Fortify Runestones", trackType = "quest_pool", trackParams = { questIDs = { 90575, 90576, 90574, 90573 }, pick = 1 }, max = 1 },
                        { label = "Stand Your Ground", trackType = "quest", trackParams = { questID = 94581 }, max = 1 },
                        { label = "Unity Against Void", description = "Complete via Delves, Dungeons, Raids, or PvP", trackType = "quest_pool", trackParams = { questIDs = { 93744, 93909, 93911, 93912, 93910 }, pick = 1 }, max = 1 },
                        { label = "Special Assignment", description = "Rotating weekly special assignment", trackType = "quest_pool", trackParams = { questIDs = { 91390, 91796, 92063, 92139, 92145, 93013, 93244, 93438 }, pick = 1 }, max = 1 },
                    },
                },
                {
                    label = "Great Vault",
                    steps = {
                        { label = "Raid: 2 Bosses", trackType = "vault_raid", max = 2 },
                        { label = "Raid: 4 Bosses", trackType = "vault_raid", max = 4 },
                        { label = "Raid: 6 Bosses", trackType = "vault_raid", max = 6 },
                        { label = "Dungeon: 1 Run", trackType = "vault_dungeon", max = 1 },
                        { label = "Dungeon: 4 Runs", trackType = "vault_dungeon", max = 4 },
                        { label = "Dungeon: 8 Runs", trackType = "vault_dungeon", max = 8 },
                        { label = "World: 2 Activities", trackType = "vault_world", max = 2 },
                        { label = "World: 4 Activities", trackType = "vault_world", max = 4 },
                        { label = "World: 8 Activities", trackType = "vault_world", max = 8 },
                    },
                },
                {
                    label = "Crests & Currencies",
                    steps = {
                        { label = "Adventurer Mistcrest", trackType = "currency", trackParams = { currencyID = 3442 }, max = 0, noMax = true },
                        { label = "Veteran Mistcrest", trackType = "currency", trackParams = { currencyID = 3443 }, max = 0, noMax = true },
                        { label = "Champion Mistcrest", trackType = "currency", trackParams = { currencyID = 3444 }, max = 0, noMax = true },
                        { label = "Hero Mistcrest", trackType = "currency", trackParams = { currencyID = 3445 }, max = 0, noMax = true },
                        { label = "Myth Mistcrest", trackType = "currency", trackParams = { currencyID = 3446 }, max = 0, noMax = true },
                        { label = "Coffer Key Shards", trackType = "currency", trackParams = { currencyID = 3310 }, max = 0, noMax = true },
                    },
                },
                {
                    label = "Prey System",
                    steps = {
                        { label = "Normal Hunts", description = "Complete 4 normal hunts", trackType = "quest_pool", trackParams = { questIDs = PREY_NORMAL_QUESTS, pick = 4 }, max = 4 },
                        { label = "Hard Hunts", description = "Complete 4 hard hunts", trackType = "quest_pool", trackParams = { questIDs = PREY_HARD_QUESTS, pick = 4 }, max = 4 },
                        { label = "Nightmare Hunts", description = "Complete 4 nightmare hunts", trackType = "quest_pool", trackParams = { questIDs = PREY_NIGHTMARE_QUESTS, pick = 4 }, max = 4 },
                        { label = "Remnants of Anguish", trackType = "currency", trackParams = { currencyID = 3392 }, max = 0, noMax = true },
                    },
                },
                {
                    label = "PvP Currencies",
                    steps = {
                        { label = "Honor", trackType = "currency", trackParams = { currencyID = 1792 }, max = 0, noMax = true },
                        { label = "Conquest", trackType = "currency", trackParams = { currencyID = 1602 }, max = 0, noMax = true },
                        { label = "Bloody Tokens", trackType = "currency", trackParams = { currencyID = 2123 }, max = 0, noMax = true },
                    },
                },
                {
                    label = "PvP Weeklies",
                    steps = {
                        { label = "Sparks of War", trackType = "quest_pool", trackParams = { questIDs = { 93424, 93425 }, pick = 1 }, max = 1 },
                        { label = "Preserving: Solo", trackType = "quest", trackParams = { questID = 80185 }, max = 1 },
                        { label = "Preserving: Skirmishes", trackType = "quest", trackParams = { questID = 80187 }, max = 1 },
                        { label = "Preserving: Arenas", trackType = "quest", trackParams = { questID = 80188 }, max = 1 },
                        { label = "Preserving: Battlegrounds", trackType = "quest", trackParams = { questID = 80184 }, max = 1 },
                    },
                },
                {
                    label = "Delves",
                    steps = {
                        { label = "Call to Delves", trackType = "quest", trackParams = { questID = 84776 }, max = 1 },
                        { label = "Midnight: Delves", description = "Spark-rewarding delve quest", trackType = "quest", trackParams = { questID = 93909 }, max = 1 },
                        { label = "Nullaeus Defeated", trackType = "quest", trackParams = { questID = 93525 }, max = 1 },
                    },
                },
                {
                    label = "Renown",
                    steps = {
                        { label = "Silvermoon Court", trackType = "renown", trackParams = { factionID = 2710, level = 20 }, max = 20 },
                        { label = "Amani Tribe", trackType = "renown", trackParams = { factionID = 2696, level = 20 }, max = 20 },
                        { label = "Hara'ti", trackType = "renown", trackParams = { factionID = 2704, level = 20 }, max = 20 },
                        { label = "The Singularity", trackType = "renown", trackParams = { factionID = 2699, level = 20 }, max = 20 },
                    },
                },
            },
        },
    },
}

function TP:LoadBundledContent()
    local TD = ns.TrackerData
    if not TD then return end

    local db = ns.db
    local versions = db.global.trackerBundledVersions
    local deleted = db.global.trackerBundledDeleted

    for _, bundled in ipairs(BUNDLED_GUIDES) do
        if not deleted[bundled.id] then
            local existing = nil
            local lists = TD:GetListsDB()
            for _, list in pairs(lists) do
                if list._bundledID == bundled.id then
                    existing = list
                    break
                end
            end

            local currentVer = versions[bundled.id] or 0
            local missing = not existing
            local outdated = existing and bundled.version > currentVer
            if missing or outdated then
                if existing then
                    TD:RemoveList(existing.id)
                end

                local list = nil
                if bundled.data then
                    list = TD:CreateListFromParsed(bundled.data)
                elseif bundled.importString then
                    list = TD:ImportList(bundled.importString)
                end

                if list then
                    list._bundledID = bundled.id
                    list.author = bundled.data and bundled.data.author or list.author or "OneWoW"
                    versions[bundled.id] = bundled.version
                end
            end
        end
    end
end

function TP:OnBundledDeleted(bundledID)
    ns.db.global.trackerBundledDeleted[bundledID] = true
end

function TP:RestoreBundledContent()
    local db = ns.db
    wipe(db.global.trackerBundledVersions)
    wipe(db.global.trackerBundledDeleted)
    self:LoadBundledContent()
end
