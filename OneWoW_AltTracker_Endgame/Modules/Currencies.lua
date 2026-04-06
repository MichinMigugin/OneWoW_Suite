-- OneWoW AltTracker Addon File
-- OneWoW_AltTracker_Endgame/Modules/Currencies.lua
-- Created by MichinMigugin (Ricky)
local addonName, ns = ...

ns.Currencies = {}
local Module = ns.Currencies

local DEFAULT_CURRENCY_IDS = {2914, 2915, 2916, 2917, 3008}

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local currencyData = {
        tracked = {},
        lastUpdated = time(),
    }

    local idsToCollect = {}
    local seen = {}

    if _G.OneWoW_AltTracker_DB and
       _G.OneWoW_AltTracker_DB.global and
       _G.OneWoW_AltTracker_DB.global.overrides and
       _G.OneWoW_AltTracker_DB.global.overrides.progress and
       _G.OneWoW_AltTracker_DB.global.overrides.progress.trackedCurrencyIDs then
        for _, id in ipairs(_G.OneWoW_AltTracker_DB.global.overrides.progress.trackedCurrencyIDs) do
            if id and id > 0 and not seen[id] then
                table.insert(idsToCollect, id)
                seen[id] = true
            end
        end
    end

    if #idsToCollect == 0 then
        for _, id in ipairs(DEFAULT_CURRENCY_IDS) do
            if not seen[id] then
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
