local ADDON_NAME, OneWoW_Bags = ...
OneWoW_Bags.GuildBankSet = {}
local GBSet = OneWoW_Bags.GuildBankSet

GBSet.slots = {}
GBSet.totalSlots = 0
GBSet.freeSlots = 0
GBSet.isBuilt = false
GBSet.numTabs = 0

local function GetOrCreateGBFrame(tabID)
    local name = "OneWoW_GuildBankFrame" .. tabID
    local frame = _G[name]
    if not frame then
        frame = CreateFrame("Frame", name, UIParent)
        frame:SetID(tabID)
        frame:SetSize(1, 1)
    end
    return frame
end

function GBSet:Build()
    local Pool = OneWoW_Bags.ItemPool

    self:ReleaseAll()
    self.totalSlots = 0
    self.freeSlots = 0
    self.numTabs = GetNumGuildBankTabs() or 0

    for tabID = 1, self.numTabs do
        local name, icon, isViewable = GetGuildBankTabInfo(tabID)
        self.slots[tabID] = {}

        if isViewable then
            local gbFrame = GetOrCreateGBFrame(tabID)

            for slotID = 1, 98 do
                local button = Pool:Acquire()
                button:SetParent(gbFrame)
                OneWoW_Bags:ApplyItemButtonMixin(button)
                button.owb_bagID = tabID
                button.owb_slotID = slotID
                button:SetID(slotID)
                button.owb_isGuildBank = true
                self.slots[tabID][slotID] = button
                self.totalSlots = self.totalSlots + 1
            end
        end
    end

    self.isBuilt = true
    self:UpdateAllSlots()
end

function GBSet:ReleaseAll()
    local Pool = OneWoW_Bags.ItemPool
    for tabID, tabSlots in pairs(self.slots) do
        for slotID, button in pairs(tabSlots) do
            button.owb_isGuildBank = nil
            Pool:Release(button)
        end
    end
    self.slots = {}
    self.totalSlots = 0
    self.freeSlots = 0
    self.isBuilt = false
    self.numTabs = 0
end

function GBSet:UpdateTab(tabID)
    if not self.isBuilt then return end
    if not self.slots[tabID] then return end

    for slotID, button in pairs(self.slots[tabID]) do
        self:UpdateSlot(tabID, slotID, button)
    end
end

function GBSet:UpdateSlot(tabID, slotID, button)
    local GUILib = OneWoW_Bags.GUILib
    local db = OneWoW_Bags.db

    OneWoW_Bags.ItemPool:ClearNewItemGlow(button)

    local texture, itemCount, locked, isFiltered, quality = GetGuildBankItemInfo(tabID, slotID)
    local itemLink = GetGuildBankItemLink(tabID, slotID)

    if texture and itemLink then
        SetItemButtonTexture(button, texture)
        SetItemButtonCount(button, itemCount)
        SetItemButtonDesaturated(button, locked)

        local itemID = tonumber(itemLink:match("item:(%d+)"))
        button.owb_itemInfo = {
            itemID = itemID,
            hyperlink = itemLink,
            stackCount = itemCount,
            isLocked = locked,
            quality = quality,
            iconFileID = texture,
        }

        if quality and quality >= 1 and db and db.global and db.global.rarityColor then
            GUILib:UpdateIconQuality(button, quality)
        else
            GUILib:UpdateIconQuality(button, nil)
        end

        button.owb_hasItem = true
    else
        SetItemButtonTexture(button, nil)
        SetItemButtonCount(button, 0)
        GUILib:UpdateIconQuality(button, nil)
        button.owb_itemInfo = nil
        button.owb_hasItem = false
    end
end

function GBSet:UpdateAllSlots()
    self.freeSlots = 0
    for tabID, tabSlots in pairs(self.slots) do
        for slotID, button in pairs(tabSlots) do
            self:UpdateSlot(tabID, slotID, button)
            if not button.owb_hasItem then
                self.freeSlots = self.freeSlots + 1
            end
        end
    end
end

function GBSet:GetAllButtons()
    local buttons = {}
    for tabID = 1, self.numTabs do
        if self.slots[tabID] then
            for slotID = 1, 98 do
                local button = self.slots[tabID][slotID]
                if button then
                    table.insert(buttons, button)
                end
            end
        end
    end
    return buttons
end

function GBSet:GetButtonsByTab(tabID)
    local buttons = {}
    if self.slots[tabID] then
        for slotID = 1, 98 do
            if self.slots[tabID][slotID] then
                table.insert(buttons, self.slots[tabID][slotID])
            end
        end
    end
    return buttons
end

function GBSet:GetSlotCount()
    return self.totalSlots
end

function GBSet:GetFreeSlotCount()
    return self.freeSlots
end
