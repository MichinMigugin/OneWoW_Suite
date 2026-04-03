local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_Trackers = {}
local addon = OneWoW_Trackers

ns.addon = addon
ns.oneWoWHubActive = false
ns.mode = "standalone"
ns.UI = ns.UI or {}

local function ApplyTheme()
    OneWoW_GUI:ApplyTheme(addon)
    if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
        ns.TrackerEngine:RefreshAllPinnedWindows()
    end
end

local function ApplyLanguage()
    local selectedLang
    if OneWoW_GUI and OneWoW_GUI.GetSetting then
        selectedLang = OneWoW_GUI:GetSetting("language")
    end
    selectedLang = selectedLang or GetLocale()
    if selectedLang == "esMX" then selectedLang = "esES" end
    ns.SetLocale(selectedLang)
end

local function RegisterWithNotesAsSubtab()
    _G.OneWoW_Trackers_API = {
        CreateTrackerTab = function(parent)
            ns.UI.CreateTrackerTab(parent)
        end,
        GetTabInfo = function()
            return {
                name = "tracker",
                displayName = function() return ns.L["TAB_TRACKER"] or "Tracker" end,
            }
        end,
    }
    ns.mode = "notes_subtab"
end

local function RegisterAsOneWoWModule()
    if not _G.OneWoW or not _G.OneWoW.RegisterModule then return false end

    _G.OneWoW:RegisterModule({
        name        = "trackers",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "Trackers" end,
        addonName   = "OneWoW_Trackers",
        order       = 2,
        tabs = {
            {
                name        = "tracker",
                displayName = function() return ns.L["TAB_TRACKER"] or "Tracker" end,
                create      = function(p) ns.UI.CreateTrackerTab(p) end,
            },
        },
    })

    ns.oneWoWHubActive = true
    ns.mode = "onewow_module"
    return true
end

local function SetupStandalone()
    ns.mode = "standalone"

    addon.Minimap = OneWoW_GUI:CreateMinimapLauncher("OneWoW_Trackers", {
        label = "Trackers",
        onClick = function()
            if ns.UI and ns.UI.Toggle then ns.UI:Toggle() end
        end,
        onRightClick = function()
        end,
        onTooltip = function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
            GameTooltip:AddLine(ns.L["ADDON_TITLE_FRAME"] or "OneWoW Trackers", 1, 0.82, 0, 1)
            if ns.L["MINIMAP_TOOLTIP_HINT"] then
                GameTooltip:AddLine(ns.L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
            end
            GameTooltip:Show()
        end,
    })
end

local function OnInitialize()
    addon.db = ns.Database:Initialize()

    ns.Database:MigrateFromNotes(addon.db)

    OneWoW_GUI:MigrateSettings(addon.db.global)

    ApplyTheme()
    ApplyLanguage()

    local function slashHandler(msg)
        addon:SlashCommandHandler(msg)
    end

    SLASH_ONEWOW_TRACKERS1 = "/1wt"
    SLASH_ONEWOW_TRACKERS2 = "/owt"
    SLASH_ONEWOW_TRACKERS3 = "/tracker"
    SlashCmdList["ONEWOW_TRACKERS"] = slashHandler

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", addon, function(self2)
        ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", addon, function(self2)
        ApplyLanguage()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", addon, function(self2)
        if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
            ns.TrackerEngine:RefreshAllPinnedWindows()
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", addon, function(owner, hidden)
        if owner.Minimap then owner.Minimap:SetShown(not hidden) end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", addon, function(owner)
        if owner.Minimap then owner.Minimap:UpdateIcon() end
    end)

    local _ver = OneWoW_GUI:GetAddonVersion(addonName)
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("Trackers", _ver, "/1wt")
    else
        addon._pendingLoadVer = _ver
    end
end

local function OnEnable()
    local notesLoaded = C_AddOns.IsAddOnLoaded("OneWoW_Notes")
    local oneWoWLoaded = _G.OneWoW ~= nil

    if notesLoaded then
        RegisterWithNotesAsSubtab()
    elseif oneWoWLoaded then
        RegisterAsOneWoWModule()
    else
        SetupStandalone()
        if addon._pendingLoadVer then
            print("|cFF00FF00OneWoW|r: |cFFFFFFFFTrackers|r |cFF888888\226\128\147 v." .. addon._pendingLoadVer .. " \226\128\147|r |cFF00FF00Loaded|r - /1wt")
        end
    end

    if _G.OneWoW then
        _G.OneWoW:RegisterMinimap("OneWoW_Trackers",
            (_G.OneWoW.L and _G.OneWoW.L["CTX_OPEN_TRACKERS"]) or "Open Trackers",
            ns.mode == "onewow_module" and "trackers" or nil,
            ns.mode ~= "onewow_module" and function()
                if ns.oneWoWHubActive and _G.OneWoW and _G.OneWoW.GUI then
                    _G.OneWoW.GUI:Show("notes", "tracker")
                elseif ns.UI and ns.UI.Toggle then
                    ns.UI:Toggle()
                end
            end or nil
        )
    end

    if ns.TrackerEngine and ns.TrackerEngine.Initialize then
        ns.TrackerEngine:Initialize()
    end

    if ns.TrackerMigration and ns.TrackerMigration.MigrateAll then
        ns.TrackerMigration:MigrateAll()
    end

    if ns.TrackerPresets and ns.TrackerPresets.LoadBundledContent then
        ns.TrackerPresets:LoadBundledContent()
    end

    if ns.TrackerMapUI and ns.TrackerMapUI.Initialize then
        ns.TrackerMapUI:Initialize()
    end
end

function addon:SlashCommandHandler(input)
    if ns.mode == "notes_subtab" then
        if ns.oneWoWHubActive and _G.OneWoW and _G.OneWoW.GUI then
            _G.OneWoW.GUI:Show("notes", "tracker")
        elseif _G.OneWoW_Notes then
            if _G.OneWoW_Notes.SlashCommandHandler then
                _G.OneWoW_Notes:SlashCommandHandler("")
            end
        end
        return
    end

    if ns.oneWoWHubActive and _G.OneWoW and _G.OneWoW.GUI then
        _G.OneWoW.GUI:Show("trackers")
        return
    end

    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

function addon:FormatResetTimer(seconds)
    if seconds <= 0 then return "<0m>" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if days > 0 then
        if hours > 0 then return string.format("<%dd %dhr>", days, hours)
        else return string.format("<%dd>", days) end
    elseif hours > 0 then
        return string.format("<%dhr>", hours)
    else
        return string.format("<%dm>", minutes)
    end
end

local pewFired = false
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        OnInitialize()
    elseif event == "PLAYER_LOGIN" then
        OnEnable()
    elseif event == "PLAYER_ENTERING_WORLD" and not pewFired then
        pewFired = true
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

_G["1WoW_Trackers_OnAddonCompartmentClick"] = function(addonName, mouseButton)
    addon:SlashCommandHandler("")
end

_G["1WoW_Trackers_OnAddonCompartmentEnter"] = function(addonName, frame)
    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
    GameTooltip:AddLine(ns.L["ADDON_TITLE_FRAME"] or "OneWoW Trackers", 1, 0.82, 0, 1)
    GameTooltip:AddLine(ns.L["MINIMAP_TOOLTIP_HINT"] or "Click to open Trackers", 0.7, 0.7, 0.8, 1)
    GameTooltip:Show()
end

_G["1WoW_Trackers_OnAddonCompartmentLeave"] = function()
    GameTooltip:Hide()
end
