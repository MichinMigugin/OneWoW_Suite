local _, ns = ...

local ItemLevel = OneWoW.ItemLevel

local function CompareValues(aValue, bValue, descending)
    if aValue == bValue then return 0 end
    if descending then
        return aValue > bValue and -1 or 1
    end
    return aValue < bValue and -1 or 1
end

local MODE_DEFAULT_DESCENDING = {
    default = false,
    name = false,
    rarity = true,
    ilvl = true,
    type = false,
    expansion = true,
}

local function ResolveDescending(mode, overrideDescending)
    if overrideDescending ~= nil then
        return overrideDescending
    end
    if MODE_DEFAULT_DESCENDING[mode] ~= nil then
        return MODE_DEFAULT_DESCENDING[mode]
    end
    return false
end

local function CompactButtons(buttons)
    local count = #buttons
    local writeIndex = 1
    for readIndex = 1, count do
        local button = buttons[readIndex]
        if button then
            buttons[writeIndex] = button
            writeIndex = writeIndex + 1
        end
    end
    for index = writeIndex, count do
        buttons[index] = nil
    end
end

local function CompareHasItem(a, b)
    local aHasItem = a and a.owb_hasItem and 1 or 0
    local bHasItem = b and b.owb_hasItem and 1 or 0
    return CompareValues(aHasItem, bHasItem, true)
end

local function CompareDefault(a, b, descending)
    local result = CompareValues(a and a.owb_bagID or 0, b and b.owb_bagID or 0, descending)
    if result ~= 0 then return result end
    return CompareValues(a and a.owb_slotID or 0, b and b.owb_slotID or 0, descending)
end

local function GetItemID(button)
    return button and button.owb_itemInfo and button.owb_itemInfo.itemID
end

local function GetSortName(button, itemID)
    local name = button and button._owb_sortName
    if not name or name == "" then
        name = C_Item.GetItemNameByID(itemID) or ""
    end
    return name
end

local function GetItemLevel(button, itemLink)
    -- Containers: use bag capacity (matches Item Level overlay), not equipment ilvl.
    local classID = button and button._owb_classID
    local itemID = GetItemID(button)
    if classID == nil and itemID then
        classID = select(6, C_Item.GetItemInfoInstant(itemID))
    end
    if classID == Enum.ItemClass.Container and itemID then
        local slots = ItemLevel.GetContainerSlotCount(itemID)
        if slots then
            return slots
        end
    end

    local ilvl = button and button._owb_ilvl
    if ilvl == nil or (ilvl == 0 and itemLink) then
        ilvl = itemLink and (select(4, C_Item.GetItemInfo(itemLink)) or 0) or 0
    end
    return ilvl
end

local function CompareName(a, b, descending)
    local aID = GetItemID(a)
    local bID = GetItemID(b)
    local result = CompareValues(aID and 1 or 0, bID and 1 or 0, true)
    if result ~= 0 then return result end
    if not aID or not bID then return 0 end
    local aName = GetSortName(a, aID)
    local bName = GetSortName(b, bID)
    return CompareValues(aName, bName, descending)
end

local function GetCachedItemQuality(button)
    if button and button._owb_itemQuality ~= nil then
        return button._owb_itemQuality
    end
    return button and button.owb_itemInfo and button.owb_itemInfo.quality or 0
end

local function GetCachedReagentQuality(button)
    return button and button._owb_reagentQuality or 0
end

local function GetCachedCraftedQuality(button)
    return button and button._owb_craftedQuality or 0
end

local function CompareRarity(a, b, descending)
    local result = CompareValues(GetCachedItemQuality(a), GetCachedItemQuality(b), descending)
    if result ~= 0 then return result end
    result = CompareValues(GetCachedReagentQuality(a), GetCachedReagentQuality(b), descending)
    if result ~= 0 then return result end
    return CompareValues(GetCachedCraftedQuality(a), GetCachedCraftedQuality(b), descending)
end

local function CompareItemLevel(a, b, descending)
    local aLink = a and a.owb_itemInfo and a.owb_itemInfo.hyperlink
    local bLink = b and b.owb_itemInfo and b.owb_itemInfo.hyperlink
    local aIlvl = GetItemLevel(a, aLink)
    local bIlvl = GetItemLevel(b, bLink)
    return CompareValues(aIlvl, bIlvl, descending)
end

local function CompareType(a, b, descending)
    local aID = GetItemID(a)
    local bID = GetItemID(b)
    local result = CompareValues(aID and 1 or 0, bID and 1 or 0, true)
    if result ~= 0 then return result end
    if not aID or not bID then return 0 end
    local aClass, aSub = a._owb_classID, a._owb_subClassID
    local bClass, bSub = b._owb_classID, b._owb_subClassID
    if aClass == nil then
        local props = ns:GetButtonProps(a)
        aClass, aSub = props.classID, props.subClassID
    end
    if bClass == nil then
        local props = ns:GetButtonProps(b)
        bClass, bSub = props.classID, props.subClassID
    end
    aClass = aClass or 0
    bClass = bClass or 0
    result = CompareValues(aClass, bClass, descending)
    if result ~= 0 then return result end
    aSub = aSub or 0
    bSub = bSub or 0
    return CompareValues(aSub, bSub, descending)
end

local function CompareExpansion(a, b, descending)
    local WH = ns.WindowHelpers
    local aExp = a and WH:GetButtonExpansionID(a) or -1
    local bExp = b and WH:GetButtonExpansionID(b) or -1
    return CompareValues(aExp, bExp, descending)
end

local COMPARE_BY_MODE = {
    default = CompareDefault,
    name = CompareName,
    rarity = CompareRarity,
    ilvl = CompareItemLevel,
    type = CompareType,
    expansion = CompareExpansion,
}

local LEGACY_TIE_BREAKERS = {
    rarity = { "name" },
    ilvl = { "rarity" },
    type = { "name" },
    expansion = { "rarity" },
}

local function CompareMode(a, b, mode, descending)
    local compare = COMPARE_BY_MODE[mode]
    return compare and compare(a, b, descending) or 0
end

local function CompareChain(a, b, specs)
    local hasItemResult = CompareHasItem(a, b)
    if hasItemResult ~= 0 then return hasItemResult end

    for _, spec in ipairs(specs) do
        local result = CompareMode(a, b, spec.mode, spec.descending)
        if result ~= 0 then return result end
    end
    return 0
end

local function AppendSpec(specs, mode, overrideDescending)
    specs[#specs + 1] = {
        mode = mode,
        descending = ResolveDescending(mode, overrideDescending),
    }
end

function ns:SortButtons(buttons, overrideSortMode, overrideSubSortMode, sortDescending, subSortDescending)
    local sortMode = overrideSortMode or "default"
    if sortMode == "none" then
        return buttons
    end

    local subSortMode = overrideSubSortMode
    if subSortMode == "none" or subSortMode == sortMode then
        subSortMode = nil
    end

    local specs = {}
    AppendSpec(specs, sortMode, sortDescending)

    if subSortMode then
        AppendSpec(specs, subSortMode, subSortDescending)
        AppendSpec(specs, "default", false)
    else
        local tieBreakers = LEGACY_TIE_BREAKERS[sortMode]
        if tieBreakers then
            for _, mode in ipairs(tieBreakers) do
                AppendSpec(specs, mode, nil)
            end
        end
        if specs[#specs].mode ~= "default" then
            AppendSpec(specs, "default", false)
        end
    end

    CompactButtons(buttons)
    sort(buttons, function(a, b)
        return CompareChain(a, b, specs) < 0
    end)

    return buttons
end
