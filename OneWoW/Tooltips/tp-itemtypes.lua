local ADDON_NAME, OneWoW = ...

local ITEM_TYPE_COLORS = OneWoW.ITEM_TYPE_COLORS

local function ItemTypeProvider(tooltip, context)
    if not context.itemID then return nil end

    local _, itemType, itemSubType, _, _, classID, subClassID = C_Item.GetItemInfoInstant(context.itemID)
    if not itemType then return nil end

    local typeString = itemType
    if itemSubType and itemSubType ~= "" and itemSubType ~= itemType then
        typeString = itemType .. " | " .. itemSubType
    end

    local color = ITEM_TYPE_COLORS[classID] or {0.9, 0.9, 0.9}

    return {
        {type = "headerRight", text = typeString, r = color[1], g = color[2], b = color[3]}
    }
end

OneWoW.TooltipEngine:RegisterProvider({
    id = "itemtypes",
    order = 10,
    featureId = "itemtypes",
    tooltipTypes = {"item"},
    callback = ItemTypeProvider,
})
