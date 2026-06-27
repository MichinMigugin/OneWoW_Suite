local _, ns = ...

-- Public, cross-addon control surface for the Auctions unit (AH price cache +
-- full-market scan). ns stays private.
OneWoW_AltTracker_Auctions_API = {}

--- Start a full auction-house replicate scan (whole-market price snapshot).
--- Requires an open auction house. The callback receives progress events:
--- ("scanStarted", 0), ("scanWaiting", 0.1, elapsed), ("scanProgress", frac,
--- total?), ("scanCompleted", 1.0, found), ("scanStopped"), ("scanFailed").
---@param callback fun(status:string, progress:number?, extra:number?)|nil
---@return boolean started false if already scanning or the AH is not open
function OneWoW_AltTracker_Auctions_API.StartFullScan(callback)
    return ns.FullAHScanner:StartScan(callback)
end

--- Stop the in-progress full auction-house scan, if any.
function OneWoW_AltTracker_Auctions_API.StopFullScan()
    ns.FullAHScanner:StopScan()
end

--- Whether a full scan is allowed now (cooldown-gated).
---@return boolean canScan
---@return number minutesRemaining 0 when canScan is true
function OneWoW_AltTracker_Auctions_API.CanFullScan()
    return ns.FullAHScanner:CanScan()
end

--- Cached auction-house price entry for a single item from OneWoW's own AH scan
--- (the Auctions unit owns the `OneWoW_AHPrices` store). Returns the raw record
--- so callers can read both the price and its capture timestamp.
---@param itemID number
---@return { price: number, timestamp: number }|nil entry nil if no cached price
function OneWoW_AltTracker_Auctions_API.GetByItemID(itemID)
    if not itemID or not OneWoW_AHPrices then return nil end
    return OneWoW_AHPrices[itemID]
end

--- All characters with stored auction data, keyed by character key. Read-only
--- iteration surface for the hub's item/auction rollups (each entry carries
--- `activeAuctions`, `lastAuctionUpdate`, …).
---@return table characters map of charKey -> stored auction data
function OneWoW_AltTracker_Auctions_API.GetCharacters()
    return OneWoW_AltTracker_Auctions_DB.characters
end
