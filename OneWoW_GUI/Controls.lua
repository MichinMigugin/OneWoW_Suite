local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local CreateFrame = CreateFrame
local unpack = unpack
local tinsert = tinsert

local Constants = OneWoW_GUI.Constants
local noop = OneWoW_GUI.noop

local _dropdownMenuCount = 0
local _activeDropdownMenu = nil
local _activeDropdownOverlay = nil

function OneWoW_GUI:CreateToggleRow(parent, options)
    options = options or {}
    local yOffset = options.yOffset or 0
    local label = options.label or ""
    local description = options.description
    local createContent = options.createContent
    local value = options.value
    local isEnabled = options.isEnabled
    local onValueChange = options.onValueChange
    local onLabel = options.onLabel or "On"
    local offLabel = options.offLabel or "Off"
    local buttonWidth = options.buttonWidth or Constants.GUI.TOGGLE_BUTTON_WIDTH
    local buttonHeight = options.buttonHeight or Constants.GUI.TOGGLE_BUTTON_HEIGHT
    local alignLeft = (options.align == "left")

    local labelFs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelFs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    labelFs:SetJustifyH("LEFT")
    labelFs:SetText(label)
    if label == "" then
        labelFs:Hide()
    end

    local onBtn, offBtn, refresh, statusPfx, statusVal = self:CreateOnOffToggleButtons(parent, {
        yOffset = yOffset,
        onLabel = onLabel,
        offLabel = offLabel,
        width = buttonWidth,
        height = buttonHeight,
        isEnabled = isEnabled,
        value = value,
        onValueChange = onValueChange,
    })

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
        descFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
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

    return newYOffset, rowRefresh, { label = labelFs, contentArea = contentArea }
end

function OneWoW_GUI:CreateCheckbox(parent, options)
    options = options or {}
    local name = options.name
    local label = options.label or ""
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetSize(Constants.GUI.CHECKBOX_SIZE, Constants.GUI.CHECKBOX_SIZE)

    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.label:SetPoint("LEFT", cb, "RIGHT", OneWoW_GUI:GetSpacing("XS"), 0)
    cb.label:SetText(label)
    cb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    return cb
end

function OneWoW_GUI:CreateDropdown(parent, options)
    options = options or {}
    local width = options.width or 200
    local height = options.height or 26
    local defaultText = options.text or ""

    local dropdown = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dropdown:SetSize(width, height)
    dropdown:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    dropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    dropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    text:SetPoint("RIGHT", dropdown, "RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(defaultText)
    text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local arrow = dropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -4, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    dropdown:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)
    dropdown:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    dropdown._text = text
    dropdown._activeValue = nil

    return dropdown, text
end

