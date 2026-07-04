local _, ns = ...

ns.ProfessionEquipment = {}
local Module = ns.ProfessionEquipment

-- Inventory slot ID -> equipment field. Slot ownership is resolved at scan time
-- via C_TradeSkillUI.GetProfessionByInventorySlot, not GetProfessions order.
local SLOT_FIELDS = {
    [20] = "tool",
    [21] = "accessory1",
    [22] = "accessory2",
    [23] = "tool",
    [24] = "accessory1",
    [25] = "accessory2",
    [26] = "tool",
    [27] = "accessory1",
    [28] = "tool",
    [29] = "accessory1",
    [30] = "accessory2",
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

    local itemName, _, itemQuality, itemLevel = C_Item.GetItemInfo(itemLink)
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

local function BuildSkillLineToName(charData)
    local skillLineToName = {}
    for _, profData in pairs(charData.professions) do
        if profData.name and profData.skillLine then
            skillLineToName[profData.skillLine] = profData.name
        end
    end
    return skillLineToName
end

local function ProfessionNameForSlot(slotID, skillLineToName)
    local professionEnum = C_TradeSkillUI.GetProfessionByInventorySlot(slotID)
    if not professionEnum then return nil end
    local skillLine = C_TradeSkillUI.GetProfessionSkillLineID(professionEnum)
    return skillLineToName[skillLine]
end

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    if not charData.professions then
        return false
    end

    local existing = charData.professionEquipment or {}
    local skillLineToName = BuildSkillLineToName(charData)
    local equipment = {}
    local hasMissing = false

    for _, profData in pairs(charData.professions) do
        if profData.name and profData.name ~= "Archaeology" then
            equipment[profData.name] = {
                professionName = profData.name,
                tool = nil,
                accessory1 = nil,
                accessory2 = nil,
            }
        end
    end

    for slotID, field in pairs(SLOT_FIELDS) do
        local profName = ProfessionNameForSlot(slotID, skillLineToName)
        local profEquip = profName and equipment[profName]
        if profEquip then
            local oldEquip = existing[profName]
            profEquip[field] = CollectSlot(slotID)
            if not profEquip[field] and oldEquip then
                profEquip[field] = oldEquip[field]
            end
            if not profEquip[field] then
                hasMissing = true
            end
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

function Module:RetryMissing(_, charData)
    if not charData or not charData.professions or not charData.professionEquipment then return end

    local skillLineToName = BuildSkillLineToName(charData)

    for slotID, field in pairs(SLOT_FIELDS) do
        local profName = ProfessionNameForSlot(slotID, skillLineToName)
        local profEquip = profName and charData.professionEquipment[profName]
        if profEquip and (not profEquip[field] or not profEquip[field].itemName) then
            local data = CollectSlot(slotID)
            if data then profEquip[field] = data end
        end
    end
end

function Module:GetEquipmentForProfession(_, charData, professionName)
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
