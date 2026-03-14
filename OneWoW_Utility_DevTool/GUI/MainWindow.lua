local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

local GUI = Addon.GUI or {}
Addon.GUI = GUI

local UI = {}
Addon.UI = UI

UI.tabs = {}
UI.currentTab = nil

local function StyleContentPanel(panel)
    panel:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
end

function UI:Initialize()
    if self.mainFrame then return end

    local frame = CreateFrame("Frame", "OneWoW_UtilityDevToolFrame", UIParent, "BackdropTemplate")
    frame:SetSize(750, 450)
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
    local maxW = math.floor(GetScreenWidth() * 0.95)
    local maxH = math.floor(GetScreenHeight() * 0.95)
    frame:SetResizeBounds(750, 450, maxW, maxH)

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

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetHeight(20)
    titleBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    titleBar:SetBackdrop(BACKDROP_SIMPLE)
    titleBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))
    titleBar:SetFrameLevel(frame:GetFrameLevel() + 1)

    local factionTheme = Addon.db and Addon.db.minimap and Addon.db.minimap.theme or "horde"
    local brandIconTex
    if factionTheme == "alliance" then
        brandIconTex = "Interface\\AddOns\\OneWoW_Utility_DevTool\\Media\\alliance-mini.png"
    elseif factionTheme == "neutral" then
        brandIconTex = "Interface\\AddOns\\OneWoW_Utility_DevTool\\Media\\neutral-mini.png"
    else
        brandIconTex = "Interface\\AddOns\\OneWoW_Utility_DevTool\\Media\\horde-mini.png"
    end

    local brandIcon = titleBar:CreateTexture(nil, "OVERLAY")
    brandIcon:SetSize(14, 14)
    brandIcon:SetPoint("LEFT", titleBar, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
    brandIcon:SetTexture(brandIconTex)

    local brandText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    brandText:SetPoint("LEFT", brandIcon, "RIGHT", 4, 0)
    brandText:SetText("OneWoW")
    brandText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    titleText:SetText(Addon.L and Addon.L["ADDON_TITLE"] or "DevTool")
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local closeBtn = OneWoW_GUI:CreateButton(titleBar, { text = "X", width = 20, height = 20 })
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -OneWoW_GUI:GetSpacing("XS") / 2, 0)
    closeBtn:SetScript("OnClick", function() UI:Hide() end)

    tinsert(UISpecialFrames, "OneWoW_UtilityDevToolFrame")

    local TAB_GAP = 4
    local TAB_HEIGHT = 28
    local NUM_TABS = 8
    local tabLabels = {
        Addon.L and Addon.L["TAB_FRAME"] or "Frame",
        Addon.L and Addon.L["TAB_EVENTS"] or "Events",
        Addon.L and Addon.L["TAB_LUA"] or "Lua",
        Addon.L and Addon.L["TAB_TEXTURES"] or "Textures",
        Addon.L and Addon.L["TAB_COLORS"] or "Colors",
        Addon.L and Addon.L["TAB_LAYOUT"] or "Layout",
        Addon.L and Addon.L["TAB_MONITOR"] or "Monitor",
        "Settings",
    }

    local tabButtons = {}
    local tabY = -(OneWoW_GUI:GetSpacing("XS") + 20 + OneWoW_GUI:GetSpacing("XS"))

    for i = 1, NUM_TABS do
        local btn = OneWoW_GUI:CreateButton(frame, { text = tabLabels[i], width = 90, height = TAB_HEIGHT })
        btn:SetID(i)
        btn.isSelected = false
        if i == 1 then
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

    self.tabs[1] = {button = tab1, content = self:CreateFrameInspectorTab(contentFrame)}
    self.tabs[2] = {button = tab2, content = self:CreateEventMonitorTab(contentFrame)}
    self.tabs[3] = {button = tab3, content = self:CreateLuaConsoleTab(contentFrame)}

    local disabledTab = CreateFrame("Frame", nil, contentFrame)
    disabledTab:SetAllPoints(contentFrame)
    disabledTab:Hide()
    self.tabs[4] = {button = tab4, content = disabledTab}
    tab4:Disable()
    tab4.text:SetTextColor(0.4, 0.4, 0.4)
    tab4:SetScript("OnClick", nil)
    tab4:SetScript("OnEnter", nil)
    tab4:SetScript("OnLeave", nil)
    tab4:SetScript("OnMouseDown", nil)
    tab4:SetScript("OnMouseUp", nil)

    self.tabs[5] = {button = tab5, content = self:CreateColorTab(contentFrame)}
    self.tabs[6] = {button = tab6, content = self:CreateLayoutTab(contentFrame)}
    self.tabs[7] = {button = tab7, content = self:CreateMonitorTab(contentFrame)}
    self.tabs[8] = {button = tab8, content = self:CreateSettingsTab(contentFrame)}

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

    self:SelectTab(1)
end

function UI:SelectTab(tabID)
    if tabID == 4 then return end
    self.currentTab = tabID

    for id, tab in pairs(self.tabs) do
        if id == 4 then
            tab.content:Hide()
        elseif id == tabID then
            tab.content:Show()
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

function UI:CreateFrameInspectorTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local pickBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_PICK_FRAME"] or "Pick Frame", width = 100, height = 22 })
    pickBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    pickBtn:SetScript("OnClick", function()
        if Addon.FramePicker then
            Addon.FramePicker:Start()
        end
    end)

    local searchBox = CreateFrame("EditBox", nil, tab, "InputBoxTemplate")
    searchBox:SetSize(150, 22)
    searchBox:SetPoint("LEFT", pickBtn, "RIGHT", 10, 0)
    searchBox:SetAutoFocus(false)

    local searchBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_SEARCH"] or "Search", width = 70, height = 22 })
    searchBtn:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)

    local leftPanel = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    leftPanel:SetPoint("TOPLEFT", pickBtn, "BOTTOMLEFT", 0, -5)
    leftPanel:SetPoint("BOTTOM", tab, "BOTTOM", 0, 5)
    leftPanel:SetWidth(350)
    StyleContentPanel(leftPanel)

    local leftTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftTitle:SetPoint("TOP", leftPanel, "TOP", 0, -5)
    leftTitle:SetText(Addon.L and Addon.L["LABEL_FRAME_HIERARCHY"] or "Frame Hierarchy")
    leftTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local copyHierarchyBtn = OneWoW_GUI:CreateButton(leftPanel, { text = Addon.L and Addon.L["BTN_COPY_HIERARCHY"] or "Copy All", width = 70, height = 18 })
    copyHierarchyBtn:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -25, -3)
    copyHierarchyBtn:SetScript("OnClick", function()
        if tab.hierarchyText then
            Addon:CopyToClipboard(tab.hierarchyText:GetText())
        end
    end)

    local leftScroll = CreateFrame("ScrollFrame", nil, leftPanel, "UIPanelScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 4, -25)
    leftScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -14, 4)
    OneWoW_GUI:StyleScrollBar(leftScroll, { container = leftPanel })

    local leftContent = CreateFrame("Frame", nil, leftScroll)
    leftContent:SetHeight(1)
    leftScroll:SetScrollChild(leftContent)

    leftScroll:HookScript("OnSizeChanged", function(self, w)
        leftContent:SetWidth(w)
    end)

    tab.hierarchyText = leftContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.hierarchyText:SetPoint("TOPLEFT", 2, -2)
    tab.hierarchyText:SetPoint("RIGHT", leftContent, "RIGHT", -2, 0)
    tab.hierarchyText:SetJustifyH("LEFT")
    tab.hierarchyText:SetText(Addon.L and Addon.L["LABEL_NO_FRAME"] or "No frame selected")
    tab.hierarchyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local rightPanel = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 5, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    StyleContentPanel(rightPanel)

    local rightTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightTitle:SetPoint("TOP", rightPanel, "TOP", 0, -5)
    rightTitle:SetText(Addon.L and Addon.L["LABEL_FRAME_DETAILS"] or "Frame Details")
    rightTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local copyDetailsBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_COPY_DETAILS"] or "Copy All", width = 70, height = 18 })
    copyDetailsBtn:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -25, -3)
    copyDetailsBtn:SetScript("OnClick", function()
        if tab.detailsText then
            Addon:CopyToClipboard(tab.detailsText:GetText())
        end
    end)

    local rightScroll = CreateFrame("ScrollFrame", nil, rightPanel, "UIPanelScrollFrameTemplate")
    rightScroll:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 4, -25)
    rightScroll:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -14, 4)
    OneWoW_GUI:StyleScrollBar(rightScroll, { container = rightPanel })

    local rightContent = CreateFrame("Frame", nil, rightScroll)
    rightContent:SetHeight(1)
    rightScroll:SetScrollChild(rightContent)

    rightScroll:HookScript("OnSizeChanged", function(self, w)
        rightContent:SetWidth(w)
    end)

    tab.detailsText = rightContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.detailsText:SetPoint("TOPLEFT", 2, -2)
    tab.detailsText:SetPoint("RIGHT", rightContent, "RIGHT", -2, 0)
    tab.detailsText:SetJustifyH("LEFT")
    tab.detailsText:SetText(Addon.L and Addon.L["LABEL_NO_FRAME"] or "No frame selected")
    tab.detailsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    tab.leftScroll = leftScroll
    tab.rightScroll = rightScroll

    function tab:UpdateFrameDetails(frame, info)
        if not info then return end
        local L = Addon.L or {}

        local lines = {}
        table.insert(lines, (L["LABEL_NAME"] or "NAME:") .. " " .. (info.name or L["LABEL_ANONYMOUS"] or "Anonymous"))
        table.insert(lines, (L["LABEL_TYPE"] or "TYPE:") .. " " .. (info.type or L["LABEL_UNKNOWN"] or "Unknown"))
        table.insert(lines, "")
        table.insert(lines, (L["LABEL_SHOWN"] or "SHOWN:") .. " " .. (info.shown and (L["LABEL_YES"] or "Yes") or (L["LABEL_NO"] or "No")))
        table.insert(lines, (L["LABEL_MOUSE"] or "MOUSE:") .. " " .. (info.mouse and (L["LABEL_YES"] or "Yes") or (L["LABEL_NO"] or "No")))
        table.insert(lines, "")

        if info.width and info.height then
            table.insert(lines, string.format((L["LABEL_SIZE"] or "SIZE:") .. " %.0f x %.0f", info.width, info.height))
        end

        if info.strata then
            table.insert(lines, (L["LABEL_STRATA"] or "STRATA:") .. " " .. info.strata)
        end

        if info.level then
            table.insert(lines, (L["LABEL_LEVEL"] or "LEVEL:") .. " " .. info.level)
        end

        table.insert(lines, "")

        if info.points and #info.points > 0 then
            table.insert(lines, L["LABEL_ANCHORS"] or "ANCHORS:")
            for i, point in ipairs(info.points) do
                table.insert(lines, string.format("  %s to %s %s (%.0f, %.0f)",
                    point.point, point.relativeTo, point.relativePoint or "", point.x or 0, point.y or 0))
            end
        end

        self.detailsText:SetText(table.concat(lines, "\n"))

        local height = self.detailsText:GetStringHeight()
        self.rightScroll:GetScrollChild():SetHeight(math.max(height + 10, self.rightScroll:GetHeight()))
    end

    function tab:UpdateFrameTree(frame)
        if not frame then return end
        local L = Addon.L or {}

        local lines = {}

        local parentChain = {}
        local current = frame
        while current do
            table.insert(parentChain, 1, current)
            current = current.GetParent and current:GetParent()
        end

        for i, f in ipairs(parentChain) do
            local indent = string.rep("  ", i - 1)
            local name = f.GetName and f:GetName() or L["LABEL_ANONYMOUS"] or "Anonymous"
            if f == frame then
                name = "[" .. name .. "]"
            end
            table.insert(lines, indent .. name)
        end

        table.insert(lines, "")
        table.insert(lines, L["LABEL_CHILDREN"] or "CHILDREN:")

        local children = frame.GetChildren and {frame:GetChildren()} or {}
        for _, child in ipairs(children) do
            local name = child.GetName and child:GetName() or L["LABEL_ANONYMOUS"] or "Anonymous"
            table.insert(lines, "  - " .. name)
        end

        self.hierarchyText:SetText(table.concat(lines, "\n"))

        local height = self.hierarchyText:GetStringHeight()
        self.leftScroll:GetScrollChild():SetHeight(math.max(height + 10, self.leftScroll:GetHeight()))
    end

    Addon.FrameInspectorTab = tab
    return tab
