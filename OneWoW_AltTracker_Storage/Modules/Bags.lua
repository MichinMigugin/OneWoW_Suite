local addonName, ns = ...

ns.Bags = {}
local Module = ns.Bags

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local bags = {}

    for bagID = 0, 5 do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        if numSlots and numSlots > 0 then
            bags[bagID] = {
                slots = {},
                numSlots = numSlots,
            }

            for slotID = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)

                if itemInfo then
                    local itemLink = C_Container.GetContainerItemLink(bagID, slotID)
                    local itemID = itemInfo.itemID
                    local itemName, _, itemQuality, itemLevel, _, _, _, _, _, itemTexture, sellPrice = GetItemInfo(itemID)

                    bags[bagID].slots[slotID] = {
                        itemID = itemID,
                        itemLink = itemLink,
                        itemName = itemName,
                        quality = itemQuality,
                        itemLevel = itemLevel,
                        texture = itemTexture,
                        sellPrice = sellPrice or 0,
                        stackCount = itemInfo.stackCount,
                        isLocked = itemInfo.isLocked,
                        isBound = itemInfo.isBound,
                    }
                end
            end
        end
    end

    charData.bags = bags
    charData.bagsLastUpdate = time()

    return true
end
