-- ============================================================================
-- OneWoW_Notes/UI/Framework.lua
-- BRIDGE + ADDON-SPECIFIC UI - Common UI functions are thin wrappers to the
-- OneWoW_GUI Library (OneWoW_GUI-1.0). Only addon-specific UI components
-- (ThemedDropdown, FontDropdown, ThemedDialog, CustomScroll, SplitPanel)
-- should live here. If you need a common UI function, check the GUI Library
-- first and add a wrapper, do NOT reimplement it here.
-- ============================================================================
local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local lib = LibStub("OneWoW_GUI-1.0", true)

function ns.UI.CreateButton(name, parent, text, width, height)
    if lib then return lib:CreateButton(name, parent, text, width, height) end
end

function ns.UI.AutoResizeButton(btn, minWidth, maxWidth)
    if not btn or not btn.text then return end
    local textWidth = btn.text:GetStringWidth()
    local padding = 20
    local currentWidth, currentHeight = btn:GetSize()
    local calculatedWidth = math.max(minWidth or currentWidth, textWidth + padding)
    if maxWidth then
        calculatedWidth = math.min(calculatedWidth, maxWidth)
    end
    btn:SetSize(calculatedWidth, currentHeight)
end

function ns.UI.CreateSplitPanel(parent)
    local listPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    listPanel:SetWidth(ns.Constants.GUI.LEFT_PANEL_WIDTH)
    listPanel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    listPanel:SetBackdropColor(T("BG_PRIMARY"))
    listPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local listTitle = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 10, -10)
    listTitle:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -10, -10)
    listTitle:SetJustifyH("LEFT")
    listTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local scrollBarWidth = 10
    local listContainer = CreateFrame("Frame", nil, listPanel)
    listContainer:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, -32)
    listContainer:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -8, 8)

    local listScrollFrame = CreateFrame("ScrollFrame", nil, listContainer)
    listScrollFrame:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, 0)
    listScrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -scrollBarWidth, 0)
    listScrollFrame:EnableMouseWheel(true)

    local listScrollTrack = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
    listScrollTrack:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", -2, 0)
    listScrollTrack:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -2, 0)
    listScrollTrack:SetWidth(8)
    listScrollTrack:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    listScrollTrack:SetBackdropColor(T("BG_TERTIARY"))

    local listScrollThumb = CreateFrame("Frame", nil, listScrollTrack, "BackdropTemplate")
    listScrollThumb:SetWidth(6)
    listScrollThumb:SetHeight(30)
    listScrollThumb:SetPoint("TOP", listScrollTrack, "TOP", 0, 0)
    listScrollThumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    listScrollThumb:SetBackdropColor(T("ACCENT_PRIMARY"))

    local listScrollChild = CreateFrame("Frame", nil, listScrollFrame)
    listScrollChild:SetWidth(listScrollFrame:GetWidth())
    listScrollChild:SetHeight(1)
    listScrollFrame:SetScrollChild(listScrollChild)

    local function UpdateListThumb()
        local scrollRange = listScrollFrame:GetVerticalScrollRange()
        local scroll = listScrollFrame:GetVerticalScroll()
        local frameH = listScrollFrame:GetHeight()
        local contentH = listScrollChild:GetHeight()
        if scrollRange <= 0 or contentH <= 0 then
            listScrollThumb:SetHeight(listScrollTrack:GetHeight())
            listScrollThumb:SetPoint("TOP", listScrollTrack, "TOP", 0, 0)
            return
        end
        local trackH = listScrollTrack:GetHeight()
        local thumbH = math.max(20, (frameH / contentH) * trackH)
        listScrollThumb:SetHeight(thumbH)
        local maxOffset = trackH - thumbH
        local pct = scroll / scrollRange
        listScrollThumb:SetPoint("TOP", listScrollTrack, "TOP", 0, -(pct * maxOffset))
    end

    listScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 40))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 40))
        end
        UpdateListThumb()
    end)

    listScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        UpdateListThumb()
    end)

    listScrollFrame:HookScript("OnSizeChanged", function(self, width)
        listScrollChild:SetWidth(width)
        UpdateListThumb()
    end)

    listScrollThumb:EnableMouse(true)
    listScrollThumb:RegisterForDrag("LeftButton")
    listScrollThumb:SetScript("OnMouseDown", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = listScrollFrame:GetVerticalScroll()
    end)
    listScrollThumb:SetScript("OnMouseUp",   function(self) self.dragging = false end)
    listScrollThumb:SetScript("OnDragStop",  function(self) self.dragging = false end)
    listScrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self.dragStartY - curY
        local trackH = listScrollTrack:GetHeight()
        local thumbH = self:GetHeight()
        local maxOffset = trackH - thumbH
        if maxOffset <= 0 then return end
        local scrollRange = listScrollFrame:GetVerticalScrollRange()
        local newScroll = self.dragStartScroll + (delta / maxOffset) * scrollRange
        listScrollFrame:SetVerticalScroll(math.max(0, math.min(scrollRange, newScroll)))
        UpdateListThumb()
    end)

    local detailPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detailPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", ns.Constants.GUI.PANEL_GAP, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    detailPanel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    detailPanel:SetBackdropColor(T("BG_PRIMARY"))
    detailPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local detailTitle = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailTitle:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 10, -10)
    detailTitle:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -10, -10)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local detailScrollBarWidth = 10
    local detailContainer = CreateFrame("Frame", nil, detailPanel)
    detailContainer:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 8, -32)
    detailContainer:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 8)

    local detailScrollFrame = CreateFrame("ScrollFrame", nil, detailContainer)
    detailScrollFrame:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 0, 0)
    detailScrollFrame:SetPoint("BOTTOMRIGHT", detailContainer, "BOTTOMRIGHT", -detailScrollBarWidth, 0)
    detailScrollFrame:EnableMouseWheel(true)

    local detailScrollTrack = CreateFrame("Frame", nil, detailContainer, "BackdropTemplate")
    detailScrollTrack:SetPoint("TOPRIGHT", detailContainer, "TOPRIGHT", -2, 0)
    detailScrollTrack:SetPoint("BOTTOMRIGHT", detailContainer, "BOTTOMRIGHT", -2, 0)
    detailScrollTrack:SetWidth(8)
    detailScrollTrack:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    detailScrollTrack:SetBackdropColor(T("BG_TERTIARY"))

    local detailScrollThumb = CreateFrame("Frame", nil, detailScrollTrack, "BackdropTemplate")
    detailScrollThumb:SetWidth(6)
    detailScrollThumb:SetHeight(30)
    detailScrollThumb:SetPoint("TOP", detailScrollTrack, "TOP", 0, 0)
    detailScrollThumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    detailScrollThumb:SetBackdropColor(T("ACCENT_PRIMARY"))

    local detailScrollChild = CreateFrame("Frame", nil, detailScrollFrame)
    detailScrollChild:SetWidth(detailScrollFrame:GetWidth())
    detailScrollChild:SetHeight(1)
    detailScrollFrame:SetScrollChild(detailScrollChild)

    local function UpdateDetailThumb()
        local scrollRange = detailScrollFrame:GetVerticalScrollRange()
        local scroll = detailScrollFrame:GetVerticalScroll()
        local frameH = detailScrollFrame:GetHeight()
        local contentH = detailScrollChild:GetHeight()
        if scrollRange <= 0 or contentH <= 0 then
            detailScrollThumb:SetHeight(detailScrollTrack:GetHeight())
            detailScrollThumb:SetPoint("TOP", detailScrollTrack, "TOP", 0, 0)
            return
        end
        local trackH = detailScrollTrack:GetHeight()
        local thumbH = math.max(20, (frameH / contentH) * trackH)
        detailScrollThumb:SetHeight(thumbH)
        local maxOffset = trackH - thumbH
        local pct = scroll / scrollRange
        detailScrollThumb:SetPoint("TOP", detailScrollTrack, "TOP", 0, -(pct * maxOffset))
    end

    detailScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 40))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 40))
        end
        UpdateDetailThumb()
    end)

    detailScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        UpdateDetailThumb()
    end)

    detailScrollFrame:HookScript("OnSizeChanged", function(self, width)
        detailScrollChild:SetWidth(width)
        UpdateDetailThumb()
    end)

    detailScrollThumb:EnableMouse(true)
    detailScrollThumb:RegisterForDrag("LeftButton")
    detailScrollThumb:SetScript("OnMouseDown", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = detailScrollFrame:GetVerticalScroll()
    end)
    detailScrollThumb:SetScript("OnMouseUp",  function(self) self.dragging = false end)
    detailScrollThumb:SetScript("OnDragStop", function(self) self.dragging = false end)
    detailScrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self.dragStartY - curY
        local trackH = detailScrollTrack:GetHeight()
        local thumbH = self:GetHeight()
        local maxOffset = trackH - thumbH
        if maxOffset <= 0 then return end
        local scrollRange = detailScrollFrame:GetVerticalScrollRange()
        local newScroll = self.dragStartScroll + (delta / maxOffset) * scrollRange
        detailScrollFrame:SetVerticalScroll(math.max(0, math.min(scrollRange, newScroll)))
        UpdateDetailThumb()
    end)

    return {
        listPanel         = listPanel,
        listTitle         = listTitle,
        listScrollFrame   = listScrollFrame,
        listScrollChild   = listScrollChild,
        UpdateListThumb   = UpdateListThumb,
        detailPanel       = detailPanel,
        detailTitle       = detailTitle,
        detailScrollFrame = detailScrollFrame,
        detailScrollChild = detailScrollChild,
        UpdateDetailThumb = UpdateDetailThumb,
    }
