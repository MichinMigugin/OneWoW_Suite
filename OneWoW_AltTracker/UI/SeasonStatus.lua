local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local L = ns.L

-- ============================================================================
-- Season Status dialog
-- ============================================================================
-- /1wat status — live snapshot of what Progress is tracking. Season label
-- comes from C_MythicPlus + EXPANSION_SEASON_NAME; lists come from SeasonData
-- and GetProgressList (same sources as the Progress tab).
-- ============================================================================

local SeasonStatus = {}
ns.SeasonStatus = SeasonStatus

local activeDialog = nil

---@param names string[]
---@return string
local function JoinNames(names)
    if #names == 0 then
        return L["PROGRESS_NO_DATA"]
    end
    return table.concat(names, ", ")
end

---@param title string
---@param body string
---@return string
local function GoldBlock(title, body)
    return "|cFFFFD100" .. title .. "|r\n" .. body
end

---@return string
local function BuildMessage()
    local lists = ns.UI.GetProgressTrackingLists()
    local parts = {}
    tinsert(parts, GoldBlock(RAIDS, JoinNames(lists.raids)))
    tinsert(parts, GoldBlock(L["SUBTAB_MYTHICPLUS"], JoinNames(lists.dungeons)))
    tinsert(parts, GoldBlock(L["TT_COL_WORLD_BOSS"], JoinNames(lists.bosses)))
    tinsert(parts, GoldBlock(L["PROGRESS_WEEKLY_ACTIVITIES"], JoinNames(lists.weeklies)))
    tinsert(parts, GoldBlock(CURRENCY, JoinNames(lists.currencies)))
    return table.concat(parts, "\n\n")
end

--- Open the live Progress tracking dialog.
function SeasonStatus:Show()
    if activeDialog and activeDialog.frame and activeDialog.frame:IsShown() then
        activeDialog.frame:Raise()
        return
    end

    local sd = ns.SeasonData
    local result = OneWoW_GUI:CreateConfirmDialog({
        name       = "OneWoW_AltTracker_SeasonStatus",
        addonTitle = L["ADDON_TITLE_SHORT"],
        title      = sd:GetCurrentSeasonLabel() or L["STATUS_TITLE"],
        message    = BuildMessage(),
        width      = 520,
        showBrand  = true,
        buttons    = {
            {
                text    = CLOSE,
                color   = { 0.2, 0.6, 0.2 },
                onClick = function(dialog)
                    dialog:Hide()
                end,
            },
        },
        onClose = function()
            activeDialog = nil
        end,
    })

    result.frame:HookScript("OnHide", function()
        activeDialog = nil
    end)

    activeDialog = result
    result.frame:Show()
    result.frame:Raise()
end
