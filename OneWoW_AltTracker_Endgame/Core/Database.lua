local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
local DB = OneWoW_GUI.DB

DB:InitSubModule("OneWoW_AltTracker_Endgame_DB")

ns.DatabaseDefaults = {
    characters = {},
    settings = {
        enableDataCollection = true,
    },
    version = 1,
}

function ns:InitializeDatabase()
    if not OneWoW_AltTracker_Endgame_DB.characters then
        OneWoW_AltTracker_Endgame_DB.characters = {}
    end

    if not OneWoW_AltTracker_Endgame_DB.settings then
        OneWoW_AltTracker_Endgame_DB.settings = ns.DatabaseDefaults.settings
    end

    if not OneWoW_AltTracker_Endgame_DB.version then
        OneWoW_AltTracker_Endgame_DB.version = ns.DatabaseDefaults.version
    end

    if not OneWoW_AltTracker_Endgame_DB.charKeysCanonicalized then
        local migrated = DB:ConsolidateCharacterKeys(OneWoW_AltTracker_Endgame_DB.characters)
        OneWoW_AltTracker_Endgame_DB.charKeysCanonicalized = true
        if migrated > 0 then
            C_Timer.After(5, function()
                print("|cFFFFD100OneWoW AltTracker:|r consolidated " .. migrated .. " legacy character key(s) in endgame data.")
            end)
        end
    end
end