end

function UI:CreateEventMonitorTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local startBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_START"] or "Start", width = 80, height = 22 })
    startBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    startBtn:SetScript("OnClick", function()
        if Addon.EventMonitor then
            Addon.EventMonitor:Start()
        end
    end)

    local stopBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_STOP"] or "Stop", width = 80, height = 22 })
    stopBtn:SetPoint("LEFT", startBtn, "RIGHT", 5, 0)
    stopBtn:SetScript("OnClick", function()
        if Addon.EventMonitor then
            Addon.EventMonitor:Stop()
        end
    end)

    local clearBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_CLEAR"] or "Clear", width = 80, height = 22 })
    clearBtn:SetPoint("LEFT", stopBtn, "RIGHT", 5, 0)
    clearBtn:SetScript("OnClick", function()
        if Addon.EventMonitor then
            Addon.EventMonitor:Clear()
        end
    end)

    local configBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_SELECT_EVENTS"] or "Select Events", width = 100, height = 22 })
    configBtn:SetPoint("LEFT", clearBtn, "RIGHT", 5, 0)
    configBtn:SetScript("OnClick", function()
        UI:ShowEventSelector()
    end)

    local importBtn = OneWoW_GUI:CreateButton(tab, { text = "Import Events", width = 110, height = 22 })
    importBtn:SetPoint("LEFT", configBtn, "RIGHT", 5, 0)
    importBtn:SetScript("OnClick", function()
        UI:ShowEventImportDialog()
    end)

    local firehoseBtn = OneWoW_GUI:CreateButton(tab, { text = "Firehose", width = 90, height = 22 })
    firehoseBtn:SetPoint("LEFT", importBtn, "RIGHT", 5, 0)
    firehoseBtn:SetScript("OnClick", function()
        if Addon.EventMonitor then
            Addon.EventMonitor:FirehoseToggle()
        end
    end)

    local filterLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("TOPLEFT", startBtn, "BOTTOMLEFT", 0, -8)
    filterLabel:SetText(Addon.L and Addon.L["LABEL_FILTER"] or "Filter:")
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local filterBox = CreateFrame("EditBox", nil, tab, "InputBoxTemplate")
    filterBox:SetSize(150, 22)
    filterBox:SetPoint("LEFT", filterLabel, "RIGHT", 5, 0)
    filterBox:SetAutoFocus(false)
    filterBox:SetScript("OnTextChanged", function()
        if Addon.EventMonitor then
            Addon.EventMonitor:UpdateUI()
        end
    end)

    local panel = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", startBtn, "BOTTOMLEFT", 0, -35)
    panel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    StyleContentPanel(panel)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 4)
    OneWoW_GUI:StyleScrollBar(scroll, { container = panel })

    local content = CreateFrame("Frame", nil, scroll)
    content:SetHeight(1)
    scroll:SetScrollChild(content)

    scroll:HookScript("OnSizeChanged", function(self, w)
        content:SetWidth(w)
    end)

    tab.logText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.logText:SetPoint("TOPLEFT", 2, -2)
    tab.logText:SetPoint("RIGHT", content, "RIGHT", -2, 0)
    tab.logText:SetJustifyH("LEFT")
    local L = Addon.L or {}
    tab.logText:SetText((L["MSG_CLICK_START"] or "Click 'Start' to begin monitoring (auto-selects common events)\nOr click 'Select Events' to customize"))
    tab.logText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    tab.startBtn = startBtn
    tab.stopBtn = stopBtn
    tab.firehoseBtn = firehoseBtn
    tab.filterBox = filterBox
    tab.scroll = scroll

    stopBtn:Disable()

    Addon.EventMonitorTab = tab
    return tab
end

function UI:CreateLuaConsoleTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local clearBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_CLEAR"] or "Clear", width = 80, height = 22 })
    clearBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    clearBtn:SetScript("OnClick", function()
        if Addon.ErrorLogger then
            Addon.ErrorLogger:ClearErrors()
        end
    end)

    local countLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countLabel:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
    countLabel:SetText((Addon.L and Addon.L["LABEL_ERRORS"] or "Errors:") .. " 0")
    countLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local soundCheck = CreateFrame("CheckButton", nil, tab, "UICheckButtonTemplate")
    soundCheck:SetSize(22, 22)
    soundCheck:SetPoint("LEFT", countLabel, "RIGHT", 15, 0)
    soundCheck:SetChecked(Addon.db and Addon.db.errorDB and Addon.db.errorDB.playSound or false)
    soundCheck:SetScript("OnClick", function(self)
        if Addon.db and Addon.db.errorDB then
            Addon.db.errorDB.playSound = self:GetChecked() and true or false
        end
    end)

    local soundLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    soundLabel:SetPoint("LEFT", soundCheck, "RIGHT", 2, 0)
    soundLabel:SetText(Addon.L and Addon.L["ERR_PLAY_ALERT"] or "Play Alert")
    soundLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local listPanel = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", clearBtn, "BOTTOMLEFT", 0, -5)
    listPanel:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -5, 0)
    listPanel:SetHeight(250)
    StyleContentPanel(listPanel)

    local listScroll = CreateFrame("ScrollFrame", nil, listPanel, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -14, 4)
    OneWoW_GUI:StyleScrollBar(listScroll, { container = listPanel })

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetHeight(1)
    listScroll:SetScrollChild(listContent)

    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
    end)

    tab.errorButtons = {}
    for i = 1, 100 do
        local btn = CreateFrame("Button", nil, listContent)
        btn:SetHeight(20)
        btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(i-1) * 20 - 2)
        btn:SetPoint("RIGHT", listContent, "RIGHT", 0, 0)
        btn:SetNormalFontObject(GameFontNormalSmall)
        btn:SetHighlightFontObject(GameFontHighlightSmall)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        btn.bg:SetAlpha(0.3)

        btn:SetScript("OnClick", function(self)
            if Addon.ErrorLogger and self.errorData then
                Addon.ErrorLogger:ShowErrorDetails(self.errorData)
            end
        end)

        tab.errorButtons[i] = btn
    end

    local detailsPanel = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    detailsPanel:SetPoint("TOPLEFT", listPanel, "BOTTOMLEFT", 0, -5)
    detailsPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 35)
    StyleContentPanel(detailsPanel)

    local detailsScroll = CreateFrame("ScrollFrame", nil, detailsPanel, "UIPanelScrollFrameTemplate")
    detailsScroll:SetPoint("TOPLEFT", detailsPanel, "TOPLEFT", 4, -4)
    detailsScroll:SetPoint("BOTTOMRIGHT", detailsPanel, "BOTTOMRIGHT", -14, 4)
    OneWoW_GUI:StyleScrollBar(detailsScroll, { container = detailsPanel })

    local detailsContent = CreateFrame("Frame", nil, detailsScroll)
    detailsContent:SetHeight(1)
    detailsScroll:SetScrollChild(detailsContent)

    detailsScroll:HookScript("OnSizeChanged", function(self, w)
        detailsContent:SetWidth(w)
    end)

    tab.detailsText = detailsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.detailsText:SetPoint("TOPLEFT", 2, -2)
    tab.detailsText:SetPoint("RIGHT", detailsContent, "RIGHT", -2, 0)
    tab.detailsText:SetJustifyH("LEFT")
    tab.detailsText:SetText(Addon.L and Addon.L["LABEL_NO_ERROR"] or "No error selected")
    tab.detailsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local copyBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_COPY_ERROR"] or "Copy Error", width = 100, height = 25 })
    copyBtn:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 5, 5)
    copyBtn:SetScript("OnClick", function()
        if Addon.ErrorLogger then
            Addon.ErrorLogger:CopyCurrentError()
        end
    end)

    tab.listScroll = listScroll
    tab.detailsScroll = detailsScroll
    tab.countLabel = countLabel

    tab:SetScript("OnShow", function()
        if Addon.ErrorLogger then
            Addon.ErrorLogger:UpdateUI()
        end
    end)

    Addon.LuaConsoleTab = tab
    return tab
