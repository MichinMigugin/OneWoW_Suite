local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BagTypes = OneWoW_Bags.BagTypes
local ItemPool = OneWoW_Bags.ItemPool

local pairs, ipairs, tinsert, wipe = pairs, ipairs, tinsert, wipe

local C_Container = C_Container
local CursorHasItem = CursorHasItem
local IsControlKeyDown = IsControlKeyDown

OneWoW_Bags.BagSet = {}
local BagSet = OneWoW_Bags.BagSet

BagSet.slots = {}
BagSet.totalSlots = 0
BagSet.freeSlots = 0
BagSet.isBuilt = false
BagSet.bagContainerFrames = {}
BagSet.buttonList = {}
BagSet.bagRanges = {}
BagSet._allButtonsScratch = {}
BagSet._bagButtonsScratch = {}

local function CopyRange(source, startIndex, stopIndex, dest)
    wipe(dest)
    if not startIndex or not stopIndex then
        return dest
    end
    for index = startIndex, stopIndex do
        tinsert(dest, source[index])
    end
    return dest
end

function BagSet:RebuildButtonList()
    wipe(self.buttonList)
    wipe(self.bagRanges)

    for _, bagID in ipairs(BagTypes:GetPlayerBagIDs()) do
        local bagSlots = self.slots[bagID]
        if bagSlots then
            local startIndex = #self.buttonList + 1
            for slotID = 1, #bagSlots do
                local button = bagSlots[slotID]
                if button then
                    tinsert(self.buttonList, button)
                end
            end
            if #self.buttonList >= startIndex then
                self.bagRanges[bagID] = { startIndex, #self.buttonList }
            end
        end
    end
end

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
    self._building = true
    local Profile = OneWoW_Bags.Profile
    Profile:Start("BagSet:Build")

    Profile:Start("BagSet:Build.ReleaseAll")
    self:ReleaseAll()
    Profile:Stop("BagSet:Build.ReleaseAll")
    self.totalSlots = 0
    self.freeSlots = 0

    Profile:Start("BagSet:Build.CreateButtons")
    for _, bagID in ipairs(BagTypes:GetPlayerBagIDs()) do
        local bagFrame = GetOrCreateBagFrame(bagID)
        self.bagContainerFrames[bagID] = bagFrame

        local numSlots = C_Container.GetContainerNumSlots(bagID)
        self.slots[bagID] = {}
        for slotID = 1, numSlots do
            local button = ItemPool:Acquire()
            button:SetParent(bagFrame)
            OneWoW_Bags:ApplyItemButtonMixin(button)
            button:OWB_SetSlot(bagID, slotID)
            self:ApplyBagScripts(button)
            if OneWoW_Bags.Masque then
                OneWoW_Bags.Masque:SkinItemButton(button, "bags")
            end
            self.slots[bagID][slotID] = button
            self.totalSlots = self.totalSlots + 1
        end
    end
    Profile:Stop("BagSet:Build.CreateButtons")

    self.isBuilt = true
    Profile:Start("BagSet:Build.RebuildButtonList")
    self:RebuildButtonList()
    Profile:Stop("BagSet:Build.RebuildButtonList")

    Profile:Start("BagSet:Build.UpdateAllSlots")
    self:UpdateAllSlots("build")
    Profile:Stop("BagSet:Build.UpdateAllSlots")

    Profile:Stop("BagSet:Build")
    self._building = false
    OneWoW_Bags:RequestLayoutRefresh("bags", "build_done")
end

function BagSet:ReleaseAll()
    for _, bagSlots in pairs(self.slots) do
        for _, button in pairs(bagSlots) do
            ItemPool:Release(button)
        end
    end
    self.slots = {}
    wipe(self.buttonList)
    wipe(self.bagRanges)
    wipe(self._allButtonsScratch)
    wipe(self._bagButtonsScratch)
    self.totalSlots = 0
    self.freeSlots = 0
    self.isBuilt = false
end

function BagSet:UpdateDirtyBags(dirtyBags)
    if not self.isBuilt then return end
    local Profile = OneWoW_Bags.Profile
    for bagID in pairs(dirtyBags) do
        if self.slots[bagID] then
            if Profile then
                Profile:Start("BagSet:UpdateDirtyBags.dirtyBagCount")
                Profile:Stop("BagSet:UpdateDirtyBags.dirtyBagCount")
            end
            local numSlots = C_Container.GetContainerNumSlots(bagID)
            local currentSlots = self.slots[bagID]

            local currentCount = 0
            for _ in pairs(currentSlots) do currentCount = currentCount + 1 end

            if currentCount ~= numSlots then
                self:RebuildBag(bagID, numSlots)
            else
                for _, button in pairs(currentSlots) do
                    button:OWB_MarkDirty()
                    if Profile then
                        Profile:Start("BagSet:UpdateDirtyBags.slotMarkedDirty")
                        Profile:Stop("BagSet:UpdateDirtyBags.slotMarkedDirty")
                    end
                end
            end
        end
    end
    self:ProcessDirtySlots("bag_update")
end

function BagSet:RebuildBag(bagID, numSlots)
    if self.slots[bagID] then
        for _, button in pairs(self.slots[bagID]) do
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
        self:ApplyBagScripts(button)
        if OneWoW_Bags.Masque then
            OneWoW_Bags.Masque:SkinItemButton(button, "bags")
        end
        button:OWB_MarkDirty()
        self.slots[bagID][slotID] = button
        self.totalSlots = self.totalSlots + 1
    end
    self:RebuildButtonList()
end

-- cause: see BankSet:ProcessDirtySlots. Same convention.
function BagSet:ProcessDirtySlots(cause)
    local Profile = OneWoW_Bags.Profile
    local causeKey = cause and ("OWB_FullUpdate.cause." .. cause) or nil
    self.freeSlots = 0
    for _, bagSlots in pairs(self.slots) do
        for _, button in pairs(bagSlots) do
            if button:OWB_IsDirty() then
                button:OWB_FullUpdate()
                if Profile and causeKey then
                    Profile:Start(causeKey)
                    Profile:Stop(causeKey)
                end
            end
            if not button.owb_hasItem then
                self.freeSlots = self.freeSlots + 1
            end
        end
    end
end

function BagSet:UpdateAllSlots(cause)
    for _, bagSlots in pairs(self.slots) do
        for _, button in pairs(bagSlots) do
            button:OWB_MarkDirty()
        end
    end
    self:ProcessDirtySlots(cause)
end

--- Returns true when at least one slot was matched and re-rendered, so
--- callers can issue a layout refresh only for sets that actually changed.
function BagSet:UpdateSlotsForItems(itemIDs)
    if not self.isBuilt or not itemIDs then return false end
    local anyDirty = false
    for _, bagSlots in pairs(self.slots) do
        for _, button in pairs(bagSlots) do
            local info = button.owb_itemInfo
            local id = info and info.itemID
            if id and itemIDs[id] then
                button:OWB_MarkDirty()
                anyDirty = true
            end
        end
    end
    if anyDirty then
        self:ProcessDirtySlots("item_info")
    end
    return anyDirty
end

function BagSet:UpdateQualityColors()
    for _, bagSlots in pairs(self.slots) do
        for _, button in pairs(bagSlots) do
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
    return CopyRange(self.buttonList, 1, #self.buttonList, self._allButtonsScratch)
end

function BagSet:GetButtonList()
    return self.buttonList
end

function BagSet:GetButtonsByBag(bagID, dest)
    local scratch = dest or self._bagButtonsScratch
    local range = self.bagRanges[bagID]
    return CopyRange(self.buttonList, range and range[1], range and range[2], scratch)
end

function BagSet:ApplyBagScripts(button)
    if button._bankScriptsApplied then
        OneWoW_Bags.BankSet:RestoreBankScripts(button)
    end
    if button._bagScriptsApplied then return end
    button._bagScriptsApplied = true

    button:HookScript("OnClick", function(myself, mouseButton)
        if mouseButton == "RightButton"
            and IsControlKeyDown()
            and OneWoW_Bags.bankOpen
            and myself.owb_hasItem
            and not CursorHasItem()
        then
            OneWoW_Bags.BankController:DepositBagButtonStack(myself)
        end
    end)
end

function BagSet:GetSlotCount()
    return self.totalSlots
end

function BagSet:GetFreeSlotCount()
    return self.freeSlots
end

function BagSet:RefreshAllVisuals()
    self:UpdateAllSlots("refresh_visuals")
end
