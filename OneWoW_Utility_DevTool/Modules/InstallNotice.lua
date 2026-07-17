local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

local InstallNotice = {}
ns.InstallNotice = InstallNotice

local activeDialog = nil

local function getAckFlag()
    return ns.db.global.installNoticeAcknowledged and true or false
end

local function setAckFlag(value)
    ns.db.global.installNoticeAcknowledged = value and true or false
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

    local result
    result = OneWoW_GUI:CreateConfirmDialog({
        name       = "OneWoW_DevTool_InstallNotice",
        addonTitle = L["INSTALL_NOTICE_ADDON_TITLE"],
        title      = L["INSTALL_NOTICE_TITLE"],
        message    = L["INSTALL_NOTICE_MESSAGE"],
        width      = 460,
        showBrand  = true,
        checkbox   = {
            label = L["INSTALL_NOTICE_DONT_SHOW"],
            wrap = true,
        },
        buttons    = {
            {
                text    = L["INSTALL_NOTICE_BTN_OK"],
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
