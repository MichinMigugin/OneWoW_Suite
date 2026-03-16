local ADDON_NAME, OneWoW_Bags = ...
OneWoW_Bags.BankSet = {}
local BankSet = OneWoW_Bags.BankSet

BankSet.slots = {}
BankSet.totalSlots = 0
BankSet.freeSlots = 0
BankSet.isBuilt = false
BankSet.bagContainerFrames = {}

local function GetOrCreateBankFrame(bagID)
    local name = "OneWoW_BankContainerFrame" .. bagID
    local frame = _G[name]
    if not frame then
        frame = CreateFrame("Frame", name, UIParent)
        frame:SetID(bagID)
        frame:SetSize(1, 1)
    end
    return frame
end

function BankSet:Build()
    local BagTypes = OneWoW_Bags.BagTypes
    local Pool = OneWoW_Bags.ItemPool
    local db = OneWoW_Bags.db

    self:ReleaseAll()
    self.totalSlots = 0
    self.freeSlots = 0

    local showWarband = db and db.global and db.global.bankShowWarband
    local bagList = showWarband and BagTypes.WARBAND_BAGS or BagTypes.BANK_BAGS

    local bankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
    local numPurchased = C_Bank.FetchNumPurchasedBankTabs(bankType) or 0

    for tabIdx, bagID in ipairs(bagList) do
        local bagFrame = GetOrCreateBankFrame(bagID)
        self.bagContainerFrames[bagID] = bagFrame

        self.slots[bagID] = {}

        if tabIdx <= numPurchased then
            local numSlots = C_Container.GetContainerNumSlots(bagID)
            for slotID = 1, numSlots do
                local button = Pool:Acquire()
                button:SetParent(bagFrame)
                OneWoW_Bags:ApplyItemButtonMixin(button)
                button:OWB_SetSlot(bagID, slotID)
                self.slots[bagID][slotID] = button
                self.totalSlots = self.totalSlots + 1
            end
        end
    end

    self.isBuilt = true
    self:UpdateAllSlots()
end

function BankSet:ReleaseAll()
    local Pool = OneWoW_Bags.ItemPool
    for bagID, bagSlots in pairs(self.slots) do
        for slotID, button in pairs(bagSlots) do
            Pool:Release(button)
        end
    end
    self.slots = {}
    self.bagContainerFrames = {}
    self.totalSlots = 0
    self.freeSlots = 0
    self.isBuilt = false
end

function BankSet:UpdateDirtyBags(dirtyBags)
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

function BankSet:RebuildBag(bagID, numSlots)
    local Pool = OneWoW_Bags.ItemPool
    if self.slots[bagID] then
        for slotID, button in pairs(self.slots[bagID]) do
            Pool:Release(button)
            self.totalSlots = self.totalSlots - 1
        end
    end

    local bagFrame = GetOrCreateBankFrame(bagID)
    self.bagContainerFrames[bagID] = bagFrame

    self.slots[bagID] = {}
    for slotID = 1, numSlots do
        local button = Pool:Acquire()
        button:SetParent(bagFrame)
        OneWoW_Bags:ApplyItemButtonMixin(button)
        button:OWB_SetSlot(bagID, slotID)
        button:OWB_MarkDirty()
        self.slots[bagID][slotID] = button
        self.totalSlots = self.totalSlots + 1
    end
end

function BankSet:ProcessDirtySlots()
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

function BankSet:UpdateAllSlots()
    for bagID, bagSlots in pairs(self.slots) do
        for slotID, button in pairs(bagSlots) do
            button:OWB_MarkDirty()
        end
    end
    self:ProcessDirtySlots()
end

function BankSet:GetAllButtons()
    local buttons = {}
    local BagTypes = OneWoW_Bags.BagTypes
    local db = OneWoW_Bags.db
    local showWarband = db and db.global and db.global.bankShowWarband
    local bagList = showWarband and BagTypes.WARBAND_BAGS or BagTypes.BANK_BAGS

    for _, bagID in ipairs(bagList) do
        if self.slots[bagID] then
            local maxSlot = 0
            for slotID in pairs(self.slots[bagID]) do
                if slotID > maxSlot then maxSlot = slotID end
            end
            for slotID = 1, maxSlot do
                local button = self.slots[bagID][slotID]
                if button then
                    table.insert(buttons, button)
                end
            end
        end
    end
    return buttons
end

function BankSet:GetButtonsByBag(bagID)
    local buttons = {}
    if self.slots[bagID] then
        local maxSlot = 0
        for slotID in pairs(self.slots[bagID]) do
            if slotID > maxSlot then maxSlot = slotID end
        end
        for slotID = 1, maxSlot do
            if self.slots[bagID][slotID] then
                table.insert(buttons, self.slots[bagID][slotID])
            end
        end
    end
    return buttons
end

function BankSet:GetSlotCount()
    return self.totalSlots
end

function BankSet:GetFreeSlotCount()
    return self.freeSlots
end
