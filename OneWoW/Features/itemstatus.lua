local ADDON_NAME, OneWoW = ...

OneWoW.ItemStatus = {}
local IS = OneWoW.ItemStatus
local callbacks = {}

function IS:RegisterCallback(id, fn)
    callbacks[id] = fn
end

local function FireCallbacks()
    for _, fn in pairs(callbacks) do
        fn()
    end
end

local function GetDB()
    return OneWoW.db and OneWoW.db.global and OneWoW.db.global.itemStatus
end

function IS:Initialize()
    if not OneWoW.db or not OneWoW.db.global then return end
    if not OneWoW.db.global.itemStatus then
        OneWoW.db.global.itemStatus = {}
    end
end

function IS:GetAllStatuses()
    local db = GetDB()
    if not db then return {} end
    return db
end

function IS:GetItemStatus(itemID)
    if not itemID then return nil end
    itemID = tonumber(itemID)
    if not itemID then return nil end
    local db = GetDB()
    if not db then return nil end
    return db[itemID]
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
    local db = GetDB()
    if not db then return junkItems end
    for itemID, statusData in pairs(db) do
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
    local db = GetDB()
    if not db then return end
    db[itemID] = statusData
end

function IS:RemoveItemStatus(itemID)
    if not itemID then return end
    itemID = tonumber(itemID)
    if not itemID then return end
    local db = GetDB()
    if not db then return end
    db[itemID] = nil
    if OneWoW.OverlayEngine then
        C_Timer.After(0.05, function()
            OneWoW.OverlayEngine:Refresh()
            FireCallbacks()
        end)
    else
        FireCallbacks()
    end
end

function IS:MarkAsJunk(itemID, inputLink)
    if not itemID then return false end
    itemID = tonumber(itemID)
    if not itemID then return false end
    local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, _, itemTexture = C_Item.GetItemInfo(itemID)
    if not itemName then return false end
    if inputLink and C_Item.GetDetailedItemLevelInfo then
        local actualItemLevel = C_Item.GetDetailedItemLevelInfo(inputLink)
        if actualItemLevel and actualItemLevel > 0 then itemLevel = actualItemLevel end
        local _, _, linkRarity = C_Item.GetItemInfo(inputLink)
        if linkRarity then itemRarity = linkRarity end
    end
    if self:IsItemProtected(itemID) then
        self:SaveItemStatus(itemID, nil)
        local db = GetDB()
        if db then db[itemID] = nil end
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
    if OneWoW.OverlayEngine then
        C_Timer.After(0.05, function()
            OneWoW.OverlayEngine:Refresh()
            FireCallbacks()
        end)
    else
        FireCallbacks()
    end
    return true
end

function IS:MarkAsProtected(itemID, inputLink)
    if not itemID then return false end
    itemID = tonumber(itemID)
    if not itemID then return false end
    local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, _, itemTexture = C_Item.GetItemInfo(itemID)
    if not itemName then return false end
    if inputLink and C_Item.GetDetailedItemLevelInfo then
        local actualItemLevel = C_Item.GetDetailedItemLevelInfo(inputLink)
        if actualItemLevel and actualItemLevel > 0 then itemLevel = actualItemLevel end
        local _, _, linkRarity = C_Item.GetItemInfo(inputLink)
        if linkRarity then itemRarity = linkRarity end
    end
    if self:IsItemJunk(itemID) then
        local db = GetDB()
        if db then db[itemID] = nil end
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
    if OneWoW.OverlayEngine then
        C_Timer.After(0.05, function()
            OneWoW.OverlayEngine:Refresh()
            FireCallbacks()
        end)
    else
        FireCallbacks()
    end
    return true
end

function OneWoW:MarkItemJunkKeybind()
    local L = OneWoW.L
    local infoType, itemID, itemLink = GetCursorInfo()
    if infoType == "item" and itemID then
        if OneWoW.ItemStatus:IsItemJunk(itemID) then
            OneWoW.ItemStatus:RemoveItemStatus(itemID)
            local name = C_Item.GetItemInfo(itemID)
            print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_REMOVED_JUNK"], name or itemID))
        else
            OneWoW.ItemStatus:MarkAsJunk(itemID, itemLink)
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
            if OneWoW.ItemStatus:IsItemJunk(id) then
                OneWoW.ItemStatus:RemoveItemStatus(id)
                local name = C_Item.GetItemInfo(id)
                print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_REMOVED_JUNK"], name or id))
            else
                OneWoW.ItemStatus:MarkAsJunk(id, link)
                local name = C_Item.GetItemInfo(id)
                print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_MARKED_JUNK"], name or id))
            end
            return
        end
    end

    print("|cFF00FF00OneWoW|r: " .. L["ITEMSTATUS_HOVER_HINT"])
end

function OneWoW:MarkItemProtectedKeybind()
    local L = OneWoW.L
    local infoType, itemID, itemLink = GetCursorInfo()
    if infoType == "item" and itemID then
        if OneWoW.ItemStatus:IsItemProtected(itemID) then
            OneWoW.ItemStatus:RemoveItemStatus(itemID)
            local name = C_Item.GetItemInfo(itemID)
            print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_REMOVED_PROTECTED"], name or itemID))
        else
            OneWoW.ItemStatus:MarkAsProtected(itemID, itemLink)
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
            if OneWoW.ItemStatus:IsItemProtected(id) then
                OneWoW.ItemStatus:RemoveItemStatus(id)
                local name = C_Item.GetItemInfo(id)
                print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_REMOVED_PROTECTED"], name or id))
            else
                OneWoW.ItemStatus:MarkAsProtected(id, link)
                local name = C_Item.GetItemInfo(id)
                print("|cFF00FF00OneWoW|r: " .. string.format(L["ITEMSTATUS_MARKED_PROTECTED"], name or id))
            end
            return
        end
    end

    print("|cFF00FF00OneWoW|r: " .. L["ITEMSTATUS_HOVER_HINT"])
end
