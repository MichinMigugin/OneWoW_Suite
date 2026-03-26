local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local DEFAULT_THEME_ICON = OneWoW_GUI.Constants.DEFAULT_THEME_ICON
local floor = math.floor
local max = math.max
local ipairs = ipairs
local pairs = pairs
local sort = sort
local tinsert = tinsert

local UI = {
    tabs = {},
    currentTabKey = nil,
    settingsUnloadCheckboxes = {},
}
Addon.UI = UI

function UI:StyleContentPanel(panel)
    panel:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
end

local function destroyFrame(frame)
    if not frame then return end
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(nil)
end

function UI:GetTabDefinitions()
    if self.tabDefinitions and self.orderedTabKeys then
        return self.tabDefinitions, self.orderedTabKeys
    end

    self.tabDefinitions = {
        frame = {
            key = "frame",
            order = 1,
            labelKey = "TAB_FRAME",
            create = function(parent) return self:CreateFrameInspectorTab(parent) end,
            teardown = function(tab)
                if Addon.FrameInspectorTab == tab then
                    Addon.FrameInspectorTab = nil
                end
            end,
        },
        events = {
            key = "events",
            order = 2,
            labelKey = "TAB_EVENTS",
            create = function(parent) return self:CreateEventMonitorTab(parent) end,
            teardown = function(tab)
                if tab and tab.Teardown then
                    tab:Teardown()
                elseif Addon.EventMonitorTab == tab then
                    Addon.EventMonitorTab = nil
                end
            end,
        },
        errors = {
            key = "errors",
            order = 3,
            labelKey = "TAB_ERRORS",
            create = function(parent) return self:CreateLuaConsoleTab(parent) end,
            teardown = function(tab)
                if Addon.LuaConsoleTab == tab then
                    Addon.LuaConsoleTab = nil
                end
            end,
        },
        monitor = {
            key = "monitor",
            order = 4,
            labelKey = "TAB_MONITOR",
            create = function(parent) return self:CreateMonitorTab(parent) end,
            teardown = function(tab)
                if tab and tab.Teardown then
                    tab:Teardown()
                elseif Addon.MonitorTabUI == tab then
                    Addon.MonitorTabUI = nil
                end
            end,
        },
        globals = {
            key = "globals",
            order = 5,
            labelKey = "TAB_GLOBALS",
            create = function(parent) return self:CreateGlobalsBrowserTab(parent) end,
            teardown = function(tab)
                if tab and tab._filterTicker then
                    tab._filterTicker:Cancel()
                    tab._filterTicker = nil
                end
                if tab and tab.Teardown then
                    tab:Teardown()
                elseif Addon.GlobalsBrowserTab == tab then
                    Addon.GlobalsBrowserTab = nil
                end
            end,
        },
        textures = {
            key = "textures",
            order = 6,
            labelKey = "TAB_TEXTURES",
            create = function(parent) return self:CreateTextureTab(parent) end,
            teardown = function(tab)
                if tab and tab._filterTicker then
                    tab._filterTicker:Cancel()
                    tab._filterTicker = nil
                end
                if tab and tab.Teardown then
                    tab:Teardown()
                elseif Addon.TextureBrowserTab == tab then
                    Addon.TextureBrowserTab = nil
                end
            end,
        },
        fonts = {
            key = "fonts",
            order = 7,
            labelKey = "TAB_FONTS",
            create = function(parent) return self:CreateFontBrowserTab(parent) end,
            teardown = function(tab)
                if tab and tab._filterTicker then
                    tab._filterTicker:Cancel()
                    tab._filterTicker = nil
                end
            end,
        },
        sounds = {
            key = "sounds",
            order = 8,
            labelKey = "TAB_SOUNDS",
            create = function(parent) return self:CreateSoundBrowserTab(parent) end,
            teardown = function(tab)
                if tab and tab._filterTicker then
                    tab._filterTicker:Cancel()
                    tab._filterTicker = nil
                end
                if tab and tab.Teardown then
                    tab:Teardown()
                elseif Addon.SoundBrowserTab == tab then
                    Addon.SoundBrowserTab = nil
                end
            end,
        },
        colors = {
            key = "colors",
            order = 9,
            labelKey = "TAB_COLORS",
            create = function(parent) return self:CreateColorToolsTab(parent) end,
        },
        layout = {
            key = "layout",
            order = 10,
            labelKey = "TAB_LAYOUT",
            create = function(parent) return self:CreateLayoutTab(parent) end,
            teardown = function(tab)
                if Addon.LayoutToolsTab == tab then
                    Addon.LayoutToolsTab = nil
                end
            end,
        },
        editor = {
            key = "editor",
            order = 11,
            labelKey = "TAB_EDITOR",
            create = function(parent) return self:CreateEditorTab(parent) end,
            teardown = function(tab)
                if tab and tab.Teardown then
                    tab:Teardown()
                end
            end,
        },
        settings = {
            key = "settings",
            order = 12,
            labelKey = "TAB_SETTINGS",
            create = function(parent) return self:CreateSettingsTab(parent) end,
            alwaysEnabled = true,
        },
    }

    self.orderedTabKeys = {}
    for key in pairs(self.tabDefinitions) do
        tinsert(self.orderedTabKeys, key)
    end
    sort(self.orderedTabKeys, function(a, b)
        return self.tabDefinitions[a].order < self.tabDefinitions[b].order
    end)

    return self.tabDefinitions, self.orderedTabKeys
