-- OneWoW AltTracker Addon File
-- OneWoW_AltTracker_Endgame/Modules/Currencies.lua
-- Created by MichinMigugin (Ricky)
local _, ns = ...

ns.Currencies = {}
local Module = ns.Currencies

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local currencyData = {
        tracked = {},
        lastUpdated = time(),
    }

    local idsToCollect = {}
    local seen = {}

    if OneWoW_AltTracker_DB and
       OneWoW_AltTracker_DB.global and
       OneWoW_AltTracker_DB.global.overrides and
       OneWoW_AltTracker_DB.global.overrides.progress and
       OneWoW_AltTracker_DB.global.overrides.progress.trackedCurrencyIDs then
        for _, id in ipairs(OneWoW_AltTracker_DB.global.overrides.progress.trackedCurrencyIDs) do
            if id and id > 0 and not seen[id] then
                table.insert(idsToCollect, id)
                seen[id] = true
            end
        end
    end

    for _, currencyID in ipairs(idsToCollect) do
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info then
            currencyData.tracked[currencyID] = {
                id = currencyID,
                name = info.name,
                quantity = info.quantity,
                maxQuantity = info.maxQuantity,
                maxWeeklyQuantity = info.maxWeeklyQuantity,
                quantityEarnedThisWeek = info.quantityEarnedThisWeek,
                iconFileID = info.iconFileID,
            }
        end
    end

    charData.currencies = currencyData
    return true
end
