-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/ZonePins.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local ZonePins = {}
ns.ZonePins = ZonePins

function ZonePins:Initialize()
    local addon = _G.OneWoW_Notes
    if not addon.zonePins then addon.zonePins = {} end
    if not addon.db.global.zonePinPositions then addon.db.global.zonePinPositions = {} end

    if ns.Zones then
        C_Timer.After(0.5, function()
            local zoneText    = GetZoneText()    or ""
            local subZoneText = GetSubZoneText() or ""
            local fullZone    = zoneText
            if subZoneText ~= "" and subZoneText ~= zoneText then
                fullZone = zoneText .. " - " .. subZoneText
            end
            local allZones = ns.Zones:GetAllZones()
            if allZones then
                for zoneName, zoneData in pairs(allZones) do
                    if zoneData and type(zoneData) == "table" and zoneData.pinEnabled then
                        if zoneName == fullZone or zoneName == zoneText or zoneName == subZoneText then
                            local dismissed = zoneData.dismissedUntil and GetTime() < zoneData.dismissedUntil
                            if not dismissed then
                                self:ShowZonePin(zoneName, zoneData)
                            end
                        end
                    end
                end
            end
        end)
    end
end

function ZonePins:ShowZonePin(zoneName, zoneData)
    local addon = _G.OneWoW_Notes
    if not zoneName or not zoneData then return end
    if not addon.zonePins then addon.zonePins = {} end

    if addon.zonePins[zoneName] then
        local pin = addon.zonePins[zoneName]
        if pin.contentText then
            pin.contentText:SetText(zoneData.content or "")
        end
        pin:Show()
        if pin.RefreshTodos then pin:RefreshTodos() end
        if pin.RefreshLayout then pin:RefreshLayout() end
        if addon.BringWindowToFront then
            addon:BringWindowToFront(pin)
        end
        return pin
    end

    return self:CreateZonePin(zoneName, zoneData)
end

function ZonePins:HideZonePin(zoneName)
    local addon = _G.OneWoW_Notes
    if not addon.zonePins or not addon.zonePins[zoneName] then return end

    local pinFrame = addon.zonePins[zoneName]
    if pinFrame then
        pinFrame:Hide()
    end
end

function ZonePins:DestroyZonePin(zoneName)
    local addon = _G.OneWoW_Notes
    if not addon.zonePins or not addon.zonePins[zoneName] then return end

    local pinFrame = addon.zonePins[zoneName]
    addon.zonePins[zoneName] = nil
    if pinFrame then
        pinFrame._destroying = true
        pinFrame:Hide()
        pinFrame:SetParent(nil)
    end
end

function ZonePins:HideAllPins()
    local addon = _G.OneWoW_Notes
    if not addon.zonePins then return end
    for zoneName, pinFrame in pairs(addon.zonePins) do
        if pinFrame then
            pinFrame._destroying = true
            pinFrame:Hide()
        end
    end
    addon.zonePins = {}
end

function ZonePins:SavePinPosition(zoneName, point, relativePoint, x, y, width, height)
    local addon = _G.OneWoW_Notes
    if not addon.db.global.zonePinPositions then
        addon.db.global.zonePinPositions = {}
    end
    addon.db.global.zonePinPositions[zoneName] = {
        point = point, relativePoint = relativePoint,
        x = x, y = y, width = width, height = height
    }
end

function ZonePins:GetPinPosition(zoneName)
    local addon = _G.OneWoW_Notes
    if not addon.db.global.zonePinPositions then return nil end
    return addon.db.global.zonePinPositions[zoneName]
end

