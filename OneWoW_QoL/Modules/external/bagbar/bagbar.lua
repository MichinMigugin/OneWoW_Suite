local _, ns = ...
local BagBarModule, L = ns.ModuleRegistry:Current()
if not BagBarModule then return end

local OneWoW_GUI = OneWoW_GUI

local SE = OneWoW.SearchExpand
local Inventory = OneWoW.Inventory

local strtrim = strtrim
local tinsert, sort = tinsert, sort

local BAGBAR_MAX_SLOTS = 24

local barFrame      = nil
local holders       = {}
local buttons       = {}
local updateTimer   = nil
local tempBlacklist = {}
local previewMode   = false

local function ModuleBagEnabled()
    return ns.ModuleRegistry:IsEnabled("bagbar")
end

local function HideChrome()
    if not barFrame then return end
    barFrame:Hide()
    local dh = barFrame.dragHandle
    if dh then dh:Hide() end
end

local function SyncKeybindings()
    if OneWoW.Restriction.IsProtectedActionBlocked() then return end
    if not ModuleBagEnabled() or not barFrame then return end
    ClearOverrideBindings(barFrame)
    for i = 1, 4 do
        local key = GetBindingKey("BAGITEM_" .. i)
        if key then
            SetOverrideBindingClick(barFrame, false, key, "OneWoW_QoL_BagBarBtn" .. i)
        end
    end
end

local function GetSettings()
    local s = ns.ModuleRegistry:GetModuleBucket("bagbar")
    if not s.manualItems then s.manualItems = {} end
    if not s.manualMacros then s.manualMacros = {} end
    if not s.blacklist then s.blacklist = {} end
    return s
end

--- User-authored PredicateEngine text plus hidden "(!#gear&!#quest)" (never stored / shown in UI)
---@param s table
---@return string fullExpr Always non-empty for PE:CheckItem
local function BuildBagBarEvalExpr(s)
    local user = strtrim(s.expressionFilter or "")
    local tail = "(!#gear&!#quest)"
    if user == "" then
        return tail
    end
    return "(" .. user .. ") & (" .. tail .. ")"
end

local function ClearBagBarButton(button)
    if not button then return end
    button.owb_itemID = nil
    button.owb_bag = nil
    button.owb_slot = nil
    button.owb_itemLink = nil
    button.owb_isMacro = nil
    button.owb_macroName = nil
    button:SetAttribute("type1", nil)
    button:SetAttribute("item1", nil)
    button:SetAttribute("macro1", nil)
    if button.icon then button.icon:SetTexture(nil) end
    if button.count then button.count:SetText("") end
    if button.cooldown then
        button.cooldown:Hide()
        button.cooldown:Clear()
    end
end

local function TeardownBar()
    previewMode = false
    if updateTimer then
        updateTimer:Cancel()
        updateTimer = nil
    end
    if barFrame then
        ClearOverrideBindings(barFrame)
        for i = 1, BAGBAR_MAX_SLOTS do
            ClearBagBarButton(buttons[i])
        end
        HideChrome()
        local dh = barFrame.dragHandle
        if dh then dh:SetAlpha(1) end
    end
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
    OneWoW_QoL:RegisterEnteringWorldHandler("bagbar", function()
        C_Timer.After(2, function()
            if not ModuleBagEnabled() or not barFrame then return end
            BagBarModule:UpdateBar()
            C_Timer.After(2, function()
                if not ModuleBagEnabled() or not barFrame then return end
                BagBarModule:UpdateBar()
            end)
        end)
    end)
    self:UpdateBar()
    SyncKeybindings()
end

function BagBarModule:OnDisable()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
    end
    OneWoW.Inventory.UnregisterCallback("QoL_bagbar")
    OneWoW.ProfessionRecipe.UnregisterCallback("QoL_bagbar")
    OneWoW_QoL:UnregisterEnteringWorldHandler("bagbar")
    TeardownBar()
end

