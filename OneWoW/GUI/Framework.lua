local ADDON_NAME, OneWoW = ...

OneWoW.GUI = OneWoW.GUI or {}
local GUI = OneWoW.GUI

local function T(key)
    if OneWoW.Constants and OneWoW.Constants.THEME and OneWoW.Constants.THEME[key] then
        return unpack(OneWoW.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if OneWoW.Constants and OneWoW.Constants.SPACING then
        return OneWoW.Constants.SPACING[key] or 8
    end
    return 8
end

local BACKDROP_SOFT = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileEdge = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local BACKDROP_INNER = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

function GUI:CreateFrame(name, parent, width, height, useModernBackdrop)
    local frame = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    frame:SetSize(width, height)

    if useModernBackdrop then
        frame:SetBackdrop(BACKDROP_SOFT)
    else
        frame:SetBackdrop(BACKDROP_INNER)
    end

    frame:SetBackdropColor(T("BG_PRIMARY"))
    frame:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    return frame
end

function GUI:CreateButton(name, parent, text, width, height)
    local C = OneWoW.Constants and OneWoW.Constants.GUI or { BUTTON_HEIGHT = 28 }

    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetSize(width or 100, height or C.BUTTON_HEIGHT)
    btn:SetBackdrop(BACKDROP_INNER)
    btn:SetBackdropColor(T("BTN_NORMAL"))
    btn:SetBackdropBorderColor(T("BTN_BORDER"))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn.text:SetTextColor(T("TEXT_PRIMARY"))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BTN_HOVER"))
        self:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
        self.text:SetTextColor(T("TEXT_ACCENT"))
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BTN_NORMAL"))
        self:SetBackdropBorderColor(T("BTN_BORDER"))
        self.text:SetTextColor(T("TEXT_PRIMARY"))
    end)

    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(T("BTN_PRESSED"))
    end)

    btn:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            self:SetBackdropColor(T("BTN_HOVER"))
        else
            self:SetBackdropColor(T("BTN_NORMAL"))
        end
    end)

    return btn
end

function GUI:CreateEditBox(name, parent, width, height)
    local C = OneWoW.Constants and OneWoW.Constants.GUI or { SEARCH_HEIGHT = 32 }

    local box = CreateFrame("EditBox", name, parent, "BackdropTemplate")
    box:SetSize(width or 200, height or C.SEARCH_HEIGHT)
    box:SetBackdrop(BACKDROP_INNER)
    box:SetBackdropColor(T("BG_TERTIARY"))
    box:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(S("SM") + 2, S("SM"), 0, 0)
    box:SetAutoFocus(false)
    box:EnableMouse(true)
    box:SetTextColor(T("TEXT_PRIMARY"))

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    return box
end

function GUI:CreateCheckbox(name, parent, label)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)

    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.label:SetPoint("LEFT", cb, "RIGHT", S("XS"), 0)
    cb.label:SetText(label)
    cb.label:SetTextColor(T("TEXT_PRIMARY"))

    return cb
end

function GUI:CreateHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", S("MD"), yOffset or -S("MD"))
    header:SetText(text)
    header:SetTextColor(T("ACCENT_PRIMARY"))
    return header
end

function GUI:CreateDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("LEFT", S("MD"), 0)
    divider:SetPoint("RIGHT", -S("MD"), 0)
    divider:SetPoint("TOP", 0, yOffset)
    divider:SetColorTexture(T("BORDER_SUBTLE"))
    return divider
end

function GUI:CreateScrollFrame(name, parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)

    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -5, 0)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -5, 0)
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
            scrollBar.Background:SetColorTexture(T("BG_TERTIARY"))
        end

        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetWidth(8)
            scrollBar.ThumbTexture:SetColorTexture(T("ACCENT_PRIMARY"))
        end
    end

    local content = CreateFrame("Frame", name .. "Content", scrollFrame)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        content:SetWidth(w)
    end)

    return scrollFrame, content
end

local _splitPanelCount = 0

