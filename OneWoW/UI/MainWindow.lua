local ADDON_NAME, ns = ...

local UI = ns.UI
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

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
local placeholderData = {}
local FRAME_NAME = "OneWoWMainWindow"

local function RemoveFromUISpecialFrames(name)
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == name then
            tremove(UISpecialFrames, i)
        end
    end
end

local function EnsureInUISpecialFrames(name)
    for _, v in ipairs(UISpecialFrames) do
        if v == name then return end
    end
    tinsert(UISpecialFrames, name)
end

hooksecurefunc("ToggleGameMenu", function()
    if MainWindow and MainWindow:IsShown() then
        UI:Hide()
        if GameMenuFrame and GameMenuFrame:IsShown() then
            HideUIPanel(GameMenuFrame)
        end
    end
end)

local function CreateRow1TabButton(parent, text, moduleName)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(30)
    btn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    btn.text = OneWoW_GUI:CreateFS(btn, 12)
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    btn.moduleName = moduleName

    btn:SetScript("OnEnter", function(self)
        if self.moduleName ~= currentModuleTab then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.moduleName ~= currentModuleTab then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        end
    end)
    btn:SetScript("OnClick", function(self)
        UI:SelectModuleTab(self.moduleName)
    end)

    return btn
end

local function CreateRow2TabButton(parent, text, subTabName, disabled)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(26)
    btn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    btn.subTabName = subTabName
    btn.disabled = disabled or false

    btn.text = OneWoW_GUI:CreateFS(btn, 12)
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)

    if disabled then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        return btn
    end

    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    btn:SetScript("OnEnter", function(self)
        if self.subTabName ~= currentSubTab then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.subTabName ~= currentSubTab then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        end
    end)
    btn:SetScript("OnClick", function(self)
        UI:SelectSubTab(currentModuleTab, self.subTabName)
    end)

    return btn
end

local function UpdateRow1Styling()
    for _, btn in ipairs(row1Buttons) do
        if btn.moduleName == currentModuleTab then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end
end

local function UpdateRow2Styling()
    for _, btn in ipairs(row2Buttons) do
        if btn.disabled then
        elseif btn.subTabName == currentSubTab then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end
end

local function UpdateContentAreaAnchors()
    if not contentArea then return end
    contentArea:ClearAllPoints()
    if row2Container and row2Container:IsShown() then
        contentArea:SetPoint("TOPLEFT", row2Container, "BOTTOMLEFT", 0, -OneWoW_GUI:GetSpacing("XS"))
    else
        contentArea:SetPoint("TOPLEFT", row1Container, "BOTTOMLEFT", 0, -OneWoW_GUI:GetSpacing("XS"))
    end
    local resizeInset = 18  -- Clear 16px resize handle + 2px margin
    contentArea:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -resizeInset, resizeInset)
end

local activeContentFrame = nil

local function HideAllContent()
    if activeContentFrame and activeContentFrame.Deactivate then
        activeContentFrame:Deactivate()
    end
    activeContentFrame = nil
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
    local spacing = OneWoW_GUI:GetSpacing("XS")
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

-- Row-1 module tabs (between Home and Settings): registered modules plus
-- ALWAYS_SHOW placeholders for units not loaded yet. Rebuilt when the registry
-- gains a module after MainWindow has already initialized (mid-session Load Addon).
local function BuildDisplayModules()
    wipe(placeholderData)

    local modules = ns.ModuleRegistry:GetModules()
    local registeredNames = {}
    for _, mod in ipairs(modules) do
        registeredNames[mod.name] = true
    end

    local displayModules = {}
    for _, mod in ipairs(modules) do
        tinsert(displayModules, mod)
    end
    for _, info in ipairs(ns:GetAlwaysShowModules()) do
        if not registeredNames[info.name] then
            placeholderData[info.name] = info
            tinsert(displayModules, {
                name = info.name,
                displayName = function() return L[info.localeKey] end,
                order = info.order,
            })
        end
    end
    sort(displayModules, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.name < b.name
    end)
    return displayModules
end

local function CollectRow1ModuleTabNames()
    local names = {}
    for i = 2, #row1Buttons - 1 do
        tinsert(names, row1Buttons[i].moduleName)
    end
    return names
end

