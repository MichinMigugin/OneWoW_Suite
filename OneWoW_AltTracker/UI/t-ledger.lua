local addonName, ns = ...
local L = ns.L
local T = ns.T

ns.UI = ns.UI or {}

function ns.UI.CreateLedgerTab(parent)
    local placeholderPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    placeholderPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    placeholderPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 5)
    placeholderPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    placeholderPanel:SetBackdropColor(T("BG_SECONDARY"))
    placeholderPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local placeholderText = placeholderPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    placeholderText:SetPoint("CENTER", placeholderPanel, "CENTER", 0, 0)
    placeholderText:SetText("Ledger Tab - Coming Soon")
    placeholderText:SetTextColor(T("TEXT_PRIMARY"))

    parent.ledgerPanel = placeholderPanel
end
