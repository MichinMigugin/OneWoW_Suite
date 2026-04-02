local addonName, ns = ...
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
local DB = OneWoW_GUI.DB

DB:InitSubModule("OneWoW_AltTracker_Storage_DB")

ns.DatabaseDefaults = {
    characters = {},
    warbandBank = {
        tabs = {},
        lastUpdatedBy = nil,
        lastUpdateTime = 0,
    },
    guildBanks = {},
    settings = {
        enableDataCollection = true,
        trackBags = true,
        trackPersonalBank = true,
        trackWarbandBank = true,
        trackGuildBank = true,
        trackMail = true,
    },
    version = 2,
}

function ns:InitializeDatabase()
    if not OneWoW_AltTracker_Storage_DB.characters then
        OneWoW_AltTracker_Storage_DB.characters = {}
    end

    if not OneWoW_AltTracker_Storage_DB.warbandBank then
        OneWoW_AltTracker_Storage_DB.warbandBank = ns.DatabaseDefaults.warbandBank
    end

    if not OneWoW_AltTracker_Storage_DB.guildBanks then
        OneWoW_AltTracker_Storage_DB.guildBanks = {}
    end

    if not OneWoW_AltTracker_Storage_DB.settings then
        OneWoW_AltTracker_Storage_DB.settings = ns.DatabaseDefaults.settings
    end

    if not OneWoW_AltTracker_Storage_DB.version then
        OneWoW_AltTracker_Storage_DB.version = ns.DatabaseDefaults.version
    end

    if not OneWoW_AltTracker_Storage_DB.mailDataCleaned then
        local cleaned = 0
        for charKey, charData in pairs(OneWoW_AltTracker_Storage_DB.characters) do
            if charData.mail and charData.mail.mails then
                local toRemove = {}
                for mailID, mailData in pairs(charData.mail.mails) do
                    if mailData.isAwaitingCollection then
                        table.insert(toRemove, mailID)
                        cleaned = cleaned + 1
                    elseif mailData.items then
                        for attachIdx, itemData in pairs(mailData.items) do
                            if itemData.count and itemData.count > 10000 then
                                itemData.count = 1
                                cleaned = cleaned + 1
                            end
                        end
                    end
                end
                for _, mailID in ipairs(toRemove) do
                    charData.mail.mails[mailID] = nil
                end
            end
        end
        OneWoW_AltTracker_Storage_DB.mailDataCleaned = true
        if cleaned > 0 then
            C_Timer.After(5, function()
                print("|cFFFFD100OneWoW AltTracker:|r Cleaned " .. cleaned .. " corrupted or stale mail entries.")
            end)
        end
    end
end
