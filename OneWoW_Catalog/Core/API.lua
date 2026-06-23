local _, ns = ...

-- Public, cross-addon read surface for the Catalog hub. ns stays private.
OneWoW_Catalog_API = {}

--- Registers a public data-store API with Catalog.
---@param name string
---@param dataAPI table
function OneWoW_Catalog_API.RegisterDataAddon(name, dataAPI)
    ns.Catalog:RegisterDataAddon(name, dataAPI)
end

--- Returns a registered public data-store API.
---@param name string
---@return table|nil dataAPI
function OneWoW_Catalog_API.GetDataAddon(name)
    return ns.Catalog:GetDataAddon(name)
end

--- Returns Catalog's shared asynchronous item-data loader.
---@return table loader
function OneWoW_Catalog_API.GetItemDataLoader()
    return ns.GetItemDataLoader()
end

--- Creates an asynchronous item-data loader backed by the provided database.
---@param dbTable table
---@return table loader
function OneWoW_Catalog_API.CreateItemDataLoader(dbTable)
    return ns.CreateItemDataLoader(dbTable)
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

--- Open the vendors tab focused on an NPC vendor.
---@param npcID number
function OneWoW_Catalog_API.OpenToVendor(npcID)
    if ns.UI and ns.UI.OpenToVendor then
        ns.UI.OpenToVendor(npcID)
    end
end

--- Refresh the quests list when the quests tab UI is loaded.
function OneWoW_Catalog_API.RefreshQuestsList()
    if ns.UI and ns.UI.RefreshQuestsList then
        ns.UI.RefreshQuestsList()
    end
end
