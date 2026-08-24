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

local function CopyItemEntry(itemData)
    local copy = {}
    for key, value in pairs(itemData) do
        copy[key] = value
    end
    return copy
end

-- Live scan is a filtered merchant window. Union static stock and other-map
-- pins so a visit never deletes shipped rows the current window hid.
local function UnionStaticInto(vendor, npcID)
    local static = ns.StaticVendors and ns.StaticVendors[npcID]
    if not static then return end

    if vendor.expansion == nil then
        vendor.expansion = static.expansion
    end
    if (not vendor.displayID or vendor.displayID == 0) and static.displayID then
        vendor.displayID = static.displayID
    end
    if not vendor.roles then
        vendor.roles = static.roles
    end

    if static.items then
        if not vendor.items then vendor.items = {} end
        for itemID, itemData in pairs(static.items) do
            if not vendor.items[itemID] then
                vendor.items[itemID] = CopyItemEntry(itemData)
            end
        end
    end

    if static.locations then
        if not vendor.locations then vendor.locations = {} end
        for mapID, loc in pairs(static.locations) do
            if not vendor.locations[mapID] then
                vendor.locations[mapID] = {
                    zone = loc.zone,
                    subzone = loc.subzone,
                    x = loc.x,
                    y = loc.y,
                }
            end
        end
    end
end

local OWNER_ID = "CatalogData_Vendors"

-- Uncategorized and General stay visitable, even when the player set them.
local function IsOpenCategory(key)
    return not key or key == "" or key == "general"
end

-- Scan sees the live row, which may not have copied static.category yet.
local function EffectiveCategory(npcID, live)
    if live.categorySource == "user" then
        return live.category, "user"
    end
    if live.category and live.category ~= "" then
        return live.category, live.categorySource or "static"
    end
    local static = ns.StaticVendors and ns.StaticVendors[npcID]
    if static and static.category then
        return static.category, "static"
    end
    return nil, nil
end

-- Visit fills Uncategorized / General. Decor we set may only move to another
-- special (never General). Other specials we set stay. Non-specials we set
-- (pet, repair, ...) may only upgrade to a special. Player types other than
-- General / Uncategorized never change.
local function ApplyScanCategory(vendor, scan, npcID)
    local current, source = EffectiveCategory(npcID, vendor)
    if source == "user" and not IsOpenCategory(current) then
        return
    end

    local resolved = ns.VendorCategoryMap.Resolve(scan.subtitle, scan.canRepair)
    if not resolved or resolved == current then
        return
    end

    local incomingSpecial = ns.VendorCategoryMap.IsSpecial(resolved)
    local currentSpecial = ns.VendorCategoryMap.IsSpecial(current)

    if IsOpenCategory(current) then
        vendor.category = resolved
        vendor.categorySource = "scan"
        return
    end

    if current == "decor" then
        if incomingSpecial and resolved ~= "decor" then
            vendor.category = resolved
            vendor.categorySource = "scan"
        end
        return
    end

    if currentSpecial then
        return
    end

    if incomingSpecial then
        vendor.category = resolved
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

        ApplyScanCategory(existing, scan, npcID)
        UnionStaticInto(existing, npcID)
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
        ApplyScanCategory(vendor, scan, npcID)
        UnionStaticInto(vendor, npcID)
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
