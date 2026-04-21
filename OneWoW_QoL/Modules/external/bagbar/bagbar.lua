local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
local PE = OneWoW_GUI and OneWoW_GUI.PredicateEngine

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
    if s.iconSpacing     == nil then s.iconSpacing     = 4    end
    if not s.manualItems    then s.manualItems    = {} end
    if not s.blacklist      then s.blacklist      = {} end
    if s.showRecipes     == nil then s.showRecipes     = true end
    if s.showMounts      == nil then s.showMounts      = true end
    if s.showPets        == nil then s.showPets        = true end
    if s.showUsableItems == nil then s.showUsableItems = true end
    if s.showContainers  == nil then s.showContainers  = true end
    if s.showDecor       == nil then s.showDecor       = true end
    if s.hideAnchor      == nil then s.hideAnchor      = false   end
    if s.growDirection   == nil then s.growDirection   = "RIGHT" end
    if s.advancedFilter  == nil then s.advancedFilter  = ""      end
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

local function PassesAdvancedFilter(itemID, bag, slot)
    local s = GetSettings()
    local expr = s.advancedFilter
    if not expr or expr == "" or not PE then return true end
    local ok, matched = pcall(PE.CheckItem, PE, expr, itemID, bag, slot)
    if not ok then return true end
    return matched == true
end

