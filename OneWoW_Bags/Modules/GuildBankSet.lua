local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local ItemPool = OneWoW_Bags.ItemPool

local tonumber, pairs, ipairs = tonumber, pairs, ipairs
local GameTooltip = GameTooltip
local C_Item = C_Item

OneWoW_Bags.GuildBankSet = {}
local GBSet = OneWoW_Bags.GuildBankSet

GBSet.slots = {}
GBSet.totalSlots = 0
GBSet.freeSlots = 0
GBSet.isBuilt = false
GBSet.bagContainerFrames = {}
GBSet.numTabs = 0
GBSet.cache = {}

local SLOTS_PER_TAB = 98

local function CreateSummary()
    return {
        anyChanged = false,
        visualChanged = false,
        layoutChanged = false,
        lockChanged = false,
        changedTabs = {},
    }
end

local function MergeSummary(summary, update)
    if not update then
        return summary
    end

    if update.anyChanged then
        summary.anyChanged = true
    end
    if update.visualChanged then
        summary.visualChanged = true
    end
    if update.layoutChanged then
        summary.layoutChanged = true
    end
    if update.lockChanged then
        summary.lockChanged = true
    end

    if update.changedTabs then
        for tabID in pairs(update.changedTabs) do
            summary.changedTabs[tabID] = true
        end
    end

    return summary
end

local function BuildTabSet(tabID)
    if not tabID then
        return nil
    end

    return {
        [tabID] = true,
    }
end

local function NormalizeTabSet(tabSet, slots)
    if tabSet then
        return tabSet
    end

    local normalized = {}
    for tabID in pairs(slots) do
        normalized[tabID] = true
    end
    return normalized
end

local function BuildCachedItem(tabID, slotID)
    local texture, itemCount, locked, _, quality = GetGuildBankItemInfo(tabID, slotID)
    if not texture then
        return nil
    end

    local itemLink = GetGuildBankItemLink(tabID, slotID)
    local itemID
    if itemLink then
        itemID = C_Item.GetItemInfoInstant(itemLink)
    end
    if not itemID and itemLink then
        itemID = tonumber(itemLink:match("item:(%d+)"))
    end

    return {
        texture = texture,
        itemCount = itemCount,
        locked = locked,
        quality = quality,
        itemLink = itemLink,
        itemID = itemID,
    }
end

local function DiffCachedItem(oldItem, newItem)
    local changed = false
    local visualChanged = false
    local layoutChanged = false
    local lockChanged = false

    if oldItem == nil and newItem == nil then
        return changed, visualChanged, layoutChanged, lockChanged
    end

    if (oldItem == nil) ~= (newItem == nil) then
        changed = true
        visualChanged = true
        layoutChanged = true
        return changed, visualChanged, layoutChanged, lockChanged
    end

    if oldItem.texture ~= newItem.texture
        or oldItem.itemCount ~= newItem.itemCount
        or oldItem.locked ~= newItem.locked
        or oldItem.quality ~= newItem.quality
        or oldItem.itemLink ~= newItem.itemLink
        or oldItem.itemID ~= newItem.itemID then
        changed = true
        visualChanged = true
    end

    if oldItem.locked ~= newItem.locked then
        lockChanged = true
    end

    if oldItem.itemID ~= newItem.itemID
        or oldItem.itemLink ~= newItem.itemLink
        or oldItem.quality ~= newItem.quality then
        layoutChanged = true
    end

    return changed, visualChanged, layoutChanged, lockChanged
end

local function HideDynamicChildren(button)
    local baseCount = button._owb_baseChildCount or 0
    local children = {button:GetChildren()}
    for i = baseCount + 1, #children do
        if children[i] ~= button.ProfessionQualityOverlay then
            children[i]:Hide()
        end
    end
end

local function ClearGuildBankButton(button)
    OneWoW_Bags.ItemPool:ClearNewItemGlow(button)
    HideDynamicChildren(button)

    button:SetAlpha(1.0)
    if button._owbUnusableOverlay then button._owbUnusableOverlay:Hide() end
    if button.IconBorder then button.IconBorder:Hide() end
    if button.IconOverlay then button.IconOverlay:Hide() end
    if button.ItemContextOverlay then button.ItemContextOverlay:Hide() end
    if button.ExtendedSlot then button.ExtendedSlot:Hide() end
    if button.IconQuestTexture then button.IconQuestTexture:Hide() end
    if button.ProfessionQualityOverlay then button.ProfessionQualityOverlay:Hide() end
    if button.SetItemButtonQuality then
        button:SetItemButtonQuality(nil, nil, true)
    end

    SetItemButtonTexture(button, nil)
    SetItemButtonCount(button, 0)
    SetItemButtonDesaturated(button, false)
    OneWoW_GUI:UpdateIconQuality(button, nil)

    button.owb_itemInfo = nil
    button.owb_hasItem = false
