-- OneWoW_QoL Addon File
-- OneWoW_QoL/OneWoW_QoL.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

OneWoW_QoL = LibStub("AceAddon-3.0"):NewAddon("OneWoW_QoL", "AceEvent-3.0", "AceConsole-3.0")
local addon = OneWoW_QoL

ns.addon = addon
ns.oneWoWHubActive = false

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
    if ns.ApplyTheme then ns.ApplyTheme() end
    if ns.ApplyLanguage then ns.ApplyLanguage() end
    self:RegisterChatCommand("owqol", "SlashCommandHandler")
    self:RegisterChatCommand("onewowqol", "SlashCommandHandler")
    self:RegisterChatCommand("1wqol", "SlashCommandHandler")
    local _ver = C_AddOns.GetAddOnMetadata(addonName, "Version") or ns.Constants.VERSION
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("QoL", _ver, "/1wqol")
    else
        print("|cFF00FF00OneWoW|r: |cFFFFFFFFQoL|r |cFF888888\226\128\147 v." .. _ver .. " \226\128\147|r |cFF00FF00Loaded|r - /1wqol")
    end
end

function addon:ApplyTheme()
    if ns.ApplyTheme then
        ns.ApplyTheme()
    end
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
        if ns.MinimapButton and ns.MinimapButton.Initialize then
            ns.MinimapButton:Initialize()
        end
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
    if not self.db.global.language then
        self.db.global.language = GetLocale()
    end
    if not self.db.global.theme then
        self.db.global.theme = "green"
    end
    if not self.db.global.modules then
        self.db.global.modules = {}
    end
    if self.db.global.minimapButton and not self.db.global.minimap then
        self.db.global.minimap = {
            hide = self.db.global.minimapButton.hide or false,
            minimapPos = 220,
            theme = "horde",
        }
        self.db.global.minimapButton = nil
    end
    if not self.db.global.minimap then self.db.global.minimap = {} end
    if self.db.global.minimap.hide == nil then self.db.global.minimap.hide = false end
    if self.db.global.minimap.minimapPos == nil then self.db.global.minimap.minimapPos = 220 end
    if not self.db.global.minimap.theme then self.db.global.minimap.theme = "horde" end
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
