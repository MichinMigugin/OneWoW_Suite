-- DEV TOOL (not shipped): simulates the WoW load chain for the quest DB to
-- verify the loader + generated data files assemble correctly.

local function scriptDir()
    local src = debug.getinfo(1, "S").source:gsub("^@", "")
    return src:match("^(.*[\\/])") or "./"
end

local ADDON = "OneWoW_CatalogData_Quests"
local root = scriptDir() .. "../"
local ns = {}

local function runFile(rel)
    local chunk = assert(loadfile(root .. rel))
    chunk(ADDON, ns)
end

runFile("Core/QuestDBLoader.lua")

local FILES = {
    "classic", "bc", "wotlk", "cata", "mop", "wod",
    "legion", "bfa", "shadowlands", "dragonflight", "warwithin", "midnight",
}
for _, e in ipairs(FILES) do
    runFile("Data/QuestDB/QuestDB_" .. e .. ".lua")
end

local total = 0
for _ in pairs(ns.ExternalQuestDB) do total = total + 1 end

local EXP = {
    [0] = "Classic", [1] = "BC", [2] = "Wrath", [3] = "Cata", [4] = "MoP",
    [5] = "WoD", [6] = "Legion", [7] = "BfA", [8] = "Shadowlands",
    [9] = "Dragonflight", [10] = "War Within", [11] = "Midnight",
}
print(string.format("Total quests in ExternalQuestDB: %d", total))
print("By expansion:")
local ids = {}
for id in pairs(ns.ExternalQuestDBByExpansion) do ids[#ids + 1] = id end
table.sort(ids)
for _, id in ipairs(ids) do
    local c = 0
    for _ in pairs(ns.ExternalQuestDBByExpansion[id]) do c = c + 1 end
    print(string.format("  [%2d] %-14s %6d", id, EXP[id] or "?", c))
end

-- spot check a known record survived cleaning
local sample = ns.ExternalQuestDB[10068]
print("Sample 10068: " .. (sample and sample.name or "MISSING"))
