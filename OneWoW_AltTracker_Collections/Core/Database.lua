local addonName, ns = ...
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
local DB = OneWoW_GUI.DB

DB:InitSubModule("OneWoW_AltTracker_Collections_DB")

ns.DatabaseDefaults = {
    characters = {},
    settings = {
        enableDataCollection = true,
    },
    version = 4,
}

function ns:InitializeDatabase()
    if not OneWoW_AltTracker_Collections_DB.characters then
        OneWoW_AltTracker_Collections_DB.characters = {}
    end

    if not OneWoW_AltTracker_Collections_DB.settings then
        OneWoW_AltTracker_Collections_DB.settings = ns.DatabaseDefaults.settings
    end

    local currentVersion = OneWoW_AltTracker_Collections_DB.version or 1

    if currentVersion < 4 then
        OneWoW_AltTracker_Collections_DB.account = nil
        for _, charData in pairs(OneWoW_AltTracker_Collections_DB.characters) do
            charData.petsMounts = nil
            if charData.reputations and charData.reputations.factions then
                for _, faction in ipairs(charData.reputations.factions) do
                    faction.description = nil
                end
            end
        end
    end

    OneWoW_AltTracker_Collections_DB.version = 4
end
