local _, ns = ...

local function GetInspectMogDb()
    local db = ns.ModuleRegistry:GetModuleBucket("inspectmog")
    if db.attachSide == nil then db.attachSide = "RIGHT" end
    if db.hideUnchanged == nil then db.hideUnchanged = false end
    if db.showEmptySlots == nil then db.showEmptySlots = false end
    return db
end

local function IsInspectMogActive()
    return ns.ModuleRegistry:IsEnabled("inspectmog")
end

local Scanner = {}
ns.InspectMogScanner = Scanner
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

local function GetSourceData(sourceID)
    sourceID = tonumber(sourceID)
    if not sourceID or sourceID <= 0 then
        return nil
    end

    local info = C_TransmogCollection.GetSourceInfo(sourceID)

    if type(info) ~= "table" then
        return {
            sourceID = sourceID,
        }
    end

    return {
        sourceID = sourceID,
        name = info.name or info.itemName,
        itemID = info.itemID,
        quality = info.quality,
        invType = info.invType,
        visualID = info.visualID,
        categoryID = info.categoryID,
        isCollected = info.isCollected,
        itemLink = info.itemLink or info.hyperlink or info.link,
    }
end

-- Resolve an item's OWN appearance source (itemModifiedAppearanceID). GetItemInfo
-- MayReturnNothing for some fully-decorated equipped links (bonus/enchant mods),
-- so fall back to the bare itemID, whose visual is identical for ilvl-only bonuses.
local function GetItemTransmogSource(itemLink, itemID)
    local _, sourceID
    if itemLink then
        _, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
    end
    if not sourceID and itemID then
        _, sourceID = C_TransmogCollection.GetItemInfo(itemID)
    end
    return sourceID
end

local function GetInspectTransmogBySlot()
    local list = C_TransmogCollection.GetInspectItemTransmogInfoList()
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

    local settings = GetInspectMogDb()
    local transmogList = GetInspectTransmogBySlot()
    local rows = {}

    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local itemLink = GetInventoryItemLink(unit, slot.id)
        local itemID = GetInventoryItemID(unit, slot.id)
        local texture = GetInventoryItemTexture(unit, slot.id)
        local baseSourceID = GetItemTransmogSource(itemLink, itemID)
        local appearanceSourceID = GetSlotAppearanceSource(transmogList, slot.id)

        if itemLink or settings.showEmptySlots then
            local itemName = itemLink and C_Item.GetItemInfo(itemLink) or nil
            local appearanceSource = GetSourceData(appearanceSourceID)
            local baseSource = GetSourceData(baseSourceID)
            local mogName = appearanceSource and appearanceSource.name
            local baseName = baseSource and baseSource.name
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
                    baseItemID = baseSource and baseSource.itemID,
                    baseItemLink = baseSource and baseSource.itemLink,
                    appearanceSourceID = appearanceSourceID,
                    appearanceName = mogName,
                    appearanceItemID = appearanceSource and appearanceSource.itemID,
                    appearanceItemLink = appearanceSource and appearanceSource.itemLink,
                    appearanceQuality = appearanceSource and appearanceSource.quality,
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

-- Blizzard's InspectFrame_Show already calls NotifyInspect; extra requests
-- fire additional INSPECT_READY cycles and aggravate the Blizzard
-- InspectGuildFrame nil-guild error (see InstallInspectGuildFrameGuard in
-- inspectpanel.lua). Only call Request while the panel is actually shown.
function Scanner:Request(unit)
    unit = unit or GetInspectedUnit()
    if not unit or not UnitExists(unit) or not CanInspect(unit) then
        return
    end

    self.pendingGUID = UnitGUID(unit)
    self.pendingUnit = unit
    NotifyInspect(unit)
end

function Scanner:Initialize()
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, event, guid)
            if not IsInspectMogActive() then
                return
            end

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

    -- Always (re)register: OnDisable unregisters the frame's events, and a
    -- later re-enable must arm them again even though the frame survives.
    self.frame:RegisterEvent("INSPECT_READY")
    self.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
end

-- Called from OnDisable: unregister events so the scanner stops responding
-- while disabled. The frame is reused on a later re-enable (Initialize re-arms).
function Scanner:Shutdown()
    if self.frame then
        self.frame:UnregisterAllEvents()
    end
end