end

function UI:CreateTextureTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    tab.atlasList = Addon:LoadBuiltInAtlases()
    tab.filteredList = {}
    for _, name in ipairs(tab.atlasList) do
        table.insert(tab.filteredList, name)
    end

    local searchBox = CreateFrame("EditBox", nil, tab, "InputBoxTemplate")
    searchBox:SetSize(200, 22)
    searchBox:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        UI:FilterAtlases(self:GetText())
    end)

    local favsBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_FAVORITES"] or "Favorites", width = 100, height = 22 })
    favsBtn:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)
    favsBtn:SetScript("OnClick", function()
        UI:ShowFavorites()
    end)

    local bookmarkBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_BOOKMARK"] or "Bookmark", width = 100, height = 22 })
    bookmarkBtn:SetPoint("LEFT", favsBtn, "RIGHT", 5, 0)
    bookmarkBtn:SetScript("OnClick", function()
        UI:ToggleBookmark()
    end)

    local leftPanel = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    leftPanel:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -5)
    leftPanel:SetPoint("BOTTOM", tab, "BOTTOM", 0, 5)
    leftPanel:SetWidth(320)
    StyleContentPanel(leftPanel)

    local listScroll = CreateFrame("ScrollFrame", nil, leftPanel, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", -14, 4)
    OneWoW_GUI:StyleScrollBar(listScroll, { container = leftPanel })

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetHeight(1)
    listScroll:SetScrollChild(listContent)

    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
    end)

    tab.listButtons = {}
    for i = 1, 30 do
        local btn = CreateFrame("Button", nil, listContent)
        btn:SetHeight(18)
        btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(i-1) * 18)
        btn:SetPoint("RIGHT", listContent, "RIGHT", 0, 0)
        btn:SetNormalFontObject(GameFontNormalSmall)
        btn:SetHighlightFontObject(GameFontHighlightSmall)

        btn:SetScript("OnClick", function(self)
            if self.atlasName then
                UI:SelectAtlas(self.atlasName)
            end
        end)

        tab.listButtons[i] = btn
    end

    local rightPanel = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 5, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    StyleContentPanel(rightPanel)

    tab.nameText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tab.nameText:SetPoint("TOP", 0, -5)
    tab.nameText:SetText("")
    tab.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local zoomInBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_ZOOM_IN"] or "+", width = 40, height = 22 })
    zoomInBtn:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -5, -5)
    zoomInBtn:SetScript("OnClick", function()
        UI:ZoomTexture(1.2)
    end)

    local zoomOutBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_ZOOM_OUT"] or "-", width = 40, height = 22 })
    zoomOutBtn:SetPoint("RIGHT", zoomInBtn, "LEFT", -2, 0)
    zoomOutBtn:SetScript("OnClick", function()
        UI:ZoomTexture(0.8)
    end)

    local resetBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_RESET_ZOOM"] or "Reset", width = 60, height = 22 })
    resetBtn:SetPoint("RIGHT", zoomOutBtn, "LEFT", -2, 0)
    resetBtn:SetScript("OnClick", function()
        UI:ResetTextureZoom()
    end)

    local previewBg = rightPanel:CreateTexture(nil, "BACKGROUND")
    previewBg:SetPoint("TOP", tab.nameText, "BOTTOM", 0, -10)
    previewBg:SetSize(400, 400)
    previewBg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))

    tab.previewFrame = CreateFrame("Frame", nil, rightPanel)
    tab.previewFrame:SetPoint("CENTER", previewBg, "CENTER")
    tab.previewFrame:SetSize(256, 256)

    tab.preview = tab.previewFrame:CreateTexture(nil, "ARTWORK")
    tab.preview:SetAllPoints(tab.previewFrame)

    local border = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    border:SetPoint("TOPLEFT", previewBg, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", previewBg, "BOTTOMRIGHT", 1, -1)
    border:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    border:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    border:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local infoPanel = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    infoPanel:SetPoint("TOPLEFT", previewBg, "BOTTOMLEFT", 0, -10)
    infoPanel:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -5, 35)
    StyleContentPanel(infoPanel)

    local infoScroll = CreateFrame("ScrollFrame", nil, infoPanel, "UIPanelScrollFrameTemplate")
    infoScroll:SetPoint("TOPLEFT", 4, -4)
    infoScroll:SetPoint("BOTTOMRIGHT", -14, 4)
    OneWoW_GUI:StyleScrollBar(infoScroll, { container = infoPanel })

    local infoContent = CreateFrame("Frame", nil, infoScroll)
    infoContent:SetHeight(1)
    infoScroll:SetScrollChild(infoContent)

    infoScroll:HookScript("OnSizeChanged", function(self, w)
        infoContent:SetWidth(w)
    end)

    tab.infoText = infoContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.infoText:SetPoint("TOPLEFT", 2, -2)
    tab.infoText:SetPoint("RIGHT", infoContent, "RIGHT", -2, 0)
    tab.infoText:SetJustifyH("LEFT")
    tab.infoText:SetText("")
    tab.infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    tab.infoScroll = infoScroll

    local copyBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_COPY_NAME"] or "Copy Name", width = 100, height = 22 })
    copyBtn:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 5, 5)
    copyBtn:SetScript("OnClick", function()
        if tab.currentAtlas then
            Addon:CopyToClipboard(tab.currentAtlas)
        end
    end)

    tab.listScroll = listScroll
    tab.zoomLevel = 1.0
    tab.selectedIndex = 1

    tab:SetScript("OnKeyDown", function(self, key)
        if key == "UP" then
            UI:NavigateAtlasList(-1)
        elseif key == "DOWN" then
            UI:NavigateAtlasList(1)
        end
    end)

    tab:EnableKeyboard(true)
    tab:SetPropagateKeyboardInput(false)

    self:UpdateAtlasList()

    if #tab.atlasList > 0 then
        self:SelectAtlas(tab.atlasList[1])
    end

    Addon.TextureBrowserTab = tab
    return tab
end

function UI:NavigateAtlasList(direction)
    local tab = Addon.TextureBrowserTab
    if not tab or #tab.filteredList == 0 then return end

    tab.selectedIndex = tab.selectedIndex + direction

    if tab.selectedIndex < 1 then
        tab.selectedIndex = 1
    elseif tab.selectedIndex > #tab.filteredList then
        tab.selectedIndex = #tab.filteredList
    end

    local atlasName = tab.filteredList[tab.selectedIndex]
    if atlasName then
        self:SelectAtlas(atlasName)
        self:UpdateAtlasList()
    end
end

function UI:ZoomTexture(factor)
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    tab.zoomLevel = tab.zoomLevel * factor
    tab.zoomLevel = math.max(0.25, math.min(4.0, tab.zoomLevel))

    local newSize = 256 * tab.zoomLevel
    tab.previewFrame:SetSize(newSize, newSize)
end

function UI:ResetTextureZoom()
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    tab.zoomLevel = 1.0
    tab.previewFrame:SetSize(256, 256)
end

function UI:FilterAtlases(filter)
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    filter = (filter or ""):lower()
    tab.filteredList = {}

    if filter == "" then
        for _, name in ipairs(tab.atlasList) do
            table.insert(tab.filteredList, name)
        end
    else
        for _, name in ipairs(tab.atlasList) do
            if name:lower():find(filter, 1, true) then
                table.insert(tab.filteredList, name)
            end
        end
    end

    self:UpdateAtlasList()
end