function GUI:CreateSplitPanel(parent)
    local C = OneWoW.Constants.GUI
    _splitPanelCount = _splitPanelCount + 1
    local uid = _splitPanelCount

    local listPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 35)
    listPanel:SetWidth(C.LEFT_PANEL_WIDTH)
    listPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    listPanel:SetBackdropColor(T("BG_PRIMARY"))
    listPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local listTitle = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 10, -10)
    listTitle:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -10, -10)
    listTitle:SetJustifyH("LEFT")
    listTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local listContainer = CreateFrame("Frame", nil, listPanel)
    listContainer:SetPoint("TOPLEFT",     listPanel, "TOPLEFT",     8,  -32)
    listContainer:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -8,   8)

    local listScrollFrame = CreateFrame("ScrollFrame", "OneWoWSplit_List" .. uid, listContainer, "UIPanelScrollFrameTemplate")
    listScrollFrame:SetPoint("TOPLEFT",     listContainer, "TOPLEFT",     0,   0)
    listScrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -14, 0)
    listScrollFrame:EnableMouseWheel(true)

    local listScrollBar = listScrollFrame.ScrollBar
    if listScrollBar then
        listScrollBar:ClearAllPoints()
        listScrollBar:SetPoint("TOPRIGHT",    listContainer, "TOPRIGHT",    -2, 0)
        listScrollBar:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -2, 0)
        listScrollBar:SetWidth(10)
        if listScrollBar.ScrollUpButton then
            listScrollBar.ScrollUpButton:Hide()
            listScrollBar.ScrollUpButton:SetAlpha(0)
            listScrollBar.ScrollUpButton:EnableMouse(false)
        end
        if listScrollBar.ScrollDownButton then
            listScrollBar.ScrollDownButton:Hide()
            listScrollBar.ScrollDownButton:SetAlpha(0)
            listScrollBar.ScrollDownButton:EnableMouse(false)
        end
        if listScrollBar.Background then
            listScrollBar.Background:SetColorTexture(T("BG_TERTIARY"))
        end
        if listScrollBar.ThumbTexture then
            listScrollBar.ThumbTexture:SetWidth(8)
            listScrollBar.ThumbTexture:SetColorTexture(T("ACCENT_PRIMARY"))
        end
    end

    local listScrollChild = CreateFrame("Frame", "OneWoWSplit_ListContent" .. uid, listScrollFrame)
    listScrollChild:SetHeight(1)
    listScrollFrame:SetScrollChild(listScrollChild)
    listScrollFrame:HookScript("OnSizeChanged", function(self, w)
        listScrollChild:SetWidth(w)
    end)

    local detailPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detailPanel:SetPoint("TOPLEFT",     listPanel, "TOPRIGHT",    C.PANEL_GAP, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent,    "BOTTOMRIGHT", 0,           35)
    detailPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    detailPanel:SetBackdropColor(T("BG_PRIMARY"))
    detailPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local detailTitle = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailTitle:SetPoint("TOPLEFT",  detailPanel, "TOPLEFT",  10, -10)
    detailTitle:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -10, -10)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local detailContainer = CreateFrame("Frame", nil, detailPanel)
    detailContainer:SetPoint("TOPLEFT",     detailPanel, "TOPLEFT",     8,  -32)
    detailContainer:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8,   8)

    local detailScrollFrame = CreateFrame("ScrollFrame", "OneWoWSplit_Detail" .. uid, detailContainer, "UIPanelScrollFrameTemplate")
    detailScrollFrame:SetPoint("TOPLEFT",     detailContainer, "TOPLEFT",     0,   0)
    detailScrollFrame:SetPoint("BOTTOMRIGHT", detailContainer, "BOTTOMRIGHT", -14, 0)
    detailScrollFrame:EnableMouseWheel(true)

    local detailScrollBar = detailScrollFrame.ScrollBar
    if detailScrollBar then
        detailScrollBar:ClearAllPoints()
        detailScrollBar:SetPoint("TOPRIGHT",    detailContainer, "TOPRIGHT",    -2, 0)
        detailScrollBar:SetPoint("BOTTOMRIGHT", detailContainer, "BOTTOMRIGHT", -2, 0)
        detailScrollBar:SetWidth(10)
        if detailScrollBar.ScrollUpButton then
            detailScrollBar.ScrollUpButton:Hide()
            detailScrollBar.ScrollUpButton:SetAlpha(0)
            detailScrollBar.ScrollUpButton:EnableMouse(false)
        end
        if detailScrollBar.ScrollDownButton then
            detailScrollBar.ScrollDownButton:Hide()
            detailScrollBar.ScrollDownButton:SetAlpha(0)
            detailScrollBar.ScrollDownButton:EnableMouse(false)
        end
        if detailScrollBar.Background then
            detailScrollBar.Background:SetColorTexture(T("BG_TERTIARY"))
        end
        if detailScrollBar.ThumbTexture then
            detailScrollBar.ThumbTexture:SetWidth(8)
            detailScrollBar.ThumbTexture:SetColorTexture(T("ACCENT_PRIMARY"))
        end
    end

    local detailScrollChild = CreateFrame("Frame", "OneWoWSplit_DetailContent" .. uid, detailScrollFrame)
    detailScrollChild:SetHeight(1)
    detailScrollFrame:SetScrollChild(detailScrollChild)
    detailScrollFrame:HookScript("OnSizeChanged", function(self, w)
        detailScrollChild:SetWidth(w)
    end)

    local leftStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    leftStatusBar:SetPoint("TOPLEFT", listPanel, "BOTTOMLEFT", 0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)
    leftStatusBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    leftStatusBar:SetBackdropColor(T("BG_SECONDARY"))
    leftStatusBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local leftStatusText = leftStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(T("TEXT_SECONDARY"))
    leftStatusText:SetText("")

    local rightStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rightStatusBar:SetPoint("TOPLEFT", detailPanel, "BOTTOMLEFT", 0, -5)
    rightStatusBar:SetPoint("TOPRIGHT", detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)
    rightStatusBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    rightStatusBar:SetBackdropColor(T("BG_SECONDARY"))
    rightStatusBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local rightStatusText = rightStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(T("TEXT_SECONDARY"))
    rightStatusText:SetText("")

    local noop = function() end

    return {
        listPanel         = listPanel,
        listTitle         = listTitle,
        listScrollFrame   = listScrollFrame,
        listScrollChild   = listScrollChild,
        UpdateListThumb   = noop,
        detailPanel       = detailPanel,
        detailTitle       = detailTitle,
        detailScrollFrame = detailScrollFrame,
        detailScrollChild = detailScrollChild,
        UpdateDetailThumb = noop,
        leftStatusBar     = leftStatusBar,
        leftStatusText    = leftStatusText,
        rightStatusBar    = rightStatusBar,
        rightStatusText   = rightStatusText,
    }
end

function GUI:ClearFrame(frame)
    if not frame then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        region:Hide()
    end
end

GUI.GetThemeColor = T
GUI.GetSpacing = S
