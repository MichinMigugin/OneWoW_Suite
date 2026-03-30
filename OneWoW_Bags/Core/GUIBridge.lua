local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
OneWoW_Bags.GUILib = OneWoW_GUI

OneWoW_Bags.Constants = {
    VERSION = "R7.2603.0100",
    ADDON_NAME = "OneWoW_Bags",

    GUI = OneWoW_GUI:RegisterGUIConstants({
        WINDOW_WIDTH = 620,
        WINDOW_HEIGHT = 520,
        PADDING = 12,
        BUTTON_HEIGHT = 28,
        SEARCH_HEIGHT = 28,
        ITEM_BUTTON_SIZE = 37,
        ITEM_BUTTON_SPACING = 3,
        INFOBAR_HEIGHT = 56,
        BAGSBAR_HEIGHT = 58,
        TITLEBAR_HEIGHT = 20,
    }),

    ICON_SIZES = {
        [1] = 28,
        [2] = 32,
        [3] = 37,
        [4] = 42,
    },
}

local Constants = OneWoW_Bags.Constants

Constants.SPACING = OneWoW_GUI.Constants.SPACING

setmetatable(Constants, {
    __index = function(self, key)
        if key == "THEME" then
            return setmetatable({}, {
                __index = function(_, colorKey)
                    local r, g, b, a = OneWoW_GUI:GetThemeColor(colorKey)
                    return { r, g, b, a }
                end
            })
        elseif key == "THEMES" then
            return OneWoW_GUI.Constants.THEMES
        elseif key == "THEMES_ORDER" then
            return OneWoW_GUI.Constants.THEMES_ORDER
        end
    end
})

OneWoW_Bags.THEME = Constants.THEME
OneWoW_Bags.SPACING = Constants.SPACING

function OneWoW_Bags.T(key)
    return OneWoW_GUI:GetThemeColor(key)
end

function OneWoW_Bags.S(key)
    return OneWoW_GUI:GetSpacing(key)
end

function OneWoW_Bags:SortButtons(buttons, overrideSortMode)
    local db = self.db
    local sortMode = overrideSortMode or (db and db.global and db.global.itemSort) or "default"
    if sortMode == "none" then
        return buttons
    elseif sortMode == "default" then
        table.sort(buttons, function(a, b)
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
        table.sort(buttons, function(a, b)
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
        table.sort(buttons, function(a, b)
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
        table.sort(buttons, function(a, b)
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
        table.sort(buttons, function(a, b)
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
        table.sort(buttons, function(a, b)
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
