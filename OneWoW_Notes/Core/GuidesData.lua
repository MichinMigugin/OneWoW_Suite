local addonName, ns = ...

ns.GuidesData = {}
local GuidesData = ns.GuidesData

function GuidesData:GenerateUniqueID()
    return string.format("g-%08x-%04x-%04x",
        GetServerTime(),
        math.random(0, 65535),
        math.random(0, 65535))
end

function GuidesData:GetGuidesDB()
    local addon = _G.OneWoW_Notes
    return addon.db.global.guides
end

function GuidesData:GetProgressDB()
    local addon = _G.OneWoW_Notes
    return addon.db.char.guideProgress
end

function GuidesData:GetAllGuides()
    return self:GetGuidesDB() or {}
end

function GuidesData:GetGuide(guideID)
    local db = self:GetGuidesDB()
    if db and db[guideID] then
        return db[guideID]
    end
    return nil
end

function GuidesData:AddGuide(guideData)
    local addon = _G.OneWoW_Notes
    local db = self:GetGuidesDB()
    if not db then
        addon.db.global.guides = {}
        db = addon.db.global.guides
    end

    local guideID = guideData.id or self:GenerateUniqueID()
    guideData.id = guideID
    guideData.title = guideData.title or ""
    guideData.description = guideData.description or ""
    guideData.author = guideData.author or UnitName("player")
    guideData.version = guideData.version or 1
    guideData.category = guideData.category or "General"
    guideData.steps = guideData.steps or {}
    guideData.created = guideData.created or GetServerTime()
    guideData.modified = guideData.modified or GetServerTime()
    guideData.favorite = guideData.favorite or false

    db[guideID] = guideData
    return guideID
end

function GuidesData:RemoveGuide(guideID)
    local db = self:GetGuidesDB()
    if not db or not db[guideID] then return false end

    if ns.GuidesTracker then
        local activeID = ns.GuidesTracker:GetActiveGuideID()
        if activeID == guideID then
            ns.GuidesTracker:Deactivate()
        end
    end

    db[guideID] = nil

    local progressDB = self:GetProgressDB()
    if progressDB and progressDB[guideID] then
        progressDB[guideID] = nil
    end

    return true
end

function GuidesData:UpdateGuide(guideID, changes)
    local guide = self:GetGuide(guideID)
    if not guide then return false end

    for k, v in pairs(changes) do
        guide[k] = v
    end
    guide.modified = GetServerTime()
    return true
end

function GuidesData:GetProgress(guideID)
    local progressDB = self:GetProgressDB()
    if not progressDB then
        local addon = _G.OneWoW_Notes
        addon.db.char.guideProgress = {}
        progressDB = addon.db.char.guideProgress
    end
    if not progressDB[guideID] then
        progressDB[guideID] = {
            currentStep = 1,
            completed = false,
            objectives = {},
        }
    end
    return progressDB[guideID]
end

function GuidesData:SetObjectiveComplete(guideID, stepIndex, objIndex, completed)
    local progress = self:GetProgress(guideID)
    if not progress.objectives[stepIndex] then
        progress.objectives[stepIndex] = {}
    end
    progress.objectives[stepIndex][objIndex] = completed
end

function GuidesData:IsObjectiveComplete(guideID, stepIndex, objIndex)
    local progress = self:GetProgress(guideID)
    if progress.objectives[stepIndex] and progress.objectives[stepIndex][objIndex] then
        return true
    end
    return false
end

function GuidesData:IsStepComplete(guideID, stepIndex)
    local guide = self:GetGuide(guideID)
    if not guide or not guide.steps[stepIndex] then return false end

    local step = guide.steps[stepIndex]
    if not step.objectives or #step.objectives == 0 then return false end

    for i = 1, #step.objectives do
        if not self:IsObjectiveComplete(guideID, stepIndex, i) then
            return false
        end
    end
    return true
end

function GuidesData:GetCompletedStepCount(guideID)
    local guide = self:GetGuide(guideID)
    if not guide then return 0, 0 end
    local total = #guide.steps
    local done = 0
    for i = 1, total do
        if self:IsStepComplete(guideID, i) then
            done = done + 1
        end
    end
    return done, total
end