function UI:UpdateAtlasList()
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    for i, btn in ipairs(tab.listButtons) do
        local name = tab.filteredList[i]
        if name then
            btn:SetText(name)
            btn.atlasName = name

            if name == tab.currentAtlas then
                btn:SetNormalFontObject(GameFontHighlight)
                btn:LockHighlight()
            else
                btn:SetNormalFontObject(GameFontNormalSmall)
                btn:UnlockHighlight()
            end

            btn:Show()
        else
            btn:Hide()
        end
    end

    local height = math.max(#tab.filteredList * 18 + 5, tab.listScroll:GetHeight())
    tab.listScroll:GetScrollChild():SetHeight(height)
end

function UI:SelectAtlas(atlasName)
    local tab = Addon.TextureBrowserTab
    if not tab then return end
    local L = Addon.L or {}

    for i, name in ipairs(tab.filteredList) do
        if name == atlasName then
            tab.selectedIndex = i
            break
        end
    end

    local info = C_Texture.GetAtlasInfo(atlasName)

    if info then
        tab.currentAtlas = atlasName
        tab.preview:SetAtlas(atlasName)
        tab.preview:Show()
        tab.nameText:SetText(atlasName)

        self:UpdateAtlasList()

        local isBookmarked = Addon.db.textureBookmarks and Addon.db.textureBookmarks[atlasName]

        local details = {}
        table.insert(details, (L["LABEL_WIDTH"] or "Width:") .. " " .. (info.width or 0))
        table.insert(details, (L["LABEL_HEIGHT"] or "Height:") .. " " .. (info.height or 0))
        table.insert(details, "")
        table.insert(details, (L["LABEL_FILE"] or "File:") .. " " .. (info.file or info.filename or L["LABEL_UNKNOWN"] or "Unknown"))

        if info.leftTexCoord then
            table.insert(details, "")
            table.insert(details, L["LABEL_TEX_COORDS"] or "Texture Coordinates:")
            table.insert(details, string.format((L["LABEL_LEFT"] or "  Left:") .. " %.4f", info.leftTexCoord))
            table.insert(details, string.format((L["LABEL_RIGHT"] or "  Right:") .. " %.4f", info.rightTexCoord))
            table.insert(details, string.format((L["LABEL_TOP"] or "  Top:") .. " %.4f", info.topTexCoord))
            table.insert(details, string.format((L["LABEL_BOTTOM"] or "  Bottom:") .. " %.4f", info.bottomTexCoord))
        end

        if info.tilesHorizontally or info.tilesVertically then
            table.insert(details, "")
            table.insert(details, string.format((L["LABEL_TILES"] or "Tiles:") .. " %s x %s",
                tostring(info.tilesHorizontally or false),
                tostring(info.tilesVertically or false)))
        end

        if isBookmarked then
            table.insert(details, "")
            table.insert(details, "|cff00ff00[" .. (L["LABEL_BOOKMARKED"] or "Bookmarked") .. "]|r")
        end

        tab.infoText:SetText(table.concat(details, "\n"))

        local height = tab.infoText:GetStringHeight()
        tab.infoScroll:GetScrollChild():SetHeight(math.max(height + 10, tab.infoScroll:GetHeight()))
    end
end

function UI:ToggleBookmark()
    local tab = Addon.TextureBrowserTab
    if not tab or not tab.currentAtlas then
        Addon:Print(Addon.L and Addon.L["MSG_SELECT_ATLAS"] or "Select an atlas first")
        return
    end

    if not Addon.db.textureBookmarks then
        Addon.db.textureBookmarks = {}
    end

    local name = tab.currentAtlas

    if Addon.db.textureBookmarks[name] then
        Addon.db.textureBookmarks[name] = nil
        Addon:Print((Addon.L and Addon.L["MSG_REMOVED_BOOKMARK"] or "Removed: ") .. name)
    else
        Addon.db.textureBookmarks[name] = true
        Addon:Print((Addon.L and Addon.L["MSG_BOOKMARKED"] or "Bookmarked: ") .. name)
    end

    self:SelectAtlas(name)
end

function UI:ShowFavorites()
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    if not Addon.db.textureBookmarks then
        Addon:Print(Addon.L and Addon.L["MSG_NO_BOOKMARKS"] or "No bookmarks yet")
        return
    end

    tab.filteredList = {}
    for name, _ in pairs(Addon.db.textureBookmarks) do
        table.insert(tab.filteredList, name)
    end

    table.sort(tab.filteredList)
    self:UpdateAtlasList()
end

function UI:CreateColorTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    if Addon.ColorToolsTab and Addon.ColorToolsTab.Initialize then
        Addon.ColorToolsTab:Initialize(tab)
    end

    return tab
end

function UI:CreateLayoutTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local gridLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    gridLabel:SetPoint("TOPLEFT", tab, "TOPLEFT", 10, -10)
    gridLabel:SetText(Addon.L and Addon.L["LABEL_GRID_OVERLAY"] or "Grid Overlay")
    gridLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local toggleBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_TOGGLE_GRID"] or "Toggle Grid", width = 120, height = 25 })
    toggleBtn:SetPoint("TOPLEFT", gridLabel, "BOTTOMLEFT", 0, -10)
    toggleBtn:SetScript("OnClick", function()
        UI:ToggleGrid()
    end)

    local sizeLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", toggleBtn, "BOTTOMLEFT", 0, -15)
    sizeLabel:SetText((Addon.L and Addon.L["LABEL_GRID_SIZE"] or "Grid Size:") .. " 50")
    sizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local sizeSlider = CreateFrame("Slider", nil, tab, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -5)
    sizeSlider:SetWidth(200)
    sizeSlider:SetMinMaxValues(10, 200)
    sizeSlider:SetValueStep(10)
    sizeSlider:SetValue(50)
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        sizeLabel:SetText((Addon.L and Addon.L["LABEL_GRID_SIZE"] or "Grid Size:") .. " " .. value)
        tab.gridSize = value
        if tab.gridActive then
            UI:UpdateGridOverlay()
        end
    end)

    local opacityLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opacityLabel:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -15)
    opacityLabel:SetText((Addon.L and Addon.L["LABEL_OPACITY"] or "Opacity:") .. " 0.3")
    opacityLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local opacitySlider = CreateFrame("Slider", nil, tab, "OptionsSliderTemplate")
    opacitySlider:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, -5)
    opacitySlider:SetWidth(200)
    opacitySlider:SetMinMaxValues(0.1, 1.0)
    opacitySlider:SetValueStep(0.1)
    opacitySlider:SetValue(0.3)
    opacitySlider:SetScript("OnValueChanged", function(self, value)
        opacityLabel:SetText((Addon.L and Addon.L["LABEL_OPACITY"] or "Opacity:") .. " " .. string.format("%.1f", value))
        tab.gridOpacity = value
        if tab.gridActive then
            UI:UpdateGridOverlay()
        end
    end)

    local centerBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_TOGGLE_CENTER"] or "Toggle Center Lines", width = 150, height = 25 })
    centerBtn:SetPoint("TOPLEFT", opacitySlider, "BOTTOMLEFT", 0, -20)
    centerBtn:SetScript("OnClick", function()
        UI:ToggleCenterLines()
    end)

    tab.gridSize = 50
    tab.gridOpacity = 0.3
    tab.gridActive = false
    tab.centerActive = false

    Addon.LayoutToolsTab = tab
    return tab
end

function UI:ToggleGrid()
    local tab = Addon.LayoutToolsTab

    if not tab.gridActive then
        if not self.gridFrame then
            self.gridFrame = CreateFrame("Frame", nil, UIParent)
            self.gridFrame:SetAllPoints()
            self.gridFrame:SetFrameStrata("BACKGROUND")
            self.gridFrame:EnableMouse(false)
            self.gridFrame.lines = {}
        end

        self:UpdateGridOverlay()
        self.gridFrame:Show()
        tab.gridActive = true
        Addon:Print(Addon.L and Addon.L["MSG_GRID_ENABLED"] or "Grid enabled")
    else
        if self.gridFrame then
            for _, line in ipairs(self.gridFrame.lines) do
                line:Hide()
            end
            self.gridFrame:Hide()
        end
        tab.gridActive = false
        Addon:Print(Addon.L and Addon.L["MSG_GRID_DISABLED"] or "Grid disabled")
    end
end

function UI:UpdateGridOverlay()
    if not self.gridFrame then return end

    local tab = Addon.LayoutToolsTab
    if not tab then return end

    for _, line in ipairs(self.gridFrame.lines) do
        line:Hide()
    end

    local width = GetScreenWidth()
    local height = GetScreenHeight()
    local gridSize = tab.gridSize or 50
    local opacity = tab.gridOpacity or 0.3
    local lineIndex = 1

    for x = 0, width, gridSize do
        if lineIndex > #self.gridFrame.lines then
            local line = self.gridFrame:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 1, 1, opacity)
            table.insert(self.gridFrame.lines, line)
        end

        local line = self.gridFrame.lines[lineIndex]
        line:SetColorTexture(1, 1, 1, opacity)
        line:SetSize(1, height)
        line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0)
        line:Show()
        lineIndex = lineIndex + 1
    end

    for y = 0, height, gridSize do
        if lineIndex > #self.gridFrame.lines then
            local line = self.gridFrame:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 1, 1, opacity)
            table.insert(self.gridFrame.lines, line)
        end

        local line = self.gridFrame.lines[lineIndex]
        line:SetColorTexture(1, 1, 1, opacity)
        line:SetSize(width, 1)
        line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y)
        line:Show()
        lineIndex = lineIndex + 1
    end
end

function UI:ToggleCenterLines()
    local tab = Addon.LayoutToolsTab

    if not tab.centerActive then
        if not self.centerFrame then
            self.centerFrame = CreateFrame("Frame", nil, UIParent)
            self.centerFrame:SetAllPoints()
            self.centerFrame:SetFrameStrata("BACKGROUND")
            self.centerFrame:EnableMouse(false)

            self.centerV = self.centerFrame:CreateTexture(nil, "ARTWORK")
            self.centerV:SetColorTexture(1, 0, 0, 0.5)
            self.centerV:SetSize(2, GetScreenHeight())
            self.centerV:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

            self.centerH = self.centerFrame:CreateTexture(nil, "ARTWORK")
            self.centerH:SetColorTexture(1, 0, 0, 0.5)
            self.centerH:SetSize(GetScreenWidth(), 2)
            self.centerH:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end

        self.centerFrame:Show()
        tab.centerActive = true
        Addon:Print(Addon.L and Addon.L["MSG_CENTER_LINES_ENABLED"] or "Center lines enabled")
    else
        if self.centerFrame then
            self.centerFrame:Hide()
        end
        tab.centerActive = false
        Addon:Print(Addon.L and Addon.L["MSG_CENTER_LINES_DISABLED"] or "Center lines disabled")
    end
end