local function Row1ModuleTabsMatch(displayModules)
    if #row1Buttons < 2 then return false end
    local expected = {}
    for _, mod in ipairs(displayModules) do
        tinsert(expected, mod.name)
    end
    local current = CollectRow1ModuleTabNames()
    if #current ~= #expected then return false end
    for i = 1, #current do
        if current[i] ~= expected[i] then return false end
    end
    return true
end

function UI:RefreshRow1ModuleTabs()
    if not isInitialized or not row1Container or #row1Buttons < 2 then return end

    local displayModules = BuildDisplayModules()
    if Row1ModuleTabsMatch(displayModules) then return end

    local homeBtn = row1Buttons[1]
    local settingsBtn = row1Buttons[#row1Buttons]

    for i = #row1Buttons - 1, 2, -1 do
        local btn = row1Buttons[i]
        btn:Hide()
        btn:ClearAllPoints()
        btn:SetParent(nil)
    end

    row1Buttons = { homeBtn }
    for _, mod in ipairs(displayModules) do
        local displayText = type(mod.displayName) == "function" and mod.displayName() or mod.displayName
        local btn = CreateRow1TabButton(row1Container, displayText, mod.name)
        tinsert(row1Buttons, btn)
    end
    tinsert(row1Buttons, settingsBtn)

    LayoutRow1Buttons()
    OneWoW_GUI:ApplyFontToFrame(row1Container)
    UpdateRow1Styling()

    -- A placeholder tab may have been showing; re-select so real module content loads.
    if currentModuleTab ~= "home" and currentModuleTab ~= "settings" then
        if ns.ModuleRegistry:IsRegistered(currentModuleTab) then
            UI:SelectModuleTab(currentModuleTab)
        end
    end
end

-- Re-query the Home tab's per-feature status rows in place. Safe before the panel
-- is built and after FullReset (homePanel is nil); the OnShow hook covers those.
function UI:RefreshHomeStatus()
    if homePanel and homePanel.RefreshStatus then
        homePanel.RefreshStatus()
    end
end

local function LayoutRow2Buttons()
    if not row2Container or #row2Buttons == 0 then return end
    local containerWidth = row2Container:GetWidth()
    if containerWidth <= 0 then containerWidth = 1380 end
    local numBtns = #row2Buttons
    local spacing = OneWoW_GUI:GetSpacing("XS")
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
        btn:ClearAllPoints()
        btn:SetParent(nil)
    end
    row2Buttons = {}

    local mod = ns.ModuleRegistry:GetModule(moduleName)
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
    OneWoW_GUI:ApplyFontToFrame(row2Container)

    row2Container:Show()
    UpdateContentAreaAnchors()
end

function UI:SelectModuleTab(moduleName)
    -- Lazy modules load the first time their tab is opened. Dormant until modules
    -- become LoadOnDemand; a no-op while all modules are login-phase.
    if ns.LoadOrchestrator then
        ns.LoadOrchestrator:EnsureModuleForTab(moduleName)
    end

    currentModuleTab = moduleName
    currentSubTab = nil

    ns.db.global.lastModuleTab = moduleName

    if OneWoW_Notes_API and OneWoW_Notes_API.CloseHelpPanel then
        OneWoW_Notes_API.CloseHelpPanel()
    end

    UpdateRow1Styling()
    HideAllContent()

    if moduleName == "home" then
        row2Container:Hide()
        UpdateContentAreaAnchors()
        if not homePanel then
            homePanel = CreateFrame("Frame", nil, contentArea)
            homePanel:SetAllPoints()
            UI:CreateHomeTab(homePanel)
            OneWoW_GUI:ApplyFontToFrame(homePanel)
        end
        homePanel:Show()
        return
    end

    if moduleName == "settings" then
        if UI.settingsTabs and #UI.settingsTabs > 0 then
            for _, btn in ipairs(row2Buttons) do
                btn:Hide()
                btn:ClearAllPoints()
                btn:SetParent(nil)
            end
            row2Buttons = {}

            for _, tabInfo in ipairs(UI.settingsTabs) do
                local btn = CreateRow2TabButton(row2Container, type(tabInfo.displayName) == "function" and tabInfo.displayName() or tabInfo.displayName, tabInfo.name, tabInfo.disabled)
                table.insert(row2Buttons, btn)
            end

            LayoutRow2Buttons()
            OneWoW_GUI:ApplyFontToFrame(row2Container)
            row2Container:Show()
            UpdateContentAreaAnchors()

            local lastSub = ns.db.global.lastSubTabs["settings"]
            local firstTab = UI.settingsTabs[1].name
            local targetTab = lastSub or firstTab

            local found = false
            for _, tabInfo in ipairs(UI.settingsTabs) do
                if tabInfo.name == targetTab and not tabInfo.disabled then
                    found = true
                    break
                end
            end
            if not found then targetTab = firstTab end

            UI:SelectSubTab("settings", targetTab)
        else
            row2Container:Hide()
            UpdateContentAreaAnchors()
            if not settingsPanel then
                settingsPanel = CreateFrame("Frame", nil, contentArea)
                settingsPanel:SetAllPoints()
                UI:CreateSettingsMainTab(settingsPanel)
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
            UI:CreateAddonPlaceholderFrame(frame, placeholderData[moduleName])
            moduleContentFrames[key] = frame
            OneWoW_GUI:ApplyFontToFrame(frame)
        end
        moduleContentFrames[key]:Show()
        return
    end

    BuildRow2ForModule(moduleName)

    local mod = ns.ModuleRegistry:GetModule(moduleName)
    if mod and mod.tabs and #mod.tabs > 0 then
        local lastSub = ns.db.global.lastSubTabs[moduleName]
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

        UI:SelectSubTab(moduleName, targetTab)
    end
end

-- A sub-tab whose content depends on optional data addon(s) can declare
-- `requiresAddon` (single string), `requiresAnyAddon` (array; available when ANY
-- listed addon is loaded -- for aggregator panels), and/or `isAvailable`
-- (predicate, highest priority). When unavailable, the sub-tab renders a "Not
-- loaded" placeholder instead of its content. A tab with none of these is always
-- available (current behavior).
local function SubTabContentAvailable(tabInfo)
    if tabInfo.isAvailable then return tabInfo.isAvailable() and true or false end
    if tabInfo.requiresAddon then return C_AddOns.IsAddOnLoaded(tabInfo.requiresAddon) end
    if tabInfo.requiresAnyAddon then
        for _, addon in ipairs(tabInfo.requiresAnyAddon) do
            if C_AddOns.IsAddOnLoaded(addon) then return true end
        end
        return false
    end
    return true
end

-- Builds a module sub-tab's content frame: real content when available, otherwise
-- the shared placeholder. Tags the frame so SelectSubTab can detect a stale
-- placeholder once the backing addon loads and rebuild it in place.
local function BuildModuleSubTabFrame(tabInfo)
    local frame = CreateFrame("Frame", nil, contentArea)
    frame:SetAllPoints()
    if SubTabContentAvailable(tabInfo) then
        tabInfo.create(frame)
        frame._isPlaceholder = false
    elseif tabInfo.requiresAnyAddon then
        UI:CreateAggregatorPlaceholderFrame(frame, {
            name = (type(tabInfo.displayName) == "function" and tabInfo.displayName()) or tabInfo.displayName,
            addons = tabInfo.requiresAnyAddon,
        })
        frame._isPlaceholder = true
        frame._requiresAnyAddon = tabInfo.requiresAnyAddon
    else
        UI:CreateAddonPlaceholderFrame(frame, {
            addonName = tabInfo.requiresAddon,
            name = (type(tabInfo.displayName) == "function" and tabInfo.displayName()) or tabInfo.displayName,
        })
        frame._isPlaceholder = true
        frame._requiresAddon = tabInfo.requiresAddon
    end
    OneWoW_GUI:ApplyFontToFrame(frame)
    return frame
end

local function FindModuleTab(moduleName, subTabName)
    local mod = ns.ModuleRegistry:GetModule(moduleName)
    if not mod or not mod.tabs then return nil end
    for _, tabInfo in ipairs(mod.tabs) do
        if tabInfo.name == subTabName then return tabInfo end
    end
    return nil
end

function UI:SelectSubTab(moduleName, subTabName)
    currentSubTab = subTabName

    ns.db.global.lastSubTabs[moduleName] = subTabName

    if OneWoW_Notes_API and OneWoW_Notes_API.CloseHelpPanel then
        OneWoW_Notes_API.CloseHelpPanel()
    end

    UpdateRow2Styling()
    HideAllContent()

    local key = moduleName .. ":" .. subTabName

    -- Drop a stale placeholder so it rebuilds as real content now that its backing
    -- addon is available (e.g. after a mid-session "Load Data Addons").
    local cached = moduleContentFrames[key]
    if cached and cached._isPlaceholder then
        local tabInfo = FindModuleTab(moduleName, subTabName)
        if tabInfo and SubTabContentAvailable(tabInfo) then
            cached:Hide()
            cached:SetParent(nil)
            moduleContentFrames[key] = nil
        end
    end

    if not moduleContentFrames[key] then
        if moduleName == "settings" and UI.settingsTabs then
            for _, tabInfo in ipairs(UI.settingsTabs) do
                if tabInfo.name == subTabName and tabInfo.create then
                    local frame = CreateFrame("Frame", nil, contentArea)
                    frame:SetAllPoints()
                    tabInfo.create(frame)
                    moduleContentFrames[key] = frame
                    OneWoW_GUI:ApplyFontToFrame(frame)
                    break
                end
            end
        else
            local tabInfo = FindModuleTab(moduleName, subTabName)
            if tabInfo and tabInfo.create then
                moduleContentFrames[key] = BuildModuleSubTabFrame(tabInfo)
            end
        end
    end

    if moduleContentFrames[key] then
        moduleContentFrames[key]:Show()
        activeContentFrame = moduleContentFrames[key]
        if activeContentFrame.Activate then
            activeContentFrame:Activate()
        end
    end
end

function UI:GetContentFrame(moduleName, subTabName)
    local key = moduleName .. ":" .. subTabName
    return moduleContentFrames[key]
end

function UI:InitMainWindow()
    if isInitialized then return end
    if not ns.Constants or not ns.Constants.GUI then return end

    L = ns.L
    local C = ns.Constants.GUI

    local screenW, screenH = GetScreenWidth(), GetScreenHeight()
    local db = ns.db.global
    -- mainFramePosition is optional (nil = center); not a MergeMissing default.
    local storage = db.mainFramePosition or {}
    if db.mainFrameSize and not storage.width then
        storage.width = db.mainFrameSize.width
        storage.height = db.mainFrameSize.height
        db.mainFramePosition = storage
    end
    local frameW = storage.width or C.WINDOW_WIDTH
    local frameH = storage.height or C.WINDOW_HEIGHT
    frameW = math.min(frameW, screenW)
    frameH = math.min(frameH, screenH)

    MainWindow = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoWMainWindow",
        width = frameW,
        height = frameH,
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
    })

    if not OneWoW_GUI:RestoreWindowPosition(MainWindow, storage) then
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
    MainWindow:SetScript("OnHide", function()
        local g = ns.db.global
        g.mainFramePosition = g.mainFramePosition or {}
        OneWoW_GUI:SaveWindowPosition(MainWindow, g.mainFramePosition)
    end)
    MainWindow:Hide()

    local titleBar = OneWoW_GUI:CreateTitleBar(MainWindow, {
        title = L["ADDON_TITLE"],
        height = 20,
        showBrand = true,
        onClose = function() UI:Hide() end,
    })
    titleBar:ClearAllPoints()
    titleBar:SetPoint("TOPLEFT", MainWindow, "TOPLEFT", OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    titleBar:SetPoint("TOPRIGHT", MainWindow, "TOPRIGHT", -OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() MainWindow:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() MainWindow:StopMovingOrSizing() end)

    if ns.Search then
        ns.Search:Init(titleBar, titleBar._closeBtn)
    end

    row1Container = CreateFrame("Frame", nil, MainWindow)
    row1Container:SetHeight(C.ROW1_HEIGHT)
    row1Container:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -OneWoW_GUI:GetSpacing("XS"))
    row1Container:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -OneWoW_GUI:GetSpacing("XS"))

    row2Container = CreateFrame("Frame", nil, MainWindow)
    row2Container:SetHeight(C.ROW2_HEIGHT)
    row2Container:SetPoint("TOPLEFT", row1Container, "BOTTOMLEFT", 0, -OneWoW_GUI:GetSpacing("XS"))
    row2Container:SetPoint("TOPRIGHT", row1Container, "BOTTOMRIGHT", 0, -OneWoW_GUI:GetSpacing("XS"))
    row2Container:Hide()

    contentArea = CreateFrame("Frame", nil, MainWindow)
    UpdateContentAreaAnchors()

    local homeBtn = CreateRow1TabButton(row1Container, L["HOME_TAB"], "home")
    table.insert(row1Buttons, homeBtn)

    for _, mod in ipairs(BuildDisplayModules()) do
        local displayText = type(mod.displayName) == "function" and mod.displayName() or mod.displayName
        local btn = CreateRow1TabButton(row1Container, displayText, mod.name)
        table.insert(row1Buttons, btn)
    end

    local settingsBtn = CreateRow1TabButton(row1Container, SETTINGS, "settings")
    table.insert(row1Buttons, settingsBtn)

    row1Container:SetScript("OnSizeChanged", function()
        LayoutRow1Buttons()
    end)

    row2Container:SetScript("OnSizeChanged", function()
        LayoutRow2Buttons()
    end)
    LayoutRow1Buttons()

    if UI.BuildSettingsTabs then
        UI:BuildSettingsTabs()
    end

    local resizeBtn = CreateFrame("Button", nil, MainWindow)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetFrameLevel(MainWindow:GetFrameLevel() + 10)
    resizeBtn:SetScript("OnMouseDown", function()
        MainWindow:StartSizing("BOTTOMRIGHT")
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        MainWindow:StopMovingOrSizing()
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        local w, h = MainWindow:GetWidth(), MainWindow:GetHeight()
        if w > sw then MainWindow:SetWidth(sw) end
        if h > sh then MainWindow:SetHeight(sh) end
    end)

    EnsureInUISpecialFrames(FRAME_NAME)
    isInitialized = true

    OneWoW_GUI:ApplyFontToFrame(MainWindow)

    local lastTab = ns.db.global.lastModuleTab
    local validTab = false
    for _, btn in ipairs(row1Buttons) do
        if btn.moduleName == lastTab then
            validTab = true
            break
        end
    end
    if not validTab then lastTab = "home" end

    UI:SelectModuleTab(lastTab)
