local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local ItemPool = OneWoW_Bags.ItemPool

local tonumber, pairs, tinsert, wipe, select = tonumber, pairs, tinsert, wipe, select
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
GBSet.buttonList = {}
GBSet.tabRanges = {}
GBSet._allButtonsScratch = {}
GBSet._tabButtonsScratch = {}

local SLOTS_PER_TAB = 98

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
    local childCount = select("#", button:GetChildren())
    for i = baseCount + 1, childCount do
        local child = select(i, button:GetChildren())
        if child and child ~= button.ProfessionQualityOverlay then
            child:Hide()
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
    button._owb_sortName = nil
    button._owb_ilvl = nil
    button._owb_expansionID = nil
    button._owb_classID = nil
    button._owb_subClassID = nil
    button._owb_itemQuality = nil
    button._owb_reagentQuality = nil
    button._owb_craftedQuality = nil
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

function GBSet:RebuildButtonList()
    wipe(self.buttonList)
    wipe(self.tabRanges)

    for tabID = 1, self.numTabs do
        local tabSlots = self.slots[tabID]
        if tabSlots then
            local startIndex = #self.buttonList + 1
            for slotID = 1, SLOTS_PER_TAB do
                local button = tabSlots[slotID]
                if button then
                    tinsert(self.buttonList, button)
                end
            end
            if #self.buttonList >= startIndex then
                self.tabRanges[tabID] = { startIndex, #self.buttonList }
            end
        end
    end
end

function GBSet:Build()
    self._building = true
    local Profile = OneWoW_Bags.Profile
    Profile:Start("GuildBankSet:Build")

    Profile:Start("GuildBankSet:Build.ReleaseAll")
    self:ReleaseAll()
    Profile:Stop("GuildBankSet:Build.ReleaseAll")
    self.totalSlots = 0
    self.numTabs = GetNumGuildBankTabs() or 0

    Profile:Start("GuildBankSet:Build.CreateButtons")
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
            if OneWoW_Bags.Masque then
                OneWoW_Bags.Masque:SkinItemButton(button, "guild")
            end
        end
    end
    Profile:Stop("GuildBankSet:Build.CreateButtons")

    self.isBuilt = true
    Profile:Start("GuildBankSet:Build.RebuildButtonList")
    self:RebuildButtonList()
    Profile:Stop("GuildBankSet:Build.RebuildButtonList")

    Profile:Start("GuildBankSet:Build.UpdateAllSlots")
    self:UpdateAllSlots()
    Profile:Stop("GuildBankSet:Build.UpdateAllSlots")

    Profile:Stop("GuildBankSet:Build")
    self._building = false
    OneWoW_Bags:RequestLayoutRefresh("guild", "build_done")
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
    local Profile = OneWoW_Bags.Profile
    local tApply = Profile:Mark()
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
        local tProps = Profile:Mark()
        local props = OneWoW_Bags:GetButtonProps(button)
        Profile:Add("GuildBankSet:GetButtonProps", tProps)
        button._owb_sortName = props.nameRaw ~= "" and props.nameRaw or nil
        button._owb_ilvl = props.ilvl and props.ilvl > 0 and props.ilvl or nil
        button._owb_expansionID = props.expansionID
        button._owb_classID = props.classID
        button._owb_subClassID = props.subClassID
        button._owb_itemQuality = cached.quality
        button._owb_reagentQuality = props.reagentQuality
        button._owb_craftedQuality = props.craftedQuality

        local masqueActive = OneWoW_Bags.Masque and OneWoW_Bags.Masque:IsActive()
        if button.SetItemButtonQuality then
            button:SetItemButtonQuality(cached.quality, cached.itemLink, false)
            if button.IconBorder and not masqueActive then
                button.IconBorder:Hide()
            end
            if button.ProfessionQualityOverlay then
                button.ProfessionQualityOverlay:SetDrawLayer("OVERLAY", 7)
            end
        end

        if not masqueActive then
            if OneWoW_Bags:ShouldShowItemQuality(true, cached.quality) then
                OneWoW_GUI:UpdateIconQuality(button, cached.quality)
            else
                OneWoW_GUI:UpdateIconQuality(button, nil)
            end
        end

        button.owb_hasItem = true
    else
        ClearGuildBankButton(button)
    end
    Profile:Add("GuildBankSet:ApplyCachedItemToButton", tApply)
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
    local Profile = OneWoW_Bags.Profile
    Profile:Start("GuildBankSet:UpdateAllSlots.CacheAllTabs")
    local summary = self:CacheAllTabs()
    Profile:Stop("GuildBankSet:UpdateAllSlots.CacheAllTabs")

    Profile:Start("GuildBankSet:UpdateAllSlots.ApplyCacheToButtons")
    self:ApplyCacheToButtons()
    Profile:Stop("GuildBankSet:UpdateAllSlots.ApplyCacheToButtons")
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
    for _, tabSlots in pairs(self.slots) do
        for _, button in pairs(tabSlots) do
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
    if button._gbScriptsApplied then return end
    button._gbScriptsApplied = true

    button._gbOrigOnClick = button:GetScript("OnClick")
    button._gbOrigOnEnter = button:GetScript("OnEnter")
    button._gbOrigOnLeave = button:GetScript("OnLeave")
    button._gbOrigOnDragStart = button:GetScript("OnDragStart")
    button._gbOrigOnReceiveDrag = button:GetScript("OnReceiveDrag")

    button._gbOrigUpdateTooltip = button.UpdateTooltip
    button.UpdateTooltip = function(myself)
        if not ShowTooltipForButton(myself) then
            GameTooltip:Hide()
        end
    end

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.SplitStack = function(myself, amount)
        SplitGuildBankItem(myself.owb_bagID, myself.owb_slotID, amount)
    end

    button:SetScript("OnClick", function(myself, mouseButton)
        local tabID = myself.owb_bagID
        local slotID = myself.owb_slotID
        if not tabID or not slotID then return end

        if myself.owb_itemInfo and myself.owb_itemInfo.hyperlink then
            if HandleModifiedItemClick(myself.owb_itemInfo.hyperlink) then return end
        end

        if IsModifiedClick("SPLITSTACK") and myself.owb_hasItem then
            local _, itemCount = GetGuildBankItemInfo(tabID, slotID)
            if itemCount and itemCount > 1 then
                StackSplitFrame:OpenStackSplitFrame(itemCount, myself, "BOTTOMLEFT", "TOPLEFT")
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
            if myself.owb_hasItem then
                AutoStoreGuildBankItem(tabID, slotID)
            end
        else
            if tabID ~= GetCurrentGuildBankTab() then
                SetCurrentGuildBankTab(tabID)
            end
            local hadItem = myself.owb_hasItem
            local isPlacingItem = cursorType ~= nil
            OneWoW_Bags._wasPlacingBeforeGBOp = isPlacingItem
            OneWoW_Bags._destHadItemBeforeGBOp = hadItem and isPlacingItem
            PickupGuildBankItem(tabID, slotID)
            if hadItem or isPlacingItem then
                OneWoW_Bags:TrackGuildBankTransferTab(tabID)
            end
        end
    end)

    button:SetScript("OnEnter", function(myself)
        if not ShowTooltipForButton(myself) then
            GameTooltip:Hide()
        end
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(myself)
        local tabID = myself.owb_bagID
        local slotID = myself.owb_slotID
        if not tabID or not slotID then return end
        if tabID ~= GetCurrentGuildBankTab() then
            SetCurrentGuildBankTab(tabID)
        end
        local hadItem = myself.owb_hasItem
        OneWoW_Bags._wasPlacingBeforeGBOp = false
        PickupGuildBankItem(tabID, slotID)
        if hadItem then
            OneWoW_Bags:TrackGuildBankTransferTab(tabID)
        end
    end)

    button:SetScript("OnReceiveDrag", function(myself)
        local cursorType = GetCursorInfo()
        if cursorType == "item" then
            local tabID = myself.owb_bagID
            if tabID ~= GetCurrentGuildBankTab() then
                SetCurrentGuildBankTab(tabID)
            end
            OneWoW_Bags:TrackGuildBankTransferTab(tabID)
            OneWoW_Bags._wasPlacingBeforeGBOp = true
            OneWoW_Bags._destHadItemBeforeGBOp = myself.owb_hasItem
            PickupGuildBankItem(tabID, myself.owb_slotID)
        end
    end)
end

function GBSet:RestoreButtonScripts(button)
    if not button._gbScriptsApplied then return end
    button._gbScriptsApplied = nil

    button:SetScript("OnClick", button._gbOrigOnClick)
    button:SetScript("OnEnter", button._gbOrigOnEnter)
    button:SetScript("OnLeave", button._gbOrigOnLeave)
    button:SetScript("OnDragStart", button._gbOrigOnDragStart)
    button:SetScript("OnReceiveDrag", button._gbOrigOnReceiveDrag)
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
    for _, tabSlots in pairs(self.slots) do
        for _, button in pairs(tabSlots) do
            GBSet:RestoreButtonScripts(button)
            button.owb_isGuildBank = nil
            Pool:Release(button)
        end
    end
    self.slots = {}
    self.bagContainerFrames = {}
    wipe(self.buttonList)
    wipe(self.tabRanges)
    wipe(self._allButtonsScratch)
    wipe(self._tabButtonsScratch)
    self.totalSlots = 0
    self.freeSlots = 0
    self.numTabs = 0
    self.isBuilt = false
end

function GBSet:ClearCache()
    self.cache = {}
end

function GBSet:GetAllButtons()
    return CopyRange(self.buttonList, 1, #self.buttonList, self._allButtonsScratch)
end

function GBSet:GetButtonList()
    return self.buttonList
end

function GBSet:GetButtonsByTab(tabID, dest)
    local scratch = dest or self._tabButtonsScratch
    local range = self.tabRanges[tabID]
    return CopyRange(self.buttonList, range and range[1], range and range[2], scratch)
end

function GBSet:RecountFreeSlots()
    self.freeSlots = 0
    for _, tabSlots in pairs(self.slots) do
        for _, button in pairs(tabSlots) do
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
