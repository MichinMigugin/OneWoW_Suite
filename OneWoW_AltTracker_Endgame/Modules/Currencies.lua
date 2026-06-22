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

    local sourceIDs = OneWoW_AltTracker_API.GetProgressList("trackedCurrencyIDs")

    for _, id in ipairs(sourceIDs) do
        if id and id > 0 and not seen[id] then
            table.insert(idsToCollect, id)
            seen[id] = true
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
