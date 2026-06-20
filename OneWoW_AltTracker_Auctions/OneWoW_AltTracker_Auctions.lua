local _, ns = ...

-- Public, cross-addon control surface for the Auctions unit (AH price scan).
-- ns stays private.
OneWoW_AltTracker_Auctions_API = {}

--- Start an auction-house price scan over the given item list. The optional
--- callback receives progress events: ("scanStarted", 0, total),
--- ("itemScanned", done, total, found), ("scanCompleted", total, total, found),
--- ("scanStopped"), and ("ahOpened").
---@param items table[] list of { itemID:number, itemName:string?, isBound:boolean? }
---@param callback fun(status:string, current:number?, total:number?, extra:number?)|nil
---@return boolean started false if a scan is already running or the list is empty
function OneWoW_AltTracker_Auctions_API.StartScan(items, callback)
    return ns.AHScanner:StartScan(items, callback)
end

--- Stop the in-progress auction-house scan, if any.
function OneWoW_AltTracker_Auctions_API.StopScan()
    ns.AHScanner:StopScan()
end

--- Whether an auction-house scan is currently running.
---@return boolean scanning
function OneWoW_AltTracker_Auctions_API.IsScanning()
    return ns.AHScanner:IsScanning()
end

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
