local addonName, ns = ...

ns.VendorData = {}
local VendorData = ns.VendorData

local staticIndex = nil
local function BuildStaticIndex()
    if staticIndex then return end
    staticIndex = {}
    if ns.StaticVendorItems then
        for itemID, itemData in pairs(ns.StaticVendorItems) do
            for npcID in pairs(itemData.vendors) do
                if not staticIndex[npcID] then
                    staticIndex[npcID] = {}
                end
                staticIndex[npcID][itemID] = {}
            end
        end
    end
end

function VendorData:GetVendor(npcID)
    local db = OneWoW_CatalogData_Vendors_DB
    return db.vendors and db.vendors[npcID]
end

function VendorData:GetAllVendors()
    BuildStaticIndex()
    local db = OneWoW_CatalogData_Vendors_DB
    local result = {}
    local seen = {}
    if db.vendors then
        for npcID, vendor in pairs(db.vendors) do
            result[npcID] = vendor
            seen[npcID] = true
        end
    end
    for npcID, items in pairs(staticIndex) do
        if not seen[npcID] then
            result[npcID] = { npcID = npcID, name = db.nameCache and db.nameCache[npcID], items = items, isStaticOnly = true }
        end
    end
    return result
end

function VendorData:GetVendorCount()
    local count = 0
    local db = OneWoW_CatalogData_Vendors_DB
    if db.vendors then
        for _ in pairs(db.vendors) do
            count = count + 1
        end
    end
    return count
end

function VendorData:SearchVendors(searchTerm)
    if not searchTerm or searchTerm == "" then
        return self:GetAllVendors()
    end

    BuildStaticIndex()
    local results = {}
    local db = OneWoW_CatalogData_Vendors_DB
    local seen = {}
    local term = searchTerm:lower()

    if db.vendors then
        for npcID, vendor in pairs(db.vendors) do
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
                seen[npcID] = true
            end
        end
    end

    for npcID, items in pairs(staticIndex) do
        if not seen[npcID] then
            local cachedName = db.nameCache and db.nameCache[npcID]
            local matched = false
            if cachedName and cachedName:lower():find(term, 1, true) then
                matched = true
            end
            if not matched and tostring(npcID):find(term, 1, true) then
                matched = true
            end
            if matched then
                results[npcID] = { npcID = npcID, name = cachedName, items = items, isStaticOnly = true }
            end
        end
    end

    return results
end

function VendorData:GetVendorsByItem(itemID)
    local results = {}
    local db = OneWoW_CatalogData_Vendors_DB
    local seen = {}

    if db.vendors then
        for npcID, vendor in pairs(db.vendors) do
            if vendor.items and vendor.items[itemID] then
                table.insert(results, vendor)
                seen[npcID] = true
            end
        end
    end

    if ns.StaticVendorItems and ns.StaticVendorItems[itemID] then
        BuildStaticIndex()
        for npcID in pairs(ns.StaticVendorItems[itemID].vendors) do
            if not seen[npcID] then
                local liveVendor = db.vendors and db.vendors[npcID]
                if liveVendor then
                    table.insert(results, liveVendor)
                else
                    table.insert(results, { npcID = npcID, items = staticIndex[npcID] or {}, isStaticOnly = true })
                end
                seen[npcID] = true
            end
        end
    end

    return results
end

function VendorData:GetUniqueItemCount()
    local items = {}
    local db = OneWoW_CatalogData_Vendors_DB
    if not db.vendors then return 0 end

    for _, vendor in pairs(db.vendors) do
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
    local db = OneWoW_CatalogData_Vendors_DB
    if db.vendors and db.vendors[npcID] then
        db.vendors[npcID] = nil
        return true
    end
    return false
end

function VendorData:GetSortedVendors(searchTerm)
    local vendors = searchTerm and self:SearchVendors(searchTerm) or self:GetAllVendors()
    local sorted = {}
    for npcID, vendor in pairs(vendors) do
        table.insert(sorted, vendor)
    end
    table.sort(sorted, function(a, b)
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

    local x = (location.x or 0) / 100
    local y = (location.y or 0) / 100

    if C_Map and C_Map.SetUserWaypoint then
        local uiMapPoint = UiMapPoint.CreateFromCoordinates(mapID, x, y)
        C_Map.SetUserWaypoint(uiMapPoint)
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        return true
    end

    return false
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
