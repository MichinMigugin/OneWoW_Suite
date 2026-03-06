local addonName, ns = ...

ns.DataLoader = {}
local DataLoader = ns.DataLoader

local pendingItems = {}
local nameQueue = {}
local totalNamesResolved = 0

function DataLoader:GetCachedItem(itemID)
    local db = OneWoW_CatalogData_Vendors_DB
    if db.itemCache and db.itemCache[itemID] then
        return db.itemCache[itemID]
    end
    return nil
end

function DataLoader:CacheItem(itemID, name, quality, icon)
    local db = OneWoW_CatalogData_Vendors_DB
    if not db.itemCache then db.itemCache = {} end
    db.itemCache[itemID] = {
        name = name,
        quality = quality or 1,
        icon = icon or 0,
    }
end

function DataLoader:LoadItemData(itemID, callback)
    local cached = self:GetCachedItem(itemID)
    if cached and cached.name then
        if callback then callback(itemID, cached) end
        return cached
    end

    local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    if name then
        self:CacheItem(itemID, name, quality, icon)
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

function DataLoader:GetCachedNPCName(npcID)
    local db = OneWoW_CatalogData_Vendors_DB
    return db.nameCache and db.nameCache[npcID]
end

function DataLoader:ResolveVendorNames()
    if not ns.StaticVendors then return end
    local db = OneWoW_CatalogData_Vendors_DB
    if not db.nameCache then db.nameCache = {} end

    for npcID in pairs(ns.StaticVendors) do
        if not db.nameCache[npcID] then
            table.insert(nameQueue, npcID)
        end
    end

    if #nameQueue > 0 then
        C_Timer.After(2, function()
            DataLoader:ProcessNameQueue()
        end)
    end
end

function DataLoader:ProcessNameQueue()
    local db = OneWoW_CatalogData_Vendors_DB

    for i = 1, 20 do
        local npcID = table.remove(nameQueue, 1)
        if not npcID then break end

        local tooltipData = C_TooltipInfo.GetHyperlink(
            string.format("unit:Creature-0-0-0-0-%d-0000000000", npcID)
        )

        if tooltipData and tooltipData.lines and tooltipData.lines[1] then
            local name = tooltipData.lines[1].leftText
            if name and name ~= "" and not name:find("Retrieving") then
                db.nameCache[npcID] = name
                totalNamesResolved = totalNamesResolved + 1
            end
        end
    end

    if #nameQueue > 0 then
        C_Timer.After(0.05, function()
            DataLoader:ProcessNameQueue()
        end)
    else
        if totalNamesResolved > 0 then
            ns:FireScanCallbacks(nil)
        end
        totalNamesResolved = 0
    end
end

function DataLoader:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    frame:SetScript("OnEvent", function(_, event, itemID, success)
        if event == "ITEM_DATA_LOAD_RESULT" and success then
            if pendingItems[itemID] then
                local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
                if name then
                    DataLoader:CacheItem(itemID, name, quality, icon)
                    for _, cb in ipairs(pendingItems[itemID]) do
                        pcall(cb, itemID, DataLoader:GetCachedItem(itemID))
                    end
                    pendingItems[itemID] = nil
                end
            end
        end
    end)

    self:ResolveVendorNames()
end
