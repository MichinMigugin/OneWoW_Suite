local _, ns = ...

ns.VendorData = {}
local VendorData = ns.VendorData

local pairs = pairs
local tinsert, sort = tinsert, sort
local C_Map = C_Map
local Location = OneWoW.Location

-- Vendor locations are stored as 0-100.
local PERCENT_COORDS = { format = "percent" }

local function CopyItemEntry(itemData)
    local copy = {}
    for key, value in pairs(itemData) do
        copy[key] = value
    end
    return copy
end

local function CopyItems(src)
    if not src then return {} end
    local out = {}
    for itemID, itemData in pairs(src) do
        out[itemID] = CopyItemEntry(itemData)
    end
    return out
end

local function FillZoneName(mapID, loc)
    if loc.zone and loc.zone ~= "" then return end
    local info = C_Map.GetMapInfo(mapID)
    if info and info.name then
        loc.zone = info.name
    end
end

local function CopyOneLocation(mapID, loc)
    local copy = {
        zone = loc.zone,
        subzone = loc.subzone,
        x = loc.x,
        y = loc.y,
        source = loc.source,
        mapID = mapID,
    }
    FillZoneName(mapID, copy)
    return copy
end

local function CopyLocations(src)
    if not src then return {} end
    local out = {}
    for mapID, loc in pairs(src) do
        out[mapID] = CopyOneLocation(mapID, loc)
    end
    return out
end

local function UnionItems(staticItems, liveItems)
    local out = CopyItems(staticItems)
    if liveItems then
        for itemID, itemData in pairs(liveItems) do
            out[itemID] = CopyItemEntry(itemData)
        end
    end
    return out
end

local function UnionLocations(staticLocs, liveLocs)
    local out = CopyLocations(staticLocs)
    if liveLocs then
        for mapID, loc in pairs(liveLocs) do
            out[mapID] = CopyOneLocation(mapID, loc)
        end
    end
    return out
end

-- Overlay static NpcDB onto a live SavedVariables row (or static-only).
-- Does not write static fields into SavedVariables; callers that persist
-- (scan / SetCategory) copy what they need.
local function OverlayVendor(npcID, live)
    local static = ns.StaticVendors and ns.StaticVendors[npcID]
    if not live and not static then return nil end

    local db = ns:GetDB()
    if not live then
        local vendor = {
            npcID = npcID,
            name = db.nameCache[npcID],
            expansion = static.expansion,
            displayID = static.displayID,
            subtitle = static.subtitle,
            category = static.category,
            roles = static.roles,
            items = CopyItems(static.items),
            locations = CopyLocations(static.locations),
            isStaticOnly = true,
        }
        return vendor
    end

    if not static then
        if live.locations then
            for mapID, loc in pairs(live.locations) do
                loc.mapID = mapID
                FillZoneName(mapID, loc)
            end
        end
        return live
    end

    -- Player Uncategorized is intentional: do not restore a shipped type.
    local category
    if live.categorySource == "user" then
        category = live.category
    else
        category = live.category
        if not category or category == "" then
            category = static.category
        end
    end

    local expansion = static.expansion
    if live.expansion ~= nil then
        expansion = live.expansion
    end

    return {
        npcID = npcID,
        name = (live.name and live.name ~= "") and live.name or db.nameCache[npcID],
        expansion = expansion,
        displayID = (live.displayID and live.displayID > 0) and live.displayID or static.displayID,
        subtitle = (live.subtitle and live.subtitle ~= "") and live.subtitle or static.subtitle,
        creatureType = live.creatureType,
        classification = live.classification,
        level = live.level,
        category = category,
        categorySource = live.categorySource,
        roles = live.roles or static.roles,
        items = UnionItems(static.items, live.items),
        locations = UnionLocations(static.locations, live.locations),
        firstSeen = live.firstSeen,
        lastScanned = live.lastScanned,
        scanCount = live.scanCount,
        isStaticOnly = false,
    }
end

function VendorData:GetVendor(npcID)
    local db = ns:GetDB()
    local live = db.vendors and db.vendors[npcID]
    return OverlayVendor(npcID, live)
end

function VendorData:GetAllVendors()
    local db = ns:GetDB()
    local result = {}
    if db.vendors then
        for npcID, live in pairs(db.vendors) do
            result[npcID] = OverlayVendor(npcID, live)
        end
    end
    if ns.StaticVendors then
        for npcID in pairs(ns.StaticVendors) do
            if not result[npcID] then
                result[npcID] = OverlayVendor(npcID, nil)
            end
        end
    end
    return result
end

function VendorData:GetVendorCount()
    local count = 0
    for _ in pairs(self:GetAllVendors()) do
        count = count + 1
    end
    return count
end

function VendorData:SearchVendors(searchTerm)
    if not searchTerm or searchTerm == "" then
        return self:GetAllVendors()
    end

    local results = {}
    local term = searchTerm:lower()

    for npcID, vendor in pairs(self:GetAllVendors()) do
        local matched = false

        if vendor.name and vendor.name:lower():find(term, 1, true) then
            matched = true
        end

        if not matched and vendor.locations then
            for _, loc in pairs(vendor.locations) do
                if loc.zone and loc.zone:lower():find(term, 1, true) then
                    matched = true
                    break
                end
                if loc.subzone and loc.subzone:lower():find(term, 1, true) then
                    matched = true
                    break
                end
            end
        end

        if not matched then
            local idStr = tostring(npcID)
            if idStr:find(term, 1, true) then
                matched = true
            end
        end

        if matched then
            results[npcID] = vendor
        end
    end

    return results
