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
---@param typeFilter string|nil
---@return table expansions
function OneWoW_CatalogData_Journal_API.GetAvailableExpansions(typeFilter)
    return ns.JournalData:GetAvailableExpansions(typeFilter)
end

--- Refresh live bountiful delve doors for this week.
function OneWoW_CatalogData_Journal_API.RefreshBountiful()
    ns.JournalData:RefreshBountiful()
end

--- Whether this delve map is bountiful on the current weekly rotation.
---@param mapID number|nil
---@return boolean
function OneWoW_CatalogData_Journal_API.IsDelveBountiful(mapID)
    return ns.JournalData:IsDelveBountiful(mapID)
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

--- Preferred instance card for a world map ID (highest expansionID when dual-listed).
---@param mapID number
---@return table|nil instanceData
function OneWoW_CatalogData_Journal_API.GetInstanceByMapID(mapID)
    return ns.JournalData:GetInstanceByMapID(mapID)
end

--- All instance cards for a world map ID (dual remakes may return multiple).
---@param mapID number
---@return table instances
function OneWoW_CatalogData_Journal_API.GetInstancesByMapID(mapID)
    return ns.JournalData:GetInstancesByMapID(mapID)
end

--- Whether live EJ loot merge has finished for the current cache.
---@return boolean
function OneWoW_CatalogData_Journal_API.IsLiveMergeComplete()
    return ns.EJLiveLoot and ns.EJLiveLoot.ejMergeComplete == true
end
