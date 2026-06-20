local _, ns = ...
local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

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
}

-- Defaults (characters / warbandBank / guildBanks / settings) are applied by
-- BootStore via DB:MergeMissing before this runs, so only one-time bridges and
-- the ongoing char-key normalizer live here.
function ns:InitializeDatabase()
    -- Merge legacy "Name - Realm" duplicates into canonical keys. Idempotent.
    local migrated = DB:ConsolidateCharacterKeys(OneWoW_AltTracker_Storage_DB.characters)
    if migrated > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW AltTracker:|r consolidated " .. migrated .. " duplicate character key(s) in storage data.")
        end)
    end

    -- One-time cleanup of stale/corrupt mail rows. Flag-gated; runs once.
    if not OneWoW_AltTracker_Storage_DB.mailDataCleaned then
        local cleaned = 0
        for _, charData in pairs(OneWoW_AltTracker_Storage_DB.characters) do
            if charData.mail and charData.mail.mails then
                local toRemove = {}
                for mailID, mailData in pairs(charData.mail.mails) do
                    if mailData.isAwaitingCollection then
                        table.insert(toRemove, mailID)
                        cleaned = cleaned + 1
                    elseif mailData.items then
                        for _, itemData in pairs(mailData.items) do
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
