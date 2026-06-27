local _, ns = ...

ns.AHScanCoordinator = ns.AHScanCoordinator or {}
local Coord = ns.AHScanCoordinator

local scanInProgress = false

function Coord:IsScanning()
    return scanInProgress
end

function Coord:StartFullScan(callback)
    if scanInProgress then return false end
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return false end
    if not ns.AHReplicateScanner then return false end

    local canScan = select(1, ns.AHPriceCache:CanFullScan())
    if not canScan then return false end

    scanInProgress = true

    local started = ns.AHReplicateScanner:StartScan(function(status, progress, extra)
        if status == "scanCompleted" or status == "scanStopped" or status == "scanFailed" then
            scanInProgress = false
        end
        if callback then
            callback(status, progress, extra)
        end
    end)

    if not started then
        scanInProgress = false
    end
    return started
end

function Coord:StopFullScan()
    if ns.AHReplicateScanner then
        ns.AHReplicateScanner:StopScan()
    end
    scanInProgress = false
end

function Coord:CanFullScan()
    return ns.AHPriceCache:CanFullScan()
end

function Coord:StartTargetedScan(itemKeys, callback)
    if not ns.AHTargetedScanner then return false end
    return ns.AHTargetedScanner:StartScan(itemKeys, callback)
end

function Coord:OnAuctionHouseClosed()
    if scanInProgress and ns.AHReplicateScanner then
        ns.AHReplicateScanner:AbortScan()
    end
    scanInProgress = false
end
