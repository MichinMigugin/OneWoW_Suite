local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI
local L = OneWoW.L
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local function T(key) return OneWoW_GUI:GetThemeColor(key) end
local function S(key) return OneWoW_GUI:GetSpacing(key) end

local MainWindow = nil
local isInitialized = false
local currentModuleTab = "home"
local currentSubTab = nil
local row1Buttons = {}
local row2Buttons = {}
local moduleContentFrames = {}
local row1Container = nil
local row2Container = nil
local contentArea = nil
local homePanel = nil
local settingsPanel = nil
local ALWAYS_SHOW_MODULES = {
    { name = "notes",      addonName = "OneWoW_Notes",    order = 1, localeKey = "MODULE_NOTES",
      url = "https://www.curseforge.com/wow/addons/onewow-notes" },
    { name = "alttracker", addonName = "OneWoW_AltTracker", order = 2, localeKey = "MODULE_ALTTRACKER",
      url = "https://www.curseforge.com/wow/addons/onewow-alttracker" },
    { name = "catalog",    addonName = "OneWoW_Catalog",  order = 4, localeKey = "MODULE_CATALOG",
      url = "https://www.curseforge.com/wow/addons/onewow-catalog" },
}
local placeholderData = {}

local function GetBrandIcon()
    local db = OneWoW.db
    local factionTheme = db and db.global and db.global.minimap and db.global.minimap.theme or "horde"
    if factionTheme == "alliance" then
        return "Interface\\AddOns\\OneWoW\\Media\\alliance-mini.png"
    elseif factionTheme == "neutral" then
        return "Interface\\AddOns\\OneWoW\\Media\\neutral-mini.png"
    end
    return "Interface\\AddOns\\OneWoW\\Media\\horde-mini.png"
end

local function CreateRow1TabButton(parent, text, moduleName)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(30)
    btn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    btn:SetBackdropColor(T("BG_SECONDARY"))
    btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn.text:SetTextColor(T("TEXT_PRIMARY"))
    btn.moduleName = moduleName

    btn:SetScript("OnEnter", function(self)
        if self.moduleName ~= currentModuleTab then
            self:SetBackdropColor(T("BG_HOVER"))
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.moduleName ~= currentModuleTab then
            self:SetBackdropColor(T("BG_SECONDARY"))
        end
    end)
    btn:SetScript("OnClick", function(self)
        GUI:SelectModuleTab(self.moduleName)
    end)

    return btn
end

local function CreateRow2TabButton(parent, text, subTabName, disabled)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(26)
    btn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    btn.subTabName = subTabName
    btn.disabled = disabled or false

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)

    if disabled then
        btn:SetBackdropColor(T("BG_PRIMARY"))
        btn:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.6)
        btn.text:SetTextColor(0.32, 0.32, 0.32, 1)
        return btn
    end

    btn:SetBackdropColor(T("BG_SECONDARY"))
    btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    btn.text:SetTextColor(T("TEXT_PRIMARY"))

    btn:SetScript("OnEnter", function(self)
        if self.subTabName ~= currentSubTab then
            self:SetBackdropColor(T("BG_HOVER"))
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.subTabName ~= currentSubTab then
            self:SetBackdropColor(T("BG_SECONDARY"))
        end
    end)
    btn:SetScript("OnClick", function(self)
        GUI:SelectSubTab(currentModuleTab, self.subTabName)
    end)

    return btn
end