function BagBarModule:OnToggle()
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
    dragHandle:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    dragHandle:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetMovable(true)

    local dragLine = dragHandle:CreateTexture(nil, "ARTWORK")
    dragLine:SetSize(3, 20)
    dragLine:SetPoint("CENTER")
    dragLine:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    dragHandle.dragLine = dragLine

    dragHandle:SetScript("OnEnter", function(myself)
        local st = GetSettings()
        if st.hideAnchor and not st.locked then
            myself:SetAlpha(1)
        end
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        local dir = st.growDirection or "RIGHT"
        local tooltipAnchor = (dir == "LEFT") and "ANCHOR_RIGHT" or "ANCHOR_LEFT"
        GameTooltip:SetOwner(myself, tooltipAnchor)
        GameTooltip:SetText(L["BAGBAR_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["CLICK_AND_DRAG_TO_MOVE"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    dragHandle:SetScript("OnLeave", function(myself)
        local st = GetSettings()
        if st.hideAnchor and not st.locked then
            myself:SetAlpha(0)
        end
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        GameTooltip:Hide()
    end)
    dragHandle:SetScript("OnDragStart", function()
        if not GetSettings().locked then
            barFrame:StartMoving()
        end
    end)
    dragHandle:SetScript("OnDragStop", function()
        barFrame:StopMovingOrSizing()
        BagBarModule:SavePosition()
    end)
    dragHandle:SetScript("OnMouseUp", function(myself, mouseButton)
        if mouseButton == "RightButton" then
            BagBarModule:ShowContextMenu(myself)
        end
    end)

    barFrame.dragHandle = dragHandle

    for i = 1, BAGBAR_MAX_SLOTS do
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

    OneWoW_GUI:SkinIconFrame(button, { preset = "clean" })

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)

    button.cooldown = CreateFrame("Cooldown", btnName .. "CD", button, "CooldownFrameTemplate")
    button.cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT")
    button.cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
    button.cooldown:SetDrawEdge(false)
    button.cooldown:SetHideCountdownNumbers(false)
    OneWoW_GUI:SkinCooldown(button.cooldown)

    button:SetScript("OnEnter", function(myself)
        if myself.owb_isMacro then
            if not myself.owb_macroName then return end
            if myself._skinBorder then
                myself._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            end
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(myself.owb_macroName, 1, 1, 1)
            local _, _, body = GetMacroInfo(myself.owb_macroName)
            if body and body ~= "" then
                GameTooltip:AddLine(strtrim(body), 0.7, 0.7, 0.7, true)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["BAGBAR_MACRO_LEFT_CLICK_TO_RUN"], 1, 1, 1)
            GameTooltip:Show()
            return
        end
        if not myself.owb_itemID or not myself.owb_bag or not myself.owb_slot then return end
        if myself._skinBorder and not (myself._skinQuality and myself._skinQuality > 1) then
            myself._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        end
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(myself.owb_itemLink or ("item:" .. myself.owb_itemID))
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["LEFT_CLICK_TO_USE"], 1, 1, 1)
        GameTooltip:AddLine(L["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"], 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(myself)
        if myself._skinBorder and not (myself._skinQuality and myself._skinQuality > 1) then
            myself._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        end
        GameTooltip:Hide()
    end)

    button:SetScript("PostClick", function(myself, mouseButton)
        if mouseButton == "RightButton" and myself.owb_itemID and (IsShiftKeyDown() or IsAltKeyDown()) then
            BagBarModule:AddToBlacklist(myself.owb_itemID, IsAltKeyDown())
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

    else
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

    self._eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self._eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self._eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    self._eventFrame:RegisterEvent("UPDATE_BINDINGS")
    self._eventFrame:RegisterEvent("UPDATE_MACROS")

    -- Bag changes funneled through OneWoW.Inventory (single BAG_* owner path for
    -- this consumer). Re-subscribing by ownerID is idempotent.
    OneWoW.Inventory.RegisterDelayedCallback("QoL_bagbar", function()
        BagBarModule:ScheduleUpdate()
    end)

    -- Profession-window suppression funneled through OneWoW.ProfessionRecipe.
    -- Re-subscribing by the same ownerID is idempotent, so it is safe to call
    -- here on every RegisterEvents(); OnDisable drops it.
    OneWoW.ProfessionRecipe.RegisterShowCallback("QoL_bagbar", function()
        BagBarModule._suppressedForProfessions = true
        if updateTimer then updateTimer:Cancel() end
        HideChrome()
    end)
    OneWoW.ProfessionRecipe.RegisterClosedCallback("QoL_bagbar", function()
        BagBarModule._suppressedForProfessions = false
        BagBarModule:ScheduleUpdate()
    end)

    self._eventFrame:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_BINDINGS" then
            SyncKeybindings()
            return
        elseif event == "UPDATE_MACROS" then
            BagBarModule:ScheduleUpdate()
        elseif event == "PLAYER_REGEN_ENABLED" then
            BagBarModule:UpdateCooldowns()
            SyncKeybindings()
        elseif event == "PLAYER_REGEN_DISABLED" then
            BagBarModule:UpdateCooldowns()
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            if not itemInfoPending then
                itemInfoPending = true
                C_Timer.After(0.5, function()
                    if not ModuleBagEnabled() or not barFrame then
                        itemInfoPending = false
                        return
                    end
                    BagBarModule:ScheduleUpdate()
                    itemInfoPending = false
                end)
            end
        end
    end)