end

local function GetOrCreateGuildBankFrame(tabID)
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
    self:ReleaseAll()
    self.totalSlots = 0
    self.numTabs = GetNumGuildBankTabs() or 0

    for tabID = 1, self.numTabs do
        self.slots[tabID] = {}
        local gbFrame = GetOrCreateGuildBankFrame(tabID)
        self.bagContainerFrames[tabID] = gbFrame

        for slotID = 1, SLOTS_PER_TAB do
            local button = ItemPool:Acquire()
            button:SetParent(gbFrame)
            OneWoW_Bags:ApplyItemButtonMixin(button)
            button.owb_bagID = tabID
            button.owb_slotID = slotID
            button:SetID(slotID)
            button.owb_isGuildBank = true
            self.slots[tabID][slotID] = button
            self.totalSlots = self.totalSlots + 1

            GBSet:ApplyGuildBankScripts(button)
        end
    end

    self.isBuilt = true
    self:UpdateAllSlots()
end

function GBSet:CacheTab(tabID)
    if not self.cache[tabID] then
        self.cache[tabID] = {}
    end

    local summary = CreateSummary()
    for slotID = 1, SLOTS_PER_TAB do
        local oldItem = self.cache[tabID][slotID]
        local newItem = BuildCachedItem(tabID, slotID)
        local changed, visualChanged, layoutChanged, lockChanged = DiffCachedItem(oldItem, newItem)

        if changed then
            summary.anyChanged = true
            summary.changedTabs[tabID] = true
        end
        if visualChanged then
            summary.visualChanged = true
        end
        if layoutChanged then
            summary.layoutChanged = true
        end
        if lockChanged then
            summary.lockChanged = true
        end

        self.cache[tabID][slotID] = newItem
    end

    return summary
end

function GBSet:CacheAllTabs()
    local summary = CreateSummary()
    for tabID = 1, self.numTabs do
        if self.slots[tabID] then
            MergeSummary(summary, self:CacheTab(tabID))
        end
    end
    return summary
end

local function ApplyCachedItemToButton(button, cached)
    OneWoW_Bags.ItemPool:ClearNewItemGlow(button)

    if cached and cached.texture then
        HideDynamicChildren(button)
        button:SetAlpha(1.0)
        if button._owbUnusableOverlay then button._owbUnusableOverlay:Hide() end
        if button.IconOverlay then button.IconOverlay:Hide() end
        if button.ItemContextOverlay then button.ItemContextOverlay:Hide() end
        if button.ExtendedSlot then button.ExtendedSlot:Hide() end
        if button.IconQuestTexture then button.IconQuestTexture:Hide() end

        SetItemButtonTexture(button, cached.texture)
        SetItemButtonCount(button, cached.itemCount)
        SetItemButtonDesaturated(button, cached.locked)

        button.owb_itemInfo = {
            itemID = cached.itemID,
            hyperlink = cached.itemLink,
            stackCount = cached.itemCount,
            isLocked = cached.locked,
            quality = cached.quality,
            iconFileID = cached.texture,
        }

        if button.SetItemButtonQuality then
            button:SetItemButtonQuality(cached.quality, cached.itemLink, false)
            if button.IconBorder then button.IconBorder:Hide() end
            if button.ProfessionQualityOverlay then
                button.ProfessionQualityOverlay:SetDrawLayer("OVERLAY", 7)
            end
        end

        if OneWoW_Bags:ShouldShowItemQuality(true, cached.quality) then
            OneWoW_GUI:UpdateIconQuality(button, cached.quality)
        else
            OneWoW_GUI:UpdateIconQuality(button, nil)
        end

        button.owb_hasItem = true
    else
        ClearGuildBankButton(button)
    end
end

function GBSet:ApplyCacheToButtons(tabSet)
    local tabs = NormalizeTabSet(tabSet, self.slots)

    for tabID in pairs(tabs) do
        local tabSlots = self.slots[tabID]
        if tabSlots then
            for slotID, button in pairs(tabSlots) do
                local cached = self.cache[tabID] and self.cache[tabID][slotID]
                ApplyCachedItemToButton(button, cached)
            end
        end
    end

    self:RecountFreeSlots()
end

function GBSet:UpdateTab(tabID)
    if not self.isBuilt then return end
    local summary = self:CacheTab(tabID)
    self:ApplyCacheToButtons(BuildTabSet(tabID))
    return summary
end

