local ADDON_NAME, OneWoW = ...

_G.OneWoW = OneWoW

local L = OneWoW.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW._loadedComponents = {}
OneWoW._registeredAddons = {}
OneWoW._minimapEntries = {}

function OneWoW:RegisterMinimap(addon, label, tabKey, callback)
    -- addon: global name (e.g. "OneWoW_AltTracker")
    -- label: display string for context menu
    -- tabKey: for OneWoW.GUI:Show(tabKey) or nil if callback used
    -- callback: optional function() for custom open logic
    tinsert(self._minimapEntries, { addon = addon, label = label, tabKey = tabKey, callback = callback })
end

local KNOWN_COMPANIONS = {
    { addon = "OneWoW_GUI",             display = "GUI",          cmd = nil },
    { addon = "OneWoW_QoL",             display = "QoL",          cmd = "/1wqol" },
    { addon = "OneWoW_Notes",           display = "Notes",        cmd = "/1wn" },
    { addon = "OneWoW_AltTracker",      display = "AltTracker",   cmd = "/1wat" },
    { addon = "OneWoW_Catalog",         display = "Catalog",      cmd = "/owcat" },
    { addon = "OneWoW_DirectDeposit",   display = "DirectDeposit",cmd = "/1wdd" },
    { addon = "OneWoW_ShoppingList",    display = "ShoppingList", cmd = "/1wsl" },
    { addon = "OneWoW_Utility_DevTool", display = "DevTools",     cmd = "/1wdt" },
}

function OneWoW:RegisterLoadComponent(displayName, version, command)
    self._registeredAddons[displayName] = true
    table.insert(self._loadedComponents, { name = displayName, ver = version, cmd = command })
end

local _defaultSaveTimer = nil
local function ScheduleDefaultSave()
    if _defaultSaveTimer then
        _defaultSaveTimer:Cancel()
    end
    _defaultSaveTimer = C_Timer.NewTimer(2, function()
        if OneWoW.Profiles and OneWoW.Profiles.AutoSaveDefault then
            OneWoW.Profiles.AutoSaveDefault()
        end
    end)
end

local function ApplyLanguage()
    local lang = OneWoW_GUI:GetSetting("language")
    lang = lang or (OneWoW.db and OneWoW.db.global.language) or "enUS"
    if lang == "esMX" then lang = "esES" end
    local localeData = OneWoW.Locales[lang] or OneWoW.Locales["enUS"]
    local fallback = OneWoW.Locales["enUS"]
    for k, v in pairs(fallback) do
        OneWoW.L[k] = localeData[k] or v
    end
    L = OneWoW.L
end

local function ResetGUIOnSettingChange(self2)
    if not self2.GUI then return end
    local wasShown = self2.GUI:GetMainWindow() and self2.GUI:GetMainWindow():IsShown()
    self2.GUI:FullReset()
    if wasShown then
        C_Timer.After(0.1, function()
            if self2.GUI then self2.GUI:Show() end
        end)
    end
end

local function RegisterSlashCommands()
    SLASH_ONEWOW1 = "/ow"
    SLASH_ONEWOW2 = "/one"
    SLASH_ONEWOW3 = "/onewow"
    SLASH_ONEWOW4 = "/1w"
    SlashCmdList["ONEWOW"] = function(msg)
        if OneWoW.GUI then
            OneWoW.GUI:Toggle()
        end
    end

    SLASH_ONEWOWKEYWORDS1 = "/owkeys"
    SLASH_ONEWOWKEYWORDS2 = "/1wkeys"
    SLASH_ONEWOWKEYWORDS3 = "/onewowkeywords"
    SlashCmdList["ONEWOWKEYWORDS"] = function()
        if OneWoW_GUI and OneWoW_GUI.ShowKeywordHelp then
            OneWoW_GUI:ShowKeywordHelp()
        end
    end
end