end

function BagBarModule:ScheduleUpdate()
    if not ModuleBagEnabled() or not barFrame then return end
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

    local u = C_Item.IsUsableItem(itemID)
    if u ~= nil then return u end

    if info and info.isUsable == true then return true end

    local spellName = C_Item.GetItemSpell(itemID)
    return spellName ~= nil and spellName ~= ""
end

function BagBarModule:ShouldShowItem(bag, slot, itemID)
    if self:IsBlacklisted(itemID) then return false end
    local s = GetSettings()
    local expr = BuildBagBarEvalExpr(s)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not SE:CheckItem(expr, itemID, bag, slot, info) then return false end
    return self:IsItemUsableForBar(bag, slot, itemID)
end

function BagBarModule:GetUsableItems()
    local items = {}
    local s = GetSettings()
    local manual = s.manualItems or {}
    Inventory.ForEachSlot("player", function(bag, slot, info)
        local itemID = info and info.itemID
        if not itemID or not self:ShouldShowItem(bag, slot, itemID) then
            return
        end
        local itemLink = C_Container.GetContainerItemLink(bag, slot)
        if info and info.iconFileID then
            tinsert(items, {
                bag        = bag,
                slot       = slot,
                itemID     = itemID,
                itemLink   = itemLink,
                stackCount = info.stackCount or 1,
                iconFileID = info.iconFileID,
                manualPin  = manual[itemID] and 1 or 0,
            })
        end
    end)
    sort(items, function(a, b)
        if a.manualPin ~= b.manualPin then
            return a.manualPin > b.manualPin
        end
        return (a.bag * 1000 + a.slot) < (b.bag * 1000 + b.slot)
    end)
    return items
end

--- Returns the ordered list of bar entries: manual macros first (alphabetical),
--- then usable bag items. Each entry carries kind = "macro" or "item".
--- Macros whose source macro no longer exists are skipped (kept in settings so
--- they reappear if the macro is recreated).
---@return table[] entries
function BagBarModule:GetBarEntries()
    local entries = {}
    local s = GetSettings()
    local macros = s.manualMacros or {}

    local names = {}
    for name in pairs(macros) do
        tinsert(names, name)
    end
    sort(names)

    for _, name in ipairs(names) do
        local mName, mIcon = GetMacroInfo(name)
        if mName and mIcon then
            tinsert(entries, { kind = "macro", macroName = mName, iconFileID = mIcon })
        end
    end

    for _, item in ipairs(self:GetUsableItems()) do
        item.kind = "item"
        tinsert(entries, item)
    end

    return entries
end

