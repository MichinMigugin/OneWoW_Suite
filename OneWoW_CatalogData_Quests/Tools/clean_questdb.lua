-- ============================================================================
-- clean_questdb.lua  (DEV TOOL - not shipped, not in the .toc)
-- ============================================================================
-- One-time / re-runnable cleaner for the Wowhead-scraped quest databases.
--
-- What it does:
--   1. Loads each raw QuestDB_<expansion>.lua (which defines a global table).
--   2. Cleans Wowhead chrome / formatting out of text fields.
--   3. Fixes Burning Crusade quests mis-tagged as Classic (expansion field).
--   4. Drops junk records (DNT / [PH] / [REMOVED] / placeholders / internal
--      names / no-display-and-no-useful-data).
--   5. Re-serializes kept records into clean, namespaced output files that call
--      ns:RegisterQuestData{...} (no raw globals, no _G scanning at runtime).
--
-- The keep/clean logic mirrors the runtime hygiene in Modules/QuestData.lua so
-- shipped data is already clean; the runtime filter stays only as a backstop.
--
-- Usage (run from anywhere; paths are relative to this file's location):
--   lua clean_questdb.lua            -> reads ../Data/QuestDB, writes in place
--   lua clean_questdb.lua <in> <out> -> explicit input/output dirs
-- ============================================================================

local INPUT_DIR, OUTPUT_DIR = ...

------------------------------------------------------------
-- RESOLVE PATHS (default: this tool's ../Data/QuestDB)
------------------------------------------------------------

local function scriptDir()
    local src = debug.getinfo(1, "S").source
    src = src:gsub("^@", "")
    local dir = src:match("^(.*[\\/])") or "./"
    return dir
end

local SELF_DIR = scriptDir()
INPUT_DIR = INPUT_DIR or (SELF_DIR .. "../Data/QuestDB/")
OUTPUT_DIR = OUTPUT_DIR or INPUT_DIR

local FILES = {
    "QuestDB_classic.lua",
    "QuestDB_bc.lua",
    "QuestDB_wotlk.lua",
    "QuestDB_cata.lua",
    "QuestDB_mop.lua",
    "QuestDB_wod.lua",
    "QuestDB_legion.lua",
    "QuestDB_bfa.lua",
    "QuestDB_shadowlands.lua",
    "QuestDB_dragonflight.lua",
    "QuestDB_warwithin.lua",
    "QuestDB_midnight.lua",
}

------------------------------------------------------------
-- BURNING CRUSADE NORMALIZATION (mirrors QuestDBLoader)
------------------------------------------------------------

local BC_MAPS = {
    [94]=true,[95]=true,[97]=true,[100]=true,[102]=true,[103]=true,[104]=true,
    [105]=true,[106]=true,[107]=true,[108]=true,[109]=true,[110]=true,[111]=true,[122]=true,
}
local BC_ZONES = {
    [3430]=true,[3431]=true,[3433]=true,[3483]=true,[3518]=true,[3519]=true,[3520]=true,
    [3521]=true,[3522]=true,[3523]=true,[3524]=true,[3525]=true,[3703]=true,[4080]=true,
    [6455]=true,[6456]=true,
}

local function questMapID(q)
    if type(q.mapID) == "number" and q.mapID ~= 0 then return q.mapID end
    if type(q.coords) == "table" and type(q.coords.mapID) == "number" and q.coords.mapID ~= 0 then
        return q.coords.mapID
    end
    if type(q.starts) == "table" and type(q.starts[1]) == "table"
        and type(q.starts[1].mapID) == "number" and q.starts[1].mapID ~= 0 then
        return q.starts[1].mapID
    end
    if type(q.ends) == "table" and type(q.ends[1]) == "table"
        and type(q.ends[1].mapID) == "number" and q.ends[1].mapID ~= 0 then
        return q.ends[1].mapID
    end
    return nil
end

local function isBCQuest(q)
    local mapID = questMapID(q)
    if mapID then return BC_MAPS[mapID] == true end
    return type(q.zoneID) == "number" and BC_ZONES[q.zoneID] == true
end

local function resolveExpansion(q)
    local exp = q.expansion
    if type(exp) == "number" and exp <= 2 and isBCQuest(q) then
        return 1
    end
    return exp
end

------------------------------------------------------------
-- TEXT HYGIENE (mirrors Modules/QuestData.lua)
------------------------------------------------------------

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function stripFormatting(text)
    if not text then return nil end
    text = tostring(text)
    text = text:gsub("|[cC]%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|[rR]", "")
    text = text:gsub("||", "|")
    return text
end

local function cleanWowheadText(text)
    if not text then return nil end
    text = stripFormatting(text)
    text = text:gsub(
        "See if you've already completed this by typing:%s*/run%s+print%(%s*C_QuestLog%.IsQuestFlaggedCompleted%(%s*%d+%s*%)%s*%)", "")
    text = text:gsub(
        "Gather info with the Wowhead Client%s*Download Now%s*Help keep the database up to date!?", "")
    text = text:gsub("Accept this quest to record its description and rewards%.?", "")
    text = text:gsub("^Community Feasts are one of the main features.-Getting a soup all the way to Legendary%s*", "")
    if text:find("Progress:", 1, true) and text:find("[\128-\255]") then
        text = text:gsub("%s*Progress:.*$", "")
    end
    text = trim(text)
    text = text:gsub("%s%s+", " ")
    if text == "" then return nil end
    return text
end

local function hasWowheadChrome(text)
    if not text then return false end
    text = tostring(text)
    return text:find("See if you've already completed this by typing:", 1, true) ~= nil
        or text:find("C_QuestLog.IsQuestFlaggedCompleted", 1, true) ~= nil
        or text:find("Wowhead Client", 1, true) ~= nil
        or text:find("Download Now", 1, true) ~= nil
        or text:find("Help keep the database up to date", 1, true) ~= nil
        or text:find("Accept this quest to record its description and rewards", 1, true) ~= nil
end

local function hasDNT(text) return text and tostring(text):upper():find("DNT", 1, true) ~= nil end
local function hasNth(text) return text and tostring(text):upper():find("%f[%w]NTH%f[%W]") ~= nil end
local function hasPH(text)
    if not text then return false end
    text = tostring(text):upper()
    return text:find("[PH]", 1, true) ~= nil or text:find("(PH)", 1, true) ~= nil
end
local function hasNYI(text) return text and tostring(text):upper():find("[NYI]", 1, true) ~= nil end
local function hasRemoved(text)
    if not text then return false end
    text = trim(tostring(text):upper())
    return text:find("[REMOVED]", 1, true) ~= nil or text == "REMOVED"
end
local function hasBracketDev(text)
    if not text then return false end
    return trim(tostring(text)):find("%b[]") ~= nil
end
local function hasPlaceholder(text)
    return text and tostring(text):lower():find("placeholder", 1, true) ~= nil
end

local function isInternalName(name, questID)
    if not name then return true end
    name = trim(tostring(name))
    local l = name:lower()
    if name == "" then return true end
    if name:match("^Level%s+%d+$") then return true end
    local substr = {
        "reward test", "rated pvp incentive", "tracking quest", "reward quest",
        "quest start", "navigation playtest", ":]p", "test case", "test quest",
        "nav test", "test currency", "testing", "do not use", "event tracking",
        "unused", "vignette", "capstone",
    }
    for _, s in ipairs(substr) do
        if l:find(s, 1, true) then return true end
    end
    if l:find("%f[%w]poi%f[%W]") then return true end
    if l:find("bonus objective", 1, true) and tonumber(questID) ~= 71153 then return true end
    if hasPlaceholder(name) or hasDNT(name) or hasNth(name) or hasPH(name)
        or hasNYI(name) or hasRemoved(name) or hasBracketDev(name) then
        return true
    end
    if name == "?" or name == "??" or l == "zz" or l == "test" then return true end
    return false
end

local function hasValue(tbl, value)
    if not tbl then return false end
    for _, v in ipairs(tbl) do if v == value then return true end end
    return false
end

local HIDDEN_CATEGORIES = { test = true, hidden = true }
local HIDDEN_FLAGS = { deprecated = true, internal = true, unobtainable = true, removed = true }

local function hasDisplayText(text)
    if not text then return false end
    text = trim(tostring(text))
    if text == "" then return false end
    if text == "Accept this quest to record its description and rewards." then return false end
    if hasWowheadChrome(text) then return false end
    return true
end

local function hasDisplayObjectives(q)
    if hasDisplayText(q.objectivesText) then return true end
    if q.objectives then
        for _, o in ipairs(q.objectives) do
            if hasDisplayText(o) then return true end
        end
    end
    return false
end

local function hasUsefulChain(q, values)
    if not values then return false end
    local id = tonumber(q.id)
    for _, v in ipairs(values) do
        local linked = tonumber(v)
        if not linked or linked ~= id then return true end
    end
    return false
end

local function hasUsefulSparse(q)
    if (q.rewardGold and q.rewardGold > 0)
        or (q.rewardXP and q.rewardXP > 0)
        or (q.rewardItems and #q.rewardItems > 0)
        or (q.rewardChoices and #q.rewardChoices > 0)
        or (q.rewardCurrencies and #q.rewardCurrencies > 0) then
        return true
    end
    if q.coords and q.coords.mapID and q.coords.mapID ~= 0 then return true end
    if q.mapID and q.mapID ~= 0 then return true end
    if hasUsefulChain(q, q.storyline) or hasUsefulChain(q, q.series) then return true end
    return false
end

------------------------------------------------------------
-- CLEAN A SINGLE QUEST (returns cleaned quest or nil to drop)
------------------------------------------------------------

local function cleanQuest(q)
    if type(q) ~= "table" or not q.id or not q.name then return nil end

    q.name = stripFormatting(q.name)
    if isInternalName(q.name, q.id) then return nil end

    q.description = cleanWowheadText(q.description)
    q.objectivesText = cleanWowheadText(q.objectivesText)
    if q.objectives then
        local out = {}
        for _, o in ipairs(q.objectives) do
            local c = cleanWowheadText(o)
            if c then out[#out + 1] = c end
        end
        q.objectives = out
    end
    if q.objectiveDetails then
        local out = {}
        for _, o in ipairs(q.objectiveDetails) do
            if type(o) == "table" then
                o.text = cleanWowheadText(o.text)
                if o.text then out[#out + 1] = o end
            end
        end
        q.objectiveDetails = out
    end

    -- marker rejection (post-clean, mirrors runtime IsValidQuest)
    local function badText(t)
        return hasDNT(t) or hasNth(t) or hasPH(t) or hasNYI(t)
            or hasBracketDev(t) or hasPlaceholder(t) or hasRemoved(t) or hasWowheadChrome(t)
    end
    if badText(q.description) or badText(q.objectivesText) then return nil end
    if q.objectives then
        for _, o in ipairs(q.objectives) do
            if badText(o) then return nil end
        end
    end

    for cat in pairs(HIDDEN_CATEGORIES) do
        if hasValue(q.categories, cat) then return nil end
    end
    for flag in pairs(HIDDEN_FLAGS) do
        if hasValue(q.flags, flag) then return nil end
    end

    if not hasDisplayText(q.description)
        and not hasDisplayObjectives(q)
        and not hasUsefulSparse(q) then
        return nil
    end

    local exp = resolveExpansion(q)
    if type(exp) == "number" then q.expansion = exp end

    -- Prune shipped noise: scraper-internal fields the runtime never reads,
    -- empty tables the runtime re-defaults anyway, and zero numeric rewards.
    q.unknownQuickfacts = nil
    local DEFAULTED_TABLES = {
        "requiredClasses", "requiredRaces", "requiredProfessions",
        "categories", "flags", "rewardItems", "rewardChoices",
        "rewardCurrencies", "storyline", "series", "starts", "ends",
    }
    for _, k in ipairs(DEFAULTED_TABLES) do
        if type(q[k]) == "table" and next(q[k]) == nil then q[k] = nil end
    end
    if q.rewardGold == 0 then q.rewardGold = nil end
    if q.rewardXP == 0 then q.rewardXP = nil end

    return q
end

------------------------------------------------------------
-- SERIALIZER (deterministic, valid Lua 5.1)
------------------------------------------------------------

local function escapeStr(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub("\"", "\\\"")
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    return "\"" .. s .. "\""
end

local function serializeNumber(n)
    if n == math.floor(n) and n == n and n ~= math.huge and n ~= -math.huge then
        return string.format("%d", n)
    end
    return string.format("%.14g", n)
end

local function isSequence(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    if n == 0 then return true end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return true
end

local serialize

local function sortedKeys(t)
    local nums, strs = {}, {}
    for k in pairs(t) do
        if type(k) == "number" then nums[#nums + 1] = k
        elseif type(k) == "string" then strs[#strs + 1] = k end
    end
    table.sort(nums)
    table.sort(strs)
    return nums, strs
end

serialize = function(v)
    local tv = type(v)
    if tv == "number" then return serializeNumber(v)
    elseif tv == "string" then return escapeStr(v)
    elseif tv == "boolean" then return v and "true" or "false"
    elseif tv == "table" then
        if next(v) == nil then return "{}" end
        if isSequence(v) then
            local parts = {}
            for i = 1, #v do parts[#parts + 1] = serialize(v[i]) end
            return "{ " .. table.concat(parts, ", ") .. " }"
        end
        local nums, strs = sortedKeys(v)
        local parts = {}
        for _, k in ipairs(nums) do
            parts[#parts + 1] = "[" .. k .. "] = " .. serialize(v[k])
        end
        for _, k in ipairs(strs) do
            parts[#parts + 1] = "[" .. escapeStr(k) .. "] = " .. serialize(v[k])
        end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    return "nil"
end

------------------------------------------------------------
-- RECORD SERIALIZER (one quest per line block, key-sorted)
------------------------------------------------------------

local QUEST_KEY_ORDER = {
    "id", "name", "level", "requiredLevel", "faction",
    "requiredClasses", "requiredRaces", "requiredProfessions",
    "categories", "flags", "timerSeconds", "sharable", "event",
    "expansion", "zoneID", "mapID", "storyline", "series",
    "description", "objectivesText", "objectives", "objectiveDetails",
    "rewardGold", "rewardXP", "rewardItems", "rewardChoices", "rewardCurrencies",
    "starts", "ends", "coords", "mapCandidates", "questGiverID", "questGiverName",
    "questTurnInID", "questTurnInName", "suggestedGroup", "classification",
}

local function serializeQuest(q)
    local seen = {}
    local parts = {}
    local function emit(k)
        if q[k] ~= nil and not seen[k] then
            seen[k] = true
            parts[#parts + 1] = "[\"" .. k .. "\"] = " .. serialize(q[k])
        end
    end
    for _, k in ipairs(QUEST_KEY_ORDER) do emit(k) end
    -- any keys not in the canonical order, sorted for determinism
    local extra = {}
    for k in pairs(q) do
        if type(k) == "string" and not seen[k] then extra[#extra + 1] = k end
    end
    table.sort(extra)
    for _, k in ipairs(extra) do emit(k) end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

------------------------------------------------------------
-- PROCESS FILES
------------------------------------------------------------

local function loadRawDB(path, globalName)
    local chunk, err = loadfile(path)
    if not chunk then return nil, err end
    -- raw files assign a global; capture it via a sandbox env
    local env = setmetatable({}, { __index = _G })
    setfenv(chunk, env)
    local ok, runErr = pcall(chunk)
    if not ok then return nil, runErr end
    return env[globalName]
end

local function writeCleaned(path, quests)
    local ids = {}
    for id in pairs(quests) do ids[#ids + 1] = id end
    table.sort(ids)

    local out = {}
    out[#out + 1] = "local _, ns = ..."
    out[#out + 1] = ""
    out[#out + 1] = "ns:RegisterQuestData({"
    for _, id in ipairs(ids) do
        out[#out + 1] = "[" .. id .. "] = " .. serializeQuest(quests[id]) .. ","
    end
    out[#out + 1] = "})"
    out[#out + 1] = ""

    local f = assert(io.open(path, "wb"))
    f:write(table.concat(out, "\n"))
    f:close()
end

local function roundTripCheck(path)
    local chunk, err = loadfile(path)
    if not chunk then return false, err end
    local captured
    local env = setmetatable({
        ns = { RegisterQuestData = function(_, t) captured = t end },
    }, { __index = _G })
    setfenv(chunk, env)
    -- emulate the "..." vararg (addonName, ns)
    local ok, runErr = pcall(function() return chunk("OneWoW_CatalogData_Quests", env.ns) end)
    if not ok then return false, runErr end
    local n = 0
    for _ in pairs(captured or {}) do n = n + 1 end
    return true, n
end

local sep = package.config:sub(1, 1)
local function join(dir, name)
    if dir:sub(-1) == "/" or dir:sub(-1) == "\\" then return dir .. name end
    return dir .. sep .. name
end

local totalIn, totalOut = 0, 0
print("Cleaning quest DBs")
print("  input : " .. INPUT_DIR)
print("  output: " .. OUTPUT_DIR)
print(string.rep("-", 60))

for _, fileName in ipairs(FILES) do
    local globalName = fileName:gsub("%.lua$", "")
    local inPath = join(INPUT_DIR, fileName)
    local raw, loadErr = loadRawDB(inPath, globalName)

    if not raw then
        print(string.format("  SKIP  %-26s (%s)", fileName, tostring(loadErr)))
    else
        local inCount, kept = 0, {}
        for id, q in pairs(raw) do
            inCount = inCount + 1
            if type(id) == "number" then
                local cleaned = cleanQuest(q)
                if cleaned then kept[id] = cleaned end
            end
        end
        local keptCount = 0
        for _ in pairs(kept) do keptCount = keptCount + 1 end

        local outPath = join(OUTPUT_DIR, fileName)
        writeCleaned(outPath, kept)
        local ok, rtCount = roundTripCheck(outPath)

        totalIn = totalIn + inCount
        totalOut = totalOut + keptCount
        print(string.format("  %-26s %6d -> %6d kept  (dropped %5d)%s",
            fileName, inCount, keptCount, inCount - keptCount,
            ok and "" or ("  ROUNDTRIP FAIL: " .. tostring(rtCount))))
    end
end

print(string.rep("-", 60))
print(string.format("TOTAL  %d -> %d kept  (dropped %d)",
    totalIn, totalOut, totalIn - totalOut))
