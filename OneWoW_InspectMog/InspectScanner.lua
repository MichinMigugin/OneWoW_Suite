local addonName, ns = ...

local Scanner = {}
ns.Scanner = Scanner

local EQUIPMENT_SLOTS = {
    { id = 1,  name = HEADSLOT or "Head" },
    { id = 3,  name = SHOULDERSLOT or "Shoulder" },
    { id = 15, name = BACKSLOT or "Back" },
    { id = 5,  name = CHESTSLOT or "Chest" },
    { id = 4,  name = SHIRTSLOT or "Shirt" },
    { id = 19, name = TABARDSLOT or "Tabard" },
    { id = 9,  name = WRISTSLOT or "Wrist" },
    { id = 10, name = HANDSSLOT or "Hands" },
    { id = 6,  name = WAISTSLOT or "Waist" },
    { id = 7,  name = LEGSSLOT or "Legs" },
    { id = 8,  name = FEETSLOT or "Feet" },
    { id = 16, name = MAINHANDSLOT or "Main Hand" },
    { id = 17, name = SECONDARYHANDSLOT or "Off Hand" },
}

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then
        return a, b, c, d, e
    end

    return nil
end

local function GetInspectedUnit()
    if InspectFrame and InspectFrame.unit and UnitExists(InspectFrame.unit) then
        return InspectFrame.unit
    end

    if UnitExists("target") and UnitIsPlayer("target") and CanInspect("target") then
        return "target"
    end

    if UnitExists("mouseover") and UnitIsPlayer("mouseover") and CanInspect("mouseover") then
        return "mouseover"
    end

    return nil
end

local function GetSourceName(sourceID)
    sourceID = tonumber(sourceID)
    if not sourceID or sourceID <= 0 then
        return nil
    end

    local info =
        C_TransmogCollection
        and C_TransmogCollection.GetSourceInfo
        and SafeCall(C_TransmogCollection.GetSourceInfo, sourceID)

    return info and (info.name or info.itemName) or nil
end

local function GetItemTransmogSource(itemLink)
    if not itemLink or not C_TransmogCollection or not C_TransmogCollection.GetItemInfo then
        return nil
    end

    local _, sourceID = SafeCall(C_TransmogCollection.GetItemInfo, itemLink)
    return sourceID
end

local function GetInspectTransmogBySlot()
    if not C_TransmogCollection
        or not C_TransmogCollection.GetInspectItemTransmogInfoList
    then
        return nil
    end

    local list = SafeCall(C_TransmogCollection.GetInspectItemTransmogInfoList)
    if type(list) ~= "table" then
        return nil
    end

    return list
end

local function GetSlotAppearanceSource(transmogList, slotID)
    if type(transmogList) ~= "table" then
        return nil
    end

    local info = transmogList[slotID]
    if not info then
        for _, candidate in pairs(transmogList) do
            if type(candidate) == "table"
                and tonumber(candidate.slotID or candidate.inventorySlotID or candidate.slot) == slotID
            then
                info = candidate
                break
            end
        end
    end

    if not info then
        return nil
    end

    return info.appearanceID
        or info.sourceID
        or info.itemModifiedAppearanceID
        or info.secondaryAppearanceID
end

function Scanner:BuildInspectSnapshot(unit)
    unit = unit or GetInspectedUnit()
    if not unit or not UnitExists(unit) then
        return nil
    end

    local settings = ns.db or {}
    local transmogList = GetInspectTransmogBySlot()
    local rows = {}

    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local itemLink = GetInventoryItemLink(unit, slot.id)
        local itemID = GetInventoryItemID(unit, slot.id)
        local texture = GetInventoryItemTexture(unit, slot.id)
        local baseSourceID = GetItemTransmogSource(itemLink)
        local appearanceSourceID = GetSlotAppearanceSource(transmogList, slot.id)

        if itemLink or settings.showEmptySlots then
            local itemName = itemLink and GetItemInfo(itemLink) or nil
            local mogName = GetSourceName(appearanceSourceID)
            local baseName = GetSourceName(baseSourceID)
            local isChanged =
                appearanceSourceID
                and baseSourceID
                and appearanceSourceID ~= baseSourceID

            if not settings.hideUnchanged or isChanged then
                table.insert(rows, {
                    slotID = slot.id,
                    slotName = slot.name,
                    itemID = itemID,
                    itemLink = itemLink,
                    itemName = itemName,
                    texture = texture,
                    baseSourceID = baseSourceID,
                    baseName = baseName,
                    appearanceSourceID = appearanceSourceID,
                    appearanceName = mogName,
                    isChanged = isChanged and true or false,
                })
            end
        end
    end

    return {
        unit = unit,
        guid = UnitGUID(unit),
        name = UnitName(unit),
        rows = rows,
    }
end

function Scanner:Request(unit)
    unit = unit or GetInspectedUnit()
    if not unit or not UnitExists(unit) or not CanInspect(unit) then
        return
    end

    self.pendingGUID = UnitGUID(unit)
    self.pendingUnit = unit
    SafeCall(NotifyInspect, unit)
end

function Scanner:Initialize()
    if self.frame then
        return
    end

    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("INSPECT_READY")
    self.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    self.frame:SetScript("OnEvent", function(_, event, guid)
        if event == "PLAYER_TARGET_CHANGED" then
            if ns.Panel and ns.Panel:IsShownForInspect() then
                C_Timer.After(0.1, function()
                    Scanner:Request()
                end)
            end
            return
        end

        if guid and Scanner.pendingGUID and guid ~= Scanner.pendingGUID then
            return
        end

        if ns.Panel and ns.Panel.Refresh then
            ns.Panel:Refresh(Scanner.pendingUnit)
        end
    end)
end
