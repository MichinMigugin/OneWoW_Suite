local _, ns = ...
local L = ns.L

ns.Tooltips = {}
local Tooltips = ns.Tooltips

local function AddShoppingListTooltip(tooltip, itemID)
    if not itemID then return end

    if not OneWoW_ShoppingList_DB.global.settings.enableTooltips then return end

    local isOnList, lists = ns.ShoppingList:IsOnAnyList(itemID)
    if not isOnList then return end

    tooltip:AddLine(" ")
    tooltip:AddLine(L["OWSL_TOOLTIP_HEADER"], 1, 0.82, 0)

    for _, listName in ipairs(lists) do
        local status = ns.ShoppingList:GetItemStatus(itemID, listName)
        if status then
            local r, g, b = unpack(status.statusColor)
            local cartIcon = CreateAtlasMarkup("Perks-ShoppingCart", 14, 14)
            tooltip:AddDoubleLine(
                cartIcon .. " " .. listName,
                string.format("%d/%d", status.totalOwned, status.needed),
                1, 1, 1, r, g, b
            )
        end
    end
end

function Tooltips:Initialize()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if not data or not data.id then return end
            AddShoppingListTooltip(tooltip, data.id)
        end)
    else
        GameTooltip:HookScript("OnTooltipSetItem", function(myself)
            local _, link = myself:GetItem()
            if not link then return end
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then AddShoppingListTooltip(myself, itemID) end
        end)
    end
end