end

function UI:GetOrderedTabKeys()
    local _, orderedKeys = self:GetTabDefinitions()
    return orderedKeys
end

function UI:GetTabDefinition(tabKey)
    local definitions = self:GetTabDefinitions()
    return definitions[tabKey]
end

function UI:GetTabSettingsDefaults()
    local defaults = {}
    for _, tabKey in ipairs(self:GetOrderedTabKeys()) do
        defaults[tabKey] = { enabled = true }
    end
    defaults.settings.enabled = true
    return defaults
end

function UI:GetUnloadOnDisable(tabKey)
    local db = Addon.db
    if type(db) ~= "table" then return false end
    if tabKey == "textures" then return db.deferTextureBrowserData == true end
    if tabKey == "sounds" then return db.deferSoundBrowserData == true end
    return false
end

function UI:UpdateUnloadCheckboxEnableState(tabKey)
    if tabKey ~= "textures" and tabKey ~= "sounds" then
        return
    end
    local cb = self.settingsUnloadCheckboxes and self.settingsUnloadCheckboxes[tabKey]
    if not cb then
        return
    end
    local parentOn = self:IsTabEnabled(tabKey)
    if parentOn then
        cb:Disable()
        if cb.label then
            cb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    else
        cb:Enable()
        if cb.label then
            cb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end
end

function UI:ApplyUnloadAssetSetting(tabKey, wantUnload)
    if tabKey ~= "textures" and tabKey ~= "sounds" then return end
    if not Addon.db then return end
    local old = self:GetUnloadOnDisable(tabKey)
    wantUnload = wantUnload and true or false
    if tabKey == "textures" then
        Addon.db.deferTextureBrowserData = wantUnload
    elseif tabKey == "sounds" then
        Addon.db.deferSoundBrowserData = wantUnload
    end
    local cb = self.settingsUnloadCheckboxes and self.settingsUnloadCheckboxes[tabKey]
    if cb then
        cb:SetChecked(wantUnload)
        self:UpdateUnloadCheckboxEnableState(tabKey)
    end
    if wantUnload and not old then
        if tabKey == "textures" and Addon.DevTool_WipeTextureAssetData then
            Addon.DevTool_WipeTextureAssetData()
        elseif tabKey == "sounds" and Addon.DevTool_WipeSoundAssetData then
            Addon.DevTool_WipeSoundAssetData()
        end
    end
end

function UI:GetTabLabel(tabKey)
    local definition = self:GetTabDefinition(tabKey)
    if not definition then
        return tabKey
    end
    return (Addon.L and Addon.L[definition.labelKey]) or tabKey
end

function UI:IsTabEnabled(tabKey)
    local definition = self:GetTabDefinition(tabKey)
    if not definition then
        return false
    end
    if definition.alwaysEnabled then
        return true
    end
    local dbTabs = Addon.db and Addon.db.tabs
    local tabSettings = dbTabs and dbTabs[tabKey]
    if type(tabSettings) == "table" and tabSettings.enabled ~= nil then
        return tabSettings.enabled and true or false
    end
    return true
end

function UI:SetTabEnabled(tabKey, enabled)
    local definition = self:GetTabDefinition(tabKey)
    if not definition or not Addon.db then
        return
    end

    Addon.db.tabs = Addon.db.tabs or {}
    Addon.db.tabs[tabKey] = Addon.db.tabs[tabKey] or {}
    if definition.alwaysEnabled then
        Addon.db.tabs[tabKey].enabled = true
    else
        Addon.db.tabs[tabKey].enabled = enabled and true or false
    end
