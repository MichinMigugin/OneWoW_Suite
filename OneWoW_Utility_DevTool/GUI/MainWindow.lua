local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local DEFAULT_THEME_ICON = OneWoW_GUI.Constants.DEFAULT_THEME_ICON

local UI = {
    tabs = {},
    currentTab = nil,
}
Addon.UI = UI

function UI:StyleContentPanel(panel)
    panel:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
end

function UI:Initialize()
    if self.mainFrame then return end

    local DU = Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
    local defaultW = DU.MAIN_FRAME_DEFAULT_WIDTH or 750
    local defaultH = DU.MAIN_FRAME_DEFAULT_HEIGHT or 450
    local resizeCap = DU.MAIN_FRAME_RESIZE_CAP or 0.95
    local TAB_GAP = DU.TAB_GAP or 4
    local TAB_HEIGHT = DU.TAB_HEIGHT or 28
    local NUM_TABS = DU.NUM_TABS or 8
    local TAB_FRAME = DU.TAB_INDEX_FRAME or 1
    local TAB_EVENTS = DU.TAB_INDEX_EVENTS or 2
    local TAB_LUA = DU.TAB_INDEX_LUA or 3
    local TAB_TEXTURES = DU.TAB_INDEX_TEXTURES or 4
    local TAB_COLORS = DU.TAB_INDEX_COLORS or 5
    local TAB_LAYOUT = DU.TAB_INDEX_LAYOUT or 6
    local TAB_MONITOR = DU.TAB_INDEX_MONITOR or 7
    local TAB_SETTINGS = DU.TAB_INDEX_SETTINGS or 8

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or DEFAULT_THEME_ICON
    local frame = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_UtilityDevToolFrame",
        width = defaultW,
        height = defaultH,
        backdrop = BACKDROP_INNER_NO_INSETS,
    })
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        frame:SetClampedToScreen(true)
    end)
    frame:SetClampedToScreen(true)
    frame:SetResizable(true)
    local maxW = math.floor(GetScreenWidth() * resizeCap)
    local maxH = math.floor(GetScreenHeight() * resizeCap)
    frame:SetResizeBounds(defaultW, defaultH, maxW, maxH)

    local resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeHandle:SetScript("OnMouseDown", function()
        frame:SetClampedToScreen(false)
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        frame:SetClampedToScreen(true)
    end)

    frame:Hide()

    local titleBar = OneWoW_GUI:CreateTitleBar(frame, {
        title = Addon.L and Addon.L["ADDON_TITLE"] or "DevTool",
        height = 20,
        showBrand = true,
        factionTheme = factionTheme,
        onClose = function() UI:Hide() end,
    })
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))

    tinsert(UISpecialFrames, "OneWoW_UtilityDevToolFrame")

    local tabLabels = {
        Addon.L["TAB_FRAME"],
        Addon.L["TAB_EVENTS"],
        Addon.L["TAB_LUA"],
        Addon.L["TAB_TEXTURES"],
        Addon.L["TAB_COLORS"],
        Addon.L["TAB_LAYOUT"],
        Addon.L["TAB_MONITOR"],
        Addon.L["TAB_SETTINGS"],
    }

    local tabButtons = {}
    local tabY = -(OneWoW_GUI:GetSpacing("XS") + 20 + OneWoW_GUI:GetSpacing("XS"))

    for i = 1, NUM_TABS do
        local btn = OneWoW_GUI:CreateButton(frame, { text = tabLabels[i], width = 90, height = TAB_HEIGHT })
        btn:SetID(i)
        btn.isSelected = false
        if i == TAB_FRAME then
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", OneWoW_GUI:GetSpacing("SM"), tabY)
        else
            btn:SetPoint("LEFT", tabButtons[i - 1], "RIGHT", TAB_GAP, 0)
        end
        local tabID = i
        btn:SetScript("OnClick", function() UI:SelectTab(tabID) end)
        btn:SetScript("OnEnter", function(self)
            if not self.isSelected then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if not self.isSelected then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end)
        btn:SetScript("OnMouseDown", function(self)
            if not self.isSelected then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
            end
        end)
        btn:SetScript("OnMouseUp", function(self)
            if not self.isSelected then
                if self:IsMouseOver() then
                    self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
                else
                    self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                end
            end
        end)
        tabButtons[i] = btn
    end

    local tab1, tab2, tab3, tab4, tab5, tab6, tab7, tab8 =
        tabButtons[1], tabButtons[2], tabButtons[3], tabButtons[4],
        tabButtons[5], tabButtons[6], tabButtons[7], tabButtons[8]

    local function ResizeTabButtons()
        local frameWidth = frame:GetWidth()
        local availWidth = frameWidth - OneWoW_GUI:GetSpacing("SM") * 2 - (NUM_TABS - 1) * TAB_GAP
        local tabWidth = math.floor(availWidth / NUM_TABS)
        for i = 1, NUM_TABS do
            tabButtons[i]:SetWidth(tabWidth)
        end
    end

    frame:HookScript("OnSizeChanged", function()
        ResizeTabButtons()
    end)
    ResizeTabButtons()

    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     OneWoW_GUI:GetSpacing("SM"), -(OneWoW_GUI:GetSpacing("XS") + 20 + OneWoW_GUI:GetSpacing("XS") + TAB_HEIGHT + OneWoW_GUI:GetSpacing("XS")))
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("SM"), OneWoW_GUI:GetSpacing("SM"))

    self.tabs[TAB_FRAME] = {button = tab1, content = self:CreateFrameInspectorTab(contentFrame)}
    self.tabs[TAB_EVENTS] = {button = tab2, content = self:CreateEventMonitorTab(contentFrame)}
    self.tabs[TAB_LUA] = {button = tab3, content = self:CreateLuaConsoleTab(contentFrame)}

    local disabledTab = CreateFrame("Frame", nil, contentFrame)
    disabledTab:SetAllPoints(contentFrame)
    disabledTab:Hide()
    self.tabs[TAB_TEXTURES] = {button = tab4, content = disabledTab}
    tab4:Disable()
    tab4.text:SetTextColor(0.4, 0.4, 0.4)
    tab4:SetScript("OnClick", nil)
    tab4:SetScript("OnEnter", nil)
    tab4:SetScript("OnLeave", nil)
    tab4:SetScript("OnMouseDown", nil)
    tab4:SetScript("OnMouseUp", nil)

    self.tabs[TAB_COLORS] = {button = tab5, content = self:CreateColorToolsTab(contentFrame)}
    self.tabs[TAB_LAYOUT] = {button = tab6, content = self:CreateLayoutTab(contentFrame)}
    self.tabs[TAB_MONITOR] = {button = tab7, content = self:CreateMonitorTab(contentFrame)}
    self.tabs[TAB_SETTINGS] = {button = tab8, content = self:CreateSettingsTab(contentFrame)}

    self.mainFrame = frame
    self.contentFrame = contentFrame

    if not OneWoW_GUI:RestoreWindowPosition(frame, Addon.db.position or {}) then
        frame:SetPoint("CENTER")
    end

    frame:SetScript("OnHide", function()
        Addon.db.position = Addon.db.position or {}
        OneWoW_GUI:SaveWindowPosition(frame, Addon.db.position)
        if Addon.FrameInspector then
            Addon.FrameInspector:ClearHighlight()
        end
    end)

    self:SelectTab(TAB_FRAME)
end

function UI:SelectTab(tabID)
    local DU = Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
    local TAB_TEXTURES = DU.TAB_INDEX_TEXTURES or 4
    local TAB_EVENTS = DU.TAB_INDEX_EVENTS or 2

    if tabID == TAB_TEXTURES then return end
    self.currentTab = tabID

    for id, tab in pairs(self.tabs) do
        if id == TAB_TEXTURES then
            tab.content:Hide()
        elseif id == tabID then
            tab.content:Show()
            if id == TAB_EVENTS and Addon.EventMonitor then
                Addon.EventMonitor:UpdateUI()
            end
            tab.button.isSelected = true
            tab.button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            tab.button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            tab.button.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            tab.content:Hide()
            tab.button.isSelected = false
            tab.button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            tab.button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            tab.button.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end
end

function UI:Show()
    self:Initialize()
    self.mainFrame:Show()
end

function UI:Hide()
    if self.mainFrame then
        self.mainFrame:Hide()
    end
end

function UI:FullReset()
    if self.mainFrame then
        self.mainFrame:Hide()
        self.mainFrame = nil
    end
end
