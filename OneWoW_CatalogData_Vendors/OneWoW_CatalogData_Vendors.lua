local addonName, ns = ...

_G.OneWoW_CatalogData_Vendors = ns

OneWoW_CatalogData_Vendors_API = {
    GetSettings = function()
        return ns:GetSettings()
    end,
    GetVendor = function(npcID)
        return ns.VendorData:GetVendor(npcID)
    end,
    GetAllVendors = function()
        return ns.VendorData:GetAllVendors()
    end,
    SearchVendors = function(term)
        return ns.VendorData:SearchVendors(term)
    end,
    GetSortedVendors = function(term)
        return ns.VendorData:GetSortedVendors(term)
    end,
    GetVendorsByItem = function(itemID)
        return ns.VendorData:GetVendorsByItem(itemID)
    end,
    GetStats = function()
        return ns.VendorData:GetStats()
    end,
    RegisterScanCallback = function(fn)
        ns:RegisterScanCallback(fn)
    end,
    GetCachedItem = function(itemID)
        return ns.DataLoader:GetCachedItem(itemID)
    end,
    LoadItemData = function(itemID, callback)
        return ns.DataLoader:LoadItemData(itemID, callback)
    end,
    CreateWaypoint = function(vendor, mapID)
        return ns.VendorData:CreateWaypoint(vendor, mapID)
    end,
}