function UI:ShowEventSelector()
    if not self.eventSelector then
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(600, 500)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.title:SetPoint("TOP", 0, -5)
        frame.title:SetText(Addon.L and Addon.L["DIALOG_TITLE_SELECT_EVENTS"] or "Event Monitor - Select Events")
        frame.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local commonBtn = OneWoW_GUI:CreateButton(frame, { text = Addon.L and Addon.L["BTN_COMMON_EVENTS"] or "Common Events", width = 110, height = 25 })
        commonBtn:SetPoint("TOPLEFT", 10, -30)
        commonBtn:SetScript("OnClick", function()
            Addon.EventMonitor:RegisterCommonEvents()
            UI:UpdateEventSelector()
            Addon:Print((Addon.L and Addon.L["MSG_ADDED_COMMON_EVENTS"] or "Added common events ({count} total)"):gsub("{count}", Addon.EventMonitor:GetEventCount()))
        end)

        local selectAllBtn = OneWoW_GUI:CreateButton(frame, { text = Addon.L and Addon.L["BTN_SELECT_ALL"] or "Select All", width = 80, height = 25 })
        selectAllBtn:SetPoint("LEFT", commonBtn, "RIGHT", 5, 0)
        selectAllBtn:SetScript("OnClick", function()
            UI:SelectAllEvents()
            Addon:Print((Addon.L and Addon.L["MSG_SELECTED_ALL_EVENTS"] or "Selected all events ({count} total)"):gsub("{count}", Addon.EventMonitor:GetEventCount()))
        end)

        local clearAllBtn = OneWoW_GUI:CreateButton(frame, { text = Addon.L and Addon.L["BTN_CLEAR_ALL"] or "Clear All", width = 80, height = 25 })
        clearAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 5, 0)
        clearAllBtn:SetScript("OnClick", function()
            Addon.EventMonitor.selectedEvents = {}
            UI:UpdateEventSelector()
            Addon:Print(Addon.L and Addon.L["MSG_CLEARED_ALL_EVENTS"] or "Cleared all events")
        end)

        local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        searchLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -215, -37)
        searchLabel:SetText((Addon.L and Addon.L["LABEL_FILTER"] or "Search:"))
        searchLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        searchBox:SetSize(180, 25)
        searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 5, 0)
        searchBox:SetAutoFocus(false)
        searchBox:SetScript("OnTextChanged", function()
            UI:UpdateEventSelector()
        end)

        local eventCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        eventCount:SetPoint("TOPLEFT", commonBtn, "BOTTOMLEFT", 0, -8)
        eventCount:SetText((Addon.L and Addon.L["LABEL_SELECTED"] or "Selected:") .. " 0")
        eventCount:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local leftPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        leftPanel:SetPoint("TOPLEFT", eventCount, "BOTTOMLEFT", 0, -8)
        leftPanel:SetPoint("BOTTOM", frame, "BOTTOM", 0, 40)
        leftPanel:SetWidth(280)
        StyleContentPanel(leftPanel)

        local leftTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leftTitle:SetPoint("TOP", 0, -5)
        leftTitle:SetText(Addon.L and Addon.L["LABEL_EVENT_LIST"] or "Event List")
        leftTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local leftScroll = CreateFrame("ScrollFrame", nil, leftPanel, "UIPanelScrollFrameTemplate")
        leftScroll:SetPoint("TOPLEFT", 4, -25)
        leftScroll:SetPoint("BOTTOMRIGHT", -14, 4)
        OneWoW_GUI:StyleScrollBar(leftScroll, { container = leftPanel })

        local leftContent = CreateFrame("Frame", nil, leftScroll)
        leftContent:SetHeight(1)
        leftScroll:SetScrollChild(leftContent)

        leftScroll:HookScript("OnSizeChanged", function(self, w)
            leftContent:SetWidth(w)
        end)

        frame.eventButtons = {}
        for i = 1, 50 do
            local btn = CreateFrame("CheckButton", nil, leftContent, "UICheckButtonTemplate")
            btn:SetSize(20, 20)
            btn:SetPoint("TOPLEFT", 5, -(i-1) * 22 - 5)

            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.text:SetPoint("LEFT", btn, "RIGHT", 5, 0)
            btn.text:SetText("")
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            btn:SetScript("OnClick", function(self)
                if self.eventName then
                    Addon.EventMonitor:ToggleEvent(self.eventName)
                    UI:UpdateEventSelector()
                end
            end)

            frame.eventButtons[i] = btn
        end

        local rightPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 5, 0)
        rightPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 40)
        StyleContentPanel(rightPanel)

        local rightTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rightTitle:SetPoint("TOP", 0, -5)
        rightTitle:SetText(Addon.L and Addon.L["LABEL_CUSTOM_ATLAS"] or "Custom Event")
        rightTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local customLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        customLabel:SetPoint("TOPLEFT", 10, -30)
        customLabel:SetText(Addon.L and Addon.L["LABEL_ENTER_EVENT"] or "Enter event name:")
        customLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local customBox = CreateFrame("EditBox", nil, rightPanel, "InputBoxTemplate")
        customBox:SetSize(250, 25)
        customBox:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -5)
        customBox:SetAutoFocus(false)

        local addBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_ADD_EVENT"] or "Add", width = 80, height = 25 })
        addBtn:SetPoint("LEFT", customBox, "RIGHT", 5, 0)
        addBtn:SetScript("OnClick", function()
            local eventName = customBox:GetText()
            if eventName and eventName ~= "" then
                Addon.EventMonitor:ToggleEvent(eventName:upper())
                customBox:SetText("")
                UI:UpdateEventSelector()
                Addon:Print((Addon.L and Addon.L["MSG_ADDED_EVENT"] or "Added event: {event}"):gsub("{event}", eventName:upper()))
            end
        end)

        local helpText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        helpText:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -40)
        helpText:SetPoint("RIGHT", rightPanel, "RIGHT", -10, 0)
        helpText:SetJustifyH("LEFT")
        helpText:SetText(Addon.L and Addon.L["HELP_TEXT_EVENTS"] or "Enter any WoW event name to monitor.\n\nCommon events:\nPLAYER_ENTERING_WORLD\nZONE_CHANGED\nPLAYER_REGEN_DISABLED\nPLAYER_REGEN_ENABLED\nBAG_UPDATE\nUNIT_HEALTH\nCHAT_MSG_SAY\nADDON_LOADED\n\nYou can find more events on:\nwarcraft.wiki.gg")
        helpText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local closeBtn = OneWoW_GUI:CreateButton(frame, { text = Addon.L and Addon.L["BTN_CLOSE"] or "Close", width = 80, height = 25 })
        closeBtn:SetPoint("BOTTOM", 0, 10)
        closeBtn:SetScript("OnClick", function()
            frame:Hide()
        end)

        frame.leftScroll = leftScroll
        frame.searchBox = searchBox
        frame.eventCount = eventCount

        self.eventSelector = frame

        Addon.EventMonitor:RegisterCommonEvents()
    end

    self:UpdateEventSelector()
    self.eventSelector:Show()
end

function UI:SelectAllEvents()
    local allEvents = {
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGIN", "PLAYER_LOGOUT",
        "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "UNIT_HEALTH", "UNIT_POWER_UPDATE", "UNIT_AURA",
        "BAG_UPDATE", "BAG_UPDATE_DELAYED",
        "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_PARTY", "CHAT_MSG_GUILD",
        "ADDON_LOADED", "VARIABLES_LOADED",
        "COMBAT_LOG_EVENT_UNFILTERED",
        "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
        "MERCHANT_SHOW", "MERCHANT_CLOSED",
        "MAIL_INBOX_UPDATE", "MAIL_SHOW", "MAIL_CLOSED",
        "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
        "LOOT_OPENED", "LOOT_CLOSED",
        "TRADE_SHOW", "TRADE_CLOSED",
        "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
        "ITEM_LOCKED", "ITEM_UNLOCKED",
        "GOSSIP_SHOW", "GOSSIP_CLOSED",
        "TAXIMAP_OPENED", "TAXIMAP_CLOSED",
    }

    for _, event in ipairs(allEvents) do
        Addon.EventMonitor.selectedEvents[event] = true
    end

    self:UpdateEventSelector()
end

