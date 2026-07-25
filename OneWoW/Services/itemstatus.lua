local _, ns = ...

ns.ItemStatus = {}
local IS = ns.ItemStatus
local callbacks = {}

function IS:RegisterCallback(id, fn)
    callbacks[id] = fn
end

local function FireCallbacks()
    for _, fn in pairs(callbacks) do
        fn()
    end
end

-- Junk/Protected status feeds PredicateEngine (#markedjunk / #protected /
-- #junk). PE caches per-item props, and OverlayEngine same-item skip_same
-- skips icon rebuild when paintGeneration is unchanged — so a plain Refresh
-- leaves stale visuals until reload. InvalidateAndRequestRefresh wipes props,
-- bumps paintGeneration, and coalesces a full icon rebuild.
local function RefreshOverlaysForStatusChange()
    ns.OverlayEngine:InvalidateAndRequestRefresh()
    FireCallbacks()
end

local function GetDB()
    return ns.db.global.itemStatus
end

function IS:GetAllStatuses()
    return GetDB()
end

function IS:GetItemStatus(itemID)
    if not itemID then return nil end
    itemID = tonumber(itemID)
    if not itemID then return nil end
    return GetDB()[itemID]
end

function IS:IsItemJunk(itemID)
    if not itemID then return false end
    itemID = tonumber(itemID)
    if not itemID then return false end
    local statusData = self:GetItemStatus(itemID)
    return statusData and statusData.status == "Junk" or false
end

function IS:IsItemProtected(itemID)
    if not itemID then return false end
    itemID = tonumber(itemID)
    if not itemID then return false end
    local statusData = self:GetItemStatus(itemID)
    return statusData and statusData.status == "Protected" or false
end

function IS:GetJunkItems()
    local junkItems = {}
    for itemID, statusData in pairs(GetDB()) do
        if statusData.status == "Junk" then
            junkItems[itemID] = statusData
        end
    end
    return junkItems
end

function IS:SaveItemStatus(itemID, statusData)
    if not itemID or not statusData then return end
    itemID = tonumber(itemID)
    if not itemID then return end
    GetDB()[itemID] = statusData
end

function IS:RemoveItemStatus(itemID)
    if not itemID then return end
    itemID = tonumber(itemID)
    if not itemID then return end
    GetDB()[itemID] = nil
    RefreshOverlaysForStatusChange()
end

function IS:MarkAsJunk(itemID, inputLink)
    if not itemID then return false end
    itemID = tonumber(itemID)
    if not itemID then return false end
    local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, _, itemTexture = C_Item.GetItemInfo(itemID)
    if not itemName then return false end
    if inputLink then
        local actualItemLevel = C_Item.GetDetailedItemLevelInfo(inputLink)
        if actualItemLevel and actualItemLevel > 0 then itemLevel = actualItemLevel end
        local _, _, linkRarity = C_Item.GetItemInfo(inputLink)
        if linkRarity then itemRarity = linkRarity end
    end
    if self:IsItemProtected(itemID) then
        self:SaveItemStatus(itemID, nil)
        GetDB()[itemID] = nil
    end
    self:SaveItemStatus(itemID, {
        itemID = itemID,
        name = itemName,
        link = itemLink,
        icon = itemTexture,
        level = itemLevel,
        rarity = itemRarity,
        type = itemType,
        subType = itemSubType,
        status = "Junk",
        junkQuality = itemRarity,
        junkItemLevel = itemLevel,
        lastSeen = GetServerTime(),
    })
    RefreshOverlaysForStatusChange()
    return true
end

function IS:MarkAsProtected(itemID, inputLink)
    if not itemID then return false end
    itemID = tonumber(itemID)
    if not itemID then return false end
    local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, _, itemTexture = C_Item.GetItemInfo(itemID)
    if not itemName then return false end
    if inputLink then
        local actualItemLevel = C_Item.GetDetailedItemLevelInfo(inputLink)
        if actualItemLevel and actualItemLevel > 0 then itemLevel = actualItemLevel end
        local _, _, linkRarity = C_Item.GetItemInfo(inputLink)
        if linkRarity then itemRarity = linkRarity end
    end
    if self:IsItemJunk(itemID) then
        GetDB()[itemID] = nil
    end
    self:SaveItemStatus(itemID, {
        itemID = itemID,
        name = itemName,
        link = itemLink,
        icon = itemTexture,
        level = itemLevel,
        rarity = itemRarity,
        type = itemType,
        subType = itemSubType,
        status = "Protected",
        lastSeen = GetServerTime(),
    })
    RefreshOverlaysForStatusChange()
    return true
end

function ns:MarkItemJunkKeybind()
    local L = ns.L
    local infoType, itemID, itemLink = GetCursorInfo()
    if infoType == "item" and itemID then
        if ns.ItemStatus:IsItemJunk(itemID) then
            ns.ItemStatus:RemoveItemStatus(itemID)
            local name = C_Item.GetItemInfo(itemID)
            print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_REMOVED_JUNK"], name or itemID))
        else
            ns.ItemStatus:MarkAsJunk(itemID, itemLink)
            local name = C_Item.GetItemInfo(itemID)
            print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_MARKED_JUNK"], name or itemID))
        end
        ClearCursor()
        return
    end

    local _, link = GameTooltip:GetItem()
    if link then
        local id = C_Item.GetItemInfoInstant(link)
        if id then
            if ns.ItemStatus:IsItemJunk(id) then
                ns.ItemStatus:RemoveItemStatus(id)
                local name = C_Item.GetItemInfo(id)
                print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_REMOVED_JUNK"], name or id))
            else
                ns.ItemStatus:MarkAsJunk(id, link)
                local name = C_Item.GetItemInfo(id)
                print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_MARKED_JUNK"], name or id))
            end
            return
        end
    end

    print("|cFF00FF00OneWoW|r: " .. L["ITEMSTATUS_HOVER_HINT"])
end

function ns:MarkItemProtectedKeybind()
    local L = ns.L
    local infoType, itemID, itemLink = GetCursorInfo()
    if infoType == "item" and itemID then
        if ns.ItemStatus:IsItemProtected(itemID) then
            ns.ItemStatus:RemoveItemStatus(itemID)
            local name = C_Item.GetItemInfo(itemID)
            print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_REMOVED_PROTECTED"], name or itemID))
        else
            ns.ItemStatus:MarkAsProtected(itemID, itemLink)
            local name = C_Item.GetItemInfo(itemID)
            print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_MARKED_PROTECTED"], name or itemID))
        end
        ClearCursor()
        return
    end

    local _, link = GameTooltip:GetItem()
    if link then
        local id = C_Item.GetItemInfoInstant(link)
        if id then
            if ns.ItemStatus:IsItemProtected(id) then
                ns.ItemStatus:RemoveItemStatus(id)
                local name = C_Item.GetItemInfo(id)
                print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_REMOVED_PROTECTED"], name or id))
            else
                ns.ItemStatus:MarkAsProtected(id, link)
                local name = C_Item.GetItemInfo(id)
                print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_MARKED_PROTECTED"], name or id))
            end
            return
        end
    end

    print("|cFF00FF00OneWoW|r: " .. L["ITEMSTATUS_HOVER_HINT"])
end
