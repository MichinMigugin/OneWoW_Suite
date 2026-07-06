local _, ns = ...

local OneWoW = OneWoW

local L = ns.L

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

ns.ITEM_TYPE_COLORS = ITEM_TYPE_COLORS

local function GetCollectionStatusText(status)
    if status.collected then
        return "|cFF66CC66" .. L["TIPS_COLLECTIONS_COLLECTED"] .. "|r"
    end

    if status.type == "recipe" and status.collectedByAlt then
        local mode = OneWoW.SettingsFeatureRegistry:GetFeatureSettings("tooltips", "collections").recipeAltDisplay
            or "differentiated"
        if mode == "combined" then
            return "|cFF66CC66" .. L["TIPS_COLLECTIONS_COLLECTED"] .. "|r"
        elseif mode == "differentiated" then
            return "|cFFFFD700" .. L["TIPS_COLLECTIONS_ALT_COLLECTED"] .. "|r"
        end
    end

    return "|cFFCC6666" .. L["TIPS_COLLECTIONS_NOT_COLLECTED"] .. "|r"
end

local function CollectionsProvider(_, context)
    if not context.itemID then return nil end

    local classID, typeString, typeColor

    local _, itemType, itemSubType
    _, itemType, itemSubType, _, _, classID = C_Item.GetItemInfoInstant(context.itemID)
    if not itemType then return nil end

    typeString = itemType
    if itemSubType and itemSubType ~= "" and itemSubType ~= itemType then
        typeString = itemType .. " | " .. itemSubType
    end

    typeColor = ITEM_TYPE_COLORS[classID] or {0.9, 0.9, 0.9}

    local status = OneWoW.Collectibles.GetItemCollectionStatus(context.itemID, context.itemLink, {
        tooltipData = context.data,
    })
    if not status then
        return {
            {type = "headerRight", text = typeString, r = typeColor[1], g = typeColor[2], b = typeColor[3]}
        }
    end

    local text = GetCollectionStatusText(status) .. " | " .. typeString
    return {
        {type = "headerRight", text = text, r = typeColor[1], g = typeColor[2], b = typeColor[3]}
    }
end

OneWoW.TooltipEngine:RegisterProvider({
    id = "collections",
    order = 9,
    featureId = "collections",
    tooltipTypes = {"item"},
    callback = CollectionsProvider,
})
