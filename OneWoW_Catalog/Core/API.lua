local _, ns = ...

-- Public, cross-addon read surface for the Catalog hub. ns stays private.
OneWoW_Catalog_API = {}

--- Returns Catalog's shared asynchronous item-data loader.
---@return table loader
function OneWoW_Catalog_API.GetItemDataLoader()
    return ns.GetItemDataLoader()
end

--- Look up a cached item name from Catalog's item cache.
---@param itemID number
---@return string|nil
function OneWoW_Catalog_API.GetCachedItemName(itemID)
    return ns.GetCachedItemName(itemID)
end

--- Record an item name into Catalog's item cache.
---@param itemID number
---@param itemName string
---@return boolean changed
function OneWoW_Catalog_API.RememberItemName(itemID, itemName)
    return ns.RememberItemName(itemID, itemName)
end

--- Toggle the Catalog module in the suite hub.
function OneWoW_Catalog_API.Toggle()
    OneWoW.UI:Toggle()
end

--- Open the item search tab, optionally focused on one item.
---@param itemID number|nil
---@param itemName string|nil
---@param retryCount number|nil
function OneWoW_Catalog_API.OpenItemSearch(itemID, itemName, retryCount)
    if ns.UI and ns.UI.OpenItemSearch then
        ns.UI.OpenItemSearch(itemID, itemName, retryCount)
    end
end

--- Open the quests tab focused on a quest.
---@param questID number
function OneWoW_Catalog_API.OpenQuest(questID)
    if ns.UI and ns.UI.OpenQuest then
        ns.UI.OpenQuest(questID)
    end
end

--- Open the quests tab with zone and/or NPC filters applied.
---@param opts { zoneName?: string, npcID?: number, npcName?: string }
function OneWoW_Catalog_API.OpenQuestsFiltered(opts)
    if ns.UI and ns.UI.OpenQuestsFiltered then
        ns.UI.OpenQuestsFiltered(opts)
    end
end

--- Open the vendors tab focused on an NPC vendor.
---@param npcID number
function OneWoW_Catalog_API.OpenToVendor(npcID)
    if ns.UI and ns.UI.OpenToVendor then
        ns.UI.OpenToVendor(npcID)
    end
end

--- Open the Zones (Journal) tab on a place. Number is mapID; table may carry
--- instanceID / placeKey / encounterID.
---@param spec number|table
function OneWoW_Catalog_API.OpenToInstance(spec)
    if ns.UI and ns.UI.OpenToInstance then
        ns.UI.OpenToInstance(spec)
    end
end

--- Refresh the quests list when the quests tab UI is loaded.
function OneWoW_Catalog_API.RefreshQuestsList()
    if ns.UI and ns.UI.RefreshQuestsList then
        ns.UI.RefreshQuestsList(true)
    end
end

--- Resolve a pack role or addon name to the CatDB addon Catalog will load.
---@param roleOrName string
---@return string|nil
function OneWoW_Catalog_API.ResolveCatalogPack(roleOrName)
    return OneWoW:ResolveCatalogPack(roleOrName)
end

--- Cross-unit API table for the resolved pack (`AddonName_API`).
---@param roleOrName string
---@return table|nil
function OneWoW_Catalog_API.GetCatalogPackAPI(roleOrName)
    return OneWoW:GetCatalogPackAPI(roleOrName)
end

--- EnsureLoaded the resolved pack. Explicit user actions only.
---@param roleOrName string
---@return string|nil
function OneWoW_Catalog_API.EnsureCatalogPack(roleOrName)
    return OneWoW:EnsureCatalogPack(roleOrName)
end