end

-- =============================================
-- THEMED DROPDOWN
-- A fully themed dropdown that replaces UIDropDownMenuTemplate
-- Usage:
--   local dd = ns.UI.CreateThemedDropdown(parent, "Category", 150, 26)
--   dd:SetOptions({{text="All", value="All"}, {text="General", value="General"}})
--   dd:SetSelected("All")
--   dd.onSelect = function(value, text) ... end
-- =============================================

local _openDropdown = nil

function ns.UI.CreateThemedDropdown(parent, labelPrefix, width, height)
    width  = width  or 150
    height = height or 26

    local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dd:SetSize(width, height)
    dd:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dd:SetBackdropColor(T("BTN_NORMAL"))
    dd:SetBackdropBorderColor(T("BTN_BORDER"))

    local textFS = dd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    textFS:SetPoint("LEFT",  dd, "LEFT",  7, 0)
    textFS:SetPoint("RIGHT", dd, "RIGHT", -18, 0)
    textFS:SetJustifyH("LEFT")
    textFS:SetTextColor(T("TEXT_PRIMARY"))

    local arrowTex = dd:CreateTexture(nil, "ARTWORK")
    arrowTex:SetSize(12, 12)
    arrowTex:SetPoint("RIGHT", dd, "RIGHT", -5, 0)
    arrowTex:SetAtlas("common-button-collapseExpand-down")

    dd._value       = nil
    dd._displayText = ""
    dd._labelPrefix = labelPrefix or ""
    dd._options     = {}
    dd.onSelect     = nil

    -- popup list
    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetWidth(width)
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(T("BG_SECONDARY"))
    popup:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    popup:Hide()
    dd._popup = popup

    local function RefreshText()
        if dd._labelPrefix ~= "" then
            textFS:SetText(dd._labelPrefix .. ": " .. dd._displayText)
        else
            textFS:SetText(dd._displayText)
        end
    end

    function dd:SetOptions(options)
        self._options = options
    end

    function dd:SetSelected(value)
        for _, opt in ipairs(self._options) do
            if opt.value == value then
                self._value       = value
                self._displayText = opt.text
                RefreshText()
                return
            end
        end
    end

    function dd:SetText(txt)
        self._displayText = txt
        RefreshText()
    end

    function dd:GetText()   return self._displayText end
    function dd:GetValue()  return self._value       end

    function dd:ClosePopup()
        popup:Hide()
        arrowTex:SetAtlas("common-button-collapseExpand-down")
        if _openDropdown == self then _openDropdown = nil end
    end

    local function BuildAndShowPopup()
        if _openDropdown and _openDropdown ~= dd then
            _openDropdown:ClosePopup()
        end

        for _, child in ipairs({popup:GetChildren()}) do
            child:Hide()
            child:SetParent(nil)
            child:ClearAllPoints()
        end

        local ROW_H  = 22
        local ROW_GAP = 1
        local PAD     = 2
        local count   = #dd._options
        popup:SetHeight(PAD * 2 + count * ROW_H + (count - 1) * ROW_GAP)

        for i, opt in ipairs(dd._options) do
            local row = CreateFrame("Button", nil, popup, "BackdropTemplate")
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT",  popup, "TOPLEFT",  PAD, -PAD - (i - 1) * (ROW_H + ROW_GAP))
            row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -PAD, -PAD - (i - 1) * (ROW_H + ROW_GAP))
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

            if opt.value == dd._value then
                row:SetBackdropColor(T("BG_ACTIVE"))
            else
                row:SetBackdropColor(T("BG_SECONDARY"))
            end

            local rowFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rowFS:SetPoint("LEFT", row, "LEFT", 8, 0)
            rowFS:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            rowFS:SetJustifyH("LEFT")
            rowFS:SetText(opt.text)

            if opt.value == dd._value then
                rowFS:SetTextColor(T("ACCENT_PRIMARY"))
            else
                rowFS:SetTextColor(T("TEXT_PRIMARY"))
            end

            row:SetScript("OnEnter", function(self)
                if opt.value ~= dd._value then
                    self:SetBackdropColor(T("BG_HOVER"))
                end
                rowFS:SetTextColor(T("TEXT_ACCENT"))
            end)
            row:SetScript("OnLeave", function(self)
                if opt.value == dd._value then
                    self:SetBackdropColor(T("BG_ACTIVE"))
                    rowFS:SetTextColor(T("ACCENT_PRIMARY"))
                else
                    self:SetBackdropColor(T("BG_SECONDARY"))
                    rowFS:SetTextColor(T("TEXT_PRIMARY"))
                end
            end)
            row:SetScript("OnClick", function()
                dd._value       = opt.value
                dd._displayText = opt.text
                RefreshText()
                dd:ClosePopup()
                if dd.onSelect then dd.onSelect(opt.value, opt.text) end
            end)
        end

        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
        popup:Show()
        popup:Raise()
        arrowTex:SetAtlas("common-button-collapseExpand-up")
        _openDropdown = dd
    end

    dd:SetScript("OnClick", function()
        if popup:IsShown() then
            dd:ClosePopup()
        else
            BuildAndShowPopup()
        end
    end)

    dd:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BTN_HOVER"))
        self:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
    end)
    dd:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BTN_NORMAL"))
        self:SetBackdropBorderColor(T("BTN_BORDER"))
    end)

    return dd