function OneWoW:OnAddonLoaded(loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end

    self:InitializeDatabase()

    OneWoW_GUI:MigrateSettings(self.db.global)

    OneWoW_GUI:ApplyTheme(_G.OneWoW)
    ApplyLanguage()
    RegisterSlashCommands()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(self2)
        OneWoW_GUI:ApplyTheme(_G.OneWoW)
        ScheduleDefaultSave()
        ResetGUIOnSettingChange(self2)
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", self, function(self2)
        ApplyLanguage()
        ScheduleDefaultSave()
        ResetGUIOnSettingChange(self2)
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", self, function(self2, hidden)
        ScheduleDefaultSave()
        if self2.Minimap then
            if hidden then
                self2.Minimap:Hide()
            else
                self2.Minimap:Show()
            end
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function(self2)
        ScheduleDefaultSave()
        if self2.Minimap then
            self2.Minimap:UpdateIcon()
        end
        ResetGUIOnSettingChange(self2)
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function(self2)
        ScheduleDefaultSave()
        ResetGUIOnSettingChange(self2)
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", self, function(self2)
        ScheduleDefaultSave()
        ResetGUIOnSettingChange(self2)
    end)

    local _ver = OneWoW_GUI:GetAddonVersion(ADDON_NAME)
    self:RegisterLoadComponent("Core", _ver, "/1w")

    self:RegisterMinimap("OneWoW", L["CTX_OPEN_ONEWOW"] or "Open OneWoW", nil, function()
        if self.GUI then self.GUI:Show() end
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        OneWoW:OnAddonLoaded(loadedAddon)
    elseif event == "PLAYER_LOGIN" then
        if OneWoW.Minimap then
            OneWoW.Minimap:Initialize()
        end
        if OneWoW.ItemStatus then
            OneWoW.ItemStatus:Initialize()
        end
        if OneWoW.UpgradeDetection then
            OneWoW.UpgradeDetection:Initialize()
        end
        if OneWoW.OverlayEngine then
            OneWoW.OverlayEngine:Initialize()
        end
        if OneWoW.PortalHubModule then
            OneWoW.PortalHubModule:Initialize()
        end
        if OneWoW.PortalHubEsc then
            OneWoW.PortalHubEsc:Initialize()
        end
        if OneWoW.TooltipEngine then
            OneWoW.TooltipEngine:Initialize()
        end
        if OneWoW.ExternalTooltipSync_OnLogin then
            OneWoW.ExternalTooltipSync_OnLogin()
        end
        if OneWoW.InitializeContextMenus then
            OneWoW:InitializeContextMenus()
        end

        for _, comp in ipairs(KNOWN_COMPANIONS) do
            if not OneWoW._registeredAddons[comp.display] and C_AddOns.IsAddOnLoaded(comp.addon) then
                local ver = C_AddOns.GetAddOnMetadata(comp.addon, "Version") or ""
                OneWoW:RegisterLoadComponent(comp.display, ver, comp.cmd)
            end
        end

        local comps = OneWoW._loadedComponents
        if comps and #comps > 0 then
            local ver = OneWoW_GUI:GetAddonVersion(ADDON_NAME)
            local parts = {}
            for _, c in ipairs(comps) do
                table.insert(parts, "|cFFFFFFFF" .. c.name .. "|r")
            end
            print("|cFF00FF00OneWoW|r |cFF888888v." .. ver .. "|r: " .. table.concat(parts, " + ") .. " |cFF00FF00loaded|r - /1w")
        end

        -- First-run feature picker: show once per account. Delayed a few
        -- seconds so it appears AFTER the suite's load banner and any error
        -- popups have cleared.
        if OneWoW.FirstRun and OneWoW.FirstRun:ShouldShowWizard() then
            C_Timer.After(3, function()
                if OneWoW.FirstRun and OneWoW.FirstRun:ShouldShowWizard() then
                    OneWoW.FirstRun:ShowWizard()
                end
            end)
        end
    end
end)

_G["1WoW_OnAddonCompartmentClick"] = function(addonName, buttonName)
    if OneWoW.GUI then
        OneWoW.GUI:Toggle()
    end
end

_G["1WoW_OnAddonCompartmentEnter"] = function(addonName, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("|cFFFFD1001WoW|r", 1, 1, 1)
    local modCount = OneWoW.ModuleRegistry and OneWoW.ModuleRegistry:GetModuleCount() or 0
    if modCount > 0 then
        GameTooltip:AddLine(modCount .. " modules loaded", 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine(OneWoW.L and OneWoW.L["MINIMAP_TOOLTIP_HINT"] or "Click to toggle", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

_G["1WoW_OnAddonCompartmentLeave"] = function(addonName, button)
    GameTooltip:Hide()
end
