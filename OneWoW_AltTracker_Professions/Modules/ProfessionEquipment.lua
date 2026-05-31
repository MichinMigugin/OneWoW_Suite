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

local function NameFromLink(itemLink)
    if not itemLink then return nil end
    local bracketText = itemLink:match("%[(.-)%]")
    if not bracketText then return nil end
    local clean = bracketText:gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    clean = strtrim(clean)
    if clean == "" then return nil end
    return clean
end

local function CollectSlot(slotID)
    local itemLink = GetInventoryItemLink("player", slotID)
    if not itemLink then return nil end

    local itemID = GetInventoryItemID("player", slotID)
    if not itemID then return nil end

    local itemName, _, itemQuality, itemLevel, _, itemType, itemSubType = C_Item.GetItemInfo(itemLink)
    if not itemName then
        itemName = NameFromLink(itemLink)
    end
    if not itemName then return nil end

    return {
        slotID = slotID,
        itemID = itemID,
        itemLink = itemLink,
        itemName = itemName,
        itemQuality = itemQuality,
        itemLevel = itemLevel,
    }
end

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    if not charData.professions then
        return false
    end

    local existing = charData.professionEquipment or {}
    local equipment = {}
    local hasMissing = false

    for slotName, profData in pairs(charData.professions) do
        if PROF_SLOTS[slotName] then
            local slotConfig = PROF_SLOTS[slotName]
            local oldEquip = existing[profData.name]
            local profEquip = {
                professionName = profData.name,
                tool = nil,
                accessory1 = nil,
                accessory2 = nil,
            }

            if slotConfig.tool then
                profEquip.tool = CollectSlot(slotConfig.tool)
                if not profEquip.tool and oldEquip then
                    profEquip.tool = oldEquip.tool
                end
                if not profEquip.tool then hasMissing = true end
            end

            if slotConfig.accessory1 then
                profEquip.accessory1 = CollectSlot(slotConfig.accessory1)
                if not profEquip.accessory1 and oldEquip then
                    profEquip.accessory1 = oldEquip.accessory1
                end
                if not profEquip.accessory1 then hasMissing = true end
            end

            if slotConfig.accessory2 then
                profEquip.accessory2 = CollectSlot(slotConfig.accessory2)
                if not profEquip.accessory2 and oldEquip then
                    profEquip.accessory2 = oldEquip.accessory2
                end
                if not profEquip.accessory2 then hasMissing = true end
            end

            equipment[profData.name] = profEquip
        end
    end

    charData.professionEquipment = equipment
    charData.lastUpdate = time()

    if hasMissing then
        C_Timer.After(3, function()
            Module:RetryMissing(charKey, charData)
        end)
    end

    return true
end

function Module:RetryMissing(charKey, charData)
    if not charData or not charData.professions or not charData.professionEquipment then return end

    for slotName, profData in pairs(charData.professions) do
        if PROF_SLOTS[slotName] then
            local slotConfig = PROF_SLOTS[slotName]
            local profEquip = charData.professionEquipment[profData.name]
            if not profEquip then break end

            if slotConfig.tool and (not profEquip.tool or not profEquip.tool.itemName) then
                local data = CollectSlot(slotConfig.tool)
                if data then profEquip.tool = data end
            end
            if slotConfig.accessory1 and (not profEquip.accessory1 or not profEquip.accessory1.itemName) then
                local data = CollectSlot(slotConfig.accessory1)
                if data then profEquip.accessory1 = data end
            end
            if slotConfig.accessory2 and (not profEquip.accessory2 or not profEquip.accessory2.itemName) then
                local data = CollectSlot(slotConfig.accessory2)
                if data then profEquip.accessory2 = data end
            end
        end
    end
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