end

function UI:Show(moduleName)
    if not isInitialized then
        UI:InitMainWindow()
    else
        UI:RefreshRow1ModuleTabs()
    end
    if MainWindow then
        MainWindow:Show()
        MainWindow:Raise()
        if moduleName then
            UI:SelectModuleTab(moduleName)
        end
    end
end

function UI:Hide()
    if MainWindow then
        MainWindow:Hide()
    end
end

function UI:Toggle()
    if MainWindow and MainWindow:IsShown() then
        UI:Hide()
    else
        UI:Show()
    end
end

function UI:GetMainWindow()
    return MainWindow
end

function UI:CreateAddonPlaceholderFrame(parent, info)
    parent.addonName = info.addonName

    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(96, 96)
    icon:SetPoint("CENTER", parent, "CENTER", 0, 60)
    icon:SetTexture("Interface\\AddOns\\OneWoW\\Media\\neutral-large.png")

    local nameText = OneWoW_GUI:CreateFS(parent, 16)
    nameText:SetPoint("TOP", icon, "BOTTOM", 0, -16)
    nameText:SetText(ns.Locale:GetOptional(ADDON_NAME, info.localeKey) or info.name)
    nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local statusText = OneWoW_GUI:CreateFS(parent, 12)
    statusText:SetPoint("TOP", nameText, "BOTTOM", 0, -8)
    statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local function RefreshPlaceholderStatus()
        local state = ns:GetFeatureUnitState(parent.addonName)
        statusText:SetText(ns:GetFeatureUnitStatusLabel(state))
    end

    parent:SetScript("OnShow", RefreshPlaceholderStatus)
    RefreshPlaceholderStatus()

    local linkRow = CreateFrame("Frame", nil, parent)
    linkRow:SetSize(400, 20)
    linkRow:SetPoint("TOP", statusText, "BOTTOM", 0, -24)
    UI:CreateManageFeaturesLinkRow(linkRow, {
        pointerKey = "PLACEHOLDER_ENABLE_POINTER",
        center = true,
    })
