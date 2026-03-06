-- OneWoW Addon File
-- OneWoW_CatalogData_Journal/Modules/DataLoader.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.DataLoader = {}
local DataLoader = ns.DataLoader

local pendingItems = {}

function DataLoader:GetCachedItem(itemID)
    local db = OneWoW_CatalogData_Journal_DB
    if db.itemCache and db.itemCache[itemID] then
        return db.itemCache[itemID]
    end
    return nil
end

function DataLoader:CacheItem(itemID, name, quality, icon, link)
    local db = OneWoW_CatalogData_Journal_DB
    if not db.itemCache then db.itemCache = {} end
    db.itemCache[itemID] = {
        name    = name,
        quality = quality or 1,
        icon    = icon or 134400,
        link    = link,
    }
end

function DataLoader:LoadItemData(itemID, callback)
    local cached = self:GetCachedItem(itemID)
    if cached and cached.name then
        if callback then callback(itemID, cached) end
        return cached
    end

    local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    if name then
        self:CacheItem(itemID, name, quality, icon, link)
        if callback then callback(itemID, self:GetCachedItem(itemID)) end
        return self:GetCachedItem(itemID)
    end

    C_Item.RequestLoadItemDataByID(itemID)
    if not pendingItems[itemID] then
        pendingItems[itemID] = {}
    end
    if callback then
        table.insert(pendingItems[itemID], callback)
    end

    return nil
end

function DataLoader:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    frame:SetScript("OnEvent", function(_, event, itemID, success)
        if event == "ITEM_DATA_LOAD_RESULT" and success then
            if pendingItems[itemID] then
                local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
                if name then
                    DataLoader:CacheItem(itemID, name, quality, icon, link)
                    for _, cb in ipairs(pendingItems[itemID]) do
                        pcall(cb, itemID, DataLoader:GetCachedItem(itemID))
                    end
                    pendingItems[itemID] = nil
                end
            end
        end
    end)
end
