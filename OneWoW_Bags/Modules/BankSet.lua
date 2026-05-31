local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BankTypes = OneWoW_Bags.BankTypes
local ItemPool = OneWoW_Bags.ItemPool

local ipairs, pairs, tinsert, wipe = ipairs, pairs, tinsert, wipe
local C_Bank, C_Container = C_Bank, C_Container

OneWoW_Bags.BankSet = {}
local BankSet = OneWoW_Bags.BankSet

BankSet.slots = {}
BankSet.totalSlots = 0
BankSet.freeSlots = 0
BankSet.isBuilt = false
BankSet.bagContainerFrames = {}
BankSet.buttonList = {}
BankSet.bagRanges = {}
BankSet._allButtonsScratch = {}
BankSet._bagButtonsScratch = {}
-- Tracks which bag tabs have had their item buttons materialized this bank
-- session. Used to keep both personal and warband modes resident after their
-- first build so toggling between them is near-instant.
BankSet.builtTabs = {}

local function MasqueKindFor(bagID)
    if BankTypes:IsWarbandTab(bagID) then
        return "warband"
    end
    return "bank"
end

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
    local db = OneWoW_Bags:GetDB()
    return db.global.bankShowWarband
end

function BankSet:GetActiveTabs()
    if self:IsWarband() then
        return BankTypes:GetWarbandTabIDs()
    else
        return BankTypes:GetBankTabIDs()
    end
end

function BankSet:RebuildButtonList()
    wipe(self.buttonList)
    wipe(self.bagRanges)

    for _, bagID in ipairs(self:GetActiveTabs()) do
        local bagSlots = self.slots[bagID]
        if bagSlots then
            local startIndex = #self.buttonList + 1
            local maxSlot = 0
            for slotID in pairs(bagSlots) do
                if slotID > maxSlot then maxSlot = slotID end
            end
            for slotID = 1, maxSlot do
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

    self.totalSlots = #self.buttonList
end

-- Materialize item buttons for a single bag tab. Idempotent at the slot
-- level: existing buttons in the tab are kept, missing slots are filled.
function BankSet:BuildTab(bagID, masqueKind, numSlots)
    local Profile = OneWoW_Bags.Profile
    local bagFrame = GetOrCreateBankFrame(bagID)
    self.bagContainerFrames[bagID] = bagFrame
    if not self.slots[bagID] then
        self.slots[bagID] = {}
    end

    for slotID = 1, numSlots do
        if not self.slots[bagID][slotID] then
            if Profile then Profile:Start("BankSet:CreateButton.Acquire") end
            local button = ItemPool:Acquire()
            button:SetParent(bagFrame)
            if Profile then Profile:Stop("BankSet:CreateButton.Acquire") end

            if Profile then Profile:Start("BankSet:CreateButton.ApplyMixin") end
            OneWoW_Bags:ApplyItemButtonMixin(button)
            if Profile then Profile:Stop("BankSet:CreateButton.ApplyMixin") end

            if Profile then Profile:Start("BankSet:CreateButton.SetSlot") end
            button:OWB_SetSlot(bagID, slotID)
            if Profile then Profile:Stop("BankSet:CreateButton.SetSlot") end

            if Profile then Profile:Start("BankSet:CreateButton.ApplyScripts") end
            self:ApplyBankScripts(button)
            if Profile then Profile:Stop("BankSet:CreateButton.ApplyScripts") end

            if OneWoW_Bags.Masque then
                if Profile then Profile:Start("BankSet:CreateButton.Masque") end
                OneWoW_Bags.Masque:SkinItemButton(button, masqueKind)
                if Profile then Profile:Stop("BankSet:CreateButton.Masque") end
            end
            self.slots[bagID][slotID] = button
        end
    end

    self.builtTabs[bagID] = true
end

-- Show container frames for the active mode's tabs, hide others. Also
-- rebuilds buttonList so downstream consumers (layout, search, sort) see
-- only active-mode buttons.
function BankSet:SetActiveModeVisibility(showWarband)
    if showWarband == nil then
        showWarband = self:IsWarband()
    end

    local activeTabs = showWarband and BankTypes:GetWarbandTabIDs() or BankTypes:GetBankTabIDs()
    local activeSet = {}
    for _, bagID in ipairs(activeTabs) do
        activeSet[bagID] = true
    end

    for bagID, frame in pairs(self.bagContainerFrames) do
        if activeSet[bagID] then
            frame:Show()
        else
            frame:Hide()
        end
    end

    self:RebuildButtonList()
