local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

-- Factory for item data loading with async callback queue.
-- Eliminates per-addon DataLoader duplication. Pass the addon's DB table
-- (the one with an itemCache sub-table). Returns a loader object.
---@class ItemDataLoader
---@field _db table Database to store cached items
---@field _pending table Database to store items where data needs to be retrieved

---@param dbTable table
---@return ItemDataLoader
function OneWoW_Catalog:CreateItemDataLoader(dbTable)
    if not dbTable or type(dbTable) ~= "table" then
        error("CreateItemDataLoader requires a dbTable table", 2)
    end

    DB:Ensure(dbTable, "itemCache")

    local loader = {
        _db = dbTable,
        _pending = {}
    }

    function loader:FireCallbacks(callbacks, itemID, result)
        if not callbacks then return end

        C_Timer.After(0, function()
            for _, cb in ipairs(callbacks) do
                cb(itemID, result)
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
            if text and text ~= "" and not text:find("Retrieving", 1, true) then
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
        if name then
            local result = self:CacheItem(itemID, name, quality, icon, link)
            if callback then self:FireCallbacks({ callback }, itemID, result) end
            return result
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
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
        frame:SetScript("OnEvent", function(_, _, loadedItemID, success)
            if not success then return end
            local callbacks = self._pending[loadedItemID]
            if not callbacks then return end
            local name, link, quality, icon = self:ResolveItemData(loadedItemID)
            if name then
                local result = self:CacheItem(loadedItemID, name, quality, icon, link)
                self:FireCallbacks(callbacks, loadedItemID, result)
            end
            self._pending[loadedItemID] = nil
        end)
    end

    return loader
end
