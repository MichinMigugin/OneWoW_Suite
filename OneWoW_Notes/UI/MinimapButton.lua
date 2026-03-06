local addonName, ns = ...

ns.MinimapButton = {}
local MinimapButton = ns.MinimapButton

local ICON_HORDE    = "Interface\\AddOns\\OneWoW_Notes\\Media\\horde-mini.png"
local ICON_ALLIANCE = "Interface\\AddOns\\OneWoW_Notes\\Media\\alliance-mini.png"
local ICON_NEUTRAL  = "Interface\\AddOns\\OneWoW_Notes\\Media\\neutral-mini.png"

local libDBIcon

local function GetCurrentIcon()
    local addon = _G.OneWoW_Notes
    local theme = addon and addon.db and addon.db.global and addon.db.global.minimap and addon.db.global.minimap.theme or "horde"
    if theme == "alliance" then return ICON_ALLIANCE end
    if theme == "neutral"  then return ICON_NEUTRAL  end
    return ICON_HORDE
end

function MinimapButton:UpdateIcon()
    if MinimapButton._ldbPlugin then
        MinimapButton._ldbPlugin.icon = GetCurrentIcon()
    end
end

function MinimapButton:Initialize()
    local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not ldb then return end

    local plugin = ldb:NewDataObject("OneWoW_Notes", {
        type = "launcher",
        icon = GetCurrentIcon(),
        OnClick = function(self, button)
            if button == "LeftButton" and ns.UI and ns.UI.Toggle then
                ns.UI:Toggle()
            end
        end,
        OnEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("|cFFFFD100OneWoW|r - Notes", 1, 0.82, 0, 1)
            if ns.L and ns.L["MINIMAP_TOOLTIP_HINT"] then
                GameTooltip:AddLine(ns.L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
            end
            GameTooltip:Show()
        end,
        OnLeave = function()
            GameTooltip:Hide()
        end,
    })
    MinimapButton._ldbPlugin = plugin

    libDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
    local addon = _G.OneWoW_Notes
    if libDBIcon and addon and addon.db and addon.db.global and addon.db.global.minimap then
        libDBIcon:Register("OneWoW_Notes", plugin, addon.db.global.minimap)
    end
end

function MinimapButton:Show()
    if libDBIcon then
        libDBIcon:Show("OneWoW_Notes")
    end
end

function MinimapButton:Hide()
    if libDBIcon then
        libDBIcon:Hide("OneWoW_Notes")
    end
end

function MinimapButton:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function MinimapButton:IsShown()
    if libDBIcon then
        local btn = libDBIcon:GetMinimapButton("OneWoW_Notes")
        return btn and btn:IsShown()
    end
    return false
end