function ZonePins:CreateZonePin(zoneName, zoneData)
    local addon = _G.OneWoW_Notes
    if not zoneName or not zoneData then return end

    local pinColor    = zoneData.pinColor  or "hunter"
    local colorConfig = ns.Config:GetResolvedColorConfig(pinColor)
    local bgColor     = colorConfig.background
    local borderColor = colorConfig.border

    -- Sanitize zone name for frame global name
    local safeName = zoneName:gsub("[^%w]", "_")

    local pin = CreateFrame("Frame", "OneWoW_ZonePin_" .. safeName, UIParent, "BackdropTemplate")
    pin:SetSize(300, 400)
    pin:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -50)
    pin:SetMovable(true)
    pin:SetResizable(true)
    local sw = GetScreenWidth()
    local sh = GetScreenHeight()
    pin:SetResizeBounds(200, 150, sw, sh)
    pin:EnableMouse(true)
    pin:SetClampedToScreen(true)
    pin:RegisterForDrag("LeftButton")
    pin:SetScript("OnDragStart", pin.StartMoving)
    pin:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        ZonePins:SavePinPosition(zoneName, point, relativePoint, x, y, self:GetWidth(), self:GetHeight())
    end)

    pin:SetScript("OnMouseDown", function(self)
        if self.windowInfo and addon.BringWindowToFront then
            addon:BringWindowToFront(self)
        end
    end)

    local pinAlpha = zoneData.opacity or 0.9

    if pinAlpha >= 1.0 then
        pin:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        pin:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], 1.0)
    else
        pin:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        pin:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], pinAlpha)
    end
    pin:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
    pin:SetAlpha(1.0)
    pin.zoneName = zoneName

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, pin, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT",  pin, "TOPLEFT",  4, -4)
    titleBar:SetPoint("TOPRIGHT", pin, "TOPRIGHT", -4, -4)
    titleBar:SetHeight(20)
    titleBar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                           insets = { left = 0, right = 0, top = 0, bottom = 0 } })
    local titleBarColor = colorConfig.titleBar
    titleBar:SetBackdropColor(titleBarColor[1], titleBarColor[2], titleBarColor[3], 0.8)

    -- Determine title text color from fontColor
    local noteFontColor = zoneData.fontColor or "match"
    local titleColor
    if noteFontColor == "match" then
        titleColor = borderColor
    elseif noteFontColor == "white" then
        titleColor = {1, 1, 1}
    elseif noteFontColor == "black" then
        titleColor = {0, 0, 0}
    else
        local fontConfig = ns.Config.PIN_COLORS[noteFontColor]
        titleColor = fontConfig and fontConfig.border or borderColor
    end

    local titleText = OneWoW_GUI:CreateFS(titleBar, 10)
    titleText:SetPoint("LEFT",  titleBar, "LEFT",  5, 0)
    titleText:SetPoint("RIGHT", titleBar, "RIGHT", -25, 0)
    titleText:SetText(zoneName)
    titleText:SetJustifyH("LEFT")
    titleText:SetTextColor(titleColor[1], titleColor[2], titleColor[3], 1)
    pin.titleText = titleText
    pin.titleBar  = titleBar

    -- Close button — sets dismissedUntil 30 min so it won't re-open on re-enter
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function()
        -- Dismiss for 30 minutes so zone re-entry doesn't immediately re-open it
        if ns.Zones then
            local zd = ns.Zones:GetZone(zoneName)
            if zd then
                zd.dismissedUntil = GetTime() + (30 * 60)
                ns.Zones:SaveZone(zoneName, zd)
            end
        end
        ZonePins:HideZonePin(zoneName)
    end)
    pin.closeBtn = closeBtn

    -- Content area (scrollable)
    local contentFrame = CreateFrame("Frame", nil, pin)
    contentFrame:SetPoint("TOPLEFT",  titleBar, "BOTTOMLEFT",  5, -5)
    contentFrame:SetPoint("TOPRIGHT", pin,      "TOPRIGHT",    -5, -5)
    contentFrame:SetHeight(120)

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame)
    scrollFrame:SetPoint("TOPLEFT",     0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    scrollFrame:SetClipsChildren(true)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(delta > 0 and math.max(0, cur - 30) or math.min(max, cur + 30))
    end)

    local contentText = CreateFrame("EditBox", nil, scrollFrame)
    contentText:SetMultiLine(true)
    contentText:SetAutoFocus(false)
    contentText:EnableMouse(false)
    contentText:EnableKeyboard(false)
    contentText:SetHyperlinksEnabled(true)
    contentText:SetWidth(scrollFrame:GetWidth() or 280)
    contentText:SetHeight(1)
    scrollFrame:SetScrollChild(contentText)

    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        contentText:SetWidth(math.max(1, width))
    end)

    contentText:SetScript("OnHyperlinkClick", function(self, linkData, link, button)
        if button == "LeftButton" then
            SetItemRef(linkData, link, button)
        end
    end)

    local fontSize = zoneData.fontSize or 12
    local fontPath = ns.Config:ResolveFontPath(zoneData.fontFamily)
    contentText:SetFont(fontPath, fontSize, zoneData.fontOutline or "")

    local contentTextColor
    if noteFontColor == "match" then
        contentTextColor = borderColor
    elseif noteFontColor == "white" then
        contentTextColor = {1, 1, 1}
    elseif noteFontColor == "black" then
        contentTextColor = {0, 0, 0}
    else
        local fontConfig = ns.Config.PIN_COLORS[noteFontColor]
        contentTextColor = fontConfig and fontConfig.border or borderColor
    end
    contentText:SetTextColor(contentTextColor[1], contentTextColor[2], contentTextColor[3], 1)
    contentText:SetText(zoneData.content or "")

    pin.contentText  = contentText
    pin.contentFrame = contentFrame
    pin.scrollFrame  = scrollFrame

    -- Todo section
    local todoMainFrame = CreateFrame("Frame", nil, pin)
    todoMainFrame:SetPoint("TOPLEFT",     titleBar, "BOTTOMLEFT",  5, -5)
    todoMainFrame:SetPoint("BOTTOMRIGHT", pin,      "BOTTOMRIGHT", -5, 15)
    pin.todoMainFrame = todoMainFrame

    local todoContainer = CreateFrame("Frame", nil, todoMainFrame)
    todoContainer:SetPoint("TOPLEFT",  todoMainFrame, "TOPLEFT",  0, 0)
    todoContainer:SetPoint("TOPRIGHT", todoMainFrame, "TOPRIGHT", 0, 0)
    pin.todoContainer = todoContainer
    pin.todoItems = {}

    pin.RefreshLayout = function(self, skipTodoRefresh)
        if not self.contentFrame or not self.todoMainFrame then return end

        local zd = ns.Zones and ns.Zones:GetZone(zoneName)
        if not zd then return end

        local todoCount = #(zd.todos or {})
        local taskHeight = 0
        if todoCount > 0 then
            taskHeight = self.todoContainer:GetHeight() or 40
            if taskHeight <= 10 then
                taskHeight = math.max(40, todoCount * 25 + 20)
            end
        end

        local hasContent  = zd.content and zd.content ~= ""
        local minWindow   = 30 + (hasContent and 60 or 10) + taskHeight + 35
        self:SetResizeBounds(200, minWindow, GetScreenWidth(), GetScreenHeight())

        self.contentFrame:ClearAllPoints()
        self.todoMainFrame:ClearAllPoints()
        self.todoContainer:ClearAllPoints()

        local tasksOnTop = zd.tasksOnTop == true

        if todoCount == 0 then
            self.todoMainFrame:Hide()
            if hasContent then
                self.contentFrame:SetPoint("TOPLEFT", self.titleBar, "BOTTOMLEFT", 5, -5)
                self.contentFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -5, 15)
                self.contentFrame:Show()
            else
                self.contentFrame:Hide()
            end
        elseif hasContent then
            self.todoMainFrame:Show()
            if tasksOnTop then
                self.todoMainFrame:SetPoint("TOPLEFT",  self.titleBar, "BOTTOMLEFT",  5, -5)
                self.todoMainFrame:SetPoint("TOPRIGHT", self,          "TOPRIGHT",    -5, -5)
                self.todoMainFrame:SetHeight(taskHeight)
                self.todoContainer:SetPoint("TOPLEFT",  self.todoMainFrame, "TOPLEFT",  0, 0)
                self.todoContainer:SetPoint("TOPRIGHT", self.todoMainFrame, "TOPRIGHT", 0, 0)
                self.contentFrame:SetPoint("TOPLEFT",     self.todoMainFrame, "BOTTOMLEFT", 0, -5)
                self.contentFrame:SetPoint("BOTTOMRIGHT", self,               "BOTTOMRIGHT", -5, 15)
            else
                self.todoMainFrame:SetPoint("BOTTOMLEFT",  self, "BOTTOMLEFT",  5, 15)
                self.todoMainFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -5, 15)
                self.todoMainFrame:SetHeight(taskHeight)
                self.todoContainer:SetPoint("TOPLEFT",  self.todoMainFrame, "TOPLEFT",  0, 0)
                self.todoContainer:SetPoint("TOPRIGHT", self.todoMainFrame, "TOPRIGHT", 0, 0)
                self.contentFrame:SetPoint("TOPLEFT",  self.titleBar, "BOTTOMLEFT",  5, -5)
                self.contentFrame:SetPoint("TOPRIGHT", self,          "TOPRIGHT",    -5, -5)
                self.contentFrame:SetPoint("BOTTOMRIGHT", self.todoMainFrame, "TOPRIGHT", 0, -5)
            end
            self.contentFrame:Show()
        else
            self.todoMainFrame:Show()
            self.todoMainFrame:SetPoint("TOPLEFT",     self.titleBar, "BOTTOMLEFT",  5, -5)
            self.todoMainFrame:SetPoint("BOTTOMRIGHT", self,          "BOTTOMRIGHT", -5, 15)
            self.todoMainFrame:SetHeight(taskHeight)
            self.todoContainer:SetPoint("TOPLEFT",  self.todoMainFrame, "TOPLEFT",  0, 0)
            self.todoContainer:SetPoint("TOPRIGHT", self.todoMainFrame, "TOPRIGHT", 0, 0)
            self.contentFrame:Hide()
        end

        if self.todoContainer then
            self.todoContainer:SetWidth(self.todoMainFrame:GetWidth())
        end

        if not skipTodoRefresh and self.RefreshTodos then
            self:RefreshTodos()
        end
    end

    pin.RefreshTodos = function(self)
        if not self.todoContainer then return end

        for i = #self.todoItems, 1, -1 do
            local item = table.remove(self.todoItems, i)
            if item then
                item:Hide()
                item._checkbox:SetScript("OnClick", nil)
                item._checkbox:SetChecked(false)
                table.insert(ns.NotesPins._zoneTodoPool or {}, item)
            end
        end

        local zd = ns.Zones and ns.Zones:GetZone(zoneName)
        if not zd or not zd.todos or #zd.todos == 0 then
            self.todoContainer:SetHeight(0)
            self:RefreshLayout(true)
            return
        end

        if not ns.NotesPins._zoneTodoPool then ns.NotesPins._zoneTodoPool = {} end

        local yOffset = 0
        for _, todo in ipairs(zd.todos) do
            local todoFrame = table.remove(ns.NotesPins._zoneTodoPool)
            if todoFrame then
                todoFrame:SetParent(self.todoContainer)
                todoFrame:ClearAllPoints()
                todoFrame:Show()
            else
                todoFrame = CreateFrame("Frame", nil, self.todoContainer)
                todoFrame:SetHeight(22)
                todoFrame._checkbox = CreateFrame("CheckButton", nil, todoFrame, "UICheckButtonTemplate")
                todoFrame._checkbox:SetSize(16, 16)
                todoFrame._checkbox:SetPoint("LEFT", todoFrame, "LEFT", 2, 0)
                todoFrame._text = todoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                todoFrame._text:SetPoint("LEFT", todoFrame._checkbox, "RIGHT", 5, 0)
                todoFrame._text:SetJustifyH("LEFT")
            end

            todoFrame:SetPoint("TOPLEFT", self.todoContainer, "TOPLEFT", 0, yOffset)
            todoFrame:SetPoint("RIGHT",   self.todoContainer, "RIGHT",   0, 0)

            todoFrame._checkbox:SetChecked(todo.completed)
            todoFrame._checkbox:SetScript("OnClick", function(cb)
                todo.completed = cb:GetChecked()
                if zd then zd.modified = GetServerTime() end
                self:RefreshTodos()
            end)

            todoFrame._text:ClearAllPoints()
            todoFrame._text:SetPoint("LEFT",  todoFrame._checkbox, "RIGHT",  5, 0)
            todoFrame._text:SetPoint("RIGHT", todoFrame,           "RIGHT", -5, 0)
            todoFrame._text:SetText(todo.text or "")

            local fs = zd.fontSize or 12
            local todoFontPath = ns.Config:ResolveFontPath(zd.fontFamily)
            todoFrame._text:SetFont(todoFontPath, fs, zd.fontOutline or "")

            if todo.completed then
                todoFrame._text:SetTextColor(0.5, 0.5, 0.5)
            else
                todoFrame._text:SetTextColor(contentTextColor[1], contentTextColor[2], contentTextColor[3], 1)
            end

            table.insert(self.todoItems, todoFrame)
            yOffset = yOffset - 25
        end

        self.todoContainer:SetHeight(math.abs(yOffset) + 10)
    end

    -- Resize handle
    local resizeBtn = CreateFrame("Button", nil, pin)
    resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeBtn:SetSize(12, 12)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function() pin:StartSizing("BOTTOMRIGHT") end)
    resizeBtn:SetScript("OnMouseUp", function()
        pin:StopMovingOrSizing()
        local point, _, relativePoint, x, y = pin:GetPoint()
        ZonePins:SavePinPosition(zoneName, point, relativePoint, x, y, pin:GetWidth(), pin:GetHeight())
        if pin.RefreshLayout then pin:RefreshLayout(true) end
    end)
    pin.resizeBtn = resizeBtn

    -- Hover controls (alpha slider + lock buttons)
    local hoverPanel = CreateFrame("Frame", nil, pin, "BackdropTemplate")
    hoverPanel:SetPoint("TOPLEFT",  pin, "BOTTOMLEFT",  0, 0)
    hoverPanel:SetPoint("TOPRIGHT", pin, "BOTTOMRIGHT", 0, 0)
    hoverPanel:SetHeight(50)
    hoverPanel:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    local listItemColor = colorConfig.listItem
    hoverPanel:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], 0.9)
    hoverPanel:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
    hoverPanel:SetFrameLevel(pin:GetFrameLevel() + 10)
    hoverPanel:Hide()
    pin.hoverPanel = hoverPanel

    local alphaSlider = OneWoW_GUI:CreateSlider(hoverPanel, {
        minVal = 0.1,
        maxVal = 1.0,
        step = 0.05,
        currentVal = pinAlpha,
        onChange = function(val)
            zoneData.opacity = val
            if val >= 1.0 then
                pin:SetBackdrop({
                    bgFile   = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = false, tileSize = 16, edgeSize = 16,
                    insets = { left = 4, right = 4, top = 4, bottom = 4 }
                })
                pin:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], 1.0)
            else
                pin:SetBackdrop({
                    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 16,
                    insets = { left = 4, right = 4, top = 4, bottom = 4 }
                })
                pin:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], val)
            end
            pin:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
        end,
    })
    alphaSlider:SetPoint("TOPLEFT",  hoverPanel, "TOPLEFT",  10, -5)
    alphaSlider:SetPoint("TOPRIGHT", hoverPanel, "TOPRIGHT", -10, -5)

    local lockMoveCB = OneWoW_GUI:CreateCheckbox(hoverPanel, {
        label = L["CORE_PIN_LOCK_MOVE"] or "Lock",
        checked = zoneData.lockMove,
        onClick = function(self)
            zoneData.lockMove = self:GetChecked()
            if zoneData.lockMove then
                pin:SetMovable(false)
                pin:RegisterForDrag()
            else
                pin:SetMovable(true)
                pin:RegisterForDrag("LeftButton")
            end
        end,
    })
    lockMoveCB:SetPoint("BOTTOMLEFT", hoverPanel, "BOTTOMLEFT", 10, 5)
    if zoneData.lockMove then
        pin:SetMovable(false)
        pin:RegisterForDrag()
    end

    local function HideHoverControls()
        hoverPanel:Hide()
    end
    local function ShowHoverControls()
        hoverPanel:Show()
    end

    HideHoverControls()
    pin:SetScript("OnEnter", ShowHoverControls)
    pin:SetScript("OnLeave", function()
        C_Timer.After(0.05, function()
            local overAny = pin:IsMouseOver() or hoverPanel:IsMouseOver()
            if not overAny then HideHoverControls() end
        end)
    end)

    -- Restore saved position
    local savedPos = self:GetPinPosition(zoneName)
    if savedPos then
        pin:ClearAllPoints()
        pin:SetPoint(savedPos.point or "CENTER", UIParent, savedPos.relativePoint or "CENTER",
                     savedPos.x or 0, savedPos.y or 0)
        if savedPos.width and savedPos.height then
            pin:SetSize(savedPos.width, savedPos.height)
        end
    end

    addon.zonePins[zoneName] = pin

    if addon.RegisterWindow then
        pin.windowInfo = addon:RegisterWindow(pin, "zone_pinned", function()
            pin:Hide()
        end)
    end

    pin:SetScript("OnHide", function(self)
        if self._destroying then
            if addon.zonePins and addon.zonePins[zoneName] == self then
                addon.zonePins[zoneName] = nil
            end
        end
        if self.windowInfo and addon.UnregisterWindow then
            addon:UnregisterWindow(self)
            self.windowInfo = nil
        end
    end)

    pin:SetScript("OnShow", function(self)
        if not self.windowInfo and addon.RegisterWindow then
            self.windowInfo = addon:RegisterWindow(self, "zone_pinned", function()
                self:Hide()
            end)
        end
    end)

    pin:RefreshLayout()
    pin:RefreshTodos()
    pin:Show()

    if addon.BringWindowToFront then
        addon:BringWindowToFront(pin)
    end

    return pin
