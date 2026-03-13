-- ============================================================================
-- OneWoW_GUI/OneWoW_GUI.lua
-- THIS IS THE GUI LIBRARY (OneWoW_GUI-1.0) - The single source of truth for
-- all shared UI creation functions. Other addons consume this via LibStub.
-- ALL reusable UI functions (buttons, scroll frames, split panels, etc.)
-- MUST be defined here. Addon Framework.lua files are thin wrappers only.
-- Do NOT duplicate these functions in any addon's Framework.lua.
-- ============================================================================
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local CreateFrame = CreateFrame
local unpack = unpack

local Constants = OneWoW_GUI.Constants
local DEFAULT_THEME = Constants.DEFAULT_THEME
local DEFAULT_THEME_COLOR = DEFAULT_THEME.COLOR
local DEFAULT_THEME_SPACING = DEFAULT_THEME.SPACING
local DEFAULT_THEME_KEY = Constants.DEFAULT_THEME_KEY
local DEFAULT_ICON_TEXTURE = Constants.ICON_TEXTURES.horde

local _splitPanelCount = 0

local noop = function() end

local themeMetatable = {
    __index = function(self, key)
        return Constants.FALLBACK_THEME[key] or DEFAULT_THEME_COLOR
    end,
    __newindex = noop,
}

local guiConstantsMetatable = {
    __index = function(self, key)
        return Constants.GUI[key] or 0
    end,
    __newindex = noop,
}

local function GetThemeColor(key)
    if Constants.ACTIVE_THEME and Constants.ACTIVE_THEME[key] then
        return unpack(Constants.ACTIVE_THEME[key])
    end
    return unpack(DEFAULT_THEME_COLOR)
end

local function GetSpacing(key)
    return Constants.SPACING[key] or DEFAULT_THEME_SPACING
end

function OneWoW_GUI:GetAddonVersion(addonName)
    if not C_AddOns.DoesAddOnExist(addonName) then return nil end
    return C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
end

function OneWoW_GUI:RegisterGUIConstants(guiConstants)
    return setmetatable(guiConstants, guiConstantsMetatable)
end

function OneWoW_GUI:GetThemeColor(key)
    return GetThemeColor(key)
end

function OneWoW_GUI:GetSpacing(key)
    return GetSpacing(key)
end

function OneWoW_GUI:GetBrandIcon(factionTheme)
    return OneWoW_GUI.Constants.ICON_TEXTURES[factionTheme] or DEFAULT_ICON_TEXTURE
end

function OneWoW_GUI:ApplyTheme(addon)
    local themeKey

    if self._settingsDB and self._settingsDB.theme then
        themeKey = self._settingsDB.theme
    elseif _G.OneWoW and _G.OneWoW.db and _G.OneWoW.db.global and _G.OneWoW.db.global.theme then
        themeKey = _G.OneWoW.db.global.theme
    elseif addon and addon.db and addon.db.global and addon.db.global.theme then
        themeKey = addon.db.global.theme
    end

    local selectedTheme = Constants.THEMES[themeKey] or Constants.THEMES[DEFAULT_THEME_KEY]
    Constants.ACTIVE_THEME = setmetatable(selectedTheme, themeMetatable)
end

function OneWoW_GUI:CreateFrame(name, parent, width, height, backdrop)
    local frame = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetBackdrop(backdrop or Constants.BACKDROP_SOFT)
    frame:SetBackdropColor(GetThemeColor("BG_PRIMARY"))
    frame:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))
    return frame
end

function OneWoW_GUI:CreateDialog(config)
    config = config or {}
    local name = config.name
    local title = config.title or ""
    local width = config.width or 500
    local height = config.height or 400
    local strata = config.strata or "DIALOG"
    local movable = config.movable ~= false
    local escClose = config.escClose ~= false
    local showBrand = config.showBrand
    local titleIcon = config.titleIcon
    local titleHeight = config.titleHeight or 28
    local onClose = config.onClose
    local buttonDefs = config.buttons
    local showScrollFrame = config.showScrollFrame

    local frame = self:CreateFrame(name, UIParent, width, height, Constants.BACKDROP_INNER_NO_INSETS)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata(strata)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)

    if movable then
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    end

    if escClose and name then
        tinsert(UISpecialFrames, name)
    end

    local result = { frame = frame, buttons = {} }

    local closeFunc = function()
        frame:Hide()
        if onClose then onClose(frame) end
    end

    local titleBarOpts = {
        height = titleHeight,
        onClose = closeFunc,
        showBrand = showBrand,
        factionTheme = config.factionTheme,
    }
    local titleBar = self:CreateTitleBar(frame, title, titleBarOpts)
    result.titleBar = titleBar

    if movable then
        titleBar:EnableMouse(true)
        titleBar:RegisterForDrag("LeftButton")
        titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
        titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    end

    if titleIcon then
        local icon = titleBar:CreateTexture(nil, "OVERLAY")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", titleBar, "LEFT", GetSpacing("SM"), 0)
        icon:SetTexture(titleIcon)
        titleBar._titleText:ClearAllPoints()
        titleBar._titleText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    end

    local buttonRowHeight = 0
    if buttonDefs and #buttonDefs > 0 then
        buttonRowHeight = 28 + 10 + 10

        local divider = frame:CreateTexture(nil, "ARTWORK")
        divider:SetHeight(1)
        divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, buttonRowHeight)
        divider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, buttonRowHeight)
        divider:SetColorTexture(GetThemeColor("BORDER_SUBTLE"))

        local prevBtn
        for i = #buttonDefs, 1, -1 do
            local def = buttonDefs[i]
            local btn = self:CreateFitTextButton(frame, def.text, { height = 28, minWidth = 80 })
            if not prevBtn then
                btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
            else
                btn:SetPoint("RIGHT", prevBtn, "LEFT", -GetSpacing("SM"), 0)
            end

            if def.color then
                local cr, cg, cb = def.color[1], def.color[2], def.color[3]
                btn:SetBackdropColor(cr, cg, cb, 0.6)
                btn:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(cr, cg, cb, 0.8)
                    self:SetBackdropBorderColor(GetThemeColor("BTN_BORDER_HOVER"))
                    self.text:SetTextColor(1, 1, 1)
                end)
                btn:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(cr, cg, cb, 0.6)
                    self:SetBackdropBorderColor(GetThemeColor("BTN_BORDER"))
                    self.text:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
                end)
            end

            if def.onClick then
                btn:SetScript("OnClick", function() def.onClick(frame) end)
            end

            result.buttons[i] = btn
            prevBtn = btn
        end
    end

    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    contentFrame:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    if buttonRowHeight > 0 then
        contentFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, buttonRowHeight + 1)
        contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, buttonRowHeight + 1)
    else
        contentFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end
    result.contentFrame = contentFrame

    if showScrollFrame then
        local scrollFrame, scrollContent = self:CreateScrollFrame(nil, contentFrame)
        result.scrollFrame = scrollFrame
        result.scrollContent = scrollContent
    end

    frame:Hide()
    return result
end

function OneWoW_GUI:CreateConfirmDialog(config)
    config = config or {}
    local titleText = config.title or ""
    local messageText = config.message or ""
    local dialogWidth = config.width or 420

    local titlePad = 20
    local msgPad = 10
    local bottomPad = 10
    local btnRowHeight = 28 + 10 + 10

    local measureFS = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    measureFS:SetWidth(dialogWidth - 40)
    measureFS:SetText(messageText)
    local msgHeight = measureFS:GetStringHeight()
    measureFS:Hide()
    measureFS:SetParent(nil)

    local titleFS = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetText(titleText)
    local titleTextHeight = titleFS:GetStringHeight()
    titleFS:Hide()
    titleFS:SetParent(nil)

    local totalHeight = titlePad + titleTextHeight + msgPad + msgHeight + msgPad + btnRowHeight + bottomPad
    totalHeight = math.max(totalHeight, 140)

    local result = self:CreateDialog({
        name = config.name,
        title = "",
        width = dialogWidth,
        height = totalHeight,
        movable = false,
        escClose = true,
        titleHeight = 1,
        buttons = config.buttons,
    })

    result.titleBar:SetAlpha(0)
    result.titleBar:SetHeight(1)

    local titleLabel = result.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOP", result.contentFrame, "TOP", 0, -titlePad)
    titleLabel:SetText(titleText)
    titleLabel:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))
    result.titleLabel = titleLabel

    local msgLabel = result.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgLabel:SetPoint("TOP", titleLabel, "BOTTOM", 0, -msgPad)
    msgLabel:SetWidth(dialogWidth - 40)
    msgLabel:SetText(messageText)
    msgLabel:SetTextColor(GetThemeColor("TEXT_SECONDARY"))
    result.messageLabel = msgLabel

    return result
end