function GBSet:UpdateTabs(tabSet)
    if not self.isBuilt then return CreateSummary() end

    local tabs = NormalizeTabSet(tabSet, self.slots)
    local summary = CreateSummary()
    for tabID in pairs(tabs) do
        if self.slots[tabID] then
            MergeSummary(summary, self:CacheTab(tabID))
        end
    end

    self:ApplyCacheToButtons(tabs)
    return summary
end

function GBSet:UpdateAllSlots()
    local summary = self:CacheAllTabs()
    self:ApplyCacheToButtons()
    return summary
end

function GBSet:RefreshAllVisuals()
    self:UpdateAllSlots()
end

function GBSet:ClearCacheSlot(tabID, slotID)
    if self.cache[tabID] then
        self.cache[tabID][slotID] = nil
    end
    local tabSlots = self.slots[tabID]
    if tabSlots and tabSlots[slotID] then
        ClearGuildBankButton(tabSlots[slotID])
    end
end

function GBSet:RefreshLockVisuals(tabSet)
    if not self.isBuilt then return CreateSummary() end

    local tabs = NormalizeTabSet(tabSet, self.slots)
    local summary = CreateSummary()

    for tabID in pairs(tabs) do
        local tabSlots = self.slots[tabID]
        if tabSlots then
            for slotID, button in pairs(tabSlots) do
                if button.owb_hasItem then
                    local _, _, locked = GetGuildBankItemInfo(tabID, slotID)
                    SetItemButtonDesaturated(button, locked)
                    if button.owb_itemInfo then
                        button.owb_itemInfo.isLocked = locked
                    end
                    if self.cache[tabID] and self.cache[tabID][slotID] then
                        self.cache[tabID][slotID].locked = locked
                    end
                else
                    SetItemButtonDesaturated(button, false)
                end
            end
            summary.visualChanged = true
            summary.lockChanged = true
            summary.changedTabs[tabID] = true
        end
    end

    return summary
end

function GBSet:UpdateQualityColors()
    for tabID, tabSlots in pairs(self.slots) do
        for slotID, button in pairs(tabSlots) do
            local quality = button.owb_itemInfo and button.owb_itemInfo.quality
            if OneWoW_Bags:ShouldShowItemQuality(true, quality) then
                OneWoW_GUI:UpdateIconQuality(button, button.owb_itemInfo.quality)
            else
                OneWoW_GUI:UpdateIconQuality(button, nil)
            end
        end
    end
end

local function ShowTooltipForButton(button)
    if not button then return false end

    local tabID = button.owb_bagID
    local slotID = button.owb_slotID
    if not tabID or not slotID or not button.owb_hasItem then
        return false
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")

    if tabID == GetCurrentGuildBankTab() then
        GameTooltip:SetGuildBankItem(tabID, slotID)
    elseif button.owb_itemInfo and button.owb_itemInfo.hyperlink then
        GameTooltip:SetHyperlink(button.owb_itemInfo.hyperlink)
    else
        return false
    end

    GameTooltip:Show()
    return true
end