end

function VendorData:GetVendorsByItem(itemID)
    local results = {}
    local seen = {}

    for npcID, vendor in pairs(self:GetAllVendors()) do
        if vendor.items and vendor.items[itemID] then
            tinsert(results, vendor)
            seen[npcID] = true
        end
    end

    if ns.StaticVendorItems and ns.StaticVendorItems[itemID] then
        for npcID in pairs(ns.StaticVendorItems[itemID].vendors) do
            if not seen[npcID] then
                local vendor = self:GetVendor(npcID)
                if vendor then
                    tinsert(results, vendor)
                end
            end
        end
    end

    return results
end

function VendorData:GetUniqueItemCount()
    local items = {}
    for _, vendor in pairs(self:GetAllVendors()) do
        if vendor.items then
            for itemID in pairs(vendor.items) do
                items[itemID] = true
            end
        end
    end
    local count = 0
    for _ in pairs(items) do count = count + 1 end
    return count
end

function VendorData:GetAvailableExpansions()
    local found = {}
    for _, vendor in pairs(self:GetAllVendors()) do
        if vendor.expansion ~= nil then
            found[vendor.expansion] = true
        end
    end
    local result = {}
    for expID in pairs(found) do
        local name = OneWoW:GetExpansionName(expID)
        if name then
            tinsert(result, {
                id = expID,
                name = name,
            })
        end
    end
    sort(result, function(a, b)
        return a.id < b.id
    end)
    return result
end

function VendorData:GetStats()
    local staticVendors = 0
    local staticItems = 0
    if ns.StaticVendors then
        for _ in pairs(ns.StaticVendors) do staticVendors = staticVendors + 1 end
    end
    if ns.StaticVendorItems then
        for _ in pairs(ns.StaticVendorItems) do staticItems = staticItems + 1 end
    end
    return {
        vendorCount = self:GetVendorCount(),
        uniqueItems = self:GetUniqueItemCount(),
        staticVendors = staticVendors,
        staticItems = staticItems,
    }
end

function VendorData:DeleteVendor(npcID)
    local db = ns:GetDB()
    if db.vendors and db.vendors[npcID] then
        db.vendors[npcID] = nil
        return true
    end
    return false
end

function VendorData:GetSortedVendors(searchTerm)
    local vendors = searchTerm and self:SearchVendors(searchTerm) or self:GetAllVendors()
    local sorted = {}
    for _, vendor in pairs(vendors) do
        tinsert(sorted, vendor)
    end
    sort(sorted, function(a, b)
        if a.lastScanned and not b.lastScanned then return true end
        if not a.lastScanned and b.lastScanned then return false end
        if a.lastScanned and b.lastScanned then
            return a.lastScanned > b.lastScanned
        end
        return (a.npcID or 0) < (b.npcID or 0)
    end)
    return sorted
end

function VendorData:CreateWaypoint(vendor, mapID)
    if not vendor or not vendor.locations then return false end

    local location = mapID and vendor.locations[mapID]
    if not location then
        for mID, loc in pairs(vendor.locations) do
            location = loc
            mapID = mID
            break
        end
    end

    if not location or not mapID then return false end

    return Location.SetWaypoint(mapID, location.x or 0, location.y or 0, PERCENT_COORDS)
end

function VendorData:GetItemCount(npcID)
    local vendor = self:GetVendor(npcID)
    if not vendor or not vendor.items then return 0 end
    local count = 0
    for _ in pairs(vendor.items) do count = count + 1 end
    return count
end

function VendorData:GetPrimaryLocation(vendor)
    if not vendor or not vendor.locations then return nil, nil end
    for mapID, loc in pairs(vendor.locations) do
        return mapID, loc
    end
    return nil, nil
end

function VendorData:GetLocationCount(vendor)
    if not vendor or not vendor.locations then return 0 end
    local count = 0
    for _ in pairs(vendor.locations) do count = count + 1 end
    return count
end

function VendorData:GetCategory(npcID)
    local vendor = self:GetVendor(npcID)
    return vendor and vendor.category
end

-- Sets (or clears, when categoryKey is nil/empty) the user-assigned category
-- for a vendor. If the vendor exists only in the static NpcDB, a minimal
-- record is materialized so the category can be persisted.
-- Clearing keeps categorySource = "user" so overlay does not restore a shipped
-- type; Uncategorized and General stay visitable (scan may replace them).
-- Any other player type is sticky.
---@param npcID number
---@param categoryKey string|nil
---@return boolean
function VendorData:SetCategory(npcID, categoryKey)
    if not npcID then return false end
    local db = ns:GetDB()
    if not db.vendors then db.vendors = {} end

    local vendor = db.vendors[npcID]
    if not vendor then
        local static = ns.StaticVendors and ns.StaticVendors[npcID]
        vendor = {
            npcID = npcID,
            name  = db.nameCache[npcID],
            items = CopyItems(static and static.items),
            locations = CopyLocations(static and static.locations),
            expansion = static and static.expansion,
            displayID = static and static.displayID,
            roles = static and static.roles,
        }
        db.vendors[npcID] = vendor
    end

    if not categoryKey or categoryKey == "" then
        vendor.category = nil
        vendor.categorySource = "user"
    else
        vendor.category = categoryKey
        vendor.categorySource = "user"
    end
    return true
end
