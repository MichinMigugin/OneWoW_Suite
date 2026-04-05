local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local ItemPool = OneWoW_Bags.ItemPool

local tonumber, pairs = tonumber, pairs

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
        local name, icon, isViewable = GetGuildBankTabInfo(tabID)
        self.slots[tabID] = {}

        if isViewable then
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
    end

    self.isBuilt = true

    local currentTab = GetCurrentGuildBankTab() or 1
    self:CacheTab(currentTab)
    self:ApplyCacheToButtons()
end

function GBSet:CacheTab(tabID)
    if not self.cache[tabID] then
        self.cache[tabID] = {}
    end

    for slotID = 1, SLOTS_PER_TAB do
        local texture, itemCount, locked, _, quality = GetGuildBankItemInfo(tabID, slotID)
        local itemLink = GetGuildBankItemLink(tabID, slotID)

        if texture then
            local itemID = itemLink and tonumber(itemLink:match("item:(%d+)"))
            self.cache[tabID][slotID] = {
                texture = texture,
                itemCount = itemCount,
                locked = locked,
                quality = quality,
                itemLink = itemLink,
                itemID = itemID,
            }
        else
            self.cache[tabID][slotID] = nil
        end
    end
end

function GBSet:ApplyCacheToButtons()
    local db = OneWoW_Bags:GetDB()
    self.freeSlots = 0

    for tabID, tabSlots in pairs(self.slots) do
        for slotID, button in pairs(tabSlots) do
            OneWoW_Bags.ItemPool:ClearNewItemGlow(button)

            local cached = self.cache[tabID] and self.cache[tabID][slotID]

            if cached and cached.itemLink then
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

                if OneWoW_Bags:ShouldShowItemQuality(true, cached.quality) then
                    OneWoW_GUI:UpdateIconQuality(button, cached.quality)
                else
                    OneWoW_GUI:UpdateIconQuality(button, nil)
                end

                button.owb_hasItem = true
            else
                SetItemButtonTexture(button, nil)
                SetItemButtonCount(button, 0)
                OneWoW_GUI:UpdateIconQuality(button, nil)
                button.owb_itemInfo = nil
                button.owb_hasItem = false
                if button.IconOverlay then button.IconOverlay:Hide() end
                if button.ItemContextOverlay then button.ItemContextOverlay:Hide() end
                if button.ExtendedSlot then button.ExtendedSlot:Hide() end
                if button.IconQuestTexture then button.IconQuestTexture:Hide() end
                self.freeSlots = self.freeSlots + 1
            end
        end
    end
end

function GBSet:UpdateTab(tabID)
    if not self.isBuilt then return end
    self:CacheTab(tabID)
    self:ApplyCacheToButtons()
end

function GBSet:UpdateAllSlots()
    local currentTab = GetCurrentGuildBankTab() or 1
    self:CacheTab(currentTab)
    self:ApplyCacheToButtons()
end

function GBSet:RefreshAllVisuals()
    self:UpdateAllSlots()
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

function GBSet:ApplyGuildBankScripts(button)
    button._gbOrigOnClick = button:GetScript("OnClick")
    button._gbOrigOnEnter = button:GetScript("OnEnter")
    button._gbOrigOnLeave = button:GetScript("OnLeave")
    button._gbOrigOnDragStart = button:GetScript("OnDragStart")
    button._gbOrigOnReceiveDrag = button:GetScript("OnReceiveDrag")

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
            PickupGuildBankItem(tabID, slotID)
            if hadItem and GetCursorInfo() then
                SetItemButtonTexture(self, nil)
                SetItemButtonCount(self, 0)
                self.owb_hasItem = false
                self.owb_itemInfo = nil
            end
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local tabID = self.owb_bagID
        local slotID = self.owb_slotID
        if tabID and slotID and self.owb_hasItem then
            if tabID == GetCurrentGuildBankTab() then
                GameTooltip:SetGuildBankItem(tabID, slotID)
            elseif self.owb_itemInfo and self.owb_itemInfo.hyperlink then
                GameTooltip:SetHyperlink(self.owb_itemInfo.hyperlink)
            end
            GameTooltip:Show()
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
        PickupGuildBankItem(tabID, slotID)
        if hadItem and GetCursorInfo() then
            SetItemButtonTexture(self, nil)
            SetItemButtonCount(self, 0)
            self.owb_hasItem = false
            self.owb_itemInfo = nil
        end
    end)

    button:SetScript("OnReceiveDrag", function(self)
        local cursorType = GetCursorInfo()
        if cursorType == "item" then
            local tabID = self.owb_bagID
            if tabID ~= GetCurrentGuildBankTab() then
                SetCurrentGuildBankTab(tabID)
            end
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
