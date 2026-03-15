-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/bagbar/bagbar.lua
local addonName, ns = ...

local BagBarModule = {
    id          = "bagbar",
    title       = "BAGBAR_TITLE",
    category    = "INTERFACE",
    description = "BAGBAR_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    preview     = true,
    defaultEnabled = true,
}

local barFrame      = nil
local holders       = {}
local buttons       = {}
local currentItems  = {}
local updateTimer   = nil
local tempBlacklist = {}
local previewMode   = false

local function SyncKeybindings()
    if InCombatLockdown() then return end
    if not barFrame then return end
    ClearOverrideBindings(barFrame)
    for i = 1, 4 do
        local key = GetBindingKey("BAGITEM_" .. i)
        if key then
            SetOverrideBindingClick(barFrame, false, key, "OneWoW_QoL_BagBarBtn" .. i, "RightButton")
        end
    end
end

local function GetSettings()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return {} end
    local mods = addon.db.global.modules
    if not mods["bagbar"] then mods["bagbar"] = {} end
    local s = mods["bagbar"]
    if s.locked          == nil then s.locked          = false end
    if s.showUsableItems == nil then s.showUsableItems = false end
    if s.maxButtons      == nil then s.maxButtons      = 12   end
    if s.buttonSize      == nil then s.buttonSize      = 36   end
    if s.columns         == nil then s.columns         = 12   end
    if not s.manualItems  then s.manualItems  = {} end
    if not s.blacklist    then s.blacklist    = {} end
    return s
end

BagBarModule.GetSettings = GetSettings

function BagBarModule:IsBlacklisted(itemID)
    if tempBlacklist[itemID] then return true end
    local s = GetSettings()
    return s.blacklist and s.blacklist[itemID] == true
end

function BagBarModule:AddToBlacklist(itemID, permanent)
    if permanent then
        local s = GetSettings()
        s.blacklist[itemID] = true
    else
        tempBlacklist[itemID] = true
    end
end

function BagBarModule:ClearTempBlacklist()
    wipe(tempBlacklist)
end

function BagBarModule:OnEnable()
    if not barFrame then
        self:CreateBar()
    end
    self:RegisterEvents()
    self:UpdateBar()
    SyncKeybindings()
end

function BagBarModule:OnDisable()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
    end
    if barFrame then
        ClearOverrideBindings(barFrame)
    end
    for i = 1, 12 do
        if holders[i] then holders[i]:SetID(0) end
        if buttons[i] then
            buttons[i]:SetID(0)
            buttons[i].owb_itemID = nil
        end
    end
    if barFrame then
        barFrame:Hide()
        if barFrame.dragHandle then
            barFrame.dragHandle:Hide()
        end
    end
end

function BagBarModule:OnToggle(toggleId, value)
end

function BagBarModule:CreateBar()
    if barFrame then return end

    barFrame = CreateFrame("Frame", "OneWoW_QoL_BagBar", UIParent)
    barFrame:SetSize(40, 40)
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetClampedToScreen(true)
    barFrame:Hide()

    local s = GetSettings()
    if s.position then
        barFrame:SetPoint(s.position.point, UIParent, s.position.relativePoint, s.position.x, s.position.y)
    else
        barFrame:SetPoint("LEFT", UIParent, "CENTER", 0, -200)
    end

    barFrame:SetMovable(true)
    barFrame:EnableMouse(false)

    local dragHandle = CreateFrame("Frame", "OneWoW_QoL_BagBarDragHandle", barFrame, "BackdropTemplate")
    dragHandle:SetSize(20, 36)
    dragHandle:SetPoint("RIGHT", barFrame, "LEFT", -2, 0)
    dragHandle:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile   = false,
        edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    dragHandle:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
    dragHandle:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetMovable(true)

    local dragLine = dragHandle:CreateTexture(nil, "ARTWORK")
    dragLine:SetSize(3, 20)
    dragLine:SetPoint("CENTER")
    dragLine:SetColorTexture(0.6, 0.6, 0.6, 1)

    dragHandle:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.L["BAGBAR_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(ns.L["BAGBAR_DRAG_TOOLTIP"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    dragHandle:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
        GameTooltip:Hide()
    end)
    dragHandle:SetScript("OnDragStart", function(self)
        if not GetSettings().locked then
            barFrame:StartMoving()
        end
    end)
    dragHandle:SetScript("OnDragStop", function(self)
        barFrame:StopMovingOrSizing()
        BagBarModule:SavePosition()
    end)

    barFrame.dragHandle = dragHandle

    for i = 1, 12 do
        self:CreateButton(i)
    end

    self.frame = barFrame
