-- OneWoW Addon File
-- OneWoW_CatalogData_Journal/OneWoW_CatalogData_Journal.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

_G.OneWoW_CatalogData_Journal = ns

OneWoW_CatalogData_Journal_API = {
    GetSettings = function()
        return ns:GetSettings()
    end,
    GetSortedInstances = function(expansionFilter, searchText, instanceTypeFilter)
        return ns.JournalData:GetSortedInstances(expansionFilter, searchText, instanceTypeFilter)
    end,
    GetAvailableExpansions = function()
        return ns.JournalData:GetAvailableExpansions()
    end,
    DetermineItemStatus = function(itemID, itemData, specialType)
        return ns.JournalData:DetermineItemStatus(itemID, itemData, specialType)
    end,
    IsItemCollected = function(itemID, itemData, specialType)
        return ns.JournalData:IsItemCollected(itemID, itemData, specialType)
    end,
    ClearCache = function()
        ns.JournalData:ClearCache()
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
}
