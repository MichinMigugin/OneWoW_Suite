local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

local type = type

ns.MigrationFix = {}
local MigrationFix = ns.MigrationFix

-- Consolidates cross-reference tables that key by charKey but don't live in any
-- submodule DB (so they aren't reached by the per-submodule consolidator pass).
function MigrationFix:ConsolidateCrossReferenceCharKeys()
    local total = 0
    total = total + DB:ConsolidateCharacterKeys(ns.db.global.favorites)

    if OneWoW_CatDB_QuestDBCurrent_DB and type(OneWoW_CatDB_QuestDBCurrent_DB.global) == "table" then
        total = total + DB:ConsolidateCharacterKeys(OneWoW_CatDB_QuestDBCurrent_DB.global.completion)
    end

    if total > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW AltTracker:|r consolidated " .. total .. " duplicate character key(s) across favorites / catalog data.")
        end)
    end

    return total
end
