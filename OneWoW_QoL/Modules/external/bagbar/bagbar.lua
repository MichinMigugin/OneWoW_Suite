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
            SetOverrideBindingClick(barFrame, false, key, "OneWoW_QoL_BagBarBtn" .. i)
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
    if s.maxButtons      == nil then s.maxButtons      = 12   end
    if s.buttonSize      == nil then s.buttonSize      = 36   end
    if s.columns         == nil then s.columns         = 12   end
    if not s.manualItems    then s.manualItems    = {} end
    if not s.blacklist      then s.blacklist      = {} end
    if s.showRecipes     == nil then s.showRecipes     = true end
    if s.showMounts      == nil then s.showMounts      = true end
    if s.showPets        == nil then s.showPets        = true end
    if s.showUsableItems == nil then s.showUsableItems = true end
    if s.showContainers  == nil then s.showContainers  = true end
    if s.showDecor       == nil then s.showDecor       = true end
    return s
end

BagBarModule.GetSettings = GetSettings

function BagBarModule:IsBlacklisted(itemID)
    if tempBlacklist[itemID] then return true end
    local s = GetSettings()
    return s.blacklist and s.blacklist[itemID] == true
end

local CLASSID_CONSUMABLE = 0
local CLASSID_CONTAINER  = 1
local CLASSID_RECIPE     = 9
local CLASSID_MISC       = 15
local CLASSID_BATTLEPET  = 17
local CLASSID_PROFESSION = 19

local MISC_SUB_COMPANION = 2
local MISC_SUB_MOUNT     = 5

function BagBarModule:PassesCategoryFilter(itemID)
    local s = GetSettings()
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if not classID then return true end

    if classID == CLASSID_RECIPE or classID == CLASSID_PROFESSION then
        return s.showRecipes
    end
    if classID == CLASSID_CONTAINER then
        return s.showContainers
    end
    if classID == CLASSID_CONSUMABLE then
        return s.showUsableItems
    end
    if classID == CLASSID_BATTLEPET then
        return s.showPets
    end
    if classID == CLASSID_MISC then
        if subClassID == MISC_SUB_MOUNT then return s.showMounts end
        if subClassID == MISC_SUB_COMPANION then return s.showPets end
        return s.showDecor
    end
    return true
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
        local b = buttons[i]
        if b then
            b.owb_itemID = nil
            b.owb_bag = nil
            b.owb_slot = nil
            b:SetAttribute("type1", nil)
            b:SetAttribute("item1", nil)
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

local function ClearBagBarButton(button)
    if not button then return end
    button.owb_itemID = nil
    button.owb_bag = nil
    button.owb_slot = nil
    button:SetAttribute("type1", nil)
    button:SetAttribute("item1", nil)
    if button.icon then button.icon:SetTexture(nil) end
    if button.count then button.count:SetText("") end
    if button.cooldown then
        button.cooldown:Hide()
        button.cooldown:Clear()
    end
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
    holder:Hide()

    local button = CreateFrame("Button", btnName, holder, "SecureActionButtonTemplate")
    button:SetAllPoints(holder)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", true)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(34, 34)
    button.icon:SetPoint("CENTER")
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.normalTex = button:CreateTexture(nil, "BACKGROUND")
    button.normalTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    button.normalTex:SetSize(64, 64)
    button.normalTex:SetPoint("CENTER", 0, -1)

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)

    button.cooldown = CreateFrame("Cooldown", btnName .. "CD", button, "CooldownFrameTemplate")
    button.cooldown:SetSize(34, 34)
    button.cooldown:SetPoint("CENTER")
    button.cooldown:SetDrawEdge(false)
    button.cooldown:SetHideCountdownNumbers(false)

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local ht = button:GetHighlightTexture()
    if ht then
        ht:SetAlpha(0.4)
        ht:SetSize(36, 36)
        ht:SetPoint("CENTER")
    end

    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    local pt = button:GetPushedTexture()
    if pt then
        pt:SetSize(36, 36)
        pt:SetPoint("CENTER")
    end

    button:SetScript("OnEnter", function(self)
        if not self.owb_itemID or not self.owb_bag or not self.owb_slot then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(self.owb_bag, self.owb_slot)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.L["BAGBAR_LEFT_CLICK_TO_USE"], 1, 1, 1)
        GameTooltip:AddLine(ns.L["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"], 0.7, 0.7, 0.7)
        GameTooltip:AddLine(ns.L["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("PostClick", function(self, mouseButton)
        if mouseButton == "RightButton" and self.owb_itemID and (IsShiftKeyDown() or IsAltKeyDown()) then
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

function BagBarModule:IsItemUsableForBar(bag, slot, itemID)
    if not itemID then return false end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then
        if info.isUsable == false then return false end
    end
    if C_Item.IsUsableItem then
        local u = C_Item.IsUsableItem(itemID)
        if u ~= nil then return u end
    end
    if info and info.isUsable == true then return true end
    local spellName = C_Item.GetItemSpell(itemID)
    return spellName ~= nil and spellName ~= ""
end

function BagBarModule:ShouldShowItem(bag, slot, itemID)
    if self:IsBlacklisted(itemID) then return false end
    if not self:PassesCategoryFilter(itemID) then return false end
    return self:IsItemUsableForBar(bag, slot, itemID)
end

function BagBarModule:GetUsableItems()
    local items = {}
    local s = GetSettings()
    local manual = s.manualItems or {}
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
                        manualPin  = manual[itemID] and 1 or 0,
                    })
                end
            end
        end
    end
    table.sort(items, function(a, b)
        if a.manualPin ~= b.manualPin then
            return a.manualPin > b.manualPin
        end
        return (a.bag * 1000 + a.slot) < (b.bag * 1000 + b.slot)
    end)
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
        for i = 1, 12 do
            ClearBagBarButton(buttons[i])
        end
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
            local b = buttons[i]
            b.owb_itemID = item.itemID
            b.owb_bag = item.bag
            b.owb_slot = item.slot
            b:SetAttribute("type1", "item")
            b:SetAttribute("item1", "item:" .. item.itemID)
            b.icon:SetTexture(item.iconFileID)
            b.count:SetText((item.stackCount and item.stackCount > 1) and item.stackCount or "")
            local start, duration, enable = C_Container.GetContainerItemCooldown(item.bag, item.slot)
            if b.cooldown then
                CooldownFrame_Set(b.cooldown, start or 0, duration or 0, enable or 0)
            end
        else
            ClearBagBarButton(buttons[i])
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

        local b = buttons[i]
        b:SetSize(btnSize, btnSize)
        local iconSize = btnSize - 2
        b.icon:SetSize(iconSize, iconSize)
        b.normalTex:SetSize(math.floor(btnSize * 1.7), math.floor(btnSize * 1.7))
        b.cooldown:SetSize(iconSize, iconSize)
        local ht = b:GetHighlightTexture()
        if ht then ht:SetSize(btnSize, btnSize) end
        local pt = b:GetPushedTexture()
        if pt then pt:SetSize(btnSize, btnSize) end

        holders[i]:Show()
    end

    for i = count + 1, 12 do
        holders[i]:Hide()
        ClearBagBarButton(buttons[i])
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
        local b = buttons[i]
        if holders[i] and holders[i]:IsShown() and b and b.owb_bag and b.owb_slot then
            local start, duration, enable = C_Container.GetContainerItemCooldown(b.owb_bag, b.owb_slot)
            if b.cooldown then
                CooldownFrame_Set(b.cooldown, start or 0, duration or 0, enable or 0)
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
