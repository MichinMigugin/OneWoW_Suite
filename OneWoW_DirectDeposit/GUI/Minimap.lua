local ADDON_NAME, OneWoW_DirectDeposit = ...

OneWoW_DirectDeposit.Minimap = {}
local Minimap = OneWoW_DirectDeposit.Minimap

local ICON_HORDE    = "Interface\\AddOns\\OneWoW_DirectDeposit\\Media\\horde-mini.png"
local ICON_ALLIANCE = "Interface\\AddOns\\OneWoW_DirectDeposit\\Media\\alliance-mini.png"
local ICON_NEUTRAL  = "Interface\\AddOns\\OneWoW_DirectDeposit\\Media\\neutral-mini.png"

local libDBIcon

local function GetCurrentIcon()
    local db = OneWoW_DirectDeposit.db
    local theme = db and db.global and db.global.minimap and db.global.minimap.theme or "horde"
    if theme == "alliance" then return ICON_ALLIANCE end
    if theme == "neutral"  then return ICON_NEUTRAL  end
    return ICON_HORDE
end

function Minimap:UpdateIcon()
    if Minimap._ldbPlugin then
        Minimap._ldbPlugin.icon = GetCurrentIcon()
    end
end

function Minimap:Initialize()
    local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not ldb then return end

    local plugin = ldb:NewDataObject("OneWoW_DirectDeposit", {
        type = "launcher",
        icon = GetCurrentIcon(),
        OnClick = function(self, button)
            if button == "LeftButton" and OneWoW_DirectDeposit.GUI then
                OneWoW_DirectDeposit.GUI:Toggle()
            end
        end,
        OnEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("|cFFFFD100OneWoW|r - Direct Deposit", 1, 0.82, 0, 1)
            local L = OneWoW_DirectDeposit.L
            if L and L["MINIMAP_TOOLTIP_HINT"] then
                GameTooltip:AddLine(L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
            end
            GameTooltip:Show()
        end,
        OnLeave = function()
            GameTooltip:Hide()
        end,
    })
    Minimap._ldbPlugin = plugin

    libDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
    local db = OneWoW_DirectDeposit.db
    if libDBIcon and db and db.global and db.global.minimap then
        libDBIcon:Register("OneWoW_DirectDeposit", plugin, db.global.minimap)
    end
end

function Minimap:Show()
    if libDBIcon then
        libDBIcon:Show("OneWoW_DirectDeposit")
    end
end

function Minimap:Hide()
    if libDBIcon then
        libDBIcon:Hide("OneWoW_DirectDeposit")
    end
end

function Minimap:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function Minimap:IsShown()
    if libDBIcon then
        local btn = libDBIcon:GetMinimapButton("OneWoW_DirectDeposit")
        return btn and btn:IsShown()
    end
    return false
end
