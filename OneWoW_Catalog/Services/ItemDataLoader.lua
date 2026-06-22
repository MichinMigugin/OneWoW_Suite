local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB

-- Factory for item data loading with async callback queue.
-- Eliminates per-addon DataLoader duplication. Pass the addon's DB table
-- (the one with an itemCache sub-table). Returns a loader object.
---@class ItemDataLoader
---@field _db table Database to store cached items
---@field _pending table Database to store items where data needs to be retrieved

---@param dbTable table
---@return ItemDataLoader
function ns.CreateItemDataLoader(dbTable)
    if not dbTable or type(dbTable) ~= "table" then
        error("CreateItemDataLoader requires a dbTable table", 2)
    end

    DB:Ensure(dbTable, "itemCache")

    local loader = {
        _db = dbTable,
        _pending = {}
    }

    -- Deferred on purpose: callers register callbacks while building UI rows
    -- (CreateItemRow / ShowItemDetail) and the callbacks rebuild those same
    -- regions; firing synchronously would recurse into the row constructors.
    function loader:FireCallbacks(callbacks, itemID, result)
        if not callbacks then return end

        C_Timer.After(0, function()
            for _, cb in ipairs(callbacks) do
                -- Isolate registrants: one failing callback must not abort the
                -- rest, and the error still reaches the global error handler.
                xpcall(cb, CallErrorHandler, itemID, result)
            end
        end)
    end

    function loader:GetTooltipItemName(itemID)
        local tooltipData = C_TooltipInfo.GetItemByID(itemID)
        if not tooltipData or not tooltipData.lines then
            return nil
        end

        for _, line in ipairs(tooltipData.lines) do
            local text = line.leftText
            -- RETRIEVING_ITEM_INFO is the locale-correct placeholder Blizzard
            -- shows on the first tooltip line while an item is uncached.
            if text and text ~= "" and text ~= RETRIEVING_ITEM_INFO then
                return text
            end
        end

        return nil
    end

    function loader:ResolveItemData(itemID)
        local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)

        if not name then
            name = C_Item.GetItemNameByID(itemID)
        end

        if not name then
            name = self:GetTooltipItemName(itemID)
        end

        if not icon then
            icon = select(5, C_Item.GetItemInfoInstant(itemID))
        end

        return name, link, quality, icon
    end

    function loader:GetCachedItem(itemID)
        return self._db.itemCache[itemID] or nil
    end

    -- Cache entries are persisted to SavedVariables and short-circuit every
    -- future LoadItemData call, so only fully-resolved data may be written.
    -- Partial resolutions (name via GetItemNameByID / tooltip scan, but no
    -- link or quality) would otherwise be frozen in permanently.
    local function IsCompleteItemData(name, link, quality, icon)
        return name ~= nil and link ~= nil and quality ~= nil and icon ~= nil
    end

    function loader:CacheItem(itemID, name, quality, icon, link)
        self._db.itemCache[itemID] = {
            name    = name,
            quality = quality or 1,
            icon    = icon or 134400,
            link    = link,
        }

        return self._db.itemCache[itemID]
    end

    function loader:LoadItemData(itemID, callback)
        local cached = self:GetCachedItem(itemID)
        if cached and cached.name then
            if callback then self:FireCallbacks({ callback }, itemID, cached) end
            return cached
        end

        local name, link, quality, icon = self:ResolveItemData(itemID)
        if IsCompleteItemData(name, link, quality, icon) then
            local result = self:CacheItem(itemID, name, quality, icon, link)
            if callback then self:FireCallbacks({ callback }, itemID, result) end
            return result
        end

        -- Partial resolution: surface what we have for display now, but keep
        -- the request pending so the callback fires again (and the cache is
        -- written) once the full data arrives.
        if name and callback then
            self:FireCallbacks({ callback }, itemID,
                { name = name, quality = quality, icon = icon, link = link })
        end

        if not self._pending[itemID] then
            self._pending[itemID] = {}
        end
        if callback then
            self._pending[itemID][#self._pending[itemID] + 1] = callback
        end

        C_Item.RequestLoadItemDataByID(itemID)

        return nil
    end

    function loader:Initialize()
        -- One-time self-heal: drop incomplete entries persisted before the
        -- completeness guard existed (name-only resolutions have no link).
        local cache = self._db.itemCache
        for itemID, entry in pairs(cache) do
            if type(entry) ~= "table" or not entry.name or not entry.link then
                cache[itemID] = nil
            end
        end

        local frame = CreateFrame("Frame")
        frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
        frame:SetScript("OnEvent", function(_, _, loadedItemID, success)
            if not success then return end
            local callbacks = self._pending[loadedItemID]
            if not callbacks then return end
            local name, link, quality, icon = self:ResolveItemData(loadedItemID)
            if IsCompleteItemData(name, link, quality, icon) then
                local result = self:CacheItem(loadedItemID, name, quality, icon, link)
                self:FireCallbacks(callbacks, loadedItemID, result)
            elseif name then
                -- Loaded but still missing fields: deliver for display without
                -- persisting a partial entry.
                self:FireCallbacks(callbacks, loadedItemID,
                    { name = name, quality = quality, icon = icon, link = link })
            end
            self._pending[loadedItemID] = nil
        end)
    end

    return loader
end

local sharedLoader = nil

--- Catalog's shared loader instance, backed by the addon db handle.
--- Lazily created: the db handle only exists after OnAddonLoaded, and UI code
--- runs strictly after that. CatalogData store addons keep their own loader
--- instances on their own DBs; this one serves Catalog's own tabs.
---@return ItemDataLoader
function ns.GetItemDataLoader()
    if not sharedLoader then
        sharedLoader = ns.CreateItemDataLoader(ns.db.global)
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