local function UpdateRow1Styling()
    for _, btn in ipairs(row1Buttons) do
        if btn.moduleName == currentModuleTab then
            btn:SetBackdropColor(T("BG_ACTIVE"))
            btn:SetBackdropBorderColor(T("BORDER_ACCENT"))
            btn.text:SetTextColor(T("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(T("BG_SECONDARY"))
            btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            btn.text:SetTextColor(T("TEXT_PRIMARY"))
        end
    end
end

local function UpdateRow2Styling()
    for _, btn in ipairs(row2Buttons) do
        if btn.disabled then
        elseif btn.subTabName == currentSubTab then
            btn:SetBackdropColor(T("BG_ACTIVE"))
            btn:SetBackdropBorderColor(T("BORDER_ACCENT"))
            btn.text:SetTextColor(T("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(T("BG_SECONDARY"))
            btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            btn.text:SetTextColor(T("TEXT_PRIMARY"))
        end
    end
end

local function UpdateContentAreaAnchors()
    if not contentArea then return end
    contentArea:ClearAllPoints()
    if row2Container and row2Container:IsShown() then
        contentArea:SetPoint("TOPLEFT", row2Container, "BOTTOMLEFT", 0, -S("XS"))
    else
        contentArea:SetPoint("TOPLEFT", row1Container, "BOTTOMLEFT", 0, -S("XS"))
    end
    contentArea:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -S("XS"), S("XS"))
end

local function HideAllContent()
    if homePanel then homePanel:Hide() end
    if settingsPanel then settingsPanel:Hide() end
    for _, frame in pairs(moduleContentFrames) do
        frame:Hide()
    end
end

local function LayoutRow1Buttons()
    if not row1Container or #row1Buttons == 0 then return end
    local containerWidth = row1Container:GetWidth()
    if containerWidth <= 0 then containerWidth = 1380 end
    local numBtns = #row1Buttons
    local spacing = S("XS")
    local btnWidth = (containerWidth - (numBtns - 1) * spacing) / numBtns

    for i, btn in ipairs(row1Buttons) do
        btn:ClearAllPoints()
        btn:SetWidth(btnWidth)
        if i == 1 then
            btn:SetPoint("TOPLEFT", row1Container, "TOPLEFT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", row1Buttons[i - 1], "TOPRIGHT", spacing, 0)
        end
    end
end

local function LayoutRow2Buttons()
    if not row2Container or #row2Buttons == 0 then return end
    local containerWidth = row2Container:GetWidth()
    if containerWidth <= 0 then containerWidth = 1380 end
    local numBtns = #row2Buttons
    local spacing = S("XS")
    local btnWidth = (containerWidth - (numBtns - 1) * spacing) / numBtns

    for i, btn in ipairs(row2Buttons) do
        btn:ClearAllPoints()
        btn:SetWidth(btnWidth)
        if i == 1 then
            btn:SetPoint("TOPLEFT", row2Container, "TOPLEFT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", row2Buttons[i - 1], "TOPRIGHT", spacing, 0)
        end
    end
end

local function BuildRow2ForModule(moduleName)
    for _, btn in ipairs(row2Buttons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    row2Buttons = {}

    local mod = OneWoW.ModuleRegistry:GetModule(moduleName)
    if not mod or not mod.tabs or #mod.tabs == 0 then
        row2Container:Hide()
        UpdateContentAreaAnchors()
        return
    end

    for _, tabInfo in ipairs(mod.tabs) do
        local displayText = type(tabInfo.displayName) == "function" and tabInfo.displayName() or tabInfo.displayName
        local btn = CreateRow2TabButton(row2Container, displayText, tabInfo.name)
        table.insert(row2Buttons, btn)
    end

    LayoutRow2Buttons()
    GUI:ApplyFontToFrame(row2Container)

    row2Container:Show()
    UpdateContentAreaAnchors()
end

function GUI:SelectModuleTab(moduleName)
    currentModuleTab = moduleName
    currentSubTab = nil

    if OneWoW.db and OneWoW.db.global then
        OneWoW.db.global.lastModuleTab = moduleName
    end

    if _G.OneWoW_Notes and _G.OneWoW_Notes.CloseHelpPanel then
        _G.OneWoW_Notes:CloseHelpPanel()
    end

    UpdateRow1Styling()
    HideAllContent()

    if moduleName == "home" then
        row2Container:Hide()
        UpdateContentAreaAnchors()
        if not homePanel then
            homePanel = CreateFrame("Frame", nil, contentArea)
            homePanel:SetAllPoints()
            GUI:CreateHomeTab(homePanel)
            GUI:ApplyFontToFrame(homePanel)
        end
        homePanel:Show()
        return
    end

    if moduleName == "settings" then
        if GUI.settingsTabs and #GUI.settingsTabs > 0 then
            for _, btn in ipairs(row2Buttons) do
                btn:Hide()
                btn:SetParent(nil)
            end
            row2Buttons = {}

            for _, tabInfo in ipairs(GUI.settingsTabs) do
                local btn = CreateRow2TabButton(row2Container, type(tabInfo.displayName) == "function" and tabInfo.displayName() or tabInfo.displayName, tabInfo.name, tabInfo.disabled)
                table.insert(row2Buttons, btn)
            end

            LayoutRow2Buttons()
            GUI:ApplyFontToFrame(row2Container)
            row2Container:Show()
            UpdateContentAreaAnchors()

            local lastSub = OneWoW.db and OneWoW.db.global and OneWoW.db.global.lastSubTabs and OneWoW.db.global.lastSubTabs["settings"]
            local firstTab = GUI.settingsTabs[1].name
            local targetTab = lastSub or firstTab

            local found = false
            for _, tabInfo in ipairs(GUI.settingsTabs) do
                if tabInfo.name == targetTab and not tabInfo.disabled then
                    found = true
                    break
                end
            end
            if not found then targetTab = firstTab end

            GUI:SelectSubTab("settings", targetTab)
        else
            row2Container:Hide()
            UpdateContentAreaAnchors()
            if not settingsPanel then
                settingsPanel = CreateFrame("Frame", nil, contentArea)
                settingsPanel:SetAllPoints()
                GUI:CreateSettingsMainTab(settingsPanel)
            end
            settingsPanel:Show()
        end
        return
    end

    if placeholderData[moduleName] then
        row2Container:Hide()
        UpdateContentAreaAnchors()
        local key = moduleName .. ":placeholder"
        if not moduleContentFrames[key] then
            local frame = CreateFrame("Frame", nil, contentArea)
            frame:SetAllPoints()
            GUI:CreateAddonPlaceholderFrame(frame, placeholderData[moduleName])
            moduleContentFrames[key] = frame
            GUI:ApplyFontToFrame(frame)
        end
        moduleContentFrames[key]:Show()
        return
    end

    BuildRow2ForModule(moduleName)

    local mod = OneWoW.ModuleRegistry:GetModule(moduleName)
    if mod and mod.tabs and #mod.tabs > 0 then
        local lastSub = OneWoW.db and OneWoW.db.global and OneWoW.db.global.lastSubTabs and OneWoW.db.global.lastSubTabs[moduleName]
        local firstTab = mod.tabs[1].name
        local targetTab = lastSub or firstTab

        local found = false
        for _, tabInfo in ipairs(mod.tabs) do
            if tabInfo.name == targetTab then
                found = true
                break
            end
        end
        if not found then targetTab = firstTab end

        GUI:SelectSubTab(moduleName, targetTab)
    end
end

function GUI:SelectSubTab(moduleName, subTabName)
    currentSubTab = subTabName

    if OneWoW.db and OneWoW.db.global and OneWoW.db.global.lastSubTabs then
        OneWoW.db.global.lastSubTabs[moduleName] = subTabName
    end

    if _G.OneWoW_Notes and _G.OneWoW_Notes.CloseHelpPanel then
        _G.OneWoW_Notes:CloseHelpPanel()
    end

    UpdateRow2Styling()
    HideAllContent()

    local key = moduleName .. ":" .. subTabName
    if not moduleContentFrames[key] then
        if moduleName == "settings" and GUI.settingsTabs then
            for _, tabInfo in ipairs(GUI.settingsTabs) do
                if tabInfo.name == subTabName and tabInfo.create then
                    local frame = CreateFrame("Frame", nil, contentArea)
                    frame:SetAllPoints()
                    tabInfo.create(frame)
                    moduleContentFrames[key] = frame
                    GUI:ApplyFontToFrame(frame)
                    break
                end
            end
        else
            local mod = OneWoW.ModuleRegistry:GetModule(moduleName)
            if mod and mod.tabs then
                for _, tabInfo in ipairs(mod.tabs) do
                    if tabInfo.name == subTabName and tabInfo.create then
                        local frame = CreateFrame("Frame", nil, contentArea)
                        frame:SetAllPoints()
                        tabInfo.create(frame)
                        moduleContentFrames[key] = frame
                        GUI:ApplyFontToFrame(frame)
                        break
                    end
                end
            end
        end
    end

    if moduleContentFrames[key] then
        moduleContentFrames[key]:Show()
    end
end

function GUI:InitMainWindow()
    if isInitialized then return end
    if not OneWoW.Constants or not OneWoW.Constants.GUI then return end

    L = OneWoW.L
    local C = OneWoW.Constants.GUI

    local screenW, screenH = GetScreenWidth(), GetScreenHeight()

    local savedSize = OneWoW.db and OneWoW.db.global and OneWoW.db.global.mainFrameSize
    local frameW = savedSize and savedSize.width or C.WINDOW_WIDTH
    local frameH = savedSize and savedSize.height or C.WINDOW_HEIGHT

    frameW = math.min(frameW, screenW)
    frameH = math.min(frameH, screenH)

    if savedSize then
        savedSize.width = frameW
        savedSize.height = frameH
    end

    MainWindow = GUI:CreateFrame("OneWoWMainWindow", UIParent, frameW, frameH, true)

    local savedPos = OneWoW.db and OneWoW.db.global and OneWoW.db.global.mainFramePosition
    if savedPos then
        MainWindow:ClearAllPoints()
        MainWindow:SetPoint(savedPos.point, UIParent, savedPos.relativePoint, savedPos.x, savedPos.y)
    else
        MainWindow:SetPoint("CENTER")
    end

    MainWindow:SetMovable(true)
    MainWindow:EnableMouse(true)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetResizable(true)
    local maxW = math.min(C.MAX_WIDTH, screenW)
    local maxH = math.min(C.MAX_HEIGHT, screenH)
    MainWindow:SetResizeBounds(C.MIN_WIDTH, C.MIN_HEIGHT, maxW, maxH)
    MainWindow:Hide()

    MainWindow:SetScript("OnDragStart", function(self) self:StartMoving() end)
    MainWindow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        if OneWoW.db and OneWoW.db.global then
            OneWoW.db.global.mainFramePosition = { point = point, relativePoint = relativePoint, x = x, y = y }
        end
    end)
    MainWindow:RegisterForDrag("LeftButton")

    local titleBar = OneWoW_GUI:CreateTitleBar(MainWindow, L["ADDON_TITLE"] or "OneWoW", {
        height = 20,
        showBrand = true,
        onClose = function() GUI:Hide() end,
    })
    titleBar:ClearAllPoints()
    titleBar:SetPoint("TOPLEFT", MainWindow, "TOPLEFT", S("XS"), -S("XS"))
    titleBar:SetPoint("TOPRIGHT", MainWindow, "TOPRIGHT", -S("XS"), -S("XS"))
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() MainWindow:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        MainWindow:StopMovingOrSizing()
        local point, relativeTo, relativePoint, x, y = MainWindow:GetPoint()
        if OneWoW.db and OneWoW.db.global then
            OneWoW.db.global.mainFramePosition = { point = point, relativePoint = relativePoint, x = x, y = y }
        end
    end)

    if OneWoW.Search then
        OneWoW.Search:Init(titleBar, titleBar._closeBtn)
    end

    row1Container = CreateFrame("Frame", nil, MainWindow)
    row1Container:SetHeight(C.ROW1_HEIGHT)
    row1Container:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -S("XS"))
    row1Container:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -S("XS"))

    row2Container = CreateFrame("Frame", nil, MainWindow)
    row2Container:SetHeight(C.ROW2_HEIGHT)
    row2Container:SetPoint("TOPLEFT", row1Container, "BOTTOMLEFT", 0, -S("XS"))
    row2Container:SetPoint("TOPRIGHT", row1Container, "BOTTOMRIGHT", 0, -S("XS"))
    row2Container:Hide()

    contentArea = CreateFrame("Frame", nil, MainWindow)
    UpdateContentAreaAnchors()

    local modules = OneWoW.ModuleRegistry:GetModules()
    local registeredNames = {}
    for _, mod in ipairs(modules) do
        registeredNames[mod.name] = true
    end

    local homeBtn = CreateRow1TabButton(row1Container, L["HOME_TAB"] or "OneWoW", "home")
    table.insert(row1Buttons, homeBtn)

    local displayModules = {}
    for _, mod in ipairs(modules) do
        table.insert(displayModules, mod)
    end
    for _, info in ipairs(ALWAYS_SHOW_MODULES) do
        if not registeredNames[info.name] then
            placeholderData[info.name] = info
            table.insert(displayModules, {
                name = info.name,
                displayName = function() return L[info.localeKey] or info.name end,
                order = info.order,
            })
        end
    end
    table.sort(displayModules, function(a, b) return a.order < b.order end)

    for _, mod in ipairs(displayModules) do
        local displayText = type(mod.displayName) == "function" and mod.displayName() or mod.displayName
        local btn = CreateRow1TabButton(row1Container, displayText, mod.name)
        table.insert(row1Buttons, btn)
    end

    local settingsBtn = CreateRow1TabButton(row1Container, L["SETTINGS_TAB"] or "Settings", "settings")
    table.insert(row1Buttons, settingsBtn)

    row1Container:SetScript("OnSizeChanged", function()
        LayoutRow1Buttons()
    end)

    row2Container:SetScript("OnSizeChanged", function()
        LayoutRow2Buttons()
    end)
    LayoutRow1Buttons()

    if GUI.BuildSettingsTabs then
        GUI:BuildSettingsTabs()
    end

    local resizeBtn = CreateFrame("Button", nil, MainWindow)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function()
        MainWindow:StartSizing("BOTTOMRIGHT")
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        MainWindow:StopMovingOrSizing()
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        local w, h = MainWindow:GetWidth(), MainWindow:GetHeight()
        if w > sw then MainWindow:SetWidth(sw) end
        if h > sh then MainWindow:SetHeight(sh) end
        if OneWoW.db and OneWoW.db.global and OneWoW.db.global.mainFrameSize then
            OneWoW.db.global.mainFrameSize.width = MainWindow:GetWidth()
            OneWoW.db.global.mainFrameSize.height = MainWindow:GetHeight()
        end
    end)

    tinsert(UISpecialFrames, "OneWoWMainWindow")
    isInitialized = true

    GUI:ApplyFontToFrame(MainWindow)

    local lastTab = OneWoW.db and OneWoW.db.global and OneWoW.db.global.lastModuleTab or "home"
    local validTab = false
    for _, btn in ipairs(row1Buttons) do
        if btn.moduleName == lastTab then
            validTab = true
            break
        end
    end
    if not validTab then lastTab = "home" end

    GUI:SelectModuleTab(lastTab)
