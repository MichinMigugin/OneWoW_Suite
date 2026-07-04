local _, ns = ...

ns.Equipment = {}
local Module = ns.Equipment

local INVENTORY_SLOTS = {
    HEADSLOT = 1,
    NECKSLOT = 2,
    SHOULDERSLOT = 3,
    SHIRTSLOT = 4,
    CHESTSLOT = 5,
    WAISTSLOT = 6,
    LEGSSLOT = 7,
    FEETSLOT = 8,
    WRISTSLOT = 9,
    HANDSSLOT = 10,
    FINGER0SLOT = 11,
    FINGER1SLOT = 12,
    TRINKET0SLOT = 13,
    TRINKET1SLOT = 14,
    BACKSLOT = 15,
    MAINHANDSLOT = 16,
    SECONDARYHANDSLOT = 17,
    RANGEDSLOT = 18,
    TABARDSLOT = 19,
}

-- Same link parsing as OneWoW_QoL charinfo (item:id:enchant:gem1:gem2:gem3:gem4:...).
local function ParseItemLinkFields(itemLink)
    local itemString = itemLink:match("item:([%-?%d:]+)")
    if not itemString then return nil end
    return { strsplit(":", itemString) }
end

local function GetEnchantIDFromLink(itemLink)
    local fields = ParseItemLinkFields(itemLink)
    if not fields then return nil end
    local enchantID = tonumber(fields[2])
    if enchantID and enchantID > 0 then return enchantID end
    return nil
end

-- Socket count via EMPTY_SOCKET_* stats (charinfo); gem fill from link fields 3-6.
-- Falls back to C_Item.GetItemNumSockets / GetItemGem when stats are not cached yet.
local function ScanSockets(itemLink)
    local numSockets = 0
    local stats = C_Item.GetItemStats(itemLink)
    if stats then
        for statKey, value in pairs(stats) do
            if string.find(statKey, "EMPTY_SOCKET_", 1, true) then
                numSockets = numSockets + (value or 0)
            end
        end
    end
    if numSockets == 0 then
        numSockets = C_Item.GetItemNumSockets(itemLink) or 0
    end

    local socketsWithGems = 0
    local fields = ParseItemLinkFields(itemLink)
    if fields then
        for i = 3, 6 do
            local gemID = tonumber(fields[i])
            if gemID and gemID > 0 then
                socketsWithGems = socketsWithGems + 1
            end
        end
    end
    if socketsWithGems == 0 and numSockets > 0 then
        for gemIdx = 1, numSockets do
            local _, gemLink = C_Item.GetItemGem(itemLink, gemIdx)
            if gemLink then
                socketsWithGems = socketsWithGems + 1
            end
        end
    end
    if socketsWithGems > numSockets then
        socketsWithGems = numSockets
    end
    return numSockets, socketsWithGems
end

local function ApplyLinkDerivedFields(slotData, itemLink)
    slotData.enchantID = GetEnchantIDFromLink(itemLink)
    local numSockets, socketsWithGems = ScanSockets(itemLink)
    slotData.numSockets = numSockets
    slotData.socketsWithGems = socketsWithGems
end

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local equipment = {}

    for slotName, slotID in pairs(INVENTORY_SLOTS) do
        local itemLink = GetInventoryItemLink("player", slotID)

        if itemLink then
            local itemID = GetInventoryItemID("player", slotID)
            local cur, max = GetInventoryItemDurability(slotID)

            equipment[slotID] = {
                slotName = slotName,
                itemLink = itemLink,
                itemID = itemID,
                durability = cur,
                maxDurability = max,
            }

            local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
            if itemLocation:IsValid() then
                equipment[slotID].quality = C_Item.GetItemQuality(itemLocation)
                equipment[slotID].itemLevel = C_Item.GetCurrentItemLevel(itemLocation)
            end

            local itemName = C_Item.GetItemName(itemLocation)
            if itemName then
                equipment[slotID].name = itemName
            end

            ApplyLinkDerivedFields(equipment[slotID], itemLink)

            local itemInfoName, _, _, _, _, _, _, _, _, _, _, _, _, _, _, setID = C_Item.GetItemInfo(itemLink)
            if setID and setID > 0 then
                equipment[slotID].setID = setID
            elseif not itemInfoName then
                equipment[slotID]._pendingSetID = true
            end
        end
    end

    local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel()
    charData.itemLevel = math.floor(avgItemLevelEquipped or avgItemLevel or 0)

    local r, g, b = GetItemLevelColor()
    charData.itemLevelColor = {r = r or 1, g = g or 1, b = b or 1}

    charData.equipment = equipment

    -- Backfill sockets/setID once item data is fully cached (GetItemStats often
    -- returns nil on first pass, which left gems at 0/0).
    for _, slotData in pairs(equipment) do
        if slotData.itemID then
            local item = Item:CreateFromItemID(slotData.itemID)
            item:ContinueOnItemLoad(function()
                local link = slotData.itemLink
                if not link then return end
                ApplyLinkDerivedFields(slotData, link)
                if slotData._pendingSetID or not slotData.setID then
                    slotData._pendingSetID = nil
                    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, loadedSetID = C_Item.GetItemInfo(link)
                    if loadedSetID and loadedSetID > 0 then
                        slotData.setID = loadedSetID
                    end
                end
            end)
        end
    end

    return true
end
