local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
OneWoW_Bags.GUILib = OneWoW_GUI

function OneWoW_Bags.T(key)
    return OneWoW_GUI:GetThemeColor(key)
end

function OneWoW_Bags.S(key)
    return OneWoW_GUI:GetSpacing(key)
end

function OneWoW_Bags.FormatNumber(n)
    return OneWoW_GUI:FormatNumber(n)
end

function OneWoW_Bags.FormatGold(copper)
    return OneWoW_GUI:FormatGold(copper)
end

function OneWoW_Bags.CreateBarButton(parent, label, height)
    local btn = OneWoW_GUI:CreateFitTextButton(parent, { text = label, height = height or 22 })
    btn.isActive = false
    btn._defaultEnter = btn:GetScript("OnEnter")
    btn._defaultLeave = btn:GetScript("OnLeave")
    btn:SetScript("OnEnter", function(self)
        if not self.isActive and self._defaultEnter then self._defaultEnter(self) end
    end)
    btn:SetScript("OnLeave", function(self)
        if not self.isActive and self._defaultLeave then self._defaultLeave(self) end
    end)
    return btn
end

function OneWoW_Bags.CreateViewBtn(parent, label)
    return OneWoW_Bags.CreateBarButton(parent, label, 22)
end

OneWoW_Bags.Constants = {
    VERSION = "R7.2603.0100",
    ADDON_NAME = "OneWoW_Bags",

    GUI = {
        WINDOW_WIDTH = 620,
        WINDOW_HEIGHT = 520,
        PADDING = 12,
        BUTTON_HEIGHT = 28,
        SEARCH_HEIGHT = 28,
        ITEM_BUTTON_SIZE = 37,
        ITEM_BUTTON_SPACING = 3,
        INFOBAR_HEIGHT = 30,
        BAGSBAR_HEIGHT = 36,
        TITLEBAR_HEIGHT = 20,
    },

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

function OneWoW_Bags.ApplyFont(fs, size)
    local fontPath = OneWoW_GUI:GetFont()
    if not fontPath or not fs then return end
    if not size and fs.GetFont then
        local _, currentSize = fs:GetFont()
        size = currentSize or 13
    end
    if size and size > 0 then
        OneWoW_GUI:SafeSetFont(fs, fontPath, size)
    end
end

function OneWoW_Bags.ApplyFontToFrame(frame)
    if not frame then return end
    local fontPath = OneWoW_GUI:GetFont()
    if not fontPath then return end
    for _, region in ipairs({frame:GetRegions()}) do
        if region.GetFont and region.SetFont then
            local _, sz = region:GetFont()
            if sz and sz > 0 then
                OneWoW_GUI:SafeSetFont(region, fontPath, sz)
            end
        end
    end
    for _, child in ipairs({frame:GetChildren()}) do
        if child:GetObjectType() == "EditBox" and child.GetFont then
            local _, sz, flags = child:GetFont()
            if sz and sz > 0 then
                OneWoW_GUI:SafeSetFont(child, fontPath, sz, flags or "")
            end
        end
        OneWoW_Bags.ApplyFontToFrame(child)
    end
end

function OneWoW_Bags:SortButtons(buttons)
    local db = self.db
    local sortMode = db and db.global and db.global.itemSort or "name"
    if sortMode == "name" then
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
    elseif sortMode == "recent" then
        table.sort(buttons, function(a, b)
            if not a.owb_hasItem then return false end
            if not b.owb_hasItem then return true end
            local aNew = a.owb_bagID and a.owb_slotID and C_NewItems.IsNewItem(a.owb_bagID, a.owb_slotID)
            local bNew = b.owb_bagID and b.owb_slotID and C_NewItems.IsNewItem(b.owb_bagID, b.owb_slotID)
            if aNew and not bNew then return true end
            if bNew and not aNew then return false end
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
    end
    return buttons
end
