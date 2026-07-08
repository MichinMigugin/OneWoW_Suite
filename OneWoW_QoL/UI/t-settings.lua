local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

local function ShowDevHelpDialog()
    if OneWoW_QoLDevHelpDialog then
        OneWoW_QoLDevHelpDialog:Show()
        OneWoW_QoLDevHelpDialog:Raise()
        return
    end

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_QoLDevHelpDialog",
        title = L["DEVHELP_TITLE"],
        width = 520,
        height = 560,
        buttons = {
            { text = CLOSE, onClick = function(dialog) dialog:Hide() end },
        },
    })

    local dialog = result.frame
    local cf = result.contentFrame

    local scrollFrame = CreateFrame("ScrollFrame", nil, cf)
    scrollFrame:SetPoint("TOPLEFT", cf, "TOPLEFT", 16, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -24, 4)
    scrollFrame:EnableMouseWheel(true)

    local scrollTrack = CreateFrame("Frame", nil, cf, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -4, -4)
    scrollTrack:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -4, 4)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop(BACKDROP_SIMPLE)
    scrollTrack:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(40)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop(BACKDROP_SIMPLE)
    scrollThumb:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    local function UpdateThumb()
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local scroll = scrollFrame:GetVerticalScroll()
        local frameH = scrollFrame:GetHeight()
        local contentH = scrollChild:GetHeight()
        if scrollRange <= 0 or contentH <= 0 then
            scrollThumb:SetHeight(scrollTrack:GetHeight())
            scrollThumb:ClearAllPoints()
            scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
            return
        end
        local trackH = scrollTrack:GetHeight()
        local thumbH = math.max(20, (frameH / contentH) * trackH)
        scrollThumb:SetHeight(thumbH)
        local maxOffset = trackH - thumbH
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(scroll / scrollRange) * maxOffset)
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        self:SetVerticalScroll(delta > 0 and math.max(0, current - 30) or math.min(maxScroll, current + 30))
        UpdateThumb()
    end)
    scrollFrame:HookScript("OnSizeChanged", function(_, width)
        scrollChild:SetWidth(width)
        UpdateThumb()
    end)

    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")
    scrollThumb:SetScript("OnMouseDown", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnMouseUp", function(self) self.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self.dragStartY - curY
        local trackH = scrollTrack:GetHeight()
        local thumbH = self:GetHeight()
        local maxOffset = trackH - thumbH
        if maxOffset <= 0 then return end
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local newScroll = self.dragStartScroll + (delta / maxOffset) * scrollRange
        scrollFrame:SetVerticalScroll(math.max(0, math.min(scrollRange, newScroll)))
        UpdateThumb()
    end)

    local bodyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bodyText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -8)
    bodyText:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -8, -8)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetWordWrap(true)
    bodyText:SetSpacing(4)
    bodyText:SetText(L["DEVHELP_BODY"])
    bodyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    scrollChild:SetHeight(bodyText:GetStringHeight() + 30)
    C_Timer.After(0.1, function() UpdateThumb() end)

    dialog:Show()
end

local function CreateSectionHeader(parent, text, yOffset)
    return OneWoW_GUI:CreateSectionHeader(parent, { title = text, yOffset = yOffset })
end

local function CreateSectionDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yOffset)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    return divider
end