function OneWoW_GUI:CreateFilterBar(parent, config)
    config = config or {}
    local height = config.height or 40
    local anchorBelow = config.anchorBelow
    local offset = config.offset or -5

    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if anchorBelow then
        bar:SetPoint("TOPLEFT", anchorBelow, "BOTTOMLEFT", 0, offset)
        bar:SetPoint("TOPRIGHT", anchorBelow, "BOTTOMRIGHT", 0, offset)
    else
        bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, offset)
        bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, offset)
    end
    bar:SetHeight(height)
    bar:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    bar:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
    bar:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))

    return bar
end

function OneWoW_GUI:CreateButton(name, parent, text, width, height)
    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetSize(width or Constants.GUI.BUTTON_WIDTH, height or Constants.GUI.BUTTON_HEIGHT)
    btn:SetBackdrop(Constants.BACKDROP_INNER)
    btn:SetBackdropColor(GetThemeColor("BTN_NORMAL"))
    btn:SetBackdropBorderColor(GetThemeColor("BTN_BORDER"))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text or "")
    btn.text:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(GetThemeColor("TEXT_ACCENT"))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
    end)
    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(GetThemeColor("BTN_PRESSED"))
    end)
    btn:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            self:SetBackdropColor(GetThemeColor("BTN_HOVER"))
        else
            self:SetBackdropColor(GetThemeColor("BTN_NORMAL"))
        end
    end)

    return btn
end

function OneWoW_GUI:CreateFitTextButton(parent, text, options)
    options = options or {}
    local height = options.height or Constants.GUI.BUTTON_HEIGHT
    local minWidth = options.minWidth or 40
    local paddingX = options.paddingX or 24

    local btn = self:CreateButton(nil, parent, text, minWidth, height)
    local textWidth = btn.text:GetStringWidth()
    local finalWidth = math.max(minWidth, textWidth + paddingX)
    btn:SetWidth(finalWidth)

    btn._minWidth = minWidth
    btn._paddingX = paddingX

    function btn:SetFitText(newText)
        self.text:SetText(newText)
        local w = self.text:GetStringWidth()
        self:SetWidth(math.max(self._minWidth, w + self._paddingX))
    end

    return btn
end

function OneWoW_GUI:CreateFitFrameButtons(parent, yOffset, items, options)
    options = options or {}
    local height = options.height or 26
    local gap = options.gap or 4
    local marginX = options.marginX or 12
    local onSelect = options.onSelect
    local availWidth = (options.width or parent:GetWidth()) - (marginX * 2)
    local n = #items
    local bw = math.max(30, math.floor((availWidth - gap * (n - 1)) / n))

    local buttons = {}

    local function applyNormal(btn)
        if btn.isActive then
            btn:SetBackdropColor(GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(GetThemeColor("BORDER_ACCENT"))
            btn.text:SetTextColor(GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(GetThemeColor("TEXT_MUTED"))
        end
    end

    local function applyHover(btn)
        if btn.isActive then
            btn:SetBackdropBorderColor(GetThemeColor("BORDER_FOCUS"))
        else
            btn:SetBackdropColor(GetThemeColor("BTN_HOVER"))
            btn:SetBackdropBorderColor(GetThemeColor("BTN_BORDER_HOVER"))
            btn.text:SetTextColor(GetThemeColor("TEXT_SECONDARY"))
        end
    end

    local xPos = marginX
    local rowY = yOffset

    for i, item in ipairs(items) do
        local btn = self:CreateButton(nil, parent, item.text, bw, height)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xPos, rowY)
        btn.itemValue = item.value
        btn.isActive = item.isActive or false

        applyNormal(btn)

        btn:SetScript("OnEnter", function(self) applyHover(self) end)
        btn:SetScript("OnLeave", function(self) applyNormal(self) end)
        btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(GetThemeColor("BTN_PRESSED")) end)
        btn:SetScript("OnMouseUp", function(self) applyNormal(self) end)
        btn:SetScript("OnClick", function(self)
            for _, ob in ipairs(buttons) do
                ob.isActive = (ob == self)
                applyNormal(ob)
            end
            if onSelect then
                onSelect(self.itemValue, item.text, self)
            end
        end)

        table.insert(buttons, btn)
        xPos = xPos + bw + gap

        if i < n and (xPos + bw) > (availWidth + marginX) then
            xPos = marginX
            rowY = rowY - height - gap
        end
    end

    local finalY = rowY - height

    buttons.SetActiveByValue = function(value)
        for _, btn in ipairs(buttons) do
            btn.isActive = (btn.itemValue == value)
            applyNormal(btn)
        end
    end

    return buttons, finalY
end

function OneWoW_GUI:CreateOnOffToggleButtons(parent, yOffset, onLabel, offLabel, width, height, isEnabled, value, onValueChange)
    width = width or Constants.TOGGLE_BUTTON_WIDTH
    height = height or Constants.TOGGLE_BUTTON_HEIGHT

    local onBtn = self:CreateFitTextButton(parent, onLabel, { height = height, minWidth = width })
    local offBtn = self:CreateFitTextButton(parent, offLabel, { height = height, minWidth = width })

    local maxW = math.max(onBtn:GetWidth(), offBtn:GetWidth())
    onBtn:SetWidth(maxW)
    offBtn:SetWidth(maxW)

    local statusPfx = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusPfx:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    statusPfx:SetText("Status:")
    statusPfx:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    local statusVal = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusVal:SetPoint("LEFT", statusPfx, "RIGHT", 4, 0)

    onBtn:SetPoint("LEFT", statusVal, "RIGHT", 10, 0)
    offBtn:SetPoint("LEFT", onBtn, "RIGHT", 4, 0)

    local function applyHover(btn)
        if btn.isActive then
            btn:SetBackdropColor(GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(GetThemeColor("BORDER_FOCUS"))
            btn.text:SetTextColor(GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(GetThemeColor("BTN_HOVER"))
            btn:SetBackdropBorderColor(GetThemeColor("BTN_BORDER_HOVER"))
            btn.text:SetTextColor(GetThemeColor("TEXT_SECONDARY"))
        end
    end

    local function applyNormal(btn)
        if btn.isActive then
            btn:SetBackdropColor(GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(GetThemeColor("BORDER_ACCENT"))
            btn.text:SetTextColor(GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(GetThemeColor("TEXT_MUTED"))
        end
    end

    for _, btn in ipairs({ onBtn, offBtn }) do
        btn:SetScript("OnEnter", function(self) applyHover(self) end)
        btn:SetScript("OnLeave", function(self) applyNormal(self) end)
        btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(GetThemeColor("BTN_PRESSED")) end)
        btn:SetScript("OnMouseUp", function(self) applyNormal(self) end)
    end

    local function refresh(enabled, val)
        isEnabled = enabled
        if not onBtn:GetParent() or not offBtn:GetParent() then
            return
        end
        enabled = enabled == true
        val = val == true
        onBtn.isActive = enabled and val
        offBtn.isActive = enabled and not val
        onBtn:EnableMouse(enabled)
        offBtn:EnableMouse(enabled)
        if not enabled then
            onBtn:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
            onBtn:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
            offBtn:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
            offBtn:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
            onBtn.text:SetTextColor(GetThemeColor("TEXT_MUTED"))
            offBtn.text:SetTextColor(GetThemeColor("TEXT_MUTED"))
            statusPfx:SetTextColor(GetThemeColor("TEXT_MUTED"))
            statusVal:SetText(val and onLabel or offLabel)
            statusVal:SetTextColor(GetThemeColor("TEXT_MUTED"))
        else
            applyNormal(onBtn)
            applyNormal(offBtn)
            statusPfx:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
            if val then
                statusVal:SetText(onLabel)
                statusVal:SetTextColor(GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                statusVal:SetText(offLabel)
                statusVal:SetTextColor(GetThemeColor("TEXT_FEATURES_DISABLED"))
            end
        end
    end

    onBtn:SetScript("OnClick", function()
        onValueChange(true)
        refresh(isEnabled, true)
        C_Timer.After(0, function()
            if onBtn:GetParent() and offBtn:GetParent() then
                if onBtn:IsMouseOver() then
                    applyHover(onBtn)
                elseif offBtn:IsMouseOver() then
                    applyHover(offBtn)
                end
            end
        end)
    end)
    offBtn:SetScript("OnClick", function()
        onValueChange(false)
        refresh(isEnabled, false)
        C_Timer.After(0, function()
            if onBtn:GetParent() and offBtn:GetParent() then
                if onBtn:IsMouseOver() then
                    applyHover(onBtn)
                elseif offBtn:IsMouseOver() then
                    applyHover(offBtn)
                end
            end
        end)
    end)

    refresh(isEnabled, value)
    return onBtn, offBtn, refresh, statusPfx, statusVal
end

function OneWoW_GUI:CreateToggleRow(parent, yOffset, options)
    options = options or {}
    local label = options.label or ""
    local description = options.description
    local createContent = options.createContent
    local value = options.value
    local isEnabled = options.isEnabled
    local onValueChange = options.onValueChange
    local onLabel = options.onLabel or "On"
    local offLabel = options.offLabel or "Off"
    local buttonWidth = options.buttonWidth or Constants.TOGGLE_BUTTON_WIDTH
    local buttonHeight = options.buttonHeight or Constants.TOGGLE_BUTTON_HEIGHT
    local alignLeft = (options.align == "left")

    local labelFs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelFs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    labelFs:SetJustifyH("LEFT")
    labelFs:SetText(label)
    if label == "" then
        labelFs:Hide()
    end

    local onBtn, offBtn, refresh, statusPfx, statusVal = self:CreateOnOffToggleButtons(
        parent, yOffset, onLabel, offLabel, buttonWidth, buttonHeight,
        isEnabled, value, onValueChange
    )

    if alignLeft then
        if label ~= "" then
            statusPfx:ClearAllPoints()
            statusPfx:SetPoint("LEFT", labelFs, "RIGHT", 8, 0)
        end
        -- when label is empty, statusPfx stays at default TOPLEFT 12 from CreateOnOffToggleButtons
    else
        offBtn:ClearAllPoints()
        offBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
        onBtn:ClearAllPoints()
        onBtn:SetPoint("RIGHT", offBtn, "LEFT", -4, 0)
        statusVal:ClearAllPoints()
        statusVal:SetPoint("RIGHT", onBtn, "LEFT", -10, 0)
        statusPfx:ClearAllPoints()
        statusPfx:SetPoint("RIGHT", statusVal, "LEFT", -4, 0)
        labelFs:SetPoint("RIGHT", statusPfx, "LEFT", -8, 0)
    end

    local rowHeight = buttonHeight
    local newYOffset = yOffset - rowHeight - 4

    local descFs
    local contentArea

    if description then
        descFs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descFs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, newYOffset)
        descFs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, newYOffset)
        descFs:SetJustifyH("LEFT")
        descFs:SetWordWrap(true)
        descFs:SetText(description)
        descFs:SetTextColor(GetThemeColor("TEXT_MUTED"))
        newYOffset = newYOffset - descFs:GetStringHeight() - 6
    elseif createContent then
        contentArea = CreateFrame("Frame", nil, parent)
        contentArea:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, newYOffset)
        contentArea:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, newYOffset)
        local contentFrame, contentHeight = createContent(contentArea)
        contentHeight = contentHeight or 0
        contentArea:SetHeight(contentHeight)
        newYOffset = newYOffset - contentHeight - 6
    end

    newYOffset = newYOffset - 10

    local function rowRefresh(enabled, val)
        refresh(enabled, val)
        if enabled then
            labelFs:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
            if descFs then
                descFs:SetTextColor(GetThemeColor("TEXT_MUTED"))
            end
        else
            labelFs:SetTextColor(GetThemeColor("TEXT_MUTED"))
            if descFs then
                descFs:SetTextColor(GetThemeColor("TEXT_MUTED"))
            end
        end
    end

    rowRefresh(isEnabled, value)

    return newYOffset, rowRefresh, { label = labelFs, contentArea = contentArea }