function GuidesData:SetCurrentStep(guideID, stepIndex)
    local progress = self:GetProgress(guideID)
    progress.currentStep = stepIndex
end

function GuidesData:ResetProgress(guideID)
    local progressDB = self:GetProgressDB()
    if progressDB then
        progressDB[guideID] = nil
    end
end

function GuidesData:AddStep(guideID, stepData)
    local guide = self:GetGuide(guideID)
    if not guide then return nil end

    stepData = stepData or {}
    stepData.title = stepData.title or ""
    stepData.description = stepData.description or ""
    stepData.objectives = stepData.objectives or {}
    stepData.optional = stepData.optional or false
    stepData.faction = stepData.faction or "both"

    table.insert(guide.steps, stepData)
    guide.modified = GetServerTime()
    return #guide.steps
end

function GuidesData:RemoveStep(guideID, stepIndex)
    local guide = self:GetGuide(guideID)
    if not guide or not guide.steps[stepIndex] then return false end
    table.remove(guide.steps, stepIndex)
    guide.modified = GetServerTime()
    return true
end

function GuidesData:AddObjective(guideID, stepIndex, objData)
    local guide = self:GetGuide(guideID)
    if not guide or not guide.steps[stepIndex] then return nil end

    objData = objData or {}
    objData.type = objData.type or "manual"
    objData.description = objData.description or ""
    objData.params = objData.params or {}

    table.insert(guide.steps[stepIndex].objectives, objData)
    guide.modified = GetServerTime()
    return #guide.steps[stepIndex].objectives
end

function GuidesData:RemoveObjective(guideID, stepIndex, objIndex)
    local guide = self:GetGuide(guideID)
    if not guide or not guide.steps[stepIndex] then return false end
    local objs = guide.steps[stepIndex].objectives
    if not objs or not objs[objIndex] then return false end
    table.remove(objs, objIndex)
    guide.modified = GetServerTime()
    return true
end

local GUIDE_CATEGORIES = {
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
}

function GuidesData:GetCategories()
    return GUIDE_CATEGORIES
end

function GuidesData:ExportGuide(guideID)
    local guide = self:GetGuide(guideID)
    if not guide then return nil end

    local exportData = {
        t = guide.title,
        d = guide.description,
        a = guide.author,
        v = guide.version,
        c = guide.category,
        s = {},
    }

    for _, step in ipairs(guide.steps) do
        local stepExport = {
            t = step.title,
            d = step.description,
            o = {},
            opt = step.optional or false,
            f = step.faction or "both",
        }
        for _, obj in ipairs(step.objectives or {}) do
            table.insert(stepExport.o, {
                y = obj.type,
                d = obj.description,
                p = obj.params,
            })
        end
        table.insert(exportData.s, stepExport)
    end

    local serialized = ns.GuidesData:SerializeTable(exportData)
    return serialized
end

function GuidesData:ImportGuide(importString)
    if not importString or importString == "" then return nil, "Empty string" end

    local data = ns.GuidesData:DeserializeTable(importString)
    if not data or type(data) ~= "table" then return nil, "Invalid format" end
    if not data.t or not data.s then return nil, "Missing guide data" end

    local guideData = {
        title = data.t,
        description = data.d or "",
        author = data.a or "Unknown",
        version = data.v or 1,
        category = data.c or "General",
        steps = {},
    }

    for _, stepData in ipairs(data.s) do
        local step = {
            title = stepData.t or "",
            description = stepData.d or "",
            objectives = {},
            optional = stepData.opt or false,
            faction = stepData.f or "both",
        }
        for _, objData in ipairs(stepData.o or {}) do
            table.insert(step.objectives, {
                type = objData.y or "manual",
                description = objData.d or "",
                params = objData.p or {},
            })
        end
        table.insert(guideData.steps, step)
    end

    local guideID = self:AddGuide(guideData)
    return guideID
end

