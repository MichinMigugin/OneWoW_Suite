local ADDON_NAME, Addon = ...

Addon.Minimap = {}
local MinimapModule = Addon.Minimap

local ICON_HORDE    = "Interface\\AddOns\\OneWoW_Utility_DevTool\\Media\\horde-mini.png"
local ICON_ALLIANCE = "Interface\\AddOns\\OneWoW_Utility_DevTool\\Media\\alliance-mini.png"
local ICON_NEUTRAL  = "Interface\\AddOns\\OneWoW_Utility_DevTool\\Media\\neutral-mini.png"

local libDBIcon

local function GetCurrentIcon()
    local theme = Addon.db and Addon.db.minimap and Addon.db.minimap.theme or "horde"
    if theme == "alliance" then return ICON_ALLIANCE end
    if theme == "neutral"  then return ICON_NEUTRAL  end
    return ICON_HORDE
end

function MinimapModule:UpdateIcon()
    if MinimapModule._ldbPlugin then
        MinimapModule._ldbPlugin.icon = GetCurrentIcon()
    end
end

function MinimapModule:Initialize()
    local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not ldb then return end

    local plugin = ldb:NewDataObject("OneWoW_UtilityDevTool", {
        type = "launcher",
        icon = GetCurrentIcon(),
        OnClick = function(self, button)
            if button == "LeftButton" and Addon.UI then
                if Addon.UI.mainFrame and Addon.UI.mainFrame:IsShown() then
                    Addon.UI:Hide()
                else
                    Addon.UI:Show()
                end
            end
        end,
        OnEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("|cFFFFD100OneWoW|r - Utility: DevTool", 1, 0.82, 0, 1)
            if Addon.L and Addon.L["MINIMAP_TOOLTIP_HINT"] then
                GameTooltip:AddLine(Addon.L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
            end
            GameTooltip:Show()
        end,
        OnLeave = function()
            GameTooltip:Hide()
        end,
    })
    MinimapModule._ldbPlugin = plugin

    libDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
    if libDBIcon and Addon.db and Addon.db.minimap then
        libDBIcon:Register("OneWoW_UtilityDevTool", plugin, Addon.db.minimap)
    end
end

function MinimapModule:Show()
    if libDBIcon then
        libDBIcon:Show("OneWoW_UtilityDevTool")
    end
end

function MinimapModule:Hide()
    if libDBIcon then
        libDBIcon:Hide("OneWoW_UtilityDevTool")
    end
end

function MinimapModule:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function MinimapModule:IsShown()
    if libDBIcon then
        local btn = libDBIcon:GetMinimapButton("OneWoW_UtilityDevTool")
        return btn and btn:IsShown()
    end
    return false
end
