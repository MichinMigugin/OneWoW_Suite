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

---@param sd table
---@return string[]
local function CollectRaidNames(sd)
    local names = {}
    for _, raid in ipairs(sd.raids) do
        local journalInstanceID = sd:ResolveRaid(raid)
        local name
        if journalInstanceID then
            name = EJ_GetInstanceInfo(journalInstanceID)
        end
        tinsert(names, name or raid.label)
    end
    return names
end

---@param sd table
---@return string[]
local function CollectDungeonNames(sd)
    local names = {}
    for _, dung in ipairs(sd.dungeons) do
        local mapID = sd:ResolveDungeonMapID(dung)
        local name
        if mapID and mapID > 0 then
            name = C_ChallengeMode.GetMapUIInfo(mapID)
        end
        tinsert(names, name or dung.name)
    end
    return names
end

---@return string[]
local function CollectWorldBossNames()
    local names = {}
    local ids = ns:GetProgressList("worldBossQuestIDs")
    for _, questID in ipairs(ids) do
        local name = C_QuestLog.GetTitleForQuestID(questID)
        if name then
            tinsert(names, name)
        end
    end
    return names
end

---@return string[]
local function CollectWeeklyNames()
    local names = {}
    local list = ns:GetProgressList("weeklyActivityQuests")
    for _, entry in ipairs(list) do
        local name
        if entry.localeKey then
            name = L[entry.localeKey]
        elseif entry.name then
            name = entry.name
        else
            local ids = entry.questIDs
            if type(ids) == "table" and ids[1] then
                name = C_QuestLog.GetTitleForQuestID(ids[1])
            elseif entry.questID then
                name = C_QuestLog.GetTitleForQuestID(entry.questID)
            end
        end
        if name then
            tinsert(names, name)
        end
    end
    return names
end

---@return string[]
local function CollectCurrencyNames()
    local names = {}
    local ids = ns:GetProgressList("trackedCurrencyIDs")
    for _, currencyID in ipairs(ids) do
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info and info.name and info.name ~= "" then
            tinsert(names, info.name)
        end
    end
    return names
end

---@param sd table
---@return string
local function BuildMessage(sd)
    local parts = {}
    tinsert(parts, GoldBlock(RAIDS, JoinNames(CollectRaidNames(sd))))
    tinsert(parts, GoldBlock(L["SUBTAB_MYTHICPLUS"], JoinNames(CollectDungeonNames(sd))))
    tinsert(parts, GoldBlock(L["TT_COL_WORLD_BOSS"], JoinNames(CollectWorldBossNames())))
    tinsert(parts, GoldBlock(L["PROGRESS_WEEKLY_ACTIVITIES"], JoinNames(CollectWeeklyNames())))
    tinsert(parts, GoldBlock(CURRENCY, JoinNames(CollectCurrencyNames())))
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
        message    = BuildMessage(sd),
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
