local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.TrackerPresets = {}
local TP = ns.TrackerPresets

local tinsert = tinsert

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
        category = "Weeklies",
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
        category = "Weeklies",
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
        id = "prey_system",
        label = "Prey System",
        listType = "weekly",
        category = "Weeklies",
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
        category = "Dailies",
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
            local list = TD:CreateList({
                title = preset.label,
                listType = preset.listType,
                category = preset.category or "General",
            })
            if not list then return nil end

            for _, secData in ipairs(preset.sections) do
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
        category = "Professions",
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
                            description = "Use the Preset button to quickly add common tracking setups: Great Vault, Renown, Professions, Weeklies, and more.",
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
        version = 1,
        importString = [==[OWT1:{["t"]="Dusting for Moths - Collection Tracker",["d"]="Track all 120 Glowing Moths for the Dusting for Moths achievement. Auto-tracks warband-wide completion. Click any moth to set a waypoint. Renown gates show if you have unlocked each tier.",["a"]="OneWoW",["v"]=1,["lt"]="guide",["c"]="Collections",["s"]={{["l"]="Renown 1 (40 Moths)",["st"]={{["l"]="Reach Harati Renown 1",["d"]="You must reach Renown 1 with the Harati to collect these moths",["tt"]="renown",["tp"]={["factionID"]=2704,["level"]=1},["m"]=1,["ob"]={}},{["l"]="Moth #1",["d"]="36.35, 48.39",["tt"]="quest_account",["tp"]={["questID"]=92196},["m"]=1,["mi"]=2413,["cx"]=36.35,["cy"]=48.39,["ob"]={}},{["l"]="Moth #3",["d"]="38.33, 47.44",["tt"]="quest_account",["tp"]={["questID"]=92207},["m"]=1,["mi"]=2413,["cx"]=38.33,["cy"]=47.44,["ob"]={}},{["l"]="Moth #5",["d"]="33.95, 44.04",["tt"]="quest_account",["tp"]={["questID"]=92208},["m"]=1,["mi"]=2413,["cx"]=33.95,["cy"]=44.04,["ob"]={}},{["l"]="Moth #6",["d"]="41.61, 40.12",["tt"]="quest_account",["tp"]={["questID"]=92230},["m"]=1,["mi"]=2413,["cx"]=41.61,["cy"]=40.12,["ob"]={}},{["l"]="Moth #13",["d"]="50.35, 33.6",["tt"]="quest_account",["tp"]={["questID"]=92232},["m"]=1,["mi"]=2413,["cx"]=50.35,["cy"]=33.6,["ob"]={}},{["l"]="Moth #15",["d"]="55.14, 32.88",["tt"]="quest_account",["tp"]={["questID"]=92227},["m"]=1,["mi"]=2413,["cx"]=55.14,["cy"]=32.88,["ob"]={}},{["l"]="Moth #17",["d"]="55.0, 27.55",["tt"]="quest_account",["tp"]={["questID"]=92199},["m"]=1,["mi"]=2413,["cx"]=55.0,["cy"]=27.55,["ob"]={}},{["l"]="Moth #21",["d"]="49.88, 25.51",["tt"]="quest_account",["tp"]={["questID"]=92198},["m"]=1,["mi"]=2413,["cx"]=49.88,["cy"]=25.51,["ob"]={}},{["l"]="Moth #23",["d"]="46.38, 24.88",["tt"]="quest_account",["tp"]={["questID"]=92225},["m"]=1,["mi"]=2413,["cx"]=46.38,["cy"]=24.88,["ob"]={}},{["l"]="Moth #25",["d"]="41.59, 27.44",["tt"]="quest_account",["tp"]={["questID"]=92301},["m"]=1,["mi"]=2413,["cx"]=41.59,["cy"]=27.44,["ob"]={}},{["l"]="Moth #29",["d"]="36.11, 26.39",["tt"]="quest_account",["tp"]={["questID"]=92197},["m"]=1,["mi"]=2413,["cx"]=36.11,["cy"]=26.39,["ob"]={}},{["l"]="Moth #30",["d"]="40.44, 34.46",["tt"]="quest_account",["tp"]={["questID"]=92300},["m"]=1,["mi"]=2413,["cx"]=40.44,["cy"]=34.46,["ob"]={}},{["l"]="Moth #32",["d"]="47.63, 46.96",["tt"]="quest_account",["tp"]={["questID"]=92231},["m"]=1,["mi"]=2413,["cx"]=47.63,["cy"]=46.96,["ob"]={}},{["l"]="Moth #35",["d"]="52.93, 50.65",["tt"]="quest_account",["tp"]={["questID"]=92214},["m"]=1,["mi"]=2413,["cx"]=52.93,["cy"]=50.65,["ob"]={}},{["l"]="Moth #38",["d"]="53.76, 59.1",["tt"]="quest_account",["tp"]={["questID"]=92229},["m"]=1,["mi"]=2413,["cx"]=53.76,["cy"]=59.1,["ob"]={}},{["l"]="Moth #40",["d"]="59.44, 54.33",["tt"]="quest_account",["tp"]={["questID"]=92206},["m"]=1,["mi"]=2413,["cx"]=59.44,["cy"]=54.33,["ob"]={}},{["l"]="Moth #43",["d"]="60.34, 48.58",["tt"]="quest_account",["tp"]={["questID"]=92209},["m"]=1,["mi"]=2413,["cx"]=60.34,["cy"]=48.58,["ob"]={}},{["l"]="Moth #46",["d"]="59.98, 43.05",["tt"]="quest_account",["tp"]={["questID"]=92305},["m"]=1,["mi"]=2413,["cx"]=59.98,["cy"]=43.05,["ob"]={}},{["l"]="Moth #54",["d"]="56.58, 47.65",["tt"]="quest_account",["tp"]={["questID"]=92299},["m"]=1,["mi"]=2413,["cx"]=56.58,["cy"]=47.65,["ob"]={}},{["l"]="Moth #56",["d"]="50.63, 40.62",["tt"]="quest_account",["tp"]={["questID"]=92302},["m"]=1,["mi"]=2413,["cx"]=50.63,["cy"]=40.62,["ob"]={}},{["l"]="Moth #58",["d"]="62.34, 37.14",["tt"]="quest_account",["tp"]={["questID"]=92226},["m"]=1,["mi"]=2413,["cx"]=62.34,["cy"]=37.14,["ob"]={}},{["l"]="Moth #61",["d"]="69.03, 31.2",["tt"]="quest_account",["tp"]={["questID"]=92304},["m"]=1,["mi"]=2413,["cx"]=69.03,["cy"]=31.2,["ob"]={}},{["l"]="Moth #63",["d"]="65.43, 27.12",["tt"]="quest_account",["tp"]={["questID"]=92303},["m"]=1,["mi"]=2413,["cx"]=65.43,["cy"]=27.12,["ob"]={}},{["l"]="Moth #68",["d"]="68.69, 36.33",["tt"]="quest_account",["tp"]={["questID"]=92233},["m"]=1,["mi"]=2413,["cx"]=68.69,["cy"]=36.33,["ob"]={}},{["l"]="Moth #76",["d"]="71.38, 58.63",["tt"]="quest_account",["tp"]={["questID"]=92215},["m"]=1,["mi"]=2413,["cx"]=71.38,["cy"]=58.63,["ob"]={}},{["l"]="Moth #79",["d"]="66.3, 62.82",["tt"]="quest_account",["tp"]={["questID"]=92200},["m"]=1,["mi"]=2413,["cx"]=66.3,["cy"]=62.82,["ob"]={}},{["l"]="Moth #83",["d"]="66.96, 56.57",["tt"]="quest_account",["tp"]={["questID"]=92228},["m"]=1,["mi"]=2413,["cx"]=66.96,["cy"]=56.57,["ob"]={}},{["l"]="Moth #86",["d"]="67.73, 68.86",["tt"]="quest_account",["tp"]={["questID"]=92306},["m"]=1,["mi"]=2413,["cx"]=67.73,["cy"]=68.86,["ob"]={}},{["l"]="Moth #89",["d"]="50.26, 69.66",["tt"]="quest_account",["tp"]={["questID"]=92234},["m"]=1,["mi"]=2413,["cx"]=50.26,["cy"]=69.66,["ob"]={}},{["l"]="Moth #92",["d"]="49.26, 75.52",["tt"]="quest_account",["tp"]={["questID"]=92235},["m"]=1,["mi"]=2413,["cx"]=49.26,["cy"]=75.52,["ob"]={}},{["l"]="Moth #95",["d"]="52.41, 80.78",["tt"]="quest_account",["tp"]={["questID"]=92205},["m"]=1,["mi"]=2413,["cx"]=52.41,["cy"]=80.78,["ob"]={}},{["l"]="Moth #98",["d"]="42.19, 66.51",["tt"]="quest_account",["tp"]={["questID"]=92204},["m"]=1,["mi"]=2413,["cx"]=42.19,["cy"]=66.51,["ob"]={}},{["l"]="Moth #103",["d"]="32.06, 67.08",["tt"]="quest_account",["tp"]={["questID"]=92213},["m"]=1,["mi"]=2413,["cx"]=32.06,["cy"]=67.08,["ob"]={}},{["l"]="Moth #106",["d"]="30.31, 73.39",["tt"]="quest_account",["tp"]={["questID"]=92211},["m"]=1,["mi"]=2413,["cx"]=30.31,["cy"]=73.39,["ob"]={}},{["l"]="Moth #107",["d"]="33.37, 75.61",["tt"]="quest_account",["tp"]={["questID"]=92202},["m"]=1,["mi"]=2413,["cx"]=33.37,["cy"]=75.61,["ob"]={}},{["l"]="Moth #110",["d"]="31.84, 81.76",["tt"]="quest_account",["tp"]={["questID"]=92203},["m"]=1,["mi"]=2413,["cx"]=31.84,["cy"]=81.76,["ob"]={}},{["l"]="Moth #111",["d"]="32.62, 84.77",["tt"]="quest_account",["tp"]={["questID"]=92212},["m"]=1,["mi"]=2413,["cx"]=32.62,["cy"]=84.77,["ob"]={}},{["l"]="Moth #114",["d"]="33.37, 63.49",["tt"]="quest_account",["tp"]={["questID"]=92201},["m"]=1,["mi"]=2413,["cx"]=33.37,["cy"]=63.49,["ob"]={}},{["l"]="Moth #118",["d"]="43.21, 53.65",["tt"]="quest_account",["tp"]={["questID"]=92210},["m"]=1,["mi"]=2413,["cx"]=43.21,["cy"]=53.65,["ob"]={}},{["l"]="Moth #120",["d"]="48.54, 55.35",["tt"]="quest_account",["tp"]={["questID"]=92307},["m"]=1,["mi"]=2413,["cx"]=48.54,["cy"]=55.35,["ob"]={}}}},{["l"]="Renown 4 (40 Moths)",["st"]={{["l"]="Reach Harati Renown 4",["d"]="You must reach Renown 4 with the Harati to collect these moths",["tt"]="renown",["tp"]={["factionID"]=2704,["level"]=4},["m"]=4,["ob"]={}},{["l"]="Moth #2",["d"]="36.97, 48.3",["tt"]="quest_account",["tp"]={["questID"]=92256},["m"]=1,["mi"]=2413,["cx"]=36.97,["cy"]=48.3,["ob"]={}},{["l"]="Moth #7",["d"]="43.06, 39.45",["tt"]="quest_account",["tp"]={["questID"]=92224},["m"]=1,["mi"]=2413,["cx"]=43.06,["cy"]=39.45,["ob"]={}},{["l"]="Moth #8",["d"]="43.26, 40.35",["tt"]="quest_account",["tp"]={["questID"]=92242},["m"]=1,["mi"]=2413,["cx"]=43.26,["cy"]=40.35,["ob"]={}},{["l"]="Moth #9",["d"]="44.02, 38.12",["tt"]="quest_account",["tp"]={["questID"]=92223},["m"]=1,["mi"]=2413,["cx"]=44.02,["cy"]=38.12,["ob"]={}},{["l"]="Moth #10",["d"]="41.95, 37.72",["tt"]="quest_account",["tp"]={["questID"]=92241},["m"]=1,["mi"]=2413,["cx"]=41.95,["cy"]=37.72,["ob"]={}},{["l"]="Moth #11",["d"]="44.78, 35.69",["tt"]="quest_account",["tp"]={["questID"]=92236},["m"]=1,["mi"]=2413,["cx"]=44.78,["cy"]=35.69,["ob"]={}},{["l"]="Moth #16",["d"]="58.67, 30.2",["tt"]="quest_account",["tp"]={["questID"]=92238},["m"]=1,["mi"]=2413,["cx"]=58.67,["cy"]=30.2,["ob"]={}},{["l"]="Moth #26",["d"]="42.19, 22.26",["tt"]="quest_account",["tp"]={["questID"]=92259},["m"]=1,["mi"]=2413,["cx"]=42.19,["cy"]=22.26,["ob"]={}},{["l"]="Moth #33",["d"]="46.86, 48.47",["tt"]="quest_account",["tp"]={["questID"]=92243},["m"]=1,["mi"]=2413,["cx"]=46.86,["cy"]=48.47,["ob"]={}},{["l"]="Moth #34",["d"]="48.27, 50.58",["tt"]="quest_account",["tp"]={["questID"]=92251},["m"]=1,["mi"]=2413,["cx"]=48.27,["cy"]=50.58,["ob"]={}},{["l"]="Moth #36",["d"]="54.49, 52.06",["tt"]="quest_account",["tp"]={["questID"]=92258},["m"]=1,["mi"]=2413,["cx"]=54.49,["cy"]=52.06,["ob"]={}},{["l"]="Moth #42",["d"]="61.24, 50.46",["tt"]="quest_account",["tp"]={["questID"]=92252},["m"]=1,["mi"]=2413,["cx"]=61.24,["cy"]=50.46,["ob"]={}},{["l"]="Moth #44",["d"]="60.72, 45.4",["tt"]="quest_account",["tp"]={["questID"]=92253},["m"]=1,["mi"]=2413,["cx"]=60.72,["cy"]=45.4,["ob"]={}},{["l"]="Moth #45",["d"]="62.49, 44.32",["tt"]="quest_account",["tp"]={["questID"]=92254},["m"]=1,["mi"]=2413,["cx"]=62.49,["cy"]=44.32,["ob"]={}},{["l"]="Moth #47",["d"]="62.43, 40.85",["tt"]="quest_account",["tp"]={["questID"]=92245},["m"]=1,["mi"]=2413,["cx"]=62.43,["cy"]=40.85,["ob"]={}},{["l"]="Moth #48",["d"]="63.74, 41.45",["tt"]="quest_account",["tp"]={["questID"]=92216},["m"]=1,["mi"]=2413,["cx"]=63.74,["cy"]=41.45,["ob"]={}},{["l"]="Moth #49",["d"]="65.89, 44.71",["tt"]="quest_account",["tp"]={["questID"]=92261},["m"]=1,["mi"]=2413,["cx"]=65.89,["cy"]=44.71,["ob"]={}},{["l"]="Moth #53",["d"]="63.99, 48.63",["tt"]="quest_account",["tp"]={["questID"]=92262},["m"]=1,["mi"]=2413,["cx"]=63.99,["cy"]=48.63,["ob"]={}},{["l"]="Moth #55",["d"]="54.49, 38.85",["tt"]="quest_account",["tp"]={["questID"]=92255},["m"]=1,["mi"]=2413,["cx"]=54.49,["cy"]=38.85,["ob"]={}},{["l"]="Moth #57",["d"]="61.42, 37.12",["tt"]="quest_account",["tp"]={["questID"]=92244},["m"]=1,["mi"]=2413,["cx"]=61.42,["cy"]=37.12,["ob"]={}},{["l"]="Moth #59",["d"]="61.28, 35.17",["tt"]="quest_account",["tp"]={["questID"]=92217},["m"]=1,["mi"]=2413,["cx"]=61.28,["cy"]=35.17,["ob"]={}},{["l"]="Moth #64",["d"]="67.97, 19.99",["tt"]="quest_account",["tp"]={["questID"]=92257},["m"]=1,["mi"]=2413,["cx"]=67.97,["cy"]=19.99,["ob"]={}},{["l"]="Moth #65",["d"]="60.34, 17.77",["tt"]="quest_account",["tp"]={["questID"]=92222},["m"]=1,["mi"]=2413,["cx"]=60.34,["cy"]=17.77,["ob"]={}},{["l"]="Moth #67",["d"]="51.38, 20.32",["tt"]="quest_account",["tp"]={["questID"]=92237},["m"]=1,["mi"]=2413,["cx"]=51.38,["cy"]=20.32,["ob"]={}},{["l"]="Moth #70",["d"]="72.87, 37.19",["tt"]="quest_account",["tp"]={["questID"]=92260},["m"]=1,["mi"]=2413,["cx"]=72.87,["cy"]=37.19,["ob"]={}},{["l"]="Moth #74",["d"]="74.0, 57.23",["tt"]="quest_account",["tp"]={["questID"]=92220},["m"]=1,["mi"]=2413,["cx"]=74.0,["cy"]=57.23,["ob"]={}},{["l"]="Moth #75",["d"]="71.71, 58.82",["tt"]="quest_account",["tp"]={["questID"]=92221},["m"]=1,["mi"]=2413,["cx"]=71.71,["cy"]=58.82,["ob"]={}},{["l"]="Moth #77",["d"]="73.71, 61.73",["tt"]="quest_account",["tp"]={["questID"]=92240},["m"]=1,["mi"]=2413,["cx"]=73.71,["cy"]=61.73,["ob"]={}},{["l"]="Moth #81",["d"]="62.49, 58.67",["tt"]="quest_account",["tp"]={["questID"]=92263},["m"]=1,["mi"]=2413,["cx"]=62.49,["cy"]=58.67,["ob"]={}},{["l"]="Moth #82",["d"]="65.3, 57.74",["tt"]="quest_account",["tp"]={["questID"]=92264},["m"]=1,["mi"]=2413,["cx"]=65.3,["cy"]=57.74,["ob"]={}},{["l"]="Moth #85",["d"]="73.71, 68.3",["tt"]="quest_account",["tp"]={["questID"]=92239},["m"]=1,["mi"]=2413,["cx"]=73.71,["cy"]=68.3,["ob"]={}},{["l"]="Moth #87",["d"]="55.79, 66.64",["tt"]="quest_account",["tp"]={["questID"]=92218},["m"]=1,["mi"]=2413,["cx"]=55.79,["cy"]=66.64,["ob"]={}},{["l"]="Moth #88",["d"]="55.61, 64.29",["tt"]="quest_account",["tp"]={["questID"]=92219},["m"]=1,["mi"]=2413,["cx"]=55.61,["cy"]=64.29,["ob"]={}},{["l"]="Moth #93",["d"]="51.88, 76.62",["tt"]="quest_account",["tp"]={["questID"]=92250},["m"]=1,["mi"]=2413,["cx"]=51.88,["cy"]=76.62,["ob"]={}},{["l"]="Moth #99",["d"]="41.34, 66.13",["tt"]="quest_account",["tp"]={["questID"]=92246},["m"]=1,["mi"]=2413,["cx"]=41.34,["cy"]=66.13,["ob"]={}},{["l"]="Moth #101",["d"]="41.34, 68.07",["tt"]="quest_account",["tp"]={["questID"]=92265},["m"]=1,["mi"]=2413,["cx"]=41.34,["cy"]=68.07,["ob"]={}},{["l"]="Moth #108",["d"]="35.89, 74.26",["tt"]="quest_account",["tp"]={["questID"]=92247},["m"]=1,["mi"]=2413,["cx"]=35.89,["cy"]=74.26,["ob"]={}},{["l"]="Moth #109",["d"]="36.09, 81.44",["tt"]="quest_account",["tp"]={["questID"]=92249},["m"]=1,["mi"]=2413,["cx"]=36.09,["cy"]=81.44,["ob"]={}},{["l"]="Moth #113",["d"]="30.8, 63.65",["tt"]="quest_account",["tp"]={["questID"]=92248},["m"]=1,["mi"]=2413,["cx"]=30.8,["cy"]=63.65,["ob"]={}},{["l"]="Moth #116",["d"]="39.09, 55.1",["tt"]="quest_account",["tp"]={["questID"]=92266},["m"]=1,["mi"]=2413,["cx"]=39.09,["cy"]=55.1,["ob"]={}}}},{["l"]="Renown 9 (40 Moths)",["st"]={{["l"]="Reach Harati Renown 9",["d"]="You must reach Renown 9 with the Harati to collect these moths",["tt"]="renown",["tp"]={["factionID"]=2704,["level"]=9},["m"]=9,["ob"]={}},{["l"]="Moth #4",["d"]="34.61, 48.54",["tt"]="quest_account",["tp"]={["questID"]=92295},["m"]=1,["mi"]=2413,["cx"]=34.61,["cy"]=48.54,["ob"]={}},{["l"]="Moth #12",["d"]="47.73, 32.85",["tt"]="quest_account",["tp"]={["questID"]=92268},["m"]=1,["mi"]=2413,["cx"]=47.73,["cy"]=32.85,["ob"]={}},{["l"]="Moth #14",["d"]="54.54, 31.76",["tt"]="quest_account",["tp"]={["questID"]=92270},["m"]=1,["mi"]=2413,["cx"]=54.54,["cy"]=31.76,["ob"]={}},{["l"]="Moth #18",["d"]="52.42, 29.21",["tt"]="quest_account",["tp"]={["questID"]=92269},["m"]=1,["mi"]=2413,["cx"]=52.42,["cy"]=29.21,["ob"]={}},{["l"]="Moth #19",["d"]="48.49, 28.27",["tt"]="quest_account",["tp"]={["questID"]=92283},["m"]=1,["mi"]=2413,["cx"]=48.49,["cy"]=28.27,["ob"]={}},{["l"]="Moth #20",["d"]="48.55, 26.23",["tt"]="quest_account",["tp"]={["questID"]=92293},["m"]=1,["mi"]=2413,["cx"]=48.55,["cy"]=26.23,["ob"]={}},{["l"]="Moth #22",["d"]="47.76, 23.38",["tt"]="quest_account",["tp"]={["questID"]=92284},["m"]=1,["mi"]=2413,["cx"]=47.76,["cy"]=23.38,["ob"]={}},{["l"]="Moth #24",["d"]="43.18, 27.34",["tt"]="quest_account",["tp"]={["questID"]=92278},["m"]=1,["mi"]=2413,["cx"]=43.18,["cy"]=27.34,["ob"]={}},{["l"]="Moth #27",["d"]="39.21, 18.35",["tt"]="quest_account",["tp"]={["questID"]=92297},["m"]=1,["mi"]=2413,["cx"]=39.21,["cy"]=18.35,["ob"]={}},{["l"]="Moth #28",["d"]="34.63, 24.22",["tt"]="quest_account",["tp"]={["questID"]=92285},["m"]=1,["mi"]=2413,["cx"]=34.63,["cy"]=24.22,["ob"]={}},{["l"]="Moth #31",["d"]="44.43, 45.18",["tt"]="quest_account",["tp"]={["questID"]=92286},["m"]=1,["mi"]=2413,["cx"]=44.43,["cy"]=45.18,["ob"]={}},{["l"]="Moth #37",["d"]="53.01, 55.98",["tt"]="quest_account",["tp"]={["questID"]=92277},["m"]=1,["mi"]=2413,["cx"]=53.01,["cy"]=55.98,["ob"]={}},{["l"]="Moth #39",["d"]="56.58, 57.16",["tt"]="quest_account",["tp"]={["questID"]=92309},["m"]=1,["mi"]=2413,["cx"]=56.58,["cy"]=57.16,["ob"]={}},{["l"]="Moth #41",["d"]="62.51, 53.75",["tt"]="quest_account",["tp"]={["questID"]=92311},["m"]=1,["mi"]=2413,["cx"]=62.51,["cy"]=53.75,["ob"]={}},{["l"]="Moth #50",["d"]="67.04, 48.39",["tt"]="quest_account",["tp"]={["questID"]=92272},["m"]=1,["mi"]=2413,["cx"]=67.04,["cy"]=48.39,["ob"]={}},{["l"]="Moth #51",["d"]="69.44, 48.98",["tt"]="quest_account",["tp"]={["questID"]=92315},["m"]=1,["mi"]=2413,["cx"]=69.44,["cy"]=48.98,["ob"]={}},{["l"]="Moth #52",["d"]="65.14, 50.85",["tt"]="quest_account",["tp"]={["questID"]=92289},["m"]=1,["mi"]=2413,["cx"]=65.14,["cy"]=50.85,["ob"]={}},{["l"]="Moth #60",["d"]="66.5, 33.1",["tt"]="quest_account",["tp"]={["questID"]=92279},["m"]=1,["mi"]=2413,["cx"]=66.5,["cy"]=33.1,["ob"]={}},{["l"]="Moth #62",["d"]="68.25, 27.78",["tt"]="quest_account",["tp"]={["questID"]=92281},["m"]=1,["mi"]=2413,["cx"]=68.25,["cy"]=27.78,["ob"]={}},{["l"]="Moth #66",["d"]="56.02, 24.52",["tt"]="quest_account",["tp"]={["questID"]=92282},["m"]=1,["mi"]=2413,["cx"]=56.02,["cy"]=24.52,["ob"]={}},{["l"]="Moth #69",["d"]="71.17, 39.1",["tt"]="quest_account",["tp"]={["questID"]=92271},["m"]=1,["mi"]=2413,["cx"]=71.17,["cy"]=39.1,["ob"]={}},{["l"]="Moth #71",["d"]="72.04, 33.14",["tt"]="quest_account",["tp"]={["questID"]=92280},["m"]=1,["mi"]=2413,["cx"]=72.04,["cy"]=33.14,["ob"]={}},{["l"]="Moth #72",["d"]="75.83, 50.15",["tt"]="quest_account",["tp"]={["questID"]=92316},["m"]=1,["mi"]=2413,["cx"]=75.83,["cy"]=50.15,["ob"]={}},{["l"]="Moth #73",["d"]="74.09, 53.39",["tt"]="quest_account",["tp"]={["questID"]=92310},["m"]=1,["mi"]=2413,["cx"]=74.09,["cy"]=53.39,["ob"]={}},{["l"]="Moth #78",["d"]="69.35, 62.94",["tt"]="quest_account",["tp"]={["questID"]=92292},["m"]=1,["mi"]=2413,["cx"]=69.35,["cy"]=62.94,["ob"]={}},{["l"]="Moth #80",["d"]="62.57, 64.63",["tt"]="quest_account",["tp"]={["questID"]=92290},["m"]=1,["mi"]=2413,["cx"]=62.57,["cy"]=64.63,["ob"]={}},{["l"]="Moth #84",["d"]="71.73, 67.45",["tt"]="quest_account",["tp"]={["questID"]=92291},["m"]=1,["mi"]=2413,["cx"]=71.73,["cy"]=67.45,["ob"]={}},{["l"]="Moth #90",["d"]="49.04, 70.69",["tt"]="quest_account",["tp"]={["questID"]=92294},["m"]=1,["mi"]=2413,["cx"]=49.04,["cy"]=70.69,["ob"]={}},{["l"]="Moth #91",["d"]="46.1, 71.84",["tt"]="quest_account",["tp"]={["questID"]=92276},["m"]=1,["mi"]=2413,["cx"]=46.1,["cy"]=71.84,["ob"]={}},{["l"]="Moth #94",["d"]="50.1, 80.17",["tt"]="quest_account",["tp"]={["questID"]=92275},["m"]=1,["mi"]=2413,["cx"]=50.1,["cy"]=80.17,["ob"]={}},{["l"]="Moth #96",["d"]="54.0, 73.03",["tt"]="quest_account",["tp"]={["questID"]=92274},["m"]=1,["mi"]=2413,["cx"]=54.0,["cy"]=73.03,["ob"]={}},{["l"]="Moth #97",["d"]="47.24, 66.1",["tt"]="quest_account",["tp"]={["questID"]=92267},["m"]=1,["mi"]=2413,["cx"]=47.24,["cy"]=66.1,["ob"]={}},{["l"]="Moth #100",["d"]="41.06, 67.35",["tt"]="quest_account",["tp"]={["questID"]=92314},["m"]=1,["mi"]=2413,["cx"]=41.06,["cy"]=67.35,["ob"]={}},{["l"]="Moth #102",["d"]="34.48, 68.99",["tt"]="quest_account",["tp"]={["questID"]=92296},["m"]=1,["mi"]=2413,["cx"]=34.48,["cy"]=68.99,["ob"]={}},{["l"]="Moth #104",["d"]="28.83, 66.91",["tt"]="quest_account",["tp"]={["questID"]=92312},["m"]=1,["mi"]=2413,["cx"]=28.83,["cy"]=66.91,["ob"]={}},{["l"]="Moth #105",["d"]="27.39, 70.32",["tt"]="quest_account",["tp"]={["questID"]=92287},["m"]=1,["mi"]=2413,["cx"]=27.39,["cy"]=70.32,["ob"]={}},{["l"]="Moth #112",["d"]="29.84, 87.65",["tt"]="quest_account",["tp"]={["questID"]=92288},["m"]=1,["mi"]=2413,["cx"]=29.84,["cy"]=87.65,["ob"]={}},{["l"]="Moth #115",["d"]="39.36, 61.37",["tt"]="quest_account",["tp"]={["questID"]=92308},["m"]=1,["mi"]=2413,["cx"]=39.36,["cy"]=61.37,["ob"]={}},{["l"]="Moth #117",["d"]="40.88, 51.52",["tt"]="quest_account",["tp"]={["questID"]=92313},["m"]=1,["mi"]=2413,["cx"]=40.88,["cy"]=51.52,["ob"]={}},{["l"]="Moth #119",["d"]="45.01, 58.08",["tt"]="quest_account",["tp"]={["questID"]=92273},["m"]=1,["mi"]=2413,["cx"]=45.01,["cy"]=58.08,["ob"]={}}}}}]==],
    },
    {
        id = "bundled_midnight_routine",
        version = 1,
        data = {
            title = "Midnight Weekly Routine",
            description = "Comprehensive weekly checklist for Midnight expansion content. Tracks weekly quests, Great Vault, crests, hunts, delves, PvP, and renown.",
            listType = "weekly",
            category = "Weeklies",
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
                        { label = "Adventurer Dawncrest", trackType = "currency", trackParams = { currencyID = 3383 }, max = 0, noMax = true },
                        { label = "Veteran Dawncrest", trackType = "currency", trackParams = { currencyID = 3341 }, max = 0, noMax = true },
                        { label = "Champion Dawncrest", trackType = "currency", trackParams = { currencyID = 3343 }, max = 0, noMax = true },
                        { label = "Hero Dawncrest", trackType = "currency", trackParams = { currencyID = 3345 }, max = 0, noMax = true },
                        { label = "Myth Dawncrest", trackType = "currency", trackParams = { currencyID = 3347 }, max = 0, noMax = true },
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

    local db = _G.OneWoW_Trackers and _G.OneWoW_Trackers.db
    if not db then return end

    db.global.trackerBundledVersions = db.global.trackerBundledVersions or {}
    db.global.trackerBundledDeleted = db.global.trackerBundledDeleted or {}
    local versions = db.global.trackerBundledVersions
    local deleted = db.global.trackerBundledDeleted

    for _, bundled in ipairs(BUNDLED_GUIDES) do
        local currentVer = versions[bundled.id] or 0
        if bundled.version > currentVer and not deleted[bundled.id] then
            local existing = nil
            local lists = TD:GetListsDB()
            for _, list in pairs(lists) do
                if list._bundledID == bundled.id then
                    existing = list
                    break
                end
            end

            if existing then
                TD:RemoveList(existing.id)
            end

            local list = nil
            if bundled.importString then
                list = TD:ImportList(bundled.importString)
            elseif bundled.data then
                list = TD:CreateListFromParsed(bundled.data)
            end

            if list then
                list._bundledID = bundled.id
                list.author = bundled.data and bundled.data.author or list.author or "OneWoW"
            end
            versions[bundled.id] = bundled.version
        end
    end
end

function TP:OnBundledDeleted(bundledID)
    local db = _G.OneWoW_Trackers and _G.OneWoW_Trackers.db
    if not db then return end

    db.global.trackerBundledDeleted = db.global.trackerBundledDeleted or {}
    db.global.trackerBundledDeleted[bundledID] = true
end

function TP:RestoreBundledContent()
    local db = _G.OneWoW_Trackers and _G.OneWoW_Trackers.db
    if not db then return end

    db.global.trackerBundledVersions = {}
    db.global.trackerBundledDeleted = {}
    self:LoadBundledContent()
end