function GuidesData:SerializeTable(tbl)
    local parts = {}
    local function encode(val)
        if type(val) == "string" then
            return string.format("%q", val)
        elseif type(val) == "number" then
            return tostring(val)
        elseif type(val) == "boolean" then
            return val and "true" or "false"
        elseif type(val) == "table" then
            local inner = {}
            local isArray = #val > 0
            if isArray then
                for _, v in ipairs(val) do
                    table.insert(inner, encode(v))
                end
            else
                for k, v in pairs(val) do
                    if type(k) == "string" then
                        table.insert(inner, k .. "=" .. encode(v))
                    end
                end
            end
            return "{" .. table.concat(inner, ",") .. "}"
        end
        return "nil"
    end
    return encode(tbl)
end

function GuidesData:DeserializeTable(str)
    if not str or str == "" then return nil end
    str = strtrim(str)
    local func, err = loadstring("return " .. str)
    if not func then return nil end
    setfenv(func, {})
    local ok, result = pcall(func)
    if not ok then return nil end
    return result
end

function GuidesData:GuideToMarkup(guideID)
    local guide = self:GetGuide(guideID)
    if not guide then return "" end

    local lines = {}
    table.insert(lines, "# " .. (guide.title or ""))
    if guide.description and guide.description ~= "" then
        for descLine in guide.description:gmatch("[^\n]+") do
            table.insert(lines, "> " .. descLine)
        end
    end

    for _, step in ipairs(guide.steps or {}) do
        table.insert(lines, "## " .. (step.title or ""))
        if step.description and step.description ~= "" then
            for descLine in step.description:gmatch("[^\n]+") do
                table.insert(lines, "> " .. descLine)
            end
        end
        for _, obj in ipairs(step.objectives or {}) do
            local bracket = obj.type
            local p = obj.params or {}
            if obj.type == "level" then
                bracket = "level:" .. (p.level or 0)
            elseif obj.type == "quest_complete" then
                bracket = "quest_complete:" .. (p.questID or 0)
            elseif obj.type == "quest_active" then
                bracket = "quest_active:" .. (p.questID or 0)
            elseif obj.type == "item_count" then
                bracket = "item_count:" .. (p.itemID or 0) .. ":" .. (p.count or 1)
            elseif obj.type == "location" then
                bracket = "location:" .. (p.mapID or 0)
            elseif obj.type == "achievement" then
                bracket = "achievement:" .. (p.achievementID or 0)
            elseif obj.type == "reputation" then
                bracket = "reputation:" .. (p.factionID or 0) .. ":" .. (p.standing or 0)
            elseif obj.type == "spell_known" then
                bracket = "spell_known:" .. (p.spellID or 0)
            elseif obj.type == "ilvl" then
                bracket = "ilvl:" .. (p.ilvl or 0)
            elseif obj.type == "currency" then
                bracket = "currency:" .. (p.currencyID or 0) .. ":" .. (p.amount or 0)
            end
            table.insert(lines, "[" .. bracket .. "] " .. (obj.description or ""))
        end
    end

    return table.concat(lines, "\n")
end

local BUNDLED_GUIDE = [[
# Midnight Alt Leveling Skip Guide
> Leveling more than one character in Midnight? Skipping the story campaign works differently this time, but alts can bypass the Defense of Sunwell intro and zone storylines. This guide covers the full process.
## Complete the Main Story on Your Main
> Play through Eversong Woods, Zul'Aman, Harandar, Voidstorm, and Arator's Journey on your main character to earn the Midnight achievement. This unlocks level 90 activities like world quests and the Prey system for mains and alts.
[achievement:41802] Complete Eversong In Reprise
[achievement:41803] Complete For Zul'Aman!
[achievement:41804] Complete One Does Not Simply Walk Into Harandar
[achievement:41805] Complete Arator's Journey
[achievement:41806] Complete Voidstorm
[achievement:42045] Earn Midnight achievement
## Start the Expansion on Your Alt
> Begin the Midnight expansion content. Accept the Midnight quest to start the intro sequence.
[quest_complete:91281] Accept the Midnight quest
## Skip the Defense of the Sunwell Intro
> After accepting the Midnight quest, the Image of Lady Liadrin will offer alts a new option to skip the Defense of the Sunwell intro, sending you directly to Silvermoon.
[manual] Talk to the Image of Lady Liadrin
[manual] Choose the option to skip Defense of the Sunwell
## Level Your Alt to 90
> Level through any method you prefer - quests, dungeons, world content. No story skip quest appears until you reach level 90.
[level:70] Reach level 70
[level:75] Reach level 75
[level:80] Reach level 80
[level:85] Reach level 85
[level:90] Reach level 90
## Travel to Silvermoon City
> At level 90 on a second character, no quest appears automatically. You must find your own way to Silvermoon City. The story skip is hidden.
[location:110] Arrive in Silvermoon City
## Talk to Soridormi to Skip the Story Campaign
> Soridormi can be found at Wayfarer's Rest in the Silvermoon Inn at coordinates 55.6, 69.8. She will allow you to skip the Midnight story campaign, placing your alt at the end of the initial campaign.
[manual] Find Soridormi at Wayfarer's Rest in Silvermoon Inn (55.6, 69.8)
[manual] Talk to Soridormi to skip the story campaign
## Accept Midnight: World Tour
> After the skip, Lor'themar offers Midnight: World Tour. This should be the first Spark of Radiance most players obtain in Midnight.
[quest_complete:95245] Complete Midnight: World Tour
]]

