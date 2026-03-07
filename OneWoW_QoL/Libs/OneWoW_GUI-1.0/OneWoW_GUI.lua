local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local CreateFrame = CreateFrame
local unpack = unpack

local Constants = OneWoW_GUI.Constants
local DEFAULT_THEME = Constants.DEFAULT_THEME
local DEFAULT_THEME_COLOR = DEFAULT_THEME.COLOR
local DEFAULT_THEME_SPACING = DEFAULT_THEME.SPACING
local DEFAULT_ICON_TEXTURE = Constants.ICON_TEXTURES.horde

local _splitPanelCount = 0

local noop = function() end

local themeMetatable = {
    __index = function(self, key)
        return Constants.FALLBACK_THEME[key] or DEFAULT_THEME_COLOR
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

function OneWoW_GUI:GetThemeColor(key)
    return GetThemeColor(key)
end

function OneWoW_GUI:GetSpacing(key)
    return GetSpacing(key)
end

function OneWoW_GUI:GetBrandIcon(factionTheme)
    return OneWoW_GUI.Constants.ICON_TEXTURES[factionTheme] or DEFAULT_ICON_TEXTURE
end

function OneWoW_GUI:ApplyTheme(themeKey)
    local selectedTheme = Constants.THEMES[themeKey] or Constants.THEMES["green"]
    Constants.ACTIVE_THEME = setmetatable(selectedTheme, themeMetatable)
end

function OneWoW_GUI:CreateFrame(name, parent, width, height, useModernBackdrop)
    local frame = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    frame:SetSize(width, height)

    if useModernBackdrop then
        frame:SetBackdrop(Constants.BACKDROP_SOFT)
    else
        frame:SetBackdrop(Constants.BACKDROP_INNER)
    end

    frame:SetBackdropColor(GetThemeColor("BG_PRIMARY"))
    frame:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))
    return frame
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

function OneWoW_GUI:CreateOnOffToggleButtons(parent, yOffset, onLabel, offLabel, width, height, isEnabled, value, onValueChange)
    width = width or 50
    height = height or 22

    local onBtn = self:CreateButton(nil, parent, onLabel, width, height)
    onBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)

    local offBtn = self:CreateButton(nil, parent, offLabel, width, height)
    offBtn:SetPoint("RIGHT", onBtn, "LEFT", -4, 0)

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
        btn:SetScript("OnEnter", function() applyHover(btn) end)
        btn:SetScript("OnLeave", function() applyNormal(btn) end)
        btn:SetScript("OnMouseDown", function() btn:SetBackdropColor(GetThemeColor("BTN_PRESSED")) end)
        btn:SetScript("OnMouseUp", function() applyNormal(btn) end)
    end

    local function refresh(enabled, val)
        isEnabled = enabled
        -- Guard: frames may be orphaned if detail panel was cleared (e.g. module switch)
        if not onBtn:GetParent() or not offBtn:GetParent() then
            return
        end
        -- Coerce to boolean to prevent EnableMouse(nil) which disables interaction
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
        else
            applyNormal(onBtn)
            applyNormal(offBtn)
        end
    end

    onBtn:SetScript("OnClick", function()
        onValueChange(true)
        -- Run refresh immediately so visual state is correct before any deferred handlers
        refresh(isEnabled, true)
        -- Defer only hover re-apply; OnLeave may have fired during click
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
    return onBtn, offBtn, refresh
end

function OneWoW_GUI:CreateEditBox(name, parent, width, height)
    local box = CreateFrame("EditBox", name, parent, "BackdropTemplate")
    box:SetSize(width or Constants.GUI.SEARCH_WIDTH, height or Constants.GUI.SEARCH_HEIGHT)
    box:SetBackdrop(Constants.BACKDROP_INNER)
    box:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
    box:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(GetSpacing("SM") + 2, GetSpacing("SM"), 0, 0)
    box:SetAutoFocus(false)
    box:EnableMouse(true)
    box:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(GetThemeColor("BORDER_FOCUS"))
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
    end)

    return box
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

    if showBrand then
        local factionTheme = options.factionTheme or "horde"
        local brandIcon = titleBg:CreateTexture(nil, "OVERLAY")
        brandIcon:SetSize(14, 14)
        brandIcon:SetPoint("LEFT", titleBg, "LEFT", GetSpacing("SM"), 0)
        brandIcon:SetTexture(self:GetBrandIcon(factionTheme))
        titleBg.brandIcon = brandIcon

        local brandText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        brandText:SetPoint("LEFT", brandIcon, "RIGHT", 4, 0)
        brandText:SetText("OneWoW")
        brandText:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))

        local titleText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
        titleText:SetText(title)
        titleText:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
    else
        local titleText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("LEFT", titleBg, "LEFT", GetSpacing("MD"), 0)
        titleText:SetText(title)
        titleText:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))
    end

    if onClose then
        local closeBtn = self:CreateButton(nil, titleBg, "X", 20, 20)
        closeBtn:SetPoint("RIGHT", titleBg, "RIGHT", -GetSpacing("XS") / 2, 0)
        closeBtn:SetScript("OnClick", onClose)
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

function OneWoW_GUI:CreateScrollFrame(name, parent)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)

    applyScrollBarStyle(scrollFrame.ScrollBar, scrollFrame, -2)

    local content = CreateFrame("Frame", name .. "Content", scrollFrame)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        content:SetWidth(w)
    end)

    return scrollFrame, content
end

function OneWoW_GUI:CreateSplitPanel(parent, options)
    local panelGap = Constants.GUI.PANEL_GAP or 10

    local backdrop = {
        bgFile = Constants.BACKDROP_INNER.bgFile,
        edgeFile = Constants.BACKDROP_INNER.edgeFile,
        edgeSize = Constants.BACKDROP_INNER.edgeSize
    }

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
        searchBox = CreateFrame("EditBox", nil, listPanel, "BackdropTemplate")
        searchBox:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, -30)
        searchBox:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -8, -30)
        searchBox:SetHeight(22)
        searchBox:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        searchBox:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
        searchBox:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
        searchBox:SetFontObject(GameFontHighlight)
        searchBox:SetTextInsets(8, 8, 0, 0)
        searchBox:SetAutoFocus(false)
        searchBox:EnableMouse(true)
        searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        searchBox:SetScript("OnEditFocusGained", function(self)
            self:SetBackdropBorderColor(GetThemeColor("BORDER_ACCENT"))
        end)
        searchBox:SetScript("OnEditFocusLost", function(self)
            self:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
        end)
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
