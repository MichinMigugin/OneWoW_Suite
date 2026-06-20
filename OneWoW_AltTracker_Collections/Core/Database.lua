local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

ns.DatabaseDefaults = {
    characters = {},
    settings = {
        enableDataCollection = true,
    },
}

-- Defaults applied by BootStore (MergeMissing) before this runs, so only the
-- char-key normalizer remains here.
function ns:InitializeDatabase()
    local migrated = DB:ConsolidateCharacterKeys(OneWoW_AltTracker_Collections_DB.characters)
    if migrated > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW AltTracker:|r consolidated " .. migrated .. " duplicate character key(s) in collections data.")
        end)
    end
end
