local _, ns = ...
local L = ns.L

local Items = ns.DataModule:New("items", "itemCustomCategories", {
    "General", "Transmog", "Crafting", "Quest", "Rare", "Collectible"
})
ns.Items = Items

Items.GetNotesDB = Items.GetDataDB
Items.GetAllItems = Items.GetAll

function Items:GetItem(itemID)
    if not itemID then return nil end
    itemID = tonumber(itemID)
    if not itemID then return nil end
    return self:GetAll()[itemID]
end

function Items:GetKnownItemName(itemID)
    if not itemID then return nil end
    itemID = tonumber(itemID)
    if not itemID then return nil end

    local itemData = self:GetItem(itemID)
    if itemData and itemData.name and itemData.name ~= "" then
        return itemData.name
    end

    local itemCache =
        OneWoW_Catalog_DB
        and OneWoW_Catalog_DB.global
        and OneWoW_Catalog_DB.global.itemCache

    local entry = itemCache and itemCache[itemID]
    if type(entry) == "table" then
        return entry.name
    end
    return entry
end

function Items:AddItem(itemID, itemData)
    if not itemID or not itemData then return false end
    itemID = tonumber(itemID)
    if not itemID then return false end

    local addon = OneWoW_Notes

    local existing = self:GetItem(itemID)
    if existing then
        for k, v in pairs(itemData) do existing[k] = v end
        existing.lastSeen = GetServerTime()
        self:SaveItem(itemID, existing)
        return true
    end

    local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, _, itemTexture = C_Item.GetItemInfo(itemID)
    itemName = itemName or itemData.name or self:GetKnownItemName(itemID)

    if not itemName then
        return false, L["NOTES_ITEM_INVALID_ID"] or "Invalid item ID"
    end

    local newItemData = {
        itemID       = itemID,
        name         = itemName,
        link         = itemLink or itemData.link,
        icon         = itemTexture or itemData.icon,
        level        = itemLevel or itemData.level,
        rarity       = itemRarity or itemData.rarity or itemData.quality or 1,
        type         = itemType or itemData.type,
        subType      = itemSubType or itemData.subType,
        category     = itemData.category or "General",
        storage      = itemData.storage or "account",
        content      = itemData.content or itemData.text or "",
        created      = itemData.created or GetServerTime(),
        modified     = itemData.modified or GetServerTime(),
        tooltipLines = itemData.tooltipLines or {"", "", "", ""},
        alertOnLoot  = itemData.alertOnLoot or false,
        favorite     = itemData.favorite or false,
        lastSeen     = GetServerTime(),
    }

    for k, v in pairs(itemData) do
        if k ~= "text" then newItemData[k] = v end
    end

    if addon.mainFrame and addon.mainFrame:IsShown() then
        newItemData.isNew = true
        newItemData.newTimestamp = GetServerTime()
    end

    self:SaveItem(itemID, newItemData)
    self:InvalidateCache()
    return true
end

function Items:SaveItem(itemID, itemData)
    if not itemID or not itemData then return end
    itemID = tonumber(itemID)
    if not itemID then return end

    local addon = OneWoW_Notes
    local storageType = itemData.storage or "account"
    itemData.modified = GetServerTime()

    if storageType == "character" then
        addon.db.char.items[itemID] = itemData
    else
        addon.db.global.items[itemID] = itemData
    end

    self:InvalidateCache()
end

function Items:RemoveItem(itemID)
    if not itemID then return end
    itemID = tonumber(itemID)
    if not itemID then return end
    self:Remove(itemID)
end
