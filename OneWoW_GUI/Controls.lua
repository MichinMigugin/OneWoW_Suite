local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local CreateFrame = CreateFrame
local IsMouseButtonDown = IsMouseButtonDown
local unpack = unpack
local tinsert = tinsert

local Constants = OneWoW_GUI.Constants
local noop = OneWoW_GUI.noop

local _dropdownMenuCount = 0
local _activeDropdownMenu = nil
local _activeDropdownOverlay = nil

--- Dismiss the open AttachFilterMenu popup (menu + overlay). Menus auto-dismiss via OnUpdate when the user
--- clicks outside their bounds; call this for programmatic teardown (e.g. before reparenting).
function OneWoW_GUI:CloseAttachFilterMenu()
    if _activeDropdownMenu then
        _activeDropdownMenu:Hide()
    elseif _activeDropdownOverlay then
        _activeDropdownOverlay:Hide()
    end
    _activeDropdownMenu = nil
    _activeDropdownOverlay = nil
end

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
    OneWoW_GUI:SafeSetFont(labelFs, OneWoW_GUI:GetFont(), 12)
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
        OneWoW_GUI:SafeSetFont(descFs, OneWoW_GUI:GetFont(), 10)
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
    local checked = options.checked
    local onClick = options.onClick
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetSize(Constants.GUI.CHECKBOX_SIZE, Constants.GUI.CHECKBOX_SIZE)
    cb:SetChecked(checked and true or false)

    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SafeSetFont(cb.label, OneWoW_GUI:GetFont(), 12)
    cb.label:SetPoint("LEFT", cb, "RIGHT", OneWoW_GUI:GetSpacing("XS"), 0)
    cb.label:SetText(label)
    cb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    if type(onClick) == "function" then
        cb:SetScript("OnClick", onClick)
    end

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
    OneWoW_GUI:SafeSetFont(text, OneWoW_GUI:GetFont(), 10)
    text:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 8, -2)
    text:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -20, 2)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetText(defaultText)
    text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local arrow = dropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("CENTER", dropdown, "RIGHT", -10, 0)
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

        -- Only one AttachFilterMenu may be open: hide previous menu+overlay and clear globals (avoids orphan overlays if strata/order prevented a clean hide).
        if _activeDropdownMenu then
            _activeDropdownMenu:Hide()
        end
        if _activeDropdownOverlay then
            _activeDropdownOverlay:Hide()
        end
        _activeDropdownMenu = nil
        _activeDropdownOverlay = nil

        local items = buildItems and buildItems() or {}

        _dropdownMenuCount = _dropdownMenuCount + 1
        local uid = _dropdownMenuCount

        -- Walk up to the top-level frame under UIParent (e.g. DevTool window). The overlay sits BELOW
        -- the host so it only blocks game-world clicks; in-host dismiss is handled by the menu's OnUpdate.
        -- Host OnHide hook handles ESC key close (menu is a UIParent child, won't hide with host).
        local host = self
        while host:GetParent() and host:GetParent() ~= UIParent do
            host = host:GetParent()
        end
        if not host._oneWoWFilterMenuOnHide then
            host._oneWoWFilterMenuOnHide = true
            host:HookScript("OnHide", function()
                OneWoW_GUI:CloseAttachFilterMenu()
            end)
        end
        local hostStrata = host:GetFrameStrata()
        local hostLevel = host:GetFrameLevel() or 0

        -- Use a higher stratum for the menu so it stays visible above toplevel host windows.
        local menuStrata = hostStrata
        if hostStrata == "BACKGROUND" or hostStrata == "LOW" or hostStrata == "MEDIUM" or hostStrata == "HIGH" then
            menuStrata = "DIALOG"
        end
        local menuLevel = (menuStrata ~= hostStrata) and 100 or math.max(100, hostLevel + 40)

        local overlay = CreateFrame("Button", "OneWoWGUI_DropOverlay_" .. uid, UIParent)
        overlay:SetAllPoints(UIParent)
        overlay:SetFrameStrata(hostStrata)
        overlay:SetFrameLevel(math.max(0, hostLevel - 2))
        overlay:SetToplevel(true)
        overlay:EnableMouse(true)
        overlay:RegisterForClicks("AnyDown", "AnyUp")

        local menu = CreateFrame("Frame", "OneWoWGUI_DropMenuFrame_" .. uid, UIParent, "BackdropTemplate")
        self._menu = menu
        _activeDropdownMenu = menu
        _activeDropdownOverlay = overlay
        menu._ownerDropdown = self
        menu._boundOverlay = overlay
        menu:SetFrameStrata(menuStrata)
        menu:SetFrameLevel(menuLevel)
        menu:SetToplevel(true)
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

        -- Dismiss on any mouse-down outside the menu's bounds. Input (OnClick on controls)
        -- is processed before OnUpdate, so the clicked control fires first, then the menu
        -- closes in the same frame — single click, no consumed events.
        local wasDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
        menu:SetScript("OnUpdate", function(self)
            local isDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
            if isDown and not wasDown then
                if not self:IsMouseOver() then
                    self:Hide()
                end
            end
            wasDown = isDown
        end)

        overlay:SetScript("OnClick", function()
            menu:Hide()
        end)
        menu:SetScript("OnHide", function(m)
            local ov = m._boundOverlay
            if ov then
                ov:Hide()
            end
            if m._ownerDropdown and m._ownerDropdown._menu == m then
                m._ownerDropdown._menu = nil
            end
            if _activeDropdownMenu == m then
                _activeDropdownMenu = nil
            end
            if ov and _activeDropdownOverlay == ov then
                _activeDropdownOverlay = nil
            end
        end)

        local searchBox
        local contentTopY = -2

        if searchable then
            searchBox = CreateFrame("EditBox", "OneWoWGUI_DropSearchBox_" .. uid, menu, "BackdropTemplate")
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

        local scrollContainer = CreateFrame("Frame", "OneWoWGUI_DropScrollContainer_" .. uid, menu)
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
        local elemIdx = 0

        for _, item in ipairs(items) do
            elemIdx = elemIdx + 1
            local itemType = item.type or "item"

            if itemType == "header" then
                local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                OneWoW_GUI:SafeSetFont(header, OneWoW_GUI:GetFont(), 12)
                header:SetText(item.text)
                header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                tinsert(elements, { frame = header, type = "header", height = 24 })

            elseif itemType == "divider" then
                local divider = scrollChild:CreateTexture(nil, "ARTWORK")
                divider:SetHeight(1)
                divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                tinsert(elements, { frame = divider, type = "divider", height = 10 })

            elseif itemType == "checkbox" then
                local row = CreateFrame("Button", "OneWoWGUI_DropItem_" .. uid .. "_" .. elemIdx, scrollChild, "BackdropTemplate")
                row:SetHeight(26)
                row:SetBackdrop(Constants.BACKDROP_SIMPLE)
                row:SetBackdropColor(0, 0, 0, 0)

                local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                cb:SetSize(18, 18)
                cb:SetPoint("LEFT", row, "LEFT", 4, 0)
                cb:SetChecked(item.checked or false)

                local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                OneWoW_GUI:SafeSetFont(label, OneWoW_GUI:GetFont(), 12)
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
                local btn = CreateFrame("Button", "OneWoWGUI_DropItem_" .. uid .. "_" .. elemIdx, scrollChild, "BackdropTemplate")
                btn:SetSize(scrollChild:GetWidth() or (menu:GetWidth() - 20), 26)
                btn:SetBackdrop(Constants.BACKDROP_SIMPLE)

                if activeValue == item.value then
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                else
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                end

                local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                OneWoW_GUI:SafeSetFont(txt, OneWoW_GUI:GetFont(), 10)
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
            local actualHeight = math.max(1, math.abs(yPos))
            scrollChild:SetHeight(actualHeight)
            return actualHeight
        end

        local contentHeight = renderList("")
        local dynamicHeight = contentHeight + math.abs(contentTopY) + 2
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
        menu:Raise()
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
    OneWoW_GUI:SafeSetFont(valLabel, OneWoW_GUI:GetFont(), 12)
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

function OneWoW_GUI:CreateColorSwatch(parent, options)
    options = options or {}
    local size = options.size or 24
    local getColor = options.getColor
    local onColorChanged = options.onColorChanged
    local hasOpacity = options.hasOpacity or false
    local getOpacity = options.getOpacity
    local onOpacityChanged = options.onOpacityChanged

    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetSize(size, size)
    swatch:SetBackdrop(Constants.BACKDROP_SOFT)
    swatch:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local function refresh()
        if getColor then
            local r, g, b = getColor()
            swatch:SetBackdropColor(r, g, b, 1)
        end
    end
    refresh()

    swatch:SetScript("OnClick", function()
        local r, g, b = 1, 1, 1
        if getColor then
            r, g, b = getColor()
        end
        local info = {
            r = r, g = g, b = b,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                if onColorChanged then
                    onColorChanged(nr, ng, nb)
                end
                refresh()
            end,
            cancelFunc = function(prev)
                if prev and onColorChanged then
                    onColorChanged(prev.r, prev.g, prev.b)
                    refresh()
                end
            end,
        }
        if hasOpacity then
            info.hasOpacity = true
            if getOpacity then
                info.opacity = getOpacity()
            end
            info.opacityFunc = function()
                local a = ColorPickerFrame:GetColorAlpha()
                if onOpacityChanged then
                    onOpacityChanged(a)
                end
            end
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    swatch.refresh = refresh
    return swatch
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
    OneWoW_GUI:SafeSetFont(text, OneWoW_GUI:GetFont(), 10)
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

function OneWoW_GUI:CreateIntegrationRow(parent, options)
    options = options or {}
    local addonName = options.addonName
    local displayName = options.displayName or addonName
    local height = options.height or 30
    local isEnabled = options.isEnabled
    local onToggle = options.onToggle
    local statusLabel = options.statusLabel or "Status:"
    local detectedText = options.detectedText or "Detected"
    local notDetectedText = options.notDetectedText or "Not Detected"
    local enabledText = options.enabledText or "Enabled"
    local disabledText = options.disabledText or "Disabled"
    local enableBtnText = options.enableBtnText or "Enable"
    local disableBtnText = options.disableBtnText or "Disable"
    local notCompatible = options.notCompatible
    local notCompatibleText = options.notCompatibleText or "Not Compatible"

    local detected = C_AddOns.IsAddOnLoaded(addonName)

    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(height)
    row:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local nameFs = OneWoW_GUI:CreateFS(row, 12)
    nameFs:SetPoint("LEFT", row, "LEFT", 10, 0)
    nameFs:SetText(displayName)
    nameFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local statusLabelFs = OneWoW_GUI:CreateFS(row, 12)
    statusLabelFs:SetPoint("LEFT", nameFs, "RIGHT", 16, 0)
    statusLabelFs:SetText(statusLabel)
    statusLabelFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local statusValueFs = OneWoW_GUI:CreateFS(row, 12)
    statusValueFs:SetPoint("LEFT", statusLabelFs, "RIGHT", 4, 0)

    local toggleBtn

    local function refresh()
        detected = C_AddOns.IsAddOnLoaded(addonName)
        if not detected then
            statusValueFs:SetText(notDetectedText)
            statusValueFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            if toggleBtn then toggleBtn:Hide() end
        elseif notCompatible then
            statusValueFs:SetText(detectedText .. " (" .. notCompatibleText .. ")")
            statusValueFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            if toggleBtn then toggleBtn:Hide() end
        else
            local enabled = isEnabled and isEnabled() or false
            if enabled then
                statusValueFs:SetText(detectedText .. " (" .. enabledText .. ")")
                statusValueFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                statusValueFs:SetText(detectedText .. " (" .. disabledText .. ")")
                statusValueFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            end
            if toggleBtn then
                toggleBtn.text:SetText(enabled and disableBtnText or enableBtnText)
                toggleBtn:Show()
            end
        end
    end

    if detected and not notCompatible then
        local enabled = isEnabled and isEnabled() or false
        toggleBtn = OneWoW_GUI:CreateFitTextButton(row, { text = enabled and disableBtnText or enableBtnText, height = 22 })
        toggleBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        toggleBtn:SetScript("OnClick", function()
            local currentEnabled = isEnabled and isEnabled() or false
            local newState = not currentEnabled
            if onToggle then onToggle(newState) end
            refresh()
        end)
    end

    refresh()

    row.refresh = refresh
    return row
end

function OneWoW_GUI:CreateFeatureStatusBlock(parent, options)
    options = options or {}
    local yOff       = options.yOffset or 0
    local xOff       = options.xOffset or 12
    local isEnabled  = options.isEnabled
    local onToggle   = options.onToggle
    local statusLbl  = options.statusLabel
    local enText     = options.enabledText
    local disText    = options.disabledText
    local enBtnTxt   = options.enableBtnText
    local disBtnTxt  = options.disableBtnText

    local statusPrefix = self:CreateFS(parent, 12)
    statusPrefix:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOff)
    if statusLbl then statusPrefix:SetText(statusLbl) end
    statusPrefix:SetTextColor(self:GetThemeColor("TEXT_PRIMARY"))

    local statusValue = self:CreateFS(parent, 12)
    statusValue:SetPoint("LEFT", statusPrefix, "RIGHT", 4, 0)

    local currentState = isEnabled and isEnabled() or false
    if currentState then
        if enText then statusValue:SetText(enText) end
        statusValue:SetTextColor(self:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        if disText then statusValue:SetText(disText) end
        statusValue:SetTextColor(self:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end

    local toggleBtn = self:CreateFitTextButton(parent, {
        text = currentState and (disBtnTxt or "") or (enBtnTxt or ""),
        height = 24,
    })
    toggleBtn:SetPoint("LEFT", statusValue, "RIGHT", 12, 0)

    local block = {
        statusPrefix = statusPrefix,
        statusValue  = statusValue,
        toggleBtn    = toggleBtn,
    }

    function block.refresh()
        local enabled = isEnabled and isEnabled() or false
        if enabled then
            if enText then statusValue:SetText(enText) end
            statusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            if disText then statusValue:SetText(disText) end
            statusValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end
        toggleBtn.text:SetText(enabled and (disBtnTxt or "") or (enBtnTxt or ""))
    end

    function block.getBottomY()
        return yOff - 30
    end

    toggleBtn:SetScript("OnClick", function()
        local nowEnabled = isEnabled and isEnabled() or false
        local newState = not nowEnabled
        if onToggle then
            onToggle(newState)
        end
        block.refresh()
    end)

    return block
end
