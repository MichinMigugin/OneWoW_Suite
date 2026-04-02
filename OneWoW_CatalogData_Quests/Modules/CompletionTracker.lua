-- OneWoW Addon File
-- OneWoW_CatalogData_Quests/Modules/CompletionTracker.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.CompletionTracker = {}
local CompletionTracker = ns.CompletionTracker

local completedCache = nil
local cacheBuilt     = false

local function GetDB()
    return OneWoW_CatalogData_Quests_DB
end

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
local function GetCharacterKey()
    return OneWoW_GUI and OneWoW_GUI:GetCharacterKey() or nil
end

local function BuildAltTrackerCache()
    if cacheBuilt then return end

    local altApi = _G.OneWoW_AltTracker_Collections_API
    if not altApi or not altApi.GetAllCharacters then
        cacheBuilt = true
        return
    end

    local chars = altApi.GetAllCharacters()
    if not chars then
        cacheBuilt = true
        return
    end

    completedCache = {}
    for charKey, _ in pairs(chars) do
        local charData = altApi.GetCharacterData(charKey)
        if charData and charData.quests and charData.quests.completed then
            completedCache[charKey] = {}
            for _, questID in ipairs(charData.quests.completed) do
                completedCache[charKey][questID] = true
            end
        end
    end
    cacheBuilt = true
end

function CompletionTracker:Initialize()
    local db = GetDB()
    if not db then return end

    local charKey = GetCharacterKey()
    if not charKey then return end

    if not db.completion[charKey] then
        db.completion[charKey] = {}
    end

    local completedIDs = C_QuestLog.GetAllCompletedQuestIDs()
    if completedIDs then
        for _, questID in ipairs(completedIDs) do
            db.completion[charKey][questID] = true
        end
    end
end

function CompletionTracker:MarkCompleted(questID)
    if not questID then return end

    local db = GetDB()
    if not db then return end

    local charKey = GetCharacterKey()
    if not charKey then return end

    if not db.completion[charKey] then
        db.completion[charKey] = {}
    end
    db.completion[charKey][questID] = true

    cacheBuilt = false
    completedCache = nil
end

function CompletionTracker:InvalidateCache()
    cacheBuilt = false
    completedCache = nil
end

function CompletionTracker:GetCompletedCharacters(questID)
    if not questID then return {} end

    local result = {}
    local seen   = {}

    -- Current character: always live
    local currentKey = GetCharacterKey()
    if currentKey and C_QuestLog.IsQuestFlaggedCompleted(questID) then
        local charName = currentKey:match("^(.-)%-") or currentKey
        table.insert(result, { key = currentKey, name = charName })
        seen[currentKey] = true
    end

    -- Our own DB is the primary source — populated for every character on login and on every turn-in
    local db = GetDB()
    if db and db.completion then
        for charKey, completedMap in pairs(db.completion) do
            if not seen[charKey] and completedMap[questID] then
                local charName = charKey:match("^(.-)%-") or charKey
                table.insert(result, { key = charKey, name = charName })
                seen[charKey] = true
            end
        end
    end

    -- AltTracker supplements with characters that have never logged in while our addon was running
    local altApi = _G.OneWoW_AltTracker_Collections_API
    if altApi and altApi.GetAllCharacters then
        BuildAltTrackerCache()
        if completedCache then
            for charKey, lookup in pairs(completedCache) do
                if not seen[charKey] and lookup[questID] then
                    local charName = charKey:match("^(.-)%-") or charKey
                    table.insert(result, { key = charKey, name = charName })
                    seen[charKey] = true
                end
            end
        end
    end

    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function CompletionTracker:IsCompletedByCurrentChar(questID)
    return C_QuestLog.IsQuestFlaggedCompleted(questID) == true
end

function CompletionTracker:IsCompletedByAny(questID)
    if C_QuestLog.IsQuestFlaggedCompleted(questID) then return true end
    local chars = self:GetCompletedCharacters(questID)
    return #chars > 0
end

function CompletionTracker:GetAllTrackedCharacters()
    local result = {}
    local seen   = {}

    -- Always include current character
    local currentKey = GetCharacterKey()
    if currentKey then
        local charName = currentKey:match("^(.-)%-") or currentKey
        table.insert(result, { key = currentKey, name = charName })
        seen[currentKey] = true
    end

    -- Our own DB is primary — all characters that have ever logged in with this addon
    local db = GetDB()
    if db and db.completion then
        for charKey, _ in pairs(db.completion) do
            if not seen[charKey] then
                local charName = charKey:match("^(.-)%-") or charKey
                table.insert(result, { key = charKey, name = charName })
                seen[charKey] = true
            end
        end
    end

    -- AltTracker supplements with characters not yet in our DB
    local altApi = _G.OneWoW_AltTracker_Collections_API
    if altApi and altApi.GetAllCharacters then
        BuildAltTrackerCache()
        if completedCache then
            for charKey, _ in pairs(completedCache) do
                if not seen[charKey] then
                    local charName = charKey:match("^(.-)%-") or charKey
                    table.insert(result, { key = charKey, name = charName })
                    seen[charKey] = true
                end
            end
        end
    end

    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end