end

function ZonePins:RefreshZonePinColors(zoneName)
    local addon = _G.OneWoW_Notes
    if not addon.zonePins or not addon.zonePins[zoneName] then return end

    local pinFrame = addon.zonePins[zoneName]
    if not pinFrame or not pinFrame:IsShown() then return end

    local zoneData = ns.Zones and ns.Zones:GetZone(zoneName)
    if not zoneData then return end

    local pinColorKey = zoneData.pinColor or "hunter"
    local colorConfig = ns.Config:GetResolvedColorConfig(pinColorKey)
    local bgColor     = colorConfig.background
    local borderColor = colorConfig.border
    local pinAlpha    = zoneData.opacity or 0.9

    pinFrame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], pinAlpha)
    pinFrame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)

    if pinFrame.titleBar then
        local titleColor = colorConfig.titleBar
        pinFrame.titleBar:SetBackdropColor(titleColor[1], titleColor[2], titleColor[3], 0.8)
    end

    local noteFontColor = zoneData.fontColor or "match"
    local fontSize      = zoneData.fontSize  or 12
    local textColor

    if noteFontColor == "match" then
        textColor = borderColor
    elseif noteFontColor == "white" then
        textColor = {1, 1, 1}
    elseif noteFontColor == "black" then
        textColor = {0, 0, 0}
    else
        local fontConfig = ns.Config.PIN_COLORS[noteFontColor]
        textColor = fontConfig and fontConfig.border or borderColor
    end

    if pinFrame.titleText then
        pinFrame.titleText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
    end
    if pinFrame.contentText then
        pinFrame.contentText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
        local fontPath = ns.Config:ResolveFontPath(zoneData.fontFamily)
        pinFrame.contentText:SetFont(fontPath, fontSize, zoneData.fontOutline or "")
    end
    if pinFrame.RefreshTodos then
        pinFrame:RefreshTodos()
    end