end

function UI:GetDefaultTabKey()
    for _, tabKey in ipairs(self:GetOrderedTabKeys()) do
        if tabKey ~= "settings" and self:IsTabEnabled(tabKey) then
            return tabKey
        end
    end

    for _, tabKey in ipairs(self:GetOrderedTabKeys()) do
        if self:IsTabEnabled(tabKey) then
            return tabKey
        end
    end

    return nil
end

function UI:StyleTabButton(button, isSelected)
    button.isSelected = isSelected and true or false
    if isSelected then
        button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        button.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    else
        button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        button.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
end

function UI:CreateTabButton(tabKey)
    local button = OneWoW_GUI:CreateButton(self.mainFrame, {
        text = self:GetTabLabel(tabKey),
        width = 90,
        height = self.tabHeight,
    })

    button.isSelected = false
    button.tabKey = tabKey
    button:SetScript("OnClick", function()
        UI:SelectTab(tabKey)
    end)
    button:SetScript("OnEnter", function(self)
        if not self.isSelected then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
            self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        end
    end)
    button:SetScript("OnLeave", function(self)
        if not self.isSelected then
            UI:StyleTabButton(self, false)
        end
    end)
    button:SetScript("OnMouseDown", function(self)
        if not self.isSelected then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        if not self.isSelected then
            if self:IsMouseOver() then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            else
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            end
        end
    end)

    return button
end

function UI:EnsureTabBuilt(tabKey)
    local definition = self:GetTabDefinition(tabKey)
    if not definition or not self.mainFrame or not self.contentFrame then
        return nil
    end

    local tab = self.tabs[tabKey]
    if tab then
        if tab.button and tab.button.text then
            tab.button.text:SetText(self:GetTabLabel(tabKey))
        end
        return tab
    end

    local button = self:CreateTabButton(tabKey)
    local content = definition.create(self.contentFrame)
    if content then
        content:Hide()
    end

    tab = {
        key = tabKey,
        button = button,
        content = content,
    }
    self.tabs[tabKey] = tab
    return tab
end

function UI:DestroyTab(tabKey)
    local tab = self.tabs[tabKey]
    if not tab then
        return
    end

    local definition = self:GetTabDefinition(tabKey)
    if definition and definition.teardown and tab.content then
        definition.teardown(tab.content)
    end

    if tab.button then
        tab.button:SetScript("OnClick", nil)
        tab.button:SetScript("OnEnter", nil)
        tab.button:SetScript("OnLeave", nil)
        tab.button:SetScript("OnMouseDown", nil)
        tab.button:SetScript("OnMouseUp", nil)
        destroyFrame(tab.button)
    end

    if tab.content then
        destroyFrame(tab.content)
    end

    self.tabs[tabKey] = nil
    if self.currentTabKey == tabKey then
        self.currentTabKey = nil
    end
end

function UI:LayoutTabButtons()
    if not self.mainFrame then
        return
    end

    local visibleTabKeys = {}
    for _, tabKey in ipairs(self:GetOrderedTabKeys()) do
        if self:IsTabEnabled(tabKey) then
            tinsert(visibleTabKeys, tabKey)
        end
    end

    self.visibleTabKeys = visibleTabKeys
    local count = #visibleTabKeys
    if count == 0 then
        return
    end

    local availWidth = self.mainFrame:GetWidth() - OneWoW_GUI:GetSpacing("SM") * 2 - (count - 1) * self.tabGap
    local tabWidth = max(1, floor(availWidth / count))

    for index, tabKey in ipairs(visibleTabKeys) do
        local tab = self.tabs[tabKey]
        if tab and tab.button then
            tab.button:ClearAllPoints()
            tab.button:SetWidth(tabWidth)
            tab.button:SetHeight(self.tabHeight)
            tab.button.text:SetText(self:GetTabLabel(tabKey))
            if index == 1 then
                tab.button:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", OneWoW_GUI:GetSpacing("SM"), self.tabY)
            else
                local previousTab = self.tabs[visibleTabKeys[index - 1]]
                if previousTab and previousTab.button then
                    tab.button:SetPoint("LEFT", previousTab.button, "RIGHT", self.tabGap, 0)
                end
            end
            tab.button:Show()
        end
    end
end

