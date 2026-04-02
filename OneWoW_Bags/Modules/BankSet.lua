local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

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

function BankSet:IsWarband()
    local db = OneWoW_Bags.db
    return db.global.bankShowWarband
end

function BankSet:GetActiveTabs()
    local BankTypes = OneWoW_Bags.BankTypes
    if self:IsWarband() then
        return BankTypes.ALL_WARBAND_TABS
    else
        return BankTypes.ALL_BANK_TABS
    end
end

function BankSet:Build()
    local Pool = OneWoW_Bags.ItemPool

    self:ReleaseAll()
    self.totalSlots = 0
    self.freeSlots = 0

    local showWarband = self:IsWarband()
    local bankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
    local numPurchased = C_Bank.FetchNumPurchasedBankTabs(bankType) or 0

    local bagList = self:GetActiveTabs()
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
                self:ApplyBankScripts(button)
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
            self:RestoreBankScripts(button)
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
            local currentCount = 0
            for _ in pairs(self.slots[bagID]) do currentCount = currentCount + 1 end
            if currentCount ~= numSlots then
                self:RebuildBag(bagID, numSlots)
            else
                for slotID, button in pairs(self.slots[bagID]) do
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
        self:ApplyBankScripts(button)
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

function BankSet:UpdateQualityColors()
    local db = OneWoW_Bags.db
    local useRarity = db.global.bankRarityColor
    for bagID, bagSlots in pairs(self.slots) do
        for slotID, button in pairs(bagSlots) do
            if button.owb_itemInfo and button.owb_itemInfo.quality and button.owb_itemInfo.quality >= 1 and useRarity then
                OneWoW_GUI:UpdateIconQuality(button, button.owb_itemInfo.quality)
            else
                OneWoW_GUI:UpdateIconQuality(button, nil)
            end
        end
    end
end

function BankSet:GetAllButtons()
    local buttons = {}
    for _, bagID in ipairs(self:GetActiveTabs()) do
        if self.slots[bagID] then
            local maxSlot = 0
            for slotID in pairs(self.slots[bagID]) do
                if slotID > maxSlot then maxSlot = slotID end
            end
            for slotID = 1, maxSlot do
                local button = self.slots[bagID][slotID]
                if button then
                    tinsert(buttons, button)
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
                tinsert(buttons, self.slots[bagID][slotID])
            end
        end
    end
    return buttons
end

function BankSet:ApplyBankScripts(button)
    if button._bankScriptsApplied then return end
    button._bankScriptsApplied = true
    button.owb_isBank = true

    button._bankOrigOnClick = button:GetScript("OnClick")
    button._bankOrigOnEnter = button:GetScript("OnEnter")
    button._bankOrigOnLeave = button:GetScript("OnLeave")
    button._bankOrigOnDragStart = button:GetScript("OnDragStart")
    button._bankOrigOnReceiveDrag = button:GetScript("OnReceiveDrag")

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.SplitStack = function(self, amount)
        C_Container.SplitContainerItem(self.owb_bagID, self.owb_slotID, amount)
    end

    button:SetScript("OnClick", function(self, mouseButton)
        local bagID = self.owb_bagID
        local slotID = self.owb_slotID
        if not bagID or not slotID then return end

        if self.owb_itemInfo and self.owb_itemInfo.hyperlink then
            if HandleModifiedItemClick(self.owb_itemInfo.hyperlink) then return end
        end

        if IsModifiedClick("SPLITSTACK") and self.owb_hasItem then
            local info = C_Container.GetContainerItemInfo(bagID, slotID)
            if info and info.stackCount and info.stackCount > 1 then
                StackSplitFrame:OpenStackSplitFrame(info.stackCount, self, "BOTTOMLEFT", "TOPLEFT")
            end
            return
        end

        if mouseButton == "RightButton" then
            C_Container.UseContainerItem(bagID, slotID)
        else
            C_Container.PickupContainerItem(bagID, slotID)
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local bagID = self.owb_bagID
        local slotID = self.owb_slotID
        if bagID and slotID then
            local info = C_Container.GetContainerItemInfo(bagID, slotID)
            if info and info.hyperlink then
                GameTooltip:SetBagItem(bagID, slotID)
                GameTooltip:Show()
            end
        end
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        C_Container.PickupContainerItem(self.owb_bagID, self.owb_slotID)
    end)

    button:SetScript("OnReceiveDrag", function(self)
        C_Container.PickupContainerItem(self.owb_bagID, self.owb_slotID)
    end)
end

function BankSet:RestoreBankScripts(button)
    if not button._bankScriptsApplied then return end
    button._bankScriptsApplied = nil

    if button._bankOrigOnClick ~= nil then
        button:SetScript("OnClick", button._bankOrigOnClick)
    end
    if button._bankOrigOnEnter ~= nil then
        button:SetScript("OnEnter", button._bankOrigOnEnter)
    end
    if button._bankOrigOnLeave ~= nil then
        button:SetScript("OnLeave", button._bankOrigOnLeave)
    end
    if button._bankOrigOnDragStart ~= nil then
        button:SetScript("OnDragStart", button._bankOrigOnDragStart)
    end
    if button._bankOrigOnReceiveDrag ~= nil then
        button:SetScript("OnReceiveDrag", button._bankOrigOnReceiveDrag)
    end
    button._bankOrigOnClick = nil
    button._bankOrigOnEnter = nil
    button._bankOrigOnLeave = nil
    button._bankOrigOnDragStart = nil
    button._bankOrigOnReceiveDrag = nil
    button.SplitStack = nil
end

function BankSet:GetSlotCount()
    return self.totalSlots
end

function BankSet:GetFreeSlotCount()
    return self.freeSlots
end
