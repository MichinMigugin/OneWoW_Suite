local ADDON_NAME, ns = ...
local L = ns.L

ns.Minimap = {}
local MinimapModule = ns.Minimap

local ICON_HORDE    = "Interface\\AddOns\\OneWoW_ShoppingList\\Media\\horde-mini.png"
local ICON_ALLIANCE = "Interface\\AddOns\\OneWoW_ShoppingList\\Media\\alliance-mini.png"
local ICON_NEUTRAL  = "Interface\\AddOns\\OneWoW_ShoppingList\\Media\\neutral-mini.png"

local libDBIcon

local function GetDB()
    return _G.OneWoW_ShoppingList_DB
end

local function GetCurrentIcon()
    local db = GetDB()
    local theme = db and db.global and db.global.minimap and db.global.minimap.theme or "neutral"
    if theme == "alliance" then return ICON_ALLIANCE end
    if theme == "horde"    then return ICON_HORDE    end
    return ICON_NEUTRAL
end

function MinimapModule:UpdateIcon()
    if MinimapModule._ldbPlugin then
        MinimapModule._ldbPlugin.icon = GetCurrentIcon()
    end
end

function MinimapModule:Initialize()
    local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not ldb then return end

    local plugin = ldb:NewDataObject("OneWoW_ShoppingList", {
        type = "launcher",
        icon = GetCurrentIcon(),
        OnClick = function(self, button)
            if button == "LeftButton" and ns.MainWindow then
                ns.MainWindow:Toggle()
            end
        end,
        OnEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("|cFFFFD100OneWoW|r - " .. L["OWSL_WINDOW_TITLE"], 1, 0.82, 0, 1)
            GameTooltip:AddLine(L["OWSL_MM_CLICK_TO_OPEN"], 0.7, 0.7, 0.8, 1)
            GameTooltip:Show()
        end,
        OnLeave = function()
            GameTooltip:Hide()
        end,
    })
    MinimapModule._ldbPlugin = plugin

    libDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
    local db = GetDB()
    if libDBIcon and db and db.global and db.global.minimap then
        libDBIcon:Register("OneWoW_ShoppingList", plugin, db.global.minimap)
    end
end

function MinimapModule:Show()
    if libDBIcon then
        libDBIcon:Show("OneWoW_ShoppingList")
    end
end

function MinimapModule:Hide()
    if libDBIcon then
        libDBIcon:Hide("OneWoW_ShoppingList")
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
        local btn = libDBIcon:GetMinimapButton("OneWoW_ShoppingList")
        return btn and btn:IsShown()
    end
    return false
end