end

function GUI:Show(moduleName)
    if not isInitialized then
        GUI:InitMainWindow()
    end
    if MainWindow then
        MainWindow:Show()
        MainWindow:Raise()
        if moduleName then
            GUI:SelectModuleTab(moduleName)
        end
    end
end

function GUI:Hide()
    if MainWindow then
        MainWindow:Hide()
    end
end

function GUI:Toggle()
    if MainWindow and MainWindow:IsShown() then
        GUI:Hide()
    else
        GUI:Show()
    end
end

function GUI:CreateAddonPlaceholderFrame(parent, info)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(96, 96)
    icon:SetPoint("CENTER", parent, "CENTER", 0, 60)
    icon:SetTexture("Interface\\AddOns\\OneWoW\\Media\\neutral-large.png")

    local nameText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("TOP", icon, "BOTTOM", 0, -16)
    nameText:SetText(L[info.localeKey] or info.name)
    nameText:SetTextColor(T("TEXT_PRIMARY"))

    local statusText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOP", nameText, "BOTTOM", 0, -8)
    statusText:SetText(L["HOME_NOT_DETECTED"])
    statusText:SetTextColor(T("TEXT_MUTED"))

    local installLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    installLabel:SetPoint("TOP", statusText, "BOTTOM", 0, -24)
    installLabel:SetText(L["HOME_INSTALL_FROM_CURSE"])
    installLabel:SetTextColor(T("TEXT_SECONDARY"))

    local urlBox = GUI:CreateEditBox("OneWoW_Placeholder_" .. info.name .. "_URL", parent, 400, 24)
    urlBox:SetPoint("TOP", installLabel, "BOTTOM", 0, -8)
    urlBox:SetText(info.url)
    urlBox:SetAutoFocus(false)
    urlBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    urlBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)
end

function GUI:ResetUIToDefaults()
    if OneWoW.db and OneWoW.db.global then
        local C = OneWoW.Constants.GUI
        local screenW, screenH = GetScreenWidth(), GetScreenHeight()
        local defW = math.min(C.WINDOW_WIDTH, screenW)
        local defH = math.min(C.WINDOW_HEIGHT, screenH)
        OneWoW.db.global.mainFrameSize = { width = defW, height = defH }
        OneWoW.db.global.mainFramePosition = nil
    end
    GUI:FullReset()
    C_Timer.After(0.1, function() GUI:Show() end)
end

function GUI:FullReset()
    if MainWindow then
        MainWindow:Hide()
        MainWindow:SetParent(nil)
    end
    MainWindow = nil
    isInitialized = false
    currentModuleTab = "home"
    currentSubTab = nil
    row1Buttons = {}
    row2Buttons = {}
    moduleContentFrames = {}
    row1Container = nil
    row2Container = nil
    contentArea = nil
    homePanel = nil
    settingsPanel = nil
    placeholderData = {}
end
