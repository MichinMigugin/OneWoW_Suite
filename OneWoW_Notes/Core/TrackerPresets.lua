local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.TrackerPresets = {}
local TP = ns.TrackerPresets

local tinsert = tinsert

local SECTION_PRESETS = {
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
                            description = "The Tracker supports five list types:\n- Guide: Step-by-step walkthroughs\n- Daily: Resets every day\n- Weekly: Resets every Tuesday\n- To-Do: Never resets, check off manually\n- Repeating: Custom interval reset",
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
}

function TP:LoadBundledContent()
    local TD = ns.TrackerData
    if not TD then return end

    local db = _G.OneWoW_Notes and _G.OneWoW_Notes.db
    if not db then return end

    db.global.trackerBundledVersions = db.global.trackerBundledVersions or {}
    local versions = db.global.trackerBundledVersions

    for _, bundled in ipairs(BUNDLED_GUIDES) do
        local currentVer = versions[bundled.id] or 0
        if bundled.version > currentVer then
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

            local list = TD:CreateListFromParsed(bundled.data)
            if list then
                list._bundledID = bundled.id
            end
            versions[bundled.id] = bundled.version
        end
    end
end

function TP:RestoreBundledContent()
    local db = _G.OneWoW_Notes and _G.OneWoW_Notes.db
    if not db then return end

    db.global.trackerBundledVersions = {}
    self:LoadBundledContent()
end