end

function OneWoW_GUI:CreateEditBox(name, parent, options)
    options = options or {}
    local width = options.width
    local height = options.height or Constants.GUI.SEARCH_HEIGHT
    local placeholderText = options.placeholderText or ""
    local maxLetters = options.maxLetters
    local onTextChanged = options.onTextChanged
    local spacing = GetSpacing("SM")

    local box = CreateFrame("EditBox", name, parent, "BackdropTemplate")
    box.placeholderText = placeholderText

    if width then
        box:SetSize(width, height)
    else
        box:SetHeight(height)
    end
    box:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    box:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
    box:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(spacing, spacing, 0, 0)
    box:SetAutoFocus(false)
    box:EnableMouse(true)
    box:SetTextColor(GetThemeColor("TEXT_MUTED"))
    box:SetText(placeholderText)

    if maxLetters then
        box:SetMaxLetters(maxLetters)
    end

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(GetThemeColor("BORDER_ACCENT"))
        if self:GetText() == self.placeholderText then
            self:SetText("")
            self:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
        end
    end)

    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
        if self:GetText() == "" then
            self:SetText(self.placeholderText)
            self:SetTextColor(GetThemeColor("TEXT_MUTED"))
        end
    end)

    if onTextChanged then
        box:SetScript("OnTextChanged", function(self)
            local text = self:GetText()
            if text == self.placeholderText then text = "" end
            onTextChanged(text)
        end)
    end

    function box:GetSearchText()
        local text = self:GetText()
        if text == self.placeholderText then return "" end
        return text
    end

    return box
end

function OneWoW_GUI:CreateStatusDot(parent, options)
    options = options or {}
    local size = options.size or 8

    local dot = parent:CreateTexture(nil, "OVERLAY")
    dot:SetSize(size, size)
    dot:SetTexture("Interface\\Buttons\\WHITE8x8")

    if options.enabled == true then
        dot:SetVertexColor(GetThemeColor("DOT_FEATURES_ENABLED"))
    elseif options.enabled == false then
        dot:SetVertexColor(GetThemeColor("DOT_FEATURES_DISABLED"))
    end

    function dot:SetStatus(enabled)
        if enabled then
            self:SetVertexColor(GetThemeColor("DOT_FEATURES_ENABLED"))
        else
            self:SetVertexColor(GetThemeColor("DOT_FEATURES_DISABLED"))
        end
    end

    return dot
end

function OneWoW_GUI:CreateListRowBasic(parent, options)
    options = options or {}
    local height = options.height or 30
    local labelText = options.label or ""
    local onClick = options.onClick
    local showDot = options.showDot
    local dotEnabled = options.dotEnabled
    local showValueText = options.showValueText
    local valueText = options.valueText or ""

    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(height)
    row:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
    row:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
    row.isActive = false

    if showDot then
        row.dot = self:CreateStatusDot(row, { enabled = dotEnabled })
        row.dot:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    end

    if showValueText then
        row.valueText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.valueText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.valueText:SetTextColor(GetThemeColor("TEXT_MUTED"))
        row.valueText:SetJustifyH("RIGHT")
        row.valueText:SetText(valueText)
    end

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
    if showDot then
        row.label:SetPoint("RIGHT", row, "RIGHT", -24, 0)
    elseif showValueText and row.valueText then
        row.label:SetPoint("RIGHT", row.valueText, "LEFT", -4, 0)
    else
        row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    end
    row.label:SetJustifyH("LEFT")
    row.label:SetText(labelText)
    row.label:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    function row:SetActive(active)
        self.isActive = active
        if active then
            self:SetBackdropColor(GetThemeColor("BG_ACTIVE"))
            self:SetBackdropBorderColor(GetThemeColor("BORDER_ACCENT"))
            self.label:SetTextColor(GetThemeColor("TEXT_ACCENT"))
        else
            self:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
            self:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
            self.label:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
        end
    end

    row:SetScript("OnEnter", function(self)
        if not self.isActive then
            self:SetBackdropColor(GetThemeColor("BG_HOVER"))
            self.label:SetTextColor(GetThemeColor("TEXT_ACCENT"))
        end
    end)
    row:SetScript("OnLeave", function(self)
        if not self.isActive then
            self:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
            self.label:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
        end
    end)

    if onClick then
        row:SetScript("OnClick", function(self) onClick(self) end)
    end

    return row
end

function OneWoW_GUI:CreateCheckbox(name, parent, label)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetSize(Constants.GUI.CHECKBOX_SIZE, Constants.GUI.CHECKBOX_SIZE)

    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.label:SetPoint("LEFT", cb, "RIGHT", GetSpacing("XS"), 0)
    cb.label:SetText(label)
    cb.label:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    return cb
end

function OneWoW_GUI:CreateHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", GetSpacing("MD"), yOffset or -GetSpacing("MD"))
    header:SetText(text)
    header:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))
    return header
end

function OneWoW_GUI:CreateDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("LEFT", GetSpacing("MD"), 0)
    divider:SetPoint("RIGHT", -GetSpacing("MD"), 0)
    divider:SetPoint("TOP", 0, yOffset)
    divider:SetColorTexture(GetThemeColor("BORDER_SUBTLE"))
    return divider
end

