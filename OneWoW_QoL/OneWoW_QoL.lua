-- OneWoW_QoL Addon File
-- OneWoW_QoL/OneWoW_QoL.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

OneWoW_QoL = LibStub("AceAddon-3.0"):NewAddon("OneWoW_QoL", "AceEvent-3.0", "AceConsole-3.0")
local addon = OneWoW_QoL

ns.oneWoWHubActive = false

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local function RegisterWithOneWoW()
    if not _G.OneWoW then return false end
    if not _G.OneWoW.RegisterModule then return false end

    local tabs = {
        { name = "features", displayName = function() return ns.L["TAB_FEATURES"] or "QoL Features" end, create = function(p) ns.UI.CreateFeaturesTab(p) end },
        { name = "toggles",  displayName = function() return ns.L["TAB_TOGGLES"]  or "Toggles"      end, create = function(p) ns.UI.CreateTogglesTab(p) end },
    }
    if _G.OneWoW.GUI and _G.OneWoW.GUI.GetQoLFeatureTabs then
        for _, tab in ipairs(_G.OneWoW.GUI:GetQoLFeatureTabs()) do
            table.insert(tabs, tab)
        end
    end
    _G.OneWoW:RegisterModule({
        name = "qol",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "QoL" end,
        addonName = "OneWoW_QoL",
        order = 4,
        tabs = tabs,
    })
    _G.OneWoW:RegisterSettingsPanel({
        name        = "qol",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "QoL" end,
        order       = 4,
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
    ns.oneWoWHubActive = true
    return true
end

function addon:OnInitialize()
    self:InitializeDatabase()

    if OneWoW_GUI.MigrateSettings then
        OneWoW_GUI:MigrateSettings(self.db.global)
    end

    OneWoW_GUI:ApplyTheme(self)
    if ns.ApplyLanguage then ns.ApplyLanguage() end
    self:RegisterChatCommand("owqol", "SlashCommandHandler")
    self:RegisterChatCommand("onewowqol", "SlashCommandHandler")
    self:RegisterChatCommand("1wqol", "SlashCommandHandler")

    if OneWoW_GUI.RegisterSettingsCallback then
        OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(self2)
            OneWoW_GUI:ApplyTheme(self2)
        end)
        OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", self, function(self2)
            if ns.ApplyLanguage then ns.ApplyLanguage() end
        end)
        OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", self, function(owner, hidden)
            if owner.Minimap then owner.Minimap:SetShown(not hidden) end
        end)
        OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function(owner)
            if owner.Minimap then owner.Minimap:UpdateIcon() end
        end)
    end

    local _ver = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("QoL", _ver, "/1wqol")
    end
end

function addon:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function addon:ApplyLanguage()
    if ns.ApplyLanguage then
        ns.ApplyLanguage()
    end
end

function addon:OnEnable()
    if ns.Core and ns.Core.Initialize then
        ns.Core:Initialize()
    end

    RegisterWithOneWoW()

    if not ns.oneWoWHubActive then
        self.Minimap = OneWoW_GUI:CreateMinimapLauncher("OneWoW_QoL", {
            label = "QoL",
            onClick = function()
                if ns.UI and ns.UI.Toggle then ns.UI:Toggle() end
            end,
            onRightClick = function()
                if ns.UI and ns.UI.Show then ns.UI:Show("settings") end
            end,
            onTooltip = function(frame)
                GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
                GameTooltip:AddLine(ns.L["ADDON_TITLE_FRAME"], 1, 0.82, 0, 1)
                GameTooltip:AddLine(ns.L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
                GameTooltip:Show()
            end,
        })
    end
    if _G.OneWoW then
        _G.OneWoW:RegisterMinimap("OneWoW_QoL", (_G.OneWoW.L and _G.OneWoW.L["CTX_OPEN_QOL"]) or "Open QoL", "qol", nil)
    end

    self.PlayMountsModule = ns.PlayMountsModule
end

function addon:SlashCommandHandler(input)
    if ns.oneWoWHubActive and _G.OneWoW and _G.OneWoW.GUI then
        _G.OneWoW.GUI:Show("qol")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

function addon:CopyTextKeybind()
    if ns.CopyTextModule then
        ns.CopyTextModule:Capture()
    end
end


function addon:InitializeDatabase()
    local defaults = ns.DatabaseDefaults or {}
    self.db = LibStub("AceDB-3.0"):New("OneWoW_QoL_DB", defaults, true)
    if not self.db.global.modules then
        self.db.global.modules = {}
    end
end

_G["1WoW_QoL_OnAddonCompartmentClick"] = function(addonName, mouseButton)
    if ns.oneWoWHubActive and _G.OneWoW and _G.OneWoW.GUI then
        _G.OneWoW.GUI:Show("qol")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

_G["1WoW_QoL_OnAddonCompartmentEnter"] = function(addonName, frame)
    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
    GameTooltip:AddLine(ns.L["ADDON_TITLE_FRAME"], 1, 0.82, 0, 1)
    GameTooltip:AddLine(ns.L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
    GameTooltip:Show()
end

_G["1WoW_QoL_OnAddonCompartmentLeave"] = function()
    GameTooltip:Hide()
end
