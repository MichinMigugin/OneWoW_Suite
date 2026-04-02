-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/ItemsData.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
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

function Items:AddItem(itemID, itemData)
    if not itemID or not itemData then return false end
    itemID = tonumber(itemID)
    if not itemID then return false end

    local addon = _G.OneWoW_Notes

    local existing = self:GetItem(itemID)
    if existing then
        for k, v in pairs(itemData) do existing[k] = v end
        existing.lastSeen = GetServerTime()
        self:SaveItem(itemID, existing)
        return true
    end

    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType,
          itemStackCount, itemEquipLoc, itemTexture = C_Item.GetItemInfo(itemID)

    if not itemName then
        return false, L["NOTES_ITEM_INVALID_ID"] or "Invalid item ID"
    end

    local newItemData = {
        itemID       = itemID,
        name         = itemName,
        link         = itemLink,
        icon         = itemTexture,
        level        = itemLevel,
        rarity       = itemRarity or 1,
        type         = itemType,
        subType      = itemSubType,
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

    local addon = _G.OneWoW_Notes
    local storageType = itemData.storage or "account"
    itemData.modified = GetServerTime()

    if storageType == "character" then
        if not addon.db.char.items then addon.db.char.items = {} end
        addon.db.char.items[itemID] = itemData
    else
        if not addon.db.global.items then addon.db.global.items = {} end
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