function OneWoW_GUI:CreateSection(parent, title, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", GetSpacing("MD"), yOffset)
    header:SetText(title)
    header:SetTextColor(GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - header:GetStringHeight() - 6

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", GetSpacing("MD"), yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -GetSpacing("MD"), yOffset)
    divider:SetColorTexture(GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    return yOffset
end

function OneWoW_GUI:CreateTitleBar(parent, title, options)
    options = options or {}
    local height = options.height or 20
    local onClose = options.onClose
    local showBrand = options.showBrand

    local titleBg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    titleBg:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    titleBg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
    titleBg:SetHeight(height)
    titleBg:SetBackdrop(Constants.BACKDROP_SIMPLE)
    titleBg:SetBackdropColor(GetThemeColor("TITLEBAR_BG"))
    titleBg:SetFrameLevel(parent:GetFrameLevel() + 1)

    titleBg._titleText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    
    if showBrand then
        local factionTheme = options.factionTheme
        if not factionTheme then
            factionTheme = (self.GetSetting and self:GetSetting("minimap.theme")) or "horde"
        end
        local brandIcon = titleBg:CreateTexture(nil, "OVERLAY")
        brandIcon:SetSize(14, 14)
        brandIcon:SetPoint("LEFT", titleBg, "LEFT", GetSpacing("SM"), 0)
        brandIcon:SetTexture(self:GetBrandIcon(factionTheme))
        titleBg.brandIcon = brandIcon

        local brandText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        brandText:SetPoint("LEFT", brandIcon, "RIGHT", 4, 0)
        brandText:SetText("OneWoW")
        brandText:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))
        
        titleBg._titleText:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
        titleBg._titleText:SetText(title)
        titleBg._titleText:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
    else
        titleBg._titleText:SetPoint("LEFT", titleBg, "LEFT", GetSpacing("MD"), 0)
        titleBg._titleText:SetText(title)
        titleBg._titleText:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))
    end

    if onClose then
        local closeBtn = self:CreateButton(nil, titleBg, "X", 20, 20)
        closeBtn:SetPoint("RIGHT", titleBg, "RIGHT", -GetSpacing("XS") / 2, 0)
        closeBtn:SetScript("OnClick", onClose)
        titleBg._closeBtn = closeBtn
    end

    return titleBg
end

local function applyScrollBarStyle(scrollBar, container, offset)
    if not scrollBar then return end
    offset = offset or -2
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", offset, 0)
    scrollBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", offset, 0)
    scrollBar:SetWidth(10)
    if scrollBar.ScrollUpButton then
        scrollBar.ScrollUpButton:Hide()
        scrollBar.ScrollUpButton:SetAlpha(0)
        scrollBar.ScrollUpButton:EnableMouse(false)
    end
    if scrollBar.ScrollDownButton then
        scrollBar.ScrollDownButton:Hide()
        scrollBar.ScrollDownButton:SetAlpha(0)
        scrollBar.ScrollDownButton:EnableMouse(false)
    end
    if scrollBar.Background then
        scrollBar.Background:SetColorTexture(GetThemeColor("BG_TERTIARY"))
    end
    if scrollBar.Track then
        if scrollBar.Track.Begin then scrollBar.Track.Begin:SetAlpha(0) end
        if scrollBar.Track.End then scrollBar.Track.End:SetAlpha(0) end
        if scrollBar.Track.Middle then scrollBar.Track.Middle:SetColorTexture(GetThemeColor("BG_TERTIARY")) end
    end
    if scrollBar.ThumbTexture then
        scrollBar.ThumbTexture:SetWidth(8)
        scrollBar.ThumbTexture:SetColorTexture(GetThemeColor("ACCENT_PRIMARY"))
    end
    scrollBar:SetScript("OnEnter", function(self)
        if self.ThumbTexture then self.ThumbTexture:SetColorTexture(GetThemeColor("ACCENT_HIGHLIGHT")) end
    end)
    scrollBar:SetScript("OnLeave", function(self)
        if self.ThumbTexture then self.ThumbTexture:SetColorTexture(GetThemeColor("ACCENT_PRIMARY")) end
    end)
end

function OneWoW_GUI:StyleScrollBar(scrollFrame, options)
    local opt = options or {}
    local scrollBar = scrollFrame.ScrollBar
    if not scrollBar then return end
    local container = opt.container or scrollFrame
    local offset = opt.offset or -2
    applyScrollBarStyle(scrollBar, container, offset)
end

function OneWoW_GUI:CreateScrollFrame(name, parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)

    applyScrollBarStyle(scrollFrame.ScrollBar, parent, -2)

    local contentName = name and (name .. "Content") or nil
    local content = CreateFrame("Frame", contentName, scrollFrame)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    if width then
        content:SetWidth(width - 32)
    else
        scrollFrame:HookScript("OnSizeChanged", function(self, w)
            content:SetWidth(w)
        end)
    end

    return scrollFrame, content
end

function OneWoW_GUI:CreateSectionHeader(parent, title, yOffset)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", 8, yOffset)
    section:SetPoint("TOPRIGHT", -8, yOffset)
    section:SetHeight(30)
    section:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    section:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
    section:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))

    local titleText = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", 12, 0)
    titleText:SetText(title)
    titleText:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))

    section.bottomY = yOffset - 30

    return section
end

function OneWoW_GUI:CreateSplitPanel(parent, options)
    local panelGap = Constants.GUI.PANEL_GAP or 10

    local backdrop = Constants.BACKDROP_INNER_NO_INSETS

    options = options or {}
    local showSearch = options.showSearch

    _splitPanelCount = _splitPanelCount + 1
    local uid = _splitPanelCount

    local listPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 35)
    listPanel:SetWidth(Constants.GUI.LEFT_PANEL_WIDTH)
    listPanel:SetBackdrop(backdrop)
    listPanel:SetBackdropColor(GetThemeColor("BG_PRIMARY"))
    listPanel:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))

    local listTitle = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 10, -10)
    listTitle:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -10, -10)
    listTitle:SetJustifyH("LEFT")
    listTitle:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))

    local searchBox
    if showSearch then
        searchBox = self:CreateEditBox(nil, listPanel, {
            placeholderText = options.searchPlaceholder or "",
        })
        searchBox:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, -30)
        searchBox:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -8, -30)
    end

    local containerTopY = showSearch and -58 or -32
    local listContainer = CreateFrame("Frame", nil, listPanel)
    listContainer:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, containerTopY)
    listContainer:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -8, 8)

    local listScrollFrame = CreateFrame("ScrollFrame", "OneWoWGUI_Split_List" .. uid, listContainer, "UIPanelScrollFrameTemplate")
    listScrollFrame:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, 0)
    listScrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -14, 0)
    listScrollFrame:EnableMouseWheel(true)

    applyScrollBarStyle(listScrollFrame.ScrollBar, listContainer, -2)

    local listScrollChild = CreateFrame("Frame", "OneWoWGUI_Split_ListContent" .. uid, listScrollFrame)
    listScrollChild:SetHeight(1)
    listScrollFrame:SetScrollChild(listScrollChild)
    listScrollFrame:HookScript("OnSizeChanged", function(self, w)
        listScrollChild:SetWidth(w)
    end)

    local detailPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detailPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", panelGap, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 35)
    detailPanel:SetBackdrop(backdrop)
    detailPanel:SetBackdropColor(GetThemeColor("BG_PRIMARY"))
    detailPanel:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))

    local detailTitle = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailTitle:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 10, -10)
    detailTitle:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -10, -10)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))

    local detailContainer = CreateFrame("Frame", nil, detailPanel)
    detailContainer:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 8, -32)
    detailContainer:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 8)

    local detailScrollFrame = CreateFrame("ScrollFrame", "OneWoWGUI_Split_Detail" .. uid, detailContainer, "UIPanelScrollFrameTemplate")
    detailScrollFrame:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 0, 0)
    detailScrollFrame:SetPoint("BOTTOMRIGHT", detailContainer, "BOTTOMRIGHT", -14, 0)
    detailScrollFrame:EnableMouseWheel(true)

    applyScrollBarStyle(detailScrollFrame.ScrollBar, detailContainer, -2)

    local detailScrollChild = CreateFrame("Frame", "OneWoWGUI_Split_DetailContent" .. uid, detailScrollFrame)
    detailScrollChild:SetHeight(1)
    detailScrollFrame:SetScrollChild(detailScrollChild)
    detailScrollFrame:HookScript("OnSizeChanged", function(self, w)
        detailScrollChild:SetWidth(w)
    end)

    local leftStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    leftStatusBar:SetPoint("TOPLEFT", listPanel, "BOTTOMLEFT", 0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)
    leftStatusBar:SetBackdrop(backdrop)
    leftStatusBar:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
    leftStatusBar:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))

    local leftStatusText = leftStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText("")

    local rightStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rightStatusBar:SetPoint("TOPLEFT", detailPanel, "BOTTOMLEFT", 0, -5)
    rightStatusBar:SetPoint("TOPRIGHT", detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)
    rightStatusBar:SetBackdrop(backdrop)
    rightStatusBar:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
    rightStatusBar:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))

    local rightStatusText = rightStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(GetThemeColor("TEXT_SECONDARY"))
    rightStatusText:SetText("")

    return {
        listPanel = listPanel,
        listTitle = listTitle,
        listScrollFrame = listScrollFrame,
        listScrollChild = listScrollChild,
        UpdateListThumb = noop,
        detailPanel = detailPanel,
        detailTitle = detailTitle,
        detailScrollFrame = detailScrollFrame,
        detailScrollChild = detailScrollChild,
        UpdateDetailThumb = noop,
        searchBox = searchBox,
        leftStatusBar = leftStatusBar,
        leftStatusText = leftStatusText,
        rightStatusBar = rightStatusBar,
        rightStatusText = rightStatusText,
    }