function ns.UI.CreateSettingsTab(parent)
    local scrollBarWidth = 10
    local settingsContainer = CreateFrame("Frame", nil, parent)
    settingsContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    settingsContainer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -scrollBarWidth, 0)

    local scrollFrame = CreateFrame("ScrollFrame", nil, settingsContainer)
    scrollFrame:SetAllPoints(settingsContainer)
    scrollFrame:EnableMouseWheel(true)

    local scrollTrack = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, 0)
    scrollTrack:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -2, 0)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop(BACKDROP_SIMPLE)
    scrollTrack:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(40)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop(BACKDROP_SIMPLE)
    scrollThumb:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    local function UpdateThumb()
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local scroll = scrollFrame:GetVerticalScroll()
        local frameH = scrollFrame:GetHeight()
        local contentH = scrollChild:GetHeight()
        if scrollRange <= 0 or contentH <= 0 then
            scrollThumb:SetHeight(scrollTrack:GetHeight())
            scrollThumb:ClearAllPoints()
            scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
            return
        end
        local trackH = scrollTrack:GetHeight()
        local thumbH = math.max(20, (frameH / contentH) * trackH)
        scrollThumb:SetHeight(thumbH)
        local maxOffset = trackH - thumbH
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(scroll / scrollRange) * maxOffset)
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        self:SetVerticalScroll(delta > 0 and math.max(0, current - 40) or math.min(maxScroll, current + 40))
        UpdateThumb()
    end)
    scrollFrame:HookScript("OnSizeChanged", function(_, width)
        scrollChild:SetWidth(width)
        UpdateThumb()
    end)

    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")
    scrollThumb:SetScript("OnMouseDown", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnMouseUp", function(self) self.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self.dragStartY - curY
        local trackH = scrollTrack:GetHeight()
        local thumbH = self:GetHeight()
        local maxOffset = trackH - thumbH
        if maxOffset <= 0 then return end
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local newScroll = self.dragStartScroll + (delta / maxOffset) * scrollRange
        scrollFrame:SetVerticalScroll(math.max(0, math.min(scrollRange, newScroll)))
        UpdateThumb()
    end)

    local SIDE = 16
    local yOffset = -20

    -- Relative-anchored layout: each block is anchored to the bottom of the
    -- previous one (full content width), so the panel reflows without overlap
    -- at any font size instead of relying on fixed offsets the text can overrun.
    local cursor = CreateFrame("Frame", nil, scrollChild)
    cursor:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", SIDE, yOffset)
    cursor:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -SIDE, yOffset)
    cursor:SetHeight(1)

    local lastRow = cursor

    local function StackBelow(region, gap)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -(gap or 0))
        region:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, -(gap or 0))
        lastRow = region
    end

    -- Weekly reset region picker. Hosted here, but owned by OneWoW_Trackers,
    -- which exposes the data + strings through its public API. Only shown when
    -- Trackers is loaded (it is the sole consumer of the setting).
    if OneWoW_Trackers_API and OneWoW_Trackers_API.GetWeeklyResetRegionOptions then
        local resetTitle, resetDescText, resetCurrentFmt = OneWoW_Trackers_API.GetWeeklyResetUIText()

        local resetHeader = CreateSectionHeader(scrollChild, resetTitle, 0)
        StackBelow(resetHeader, 20)

        local resetDivider = CreateSectionDivider(scrollChild, 0)
        StackBelow(resetDivider, 8)

        local resetDesc = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        resetDesc:SetJustifyH("LEFT")
        resetDesc:SetWordWrap(true)
        resetDesc:SetSpacing(3)
        resetDesc:SetText(resetDescText)
        resetDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        StackBelow(resetDesc, 10)

        local resetRow = CreateFrame("Frame", nil, scrollChild)
        resetRow:SetHeight(30)
        StackBelow(resetRow, 12)

        local dropdown = OneWoW_GUI:CreateDropdown(resetRow, {
            width = 240,
            height = 28,
            text = OneWoW_Trackers_API.GetWeeklyResetRegionLabel(),
        })
        dropdown:SetPoint("LEFT", resetRow, "LEFT", 0, 0)

        local currentLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        currentLabel:SetPoint("LEFT", dropdown, "RIGHT", 12, 0)
        currentLabel:SetText(resetCurrentFmt:format(OneWoW_Trackers_API.GetWeeklyResetRegionLabel()))
        currentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        OneWoW_GUI:AttachFilterMenu(dropdown, {
            searchable = false,
            buildItems = function()
                local items = {}
                for _, opt in ipairs(OneWoW_Trackers_API.GetWeeklyResetRegionOptions()) do
                    items[#items + 1] = { text = opt.label, value = opt.value }
                end
                return items
            end,
            onSelect = function(value, text)
                OneWoW_Trackers_API.SetWeeklyResetRegion(value)
                dropdown._text:SetText(text)
                currentLabel:SetText(resetCurrentFmt:format(text))
            end,
            getActiveValue = function() return OneWoW_Trackers_API.GetWeeklyResetRegion() end,
        })
    end

    local devHeader = CreateSectionHeader(scrollChild, L["SETTINGS_DEVELOPER_HEADER"], 0)
    StackBelow(devHeader, 20)

    local devDivider = CreateSectionDivider(scrollChild, 0)
    StackBelow(devDivider, 8)

    local devDesc = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    devDesc:SetJustifyH("LEFT")
    devDesc:SetWordWrap(true)
    devDesc:SetSpacing(3)
    devDesc:SetText(L["SETTINGS_DEVELOPER_DESC"])
    devDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    StackBelow(devDesc, 12)

    local devBtnRow = CreateFrame("Frame", nil, scrollChild)
    devBtnRow:SetHeight(34)
    StackBelow(devBtnRow, 12)

    local devHelpBtn = OneWoW_GUI:CreateFitTextButton(devBtnRow, { text = L["SETTINGS_DEV_HELP_BTN"], height = 32 })
    devHelpBtn:SetPoint("LEFT", devBtnRow, "LEFT", 0, 0)
    devHelpBtn:SetScript("OnClick", function()
        ShowDevHelpDialog()
    end)

    -- Content height is measured from the rendered bottom of the last row once
    -- the panel has a real width, so wrapped text at any font size is included.
    local function RecalcHeight()
        local top = scrollChild:GetTop()
        local bottom = lastRow and lastRow:GetBottom()
        if top and bottom then
            scrollChild:SetHeight((top - bottom) + 30)
        end
        UpdateThumb()
    end

    scrollChild:SetHeight(600)
    scrollFrame:HookScript("OnSizeChanged", RecalcHeight)
    C_Timer.After(0.1, RecalcHeight)
    C_Timer.After(0.5, RecalcHeight)
end
