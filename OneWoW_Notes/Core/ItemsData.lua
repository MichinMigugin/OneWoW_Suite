local _, ns = ...
local L = ns.L

local Items = ns.DataModule:New("items", "itemCustomCategories", {
    "General", "Transmog", "Crafting", "Quest", "Rare"
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

    local existing = self:GetItem(itemID)
    if existing then
        for k, v in pairs(itemData) do existing[k] = v end
        existing.lastSeen = GetServerTime()
        self:SaveItem(itemID, existing)
        return true
    end

    local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, _, itemTexture = C_Item.GetItemInfo(itemID)
    itemName = itemName or itemData.name or C_Item.GetItemNameByID(itemID)
    itemLink = itemLink or itemData.link
    itemTexture = itemTexture or itemData.icon
    itemRarity = itemRarity or itemData.rarity or itemData.quality
    itemLevel = itemLevel or itemData.level
    itemType = itemType or itemData.type
    itemSubType = itemSubType or itemData.subType

    if not itemName then
        return false, L["NOTES_ITEM_INVALID_ID"]
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

    self:SaveItem(itemID, newItemData)
    self:InvalidateCache()
    return true
end

function Items:SaveItem(itemID, itemData)
    if not itemID or not itemData then return end
    itemID = tonumber(itemID)
    if not itemID then return end

    local addon = ns
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

function Items:Initialize()
    if Items._lootFrame then return end

    -- Identify self-loot messages via Blizzard's own localized loot strings
    -- (plain-text prefix match, locale-safe) so we ignore other players' loot.
    local selfPrefixes = {}
    for _, g in ipairs({ LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_PUSHED_SELF, LOOT_ITEM_PUSHED_SELF_MULTIPLE }) do
        local prefix = g and g:match("^(.-)%%s")
        if prefix and prefix ~= "" then
            selfPrefixes[#selfPrefixes + 1] = prefix
        end
    end

    local f = CreateFrame("Frame")
    Items._lootFrame = f
    f:SetScript("OnEvent", function(_, _, msg)
        if not msg then return end
        if OneWoW.Restriction.IsSecret(msg) then return end

        local isSelf = false
        for _, prefix in ipairs(selfPrefixes) do
            if msg:find(prefix, 1, true) == 1 then
                isSelf = true
                break
            end
        end
        if not isSelf then return end

        local itemID = tonumber(msg:match("Hitem:(%d+)"))
        if not itemID then return end

        local itemData = Items:GetItem(itemID)
        if not itemData or not itemData.alertOnLoot then return end

        local count = tonumber(msg:match("x(%d+)%.?$")) or 1
        OneWoW.Toasts.FireItemLootAlert(itemData.name, itemData.icon, count)
    end)
    f:RegisterEvent("CHAT_MSG_LOOT")
end