function UI:UpdateEventSelector()
    if not self.eventSelector then return end

    local frame = self.eventSelector
    local searchText = frame.searchBox:GetText():upper()

    local allEvents = {
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGIN", "PLAYER_LOGOUT",
        "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "UNIT_HEALTH", "UNIT_POWER_UPDATE", "UNIT_AURA",
        "BAG_UPDATE", "BAG_UPDATE_DELAYED",
        "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_PARTY", "CHAT_MSG_GUILD",
        "ADDON_LOADED", "VARIABLES_LOADED",
        "COMBAT_LOG_EVENT_UNFILTERED",
        "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
        "MERCHANT_SHOW", "MERCHANT_CLOSED",
        "MAIL_INBOX_UPDATE", "MAIL_SHOW", "MAIL_CLOSED",
        "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
        "LOOT_OPENED", "LOOT_CLOSED",
        "TRADE_SHOW", "TRADE_CLOSED",
        "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    }

    for event in pairs(Addon.EventMonitor.selectedEvents) do
        local exists = false
        for _, e in ipairs(allEvents) do
            if e == event then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(allEvents, event)
        end
    end

    table.sort(allEvents)

    local filteredEvents = {}
    for _, event in ipairs(allEvents) do
        if searchText == "" or string.find(event, searchText, 1, true) then
            table.insert(filteredEvents, event)
        end
    end

    for i, btn in ipairs(frame.eventButtons) do
        local event = filteredEvents[i]
        if event then
            btn.eventName = event
            btn.text:SetText(event)
            btn:SetChecked(Addon.EventMonitor:IsEventRegistered(event))
            btn:Show()
        else
            btn:Hide()
        end
    end

    local height = math.max(#filteredEvents * 22 + 10, frame.leftScroll:GetHeight())
    frame.leftScroll:GetScrollChild():SetHeight(height)

    frame.eventCount:SetText((Addon.L and Addon.L["LABEL_SELECTED"] or "Selected:") .. " " .. Addon.EventMonitor:GetEventCount())
end

function UI:CreateMonitorTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local L = Addon.L or {}
    local Monitor = Addon.MonitorTab

    if Monitor then
        Monitor:Initialize()
    end

    local ROW_HEIGHT = 20
    local MAX_ROWS = 60

    local playBtn = OneWoW_GUI:CreateButton(tab, { text = L["MON_BTN_PLAY"] or "Play", width = 80, height = 22 })
    playBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)

    local updateBtn = OneWoW_GUI:CreateButton(tab, { text = L["MON_BTN_UPDATE"] or "Update", width = 80, height = 22 })
    updateBtn:SetPoint("LEFT", playBtn, "RIGHT", 5, 0)

    local resetBtn = OneWoW_GUI:CreateButton(tab, { text = L["MON_BTN_RESET"] or "Reset", width = 80, height = 22 })
    resetBtn:SetPoint("LEFT", updateBtn, "RIGHT", 5, 0)

    local cpuCheck = CreateFrame("CheckButton", nil, tab, "UICheckButtonTemplate")
    cpuCheck:SetSize(22, 22)
    cpuCheck:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    cpuCheck:SetChecked(Monitor and Monitor:IsCPUProfilingEnabled() or false)

    local cpuLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cpuLabel:SetPoint("LEFT", cpuCheck, "RIGHT", 2, 0)
    cpuLabel:SetText(L["MON_LABEL_CPU_PROFILING"] or "CPU Profiling")
    cpuLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local showOnLoadCheck = CreateFrame("CheckButton", nil, tab, "UICheckButtonTemplate")
    showOnLoadCheck:SetSize(22, 22)
    showOnLoadCheck:SetPoint("LEFT", cpuLabel, "RIGHT", 15, 0)
    showOnLoadCheck:SetChecked(Addon.db and Addon.db.monitor and Addon.db.monitor.showOnLoad or false)

    local showOnLoadLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    showOnLoadLabel:SetPoint("LEFT", showOnLoadCheck, "RIGHT", 2, 0)
    showOnLoadLabel:SetText(L["MON_LABEL_SHOW_ON_LOAD"] or "Show on Load")
    showOnLoadLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local filterLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("TOPLEFT", playBtn, "BOTTOMLEFT", 0, -8)
    filterLabel:SetText(L["MON_LABEL_FILTER"] or "Filter:")
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local filterBox = CreateFrame("EditBox", nil, tab, "InputBoxTemplate")
    filterBox:SetSize(150, 22)
    filterBox:SetPoint("LEFT", filterLabel, "RIGHT", 5, 0)
    filterBox:SetAutoFocus(false)

    local hasCPU = Monitor and Monitor:IsCPUProfilingEnabled() or false

    local headerFrame = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    headerFrame:SetPoint("TOPLEFT", playBtn, "BOTTOMLEFT", 0, -35)
    headerFrame:SetPoint("RIGHT", tab, "RIGHT", -5, 0)
    headerFrame:SetHeight(22)
    headerFrame:SetBackdrop(BACKDROP_SIMPLE)
    headerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local nameHeader = CreateFrame("Button", nil, headerFrame)
    nameHeader:SetPoint("LEFT", headerFrame, "LEFT", 5, 0)
    nameHeader:SetHeight(22)
    nameHeader.text = nameHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameHeader.text:SetPoint("LEFT", 0, 0)
    nameHeader.text:SetText(L["MON_HEADER_NAME"] or "Addon")
    nameHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local memHeader = CreateFrame("Button", nil, headerFrame)
    memHeader:SetSize(90, 22)
    memHeader.text = memHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    memHeader.text:SetPoint("RIGHT", 0, 0)
    memHeader.text:SetText(L["MON_HEADER_MEMORY"] or "Memory (k)")
    memHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local memPctHeader = CreateFrame("Button", nil, headerFrame)
    memPctHeader:SetSize(55, 22)
    memPctHeader.text = memPctHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    memPctHeader.text:SetPoint("RIGHT", 0, 0)
    memPctHeader.text:SetText(L["MON_HEADER_MEM_PCT"] or "Mem %")
    memPctHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local cpuHeader = CreateFrame("Button", nil, headerFrame)
    cpuHeader:SetSize(90, 22)
    cpuHeader.text = cpuHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cpuHeader.text:SetPoint("RIGHT", 0, 0)
    cpuHeader.text:SetText(L["MON_HEADER_CPU"] or "CPU (ms/s)")
    cpuHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local cpuPctHeader = CreateFrame("Button", nil, headerFrame)
    cpuPctHeader:SetSize(55, 22)
    cpuPctHeader.text = cpuPctHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cpuPctHeader.text:SetPoint("RIGHT", -14, 0)
    cpuPctHeader.text:SetText(L["MON_HEADER_CPU_PCT"] or "CPU %")
    cpuPctHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    if hasCPU then
        cpuPctHeader:SetPoint("RIGHT", headerFrame, "RIGHT", 0, 0)
        cpuHeader:SetPoint("RIGHT", cpuPctHeader, "LEFT", -5, 0)
        memPctHeader:SetPoint("RIGHT", cpuHeader, "LEFT", -5, 0)
        memHeader:SetPoint("RIGHT", memPctHeader, "LEFT", -5, 0)
    else
        cpuPctHeader:Hide()
        cpuHeader:Hide()
        memPctHeader:SetPoint("RIGHT", headerFrame, "RIGHT", -14, 0)
        memHeader:SetPoint("RIGHT", memPctHeader, "LEFT", -5, 0)
    end

    nameHeader:SetPoint("RIGHT", memHeader, "LEFT", -5, 0)

    nameHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(1); Monitor:GetSortedList(); tab:RefreshList() end
    end)
    memHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(2); Monitor:GetSortedList(); tab:RefreshList() end
    end)
    memPctHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(2); Monitor:GetSortedList(); tab:RefreshList() end
    end)
    cpuHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(3); Monitor:GetSortedList(); tab:RefreshList() end
    end)
    cpuPctHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(3); Monitor:GetSortedList(); tab:RefreshList() end
    end)

    local listPanel = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 35)
    StyleContentPanel(listPanel)

    local listScroll = CreateFrame("ScrollFrame", nil, listPanel, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 0, 0)
    listScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -14, 0)
    OneWoW_GUI:StyleScrollBar(listScroll, { container = listPanel })

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetHeight(1)
    listScroll:SetScrollChild(listContent)

    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
    end)

    tab.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, listContent)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", listContent, "RIGHT", 0, 0)

        row.stripe = row:CreateTexture(nil, "BACKGROUND")
        row.stripe:SetAllPoints()
        if i % 2 == 0 then
            row.stripe:SetColorTexture(1, 1, 1, 0.03)
        else
            row.stripe:SetColorTexture(0, 0, 0, 0)
        end

        row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        row.highlight:SetAlpha(0.15)

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameText:SetPoint("LEFT", row, "LEFT", 5, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        row.memText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.memText:SetJustifyH("RIGHT")
        row.memText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row.memPctText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.memPctText:SetJustifyH("RIGHT")
        row.memPctText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        row.cpuText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cpuText:SetJustifyH("RIGHT")
        row.cpuText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row.cpuPctText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cpuPctText:SetJustifyH("RIGHT")
        row.cpuPctText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        if hasCPU then
            row.cpuPctText:SetPoint("RIGHT", row, "RIGHT", -14, 0)
            row.cpuPctText:SetWidth(55)
            row.cpuText:SetPoint("RIGHT", row.cpuPctText, "LEFT", -5, 0)
            row.cpuText:SetWidth(90)
            row.memPctText:SetPoint("RIGHT", row.cpuText, "LEFT", -5, 0)
            row.memPctText:SetWidth(55)
            row.memText:SetPoint("RIGHT", row.memPctText, "LEFT", -5, 0)
            row.memText:SetWidth(90)
        else
            row.cpuText:Hide()
            row.cpuPctText:Hide()
            row.memPctText:SetPoint("RIGHT", row, "RIGHT", -14, 0)
            row.memPctText:SetWidth(55)
            row.memText:SetPoint("RIGHT", row.memPctText, "LEFT", -5, 0)
            row.memText:SetWidth(90)
        end

        row.nameText:SetPoint("RIGHT", row.memText, "LEFT", -5, 0)

        row:Hide()
        tab.rows[i] = row
    end

    local totalsBar = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    totalsBar:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 5, 5)
    totalsBar:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    totalsBar:SetHeight(25)
    totalsBar:SetBackdrop(BACKDROP_SIMPLE)
    totalsBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    tab.totalsText = totalsBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.totalsText:SetPoint("LEFT", totalsBar, "LEFT", 10, 0)
    tab.totalsText:SetText("")
    tab.totalsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    tab.noDataText = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.noDataText:SetPoint("CENTER", listPanel, "CENTER", 0, 0)
    tab.noDataText:SetText(L["MON_MSG_NO_DATA"] or "Click 'Update' or 'Play' to begin monitoring")
    tab.noDataText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    function tab:RefreshList()
        if not Monitor then return end
        local list = Monitor:GetDisplayedList()
        local t = Monitor:GetTotals()

        if t.count == 0 then
            tab.noDataText:Show()
        else
            tab.noDataText:Hide()
        end

        for i = 1, MAX_ROWS do
            local row = tab.rows[i]
            local info = list[i]
            if info then
                row.nameText:SetText(info.title)
                row.memText:SetText(Monitor:FormatMemory(info.memory))
                row.memPctText:SetText(Monitor:FormatPercent(info.memPercent))
                if hasCPU then
                    row.cpuText:SetText(Monitor:FormatCPU(info.cpuPerSec))
                    row.cpuPctText:SetText(Monitor:FormatPercent(info.cpuPercent))
                end
                row:Show()
            else
                row:Hide()
            end
        end

        local contentHeight = math.max(#list * ROW_HEIGHT + 5, listScroll:GetHeight())
        listContent:SetHeight(contentHeight)

        local cpuTotalPerSec = 0
        if t.duration > 0 then
            cpuTotalPerSec = t.cpu / t.duration
        end

        local totalsStr = (L["MON_TOTALS_ADDONS"] or "Addons:") .. " " .. t.count ..
            "    " .. (L["MON_TOTALS_MEMORY"] or "Memory:") .. " " .. Monitor:FormatMemory(t.memory) .. " k"
        if hasCPU then
            totalsStr = totalsStr .. "    " .. (L["MON_TOTALS_CPU"] or "CPU:") .. " " .. Monitor:FormatCPU(cpuTotalPerSec) .. " ms/s"
        end
        tab.totalsText:SetText(totalsStr)
    end

    local function DoUpdate()
        if Monitor then
            Monitor:GatherUsage()
            Monitor:GetSortedList()
            tab:RefreshList()
        end
    end

    playBtn:SetScript("OnClick", function()
        if not Monitor then return end
        Monitor:ToggleMonitoring()
        if Monitor:IsMonitoring() then
            playBtn.text:SetText(L["MON_BTN_PAUSE"] or "Pause")
            DoUpdate()
        else
            playBtn.text:SetText(L["MON_BTN_PLAY"] or "Play")
        end
    end)

    updateBtn:SetScript("OnClick", function()
        DoUpdate()
    end)

    resetBtn:SetScript("OnClick", function()
        if Monitor then
            Monitor:Reset()
            DoUpdate()
            Addon:Print(L["MON_MSG_RESET"] or "Memory collected and CPU usage reset")
        end
    end)

    cpuCheck:SetScript("OnClick", function()
        if Monitor then
            StaticPopupDialogs["ONEWOW_DEVTOOL_CPU_RELOAD"] = {
                text = L["MON_CPU_RELOAD_CONFIRM"] or "Changing CPU profiling requires a UI reload. Reload now?",
                button1 = YES,
                button2 = NO,
                OnAccept = function()
                    Monitor:ToggleCPUProfiling()
                end,
                OnCancel = function()
                    cpuCheck:SetChecked(Monitor:IsCPUProfilingEnabled())
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("ONEWOW_DEVTOOL_CPU_RELOAD")
        end
    end)

    filterBox:SetScript("OnTextChanged", function(self)
        if Monitor then
            Monitor:SetFilter(self:GetText())
            Monitor:GetSortedList()
            tab:RefreshList()
        end
    end)

    showOnLoadCheck:SetScript("OnClick", function(self)
        if Addon.db and Addon.db.monitor then
            Addon.db.monitor.showOnLoad = self:GetChecked() and true or false
        end
    end)

    tab:SetScript("OnUpdate", function(self, elapsed)
        if Monitor then
            local wasMonitoring = Monitor:IsMonitoring()
            Monitor:OnUpdate(elapsed)
            if wasMonitoring then
                Monitor:GetSortedList()
            end
        end
    end)

    Addon.MonitorTabUI = tab
    return tab
end

function UI:CreateSettingsTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local L = Addon.L
    local yOffset = -10

    local splitContainer = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    splitContainer:SetPoint("TOPLEFT", tab, "TOPLEFT", 10, yOffset)
    splitContainer:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -10, yOffset)
    splitContainer:SetHeight(165)
    splitContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    splitContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    splitContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local leftPanel = CreateFrame("Frame", nil, splitContainer)
    leftPanel:SetPoint("TOPLEFT", splitContainer, "TOPLEFT", 0, 0)
    leftPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOM", 0, 0)

    local langTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    langTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -12)
    langTitle:SetText(L["SETTINGS_LANGUAGE_SELECTION"])
    langTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local langDescText = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDescText:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -38)
    langDescText:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -10, -38)
    langDescText:SetJustifyH("LEFT")
    langDescText:SetWordWrap(true)
    langDescText:SetText(L["SETTINGS_LANGUAGE_DESC"])
    langDescText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local LANGUAGES = {
        { code = "enUS", name = L["LANG_ENGLISH"] },
        { code = "koKR", name = L["LANG_KOREAN"]  },
        { code = "esES", name = L["LANG_SPANISH"] },
        { code = "frFR", name = L["LANG_FRENCH"]  },
        { code = "ruRU", name = L["LANG_RUSSIAN"] },
        { code = "deDE", name = L["LANG_GERMAN"]  },
    }

    local currentLang = Addon.db and Addon.db.language or "enUS"
    local currentLangName = L["LANG_ENGLISH"]
    for _, entry in ipairs(LANGUAGES) do
        if entry.code == currentLang then currentLangName = entry.name break end
    end

    local langCurrentLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langCurrentLabel:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -90)
    langCurrentLabel:SetText(L["SETTINGS_LANGUAGE_SELECTION"] .. ": " .. currentLangName)
    langCurrentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local langDropdown = CreateFrame("Button", nil, leftPanel, "BackdropTemplate")
    langDropdown:SetSize(190, 30)
    langDropdown:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -115)
    langDropdown:SetBackdrop(backdrop)
    langDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    langDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local langDropText = langDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDropText:SetPoint("CENTER")
    langDropText:SetText(currentLangName)
    langDropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local langDropArrow = langDropdown:CreateTexture(nil, "OVERLAY")
    langDropArrow:SetSize(16, 16)
    langDropArrow:SetPoint("RIGHT", langDropdown, "RIGHT", -5, 0)
    langDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    langDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS")) end)
    langDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE")) end)

    langDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(190, #LANGUAGES * 27 + 10)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop(backdrop)
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)
        for i, entry in ipairs(LANGUAGES) do
            local btn = CreateFrame("Button", nil, menu, "BackdropTemplate")
            btn:SetSize(180, 25)
            btn:SetPoint("TOP", menu, "TOP", 0, -(5 + (i - 1) * 27))
            btn:SetBackdrop(BACKDROP_SIMPLE)
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            txt:SetPoint("CENTER")
            txt:SetText(entry.name)
            txt:SetTextColor(0.9, 0.9, 0.9)
            btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) txt:SetTextColor(1, 0.82, 0) end)
            btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) txt:SetTextColor(0.9, 0.9, 0.9) end)
            local capturedCode = entry.code
            btn:SetScript("OnClick", function()
                Addon.db.language = capturedCode
                Addon:ApplyLanguage()
                menu:Hide()
                if UI.mainFrame then UI.mainFrame:Hide() end
                UI.mainFrame = nil
                UI.tabs = {}
                C_Timer.After(0.1, function() UI:Show() end)
            end)
        end
        menu:SetScript("OnShow", function(self)
            local timeOutside = 0
            self:SetScript("OnUpdate", function(self, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(langDropdown) then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 0.5 then self:Hide() self:SetScript("OnUpdate", nil) end
                else timeOutside = 0 end
            end)
        end)
    end)

    local vertDivider = splitContainer:CreateTexture(nil, "ARTWORK")
    vertDivider:SetWidth(1)
    vertDivider:SetPoint("TOP", splitContainer, "TOP", 0, -8)
    vertDivider:SetPoint("BOTTOM", splitContainer, "BOTTOM", 0, 8)
    vertDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local rightPanel = CreateFrame("Frame", nil, splitContainer)
    rightPanel:SetPoint("TOPLEFT", splitContainer, "TOP", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOMRIGHT", 0, 0)

    local themeNames = {
        green = "Forest Green", blue = "Ocean Blue", purple = "Mystic Purple",
        red = "Crimson Red", orange = "Sunset Orange", teal = "Mystic Teal",
        gold = "Classic Gold", pink = "Rose Pink", dark = "Midnight Dark",
        amber = "Amber Fire", cyan = "Arctic Cyan", slate = "Slate Gray",
        voidblack = "Void Black", charcoal = "Charcoal Deep", forestnight = "Forest Night",
        obsidian = "Obsidian Minimal", monochrome = "Monochrome Pro", twilight = "Twilight Compact",
        neon = "Neon Synthwave", glassmorphic = "Glassmorphic", lightmode = "Minimal White",
        retro = "Retro Classic", fantasy = "RPG Fantasy", nightfae = "Covenant Twilight",
    }
    local themeKeys = OneWoW_GUI.Constants.THEMES_ORDER

    local currentTheme = OneWoW_GUI:GetSetting("theme") or Addon.db and Addon.db.theme or "green"
    local currentThemeName = themeNames[currentTheme] or "Forest Green"

    local themeTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    themeTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -12)
    themeTitle:SetText(L["SETTINGS_THEME_SELECTION"])
    themeTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local themeDescText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDescText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -38)
    themeDescText:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -10, -38)
    themeDescText:SetJustifyH("LEFT")
    themeDescText:SetWordWrap(true)
    themeDescText:SetText(L["SETTINGS_THEME_DESC"])
    themeDescText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local themeCurrentLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeCurrentLabel:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -90)
    themeCurrentLabel:SetText(L["SETTINGS_THEME_SELECTION"] .. ": " .. currentThemeName)
    themeCurrentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local themeDropdown = CreateFrame("Button", nil, rightPanel, "BackdropTemplate")
    themeDropdown:SetSize(210, 30)
    themeDropdown:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -115)
    themeDropdown:SetBackdrop(backdrop)
    themeDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    themeDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local themeDropText = themeDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDropText:SetPoint("LEFT", themeDropdown, "LEFT", 25, 0)
    themeDropText:SetText(currentThemeName)
    themeDropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local themeColorPreview = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeColorPreview:SetSize(14, 14)
    themeColorPreview:SetPoint("LEFT", themeDropdown, "LEFT", 6, 0)
    themeColorPreview:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local themeDropArrow = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeDropArrow:SetSize(16, 16)
    themeDropArrow:SetPoint("RIGHT", themeDropdown, "RIGHT", -5, 0)
    themeDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    themeDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS")) end)
    themeDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE")) end)

    themeDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(240, 318)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop(backdrop)
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)

        local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
        scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
        scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -15, 2)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(scrollFrame:GetWidth())
        scrollFrame:SetScrollChild(scrollChild)

        local scrollBar = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, -2)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 2)
        scrollBar:SetWidth(12)
        scrollBar:SetBackdrop(BACKDROP_SIMPLE)
        scrollBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        scrollBar:EnableMouse(true)
        scrollBar:SetScript("OnValueChanged", function(self, value) scrollFrame:SetVerticalScroll(value) end)

        local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(8, 40)
        thumb:SetPoint("TOP", scrollBar, "TOP", 0, -2)
        thumb:SetColorTexture(0.5, 0.5, 0.5)
        scrollBar:SetThumbTexture(thumb)

        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(self, direction)
            local currentScroll = scrollFrame:GetVerticalScroll()
            local maxScroll = scrollChild:GetHeight() - scrollFrame:GetHeight()
            local newScroll = math.max(0, math.min(maxScroll, currentScroll - (direction * 30)))
            scrollFrame:SetVerticalScroll(newScroll)
            scrollBar:SetValue(newScroll)
        end)

        local guiThemesForMenu = OneWoW_GUI.Constants.THEMES
        for i, themeKey in ipairs(themeKeys) do
            local themeData = guiThemesForMenu[themeKey]
            if themeData then
                local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                btn:SetSize(230, 26)
                btn:SetPoint("TOP", scrollChild, "TOP", 0, -(5 + (i - 1) * 28))
                btn:SetBackdrop(BACKDROP_SIMPLE)
                btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                local dot = btn:CreateTexture(nil, "OVERLAY")
                dot:SetSize(14, 14)
                dot:SetPoint("LEFT", btn, "LEFT", 8, 0)
                dot:SetColorTexture(unpack(themeData.ACCENT_PRIMARY))
                local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                txt:SetPoint("LEFT", btn, "LEFT", 28, 0)
                txt:SetText(themeNames[themeKey] or themeData.name or themeKey)
                txt:SetTextColor(0.9, 0.9, 0.9)
                btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) txt:SetTextColor(1, 0.82, 0) end)
                btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) txt:SetTextColor(0.9, 0.9, 0.9) end)
                local capturedKey = themeKey
                btn:SetScript("OnClick", function()
                    OneWoW_GUI:SetSetting("theme", capturedKey)
                    menu:Hide()
                    -- OnThemeChanged callback handles ApplyTheme + FullReset + Show
                end)
            end
        end
        scrollChild:SetHeight(#themeKeys * 28 + 10)
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollFrame:SetVerticalScroll(0)
        menu:SetScript("OnShow", function(self)
            local timeOutside = 0
            self:SetScript("OnUpdate", function(self, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(themeDropdown) then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 0.5 then self:Hide() self:SetScript("OnUpdate", nil) end
                else timeOutside = 0 end
            end)
        end)
    end)

    yOffset = yOffset - 180

    local minimapSplit = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    minimapSplit:SetPoint("TOPLEFT", tab, "TOPLEFT", 10, yOffset)
    minimapSplit:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -10, yOffset)
    minimapSplit:SetHeight(140)
    minimapSplit:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    minimapSplit:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    minimapSplit:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local mmLeftPanel = CreateFrame("Frame", nil, minimapSplit)
    mmLeftPanel:SetPoint("TOPLEFT", minimapSplit, "TOPLEFT", 0, 0)
    mmLeftPanel:SetPoint("BOTTOMRIGHT", minimapSplit, "BOTTOM", 0, 0)

    local mmLeftTitle = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmLeftTitle:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -12)
    mmLeftTitle:SetText(L["MINIMAP_SECTION"])
    mmLeftTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local mmLeftDesc = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmLeftDesc:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -38)
    mmLeftDesc:SetPoint("TOPRIGHT", mmLeftPanel, "TOPRIGHT", -10, -38)
    mmLeftDesc:SetJustifyH("LEFT")
    mmLeftDesc:SetWordWrap(true)
    mmLeftDesc:SetText(L["MINIMAP_SECTION_DESC"])
    mmLeftDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local mmCheckbox = CreateFrame("CheckButton", nil, mmLeftPanel, "UICheckButtonTemplate")
    mmCheckbox:SetSize(26, 26)
    mmCheckbox:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -70)

    local isMinimapEnabled = not (Addon.db and Addon.db.minimap and Addon.db.minimap.hide)
    mmCheckbox:SetChecked(isMinimapEnabled)

    local mmCheckLabel = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmCheckLabel:SetPoint("LEFT", mmCheckbox, "RIGHT", 4, 0)
    mmCheckLabel:SetText(L["MINIMAP_SHOW_BTN"])
    mmCheckLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    mmCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if checked then
            if Addon.db and Addon.db.minimap then Addon.db.minimap.hide = false end
            if Addon.Minimap then Addon.Minimap:Show() end
        else
            if Addon.db and Addon.db.minimap then Addon.db.minimap.hide = true end
            if Addon.Minimap then Addon.Minimap:Hide() end
        end
    end)

    local mmVertDiv = minimapSplit:CreateTexture(nil, "ARTWORK")
    mmVertDiv:SetWidth(1)
    mmVertDiv:SetPoint("TOP", minimapSplit, "TOP", 0, -8)
    mmVertDiv:SetPoint("BOTTOM", minimapSplit, "BOTTOM", 0, 8)
    mmVertDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local mmRightPanel = CreateFrame("Frame", nil, minimapSplit)
    mmRightPanel:SetPoint("TOPLEFT", minimapSplit, "TOP", 0, 0)
    mmRightPanel:SetPoint("BOTTOMRIGHT", minimapSplit, "BOTTOMRIGHT", 0, 0)

    local mmRightTitle = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmRightTitle:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -12)
    mmRightTitle:SetText(L["MINIMAP_ICON_SECTION"])
    mmRightTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local mmRightDesc = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmRightDesc:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -38)
    mmRightDesc:SetPoint("TOPRIGHT", mmRightPanel, "TOPRIGHT", -10, -38)
    mmRightDesc:SetJustifyH("LEFT")
    mmRightDesc:SetWordWrap(true)
    mmRightDesc:SetText(L["MINIMAP_ICON_DESC"])
    mmRightDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local currentIconTheme = Addon.db and Addon.db.minimap and Addon.db.minimap.theme or "horde"
    local iconThemeNames = {
        ["horde"]    = L["MINIMAP_ICON_HORDE"],
        ["alliance"] = L["MINIMAP_ICON_ALLIANCE"],
        ["neutral"]  = L["MINIMAP_ICON_NEUTRAL"],
    }
    local iconThemePaths = {
        ["horde"]    = "Interface\\AddOns\\OneWoW_Utility_DevTool\\Media\\horde-mini.png",
        ["alliance"] = "Interface\\AddOns\\OneWoW_Utility_DevTool\\Media\\alliance-mini.png",
        ["neutral"]  = "Interface\\AddOns\\OneWoW_Utility_DevTool\\Media\\neutral-mini.png",
    }

    local mmIconDropdown = CreateFrame("Button", nil, mmRightPanel, "BackdropTemplate")
    mmIconDropdown:SetSize(190, 30)
    mmIconDropdown:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -70)
    mmIconDropdown:SetBackdrop(backdrop)
    mmIconDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    mmIconDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local mmIconPreview = mmIconDropdown:CreateTexture(nil, "OVERLAY")
    mmIconPreview:SetSize(18, 18)
    mmIconPreview:SetPoint("LEFT", mmIconDropdown, "LEFT", 8, 0)
    mmIconPreview:SetTexture(iconThemePaths[currentIconTheme] or iconThemePaths["horde"])

    local mmIconText = mmIconDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmIconText:SetPoint("LEFT", mmIconPreview, "RIGHT", 6, 0)
    mmIconText:SetText(iconThemeNames[currentIconTheme] or currentIconTheme)
    mmIconText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local mmIconArrow = mmIconDropdown:CreateTexture(nil, "OVERLAY")
    mmIconArrow:SetSize(16, 16)
    mmIconArrow:SetPoint("RIGHT", mmIconDropdown, "RIGHT", -5, 0)
    mmIconArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    mmIconDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS")) end)
    mmIconDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE")) end)

    mmIconDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(190, 88)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop(backdrop)
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)

        local iconOrder = {"horde", "alliance", "neutral"}
        local function createIconBtn(parent, themeKey, yPos)
            local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(180, 25)
            btn:SetPoint("TOP", parent, "TOP", 0, yPos)
            btn:SetBackdrop(BACKDROP_SIMPLE)
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            local ico = btn:CreateTexture(nil, "OVERLAY")
            ico:SetSize(18, 18)
            ico:SetPoint("LEFT", btn, "LEFT", 8, 0)
            ico:SetTexture(iconThemePaths[themeKey])
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", ico, "RIGHT", 6, 0)
            text:SetText(iconThemeNames[themeKey])
            text:SetTextColor(0.9, 0.9, 0.9)
            btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) text:SetTextColor(1, 0.82, 0) end)
            btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) text:SetTextColor(0.9, 0.9, 0.9) end)
            btn:SetScript("OnClick", function()
                if Addon.db and Addon.db.minimap then
                    Addon.db.minimap.theme = themeKey
                end
                if Addon.Minimap then Addon.Minimap:UpdateIcon() end
                menu:Hide()
                if UI.mainFrame then UI.mainFrame:Hide() end
                UI.mainFrame = nil
                UI.tabs = {}
                C_Timer.After(0.1, function() UI:Show() end)
            end)
            return btn
        end

        local yPos = -5
        for _, themeKey in ipairs(iconOrder) do
            createIconBtn(menu, themeKey, yPos)
            yPos = yPos - 27
        end

        menu:SetScript("OnShow", function(self)
            local timeOutside = 0
            self:SetScript("OnUpdate", function(self, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(mmIconDropdown) then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 0.5 then self:Hide() self:SetScript("OnUpdate", nil) end
                else timeOutside = 0 end
            end)
        end)
    end)

    return tab