end

function BagBarModule:CreateButton(index)
    local holderName = "OneWoW_QoL_BagBarHolder" .. index
    local btnName    = "OneWoW_QoL_BagBarBtn" .. index

    local holder = CreateFrame("Frame", holderName, barFrame)
    holder:SetSize(36, 36)
    holder:SetID(0)
    holder:Hide()

    local button = CreateFrame("ItemButton", btnName, holder, "ContainerFrameItemButtonTemplate")
    button:SetAllPoints(holder)
    button:SetID(0)
    button:Show()

    local normalTexture = button:GetNormalTexture()
    if normalTexture then
        normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        normalTexture:SetSize(64, 64)
        normalTexture:ClearAllPoints()
        normalTexture:SetPoint("CENTER", 0, -1)
    end

    if button.IconBorder         then button.IconBorder:Hide()         end
    if button.IconOverlay        then button.IconOverlay:Hide()        end
    if button.ItemContextOverlay then button.ItemContextOverlay:Hide() end
    if button.ExtendedSlot       then button.ExtendedSlot:Hide()       end
    if button.IconQuestTexture   then button.IconQuestTexture:Hide()   end

    button.owb_itemID = nil

    button:HookScript("OnEnter", function(self)
        if GameTooltip:IsShown() then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(ns.L["BAGBAR_LEFT_CLICK_TO_USE"], 1, 1, 1)
            GameTooltip:AddLine(ns.L["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"], 0.7, 0.7, 0.7)
            GameTooltip:AddLine(ns.L["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"], 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)

    button:HookScript("OnClick", function(self, mouseButton)
        if mouseButton == "LeftButton" and self.owb_itemID then
            C_Container.UseContainerItem(self:GetParent():GetID(), self:GetID())
        elseif mouseButton == "RightButton" and self.owb_itemID and (IsShiftKeyDown() or IsAltKeyDown()) then
            BagBarModule:AddToBlacklist(self.owb_itemID, IsAltKeyDown())
            BagBarModule:ScheduleUpdate()
        end
    end)

    holders[index] = holder
    buttons[index] = button
end

function BagBarModule:SavePosition()
    if not barFrame then return end
    local left   = barFrame:GetLeft()
    local top    = barFrame:GetTop()
    local bottom = barFrame:GetBottom()
    if not left or not top or not bottom then return end

    local centerY      = (top + bottom) / 2
    local screenHeight = UIParent:GetHeight()
    local anchorPoint, yOffset

    if centerY > (screenHeight * 0.66) then
        anchorPoint = "TOPLEFT"
        yOffset     = top - screenHeight
    elseif centerY < (screenHeight * 0.33) then
        anchorPoint = "BOTTOMLEFT"
        yOffset     = bottom
    else
        anchorPoint = "LEFT"
        yOffset     = centerY - (screenHeight / 2)
    end

    barFrame:ClearAllPoints()
    barFrame:SetPoint(anchorPoint, UIParent, anchorPoint, left, yOffset)

    local s = GetSettings()
    s.position = { point = anchorPoint, relativePoint = anchorPoint, x = left, y = yOffset }
end

function BagBarModule:RegisterEvents()
    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_BagBarEvents")
    end
    self._eventFrame:UnregisterAllEvents()

    local itemInfoPending = false

    self._eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    self._eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self._eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self._eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self._eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    self._eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
    self._eventFrame:RegisterEvent("TRADE_SKILL_CLOSE")
    self._eventFrame:RegisterEvent("UPDATE_BINDINGS")

    self._eventFrame:SetScript("OnEvent", function(self, event)
        if event == "UPDATE_BINDINGS" then
            SyncKeybindings()
            return
        elseif event == "TRADE_SKILL_SHOW" then
            BagBarModule._suppressedForProfessions = true
            if updateTimer then updateTimer:Cancel() end
            if barFrame then
                barFrame:Hide()
                if barFrame.dragHandle then barFrame.dragHandle:Hide() end
            end
        elseif event == "TRADE_SKILL_CLOSE" then
            BagBarModule._suppressedForProfessions = false
            BagBarModule:ScheduleUpdate()
        elseif event == "BAG_UPDATE_DELAYED" then
            BagBarModule:ScheduleUpdate()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if BagBarModule.needsUpdate then
                BagBarModule:ScheduleUpdate()
            end
            BagBarModule:UpdateCooldowns()
            SyncKeybindings()
        elseif event == "PLAYER_REGEN_DISABLED" then
            BagBarModule:UpdateCooldowns()
        elseif event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, function()
                BagBarModule:UpdateBar()
                C_Timer.After(2, function() BagBarModule:UpdateBar() end)
            end)
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            if not itemInfoPending then
                itemInfoPending = true
                C_Timer.After(0.5, function()
                    BagBarModule:ScheduleUpdate()
                    itemInfoPending = false
                end)
            end
        end
    end)
