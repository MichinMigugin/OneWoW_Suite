local ADDON_NAME, OneWoW = ...

local ITEM_TYPE_COLORS = {
    [0]  = {0.47, 0.94, 0.47},
    [1]  = {0.80, 0.70, 0.50},
    [2]  = {0.47, 1.00, 1.00},
    [3]  = {1.00, 0.50, 1.00},
    [4]  = {0.47, 1.00, 1.00},
    [5]  = {0.60, 0.80, 0.60},
    [7]  = {0.32, 0.73, 0.91},
    [8]  = {0.80, 0.60, 1.00},
    [9]  = {1.00, 0.80, 0.40},
    [12] = {0.80, 0.80, 0.40},
    [15] = {0.70, 0.70, 0.70},
    [16] = {0.60, 0.80, 1.00},
    [17] = {0.40, 0.80, 0.40},
    [18] = {1.00, 0.82, 0.00},
    [19] = {0.32, 0.73, 0.91},
}

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
