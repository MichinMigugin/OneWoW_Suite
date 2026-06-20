local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

ns.db = DB:InitSubModule("OneWoW_AltTracker_Professions_DB")

ns.DatabaseDefaults = {
    characters = {},
    settings = {
        enableDataCollection = true,
        trackRecipes = true,
        trackEquipment = true,
    },
}

-- Defaults applied by BootStore (MergeMissing) before this runs, so only the
-- char-key normalizer remains here.
function ns:InitializeDatabase()
    local migrated = DB:ConsolidateCharacterKeys(ns.db.characters)
    if migrated > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW AltTracker:|r consolidated " .. migrated .. " duplicate character key(s) in professions data.")
        end)
    end
end