end

function BankSet:Build()
    self._building = true
    local Profile = OneWoW_Bags.Profile
    Profile:Start("BankSet:Build")

    local showWarband = self:IsWarband()
    local bankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
    local numPurchased = C_Bank.FetchNumPurchasedBankTabs(bankType) or 0
    local masqueKind = showWarband and "warband" or "bank"
    local createLabel = showWarband and "BankSet:Build.CreateButtons[warband]" or "BankSet:Build.CreateButtons[bank]"

    local newTabsBuilt = false

    Profile:Start(createLabel)
    for tabIdx, bagID in ipairs(self:GetActiveTabs()) do
        if not self.builtTabs[bagID] and tabIdx <= numPurchased then
            local numSlots = C_Container.GetContainerNumSlots(bagID)
            self:BuildTab(bagID, masqueKind, numSlots)
            newTabsBuilt = true
        elseif not self.bagContainerFrames[bagID] then
            -- Ensure unpurchased active-mode tabs still have an empty
            -- container frame so the layout controller has something to
            -- iterate; matches the original Build's behavior.
            local bagFrame = GetOrCreateBankFrame(bagID)
            self.bagContainerFrames[bagID] = bagFrame
            if not self.slots[bagID] then
                self.slots[bagID] = {}
            end
        end
    end
    Profile:Stop(createLabel)

    self.isBuilt = true

    Profile:Start("BankSet:Build.SetActiveMode")
    self:SetActiveModeVisibility(showWarband)
    Profile:Stop("BankSet:Build.SetActiveMode")

    -- Only refresh slot data when new tabs were just materialized. The
    -- cached inactive mode is kept fresh via UpdateDirtyBags as BAG_UPDATE
    -- events arrive, so a pure toggle to a previously-built mode does no
    -- per-button work here.
    if newTabsBuilt then
        Profile:Start("BankSet:Build.UpdateAllSlots")
        self:UpdateAllSlots("build")
        Profile:Stop("BankSet:Build.UpdateAllSlots")
    else
        Profile:Start("BankSet:Build.ProcessDirtySlots")
        self:ProcessDirtySlots("build_toggle")
        Profile:Stop("BankSet:Build.ProcessDirtySlots")
    end

    Profile:Stop("BankSet:Build")
    self._building = false
    OneWoW_Bags:RequestLayoutRefresh("bank", "build_done")
end

function BankSet:ReleaseAll()
    for _, bagSlots in pairs(self.slots) do
        for _, button in pairs(bagSlots) do
            self:RestoreBankScripts(button)
            ItemPool:Release(button)
        end
    end
    for _, frame in pairs(self.bagContainerFrames) do
        if frame and frame.Hide then
            frame:Hide()
        end
    end
    self.slots = {}
    self.bagContainerFrames = {}
    wipe(self.builtTabs)
    wipe(self.buttonList)
    wipe(self.bagRanges)
    wipe(self._allButtonsScratch)
    wipe(self._bagButtonsScratch)
    self.totalSlots = 0
    self.freeSlots = 0
    self.isBuilt = false
end

function BankSet:UpdateDirtyBags(dirtyBags)
    if not self.isBuilt then return end
    local Profile = OneWoW_Bags.Profile
    for bagID in pairs(dirtyBags) do
        if self.slots[bagID] then
            if Profile then
                Profile:Start("BankSet:UpdateDirtyBags.dirtyBagCount")
                Profile:Stop("BankSet:UpdateDirtyBags.dirtyBagCount")
            end
            local numSlots = C_Container.GetContainerNumSlots(bagID)
            local currentCount = 0
            for _ in pairs(self.slots[bagID]) do currentCount = currentCount + 1 end
            if currentCount ~= numSlots then
                self:RebuildBag(bagID, numSlots)
            else
                for _, button in pairs(self.slots[bagID]) do
                    button:OWB_MarkDirty()
                    if Profile then
                        Profile:Start("BankSet:UpdateDirtyBags.slotMarkedDirty")
                        Profile:Stop("BankSet:UpdateDirtyBags.slotMarkedDirty")
                    end
                end
            end
        end
    end
    self:ProcessDirtySlots("bag_update")
end

