local addonName, ns = ...

ns.PVP = {}
local Module = ns.PVP

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local pvpData = {
        honorLevel = UnitHonorLevel("player"),
        lifetimeStats = {
            honorableKills = GetPVPLifetimeStats() or 0,
            kills = 0,
            deaths = 0,
        },
        season = {
            -- Remove old DB entries (2026-04-27)
            arena2v2 = nil,
            arena3v3 = nil,
            rbg = nil,
        },
        currencies = {},
        lastUpdated = time(),
    }

    -- New DB entries are stored by tierID and rely on CONQUEST_BRACKET_NAMES rather than a manually-created table
    for tierID, tierName in pairs(CONQUEST_BRACKET_NAMES) do
        local rating, seasonBest, weeklyBest, seasonPlayed, seasonWon, weeklyPlayed, weeklyWon, cap = GetPersonalRatedInfo(tierID)
        pvpData.season[tierID] = {
            tierID = tierID,
            tierName = tierName,
            rating = rating,
            seasonBest = seasonBest,
            weeklyBest = weeklyBest,
            seasonPlayed = seasonPlayed,
            seasonWon = seasonWon,
            weeklyPlayed = weeklyPlayed,
            weeklyWon = weeklyWon,
            cap = cap
        }
     end

    local honorInfo = C_CurrencyInfo.GetCurrencyInfo(1792)
    if honorInfo then
        pvpData.currencies.honor = {
            id = honorInfo.currencyID,
            name = honorInfo.name,
            quantity = honorInfo.quantity,
            maxQuantity = honorInfo.maxQuantity,
            iconFileID = honorInfo.iconFileID,
        }
    end

    local conquestInfo = C_CurrencyInfo.GetCurrencyInfo(1602)
    if conquestInfo then
        pvpData.currencies.conquest = {
            id = conquestInfo.currencyID,
            name = conquestInfo.name,
            quantity = conquestInfo.quantity,
            maxQuantity = conquestInfo.maxQuantity,
            maxWeeklyQuantity = conquestInfo.maxWeeklyQuantity,
            quantityEarnedThisWeek = conquestInfo.quantityEarnedThisWeek,
            iconFileID = conquestInfo.iconFileID,
        }
    end

    charData.pvp = pvpData

    return true
end
