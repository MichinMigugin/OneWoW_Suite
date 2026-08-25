local _, ns = ...

-- ============================================================================
-- QuestDBLoader (Archive)
-- ============================================================================
-- Same registrar as the hot Quests pack. Shards call ns:RegisterQuestData;
-- Core.lua then imports the merged table into OneWoW_CatalogData_Quests_API.
-- ============================================================================

local pairs = pairs

ns.ExternalQuestDB = ns.ExternalQuestDB or {}
ns.ExternalQuestDBByExpansion = ns.ExternalQuestDBByExpansion or {}

local db = ns.ExternalQuestDB
local byExpansion = ns.ExternalQuestDBByExpansion

--- Merge a generated quest data table into the archive database.
---@param source table<number, table>
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