end

function UI:ShowEventImportDialog()
    if not self.importDialog then
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(650, 480)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -8)
        title:SetText("Import Events to Monitor")
        title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local instrLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        instrLabel:SetPoint("TOPLEFT", 10, -28)
        instrLabel:SetText("Paste event search output below, then click Import:")
        instrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local panel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", 10, -48)
        panel:SetPoint("BOTTOMRIGHT", -10, 58)
        StyleContentPanel(panel)

        local editScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        editScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
        editScroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 4)
        OneWoW_GUI:StyleScrollBar(editScroll, { container = panel })

        local editBox = CreateFrame("EditBox", nil, editScroll)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(GameFontNormalSmall)
        editBox:SetHeight(400)
        editBox:SetMaxLetters(0)
        editBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        editScroll:SetScrollChild(editBox)

        editScroll:HookScript("OnSizeChanged", function(self, w)
            editBox:SetWidth(w)
        end)

        local statusLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statusLabel:SetPoint("BOTTOMLEFT", 10, 33)
        statusLabel:SetText("")
        statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

        local importBtn = OneWoW_GUI:CreateButton(frame, { text = "Import Events", width = 120, height = 26 })
        importBtn:SetPoint("BOTTOMRIGHT", -100, 8)
        importBtn:SetScript("OnClick", function()
            local text = editBox:GetText()
            if not text or text == "" then
                statusLabel:SetText("Nothing to import - paste event output first")
                return
            end
            local count = Addon.EventMonitor:ImportEvents(text)
            if count == 0 then
                statusLabel:SetText("No events found in pasted text")
            else
                statusLabel:SetText("Imported " .. count .. " event(s) - now monitoring")
                if not Addon.EventMonitor.monitoring then
                    Addon.EventMonitor:Start()
                end
            end
        end)

        local cancelBtn = OneWoW_GUI:CreateButton(frame, { text = "Close", width = 80, height = 26 })
        cancelBtn:SetPoint("BOTTOMRIGHT", -10, 8)
        cancelBtn:SetScript("OnClick", function()
            frame:Hide()
        end)

        frame.editBox = editBox
        frame.statusLabel = statusLabel
        self.importDialog = frame
    end

    self.importDialog.editBox:SetText("")
    self.importDialog.statusLabel:SetText("")
    self.importDialog:Show()
    self.importDialog.editBox:SetFocus()
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

return UI
