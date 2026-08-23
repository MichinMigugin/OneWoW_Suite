local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

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

--- Refresh live bountiful delve doors for this week. Does not build the journal loot cache.
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

--- Rebuilds the static journal cache. Does not scrape live EJ for every instance.
function OneWoW_CatalogData_Journal_API.RefreshLiveJournalLoot()
    ns.JournalData:ClearCache()
    ns.JournalData:BuildJournalCache()
end

--- Hydrate loot for one journal card. Idempotent. Skeleton cards stay cheap until this runs.
---@param inst table
---@return table inst
function OneWoW_CatalogData_Journal_API.EnsureEncounters(inst)
    return ns.JournalData:EnsureEncounters(inst)
end

--- Scan one journal card against live EJ (names and scaled links only).
---@param inst table
function OneWoW_CatalogData_Journal_API.MergeInstance(inst)
    ns.EJLiveLoot:MergeInstance(inst)
end

--- Card to refresh when EJ loot data arrives. Pass nil to ignore those events.
---@param inst table|nil
function OneWoW_CatalogData_Journal_API.SetLiveMergeTarget(inst)
    ns.EJLiveLoot:SetMergeTarget(inst)
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

--- Zone / city card for a UiMap ID.
---@param expansionID number|nil
---@param mapID number
---@return table|nil instanceData
function OneWoW_CatalogData_Journal_API.GetZoneInstance(expansionID, mapID)
    return ns.JournalData:GetZoneInstance(expansionID, mapID)
end

--- All instance cards for a world map ID (dual remakes may return multiple).
---@param mapID number
---@return table instances
function OneWoW_CatalogData_Journal_API.GetInstancesByMapID(mapID)
    return ns.JournalData:GetInstancesByMapID(mapID)
end

--- Flat itemID -> localized name for every journal drop (Adventure Guide plus
--- extras). Offline: does not depend on the client's item cache. Callers walk it
--- directly so they keep their own yield cadence.
---@return table<number, string>
function OneWoW_CatalogData_Journal_API.GetItemNameIndex()
    return ns.JournalData:GetItemNameIndex()
end

--- Instance / encounter names for every place an item drops.
---@param itemID number
---@return table drops array of { instanceID, instanceName, encounterName, difficulties }
function OneWoW_CatalogData_Journal_API.GetItemDropLocations(itemID)
    return ns.JournalData:GetItemDropLocations(itemID)
end

--- Append unseen ATT extras onto a card if AllTheThings is already loaded.
---@param inst table
---@return boolean added
function OneWoW_CatalogData_Journal_API.MergeLiveATTExtras(inst)
    return ns.JournalData:MergeLiveATTExtras(inst)
end

--- Localized creature name from npcID, or nil until the client cache fills.
---@param npcID number
---@return string|nil name
function OneWoW_CatalogData_Journal_API.ResolveNPCName(npcID)
    return ns.JournalData.ResolveNPCName(npcID)
end

local tinsert = tinsert
local pendingNPCNames = {}

local function CreatureHyperlink(npcID)
    return ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID)
end

local function DeliverNPCName(npcID, name)
    local cbs = pendingNPCNames[npcID]
    if not cbs then return end
    pendingNPCNames[npcID] = nil
    local info = name and { name = name } or nil
    for i = 1, #cbs do
        xpcall(cbs[i], CallErrorHandler, npcID, info)
    end
end

local npcNameFrame = CreateFrame("Frame")
npcNameFrame:RegisterEvent("TOOLTIP_DATA_UPDATE")
npcNameFrame:SetScript("OnEvent", function()
    if not next(pendingNPCNames) then return end
    for npcID, cbs in pairs(pendingNPCNames) do
        local name = ns.JournalData.ResolveNPCName(npcID)
        if name then
            pendingNPCNames[npcID] = nil
            local info = { name = name }
            for i = 1, #cbs do
                xpcall(cbs[i], CallErrorHandler, npcID, info)
            end
        end
    end
end)

local function RequestNPCName(npcID, cb)
    local name = ns.JournalData.ResolveNPCName(npcID)
    if name then
        cb(npcID, { name = name })
        return
    end
    C_TooltipInfo.GetHyperlink(CreatureHyperlink(npcID))
    local list = pendingNPCNames[npcID]
    if not list then
        list = {}
        pendingNPCNames[npcID] = list
        C_Timer.After(1, function()
            if pendingNPCNames[npcID] then
                DeliverNPCName(npcID, ns.JournalData.ResolveNPCName(npcID))
            end
        end)
    end
    tinsert(list, cb)
end

OneWoW_GUI:RegisterEntityResolver("npc", {
    Resolve = function(id)
        return ns.JournalData.ResolveNPCName(id)
    end,
    RequestAsync = RequestNPCName,
})
