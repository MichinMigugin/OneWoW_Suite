local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BagTypes = OneWoW_Bags.BagTypes
local ItemPool = OneWoW_Bags.ItemPool

local pairs, ipairs, tinsert = pairs, ipairs, tinsert

local C_Container = C_Container

OneWoW_Bags.BagSet = {}
local BagSet = OneWoW_Bags.BagSet

BagSet.slots = {}
BagSet.totalSlots = 0
BagSet.freeSlots = 0
BagSet.isBuilt = false
BagSet.bagContainerFrames = {}

local function GetOrCreateBagFrame(bagID)
    local name = "OneWoW_BagContainerFrame" .. bagID
    local frame = _G[name]
    if not frame then
        frame = CreateFrame("Frame", name, UIParent)
        frame:SetID(bagID)
        frame:SetSize(1, 1)
    end
    return frame
end

function BagSet:Build()
    self:ReleaseAll()
    self.totalSlots = 0
    self.freeSlots = 0

    for _, bagID in ipairs(BagTypes.ALL_PLAYER_BAGS) do
        local bagFrame = GetOrCreateBagFrame(bagID)
        self.bagContainerFrames[bagID] = bagFrame

        local numSlots = C_Container.GetContainerNumSlots(bagID)
        self.slots[bagID] = {}
        for slotID = 1, numSlots do
            local button = ItemPool:Acquire()
            button:SetParent(bagFrame)
            OneWoW_Bags:ApplyItemButtonMixin(button)
            button:OWB_SetSlot(bagID, slotID)
            self.slots[bagID][slotID] = button
            self.totalSlots = self.totalSlots + 1
        end
    end

    self.isBuilt = true
    self:UpdateAllSlots()
end

function BagSet:ReleaseAll()
    for bagID, bagSlots in pairs(self.slots) do
        for slotID, button in pairs(bagSlots) do
            ItemPool:Release(button)
        end
    end
    self.slots = {}
    self.totalSlots = 0
    self.freeSlots = 0
    self.isBuilt = false
end

function BagSet:UpdateDirtyBags(dirtyBags)
    if not self.isBuilt then return end
    for bagID in pairs(dirtyBags) do
        if self.slots[bagID] then
            local numSlots = C_Container.GetContainerNumSlots(bagID)
            local currentSlots = self.slots[bagID]

            local currentCount = 0
            for _ in pairs(currentSlots) do currentCount = currentCount + 1 end

            if currentCount ~= numSlots then
                self:RebuildBag(bagID, numSlots)
            else
                for slotID, button in pairs(currentSlots) do
                    button:OWB_MarkDirty()
                end
            end
        end
    end
    self:ProcessDirtySlots()
end

function BagSet:RebuildBag(bagID, numSlots)
    if self.slots[bagID] then
        for slotID, button in pairs(self.slots[bagID]) do
            ItemPool:Release(button)
            self.totalSlots = self.totalSlots - 1
        end
    end

    local bagFrame = GetOrCreateBagFrame(bagID)
    self.bagContainerFrames[bagID] = bagFrame

    self.slots[bagID] = {}
    for slotID = 1, numSlots do
        local button = ItemPool:Acquire()
        button:SetParent(bagFrame)
        OneWoW_Bags:ApplyItemButtonMixin(button)
        button:OWB_SetSlot(bagID, slotID)
        button:OWB_MarkDirty()
        self.slots[bagID][slotID] = button
        self.totalSlots = self.totalSlots + 1
    end
end

function BagSet:ProcessDirtySlots()
    self.freeSlots = 0
    for bagID, bagSlots in pairs(self.slots) do
        for slotID, button in pairs(bagSlots) do
            if button:OWB_IsDirty() then
                button:OWB_FullUpdate()
            end
            if not button.owb_hasItem then
                self.freeSlots = self.freeSlots + 1
            end
        end
    end
end

function BagSet:UpdateAllSlots()
    for bagID, bagSlots in pairs(self.slots) do
        for slotID, button in pairs(bagSlots) do
            button:OWB_MarkDirty()
        end
    end
    self:ProcessDirtySlots()
end

function BagSet:UpdateQualityColors()
    for bagID, bagSlots in pairs(self.slots) do
        for slotID, button in pairs(bagSlots) do
            local quality = button.owb_itemInfo and button.owb_itemInfo.quality
            if OneWoW_Bags:ShouldShowItemQuality(false, quality) then
                OneWoW_GUI:UpdateIconQuality(button, button.owb_itemInfo.quality)
            else
                OneWoW_GUI:UpdateIconQuality(button, nil)
            end
        end
    end
end

function BagSet:GetAllButtons()
    local buttons = {}
    for _, bagID in ipairs(BagTypes.ALL_PLAYER_BAGS) do
        if self.slots[bagID] then
            for slotID = 1, #self.slots[bagID] do
                local button = self.slots[bagID][slotID]
                if button then
                    tinsert(buttons, button)
                end
            end
        end
    end
    return buttons
end

function BagSet:GetButtonsByBag(bagID)
    local buttons = {}
    if self.slots[bagID] then
        for slotID = 1, #self.slots[bagID] do
            if self.slots[bagID][slotID] then
                tinsert(buttons, self.slots[bagID][slotID])
            end
        end
    end
    return buttons
end

function BagSet:GetSlotCount()
    return self.totalSlots
end

function BagSet:GetFreeSlotCount()
    return self.freeSlots
end

function BagSet:RefreshAllVisuals()
    self:UpdateAllSlots()
end
