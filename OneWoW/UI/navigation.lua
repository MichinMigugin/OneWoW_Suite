local ADDON_NAME, ns = ...

local UI = ns.UI

local OneWoW_GUI = OneWoW_GUI

local CreateFrame = CreateFrame
local SetCursor = SetCursor
local ResetCursor = ResetCursor

function UI:OpenManageFeatures()
    UI:Show("settings")
    UI:SelectSubTab("settings", "managefeatures")
end

function UI:OpenSearchShortcuts()
    UI:Show("settings")
    UI:SelectSubTab("settings", "searchshortcuts")
end

--- Pointer text + accent link that opens Settings > Manage Features.
---@param parent Frame row container (sized/positioned by caller)
---@param opts table? { pointerKey?: string, center?: boolean }
function UI:CreateManageFeaturesLinkRow(parent, opts)
    opts = opts or {}
    local L = ns.L or {}
    local pointerKey = opts.pointerKey or "HOME_MANAGE_POINTER"

    local manageText = OneWoW_GUI:CreateFS(parent, 12)
    manageText:SetText(ns.Locale:GetOptional(ADDON_NAME, pointerKey) or "")
    manageText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local manageLink = CreateFrame("Button", nil, parent)
    manageLink:SetHeight(20)
    manageLink:EnableMouse(true)

    local manageLinkLabel = manageLink:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SafeSetFont(manageLinkLabel, OneWoW_GUI:GetFont(), 12)
    manageLinkLabel:SetPoint("LEFT", manageLink, "LEFT", 0, 0)
    manageLinkLabel:SetText(L["HOME_MANAGE_LINK"])
    manageLinkLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    manageLink:SetWidth((manageLinkLabel:GetStringWidth() or 120) + 4)

    local gap = 6
    local textW = manageText:GetStringWidth() or 0
    local linkW = manageLink:GetWidth()
    local totalW = textW + gap + linkW

    if opts.center then
        manageText:SetPoint("LEFT", parent, "CENTER", -totalW / 2, 0)
    else
        manageText:SetPoint("LEFT", parent, "LEFT", 0, 0)
    end
    manageLink:SetPoint("LEFT", manageText, "RIGHT", gap, 0)

    manageLink:SetScript("OnEnter", function()
        manageLinkLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        SetCursor("Interface\\CURSOR\\Point")
    end)
    manageLink:SetScript("OnLeave", function()
        manageLinkLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        ResetCursor()
    end)
    manageLink:SetScript("OnClick", function()
        UI:OpenManageFeatures()
    end)

    return manageText, manageLink
end
