local _, ns = ...

-- ============================================================================
-- QuestDBLoader
-- ============================================================================
-- Assembles the shipped static quest database. Each generated data file under
-- Data/QuestDB calls ns:RegisterQuestData{...}; this file defines that registrar
-- and the two lookup tables it feeds:
--
--   ns.ExternalQuestDB             [questID] = questData
--   ns.ExternalQuestDBByExpansion  [expansionID][questID] = questData
--
-- Shards are emitted offline by bin/wowhead/quest-split.py. The registrar is
-- a plain merge: no runtime scraping, no _G scanning, no global pollution.
-- ============================================================================

local pairs = pairs

ns.ExternalQuestDB = ns.ExternalQuestDB or {}
ns.ExternalQuestDBByExpansion = ns.ExternalQuestDBByExpansion or {}

local db = ns.ExternalQuestDB
local byExpansion = ns.ExternalQuestDBByExpansion

--- Merge a generated quest data table into the static database.
--- Called once per shipped Data/QuestDB file.
---@param source table<number, table>  questID -> quest record
function ns:RegisterQuestData(source)
    if type(source) ~= "table" then return end

    for questID, questData in pairs(source) do
        if type(questID) == "number" and type(questData) == "table" then
            db[questID] = questData

            local expansionID = questData.expansion
            if type(expansionID) == "number" then
                byExpansion[expansionID] = byExpansion[expansionID] or {}
                byExpansion[expansionID][questID] = questData
            end
        end
    end
end
