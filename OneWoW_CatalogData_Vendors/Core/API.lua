local _, ns = ...

-- Public, cross-addon read surface for the Vendors data store. ns stays private.
OneWoW_CatalogData_Vendors_API = {}

--- Returns the vendor store settings.
---@return table settings
function OneWoW_CatalogData_Vendors_API.GetSettings()
    return ns:GetSettings()
end

--- Returns one vendor record by NPC ID.
---@param npcID number
---@return table|nil vendor
function OneWoW_CatalogData_Vendors_API.GetVendor(npcID)
    return ns.VendorData:GetVendor(npcID)
end

--- All vendors keyed by NPC ID.
---@return table vendors
function OneWoW_CatalogData_Vendors_API.GetAllVendors()
    return ns.VendorData:GetAllVendors()
end

--- Search vendors by name or item text.
---@param term string
---@return table results
function OneWoW_CatalogData_Vendors_API.SearchVendors(term)
    return ns.VendorData:SearchVendors(term)
end

--- Vendors sorted for list display, optionally filtered by search term.
---@param term string|nil
---@return table vendors
function OneWoW_CatalogData_Vendors_API.GetSortedVendors(term)
    return ns.VendorData:GetSortedVendors(term)
end

--- Vendors that sell a given item.
---@param itemID number
---@return table vendors
function OneWoW_CatalogData_Vendors_API.GetVendorsByItem(itemID)
    return ns.VendorData:GetVendorsByItem(itemID)
end

--- Aggregate vendor-store statistics.
---@return table stats
function OneWoW_CatalogData_Vendors_API.GetStats()
    return ns.VendorData:GetStats()
end

--- Expansions that have at least one vendor row, for the Vendors filter.
---@return table expansions { { id, name }, ... } sorted by id
function OneWoW_CatalogData_Vendors_API.GetAvailableExpansions()
    return ns.VendorData:GetAvailableExpansions()
end

--- Sets the user category for a vendor NPC.
---@param npcID number
---@param categoryKey string|nil
function OneWoW_CatalogData_Vendors_API.SetCategory(npcID, categoryKey)
    return ns.VendorData:SetCategory(npcID, categoryKey)
end

--- Register a listener invoked after vendor scan data updates.
---@param fn fun()|nil
function OneWoW_CatalogData_Vendors_API.RegisterScanCallback(fn)
    ns:RegisterScanCallback(fn)
end

--- Cached NPC name from tooltip resolution or a merchant scan.
---@param npcID number
---@return string|nil name
function OneWoW_CatalogData_Vendors_API.GetCachedNPCName(npcID)
    return ns:GetDB().nameCache[npcID]
end

--- Persist a resolved NPC name for later overlay.
---@param npcID number
---@param name string
function OneWoW_CatalogData_Vendors_API.RememberNPCName(npcID, name)
    if not npcID or not name or name == "" then return end
    ns:GetDB().nameCache[npcID] = name
end

--- Cached item-data entry from this store's item loader.
---@param itemID number
---@return table|nil cached
function OneWoW_CatalogData_Vendors_API.GetCachedItem(itemID)
    return ns.DataLoader:GetCachedItem(itemID)
end

--- Loads item data asynchronously via this store's item loader.
---@param itemID number
---@param callback fun(itemID: number, result: table|nil)|nil
---@return table|nil cached synchronous result when already cached
function OneWoW_CatalogData_Vendors_API.LoadItemData(itemID, callback)
    return ns.DataLoader:LoadItemData(itemID, callback)
end

--- Creates a map waypoint for a vendor on the given map.
---@param vendor table
---@param mapID number|nil
---@return boolean created
function OneWoW_CatalogData_Vendors_API.CreateWaypoint(vendor, mapID)
    return ns.VendorData:CreateWaypoint(vendor, mapID)
end