end

function ZonePins:RefreshAllPinFonts()
    local addon = _G.OneWoW_Notes
    if not addon.zonePins then return end
    for zoneName, pinFrame in pairs(addon.zonePins) do
        if pinFrame and pinFrame:IsShown() then
            self:RefreshZonePinColors(zoneName)
        end
    end
end

function ZonePins:RefreshSyncPins()
    local addon = _G.OneWoW_Notes
    if not addon.zonePins then return end

    for zoneName, pinFrame in pairs(addon.zonePins) do
        if pinFrame and pinFrame:IsShown() then
            local zoneData = ns.Zones and ns.Zones:GetZone(zoneName)
            if zoneData and zoneData.pinColor == "sync" then
                local colorConfig = ns.Config:GetResolvedColorConfig("sync")
                local bgColor = colorConfig.background
                local borderColor = colorConfig.border
                local titleBarColor = colorConfig.titleBar
                local opacity = zoneData.opacity or 0.9

                if pinFrame:GetBackdropColor() then
                    pinFrame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], opacity)
                end
                pinFrame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)

                if pinFrame.titleBar then
                    pinFrame.titleBar:SetBackdropColor(titleBarColor[1], titleBarColor[2], titleBarColor[3], 0.8)
                end

                if pinFrame.titleText then
                    local fontColor = zoneData.fontColor or "match"
                    local titleColor = ns.Config:GetResolvedFontColor(fontColor, "sync")
                    pinFrame.titleText:SetTextColor(titleColor[1], titleColor[2], titleColor[3], 1)
                end
            end
        end
    end
end
