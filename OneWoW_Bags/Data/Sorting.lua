local _, OneWoW_Bags = ...

function OneWoW_Bags:SortButtons(buttons, overrideSortMode)
    local sortMode = overrideSortMode or "default"
    if sortMode == "none" then
        return buttons
    elseif sortMode == "default" then
        -- sort by bagID then slotID
        sort(buttons, function(a, b)
            if not a.owb_hasItem then return false end
            if not b.owb_hasItem then return true end
            local aBag = a.owb_bagID or 0
            local bBag = b.owb_bagID or 0
            if aBag ~= bBag then return aBag < bBag end
            local aSlot = a.owb_slotID or 0
            local bSlot = b.owb_slotID or 0
            return aSlot < bSlot
        end)
    elseif sortMode == "name" then
        -- sort by localized item name
        sort(buttons, function(a, b)
            if not a.owb_hasItem then return false end
            if not b.owb_hasItem then return true end
            local aID = a.owb_itemInfo and a.owb_itemInfo.itemID
            local bID = b.owb_itemInfo and b.owb_itemInfo.itemID
            if not aID then return false end
            if not bID then return true end
            local aName = C_Item.GetItemNameByID(aID) or ""
            local bName = C_Item.GetItemNameByID(bID) or ""
            return aName < bName
        end)
    elseif sortMode == "rarity" then
        -- sort by quality in Enum.ItemQuality order then by localized item name
        sort(buttons, function(a, b)
            if not a.owb_hasItem then return false end
            if not b.owb_hasItem then return true end
            local aQ = a.owb_itemInfo and a.owb_itemInfo.quality or 0
            local bQ = b.owb_itemInfo and b.owb_itemInfo.quality or 0
            if aQ ~= bQ then return aQ > bQ end
            local aID = a.owb_itemInfo and a.owb_itemInfo.itemID
            local bID = b.owb_itemInfo and b.owb_itemInfo.itemID
            local aName = aID and C_Item.GetItemNameByID(aID) or ""
            local bName = bID and C_Item.GetItemNameByID(bID) or ""
            return aName < bName
        end)
    elseif sortMode == "ilvl" then
        -- sort by actual item level (not including upgrades) then by quality in Enum.ItemQuality order
        sort(buttons, function(a, b)
            if not a.owb_hasItem then return false end
            if not b.owb_hasItem then return true end
            local aLink = a.owb_itemInfo and a.owb_itemInfo.hyperlink
            local bLink = b.owb_itemInfo and b.owb_itemInfo.hyperlink
            local aIlvl = aLink and (select(4, C_Item.GetItemInfo(aLink)) or 0) or 0
            local bIlvl = bLink and (select(4, C_Item.GetItemInfo(bLink)) or 0) or 0
            if aIlvl ~= bIlvl then return aIlvl > bIlvl end
            local aQ = a.owb_itemInfo and a.owb_itemInfo.quality or 0
            local bQ = b.owb_itemInfo and b.owb_itemInfo.quality or 0
            return aQ > bQ
        end)
    elseif sortMode == "type" then
        -- sort by numeric item class, then by numeric item sub-class, then by localized item name
        -- sorting by numerics retains sort order across locales
        sort(buttons, function(a, b)
            if not a.owb_hasItem then return false end
            if not b.owb_hasItem then return true end
            local aID = a.owb_itemInfo and a.owb_itemInfo.itemID
            local bID = b.owb_itemInfo and b.owb_itemInfo.itemID
            if not aID then return false end
            if not bID then return true end
            local _, _, _, _, _, aClass, aSub = C_Item.GetItemInfoInstant(aID)
            local _, _, _, _, _, bClass, bSub = C_Item.GetItemInfoInstant(bID)
            aClass = aClass or 0
            bClass = bClass or 0
            if aClass ~= bClass then return aClass < bClass end
            aSub = aSub or 0
            bSub = bSub or 0
            if aSub ~= bSub then return aSub < bSub end
            local aName = C_Item.GetItemNameByID(aID) or ""
            local bName = C_Item.GetItemNameByID(bID) or ""
            return aName < bName
        end)
    elseif sortMode == "expansion" then
        local WH = OneWoW_Bags.WindowHelpers
        -- sort by expansion ID in Enum.ExpansionLevel order then by quality in Enum.ItemQuality order
        sort(buttons, function(a, b)
            if not a.owb_hasItem then return false end
            if not b.owb_hasItem then return true end
            local aExp = WH and a.owb_itemInfo and WH:ResolveExpansionID(a.owb_itemInfo, a.owb_bagID, a.owb_slotID) or -1
            local bExp = WH and b.owb_itemInfo and WH:ResolveExpansionID(b.owb_itemInfo, b.owb_bagID, b.owb_slotID) or -1
            if aExp ~= bExp then return aExp > bExp end
            local aQ = a.owb_itemInfo and a.owb_itemInfo.quality or 0
            local bQ = b.owb_itemInfo and b.owb_itemInfo.quality or 0
            return aQ > bQ
        end)
    end
    return buttons
end
