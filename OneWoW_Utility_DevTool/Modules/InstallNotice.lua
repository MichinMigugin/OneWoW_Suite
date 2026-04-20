local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local InstallNotice = {}
Addon.InstallNotice = InstallNotice

local activeDialog = nil

local function getAckFlag()
    local g = Addon.db and Addon.db.global
    if not g then return false end
    return g.installNoticeAcknowledged and true or false
end

local function setAckFlag(value)
    local g = Addon.db and Addon.db.global
    if not g then return end
    g.installNoticeAcknowledged = value and true or false
end

function InstallNotice:IsAcknowledged()
    return getAckFlag()
end

function InstallNotice:ResetAck()
    setAckFlag(false)
end

function InstallNotice:Show(force)
    if not force and getAckFlag() then return end

    if activeDialog and activeDialog.frame and activeDialog.frame:IsShown() then
        return
    end

    local L = Addon.L or {}
    local result
    result = OneWoW_GUI:CreateConfirmDialog({
        name       = "OneWoW_DevTool_InstallNotice",
        addonTitle = L["INSTALL_NOTICE_ADDON_TITLE"] or L["ADDON_TOOLTIP_TITLE"] or "OneWoW DevTool",
        title      = L["INSTALL_NOTICE_TITLE"] or "Heads up - this is a developer addon",
        message    = L["INSTALL_NOTICE_MESSAGE"] or "OneWoW DevTool is not commonly installed. It exists to assist with addon development and troubleshooting.",
        width      = 460,
        showBrand  = true,
        checkbox   = { label = L["INSTALL_NOTICE_DONT_SHOW"] or "Don't show this again" },
        buttons    = {
            {
                text    = L["INSTALL_NOTICE_BTN_OK"] or "Got it",
                color   = { 0.2, 0.6, 0.2 },
                onClick = function(dialog)
                    local checked = result and result.checkbox and result.checkbox:GetChecked()
                    if checked then setAckFlag(true) end
                    dialog:Hide()
                    activeDialog = nil
                end,
            },
        },
        onClose = function()
            activeDialog = nil
        end,
    })

    if result and result.checkbox then
        result.checkbox:SetChecked(true)
    end

    activeDialog = result
    if result and result.frame then
        result.frame:Show()
    end
end