function UI:RefreshTabs(preferredTabKey)
    if not self.mainFrame or not self.contentFrame then
        return
    end

    for _, tabKey in ipairs(self:GetOrderedTabKeys()) do
        if self:IsTabEnabled(tabKey) then
            self:EnsureTabBuilt(tabKey)
        else
            self:DestroyTab(tabKey)
        end
    end

    self:LayoutTabButtons()

    local targetTabKey = preferredTabKey
    if not targetTabKey or not self.tabs[targetTabKey] or not self:IsTabEnabled(targetTabKey) then
        if self.currentTabKey and self.tabs[self.currentTabKey] and self:IsTabEnabled(self.currentTabKey) then
            targetTabKey = self.currentTabKey
        else
            targetTabKey = self:GetDefaultTabKey()
        end
    end

    if targetTabKey then
        self:SelectTab(targetTabKey)
    end
end

function UI:Initialize()
    if self.mainFrame then return end

    local DU = Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
    local defaultW = DU.MAIN_FRAME_DEFAULT_WIDTH or 750
    local defaultH = DU.MAIN_FRAME_DEFAULT_HEIGHT or 450
    local resizeCap = DU.MAIN_FRAME_RESIZE_CAP or 0.95
    self.tabGap = DU.TAB_GAP or 4
    self.tabHeight = DU.TAB_HEIGHT or 28

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or DEFAULT_THEME_ICON
    local frame = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_UtilityDevToolFrame",
        width = defaultW,
        height = defaultH,
        backdrop = BACKDROP_INNER_NO_INSETS,
    })
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    -- Explicit level so OneWoW_GUI AttachFilterMenu can place overlay below and menu above this frame (same strata).
    frame:SetFrameLevel(10)
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

    self.tabY = -(OneWoW_GUI:GetSpacing("XS") + 20 + OneWoW_GUI:GetSpacing("XS"))

    frame:HookScript("OnSizeChanged", function()
        UI:LayoutTabButtons()
    end)

    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     OneWoW_GUI:GetSpacing("SM"), -(OneWoW_GUI:GetSpacing("XS") + 20 + OneWoW_GUI:GetSpacing("XS") + self.tabHeight + OneWoW_GUI:GetSpacing("XS")))
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("SM"), OneWoW_GUI:GetSpacing("SM"))

    self.mainFrame = frame
    self.contentFrame = contentFrame
    self.tabs = {}

    local combatHide = CreateFrame("Frame", nil, frame)
    combatHide:SetScript("OnEvent", function()
        if frame:IsShown() then
            UI:Hide()
        end
    end)
    combatHide:RegisterEvent("PLAYER_REGEN_DISABLED")

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

    self:RefreshTabs(self:GetDefaultTabKey())
end

function UI:SelectTab(tabKey)
    if not tabKey or not self:IsTabEnabled(tabKey) or not self.tabs[tabKey] then
        tabKey = self:GetDefaultTabKey()
    end
    if not tabKey then
        return
    end

    self.currentTabKey = tabKey

    for key, tab in pairs(self.tabs) do
        if key == tabKey then
            tab.content:Show()
            if key == "events" and Addon.EventMonitor then
                Addon.EventMonitor:UpdateUI()
            elseif key == "sounds" and Addon.UI.SoundTab_RefreshSoundCvarCheckboxes then
                Addon.UI.SoundTab_RefreshSoundCvarCheckboxes()
            end
            self:StyleTabButton(tab.button, true)
        else
            tab.content:Hide()
            self:StyleTabButton(tab.button, false)
        end
    end
end

function UI:Show()
    self:Initialize()
    self.mainFrame:Show()
    if self.currentTabKey and self:IsTabEnabled(self.currentTabKey) then
        self:SelectTab(self.currentTabKey)
    else
        self:SelectTab(self:GetDefaultTabKey())
    end
end

function UI:Hide()
    if Addon.UI.SoundTab_GlobalStopPlayback then
        Addon.UI.SoundTab_GlobalStopPlayback()
    end
    if self.mainFrame then
        self.mainFrame:Hide()
    end
end

function UI:FullReset()
    if self.mainFrame then
        local selectedTabKey = self.currentTabKey
        for _, tabKey in ipairs(self:GetOrderedTabKeys()) do
            self:DestroyTab(tabKey)
        end
        self.mainFrame:Hide()
        self.mainFrame:SetParent(nil)
        self.mainFrame = nil
        self.contentFrame = nil
        self.tabs = {}
        self.settingsUnloadCheckboxes = {}
        self.currentTabKey = selectedTabKey
    end
end
