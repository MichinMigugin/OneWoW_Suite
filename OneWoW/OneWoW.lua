local ADDON_NAME, OneWoW = ...

-- Using _G[""] form so pre-commit hook is satisfied, but also because we can't do
-- `OneWoW = OneWoW` since it's already defined as a local
_G["OneWoW"] = OneWoW

local L = OneWoW.L

local OneWoW_GUI = OneWoW_GUI

OneWoW._loadedComponents = {}
OneWoW._registeredAddons = {}
OneWoW._minimapEntries = {}

function OneWoW:RegisterMinimap(addon, label, tabKey, callback)
    -- addon: global name (e.g. "OneWoW_AltTracker")
    -- label: display string for context menu
    -- tabKey: for OneWoW.UI:Show(tabKey) or nil if callback used
    -- callback: optional function() for custom open logic
    tinsert(self._minimapEntries, { addon = addon, label = label, tabKey = tabKey, callback = callback })
end

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
    -- Locale service folds enUS <- selected language, refolds the stable OneWoW.L
    -- view in place, and pushes BINDING_* globals. esMX->esES is normalized inside.
    OneWoW.Locale:SetLanguage(lang)
end

local function ResetGUIOnSettingChange(self2)
    if not self2.UI then return end
    local wasShown = self2.UI:GetMainWindow() and self2.UI:GetMainWindow():IsShown()
    self2.UI:FullReset()
    if wasShown then
        C_Timer.After(0.1, function()
            if self2.UI then self2.UI:Show() end
        end)
    end
end

local function RegisterSlashCommands()
    SLASH_ONEWOW1 = "/ow"
    SLASH_ONEWOW2 = "/one"
    SLASH_ONEWOW3 = "/onewow"
    SLASH_ONEWOW4 = "/1w"
    SlashCmdList["ONEWOW"] = function()
        if OneWoW.UI then
            OneWoW.UI:Toggle()
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

    -- Unified DB first (OneWoW_GUI_DB folded into OneWoW_DB in MIGRATION
    -- step 8), then the toolkit binds its settings handle to it — before any
    -- theme/font reads or module UI built by the orchestrator below.
    self:InitializeDatabase()
    OneWoW_GUI:InitializeSettings(self.db)

    -- Read the persisted lifecycle-trace flag into memory before RunStartupPhase
    -- so a /reload captures the full startup orchestration from the first event.
    OneWoW.Lifecycle.Trace:Sync()

    OneWoW_GUI:ApplyTheme(OneWoW)
    ApplyLanguage()
    RegisterSlashCommands()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(self2)
        OneWoW_GUI:ApplyTheme(OneWoW)
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

    local _ver = OneWoW:GetAddonVersion(ADDON_NAME)
    self:RegisterLoadComponent("Core", _ver, "/1w")

    self:RegisterMinimap("OneWoW", L["CTX_OPEN_ONEWOW"], nil, function()
        if self.UI then self.UI:Show() end
    end)

    -- Pull enabled Tier-2 modules and their data stores now (still inside core's
    -- ADDON_LOADED, before PLAYER_LOGIN). EnsureLoaded drives each unit's
    -- OnAddonLoaded() hook synchronously, so every DB is built in dependency order
    -- before any PLAYER_LOGIN fires.
    if OneWoW.LoadOrchestrator then
        OneWoW.LoadOrchestrator:RunStartupPhase()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        OneWoW:DispatchAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        -- After this point, a mid-session LoadAddOn won't deliver the unit's own
        -- one-shot PLAYER_LOGIN, so OneWoW:EnsureLoaded drives its login hooks.
        OneWoW._playerLoginFired = true
        -- Feature inits register themselves as "early" handlers in their own
        -- files; "late" handlers (integrations) run after the load banner.
        OneWoW:FireCoreLoginHandlers("early")

        for _, comp in ipairs(OneWoW.ModuleManifest or {}) do
            if not OneWoW._registeredAddons[comp.display] and C_AddOns.IsAddOnLoaded(comp.addon) then
                OneWoW:RegisterLoadComponent(comp.display, OneWoW:GetAddonVersion(comp.addon), comp.cmd)
            end
        end

        local comps = OneWoW._loadedComponents
        if comps and #comps > 0 then
            local ver = OneWoW:GetAddonVersion(ADDON_NAME)
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

        OneWoW:FireCoreLoginHandlers("late")
        OneWoW:RunManifestLoginPhase()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...
        OneWoW:DispatchEnteringWorld(isLogin, isReload)
    end
end)

_G["1WoW_OnAddonCompartmentClick"] = function()
    if OneWoW.UI then
        OneWoW.UI:Toggle()
    end
end

_G["1WoW_OnAddonCompartmentEnter"] = function(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("|cFFFFD1001WoW|r", 1, 1, 1)
    local modCount = OneWoW.ModuleRegistry and OneWoW.ModuleRegistry:GetModuleCount() or 0
    if modCount > 0 then
        GameTooltip:AddLine(modCount .. " modules loaded", 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine(OneWoW.L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

_G["1WoW_OnAddonCompartmentLeave"] = function()
    GameTooltip:Hide()
end
