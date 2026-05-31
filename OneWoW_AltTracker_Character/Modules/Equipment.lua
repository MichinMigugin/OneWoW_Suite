local addonName, ns = ...

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

            local numSockets = C_Item.GetItemNumSockets(itemLink) or 0
            local socketsWithGems = 0
            for gemIdx = 1, numSockets do
                local _, gemLink = C_Item.GetItemGem(itemLink, gemIdx)
                if gemLink then
                    socketsWithGems = socketsWithGems + 1
                end
            end
            equipment[slotID].numSockets = numSockets
            equipment[slotID].socketsWithGems = socketsWithGems

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

    for slotID, slotData in pairs(equipment) do
        if slotData._pendingSetID then
            slotData._pendingSetID = nil
            local item = Item:CreateFromItemID(slotData.itemID)
            item:ContinueOnItemLoad(function()
                local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, loadedSetID = C_Item.GetItemInfo(slotData.itemLink)
                if loadedSetID and loadedSetID > 0 then
                    slotData.setID = loadedSetID
                end
            end)
        end
    end

    return true
end
