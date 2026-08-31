local _, ns = ...

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

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

    local lines = {}

    local status = OneWoW.Collectibles.GetItemCollectionStatus(context.itemID, context.itemLink, {
        tooltipData = context.data,
        light = true,
    })
    local showNonCollectable = OneWoW.SettingsFeatureRegistry:GetFeatureSettings("tooltips", "collections").showNonCollectable == true
    local statusText
    if status and status.applicable then
        statusText = GetCollectionStatusText(status)
    elseif showNonCollectable then
        statusText = "|cFFFFD700" .. L["TIPS_COLLECTIONS_NOT_COLLECTABLE"] .. "|r"
    end
    if statusText then
        local text = statusText .. " | " .. typeString
        lines[#lines + 1] = {
            type = "headerRight",
            text = text,
            r = typeColor[1],
            g = typeColor[2],
            b = typeColor[3],
        }
    else
        lines[#lines + 1] = {
            type = "headerRight",
            text = typeString,
            r = typeColor[1],
            g = typeColor[2],
            b = typeColor[3],
        }
    end

    local punch = OneWoW.Collectibles.GetPunchListSummary(context.itemID, context.data)
    if punch then
        local missing = punch.missing
        if #missing > 0 then
            lines[#lines + 1] = {
                type = "header",
                text = "  " .. L["TIPS_COLLECTIONS_NOT_COLLECTED"],
            }
            for i = 1, #missing do
                local row = missing[i]
                local r, g, b = OneWoW_GUI:GetItemQualityColor(row.quality)
                lines[#lines + 1] = {
                    type = "text",
                    text = "    " .. row.name,
                    r = r,
                    g = g,
                    b = b,
                }
            end
        else
            lines[#lines + 1] = {
                type = "text",
                text = "  " .. format(L["TIPS_COLLECTIONS_PUNCH_ALL_COLLECTED"], punch.cacheName),
                r = 0.4,
                g = 0.8,
                b = 0.4,
            }
        end
    end

    return lines
end

OneWoW.TooltipEngine:RegisterProvider({
    id = "collections",
    order = 9,
    featureId = "collections",
    tooltipTypes = {"item"},
    callback = CollectionsProvider,
})
