-- ============================================================================
-- QoL single-state On/Off toggle (phase 2 prototype)
-- ============================================================================
-- Temporary Features/AutoMount control while validating look/feel. Phase 3 moves
-- this into OneWoW_GUI:CreateOnOffToggleButtons / CreateToggleRow and deletes
-- this file.
--
-- Option 2 coloring: On = soft green fill + green label; Off = muted chrome +
-- red label; parent-disabled = fully muted / non-interactive.
-- ============================================================================

local _, ns = ...
local L = ns.L
local OneWoW_GUI = OneWoW_GUI

ns.UI = ns.UI or {}

local Constants = OneWoW_GUI.Constants

--- Soft fill from DOT_FEATURES_ENABLED (avoid neon TEXT_FEATURES_* as backdrop).
local function SoftEnabledFill(alpha)
    local r, g, b = OneWoW_GUI:GetThemeColor("DOT_FEATURES_ENABLED")
    return r, g, b, alpha
end

---@param parent Frame
---@param options {
---  onLabel?: string,
---  offLabel?: string,
---  width?: number,
---  height?: number,
---  isEnabled?: boolean,
---  value?: boolean,
---  onValueChange?: fun(newValue: boolean),
---  clickTooltipFormat?: string,
--- }
---@return Button btn
---@return fun(enabled: boolean, value: boolean) refresh
function ns.UI.CreateSingleStateToggle(parent, options)
    options = options or {}
    local onLabel = options.onLabel or L["FEATURES_ON"]
    local offLabel = options.offLabel or L["FEATURES_OFF"]
    local width = options.width or Constants.GUI.TOGGLE_BUTTON_WIDTH
    local height = options.height or Constants.GUI.TOGGLE_BUTTON_HEIGHT
    local isEnabled = options.isEnabled
    local value = options.value
    local onValueChange = options.onValueChange
    local clickFmt = options.clickTooltipFormat or L["FEATURES_TOGGLE_CLICK"]

    local btn = OneWoW_GUI:CreateFitTextButton(parent, {
        text = onLabel,
        height = height,
        minWidth = width,
    })

    -- Size to the wider of On/Off so the control does not jump when toggled.
    local wOn = btn:GetWidth()
    btn:SetFitText(offLabel)
    local wOff = btn:GetWidth()
    local maxW = math.max(wOn, wOff)
    btn._minWidth = maxW
    btn:SetWidth(maxW)

    local currentValue = value == true

    local function applyNormal()
        if not btn:GetParent() then return end
        if isEnabled ~= true then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            return
        end
        if currentValue then
            btn:SetBackdropColor(SoftEnabledFill(0.40))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("DOT_FEATURES_ENABLED"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end
    end

    local function applyHover()
        if not btn:GetParent() or isEnabled ~= true then return end
        if currentValue then
            btn:SetBackdropColor(SoftEnabledFill(0.55))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end
    end

    local function refresh(enabled, val)
        isEnabled = enabled
        currentValue = val == true
        if not btn:GetParent() then return end
        btn:EnableMouse(enabled == true)
        btn:SetFitText(currentValue and onLabel or offLabel)
        if btn:IsMouseOver() and enabled == true then
            applyHover()
        else
            applyNormal()
        end
    end

    btn:SetScript("OnEnter", function(myself)
        applyHover()
        if isEnabled ~= true then return end
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        local nextLabel = currentValue and offLabel or onLabel
        GameTooltip:SetText(string.format(clickFmt, nextLabel), 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        applyNormal()
        GameTooltip:Hide()
    end)
    btn:SetScript("OnMouseDown", function(myself)
        if isEnabled ~= true then return end
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
    end)
    btn:SetScript("OnMouseUp", function(myself)
        if myself:IsMouseOver() and isEnabled == true then
            applyHover()
        else
            applyNormal()
        end
    end)
    btn:SetScript("OnClick", function()
        if isEnabled ~= true or not onValueChange then return end
        local newVal = not currentValue
        onValueChange(newVal)
        refresh(isEnabled, newVal)
        C_Timer.After(0, function()
            if btn:GetParent() and btn:IsMouseOver() and isEnabled == true then
                applyHover()
                GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                local nextLabel = currentValue and offLabel or onLabel
                GameTooltip:SetText(string.format(clickFmt, nextLabel), 1, 1, 1)
                GameTooltip:Show()
            end
        end)
    end)

    refresh(isEnabled, value)
    return btn, refresh
end

--- Row wrapper matching CreateToggleRow's layout contract for Features/AutoMount.
---@param parent Frame
---@param options table same shape as CreateToggleRow, plus clickTooltipFormat
---@return number newYOffset
---@return fun(enabled: boolean, value: boolean) rowRefresh
---@return { label: FontString, contentArea: Frame|nil, button: Button }
function ns.UI.CreateSingleStateToggleRow(parent, options)
    options = options or {}
    local yOffset = options.yOffset or 0
    local label = options.label or ""
    local description = options.description
    local createContent = options.createContent
    local value = options.value
    local isEnabled = options.isEnabled
    local onValueChange = options.onValueChange
    local onLabel = options.onLabel or L["FEATURES_ON"]
    local offLabel = options.offLabel or L["FEATURES_OFF"]
    local buttonWidth = options.buttonWidth or Constants.GUI.TOGGLE_BUTTON_WIDTH
    local buttonHeight = options.buttonHeight or Constants.GUI.TOGGLE_BUTTON_HEIGHT
    local alignLeft = (options.align == "left")

    local labelFs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SetFontBaseSize(labelFs, 12)
    OneWoW_GUI:SafeSetFont(labelFs, OneWoW_GUI:GetFont(), 12)
    labelFs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    labelFs:SetJustifyH("LEFT")
    labelFs:SetText(label)
    if label == "" then
        labelFs:Hide()
    end

    local btn, refresh = ns.UI.CreateSingleStateToggle(parent, {
        onLabel = onLabel,
        offLabel = offLabel,
        width = buttonWidth,
        height = buttonHeight,
        isEnabled = isEnabled,
        value = value,
        onValueChange = onValueChange,
        clickTooltipFormat = options.clickTooltipFormat,
    })

    if alignLeft then
        if label ~= "" then
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", labelFs, "RIGHT", 8, 0)
        else
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
        end
    else
        btn:ClearAllPoints()
        btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
        if label ~= "" then
            labelFs:SetPoint("RIGHT", btn, "LEFT", -8, 0)
        end
    end

    local labelHeight = (label ~= "" and labelFs:GetStringHeight()) or 0
    local rowHeight = math.max(buttonHeight, labelHeight)
    local newYOffset = yOffset - rowHeight - 4

    local descFs
    local contentArea

    if description then
        descFs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        OneWoW_GUI:SetFontBaseSize(descFs, 10)
        OneWoW_GUI:SafeSetFont(descFs, OneWoW_GUI:GetFont(), 10)
        descFs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, newYOffset)
        descFs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, newYOffset)
        descFs:SetJustifyH("LEFT")
        descFs:SetWordWrap(true)
        local parentW = parent:GetWidth()
        local wrapW = (parentW and parentW > Constants.GUI.TOGGLE_ROW_DESC_WRAP_MIN)
            and (parentW - 24)
            or Constants.GUI.TOGGLE_ROW_DESC_WRAP_FALLBACK
        descFs:SetWidth(wrapW)
        descFs:SetText(description)
        descFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        newYOffset = newYOffset - descFs:GetStringHeight() - 6
    elseif createContent then
        contentArea = CreateFrame("Frame", nil, parent)
        contentArea:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, newYOffset)
        contentArea:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, newYOffset)
        local _, contentHeight = createContent(contentArea)
        contentHeight = contentHeight or 0
        contentArea:SetHeight(contentHeight)
        newYOffset = newYOffset - contentHeight - 6
    end

    newYOffset = newYOffset - 10

    local function rowRefresh(enabled, val)
        refresh(enabled, val)
        if enabled then
            labelFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            if descFs then
                descFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        else
            labelFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            if descFs then
                descFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        end
    end

    rowRefresh(isEnabled, value)

    return newYOffset, rowRefresh, { label = labelFs, contentArea = contentArea, button = btn }
end
