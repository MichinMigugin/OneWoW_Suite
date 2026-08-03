local _, ns = ...

-- Consumes the core OneWoW.Merchant funnel instead of owning a private
-- MERCHANT_* frame. Core builds the debounced, retry-backed vendor snapshot;
-- this module merges it into the store's SavedVariables and re-fans through the
-- store's own _API.RegisterScanCallback for Catalog UI compat. The vendor
-- "enabled" setting is a subscription decision (subscribe / UnregisterCallback),
-- never a handler-side gate -- see OneWoW/Docs/MERCHANT.md.

ns.VendorScanner = {}
local VendorScanner = ns.VendorScanner

local OneWoW = OneWoW

local pairs, time = pairs, time

local OWNER_ID = "CatalogData_Vendors"

local function ApplyScanCategory(vendor, scan)
    -- User-assigned types are never overwritten. Existing category with no
    -- source is grandfathered as user (pre-categorySource SavedVariables).
    if vendor.categorySource == "user" then
        return
    end
    if vendor.category and not vendor.categorySource then
        vendor.categorySource = "user"
        return
    end

    local key = ns.VendorCategoryMap.Resolve(scan.subtitle, scan.canRepair)
    if key then
        vendor.category = key
        vendor.categorySource = "scan"
    end
end

-- Merge one ephemeral snapshot from the core funnel into the vendor DB. Item
-- entries arrive in persist shape (cost, limited, maxStack, isPurchasable,
-- isUsable, lastSeen, currencies), so they merge directly.
function VendorScanner:MergeScanIntoDB(scan)
    if not scan or not scan.npcID or scan.npcID == 0 then return end

    local db = ns:GetDB()
    if not db.vendors then db.vendors = {} end

    local npcID = scan.npcID
    local name = scan.name or ""
    local location = scan.location
    local now = time()

    local existing = db.vendors[npcID]
    if existing then
        if name ~= "" then existing.name = name end
        existing.creatureType = scan.creatureType
        existing.classification = scan.classification
        existing.level = scan.level
        existing.lastScanned = now
        existing.scanCount = (existing.scanCount or 0) + 1

        if scan.displayID and scan.displayID > 0 then
            existing.displayID = scan.displayID
        end
        if scan.subtitle and scan.subtitle ~= "" then
            existing.subtitle = scan.subtitle
        end

        if location and location.mapID then
            if not existing.locations then existing.locations = {} end
            existing.locations[location.mapID] = {
                zone = location.zone,
                subzone = location.subzone,
                x = location.x,
                y = location.y,
            }
        end

        if not existing.items then existing.items = {} end
        for itemID, itemData in pairs(scan.items) do
            existing.items[itemID] = itemData
        end

        ApplyScanCategory(existing, scan)
    else
        local locations = {}
        if location and location.mapID then
            locations[location.mapID] = {
                zone = location.zone,
                subzone = location.subzone,
                x = location.x,
                y = location.y,
            }
        end

        local vendor = {
            name = name,
            npcID = npcID,
            locations = locations,
            creatureType = scan.creatureType,
            classification = scan.classification,
            level = scan.level,
            displayID = (scan.displayID and scan.displayID > 0) and scan.displayID or nil,
            subtitle = (scan.subtitle and scan.subtitle ~= "") and scan.subtitle or nil,
            items = scan.items,
            firstSeen = now,
            lastScanned = now,
            scanCount = 1,
        }
        db.vendors[npcID] = vendor
        ApplyScanCategory(vendor, scan)
    end

    if name ~= "" then
        if not db.nameCache then db.nameCache = {} end
        db.nameCache[npcID] = name
    end

    -- Secondary fan-out for Catalog UI (_API.RegisterScanCallback), fired after
    -- the DB merge with the same payload shape as before (the vendor record).
    ns:FireScanCallbacks(db.vendors[npcID])
end

-- Reconcile the core subscription with the "enabled" setting. Called at login
-- and safe to call again from a future settings toggle: toggling off drops the
-- subscription (may take core to 0 subscribers → events unregistered), toggling
-- on re-subscribes (0→1 catch-up scans an already-open merchant).
function VendorScanner:ApplySubscription()
    local settings = ns:GetSettings()
    if settings and settings.enabled == false then
        OneWoW.Merchant.UnregisterCallback(OWNER_ID)
    else
        OneWoW.Merchant.RegisterScanCallback(OWNER_ID, function(scan)
            VendorScanner:MergeScanIntoDB(scan)
        end)
    end
end

function VendorScanner:Initialize()
    self:ApplySubscription()
end
