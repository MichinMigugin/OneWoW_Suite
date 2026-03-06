-- OneWoW Addon File
-- OneWoW_Catalog/UI/Framework.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

function ns.UI.CreateScrollFrame(name, parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -5, 5)

    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -3, 0)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -3, 0)
        scrollBar:SetWidth(8)
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

    local contentName = name and (name .. "Content") or nil
    local content = CreateFrame("Frame", contentName, scrollFrame)
    content:SetWidth((width or 800) - 20)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    return scrollFrame, content
end

function ns.UI.CreateSectionHeader(parent, title, yOffset)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", 8, yOffset)
    section:SetPoint("TOPRIGHT", -8, yOffset)
    section:SetHeight(30)
    section:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    section:SetBackdropColor(T("BG_SECONDARY"))
    section:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local titleText = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", 12, 0)
    titleText:SetText(title)
    titleText:SetTextColor(T("ACCENT_PRIMARY"))

    section.bottomY = yOffset - 30

    return section
end

function ns.UI.CreateButton(name, parent, text, width, height)
    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetSize(width or 100, height or ns.Constants.GUI.BUTTON_HEIGHT)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    btn:SetBackdropColor(T("BTN_NORMAL"))
    btn:SetBackdropBorderColor(T("BTN_BORDER"))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text or "")
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

function ns.UI.CreateSplitPanel(parent)
    local listPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 35)
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

    local listContainer = CreateFrame("Frame", nil, listPanel)
    listContainer:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, -32)
    listContainer:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -8, 8)

    local listScrollFrame = CreateFrame("ScrollFrame", nil, listContainer, "UIPanelScrollFrameTemplate")
    listScrollFrame:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, 0)
    listScrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -14, 0)

    local listScrollBar = listScrollFrame.ScrollBar
    if listScrollBar then
        listScrollBar:ClearAllPoints()
        listScrollBar:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", -2, 0)
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

    local listScrollChild = CreateFrame("Frame", nil, listScrollFrame)
    listScrollChild:SetHeight(1)
    listScrollFrame:SetScrollChild(listScrollChild)

    listScrollFrame:HookScript("OnSizeChanged", function(self, w)
        listScrollChild:SetWidth(w)
    end)

    local detailPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detailPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", ns.Constants.GUI.PANEL_GAP, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 35)
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

    local detailContainer = CreateFrame("Frame", nil, detailPanel)
    detailContainer:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 8, -32)
    detailContainer:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 8)

    local detailScrollFrame = CreateFrame("ScrollFrame", nil, detailContainer, "UIPanelScrollFrameTemplate")
    detailScrollFrame:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 0, 0)
    detailScrollFrame:SetPoint("BOTTOMRIGHT", detailContainer, "BOTTOMRIGHT", -14, 0)

    local detailScrollBar = detailScrollFrame.ScrollBar
    if detailScrollBar then
        detailScrollBar:ClearAllPoints()
        detailScrollBar:SetPoint("TOPRIGHT", detailContainer, "TOPRIGHT", -2, 0)
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

    local detailScrollChild = CreateFrame("Frame", nil, detailScrollFrame)
    detailScrollChild:SetHeight(1)
    detailScrollFrame:SetScrollChild(detailScrollChild)

    detailScrollFrame:HookScript("OnSizeChanged", function(self, w)
        detailScrollChild:SetWidth(w)
    end)

    local function noop() end

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