end

-- =============================================
-- FONT DROPDOWN
-- Like CreateThemedDropdown but with scrolling and font preview
-- Usage:
--   local dd = ns.UI.CreateFontDropdown(parent, 150, 26)
--   dd:SetOptions({{text="Arial", value="Arial"}, {text="Times", value="Times"}})
--   dd:SetSelected("Arial")
--   dd.onSelect = function(value, text) ... end
-- =============================================

local _openFontDropdown = nil

function ns.UI.CreateFontDropdown(parent, width, height)
    width  = width  or 150
    height = height or 26

    local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dd:SetSize(width, height)
    dd:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dd:SetBackdropColor(T("BTN_NORMAL"))
    dd:SetBackdropBorderColor(T("BTN_BORDER"))

    local textFS = dd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    textFS:SetPoint("LEFT",  dd, "LEFT",  7, 0)
    textFS:SetPoint("RIGHT", dd, "RIGHT", -18, 0)
    textFS:SetJustifyH("LEFT")
    textFS:SetTextColor(T("TEXT_PRIMARY"))

    local arrowTex = dd:CreateTexture(nil, "ARTWORK")
    arrowTex:SetSize(12, 12)
    arrowTex:SetPoint("RIGHT", dd, "RIGHT", -5, 0)
    arrowTex:SetAtlas("common-button-collapseExpand-down")

    dd._value       = nil
    dd._displayText = ""
    dd._options     = {}
    dd.onSelect     = nil

    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(T("BG_SECONDARY"))
    popup:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    popup:Hide()
    dd._popup = popup

    local function RefreshText()
        textFS:SetText(dd._displayText)
        if dd._displayText and dd._displayText ~= "" then
            local LSM = LibStub("LibSharedMedia-3.0", true)
            if LSM then
                local fontPath = LSM:Fetch("font", dd._displayText)
                if fontPath then
                    textFS:SetFont(fontPath, 11, "")
                    return
                end
            end
        end
        textFS:SetFontObject("GameFontNormalSmall")
    end

    function dd:SetOptions(options)
        self._options = options
    end

    function dd:SetSelected(value)
        for _, opt in ipairs(self._options) do
            if opt.value == value then
                self._value       = value
                self._displayText = opt.text
                RefreshText()
                return
            end
        end
    end

    function dd:SetText(txt)
        self._displayText = txt
        RefreshText()
    end

    function dd:GetText()   return self._displayText end
    function dd:GetValue()  return self._value       end

    function dd:ClosePopup()
        popup:Hide()
        arrowTex:SetAtlas("common-button-collapseExpand-down")
        if _openFontDropdown == self then _openFontDropdown = nil end
    end

    local function BuildAndShowPopup()
        if _openFontDropdown and _openFontDropdown ~= dd then
            _openFontDropdown:ClosePopup()
        end

        for _, child in ipairs({popup:GetChildren()}) do
            child:Hide()
            child:SetParent(nil)
            child:ClearAllPoints()
        end

        local MAX_HEIGHT = 300
        local ROW_H  = 22
        local ROW_GAP = 1
        local PAD     = 2
        local count   = #dd._options
        local sbw     = 10

        local scrollFrame = CreateFrame("ScrollFrame", nil, popup)
        scrollFrame:SetPoint("TOPLEFT",     popup, "TOPLEFT",     0,    0)
        scrollFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -sbw, 0)
        scrollFrame:EnableMouseWheel(true)

        local scrollBar = CreateFrame("Slider", nil, popup, "BackdropTemplate")
        scrollBar:SetPoint("TOPLEFT",    scrollFrame, "TOPRIGHT",    0, 0)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 0)
        scrollBar:SetWidth(sbw)
        scrollBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        scrollBar:SetBackdropColor(T("BG_TERTIARY"))
        scrollBar:SetMinMaxValues(0, 1)
        scrollBar:SetValue(0)
        scrollBar:SetScript("OnValueChanged", function(_, value)
            scrollFrame:SetVerticalScroll(value)
        end)

        local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(8, 20)
        thumb:SetColorTexture(T("ACCENT_PRIMARY"))
        scrollBar:SetThumbTexture(thumb)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)
        local fw = scrollFrame:GetWidth()
        if fw > 0 then scrollChild:SetWidth(fw) end

        scrollFrame:HookScript("OnSizeChanged", function(self, w)
            scrollChild:SetWidth(w)
        end)

        scrollFrame:SetScript("OnMouseWheel", function(self, direction)
            local cur = scrollFrame:GetVerticalScroll()
            local max = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
            local new = math.max(0, math.min(max, cur - direction * 28))
            scrollFrame:SetVerticalScroll(new)
            scrollBar:SetValue(new)
        end)

        for i, opt in ipairs(dd._options) do
            local row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  PAD, -PAD - (i - 1) * (ROW_H + ROW_GAP))
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PAD, -PAD - (i - 1) * (ROW_H + ROW_GAP))
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

            if opt.value == dd._value then
                row:SetBackdropColor(T("BG_ACTIVE"))
            else
                row:SetBackdropColor(T("BG_SECONDARY"))
            end

            local rowFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rowFS:SetPoint("LEFT", row, "LEFT", 8, 0)
            rowFS:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            rowFS:SetJustifyH("LEFT")
            rowFS:SetText(opt.text)

            local LSM = LibStub("LibSharedMedia-3.0", true)
            if LSM then
                local fontPath = LSM:Fetch("font", opt.value)
                if fontPath then
                    rowFS:SetFont(fontPath, 11, "")
                end
            end

            if opt.value == dd._value then
                rowFS:SetTextColor(T("ACCENT_PRIMARY"))
            else
                rowFS:SetTextColor(T("TEXT_PRIMARY"))
            end

            row:SetScript("OnEnter", function(self)
                if opt.value ~= dd._value then
                    self:SetBackdropColor(T("BG_HOVER"))
                end
                rowFS:SetTextColor(T("TEXT_ACCENT"))
            end)
            row:SetScript("OnLeave", function(self)
                if opt.value == dd._value then
                    self:SetBackdropColor(T("BG_ACTIVE"))
                    rowFS:SetTextColor(T("ACCENT_PRIMARY"))
                else
                    self:SetBackdropColor(T("BG_SECONDARY"))
                    rowFS:SetTextColor(T("TEXT_PRIMARY"))
                end
            end)
            row:SetScript("OnClick", function()
                dd._value       = opt.value
                dd._displayText = opt.text
                RefreshText()
                dd:ClosePopup()
                if dd.onSelect then dd.onSelect(opt.value, opt.text) end
            end)
        end

        local totalH = PAD * 2 + count * ROW_H + (count - 1) * ROW_GAP
        scrollChild:SetHeight(totalH)
        local frameH = math.min(MAX_HEIGHT, math.max(ROW_H + 4, totalH))
        popup:SetHeight(frameH)

        local maxScroll = math.max(0, totalH - frameH)
        scrollBar:SetMinMaxValues(0, maxScroll)

        popup:ClearAllPoints()
        popup:SetWidth(width)
        popup:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
        popup:Show()
        popup:Raise()
        arrowTex:SetAtlas("common-button-collapseExpand-up")
        _openFontDropdown = dd
    end

    dd:SetScript("OnClick", function()
        if popup:IsShown() then
            dd:ClosePopup()
        else
            BuildAndShowPopup()
        end
    end)

    dd:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BTN_HOVER"))
        self:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
    end)
    dd:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BTN_NORMAL"))
        self:SetBackdropBorderColor(T("BTN_BORDER"))
    end)

    return dd