end

function BagBarModule:ScheduleUpdate()
    if updateTimer then
        updateTimer:Cancel()
    end
    updateTimer = C_Timer.NewTimer(0.2, function()
        BagBarModule:UpdateBar()
        updateTimer = nil
    end)
end

function BagBarModule:ShouldShowItem(bag, slot, itemID)
    if self:IsBlacklisted(itemID) then return false end

    local s = GetSettings()
    if s.manualItems and s.manualItems[itemID] then return true end

    local itemName, _, _, _, _, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(itemID)
    if not itemName then return false end

    if classID == Enum.ItemClass.Recipe then return true end

    if classID == Enum.ItemClass.Battlepet then
        local itemLink = C_Container.GetContainerItemLink(bag, slot)
        if itemLink then
            local linkID = tonumber(itemLink:match("|Hbattlepet:(%d+)"))
            if linkID then
                local numCollected, limit = C_PetJournal.GetNumCollectedInfo(linkID)
                if numCollected and limit and numCollected >= limit then return false end
            end
        end
        return true
    end

    if classID == Enum.ItemClass.Miscellaneous then
        if subclassID == Enum.ItemMiscellaneousSubclass.Mount then return true end
        if subclassID == Enum.ItemMiscellaneousSubclass.CompanionPet then return true end
    end

    if classID == Enum.ItemClass.Consumable then
        if subclassID == Enum.ItemConsumableSubclass.UtilityCurio
        or subclassID == Enum.ItemConsumableSubclass.CombatCurio then
            return true
        end
    end

    local tooltipData = C_TooltipInfo.GetBagItem(bag, slot)
    if tooltipData and tooltipData.lines then
        for _, line in ipairs(tooltipData.lines) do
            if line.leftText then
                local text = line.leftText

                if text == TOY then
                    return not PlayerHasToy(itemID)
                end

                if text == ITEM_COSMETIC then
                    local itemLink = C_Container.GetContainerItemLink(bag, slot)
                    if itemLink then
                        local _, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
                        if sourceID then
                            local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
                            if sourceInfo and not sourceInfo.isCollected then return true end
                        end
                    end
                    return false
                end
            end
        end
    end

    if s.showUsableItems then
        if itemName and itemName:find("Hearth") then return false end
        if classID == Enum.ItemClass.Consumable then return true end
        if classID == Enum.ItemClass.ItemEnhancement then return true end
        if classID == Enum.ItemClass.Miscellaneous then
            local spellName = C_Item.GetItemSpell(itemID)
            if spellName then return true end
        end
    end

    return false
end

function BagBarModule:GetUsableItems()
    local items = {}
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID and self:ShouldShowItem(bag, slot, itemID) then
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                local info     = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.iconFileID then
                    table.insert(items, {
                        bag        = bag,
                        slot       = slot,
                        itemID     = itemID,
                        itemLink   = itemLink,
                        stackCount = info.stackCount or 1,
                        iconFileID = info.iconFileID,
                    })
                end
            end
        end
    end
    return items
end