function OneWoW_GUI:AttachFilterMenu(dropdown, options)
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

        if _activeDropdownMenu and _activeDropdownMenu:IsShown() then
            _activeDropdownMenu:Hide()
        end
        if _activeDropdownOverlay and _activeDropdownOverlay:IsShown() then
            _activeDropdownOverlay:Hide()
        end

        local items = buildItems and buildItems() or {}

        _dropdownMenuCount = _dropdownMenuCount + 1
        local uid = _dropdownMenuCount

        local overlay = CreateFrame("Button", nil, UIParent)
        overlay:SetAllPoints(UIParent)
        overlay:SetFrameStrata("FULLSCREEN_DIALOG")
        overlay:SetFrameLevel(0)
        overlay:EnableMouse(true)
        overlay:RegisterForClicks("AnyDown", "AnyUp")

        local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        self._menu = menu
        _activeDropdownMenu = menu
        _activeDropdownOverlay = overlay
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(10)
        menu:SetClampedToScreen(true)
        menu:SetSize(self:GetWidth() + 20, menuHeight)

        local screenH = UIParent:GetHeight()
        local dropdownBottom = self:GetBottom() or 0
        local spaceBelow = dropdownBottom
        local spaceAbove = screenH - (self:GetTop() or screenH)
        local openUpward = spaceBelow < menuHeight and spaceAbove > spaceBelow

        if openUpward then
            menu:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2)
        else
            menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        end

        menu:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        menu:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        menu:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        menu:EnableMouse(true)

        overlay:SetScript("OnClick", function()
            menu:Hide()
        end)
        menu:SetScript("OnHide", function()
            overlay:Hide()
        end)

        local searchBox
        local contentTopY = -2

        if searchable then
            searchBox = CreateFrame("EditBox", nil, menu, "BackdropTemplate")
            searchBox:SetSize(menu:GetWidth() - 15, 28)
            searchBox:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
            searchBox:SetBackdrop(Constants.BACKDROP_INNER)
            searchBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            searchBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            searchBox:SetFontObject(GameFontHighlight)
            searchBox:SetTextInsets(8, 8, 0, 0)
            searchBox:SetAutoFocus(false)
            searchBox:SetMaxLetters(50)
            searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            searchBox:SetScript("OnEditFocusGained", function(s)
                s:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            end)
            searchBox:SetScript("OnEditFocusLost", function(s)
                s:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end)

            local separator = menu:CreateTexture(nil, "ARTWORK")
            separator:SetSize(menu:GetWidth() - 4, 1)
            separator:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -32)
            separator:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

            contentTopY = -36
        end

        local scrollContainer = CreateFrame("Frame", nil, menu)
        scrollContainer:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, contentTopY)
        scrollContainer:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -2, 2)

        local scrollFrame = CreateFrame("ScrollFrame", "OneWoWGUI_DropMenu_" .. uid, scrollContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", 0, 0)
        scrollFrame:EnableMouseWheel(true)

        OneWoW_GUI:StyleScrollBar(scrollFrame, { container = scrollContainer, offset = -2 })

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
                header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                tinsert(elements, { frame = header, type = "header", height = 24 })

            elseif itemType == "divider" then
                local divider = scrollChild:CreateTexture(nil, "ARTWORK")
                divider:SetHeight(1)
                divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                tinsert(elements, { frame = divider, type = "divider", height = 10 })

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
                label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

                row:SetScript("OnEnter", function(r)
                    r:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                end)
                row:SetScript("OnLeave", function(r)
                    r:SetBackdropColor(0, 0, 0, 0)
                    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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
                tinsert(elements, { frame = row, type = "checkbox", height = 26 })

            else
                local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                btn:SetSize(scrollChild:GetWidth() or (menu:GetWidth() - 20), 26)
                btn:SetBackdrop(Constants.BACKDROP_SIMPLE)

                if activeValue == item.value then
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                else
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                end

                local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                txt:SetPoint("LEFT", btn, "LEFT", 8, 0)
                txt:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
                txt:SetJustifyH("LEFT")
                txt:SetText(item.text)
                txt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

                btn:SetScript("OnEnter", function(b)
                    if activeValue ~= item.value then
                        b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                        txt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                    end
                    if item.onEnter then item.onEnter(b) end
                end)
                btn:SetScript("OnLeave", function(b)
                    if activeValue ~= item.value then
                        b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                        txt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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
                tinsert(elements, { frame = btn, type = "item", height = 28, filterKey = btn.filterKey })
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

        local contentHeight = scrollChild:GetHeight() or 28
        local searchHeight = searchable and 36 or 0
        local dynamicHeight = contentHeight + searchHeight + 6
        local finalHeight = math.min(dynamicHeight, menuHeight)
        finalHeight = math.max(finalHeight, 40)
        menu:SetHeight(finalHeight)

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

        menu:Show()
        if searchBox then
            searchBox:SetFocus()
        end
    end)
end

function OneWoW_GUI:CreateSlider(parent, options)
    options = options or {}
    local minVal = options.minVal or 0
    local maxVal = options.maxVal or 100
    local step = options.step or 1
    local currentVal = options.currentVal or minVal
    local onChange = options.onChange or noop
    local width = options.width or 200
    local fmt = options.fmt or "%.1f"
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 36)

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
    valLabel:SetText(string.format(fmt, currentVal))
    valLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    if slider.Low  then slider.Low:SetText(tostring(minVal)) end
    if slider.High then slider.High:SetText(tostring(maxVal)) end
    if slider.Text then slider.Text:SetText("") end

    slider:SetScript("OnValueChanged", function(self, val)
        local rounded = math.floor(val / step + 0.5) * step
        rounded = math.max(minVal, math.min(maxVal, rounded))
        valLabel:SetText(string.format(fmt, rounded))
        onChange(rounded)
    end)

    return container
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