end

function ns.UI.CloseAllOpenDropdowns()
    if _openDropdown then _openDropdown:ClosePopup() end
    if _openFontDropdown then _openFontDropdown:ClosePopup() end
end

-- =============================================
-- THEMED DIALOG
-- A fully themed modal dialog without BasicFrameTemplate.
-- config: { name, title, width, height, buttons, onClose, destroyOnClose }
-- Returns frame with .content, .titleLabel
-- =============================================

local _themedDialogs = {}

function ns.UI.CreateThemedDialog(config)
    local dialogName    = config.name or "OneWoW_NotesThemedDialog"
    local width         = config.width  or 500
    local height        = config.height or 400
    local title         = config.title  or ""
    local destroyOnClose = config.destroyOnClose

    local cached = _themedDialogs[dialogName]
    if destroyOnClose and cached then
        cached:Hide()
        cached:SetParent(nil)
        _themedDialogs[dialogName] = nil
        cached = nil
    end
    if cached then
        if cached:IsShown() then cached:Raise() return cached end
        cached:Show()
        cached:Raise()
        return cached
    end

    local TITLE_H  = 20
    local FOOTER_H = config.buttons and #config.buttons > 0 and 44 or 0
    local EDGE     = S("XS")

    local frame = CreateFrame("Frame", dialogName, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(T("BG_PRIMARY"))
    frame:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    _themedDialogs[dialogName] = frame

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  EDGE, -EDGE)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -EDGE, -EDGE)
    titleBar:SetHeight(TITLE_H)
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    titleBar:SetBackdropColor(T("TITLEBAR_BG"))
    titleBar:SetFrameLevel(frame:GetFrameLevel() + 1)
    titleBar:EnableMouse(true)
    titleBar:SetScript("OnMouseDown", function() frame:StartMoving() end)
    titleBar:SetScript("OnMouseUp",   function() frame:StopMovingOrSizing() end)

    local titleLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("LEFT",  titleBar, "LEFT",  S("SM"), 0)
    titleLabel:SetPoint("RIGHT", titleBar, "RIGHT", -28, 0)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(title)
    titleLabel:SetTextColor(T("ACCENT_PRIMARY"))
    frame.titleLabel = titleLabel

    local closeBtn = ns.UI.CreateButton(nil, titleBar, "X", 20, 20)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -S("XS") / 2, 0)
    closeBtn:SetScript("OnClick", function()
        if config.onClose then config.onClose() end
        if destroyOnClose then
            frame:Hide()
            frame:SetParent(nil)
            _themedDialogs[dialogName] = nil
        else
            frame:Hide()
        end
    end)
    frame.closeBtn = closeBtn

    -- Footer
    if FOOTER_H > 0 then
        local footer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        footer:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  EDGE,  1)
        footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -EDGE, 1)
        footer:SetHeight(FOOTER_H)
        footer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        footer:SetBackdropColor(T("BG_SECONDARY"))
        frame.footer = footer

        local totalBtns = #config.buttons
        local btnW      = 100
        local btnGap    = 8
        local totalW    = totalBtns * btnW + (totalBtns - 1) * btnGap
        local startX    = (width - totalW) / 2

        for i, bc in ipairs(config.buttons) do
            local btn = ns.UI.CreateButton(nil, footer, bc.text, btnW, 30)
            btn:SetPoint("LEFT", footer, "LEFT", startX + (i - 1) * (btnW + btnGap), 0)
            btn:SetScript("OnClick", function()
                if bc.onClick then bc.onClick(frame) end
            end)
        end

        local footSep = frame:CreateTexture(nil, "BORDER")
        footSep:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  EDGE, FOOTER_H + 1)
        footSep:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -EDGE, FOOTER_H + 1)
        footSep:SetHeight(1)
        footSep:SetColorTexture(T("BORDER_DEFAULT"))
    end

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT",     frame, "TOPLEFT",     EDGE,  -(TITLE_H + EDGE + 2))
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -EDGE, (FOOTER_H > 0 and FOOTER_H + 2 or EDGE))
    frame.content = content

    if dialogName then
        tinsert(UISpecialFrames, dialogName)
    end

    frame:SetScript("OnHide", function()
        ns.UI.CloseAllOpenDropdowns()
    end)

    frame:Hide()
    return frame