end

function OneWoW_GUI:CreateDropdown(parent, options)
    options = options or {}
    local width = options.width or 200
    local height = options.height or 26
    local defaultText = options.text or ""

    local dropdown = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dropdown:SetSize(width, height)
    dropdown:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    dropdown:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
    dropdown:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))

    local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    text:SetPoint("RIGHT", dropdown, "RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(defaultText)
    text:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    local arrow = dropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -4, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    dropdown:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(GetThemeColor("BORDER_FOCUS"))
    end)
    dropdown:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
    end)

    dropdown._text = text
    dropdown._activeValue = nil

    return dropdown, text
end

local _dropdownMenuCount = 0

function OneWoW_GUI:AttachFilterMenu(dropdown, dropdownText, options)
    options = options or {}
    local searchable = options.searchable ~= false
    local buildItems = options.buildItems
    local onSelect = options.onSelect
    local maxVisible = options.maxVisible or 20
    local menuHeight = options.menuHeight or 314
    local getActiveValue = options.getActiveValue

    dropdown:SetScript("OnClick", function(self)
        if self._menu and self._menu:IsShown() then
            self._menu:Hide()
            return
        end

        local items = buildItems and buildItems() or {}

        _dropdownMenuCount = _dropdownMenuCount + 1
        local uid = _dropdownMenuCount

        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        self._menu = menu
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(self:GetWidth() + 20, menuHeight)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        menu:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
        menu:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))
        menu:EnableMouse(true)

        local searchBox
        local contentTopY = -2

        if searchable then
            searchBox = CreateFrame("EditBox", nil, menu, "BackdropTemplate")
            searchBox:SetSize(menu:GetWidth() - 15, 28)
            searchBox:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
            searchBox:SetBackdrop(Constants.BACKDROP_INNER)
            searchBox:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
            searchBox:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
            searchBox:SetFontObject(GameFontHighlight)
            searchBox:SetTextInsets(8, 8, 0, 0)
            searchBox:SetAutoFocus(false)
            searchBox:SetMaxLetters(50)
            searchBox:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
            searchBox:SetScript("OnEditFocusGained", function(s)
                s:SetBackdropBorderColor(GetThemeColor("BORDER_FOCUS"))
            end)
            searchBox:SetScript("OnEditFocusLost", function(s)
                s:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
            end)

            local separator = menu:CreateTexture(nil, "ARTWORK")
            separator:SetSize(menu:GetWidth() - 4, 1)
            separator:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -32)
            separator:SetColorTexture(GetThemeColor("BORDER_DEFAULT"))

            contentTopY = -36
        end

        local scrollContainer = CreateFrame("Frame", nil, menu)
        scrollContainer:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, contentTopY)
        scrollContainer:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -2, 2)

        local scrollFrame = CreateFrame("ScrollFrame", "OneWoWGUI_DropMenu_" .. uid, scrollContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", 0, 0)
        scrollFrame:EnableMouseWheel(true)

        applyScrollBarStyle(scrollFrame.ScrollBar, scrollContainer, -2)

        local scrollChild = CreateFrame("Frame", "OneWoWGUI_DropMenuContent_" .. uid, scrollFrame)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)
        scrollFrame:HookScript("OnSizeChanged", function(sf, w)
            scrollChild:SetWidth(w)
        end)

        local elements = {}
        local activeValue = getActiveValue and getActiveValue() or dropdown._activeValue

        for _, item in ipairs(items) do
            local itemType = item.type or "item"

            if itemType == "header" then
                local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                header:SetText(item.text)
                header:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))
                table.insert(elements, { frame = header, type = "header", height = 24 })

            elseif itemType == "divider" then
                local divider = scrollChild:CreateTexture(nil, "ARTWORK")
                divider:SetHeight(1)
                divider:SetColorTexture(GetThemeColor("BORDER_SUBTLE"))
                table.insert(elements, { frame = divider, type = "divider", height = 10 })

            elseif itemType == "checkbox" then
                local row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                row:SetHeight(26)
                row:SetBackdrop(Constants.BACKDROP_SIMPLE)
                row:SetBackdropColor(0, 0, 0, 0)

                local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                cb:SetSize(18, 18)
                cb:SetPoint("LEFT", row, "LEFT", 4, 0)
                cb:SetChecked(item.checked or false)

                local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
                label:SetText(item.text)
                label:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

                row:SetScript("OnEnter", function(r)
                    r:SetBackdropColor(GetThemeColor("BG_HOVER"))
                    label:SetTextColor(GetThemeColor("TEXT_ACCENT"))
                end)
                row:SetScript("OnLeave", function(r)
                    r:SetBackdropColor(0, 0, 0, 0)
                    label:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
                end)

                local onToggle = item.onToggle
                cb:SetScript("OnClick", function(c)
                    if onToggle then onToggle(c:GetChecked()) end
                end)
                row:SetScript("OnClick", function()
                    cb:SetChecked(not cb:GetChecked())
                    if onToggle then onToggle(cb:GetChecked()) end
                end)

                row.checkbox = cb
                table.insert(elements, { frame = row, type = "checkbox", height = 26 })

            else
                local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                btn:SetSize(scrollChild:GetWidth() or (menu:GetWidth() - 20), 26)
                btn:SetBackdrop(Constants.BACKDROP_SIMPLE)

                if activeValue == item.value then
                    btn:SetBackdropColor(GetThemeColor("ACCENT_PRIMARY"))
                else
                    btn:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
                end

                local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                txt:SetPoint("LEFT", btn, "LEFT", 8, 0)
                txt:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
                txt:SetJustifyH("LEFT")
                txt:SetText(item.text)
                txt:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

                btn:SetScript("OnEnter", function(b)
                    if activeValue ~= item.value then
                        b:SetBackdropColor(GetThemeColor("BG_HOVER"))
                        txt:SetTextColor(GetThemeColor("TEXT_ACCENT"))
                    end
                    if item.onEnter then item.onEnter(b) end
                end)
                btn:SetScript("OnLeave", function(b)
                    if activeValue ~= item.value then
                        b:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
                        txt:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
                    end
                    if item.onLeave then item.onLeave(b) end
                end)
                btn:SetScript("OnClick", function()
                    menu:Hide()
                    dropdown._activeValue = item.value
                    if onSelect then
                        onSelect(item.value, item.text)
                    end
                end)

                btn.filterKey = item.text:lower()
                btn:Hide()
                table.insert(elements, { frame = btn, type = "item", height = 28, filterKey = btn.filterKey })
            end
        end

        local function renderList(filter)
            local yPos = -2
            local shown = 0
            local isFiltering = filter ~= ""
            for _, elem in ipairs(elements) do
                if isFiltering and elem.type ~= "item" then
                    elem.frame:Hide()
                elseif elem.type == "item" then
                    if not isFiltering or string.find(elem.filterKey, filter, 1, true) then
                        if shown < maxVisible or isFiltering then
                            elem.frame:ClearAllPoints()
                            elem.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, yPos)
                            elem.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -2, yPos)
                            elem.frame:Show()
                            yPos = yPos - elem.height
                            shown = shown + 1
                        else
                            elem.frame:Hide()
                        end
                    else
                        elem.frame:Hide()
                    end
                elseif elem.type == "header" then
                    elem.frame:ClearAllPoints()
                    elem.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, yPos - 4)
                    elem.frame:Show()
                    yPos = yPos - elem.height
                elseif elem.type == "divider" then
                    elem.frame:ClearAllPoints()
                    elem.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, yPos - 4)
                    elem.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -8, yPos - 4)
                    elem.frame:Show()
                    yPos = yPos - elem.height
                elseif elem.type == "checkbox" then
                    elem.frame:ClearAllPoints()
                    elem.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, yPos)
                    elem.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -2, yPos)
                    elem.frame:Show()
                    yPos = yPos - elem.height
                end
            end
            local totalH = math.max(28, math.abs(yPos) + 2)
            scrollChild:SetHeight(totalH)
        end

        renderList("")

        if searchBox then
            searchBox:SetScript("OnTextChanged", function(s)
                renderList(s:GetText():lower())
            end)
            searchBox:SetScript("OnEscapePressed", function(s)
                if s:GetText() ~= "" then
                    s:SetText("")
                    renderList("")
                else
                    menu:Hide()
                end
            end)
        end

        menu:SetScript("OnShow", function(m)
            local timeOutside = 0
            m:SetScript("OnUpdate", function(m2, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(self) and (not searchBox or not searchBox:HasFocus()) then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 0.5 then
                        m2:Hide()
                        m2:SetScript("OnUpdate", nil)
                    end
                else
                    timeOutside = 0
                end
            end)
        end)

        menu:Show()
        if searchBox then
            searchBox:SetFocus()
        end
    end)