function BankSet:RebuildBag(bagID, numSlots)
    if self.slots[bagID] then
        for _, button in pairs(self.slots[bagID]) do
            self:RestoreBankScripts(button)
            ItemPool:Release(button)
        end
    end

    local bagFrame = GetOrCreateBankFrame(bagID)
    self.bagContainerFrames[bagID] = bagFrame
    self.slots[bagID] = {}

    if numSlots <= 0 then
        self.builtTabs[bagID] = nil
        self:RebuildButtonList()
        return
    end

    local masqueKind = MasqueKindFor(bagID)
    for slotID = 1, numSlots do
        local button = ItemPool:Acquire()
        button:SetParent(bagFrame)
        OneWoW_Bags:ApplyItemButtonMixin(button)
        button:OWB_SetSlot(bagID, slotID)
        self:ApplyBankScripts(button)
        if OneWoW_Bags.Masque then
            OneWoW_Bags.Masque:SkinItemButton(button, masqueKind)
        end
        button:OWB_MarkDirty()
        self.slots[bagID][slotID] = button
    end
    self.builtTabs[bagID] = true
    self:RebuildButtonList()
end

-- Processes any dirty buttons across BOTH modes so the cached inactive
-- mode stays correct for instant toggles. Free-slot counter is scoped to
-- the active mode (buttonList already filters to it).
--
-- cause: diagnostic tag attributed to each OWB_FullUpdate executed by this
-- pass (e.g. "build", "bag_update", "item_info"). Lets /owbprof show which
-- call site is driving the bulk of per-button updates without changing
-- behavior.
function BankSet:ProcessDirtySlots(cause)
    local Profile = OneWoW_Bags.Profile
    local causeKey = cause and ("OWB_FullUpdate.cause." .. cause) or nil
    for _, bagSlots in pairs(self.slots) do
        for _, button in pairs(bagSlots) do
            if button:OWB_IsDirty() then
                button:OWB_FullUpdate()
                if Profile and causeKey then
                    Profile:Start(causeKey)
                    Profile:Stop(causeKey)
                end
            end
        end
    end

    self.freeSlots = 0
    for _, button in ipairs(self.buttonList) do
        if not button.owb_hasItem then
            self.freeSlots = self.freeSlots + 1
        end
    end
end

function BankSet:UpdateAllSlots(cause)
    for _, bagSlots in pairs(self.slots) do
        for _, button in pairs(bagSlots) do
            button:OWB_MarkDirty()
        end
    end
    self:ProcessDirtySlots(cause)
end

--- Returns true when at least one slot was matched and re-rendered, so
--- callers can issue a layout refresh only for sets that actually changed.
function BankSet:UpdateSlotsForItems(itemIDs)
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

function BankSet:RefreshAllVisuals()
    self:UpdateAllSlots("refresh_visuals")
end

function BankSet:UpdateQualityColors()
    for _, bagSlots in pairs(self.slots) do
        for _, button in pairs(bagSlots) do
            local quality = button.owb_itemInfo and button.owb_itemInfo.quality
            if OneWoW_Bags:ShouldShowItemQuality(true, quality) then
                OneWoW_GUI:UpdateIconQuality(button, button.owb_itemInfo.quality)
            else
                OneWoW_GUI:UpdateIconQuality(button, nil)
            end
        end
    end
end

function BankSet:GetAllButtons()
    return CopyRange(self.buttonList, 1, #self.buttonList, self._allButtonsScratch)
end

function BankSet:GetButtonList()
    return self.buttonList
end

function BankSet:GetButtonsByBag(bagID, dest)
    local scratch = dest or self._bagButtonsScratch
    local range = self.bagRanges[bagID]
    return CopyRange(self.buttonList, range and range[1], range and range[2], scratch)
end

function BankSet:ApplyBankScripts(button)
    if button._bankScriptsApplied then return end
    button._bankScriptsApplied = true
    button.owb_isBank = true

    button._bankOrigOnEnter = button:GetScript("OnEnter")
    button._bankOrigOnLeave = button:GetScript("OnLeave")

    button:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        local bagID = myself.owb_bagID
        local slotID = myself.owb_slotID
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
end

function BankSet:RestoreBankScripts(button)
    if not button._bankScriptsApplied then return end
    button._bankScriptsApplied = nil
    button.owb_isBank = nil

    button:SetScript("OnEnter", button._bankOrigOnEnter)
    button:SetScript("OnLeave", button._bankOrigOnLeave)
    button._bankOrigOnEnter = nil
    button._bankOrigOnLeave = nil
end

function BankSet:GetSlotCount()
    return self.totalSlots
end

function BankSet:GetFreeSlotCount()
    return self.freeSlots
end
