local ADDON_NAME, OneWoW_Bags = ...

function OneWoW_Bags:SortButtons(buttons, overrideSortMode)
    local db = self.db
    local sortMode = overrideSortMode or (db and db.global and db.global.itemSort) or "default"
    if sortMode == "none" then
        return buttons
    elseif sortMode == "default" then
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
        sort(buttons, function(a, b)
            if not a.owb_hasItem then return false end
            if not b.owb_hasItem then return true end
            local aID = a.owb_itemInfo and a.owb_itemInfo.itemID
            local bID = b.owb_itemInfo and b.owb_itemInfo.itemID
            if not aID then return false end
            if not bID then return true end
            local _, _, _, _, _, aType = C_Item.GetItemInfo(aID)
            local _, _, _, _, _, bType = C_Item.GetItemInfo(bID)
            aType = aType or ""
            bType = bType or ""
            if aType ~= bType then return aType < bType end
            local aName = C_Item.GetItemNameByID(aID) or ""
            local bName = C_Item.GetItemNameByID(bID) or ""
            return aName < bName
        end)
    elseif sortMode == "expansion" then
        local SE = OneWoW_Bags.SearchEngine
        sort(buttons, function(a, b)
            if not a.owb_hasItem then return false end
            if not b.owb_hasItem then return true end
            local aLink = a.owb_itemInfo and a.owb_itemInfo.hyperlink
            local bLink = b.owb_itemInfo and b.owb_itemInfo.hyperlink
            local aExp = SE and aLink and SE:GetExpansionID(a.owb_itemInfo.itemID, aLink) or -1
            local bExp = SE and bLink and SE:GetExpansionID(b.owb_itemInfo.itemID, bLink) or -1
            if aExp ~= bExp then return aExp > bExp end
            local aQ = a.owb_itemInfo and a.owb_itemInfo.quality or 0
            local bQ = b.owb_itemInfo and b.owb_itemInfo.quality or 0
            return aQ > bQ
        end)
    end
    return buttons
end