function GBSet:ApplyGuildBankScripts(button)
    button._gbOrigOnClick = button:GetScript("OnClick")
    button._gbOrigOnEnter = button:GetScript("OnEnter")
    button._gbOrigOnLeave = button:GetScript("OnLeave")
    button._gbOrigOnDragStart = button:GetScript("OnDragStart")
    button._gbOrigOnReceiveDrag = button:GetScript("OnReceiveDrag")

    button._gbOrigUpdateTooltip = button.UpdateTooltip
    button.UpdateTooltip = function(self)
        if not ShowTooltipForButton(self) then
            GameTooltip:Hide()
        end
    end

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.SplitStack = function(self, amount)
        SplitGuildBankItem(self.owb_bagID, self.owb_slotID, amount)
    end

    button:SetScript("OnClick", function(self, mouseButton)
        local tabID = self.owb_bagID
        local slotID = self.owb_slotID
        if not tabID or not slotID then return end

        if self.owb_itemInfo and self.owb_itemInfo.hyperlink then
            if HandleModifiedItemClick(self.owb_itemInfo.hyperlink) then return end
        end

        if IsModifiedClick("SPLITSTACK") and self.owb_hasItem then
            local texture, itemCount = GetGuildBankItemInfo(tabID, slotID)
            if itemCount and itemCount > 1 then
                StackSplitFrame:OpenStackSplitFrame(itemCount, self, "BOTTOMLEFT", "TOPLEFT")
            end
            return
        end

        local cursorType = GetCursorInfo()
        if cursorType == "money" then
            DepositGuildBankMoney(GetCursorMoney())
            ClearCursor()
            return
        elseif cursorType == "guildbankmoney" then
            DropCursorMoney()
            ClearCursor()
            return
        end

        if mouseButton == "RightButton" then
            if self.owb_hasItem then
                AutoStoreGuildBankItem(tabID, slotID)
            end
        else
            if tabID ~= GetCurrentGuildBankTab() then
                SetCurrentGuildBankTab(tabID)
            end
            local hadItem = self.owb_hasItem
            local isPlacingItem = cursorType ~= nil
            OneWoW_Bags._wasPlacingBeforeGBOp = isPlacingItem
            OneWoW_Bags._destHadItemBeforeGBOp = hadItem and isPlacingItem
            PickupGuildBankItem(tabID, slotID)
            if hadItem or isPlacingItem then
                OneWoW_Bags:TrackGuildBankTransferTab(tabID)
            end
        end
    end)

    button:SetScript("OnEnter", function(self)
        if not ShowTooltipForButton(self) then
            GameTooltip:Hide()
        end
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        local tabID = self.owb_bagID
        local slotID = self.owb_slotID
        if not tabID or not slotID then return end
        if tabID ~= GetCurrentGuildBankTab() then
            SetCurrentGuildBankTab(tabID)
        end
        local hadItem = self.owb_hasItem
        OneWoW_Bags._wasPlacingBeforeGBOp = false
        PickupGuildBankItem(tabID, slotID)
        if hadItem then
            OneWoW_Bags:TrackGuildBankTransferTab(tabID)
        end
    end)

    button:SetScript("OnReceiveDrag", function(self)
        local cursorType = GetCursorInfo()
        if cursorType == "item" then
            local tabID = self.owb_bagID
            if tabID ~= GetCurrentGuildBankTab() then
                SetCurrentGuildBankTab(tabID)
            end
            OneWoW_Bags:TrackGuildBankTransferTab(tabID)
            OneWoW_Bags._wasPlacingBeforeGBOp = true
            OneWoW_Bags._destHadItemBeforeGBOp = self.owb_hasItem
            PickupGuildBankItem(tabID, self.owb_slotID)
        end
    end)
end

function GBSet:RestoreButtonScripts(button)
    if button._gbOrigOnClick ~= nil then
        button:SetScript("OnClick", button._gbOrigOnClick)
    end
    if button._gbOrigOnEnter ~= nil then
        button:SetScript("OnEnter", button._gbOrigOnEnter)
    end
    if button._gbOrigOnLeave ~= nil then
        button:SetScript("OnLeave", button._gbOrigOnLeave)
    end
    if button._gbOrigOnDragStart ~= nil then
        button:SetScript("OnDragStart", button._gbOrigOnDragStart)
    end
    if button._gbOrigOnReceiveDrag ~= nil then
        button:SetScript("OnReceiveDrag", button._gbOrigOnReceiveDrag)
    end
    button._gbOrigOnClick = nil
    button._gbOrigOnEnter = nil
    button._gbOrigOnLeave = nil
    button._gbOrigOnDragStart = nil
    button._gbOrigOnReceiveDrag = nil
    button.UpdateTooltip = button._gbOrigUpdateTooltip
    button._gbOrigUpdateTooltip = nil
    button.SplitStack = nil
end

function GBSet:ReleaseAll()
    local Pool = OneWoW_Bags.ItemPool
    for tabID, tabSlots in pairs(self.slots) do
        for slotID, button in pairs(tabSlots) do
            GBSet:RestoreButtonScripts(button)
            button.owb_isGuildBank = nil
            Pool:Release(button)
        end
    end
    self.slots = {}
    self.bagContainerFrames = {}
    self.totalSlots = 0
    self.freeSlots = 0
    self.numTabs = 0
    self.isBuilt = false
end

function GBSet:ClearCache()
    self.cache = {}
end

function GBSet:GetAllButtons()
    local buttons = {}
    for tabID = 1, self.numTabs do
        if self.slots[tabID] then
            for slotID = 1, SLOTS_PER_TAB do
                local button = self.slots[tabID][slotID]
                if button then
                    tinsert(buttons, button)
                end
            end
        end
    end
    return buttons
end

function GBSet:GetButtonsByTab(tabID)
    local buttons = {}
    if self.slots[tabID] then
        for slotID = 1, SLOTS_PER_TAB do
            if self.slots[tabID][slotID] then
                tinsert(buttons, self.slots[tabID][slotID])
            end
        end
    end
    return buttons
end

function GBSet:RecountFreeSlots()
    self.freeSlots = 0
    for tabID, tabSlots in pairs(self.slots) do
        for slotID, button in pairs(tabSlots) do
            if not button.owb_hasItem then
                self.freeSlots = self.freeSlots + 1
            end
        end
    end
end

function GBSet:GetSlotCount()
    return self.totalSlots
end

function GBSet:GetFreeSlotCount()
    return self.freeSlots
end
