local _, ns = ...

-- Public, cross-addon read surface for the Journal data store. ns stays private.
OneWoW_CatalogData_Journal_API = {}

--- Returns the journal store settings.
---@return table settings
function OneWoW_CatalogData_Journal_API.GetSettings()
    return ns:GetSettings()
end

--- Returns instances sorted and filtered for the Catalog journal tab.
---@param expansionFilter number|nil
---@param searchText string|nil
---@param instanceTypeFilter string|nil
---@return table instances
function OneWoW_CatalogData_Journal_API.GetSortedInstances(expansionFilter, searchText, instanceTypeFilter)
    return ns.JournalData:GetSortedInstances(expansionFilter, searchText, instanceTypeFilter)
end

--- Returns expansion IDs available for journal filtering.
---@return table expansions
function OneWoW_CatalogData_Journal_API.GetAvailableExpansions()
    return ns.JournalData:GetAvailableExpansions()
end

--- Determines collection status metadata for a journal loot item.
---@param itemID number
---@param itemData table|nil
---@param specialType string|nil
---@return string|nil status
function OneWoW_CatalogData_Journal_API.DetermineItemStatus(itemID, itemData, specialType)
    return ns.JournalData:DetermineItemStatus(itemID, itemData, specialType)
end

--- Whether a journal loot item is collected for the current character.
---@param itemID number
---@param itemData table|nil
---@param specialType string|nil
---@return boolean collected
function OneWoW_CatalogData_Journal_API.IsItemCollected(itemID, itemData, specialType)
    return ns.JournalData:IsItemCollected(itemID, itemData, specialType)
end

--- Clears the in-memory journal loot cache.
function OneWoW_CatalogData_Journal_API.ClearCache()
    ns.JournalData:ClearCache()
end

--- Rebuilds live encounter-journal loot after clearing the cache.
function OneWoW_CatalogData_Journal_API.RefreshLiveJournalLoot()
    ns.JournalData:ClearCache()
    ns.JournalData:BuildJournalCache()
end

--- Register a listener invoked after journal scan data updates.
---@param fn fun()|nil
function OneWoW_CatalogData_Journal_API.RegisterScanCallback(fn)
    ns:RegisterScanCallback(fn)
end

--- Cached item-data entry from this store's item loader.
---@param itemID number
---@return table|nil cached
function OneWoW_CatalogData_Journal_API.GetCachedItem(itemID)
    return ns.DataLoader:GetCachedItem(itemID)
end

--- Loads item data asynchronously via this store's item loader.
---@param itemID number
---@param callback fun(itemID: number, result: table|nil)|nil
---@return table|nil cached synchronous result when already cached
function OneWoW_CatalogData_Journal_API.LoadItemData(itemID, callback)
    return ns.DataLoader:LoadItemData(itemID, callback)
end

--- Scaled loot hyperlink for a journal encounter item (difficulty-aware).
---@param instanceID number
---@param encounterID number
---@param diffID number
---@param itemID number
---@return string|nil link
function OneWoW_CatalogData_Journal_API.GetScaledLootLink(instanceID, encounterID, diffID, itemID)
    return ns.EJLiveLoot:GetScaledLootLink(instanceID, encounterID, diffID, itemID)
end

--- Ensures the journal cache is built and returns the instance for a world map ID.
---@param mapID number
---@return table|nil instanceData
function OneWoW_CatalogData_Journal_API.GetInstanceByMapID(mapID)
    ns.JournalData:BuildJournalCache()
    local cache = ns.JournalData.journalCache
    if not cache then return nil end
    for _, data in pairs(cache) do
        if data.mapID == mapID then
            return data
        end
    end
    return nil
end
