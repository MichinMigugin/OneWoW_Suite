local _, ns = ...

-- Shared item display helpers for Mail (preview rows, Activity, attach logs).
-- Prefer a named hyperlink; otherwise resolve via itemID. Never block on
-- ITEM_DATA_LOAD_RESULT — callers may RequestLoad and refresh later.

ns.ItemLabel = {}
local ItemLabel = ns.ItemLabel

--- True when a hyperlink has a non-empty display name (not []).
---@param link string|nil
---@return boolean
function ItemLabel.LinkHasVisibleName(link)
    if not link or link == "" then
        return false
    end
    local name = link:match("%[(.-)%]")
    return name ~= nil and name ~= ""
end

--- Extract the bracketed name from a hyperlink, or nil.
---@param link string|nil
---@return string|nil
function ItemLabel.LinkName(link)
    if not link or link == "" then
        return nil
    end
    local name = link:match("%[(.-)%]")
    if name and name ~= "" then
        return name
    end
    return nil
end

--- Plain display name for colored UI (never a hyperlink).
---@param itemID number|nil
---@param link string|nil
---@return string name
---@return boolean resolved true when a real item name was found
function ItemLabel.ResolveName(itemID, link)
    local fromLink = ItemLabel.LinkName(link)
    if fromLink then
        return fromLink, true
    end
    if itemID then
        local byID = C_Item.GetItemNameByID(itemID)
        if byID and byID ~= "" then
            return byID, true
        end
        local infoName = C_Item.GetItemInfo(itemID)
        if infoName and infoName ~= "" then
            return infoName, true
        end
        return "item:" .. tostring(itemID), false
    end
    return "?", false
end

--- Best label for chat / RunLog: named hyperlink when possible, else plain name.
---@param itemID number|nil
---@param link string|nil
---@return string
function ItemLabel.ResolveLabel(itemID, link)
    if ItemLabel.LinkHasVisibleName(link) then
        return link
    end
    local name = ItemLabel.ResolveName(itemID, nil)
    return name
end

--- Warm the item cache when name/link are not yet available (non-blocking).
---@param itemID number|nil
---@param link string|nil
function ItemLabel.RequestLoadIfNeeded(itemID, link)
    if not itemID then
        return
    end
    if ItemLabel.LinkHasVisibleName(link) then
        return
    end
    local byID = C_Item.GetItemNameByID(itemID)
    if byID and byID ~= "" then
        return
    end
    local infoName = C_Item.GetItemInfo(itemID)
    if infoName and infoName ~= "" then
        return
    end
    C_Item.RequestLoadItemDataByID(itemID)
end