end

function OneWoW_GUI:CreateSlider(parent, minVal, maxVal, step, currentVal, onChange, width, fmt)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width or 200, 36)

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT",  container, "TOPLEFT",  0,   0)
    slider:SetPoint("TOPRIGHT", container, "TOPRIGHT", -40, 0)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetValue(currentVal)
    slider:SetObeyStepOnDrag(true)

    local valLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valLabel:SetPoint("LEFT", slider, "RIGHT", 6, 0)
    valLabel:SetText(string.format(fmt or "%.1f", currentVal))
    valLabel:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    if slider.Low  then slider.Low:SetText(tostring(minVal)) end
    if slider.High then slider.High:SetText(tostring(maxVal)) end
    if slider.Text then slider.Text:SetText("") end

    slider:SetScript("OnValueChanged", function(self, val)
        local rounded = math.floor(val / step + 0.5) * step
        rounded = math.max(minVal, math.min(maxVal, rounded))
        valLabel:SetText(string.format(fmt or "%.1f", rounded))
        onChange(rounded)
    end)

    return container
end

function OneWoW_GUI:ClearFrame(frame)
    if not frame then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        region:Hide()
    end
end

function OneWoW_GUI:GetProgressColor(current, max)
    local colors = Constants.PROGRESS_COLORS
    if max == 0 then return unpack(colors.NONE) end
    local pct = current / max
    if pct >= 1.0 then return unpack(colors.FULL)
    elseif pct >= 0.5 then return unpack(colors.MID)
    else return unpack(colors.LOW) end
end

function OneWoW_GUI:CreateProgressBar(parent, options)
    options = options or {}
    local height = options.height or Constants.PROGRESS_BAR.HEIGHT
    local min = options.min or 0
    local max = options.max or 100
    local value = options.value or 0
    local bgColor = Constants.PROGRESS_BAR.BG_COLOR

    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(Constants.BAR_TEXTURE)
    bar:GetStatusBarTexture():SetHorizTile(false)
    bar:SetMinMaxValues(min, max)
    bar:SetValue(value)
    bar:SetHeight(height)

    local pR, pG, pB = self:GetProgressColor(value, max)
    bar:SetStatusBarColor(pR, pG, pB)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(unpack(bgColor))
    bar._bg = bg

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetText(string.format("%d/%d", value, max))
    text:SetTextColor(1, 1, 1, 1)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    bar._text = text

    function bar:UpdateProgress(current, maximum)
        self:SetMinMaxValues(0, maximum)
        self:SetValue(current)
        local r, g, b = OneWoW_GUI:GetProgressColor(current, maximum)
        self:SetStatusBarColor(r, g, b)
        self._text:SetText(string.format("%d/%d", current, maximum))
    end

    return bar
end

local _dataTableCount = 0

function OneWoW_GUI:CreateDataTable(parent, options)
    options = options or {}
    local columns = options.columns or {}
    local headerHeight = options.headerHeight or 30
    local rowHeight = options.rowHeight or 32
    local colGap = options.colGap or 4
    local scrollBarWidth = options.scrollBarWidth or 10
    local padding = options.padding or 8
    local minFlexWidth = options.minFlexWidth or 20
    local onSort = options.onSort
    local onHeaderCreate = options.onHeaderCreate

    _dataTableCount = _dataTableCount + 1
    local uid = _dataTableCount

    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    container:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    container:SetBackdropColor(GetThemeColor("BG_PRIMARY"))
    container:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))

    local inner = CreateFrame("Frame", nil, container)
    inner:SetPoint("TOPLEFT", container, "TOPLEFT", padding, -padding)
    inner:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -padding, padding)

    local headerRow = CreateFrame("Frame", nil, inner, "BackdropTemplate")
    headerRow:SetClipsChildren(true)
    headerRow:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, 0)
    headerRow:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -scrollBarWidth, 0)
    headerRow:SetHeight(headerHeight)
    headerRow:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    headerRow:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
    headerRow:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))

    headerRow.columnButtons = {}
    headerRow.columns = columns

    local state = {
        sortColumn = nil,
        sortAscending = true,
        rows = {},
    }

    local function UpdateAllRowCells()
        if not headerRow or not headerRow.columnButtons then return end
        if not state.rows then return end
        for _, row in ipairs(state.rows) do
            if row.cells then
                for i, cell in ipairs(row.cells) do
                    local btn = headerRow.columnButtons[i]
                    if btn and btn.columnWidth and btn.columnX then
                        local width = btn.columnWidth
                        local x = btn.columnX
                        local col = columns[i]
                        cell:ClearAllPoints()
                        if col and col.align == "icon" then
                            cell:SetSize(width, rowHeight)
                            cell:SetPoint("LEFT", row, "LEFT", x, 0)
                        elseif col and col.align == "center" then
                            cell:SetWidth(width - 6)
                            cell:SetPoint("CENTER", row, "LEFT", x + width / 2, 0)
                        elseif col and col.align == "right" then
                            cell:SetWidth(width - 6)
                            cell:SetPoint("RIGHT", row, "LEFT", x + width - 3, 0)
                        else
                            cell:SetWidth(width - 6)
                            cell:SetPoint("LEFT", row, "LEFT", x + 3, 0)
                        end
                    end
                end
            end
        end
    end

    local function UpdateColumnLayout()
        local availableWidth = headerRow:GetWidth() - 10
        if availableWidth <= 0 then return end

        local fixedWidth = 0
        local flexCount = 0
        for _, col in ipairs(columns) do
            if col.fixed then
                fixedWidth = fixedWidth + col.width
            else
                flexCount = flexCount + 1
            end
        end

        local totalGaps = (#columns - 1) * colGap
        local remainingWidth = availableWidth - fixedWidth - totalGaps
        local flexWidth = flexCount > 0 and math.max(0, remainingWidth / flexCount) or 0

        local xOffset = 5
        for i, col in ipairs(columns) do
            local btn = headerRow.columnButtons[i]
            if btn then
                local width = col.fixed and col.width or math.max(minFlexWidth, flexWidth)
                btn:SetWidth(width)
                btn:ClearAllPoints()
                btn:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", xOffset, 2)
                btn.columnWidth = width
                btn.columnX = xOffset
                xOffset = xOffset + width + colGap
            end
        end

        UpdateAllRowCells()
    end

    local function UpdateSortIndicators()
        if not headerRow or not headerRow.columnButtons then return end
        for i, btn in ipairs(headerRow.columnButtons) do
            local col = columns[i]
            if btn.sortArrow then btn.sortArrow:Hide() end
            if col and col.key == state.sortColumn then
                if not btn.sortArrow then
                    btn.sortArrow = btn:CreateTexture(nil, "OVERLAY")
                    btn.sortArrow:SetSize(8, 8)
                    btn.sortArrow:SetPoint("RIGHT", btn, "RIGHT", -3, 0)
                    btn.sortArrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
                end
                btn.sortArrow:Show()
                if state.sortAscending then
                    btn.sortArrow:SetTexCoord(0, 0.5625, 1, 0)
                else
                    btn.sortArrow:SetTexCoord(0, 0.5625, 0, 1)
                end
            end
        end
    end

    for i, col in ipairs(columns) do
        local btn = CreateFrame("Button", nil, headerRow, "BackdropTemplate")
        btn:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        btn:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
        btn:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))
        btn:SetHeight(headerHeight - 4)

        if col.headerIcon then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(col.headerIconSize or 16, col.headerIconSize or 16)
            icon:SetPoint("CENTER")
            if col.headerIconAtlas then
                icon:SetAtlas(col.headerIcon)
            else
                icon:SetTexture(col.headerIcon)
            end
            btn.icon = icon
        else
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("CENTER")
            text:SetText(col.label or "")
            text:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
            btn.text = text
        end

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(GetThemeColor("BG_HOVER"))
            if btn.text then btn.text:SetTextColor(GetThemeColor("TEXT_ACCENT")) end
            if col.ttTitle and col.ttDesc then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(col.ttTitle, 1, 1, 1)
                GameTooltip:AddLine(col.ttDesc, nil, nil, nil, true)
                GameTooltip:Show()
            elseif col.tooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(col.tooltip, 1, 1, 1)
                GameTooltip:Show()
            end
        end)

        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
            if btn.text then btn.text:SetTextColor(GetThemeColor("TEXT_PRIMARY")) end
            GameTooltip:Hide()
        end)

        if col.sortable ~= false then
            btn:SetScript("OnClick", function()
                if state.sortColumn == col.key then
                    state.sortAscending = not state.sortAscending
                else
                    state.sortColumn = col.key
                    state.sortAscending = true
                end
                if onSort then
                    onSort(state.sortColumn, state.sortAscending)
                end
                UpdateSortIndicators()
            end)
        end

        if onHeaderCreate then
            onHeaderCreate(btn, col, i)
        end

        table.insert(headerRow.columnButtons, btn)
    end

    headerRow:SetScript("OnSizeChanged", function()
        C_Timer.After(0.1, function() UpdateColumnLayout() end)
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, inner)
    scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -scrollBarWidth, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 40))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 40))
        end
    end)

    local scrollTrack = CreateFrame("Frame", nil, inner, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -2, 0)
    scrollTrack:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -2, 0)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop(Constants.BACKDROP_SIMPLE)
    scrollTrack:SetBackdropColor(GetThemeColor("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(30)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop(Constants.BACKDROP_SIMPLE)
    scrollThumb:SetBackdropColor(GetThemeColor("ACCENT_PRIMARY"))

    local function UpdateScrollThumb()
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        if maxScroll <= 0 then
            scrollThumb:Hide()
            return
        end
        scrollThumb:Show()
        local viewHeight = scrollFrame:GetHeight()
        local trackHeight = scrollTrack:GetHeight()
        local thumbHeight = math.max(20, trackHeight * (viewHeight / (viewHeight + maxScroll)))
        local thumbRange = trackHeight - thumbHeight
        local thumbPos = (scrollFrame:GetVerticalScroll() / maxScroll) * thumbRange
        scrollThumb:SetHeight(thumbHeight)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -thumbPos)
    end

    scrollFrame:SetScript("OnVerticalScroll", function() UpdateScrollThumb() end)
    scrollFrame:SetScript("OnScrollRangeChanged", function() UpdateScrollThumb() end)

    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")
    scrollThumb:SetScript("OnDragStart", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnDragStop", function(self) self.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self.dragStartY - curY
        local trackHeight = scrollTrack:GetHeight()
        local thumbRange = trackHeight - self:GetHeight()
        if thumbRange > 0 then
            local maxScroll = scrollFrame:GetVerticalScrollRange()
            local newScroll = self.dragStartScroll + (delta / thumbRange) * maxScroll
            scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, newScroll)))
        end
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(scrollFrame:GetWidth())
    scrollContent:SetHeight(400)
    scrollFrame:SetScrollChild(scrollContent)

    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        scrollContent:SetWidth(width)
        UpdateScrollThumb()
    end)

    C_Timer.After(0.2, function() UpdateColumnLayout() end)

    local dataTable = {
        container = container,
        inner = inner,
        headerRow = headerRow,
        scrollFrame = scrollFrame,
        scrollContent = scrollContent,
        scrollTrack = scrollTrack,
        scrollThumb = scrollThumb,
        state = state,
        UpdateColumnLayout = UpdateColumnLayout,
        UpdateSortIndicators = UpdateSortIndicators,
        UpdateScrollThumb = UpdateScrollThumb,
    }

    function dataTable:SetColumns(newColumns)
        columns = newColumns
        headerRow.columns = newColumns
    end

    function dataTable:GetSortState()
        return state.sortColumn, state.sortAscending
    end

    function dataTable:SetSortState(column, ascending)
        state.sortColumn = column
        state.sortAscending = ascending
        UpdateSortIndicators()
    end

    function dataTable:RegisterRow(row)
        table.insert(state.rows, row)
    end

    function dataTable:ClearRows()
        state.rows = {}
    end

    function dataTable:GetColumnLayout()
        local layout = {}
        for i, btn in ipairs(headerRow.columnButtons) do
            layout[i] = { width = btn.columnWidth, x = btn.columnX }
        end
        return layout
    end

    return dataTable