local BUNDLED_GUIDE_HOW_TO = [[
# How to Create and Share Guides
> Guides let you build step-by-step walkthroughs for anything in the game. Each guide is made up of steps, and each step has objectives that can be checked off manually or tracked automatically as you play. You can make your own from scratch, or get pre-made guides from other players on Discord.
## Creating a New Guide
> Click the New button at the top of the Guides tab. This opens the guide editor where you write your guide using a simple markup format. Pick a category from the dropdown to help organize it. Your character name is saved as the author automatically.
[manual] Click the New button to open the guide editor
[manual] Choose a category from the dropdown
[manual] Write a title on the first line using: # Your Title Here
## Writing Steps
> Each step starts with ## followed by the step title. You can add a description below any step by starting a line with > followed by your text. Steps are shown in the order you write them, and you can reorder them later using the arrow buttons.
[manual] Add a step using: ## Step Title Here
[manual] Add a description using: > Your description text here
## Adding Objectives
> Objectives go under each step. The simplest type is manual - just write [manual] followed by a description. Manual objectives require clicking to mark complete. For example: [manual] Talk to the innkeeper
[manual] Add a manual objective using: [manual] Your task description
## Auto-Tracking Objectives
> Some objective types track your progress automatically while you play. Use the type name and a colon followed by the value. Available auto-tracking types:
> [level:90] - Completes when you reach that level
> [quest_complete:12345] - Completes when you finish that quest ID
> [quest_active:12345] - Completes when that quest is in your log
> [item_count:12345:10] - Completes when you have that many of an item
> [location:123] - Completes when you enter that map zone
> [achievement:12345] - Completes when you earn that achievement
> [reputation:1234:6] - Completes at that rep standing with a faction
> [spell_known:12345] - Completes when you know that spell
> [ilvl:600] - Completes when your equipped item level reaches that value
> [currency:1234:100] - Completes when you have that much of a currency
[manual] Try adding an auto-tracking objective to a test guide
## Faction-Specific Steps
> When editing a step individually (click the edit icon on any step), you can set it to Horde Only, Alliance Only, or Both. Faction-locked steps only appear for the matching faction. You can also mark steps as Optional so they do not block progress.
[manual] Open a step editor and see the Faction and Optional settings
## Activating a Guide
> Click the Activate button on any guide to start tracking it. A floating tracker window appears on your screen showing your current step and objectives. The tracker updates in real-time as you complete objectives. You can drag it anywhere on screen and it remembers its position. Click Skip Step on the tracker to jump ahead, or close it to deactivate.
[manual] Activate this guide to see the floating tracker
[manual] Drag the tracker to reposition it
[manual] Deactivate when done by clicking the close button
## Exporting Your Guide
> Click the Export button on any guide to get a shareable text string. Copy the entire text and send it to others. They can paste it into the Import window to add your guide to their collection.
[manual] Click Export on any guide and copy the text
## Importing a Guide
> Click the Import button at the top of the Guides tab. Paste either the export string or write a guide directly in markup format. The importer accepts both formats. You can set a title and category before importing.
[manual] Click Import and try pasting a guide
## Sharing on Discord
> The best way to share guides and find guides made by other players is through the OneWoW Discord community. Share your exported guide text in the appropriate channel, or browse what others have shared. You can also request specific guides from the community if there is something you need help with.
[manual] Visit the OneWoW Discord to share or find guides
]]

