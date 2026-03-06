local addonName, ns = ...

ns.PVP = {}
local Module = ns.PVP

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local pvpData = {
        honorLevel = 0,
        lifetimeStats = {
            honorableKills = 0,
            kills = 0,
            deaths = 0,
        },
        season = {
            arena2v2 = {},
            arena3v3 = {},
            rbg = {},
        },
        currencies = {},
        lastUpdated = time(),
    }

    pvpData.honorLevel = UnitHonorLevel("player")

    local honorableKills, kills, deaths = GetPVPLifetimeStats()
    if honorableKills then
        pvpData.lifetimeStats.honorableKills = honorableKills
        pvpData.lifetimeStats.kills = kills or 0
        pvpData.lifetimeStats.deaths = deaths or 0
    end

    local brackets = {
        { type = 1, name = "arena2v2" },
        { type = 2, name = "arena3v3" },
        { type = 4, name = "rbg" },
    }

    for _, bracket in ipairs(brackets) do
        local tierInfo = C_PvP.GetPvpTierInfo(bracket.type)
        if tierInfo then
            pvpData.season[bracket.name].tierID = tierInfo.tierID
            pvpData.season[bracket.name].tierName = tierInfo.tierName
            pvpData.season[bracket.name].activityItemLevel = tierInfo.activityItemLevel
            pvpData.season[bracket.name].weeklyItemLevel = tierInfo.weeklyItemLevel
        end

        local seasonBest = C_PvP.GetSeasonBestInfo(bracket.type)
        if seasonBest then
            if type(seasonBest) == "table" then
                pvpData.season[bracket.name].rating = seasonBest.rating
                pvpData.season[bracket.name].tier = seasonBest.tier
            elseif type(seasonBest) == "number" then
                pvpData.season[bracket.name].rating = seasonBest
            end
        end
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
