local addonName, ns = ...

ns.ProfessionEquipment = {}
local Module = ns.ProfessionEquipment

local PROF_SLOTS = {
    Primary1 = {
        tool = 20,
        accessory1 = 21,
        accessory2 = 22,
    },
    Primary2 = {
        tool = 23,
        accessory1 = 24,
        accessory2 = 25,
    },
    Cooking = {
        tool = 26,
        accessory1 = 27,
    },
    Fishing = {
        tool = 28,
        accessory1 = 29,
        accessory2 = 30,
    },
}

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    if not charData.professions then
        return false
    end

    local equipment = {}

    for slotName, profData in pairs(charData.professions) do
        if PROF_SLOTS[slotName] then
            local slotConfig = PROF_SLOTS[slotName]
            local profEquip = {
                professionName = profData.name,
                tool = nil,
                accessory1 = nil,
                accessory2 = nil,
            }

            if slotConfig.tool then
                local itemLink = GetInventoryItemLink("player", slotConfig.tool)
                if itemLink then
                    local itemID = GetInventoryItemID("player", slotConfig.tool)
                    if itemID then
                        local itemName, _, itemQuality, itemLevel, _, itemType, itemSubType = C_Item.GetItemInfo(itemLink)
                        profEquip.tool = {
                            slotID = slotConfig.tool,
                            itemID = itemID,
                            itemLink = itemLink,
                            itemName = itemName,
                            itemQuality = itemQuality,
                            itemLevel = itemLevel,
                        }
                    end
                end
            end

            if slotConfig.accessory1 then
                local itemLink = GetInventoryItemLink("player", slotConfig.accessory1)
                if itemLink then
                    local itemID = GetInventoryItemID("player", slotConfig.accessory1)
                    if itemID then
                        local itemName, _, itemQuality, itemLevel, _, itemType, itemSubType = C_Item.GetItemInfo(itemLink)
                        profEquip.accessory1 = {
                            slotID = slotConfig.accessory1,
                            itemID = itemID,
                            itemLink = itemLink,
                            itemName = itemName,
                            itemQuality = itemQuality,
                            itemLevel = itemLevel,
                        }
                    end
                end
            end

            if slotConfig.accessory2 then
                local itemLink = GetInventoryItemLink("player", slotConfig.accessory2)
                if itemLink then
                    local itemID = GetInventoryItemID("player", slotConfig.accessory2)
                    if itemID then
                        local itemName, _, itemQuality, itemLevel, _, itemType, itemSubType = C_Item.GetItemInfo(itemLink)
                        profEquip.accessory2 = {
                            slotID = slotConfig.accessory2,
                            itemID = itemID,
                            itemLink = itemLink,
                            itemName = itemName,
                            itemQuality = itemQuality,
                            itemLevel = itemLevel,
                        }
                    end
                end
            end

            equipment[profData.name] = profEquip
        end
    end

    charData.professionEquipment = equipment
    charData.lastUpdate = time()

    return true
end

function Module:GetEquipmentForProfession(charKey, charData, professionName)
    if not charData or not charData.professionEquipment then return nil end

    return charData.professionEquipment[professionName]
end

function Module:HasMissingEquipment(charKey, charData, professionName)
    local equip = self:GetEquipmentForProfession(charKey, charData, professionName)
    if not equip then return true end

    if not equip.tool then return true end

    if not equip.accessory1 and not equip.accessory2 then
        return true
    end

    return false
end