local BUNDLED_GUIDE_ROUTINES = [[
# How to Create and Share Routines
> Routines are repeating checklists for tracking your daily and weekly tasks in the game. Unlike Guides which are step-by-step walkthroughs, Routines are designed to reset and repeat. Sections can reset weekly with the server reset, or be set to never reset for permanent tracking. You can build simple manual checklists or detailed auto-tracking routines. Make your own or get pre-made routines from other players on Discord.
## Creating a New Routine
> Click the New Routine button at the top of the Routines tab. A new routine appears in the list with a default name. Click on it, then edit the title directly in the detail panel on the right side.
[manual] Click New Routine to create one
[manual] Click on your new routine in the list
[manual] Edit the title in the detail panel
## Adding Sections with Presets
> Click Add Section on your routine to see the preset options. Presets give you pre-built sections with auto-tracking already configured. Available presets:
> Great Vault - Tracks raid bosses, dungeon runs, and world activities for all three vault rows.
> Prey System - Tracks Normal, Hard, and Nightmare hunts plus Remnants of Anguish currency.
> Season Weeklies - Tracks all current weekly quests like Abundance, Lost Legends, Special Assignment, and more.
> Renown Tracking - Tracks your renown level with all four Midnight factions.
> Professions - Pick any of the 12 professions to track skill, concentration, knowledge, uniques, first crafts, treatise, weekly quest, treasures, and catch-up currency.
> Track Uniques - Pick a profession to get detailed per-item tracking for each unique knowledge item.
[manual] Click Add Section and browse the preset options
[manual] Try adding a Great Vault or Professions preset
## Adding a Custom Section
> Choose Custom Section to create a blank section. Give it a label and choose its reset type. Weekly sections reset automatically when the server resets each week. Never sections keep their progress permanently. You can mix both in one routine.
[manual] Add a Custom Section
[manual] Set a label and choose Weekly or Never for the reset type
## Adding Tasks to Custom Sections
> Click Add Task inside any custom section. Each task has a label and a max count. A task with max 1 works as a simple checkbox. A task with a higher max (like 4) works as a counter you can click to increment. The tracking type controls how it updates:
> Manual - You click to mark progress yourself.
> Quest - Auto-completes when specific quest IDs are turned in.
> Currency - Auto-tracks a currency amount.
> Spell - Auto-tracks when you cast a specific spell.
[manual] Add a task with max 1 (simple checkbox)
[manual] Add a task with a higher max (counter style)
## Pinning a Routine to Your Screen
> Click the Pin button on any routine to create a floating window on your screen. The pinned window shows all sections and tasks with live progress. You can drag it anywhere, and it remembers its position. Click the close button on the pinned window to unpin it. Pinned routines stay visible while you play and update automatically.
[manual] Pin a routine and see it on screen
[manual] Drag the pinned window to reposition it
## Routine Auto-Reset
> Sections set to Weekly reset automatically when the game server resets each week. Your progress is cleared and you start fresh. Tasks inside a weekly section can individually be set to Never reset if you want certain items to persist through resets (like permanent skill tracking inside a weekly profession section).
[manual] Note how weekly sections reset and never sections persist
## Exporting a Routine
> Click the Export button on any routine to get a shareable text string. Copy the entire text and share it with other players. The export includes all sections, tasks, tracking settings, and reset types.
[manual] Click Export on a routine and copy the text
## Importing a Routine
> Click the Import button at the top of the Routines tab. Paste the export string from another player and click Import. The full routine with all its sections and tracking configuration is recreated for you.
[manual] Click Import and try pasting a routine
## Sharing on Discord
> The best way to share routines and find routines made by other players is through the OneWoW Discord community. Share your exported routine text in the appropriate channel, or browse what others have created. You can also request custom routines from the community. Zone routines, profession routines, weekly checklists, and farming routes are all popular choices.
[manual] Visit the OneWoW Discord to share or find routines
]]

local BUNDLED_GUIDES_VERSION = 2