end

local _dataRowCount = 0

function OneWoW_GUI:ClearDataRows(scrollContent)
    if not scrollContent or not scrollContent._dataRows then return end
    for _, row in ipairs(scrollContent._dataRows) do
        if row.expandedFrame then
            row.expandedFrame:Hide()
            row.expandedFrame = nil
        end
        row:Hide()
        row:SetParent(nil)
    end
    wipe(scrollContent._dataRows)
end

function OneWoW_GUI:LayoutDataRows(scrollContent, options)
    if not scrollContent or not scrollContent._dataRows then return end
    options = options or {}
    local rowHeight = options.rowHeight or 32
    local rowGap = options.rowGap or 2
    local topPadding = options.topPadding or 5

    local yOffset = -topPadding
    for _, row in ipairs(scrollContent._dataRows) do
        if row:IsShown() then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
            row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
            yOffset = yOffset - (rowHeight + rowGap)

            if row.isExpanded and row.expandedFrame and row.expandedFrame:IsShown() then
                row.expandedFrame:ClearAllPoints()
                row.expandedFrame:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -2)
                row.expandedFrame:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -2)
                yOffset = yOffset - (row.expandedFrame:GetHeight() + rowGap)
            end
        end
    end

    local totalHeight = math.abs(yOffset) + 50
    scrollContent:SetHeight(totalHeight)
end

function OneWoW_GUI:CreateDataRow(scrollContent, options)
    options = options or {}
    local rowHeight = options.rowHeight or 32
    local expandedHeight = options.expandedHeight or 160
    local rowGap = options.rowGap or 2
    local expandable = options.expandable ~= false
    local createDetails = options.createDetails
    local onRowEnter = options.onEnter
    local onRowLeave = options.onLeave

    _dataRowCount = _dataRowCount + 1

    local bgR, bgG, bgB = GetThemeColor("BG_TERTIARY")
    local hoverR, hoverG, hoverB = GetThemeColor("BG_HOVER")

    local row = CreateFrame("Frame", nil, scrollContent)
    row:SetHeight(rowHeight)
    row.cells = {}
    row.data = options.data
    row.isExpanded = false

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetColorTexture(bgR, bgG, bgB, 0.6)
    row.bg = bg

    row:EnableMouse(true)

    local expandBtn, expandIcon
    if expandable then
        expandBtn = CreateFrame("Button", nil, row)
        expandBtn:SetSize(25, rowHeight)
        expandIcon = expandBtn:CreateTexture(nil, "ARTWORK")
        expandIcon:SetSize(14, 14)
        expandIcon:SetPoint("CENTER")
        expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
        expandBtn.icon = expandIcon
        table.insert(row.cells, expandBtn)
    end

    local function ToggleExpanded()
        row.isExpanded = not row.isExpanded

        if row.isExpanded then
            if expandIcon then expandIcon:SetAtlas("Gamepad_Rev_Minus_64") end
            if not row.expandedFrame then
                local detBgR, detBgG, detBgB = GetThemeColor("BG_SECONDARY")

                row.expandedFrame = CreateFrame("Frame", nil, scrollContent)
                row.expandedFrame:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -2)
                row.expandedFrame:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -2)
                row.expandedFrame:SetHeight(expandedHeight)

                local detBg = row.expandedFrame:CreateTexture(nil, "BACKGROUND")
                detBg:SetAllPoints(row.expandedFrame)
                detBg:SetColorTexture(detBgR, detBgG, detBgB, 0.7)
                row.expandedFrame.bg = detBg

                if createDetails then
                    createDetails(row.expandedFrame, row.data)
                end
            end
            row.expandedFrame:Show()
        else
            if expandIcon then expandIcon:SetAtlas("Gamepad_Rev_Plus_64") end
            if row.expandedFrame then
                row.expandedFrame:Hide()
            end
        end

        OneWoW_GUI:LayoutDataRows(scrollContent, {
            rowHeight = rowHeight,
            rowGap = rowGap,
        })
    end

    if expandable and expandBtn then
        expandBtn:SetScript("OnClick", ToggleExpanded)
    end

    row:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and expandable then
            ToggleExpanded()
        end
    end)

    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(hoverR, hoverG, hoverB, 0.8)
        if onRowEnter then onRowEnter(self) end
    end)

    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(bgR, bgG, bgB, 0.6)
        if onRowLeave then onRowLeave(self) end
    end)

    if not scrollContent._dataRows then
        scrollContent._dataRows = {}
    end
    table.insert(scrollContent._dataRows, row)

    return row, expandBtn, expandIcon
end