function BagBarModule:UpdateBar()
    if not barFrame then return end
    if not ModuleBagEnabled() then
        HideChrome()
        return
    end
    if OneWoW.Restriction.IsProtectedActionBlocked() then
        OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_QoL.bagbar", function()
            BagBarModule:UpdateBar()
        end)
        return
    end

    if self._suppressedForProfessions then
        HideChrome()
        return
    end

    local entries    = self:GetBarEntries()
    local s          = GetSettings()
    local maxBtns    = math.min(s.maxButtons or 12, BAGBAR_MAX_SLOTS)
    local entryCount = #entries

    if entryCount == 0 and not previewMode then
        for i = 1, BAGBAR_MAX_SLOTS do
            ClearBagBarButton(buttons[i])
        end
        HideChrome()
        return
    end

    local visible = math.min(entryCount, maxBtns)
    if previewMode and entryCount == 0 then
        visible = math.min(3, maxBtns)
    end

    for i = 1, BAGBAR_MAX_SLOTS do
        if i <= entryCount and i <= maxBtns then
            local entry = entries[i]
            local b = buttons[i]
            if entry.kind == "macro" then
                b.owb_isMacro = true
                b.owb_macroName = entry.macroName
                b.owb_itemID = nil
                b.owb_bag = nil
                b.owb_slot = nil
                b.owb_itemLink = nil
                b:SetAttribute("type1", "macro")
                b:SetAttribute("item1", nil)
                b:SetAttribute("macro1", entry.macroName)
                b.icon:SetTexture(entry.iconFileID)
                b.count:SetText("")
                if b.cooldown then
                    CooldownFrame_Set(b.cooldown, 0, 0, 0)
                end
            else
                b.owb_isMacro = nil
                b.owb_macroName = nil
                b.owb_itemID = entry.itemID
                b.owb_bag = entry.bag
                b.owb_slot = entry.slot
                b.owb_itemLink = entry.itemLink
                b:SetAttribute("type1", "item")
                b:SetAttribute("macro1", nil)
                b:SetAttribute("item1", "item:" .. entry.itemID)
                b.icon:SetTexture(entry.iconFileID)
                b.count:SetText((entry.stackCount and entry.stackCount > 1) and entry.stackCount or "")
                local start, duration, enable = C_Container.GetContainerItemCooldown(entry.bag, entry.slot)
                if b.cooldown then
                    CooldownFrame_Set(b.cooldown, start or 0, duration or 0, enable or 0)
                end
            end
        else
            ClearBagBarButton(buttons[i])
        end
    end

    self:LayoutButtons(visible)
    barFrame:Show()
end

function BagBarModule:LayoutButtons(count)
    if not barFrame then return end
    local s       = GetSettings()
    local btnSize = s.buttonSize or 36
    local spacing = s.iconSpacing or 4
    local dir     = s.growDirection or "RIGHT"
    -- Down/Up are single-column: buttons stack vertically
    local cols    = (dir == "DOWN" or dir == "UP") and 1 or math.min(s.columns or 12, BAGBAR_MAX_SLOTS)
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

        OneWoW_GUI:SkinIconFrame(b, { preset = "clean" })

        holders[i]:Show()
    end

    for i = count + 1, BAGBAR_MAX_SLOTS do
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

    local dh = barFrame.dragHandle
    if dh then
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
        else
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
    if not ModuleBagEnabled() or not barFrame then return end
    for i = 1, BAGBAR_MAX_SLOTS do
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
    if not barFrame then return end
    local dh = barFrame.dragHandle
    if not dh then return end
    if locked then
        dh:Hide()
        dh:SetAlpha(1)
    elseif s.hideAnchor then
        dh:Show()
        dh:SetAlpha(0)
    else
        dh:Show()
        dh:SetAlpha(1)
    end
end

function BagBarModule:ShowPreview()
    if not ModuleBagEnabled() then return end
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
    if not ModuleBagEnabled() then return end
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, rootDescription)
            local s = GetSettings()
            rootDescription:CreateTitle(L["BAGBAR_TITLE"])
            local lockLabel = s.locked and L["UNLOCK_POSITION"] or L["BAGBAR_CONTEXT_LOCK"]
            rootDescription:CreateButton(lockLabel, function()
                BagBarModule:SetLocked(not s.locked)
            end)
            rootDescription:CreateButton(L["OPEN_SETTINGS"], function()
                BagBarModule:OpenSettings()
            end)
        end)
    end
end

-- ============================================================================
-- Slash command: /1wbb
-- ============================================================================
-- Toggles the BagBar module's enabled state. Registered at file-load time
-- (outside OnEnable/OnDisable) so the command can always re-show a hidden bar.
-- ============================================================================

local function ToggleBagBarModule()
    if not ns.db then
        print("|cFFFFD100OneWoW QoL:|r BagBar isn't ready yet.")
        return
    end

    local nowEnabled = not ns.ModuleRegistry:IsEnabled("bagbar")
    ns.ModuleRegistry:SetEnabled("bagbar", nowEnabled)

    if nowEnabled then
        print("|cFFFFD100OneWoW QoL:|r BagBar |cFF00FF00shown|r.")
    else
        print("|cFFFFD100OneWoW QoL:|r BagBar |cFFFF6666hidden|r.")
    end
end

_G["SLASH_OWBAGBAR1"] = "/1wbb"
SlashCmdList["OWBAGBAR"] = ToggleBagBarModule
