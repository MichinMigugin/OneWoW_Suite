local _, ns = ...

local sharedLoader = nil

--- Catalog's shared loader instance, backed by the addon db handle.
--- Lazily created: the db handle only exists after OnAddonLoaded, and UI code
--- runs strictly after that. CatalogData store addons keep their own loader
--- instances on their own DBs; this one serves Catalog's own tabs.
---@return ItemDataLoader
function ns.GetItemDataLoader()
    if not sharedLoader then
        sharedLoader = OneWoW:CreateItemDataLoader(ns.db.global)
        sharedLoader:Initialize()
    end
    return sharedLoader
end

--- Look up a cached item *name* from Catalog's item cache. Returns nil when
--- Catalog has no entry (or is not initialized). Tolerates legacy string-valued
--- cache entries.
---@param itemID number
---@return string|nil
function ns.GetCachedItemName(itemID)
    itemID = tonumber(itemID)
    if not itemID or not ns.db then return nil end
    local itemCache = ns.db.global and ns.db.global.itemCache
    local cached = itemCache and itemCache[itemID]
    if type(cached) == "table" then
        return cached.name
    elseif type(cached) == "string" then
        return cached
    end
    return nil
end

--- Record an item name into Catalog's item cache, filling link/quality/icon from
--- the game the first time the item is seen. No-op (returns false) when Catalog
--- is not loaded.
---@param itemID number
---@param itemName string
---@return boolean changed true if the stored name differs from before
function ns.RememberItemName(itemID, itemName)
    itemID = tonumber(itemID)
    if not itemID or not itemName or itemName == "" or not ns.db then
        return false
    end

    ns.db.global.itemCache = ns.db.global.itemCache or {}
    local itemCache = ns.db.global.itemCache
    local previous = itemCache[itemID]
    local previousName =
        type(previous) == "table"
        and previous.name
        or previous

    if type(previous) ~= "table" then
        previous = {}
        itemCache[itemID] = previous
    end

    previous.name = itemName

    if not previous.link then
        local _, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
        previous.link = link
        previous.quality = previous.quality or quality or 1
        previous.icon = previous.icon or icon or 134400
    else
        previous.quality = previous.quality or 1
        previous.icon = previous.icon or 134400
    end

    return previousName ~= itemName
end
