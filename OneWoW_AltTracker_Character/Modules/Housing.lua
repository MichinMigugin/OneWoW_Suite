local _, ns = ...

-- ============================================================================
-- Housing (account-wide, collection only)
-- ============================================================================
-- Writes OneWoW_AltTracker_Character_DB.account.housing. No interiors.
-- Keep this file small so it can move to its own load unit later.
-- ============================================================================

ns.Housing = {}
local Module = ns.Housing

local function SlimHouse(info)
    local guid = info.houseGUID
    local row = {
        houseGuid = guid,
        houseName = info.houseName,
        neighborhoodName = info.neighborhoodName,
        neighborhoodGuid = info.neighborhoodGUID,
        plotId = info.plotID,
    }
    if guid then
        local favor = C_Housing.GetCurrentHouseLevelFavor(guid)
        if favor then
            row.level = favor.houseLevel
            row.favor = favor.houseFavor
        end
    end
    return row
end

function Module:CollectAccount()
    local account = ns:GetAccountBucket()
    local houses = {}
    local owned = C_Housing.GetPlayerOwnedHouses()
    if type(owned) == "table" then
        if owned.houseGUID or owned.houseName then
            houses[#houses + 1] = SlimHouse(owned)
        else
            for i = 1, #owned do
                local info = owned[i]
                if type(info) == "table" then
                    houses[#houses + 1] = SlimHouse(info)
                end
            end
        end
    end

    local current = C_Housing.GetCurrentHouseInfo()
    local currentSlim = nil
    if current then
        currentSlim = SlimHouse(current)
    end

    local first = houses[1] or currentSlim
    local total, exempt = C_HousingCatalog.GetDecorTotalOwnedCount()

    account.housing = {
        collectedAt = time(),
        hasAccess = C_Housing.HasHousingExpansionAccess(),
        houses = houses,
        current = currentSlim,
        weekly = {
            favor = first and first.favor or 0,
            level = first and first.level or 0,
        },
        ownedDecorCount = total,
        ownedDecorExempt = exempt,
        ownedDecorMax = C_HousingCatalog.GetDecorMaxOwnedCount(),
    }
    return true
end
