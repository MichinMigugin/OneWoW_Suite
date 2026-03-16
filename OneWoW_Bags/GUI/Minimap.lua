local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.Minimap = {}
local Minimap = OneWoW_Bags.Minimap

local ldb = nil
local icon = nil

function Minimap:Initialize()
    local L = OneWoW_Bags.L
    local db = OneWoW_Bags.db
    if not db then return end

    if OneWoW_Bags.oneWoWHubActive then return end

    local LibStub = _G.LibStub
    if not LibStub then return end

    ldb = LibStub("LibDataBroker-1.1", true)
    icon = LibStub("LibDBIcon-1.0", true)
    if not ldb or not icon then return end

    local iconTheme = db.global.minimap and db.global.minimap.theme or "horde"
    local iconPath = "Interface\\AddOns\\OneWoW_Bags\\Media\\" .. iconTheme .. "-mini"

    local dataObj = ldb:NewDataObject("OneWoW_Bags", {
        type = "launcher",
        text = "OneWoW Bags",
        icon = iconPath,
        OnClick = function(_, button)
            if button == "LeftButton" then
                if OneWoW_Bags.GUI then
                    OneWoW_Bags.GUI:Toggle()
                end
            elseif button == "RightButton" then
                if OneWoW_Bags.Settings then
                    if OneWoW_Bags.GUI then
                        OneWoW_Bags.GUI:Show()
                    end
                    OneWoW_Bags.Settings:Toggle()
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText("|cFFFFD100OneWoW|r - |cFF00FF00" .. L["ADDON_TITLE"] .. "|r")
            tooltip:AddLine(L["MINIMAP_SECTION_DESC"], 0.7, 0.7, 0.7)
            tooltip:Show()
        end,
    })

    if not OneWoW_Bags_MinimapLDBIconDB then
        OneWoW_Bags_MinimapLDBIconDB = {}
    end

    icon:Register("OneWoW_Bags", dataObj, OneWoW_Bags_MinimapLDBIconDB)

    if db.global.minimap and db.global.minimap.hide then
        icon:Hide("OneWoW_Bags")
    end
end

function Minimap:SetShown(show)
    if not icon then return end
    if show then
        icon:Show("OneWoW_Bags")
    else
        icon:Hide("OneWoW_Bags")
    end
end

function Minimap:UpdateIcon()
    if not icon or not ldb then return end
    local db = OneWoW_Bags.db
    local iconTheme = db.global.minimap and db.global.minimap.theme or "horde"
    local iconPath = "Interface\\AddOns\\OneWoW_Bags\\Media\\" .. iconTheme .. "-mini"
    local dataObj = ldb:GetDataObjectByName("OneWoW_Bags")
    if dataObj then
        dataObj.icon = iconPath
    end
end
