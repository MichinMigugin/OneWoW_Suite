local _, ns = ...

-- Public, cross-addon control surface for the Auctions unit (AH price cache +
-- full-market scan). ns stays private.
OneWoW_AltTracker_Auctions_API = {}

--- Start a full auction-house replicate scan (whole-market price snapshot).
---@param callback fun(status:string, progress:number?, extra:number?)|nil
---@return boolean started
function OneWoW_AltTracker_Auctions_API.StartFullScan(callback)
    return ns.AHScanCoordinator:StartFullScan(callback)
end

function OneWoW_AltTracker_Auctions_API.StopFullScan()
    ns.AHScanCoordinator:StopFullScan()
end

---@return boolean canScan
---@return number minutesRemaining
function OneWoW_AltTracker_Auctions_API.CanFullScan()
    return ns.AHScanCoordinator:CanFullScan()
end

---@param itemID number
---@param itemLink string|nil
---@return { price: number, timestamp: number, dbKey: string }|nil
function OneWoW_AltTracker_Auctions_API.GetPrice(itemID, itemLink)
    if not itemID then return nil end
    local row, dbKey = ns.AHPriceCache:LookupPrice(itemID, itemLink)
    if not row then return nil end
    return {
        price = row.price,
        timestamp = row.timestamp,
        dbKey = dbKey,
    }
end

---@param speciesID number
---@return { price: number, timestamp: number, dbKey: string }|nil
function OneWoW_AltTracker_Auctions_API.GetPriceForSpecies(speciesID)
    if not speciesID then return nil end
    local row, dbKey = ns.AHPriceCache:LookupSpeciesPrice(speciesID)
    if not row then return nil end
    return {
        price = row.price,
        timestamp = row.timestamp,
        dbKey = dbKey,
    }
end

---@return { lastFullScanAt: number, lastFullScanItemCount: number, realmID: number }
function OneWoW_AltTracker_Auctions_API.GetScanMeta()
    return ns.AHPriceCache:GetScanMeta()
end

--- Phase 2 targeted refresh for specific item keys.
---@param itemKeys table
---@param callback fun(status:string, progress:number?, extra:any?)|nil
---@return boolean started
function OneWoW_AltTracker_Auctions_API.StartTargetedScan(itemKeys, callback)
    return ns.AHScanCoordinator:StartTargetedScan(itemKeys, callback)
end

---@return table characters
function OneWoW_AltTracker_Auctions_API.GetCharacters()
    return OneWoW_AltTracker_Auctions_DB.characters
end
