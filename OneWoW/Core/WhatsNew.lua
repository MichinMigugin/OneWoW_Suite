local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

-- ============================================================================
-- What's New dialog
-- ============================================================================
-- Account-scoped dismiss (whatsNewDismissedVersion). Auto-show on login when
-- releaseId matches TOC Version, highlights exist, and FirstRun wizard is not
-- pending. Home force-opens via Show(true).
-- ============================================================================

local WhatsNew = {}
ns.WhatsNew = WhatsNew

local activeDialog = nil

local function CurrentVersion()
    return ns:GetAddonVersion(ADDON_NAME) or ""
end

local function BuildMessage()
    local L = ns.L
    local data = ns.WhatsNewData
    local parts = {}
    if data and data.highlights then
        for _, item in ipairs(data.highlights) do
            local title = L[item.titleKey] or item.titleKey
            local body = L[item.bodyKey] or item.bodyKey
            tinsert(parts, "|cFFFFD100" .. title .. "|r\n" .. body)
        end
    end
    tinsert(parts, L["WHATS_NEW_FOOTER"])
    return table.concat(parts, "\n\n")
end

--- Auto-show gate: TOC Version must match WhatsNewData.releaseId, highlights
--- non-empty, and this account has not dismissed this version.
---@return boolean
function WhatsNew:ShouldAutoShow()
    local data = ns.WhatsNewData
    if not data or not data.highlights or #data.highlights == 0 then
        return false
    end
    local ver = CurrentVersion()
    if ver == "" or ver == "Unknown" then
        return false
    end
    if data.releaseId ~= ver then
        return false
    end
    if ns.db.global.whatsNewDismissedVersion == ver then
        return false
    end
    return true
end

--- Show the What's New dialog.
---@param force boolean|nil when true, skip auto-show gates (Home button)
function WhatsNew:Show(force)
    if not force and not self:ShouldAutoShow() then
        return
    end

    local data = ns.WhatsNewData
    if not data or not data.highlights or #data.highlights == 0 then
        return
    end

    if activeDialog and activeDialog.frame and activeDialog.frame:IsShown() then
        activeDialog.frame:Raise()
        return
    end

    local L = ns.L
    local ver = CurrentVersion()
    local result
    result = OneWoW_GUI:CreateConfirmDialog({
        name       = "OneWoW_WhatsNew",
        addonTitle = "OneWoW",
        title      = format(L["WHATS_NEW_TITLE"], ver),
        message    = BuildMessage(),
        width      = 520,
        showBrand  = true,
        checkbox   = {
            label = L["WHATS_NEW_DONT_SHOW"],
            wrap = true,
        },
        buttons    = {
            {
                text    = CLOSE,
                color   = { 0.2, 0.6, 0.2 },
                onClick = function(dialog)
                    local checked = result and result.checkbox and result.checkbox:GetChecked()
                    if checked then
                        ns.db.global.whatsNewDismissedVersion = ver
                    end
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

    -- Left of the Close button row: opens the shared copy-URL dialog (WoW
    -- cannot select FontString text for Ctrl+C).
    if result and result.frame then
        local releaseBtn = OneWoW_GUI:CreateFitTextButton(result.frame, {
            text = L["WHATS_NEW_RELEASE_NOTES_BTN"],
            height = 28,
            minWidth = 80,
        })
        releaseBtn:SetPoint("BOTTOMLEFT", result.frame, "BOTTOMLEFT", 10, 10)
        releaseBtn:SetScript("OnClick", function()
            OneWoW_GUI:ShowCopyURLDialog(L["WHATS_NEW_RELEASE_NOTES_BTN"], L["WHATS_NEW_URL"])
        end)
        result.releaseNotesButton = releaseBtn
    end

    activeDialog = result
    if result and result.frame then
        result.frame:Show()
        result.frame:Raise()
    end
end

--- Login-path entry: skip when FirstRun wizard still pending.
function WhatsNew:TryAutoShow()
    if ns.FirstRun and ns.FirstRun:ShouldShowWizard() then
        return
    end
    self:Show(false)
end