end

--- Placeholder for an aggregator panel that has no single backing addon: it draws
--- from several optional data addons (info.addons) and is "available" when ANY of
--- them is loaded. Lists each source with its current load state so the user knows
--- what to enable in Manage Features.
---@param parent Frame
---@param info table { name: string, addons: string[] }
function UI:CreateAggregatorPlaceholderFrame(parent, info)
    local addons = info.addons or {}

    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(96, 96)
    icon:SetPoint("CENTER", parent, "CENTER", 0, 110)
    icon:SetTexture("Interface\\AddOns\\OneWoW\\Media\\neutral-large.png")

    local nameText = OneWoW_GUI:CreateFS(parent, 16)
    nameText:SetPoint("TOP", icon, "BOTTOM", 0, -16)
    nameText:SetText(info.name or "")
    nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local descText = OneWoW_GUI:CreateFS(parent, 12)
    descText:SetWidth(440)
    descText:SetJustifyH("CENTER")
    descText:SetPoint("TOP", nameText, "BOTTOM", 0, -10)
    descText:SetText(ns.L["AGGREGATOR_PLACEHOLDER_DESC"])
    descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    -- One status line per source addon (localized name + current load state).
    local sourceRows = {}
    local anchor = descText
    for _, addon in ipairs(addons) do
        local labelKey = ns:GetStoreLabelKey(addon)
        local fs = OneWoW_GUI:CreateFS(parent, 12)
        fs:SetPoint("TOP", anchor, "BOTTOM", 0, anchor == descText and -16 or -6)
        fs._addon = addon
        fs._label = (labelKey and ns.L[labelKey]) or addon
        sourceRows[#sourceRows + 1] = fs
        anchor = fs
    end

    local function RefreshSourceRows()
        for _, fs in ipairs(sourceRows) do
            local state = ns:GetFeatureUnitState(fs._addon)
            local loaded = C_AddOns.IsAddOnLoaded(fs._addon)
            fs:SetText(fs._label .. "  -  " .. ns:GetFeatureUnitStatusLabel(state))
            fs:SetTextColor(OneWoW_GUI:GetThemeColor(loaded and "TEXT_PRIMARY" or "TEXT_MUTED"))
        end
    end

    parent:SetScript("OnShow", RefreshSourceRows)
    RefreshSourceRows()

    local linkRow = CreateFrame("Frame", nil, parent)
    linkRow:SetSize(400, 20)
    linkRow:SetPoint("TOP", anchor, "BOTTOM", 0, -24)
    UI:CreateManageFeaturesLinkRow(linkRow, {
        pointerKey = "PLACEHOLDER_ENABLE_POINTER",
        center = true,
    })
end

function UI:ResetUIToDefaults()
    local C = ns.Constants.GUI
    local screenW, screenH = GetScreenWidth(), GetScreenHeight()
    local defW = math.min(C.WINDOW_WIDTH, screenW)
    local defH = math.min(C.WINDOW_HEIGHT, screenH)
    ns.db.global.mainFrameSize = { width = defW, height = defH }
    ns.db.global.mainFramePosition = nil
    UI:FullReset()
    C_Timer.After(0.1, function() UI:Show() end)
end

function UI:FullReset()
    RemoveFromUISpecialFrames(FRAME_NAME)
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

EventRegistry:RegisterCallback("ns.ModuleRegistered", function()
    UI:RefreshRow1ModuleTabs()
end)

EventRegistry:RegisterCallback("ns.FeatureStateChanged", function(_, name)
    UI:RefreshHomeStatus()
    -- A data addon loaded while its placeholder sub-tab is on screen: rebuild it in
    -- place. Off-screen placeholders rebuild lazily on next SelectSubTab. Covers
    -- both single-addon (`_requiresAddon`) and aggregator (`_requiresAnyAddon`) tabs.
    if not (activeContentFrame and activeContentFrame._isPlaceholder
        and currentModuleTab and currentSubTab) then
        return
    end
    local matches = activeContentFrame._requiresAddon == name
    if not matches and activeContentFrame._requiresAnyAddon then
        for _, addon in ipairs(activeContentFrame._requiresAnyAddon) do
            if addon == name then matches = true break end
        end
    end
    if matches then
        UI:SelectSubTab(currentModuleTab, currentSubTab)
    end
end)