function BagBarModule:UpdateBar()
    if not barFrame then return end
    if InCombatLockdown() then
        self.needsUpdate = true
        return
    end
    self.needsUpdate = false

    if self._suppressedForProfessions then
        barFrame:Hide()
        if barFrame.dragHandle then barFrame.dragHandle:Hide() end
        return
    end

    if not ns.ModuleRegistry:IsEnabled("bagbar") then
        barFrame:Hide()
        if barFrame.dragHandle then barFrame.dragHandle:Hide() end
        return
    end

    local items     = self:GetUsableItems()
    currentItems    = items
    local s         = GetSettings()
    local maxBtns   = s.maxButtons or 12
    local itemCount = #items

    if itemCount == 0 and not previewMode then
        barFrame:Hide()
        if barFrame.dragHandle then barFrame.dragHandle:Hide() end
        return
    end

    local visible = math.min(itemCount, maxBtns)
    if previewMode and itemCount == 0 then
        visible = math.min(3, maxBtns)
    end

    for i = 1, 12 do
        if i <= itemCount and i <= maxBtns then
            local item = items[i]
            holders[i]:SetID(item.bag)
            buttons[i]:SetID(item.slot)
            buttons[i].owb_itemID = item.itemID
            SetItemButtonTexture(buttons[i], item.iconFileID)
            SetItemButtonCount(buttons[i], item.stackCount)
            local start, duration, enable = C_Container.GetContainerItemCooldown(item.bag, item.slot)
            if buttons[i].Cooldown then
                CooldownFrame_Set(buttons[i].Cooldown, start or 0, duration or 0, enable or 0)
            end
        else
            holders[i]:SetID(0)
            buttons[i]:SetID(0)
            buttons[i].owb_itemID = nil
            SetItemButtonTexture(buttons[i], nil)
            SetItemButtonCount(buttons[i], 0)
            if buttons[i].Cooldown then buttons[i].Cooldown:Clear() end
        end
    end

    self:LayoutButtons(visible)
    barFrame:Show()
end

function BagBarModule:LayoutButtons(count)
    local s          = GetSettings()
    local btnSize    = s.buttonSize or 36
    local padding    = 5
    local cols       = s.columns or 12
    local actualCols = math.min(count, cols)
    local rows       = math.max(1, math.ceil(count / cols))

    for i = 1, count do
        local row = math.floor((i - 1) / cols)
        local col = (i - 1) % cols
        holders[i]:ClearAllPoints()
        holders[i]:SetSize(btnSize, btnSize)
        holders[i]:SetPoint("TOPLEFT", barFrame, "TOPLEFT",
            col * (btnSize + padding),
            -(row * (btnSize + padding)))

        local normalTexture = buttons[i]:GetNormalTexture()
        if normalTexture then
            local borderSize = math.floor(btnSize * 1.7)
            normalTexture:SetSize(borderSize, borderSize)
        end

        holders[i]:Show()
    end

    for i = count + 1, 12 do
        holders[i]:Hide()
    end

    if actualCols > 0 then
        local width  = (actualCols * btnSize) + ((actualCols - 1) * padding)
        local height = (rows * btnSize) + ((rows - 1) * padding)
        barFrame:SetSize(width, height)
    else
        barFrame:SetSize(btnSize, btnSize)
    end

    if barFrame.dragHandle then
        local height = barFrame:GetHeight()
        barFrame.dragHandle:SetSize(20, math.max(height, 36))
        if previewMode or not s.locked then
            barFrame.dragHandle:Show()
        else
            barFrame.dragHandle:Hide()
        end
    end
end

function BagBarModule:UpdateCooldowns()
    for i = 1, 12 do
        if holders[i] and holders[i]:IsShown() and buttons[i]:GetID() > 0 then
            local start, duration, enable = C_Container.GetContainerItemCooldown(holders[i]:GetID(), buttons[i]:GetID())
            if buttons[i].Cooldown then
                CooldownFrame_Set(buttons[i].Cooldown, start or 0, duration or 0, enable or 0)
            end
        end
    end
end

function BagBarModule:SetLocked(locked)
    local s = GetSettings()
    s.locked = locked
    if barFrame and barFrame.dragHandle then
        if locked then
            barFrame.dragHandle:Hide()
        else
            barFrame.dragHandle:Show()
        end
    end
end

function BagBarModule:ShowPreview()
    previewMode = true
    if not barFrame then
        self:CreateBar()
        self:RegisterEvents()
    elseif not self._eventFrame then
        self:RegisterEvents()
    end
    self:UpdateBar()
end

function BagBarModule:HidePreview()
    previewMode = false
    if barFrame then
        self:UpdateBar()
    end
end

function BagBarModule:IsPreviewActive()
    return previewMode
end

ns.BagBarModule = BagBarModule