function BagBarModule:PassesCategoryFilter(itemID, bag, slot)
    local s = GetSettings()
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    local categoryPass
    if not classID then
        categoryPass = true
    elseif classID == CLASSID_RECIPE or classID == CLASSID_PROFESSION then
        categoryPass = s.showRecipes
    elseif classID == CLASSID_CONTAINER then
        categoryPass = s.showContainers
    elseif classID == CLASSID_CONSUMABLE then
        categoryPass = s.showUsableItems
    elseif classID == CLASSID_BATTLEPET then
        categoryPass = s.showPets
    elseif classID == CLASSID_MISC then
        if subClassID == MISC_SUB_MOUNT then
            categoryPass = s.showMounts
        elseif subClassID == MISC_SUB_COMPANION then
            categoryPass = s.showPets
        else
            categoryPass = s.showDecor
        end
    else
        categoryPass = true
    end

    if not categoryPass then return false end
    return PassesAdvancedFilter(itemID, bag, slot)
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
            b.owb_itemLink = nil
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
    button.owb_itemLink = nil
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
    if OneWoW_GUI then
        dragHandle:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        dragHandle:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    else
        dragHandle:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
        dragHandle:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetMovable(true)

    local dragLine = dragHandle:CreateTexture(nil, "ARTWORK")
    dragLine:SetSize(3, 20)
    dragLine:SetPoint("CENTER")
    if OneWoW_GUI then
        dragLine:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    else
        dragLine:SetColorTexture(0.6, 0.6, 0.6, 1)
    end
    dragHandle.dragLine = dragLine

    dragHandle:SetScript("OnEnter", function(self)
        local st = GetSettings()
        if st.hideAnchor and not st.locked then
            self:SetAlpha(1)
        end
        if OneWoW_GUI then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        else
            self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        end
        local dir = st.growDirection or "RIGHT"
        local tooltipAnchor = (dir == "LEFT") and "ANCHOR_RIGHT" or "ANCHOR_LEFT"
        GameTooltip:SetOwner(self, tooltipAnchor)
        GameTooltip:SetText(ns.L["BAGBAR_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(ns.L["BAGBAR_DRAG_TOOLTIP"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    dragHandle:SetScript("OnLeave", function(self)
        local st = GetSettings()
        if st.hideAnchor and not st.locked then
            self:SetAlpha(0)
        end
        if OneWoW_GUI then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        else
            self:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
        end
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
    dragHandle:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "RightButton" then
            BagBarModule:ShowContextMenu(self)
        end
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

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    button.icon = icon
    button._skinnedIcon = icon

    if OneWoW_GUI then
        OneWoW_GUI:SkinIconFrame(button, { preset = "clean" })
    end

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)

    button.cooldown = CreateFrame("Cooldown", btnName .. "CD", button, "CooldownFrameTemplate")
    button.cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT")
    button.cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
    button.cooldown:SetDrawEdge(false)
    button.cooldown:SetHideCountdownNumbers(false)
    if OneWoW_GUI then
        OneWoW_GUI:SkinCooldown(button.cooldown)
    end

    button:SetScript("OnEnter", function(self)
        if not self.owb_itemID or not self.owb_bag or not self.owb_slot then return end
        if self._skinBorder and not (self._skinQuality and self._skinQuality > 1) then
            self._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.owb_itemLink or ("item:" .. self.owb_itemID))
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.L["BAGBAR_LEFT_CLICK_TO_USE"], 1, 1, 1)
        GameTooltip:AddLine(ns.L["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"], 0.7, 0.7, 0.7)
        GameTooltip:AddLine(ns.L["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        if self._skinBorder and not (self._skinQuality and self._skinQuality > 1) then
            self._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        end
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
    local right  = barFrame:GetRight()
    local top    = barFrame:GetTop()
    local bottom = barFrame:GetBottom()
    if not left or not top or not bottom then return end

    local s            = GetSettings()
    local dir          = s.growDirection or "RIGHT"
    local screenWidth  = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    local anchorPoint, xOffset, yOffset

    if dir == "LEFT" then
        local centerY = (top + bottom) / 2
        if centerY > (screenHeight * 0.66) then
            anchorPoint = "TOPRIGHT"
            yOffset     = top - screenHeight
        elseif centerY < (screenHeight * 0.33) then
            anchorPoint = "BOTTOMRIGHT"
            yOffset     = bottom
        else
            anchorPoint = "RIGHT"
            yOffset     = centerY - (screenHeight / 2)
        end
        xOffset = right - screenWidth

    elseif dir == "DOWN" or dir == "UP" then
        local centerX = (left + right) / 2
        local isDown  = (dir == "DOWN")
        if centerX < (screenWidth * 0.33) then
            anchorPoint = isDown and "TOPLEFT" or "BOTTOMLEFT"
            xOffset     = left
        elseif centerX > (screenWidth * 0.66) then
            anchorPoint = isDown and "TOPRIGHT" or "BOTTOMRIGHT"
            xOffset     = right - screenWidth
        else
            anchorPoint = isDown and "TOP" or "BOTTOM"
            xOffset     = centerX - (screenWidth / 2)
        end
        yOffset = isDown and (top - screenHeight) or bottom

    else -- RIGHT (default)
        local centerY = (top + bottom) / 2
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
        xOffset = left
    end

    barFrame:ClearAllPoints()
    barFrame:SetPoint(anchorPoint, UIParent, anchorPoint, xOffset, yOffset)
    s.position = { point = anchorPoint, relativePoint = anchorPoint, x = xOffset, y = yOffset }
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
    if not self:PassesCategoryFilter(itemID, bag, slot) then return false end
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
            b.owb_itemLink = item.itemLink
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
    local s       = GetSettings()
    local btnSize = s.buttonSize or 36
    local spacing = s.iconSpacing or 4
    local dir     = s.growDirection or "RIGHT"
    -- Down/Up are single-column: buttons stack vertically
    local cols    = (dir == "DOWN" or dir == "UP") and 1 or (s.columns or 12)
    local actualCols = math.min(count, cols)
    local rows       = math.max(1, math.ceil(count / cols))

    for i = 1, count do
        local row = math.floor((i - 1) / cols)
        local col = (i - 1) % cols
        holders[i]:ClearAllPoints()
        holders[i]:SetSize(btnSize, btnSize)

        if dir == "LEFT" then
            holders[i]:SetPoint("TOPRIGHT", barFrame, "TOPRIGHT",
                -(col * (btnSize + spacing)),
                -(row * (btnSize + spacing)))
        elseif dir == "UP" then
            holders[i]:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT",
                col * (btnSize + spacing),
                row * (btnSize + spacing))
        else -- RIGHT or DOWN: same internal layout, handle position differs
            holders[i]:SetPoint("TOPLEFT", barFrame, "TOPLEFT",
                col * (btnSize + spacing),
                -(row * (btnSize + spacing)))
        end

        local b = buttons[i]
        b:SetSize(btnSize, btnSize)

        if OneWoW_GUI then
            OneWoW_GUI:SkinIconFrame(b, { preset = "clean" })
        end

        holders[i]:Show()
    end

    for i = count + 1, 12 do
        holders[i]:Hide()
        ClearBagBarButton(buttons[i])
    end

    if actualCols > 0 then
        local width  = (actualCols * btnSize) + ((actualCols - 1) * spacing)
        local height = (rows * btnSize) + ((rows - 1) * spacing)
        barFrame:SetSize(width, height)
    else
        barFrame:SetSize(btnSize, btnSize)
    end

    if barFrame.dragHandle then
        local dh = barFrame.dragHandle
        local bw = barFrame:GetWidth()
        local bh = barFrame:GetHeight()
        dh:ClearAllPoints()

        if dir == "LEFT" then
            dh:SetSize(20, math.max(bh, 36))
            dh:SetPoint("LEFT", barFrame, "RIGHT", 2, 0)
            if dh.dragLine then dh.dragLine:SetSize(3, 20) end
        elseif dir == "DOWN" then
            dh:SetSize(math.max(bw, 36), 20)
            dh:SetPoint("BOTTOM", barFrame, "TOP", 0, 2)
            if dh.dragLine then dh.dragLine:SetSize(20, 3) end
        elseif dir == "UP" then
            dh:SetSize(math.max(bw, 36), 20)
            dh:SetPoint("TOP", barFrame, "BOTTOM", 0, -2)
            if dh.dragLine then dh.dragLine:SetSize(20, 3) end
        else -- RIGHT
            dh:SetSize(20, math.max(bh, 36))
            dh:SetPoint("RIGHT", barFrame, "LEFT", -2, 0)
            if dh.dragLine then dh.dragLine:SetSize(3, 20) end
        end

        local shouldShow = previewMode or not s.locked
        if shouldShow then
            dh:Show()
            dh:SetAlpha(s.hideAnchor and 0 or 1)
        else
            dh:Hide()
            dh:SetAlpha(1)
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
            barFrame.dragHandle:SetAlpha(1)
        elseif s.hideAnchor then
            barFrame.dragHandle:Show()
            barFrame.dragHandle:SetAlpha(0)
        else
            barFrame.dragHandle:Show()
            barFrame.dragHandle:SetAlpha(1)
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

function BagBarModule:OpenSettings()
    if ns.UI and ns.UI.SelectFeature then
        ns.UI.SelectFeature("bagbar")
    end
end

function BagBarModule:ShowContextMenu(anchor)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, rootDescription)
            local s = GetSettings()
            rootDescription:CreateTitle(ns.L["BAGBAR_TITLE"])
            local lockLabel = s.locked and ns.L["BAGBAR_CONTEXT_UNLOCK"] or ns.L["BAGBAR_CONTEXT_LOCK"]
            rootDescription:CreateButton(lockLabel, function()
                BagBarModule:SetLocked(not s.locked)
            end)
            rootDescription:CreateButton(ns.L["BAGBAR_CONTEXT_SETTINGS"], function()
                BagBarModule:OpenSettings()
            end)
        end)
    end
end

ns.BagBarModule = BagBarModule