function GuidesData:LoadBundledGuides(force)
    local addon = _G.OneWoW_Notes
    local currentVersion = addon.db.global.bundledGuidesVersion or 0

    if not force and currentVersion >= BUNDLED_GUIDES_VERSION then return end

    if currentVersion < 1 or force then
        local parsed = self:ParseMarkupGuide(BUNDLED_GUIDE)
        if parsed then
            parsed.author = "OneWoW"
            parsed.category = "Leveling"
            self:AddGuide(parsed)
        end
    end

    if currentVersion < 2 or force then
        local parsedHow = self:ParseMarkupGuide(BUNDLED_GUIDE_HOW_TO)
        if parsedHow then
            parsedHow.author = "OneWoW"
            parsedHow.category = "General"
            self:AddGuide(parsedHow)
        end

        local parsedRoutines = self:ParseMarkupGuide(BUNDLED_GUIDE_ROUTINES)
        if parsedRoutines then
            parsedRoutines.author = "OneWoW"
            parsedRoutines.category = "General"
            self:AddGuide(parsedRoutines)
        end
    end

    addon.db.global.bundledGuidesVersion = BUNDLED_GUIDES_VERSION
    addon.db.global.bundledGuidesLoaded = true
    return true
end

function GuidesData:ParseMarkupGuide(text)
    if not text or text == "" then return nil end

    local guide = {
        title = "",
        description = "",
        category = "General",
        steps = {},
    }

    local currentStep = nil
    local lines = { strsplit("\n", text) }

    for _, line in ipairs(lines) do
        line = strtrim(line)
        if line == "" then
            -- skip
        elseif line:match("^# (.+)") then
            guide.title = line:match("^# (.+)")
        elseif line:match("^## (.+)") then
            if currentStep then
                table.insert(guide.steps, currentStep)
            end
            currentStep = {
                title = line:match("^## (.+)"),
                description = "",
                objectives = {},
                optional = false,
                faction = "both",
            }
        elseif line:match("^> (.+)") then
            if currentStep then
                if currentStep.description ~= "" then
                    currentStep.description = currentStep.description .. "\n"
                end
                currentStep.description = currentStep.description .. line:match("^> (.+)")
            else
                if guide.description ~= "" then
                    guide.description = guide.description .. "\n"
                end
                guide.description = guide.description .. line:match("^> (.+)")
            end
        elseif line:match("^%[(.-)%]") then
            if currentStep then
                local bracket, desc = line:match("^%[(.-)%]%s*(.*)")
                local objType, paramStr = bracket:match("^(.-):(.*)")
                if not objType then
                    objType = bracket
                    paramStr = ""
                end

                local obj = {
                    type = objType,
                    description = desc or "",
                    params = {},
                }

                if objType == "level" then
                    obj.params.level = tonumber(paramStr) or 0
                elseif objType == "quest_complete" or objType == "quest_active" then
                    obj.params.questID = tonumber(paramStr) or 0
                elseif objType == "item_count" then
                    local itemID, count = paramStr:match("(%d+):(%d+)")
                    obj.params.itemID = tonumber(itemID) or 0
                    obj.params.count = tonumber(count) or 1
                elseif objType == "location" then
                    obj.params.mapID = tonumber(paramStr) or 0
                elseif objType == "achievement" then
                    obj.params.achievementID = tonumber(paramStr) or 0
                elseif objType == "reputation" then
                    local factionID, standing = paramStr:match("(%d+):(%d+)")
                    obj.params.factionID = tonumber(factionID) or 0
                    obj.params.standing = tonumber(standing) or 0
                elseif objType == "spell_known" then
                    obj.params.spellID = tonumber(paramStr) or 0
                elseif objType == "ilvl" then
                    obj.params.ilvl = tonumber(paramStr) or 0
                elseif objType == "currency" then
                    local currencyID, amount = paramStr:match("(%d+):(%d+)")
                    obj.params.currencyID = tonumber(currencyID) or 0
                    obj.params.amount = tonumber(amount) or 0
                end

                table.insert(currentStep.objectives, obj)
            end
        end
    end

    if currentStep then
        table.insert(guide.steps, currentStep)
    end

    if guide.title == "" and #guide.steps == 0 then
        return nil
    end

    return guide
end