function OneWoW_GUI:CreateOverviewPanel(parent, options)
    options = options or {}
    local title = options.title or ""
    local height = options.height or 110
    local stats = options.stats or {}
    local numCols = options.columns or 5

    local numRows = math.ceil(#stats / numCols)

    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)
    panel:SetHeight(height)
    panel:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    panel:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
    panel:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))

    local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -6)
    titleFS:SetText(title)
    titleFS:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))

    local statsContainer = CreateFrame("Frame", nil, panel)
    statsContainer:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -8)
    statsContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 6)

    local statBoxes = {}

    for i = 1, #stats do
        local stat = stats[i]

        local statBox = CreateFrame("Frame", nil, statsContainer, "BackdropTemplate")
        statBox:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        statBox:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
        statBox:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))

        local label = statBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOP", statBox, "TOP", 0, -5)
        label:SetText(stat.label or "")
        label:SetTextColor(GetThemeColor("TEXT_SECONDARY"))

        local value = statBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("BOTTOM", statBox, "BOTTOM", 0, 6)
        value:SetText(stat.value or "0")
        value:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

        statBox.label = label
        statBox.value = value

        statBox:EnableMouse(true)
        statBox:SetScript("OnEnter", function(self)
            self:SetBackdropColor(GetThemeColor("BG_HOVER"))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(stat.ttTitle or "", 1, 1, 1)
            GameTooltip:AddLine(stat.ttDesc or "", nil, nil, nil, true)
            if self.extraTooltipLines and #self.extraTooltipLines > 0 then
                GameTooltip:AddLine(" ")
                for _, line in ipairs(self.extraTooltipLines) do
                    GameTooltip:AddLine(line.text, line.r or 0.8, line.g or 0.8, line.b or 0.8, line.wrap)
                end
            end
            GameTooltip:Show()
        end)
        statBox:SetScript("OnLeave", function(self)
            self:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
            GameTooltip:Hide()
        end)

        table.insert(statBoxes, statBox)
    end

    statsContainer:SetScript("OnSizeChanged", function(self, width, height)
        local boxWidth = (width - (numCols + 1) * 3) / numCols
        local boxHeight = (height - (numRows + 1) * 3) / numRows

        for i, box in ipairs(statBoxes) do
            local r = math.ceil(i / numCols)
            local c = ((i - 1) % numCols) + 1

            local x = 3 + (c - 1) * (boxWidth + 3)
            local y = -3 - (r - 1) * (boxHeight + 3)

            box:SetSize(boxWidth, boxHeight)
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
        end
    end)

    return {
        panel = panel,
        title = titleFS,
        statsContainer = statsContainer,
        statBoxes = statBoxes,
    }
end

function OneWoW_GUI:CreateStatusBar(parent, anchorFrame, options)
    options = options or {}
    local anchorPoint = options.anchorPoint or "BELOW"
    local initialText = options.text or ""

    local statusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if anchorPoint == "BOTTOM" then
        statusBar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 5, 5)
        statusBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 5)
    else
        statusBar:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -5)
        statusBar:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -5)
    end
    statusBar:SetHeight(25)
    statusBar:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    statusBar:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
    statusBar:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))

    local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", statusBar, "LEFT", 10, 0)
    statusText:SetText(initialText)
    statusText:SetTextColor(GetThemeColor("TEXT_SECONDARY"))

    return {
        bar = statusBar,
        text = statusText,
    }
end

function OneWoW_GUI:CreateRosterPanel(parent, anchorFrame)
    local rosterPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rosterPanel:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -8)
    rosterPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 30)
    rosterPanel:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    rosterPanel:SetBackdropColor(GetThemeColor("BG_PRIMARY"))
    rosterPanel:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))

    return rosterPanel
end

function OneWoW_GUI:CreateItemIcon(parent, options)
    options = options or {}
    local size = options.size or 48
    local showIlvl = options.showIlvl ~= false
    local itemLink = options.itemLink
    local itemID = options.itemID
    local quality = options.quality or 1
    local itemLevel = options.itemLevel
    local iconTexture = options.iconTexture

    local QUALITY_COLORS = {
        [0] = {0.6, 0.6, 0.6, 1},
        [1] = {1, 1, 1, 1},
        [2] = {0.12, 1, 0, 1},
        [3] = {0, 0.44, 0.87, 1},
        [4] = {0.64, 0.21, 0.93, 1},
        [5] = {1, 0.5, 0, 1},
        [6] = {0.9, 0.8, 0.5, 1},
        [7] = {0.41, 0.8, 0.94, 1},
    }

    local iconFrame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    iconFrame:SetSize(size, size)

    local tex = iconFrame:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints(iconFrame)

    if iconTexture then
        tex:SetTexture(iconTexture)
    elseif itemID and GetItemIcon then
        local icon = GetItemIcon(itemID)
        tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    else
        tex:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    end

    local borderFrame = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
    borderFrame:SetAllPoints(iconFrame)
    borderFrame:SetFrameLevel(iconFrame:GetFrameLevel() + 1)

    local color = QUALITY_COLORS[quality] or QUALITY_COLORS[1]
    if itemLink or itemID then
        borderFrame:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        borderFrame:SetBackdropBorderColor(color[1], color[2], color[3], color[4])
    else
        borderFrame:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        borderFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    end

    local ilvlText = nil
    if showIlvl then
        ilvlText = iconFrame:CreateFontString(nil, "OVERLAY")
        ilvlText:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
        ilvlText:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2, 2)
        ilvlText:SetTextColor(1, 1, 1, 1)
        ilvlText:SetShadowColor(0, 0, 0, 1)
        ilvlText:SetShadowOffset(1, -1)

        if itemLevel and itemLevel > 0 then
            ilvlText:SetText(tostring(itemLevel))
        else
            ilvlText:SetText("")
        end
    end

    if itemLink then
        iconFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()
        end)
        iconFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end

    return {
        frame = iconFrame,
        texture = tex,
        border = borderFrame,
        ilvlText = ilvlText,
    }
end

function OneWoW_GUI:CreateFactionIcon(parent, faction, size)
    size = size or 18
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetPoint("CENTER")
    if faction == "Alliance" then
        icon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
    elseif faction == "Horde" then
        icon:SetTexture("Interface\\FriendsFrame\\PlusManz-Horde")
    else
        icon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
        icon:SetDesaturated(true)
    end
    frame.icon = icon
    return frame
end

function OneWoW_GUI:CreateMailIcon(parent, hasMail, size)
    size = size or 16
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
    if hasMail then
        icon:SetVertexColor(1, 1, 0, 1)
    else
        icon:SetVertexColor(0.3, 0.3, 0.3, 0.5)
    end
    frame.icon = icon
    return frame
end

function OneWoW_GUI:CreateExpandedPanelGrid(ef, options)
    options = options or {}
    local gap = options.gap or 8
    local inset = options.inset or 4
    local lineHeight = options.lineHeight or 14
    local minRows = options.minRows or 5
    local maxRows = options.maxRows or 50

    local panels = {}

    local grid = {
        ef = ef,
        panels = panels,
    }

    function grid:AddPanel(title)
        local p = CreateFrame("Frame", nil, ef, "BackdropTemplate")
        p:SetPoint("TOPLEFT", ef, "TOPLEFT", inset, -inset)
        p:SetPoint("BOTTOMLEFT", ef, "BOTTOMLEFT", inset, inset)
        p:SetWidth(100)
        p:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        p:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        p:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        local titleFS = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        titleFS:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -5)
        titleFS:SetText(title)
        titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        p.titleFS = titleFS
        p.dy = -18
        table.insert(panels, p)
        return p
    end

    function grid:AddLine(panel, a1, a2, a3)
        local text, color
        if type(a2) == "string" then
            text = a1 .. " " .. a2
            color = a3
        else
            text = a1
            color = a2
        end

        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, panel.dy)
        fs:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, panel.dy)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        if color then
            if type(color) == "table" then
                fs:SetTextColor(unpack(color))
            else
                fs:SetTextColor(color)
            end
        else
            fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        panel.dy = panel.dy - lineHeight
        return fs
    end

    function grid:Finish()
        local maxLines = 0
        for _, p in ipairs(panels) do
            local lineCount = math.floor((math.abs(p.dy) - 18) / lineHeight) + 1
            if lineCount > maxLines then maxLines = lineCount end
        end
        local clampedLines = math.max(minRows, math.min(maxRows, maxLines))
        local dynamicHeight = 18 + (clampedLines * lineHeight) + 12
        ef:SetHeight(dynamicHeight)

        local function LayoutPanels()
            local w = ef:GetWidth()
            if w <= 10 then return end
            local numPanels = #panels
            if numPanels == 0 then return end
            local panelWidth = (w - gap * (numPanels + 1)) / numPanels
            for i, p in ipairs(panels) do
                p:ClearAllPoints()
                local xOff = gap + (i - 1) * (panelWidth + gap)
                p:SetPoint("TOPLEFT", ef, "TOPLEFT", xOff, -inset)
                p:SetPoint("BOTTOMLEFT", ef, "BOTTOMLEFT", xOff, inset)
                p:SetWidth(panelWidth)
            end
        end

        ef:SetScript("OnSizeChanged", function() LayoutPanels() end)
        C_Timer.After(0.05, function() LayoutPanels() end)

        return dynamicHeight
    end

    return grid
end