end

function ns.UI.CreateCustomScroll(parent)
    local TRACK_WIDTH = 10

    local container = CreateFrame("Frame", nil, parent)

    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT",     container, "TOPLEFT",     0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -TRACK_WIDTH, 0)
    scrollFrame:EnableMouseWheel(true)

    local scrollTrack = CreateFrame("Frame", nil, container, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT",    container, "TOPRIGHT",    -2, 0)
    scrollTrack:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 0)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollTrack:SetBackdropColor(T("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(30)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollThumb:SetBackdropColor(T("ACCENT_PRIMARY"))

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    local function UpdateThumb()
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local scroll      = scrollFrame:GetVerticalScroll()
        local frameH      = scrollFrame:GetHeight()
        local contentH    = scrollChild:GetHeight()
        if scrollRange <= 0 or contentH <= 0 then
            scrollThumb:SetHeight(scrollTrack:GetHeight())
            scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
            return
        end
        local trackH  = scrollTrack:GetHeight()
        local thumbH  = math.max(20, (frameH / contentH) * trackH)
        scrollThumb:SetHeight(thumbH)
        local maxOffset = trackH - thumbH
        local pct       = scroll / scrollRange
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(pct * maxOffset))
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current   = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 40))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 40))
        end
        UpdateThumb()
    end)

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        UpdateThumb()
    end)

    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        scrollChild:SetWidth(width)
        UpdateThumb()
    end)

    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")
    scrollThumb:SetScript("OnMouseDown", function(self)
        self.dragging     = true
        self.dragStartY   = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnMouseUp",  function(self) self.dragging = false end)
    scrollThumb:SetScript("OnDragStop", function(self) self.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY      = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta     = self.dragStartY - curY
        local trackH    = scrollTrack:GetHeight()
        local thumbH    = self:GetHeight()
        local maxOffset = trackH - thumbH
        if maxOffset <= 0 then return end
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local newScroll   = self.dragStartScroll + (delta / maxOffset) * scrollRange
        scrollFrame:SetVerticalScroll(math.max(0, math.min(scrollRange, newScroll)))
        UpdateThumb()
    end)

    return {
        container   = container,
        scrollFrame = scrollFrame,
        scrollChild = scrollChild,
        UpdateThumb = UpdateThumb,
    }
end
