local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local tinsert, tremove, wipe = tinsert, tremove, wipe

local L = ns.L
ns.UI = ns.UI or {}

-- Fallback titles when C_QuestLog has not cached the world-boss quest yet.
local BOSS_NAME_FALLBACK = {
    [92123] = "Cragpine",
    [92560] = "Lu'ashal",
    [92636] = "Predaxas",
    [92034] = "Thorm'belan",
    [96472] = "Nexus-Captain Leth'ir",
    [96473] = "Imperator Pertinax",
    [97128] = "Nymrissa Wavecaller",
}

local trackingDialog

local function JoinNames(names)
    if #names == 0 then
        return L["TRACKING_BAR_NOT_SET"]
    end
    return table.concat(names, ", ")
end

local function CurrencyName(id)
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if info and info.name and info.name ~= "" then
        return info.name
    end
    return CURRENCY .. " " .. id
end

local function CollectRaidNames()
    local names = {}
    local sd = ns.SeasonData
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

local function CollectDungeonNames()
    local names = {}
    local sd = ns.SeasonData
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

local function CollectWorldBossNames()
    local names = {}
    local ids = ns:GetProgressList("worldBossQuestIDs")
    for i = 1, #ids do
        local questID = ids[i]
        local name = C_QuestLog.GetTitleForQuestID(questID) or BOSS_NAME_FALLBACK[questID]
        tinsert(names, name or (L["OVERRIDE_ENTER_QUEST_ID"] .. " " .. questID))
    end
    return names
end

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

local function CollectCurrencyNames()
    local names = {}
    local ids = ns:GetProgressList("trackedCurrencyIDs")
    for i = 1, #ids do
        tinsert(names, CurrencyName(ids[i]))
    end
    return names
end

--- Name lists Progress is tracking (season data + player overrides).
---@return table lists
function ns.UI.GetProgressTrackingLists()
    return {
        raids = CollectRaidNames(),
        dungeons = CollectDungeonNames(),
        bosses = CollectWorldBossNames(),
        weeklies = CollectWeeklyNames(),
        currencies = CollectCurrencyNames(),
    }
end

--- Season name and client patch for the Progress identity bar.
---@return string title
---@return string version
function ns.UI.GetSeasonIdentity()
    local sd = ns.SeasonData
    local title = sd:GetCurrentSeasonLabel()
    if not title then
        title = OneWoW:GetExpansionName(LE_EXPANSION_LEVEL_CURRENT) or ""
    end
    local patch = sd:GetClientPatchDisplay()
    local version = ""
    if patch ~= "" then
        version = GAME_VERSION_LABEL .. " " .. patch
    end
    return title, version
end

local function NotifyStrip()
    local progressTab = ns.UI.progressTabFrame
    if progressTab then
        ns.UI.RefreshTrackingBar(progressTab)
    end
end

local function NotifyCurrencies()
    if ns.UI.NotifyTrackedCurrenciesChanged then
        ns.UI.NotifyTrackedCurrenciesChanged()
    else
        NotifyStrip()
    end
end

local function MakeInfoRow(parent, text)
    local row = OneWoW_GUI:CreateFrame(parent, { height = 26, bgColor = "BG_TERTIARY", borderColor = "BORDER_SUBTLE" })
    local fs = OneWoW_GUI:CreateFS(row, 12)
    fs:SetPoint("LEFT", 10, 0)
    fs:SetPoint("RIGHT", -10, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    return row
end

local function MakeEditRow(parent, leftText, nameText)
    local row = OneWoW_GUI:CreateFrame(parent, { height = 28, bgColor = "BG_TERTIARY", borderColor = "BORDER_SUBTLE" })
    local left = OneWoW_GUI:CreateFS(row, 10)
    left:SetPoint("LEFT", 10, 0)
    left:SetWidth(70)
    left:SetText(leftText)
    left:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    local name = OneWoW_GUI:CreateFS(row, 12)
    name:SetPoint("LEFT", left, "RIGHT", 8, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -88, 0)
    name:SetJustifyH("LEFT")
    name:SetText(nameText)
    name:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    return row
end

local function MakeRemoveButton(row, onClick)
    local btn = OneWoW_GUI:CreateFitTextButton(row, { text = REMOVE, height = 20 })
    btn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
    if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
    btn:SetScript("OnEnter", function(myself) myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER")) end)
    btn:SetScript("OnLeave", function(myself) myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL")) end)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function SetBlockHeight(block, height)
    block._h = height
    block:SetHeight(height)
end

local function BuildDialog()
    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoWProgressTrackingDialog",
        showBrand = true,
        title = L["STATUS_TITLE"],
        width = 640,
        height = 700,
        titleHeight = 26,
        showScrollFrame = true,
        buttons = {
            {
                text = L["OVERRIDE_RESET_DEFAULTS"],
                onClick = function()
                    ns:ResetCurrencyTracking()
                    local progress = ns.db.global.overrides.progress
                    progress.worldBossQuestIDs = nil
                    progress.weeklyActivityQuests = nil
                    if trackingDialog and trackingDialog.Rebuild then
                        trackingDialog.Rebuild()
                    end
                    NotifyCurrencies()
                end,
            },
            {
                text = CLOSE,
                onClick = function(frame)
                    frame:Hide()
                end,
            },
        },
        relayout = function()
            if trackingDialog and trackingDialog.Rebuild then
                trackingDialog.Rebuild()
            end
        end,
    })

    local frame = result.frame
    local sc = result.scrollContent
    local pad = OneWoW_GUI:GetSpacing("SM")

    local identityWrap = OneWoW_GUI:CreateFrame(sc, {
        height = 36,
        bgColor = "BG_TERTIARY",
        borderColor = "BORDER_SUBTLE",
    })
    local identityVersion = OneWoW_GUI:CreateFS(identityWrap, 11)
    identityVersion:SetJustifyH("RIGHT")
    identityVersion:SetWordWrap(false)
    identityVersion:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    local identityTitle = OneWoW_GUI:CreateFS(identityWrap, 13)
    identityTitle:SetJustifyH("LEFT")
    identityTitle:SetWordWrap(false)
    identityTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local function LayoutIdentity()
        local verW = math.max(identityVersion:GetStringWidth() or 0, 1)
        identityVersion:ClearAllPoints()
        identityVersion:SetPoint("RIGHT", identityWrap, "RIGHT", -10, 0)
        identityVersion:SetWidth(verW)
        identityTitle:ClearAllPoints()
        identityTitle:SetPoint("LEFT", identityWrap, "LEFT", 10, 0)
        identityTitle:SetPoint("RIGHT", identityVersion, "LEFT", -8, 0)
    end

    local function RebuildIdentity()
        local title, version = ns.UI.GetSeasonIdentity()
        identityTitle:SetText(title)
        identityVersion:SetText(version)
        LayoutIdentity()
    end
    RebuildIdentity()

    local introWrap = CreateFrame("Frame", nil, sc)
    local intro = OneWoW_GUI:CreateFS(introWrap, 12)
    intro:SetPoint("TOPLEFT", 0, 0)
    intro:SetPoint("TOPRIGHT", 0, 0)
    intro:SetJustifyH("LEFT")
    intro:SetWordWrap(true)
    intro:SetSpacing(3)
    intro:SetText(L["OVERRIDE_SYSTEM_DESC"])
    intro:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    function introWrap:GetMeasuredHeight()
        return (intro:GetStringHeight() or 12) + 4
    end

    local seasonBlock = CreateFrame("Frame", nil, sc)
    local bossBlock = CreateFrame("Frame", nil, sc)
    local currencyBlock = CreateFrame("Frame", nil, sc)

    local noteWrap = CreateFrame("Frame", nil, sc)
    local note = OneWoW_GUI:CreateFS(noteWrap, 10)
    note:SetPoint("TOPLEFT", 0, 0)
    note:SetPoint("TOPRIGHT", 0, 0)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(L["OVERRIDE_CURRENCY_LOGIN_NOTE"])
    note:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    function noteWrap:GetMeasuredHeight()
        return (note:GetStringHeight() or 10) + 4
    end

    local seasonRows = {}
    local bossRows = {}
    local currencyRows = {}

    local seasonHeader = OneWoW_GUI:CreateSectionHeader(seasonBlock, { title = RAIDS, yOffset = 0 })
    local dungeonLine = OneWoW_GUI:CreateFS(seasonBlock, 11)
    dungeonLine:SetJustifyH("LEFT")
    dungeonLine:SetWordWrap(true)
    dungeonLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    local weeklyLine = OneWoW_GUI:CreateFS(seasonBlock, 11)
    weeklyLine:SetJustifyH("LEFT")
    weeklyLine:SetWordWrap(true)
    weeklyLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local bossHeader = OneWoW_GUI:CreateSectionHeader(bossBlock, { title = L["OVERRIDE_WORLD_BOSS_QUEST"], yOffset = 0 })
    local addBossRow = OneWoW_GUI:CreateFrame(bossBlock, { height = 28, bgColor = "BG_SECONDARY", borderColor = "BORDER_SUBTLE" })
    local addBossLabel = OneWoW_GUI:CreateFS(addBossRow, 10)
    addBossLabel:SetPoint("LEFT", 8, 0)
    addBossLabel:SetText(L["OVERRIDE_ENTER_QUEST_ID"])
    addBossLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    local addBossBox = OneWoW_GUI:CreateEditBox(addBossRow, { width = 90, height = 22 })
    addBossBox:SetPoint("LEFT", addBossLabel, "RIGHT", 8, 0)
    addBossBox:SetNumeric(true)
    addBossBox:SetMaxLetters(8)
    local addBossBtn = OneWoW_GUI:CreateFitTextButton(addBossRow, { text = ADD, height = 22 })
    addBossBtn:SetPoint("LEFT", addBossBox, "RIGHT", 6, 0)

    local currencyHeader = OneWoW_GUI:CreateSectionHeader(currencyBlock, { title = L["OVERRIDE_PRESET_CURRENCIES"], yOffset = 0 })
    local seasonResetBtn = OneWoW_GUI:CreateFitTextButton(currencyHeader, { text = RESET, height = 22 })
    seasonResetBtn:SetPoint("RIGHT", currencyHeader, "RIGHT", -8, 0)
    currencyHeader.titleText:ClearAllPoints()
    currencyHeader.titleText:SetPoint("LEFT", 12, 0)
    currencyHeader.titleText:SetPoint("RIGHT", seasonResetBtn, "LEFT", -8, 0)

    local extrasHeader = OneWoW_GUI:CreateSectionHeader(currencyBlock, { title = L["OVERRIDE_ADD_CUSTOM_CURRENCY"], yOffset = 0 })
    local addCurrRow = OneWoW_GUI:CreateFrame(currencyBlock, { height = 28, bgColor = "BG_SECONDARY", borderColor = "BORDER_SUBTLE" })
    local addCurrLabel = OneWoW_GUI:CreateFS(addCurrRow, 10)
    addCurrLabel:SetPoint("LEFT", 8, 0)
    addCurrLabel:SetText(L["OVERRIDE_ENTER_CURRENCY_ID"])
    addCurrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    local addCurrBox = OneWoW_GUI:CreateEditBox(addCurrRow, { width = 90, height = 22 })
    addCurrBox:SetPoint("LEFT", addCurrLabel, "RIGHT", 8, 0)
    addCurrBox:SetNumeric(true)
    addCurrBox:SetMaxLetters(8)
    local addCurrBtn = OneWoW_GUI:CreateFitTextButton(addCurrRow, { text = ADD, height = 22 })
    addCurrBtn:SetPoint("LEFT", addCurrBox, "RIGHT", 6, 0)

    local stack

    local function RebuildSeason()
        for _, row in ipairs(seasonRows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(seasonRows)

        local y = seasonHeader.bottomY - 6
        local lists = ns.UI.GetProgressTrackingLists()
        for i = 1, #lists.raids do
            local row = MakeInfoRow(seasonBlock, lists.raids[i])
            row:SetPoint("TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", 0, y)
            y = y - 30
            tinsert(seasonRows, row)
        end
        dungeonLine:ClearAllPoints()
        dungeonLine:SetPoint("TOPLEFT", 4, y - 4)
        dungeonLine:SetPoint("TOPRIGHT", -4, y - 4)
        dungeonLine:SetText(L["SUBTAB_MYTHICPLUS"] .. "  " .. JoinNames(lists.dungeons))
        local dungeonH = dungeonLine:GetStringHeight() or 14
        y = y - dungeonH - 8
        weeklyLine:ClearAllPoints()
        weeklyLine:SetPoint("TOPLEFT", 4, y - 4)
        weeklyLine:SetPoint("TOPRIGHT", -4, y - 4)
        weeklyLine:SetText(L["PROGRESS_WEEKLY_ACTIVITIES"] .. "  " .. JoinNames(lists.weeklies))
        local weeklyH = weeklyLine:GetStringHeight() or 14
        SetBlockHeight(seasonBlock, math.abs(y) + weeklyH + 12)
        if stack then stack:Refresh() end
    end

    local function RebuildBosses()
        for _, row in ipairs(bossRows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(bossRows)

        local ids = ns:EnsureProgressList("worldBossQuestIDs")
        local y = bossHeader.bottomY - 6
        for i = 1, #ids do
            local questID = ids[i]
            local nm = C_QuestLog.GetTitleForQuestID(questID) or BOSS_NAME_FALLBACK[questID] or (L["OVERRIDE_ENTER_QUEST_ID"] .. " " .. questID)
            local row = MakeEditRow(bossBlock, tostring(questID), nm)
            row:SetPoint("TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", 0, y)
            MakeRemoveButton(row, function()
                local list = ns:EnsureProgressList("worldBossQuestIDs")
                for j = #list, 1, -1 do
                    if list[j] == questID then
                        tremove(list, j)
                    end
                end
                RebuildBosses()
                NotifyStrip()
            end)
            y = y - 32
            tinsert(bossRows, row)
        end
        addBossRow:ClearAllPoints()
        addBossRow:SetPoint("TOPLEFT", 0, y)
        addBossRow:SetPoint("TOPRIGHT", 0, y)
        SetBlockHeight(bossBlock, math.abs(y) + 32)
        if stack then stack:Refresh() end
    end

    local function RebuildCurrencies()
        for _, row in ipairs(currencyRows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(currencyRows)

        local y = currencyHeader.bottomY - 6
        local seasonIDs = ns:GetSeasonCurrencyIDs()
        local innerW = sc:GetWidth() or 600
        if innerW < 200 then innerW = 600 end
        local colW = math.floor((innerW - 8) / 2)
        local rows = math.ceil(#seasonIDs / 2)
        for i = 1, #seasonIDs do
            local currencyID = seasonIDs[i]
            local col = ((i - 1) % 2)
            local rowIndex = math.floor((i - 1) / 2)
            local cb = OneWoW_GUI:CreateCheckbox(currencyBlock, {
                label = CurrencyName(currencyID),
                checked = ns:IsSeasonCurrencyEnabled(currencyID),
                labelMaxWidth = colW - 40,
            })
            cb:SetPoint("TOPLEFT", 4 + col * colW, y - rowIndex * 28)
            cb:SetScript("OnClick", function(myself)
                ns:SetSeasonCurrencyEnabled(currencyID, myself:GetChecked())
                NotifyCurrencies()
            end)
            tinsert(currencyRows, cb)
        end
        y = y - rows * 28 - 8

        extrasHeader:ClearAllPoints()
        extrasHeader:SetPoint("TOPLEFT", 0, y)
        extrasHeader:SetPoint("TOPRIGHT", 0, y)
        local extrasH = extrasHeader:GetHeight() or 30
        y = y - extrasH - 6

        local extras = ns:GetExtraCurrencyIDs()
        for i = 1, #extras do
            local extraID = extras[i]
            local row = MakeEditRow(currencyBlock, tostring(extraID), CurrencyName(extraID))
            row:SetPoint("TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", 0, y)
            MakeRemoveButton(row, function()
                ns:RemoveExtraCurrencyID(extraID)
                RebuildCurrencies()
                NotifyCurrencies()
            end)
            y = y - 32
            tinsert(currencyRows, row)
        end

        addCurrRow:ClearAllPoints()
        addCurrRow:SetPoint("TOPLEFT", 0, y)
        addCurrRow:SetPoint("TOPRIGHT", 0, y)
        SetBlockHeight(currencyBlock, math.abs(y) + 32)
        if stack then stack:Refresh() end
        OneWoW_GUI:ApplyFontToFrame(frame)
    end

    local function Rebuild()
        RebuildIdentity()
        RebuildSeason()
        RebuildBosses()
        RebuildCurrencies()
    end

    addBossBtn:SetScript("OnClick", function()
        local val = tonumber(addBossBox:GetText()) or 0
        if val <= 0 then return end
        local ids = ns:EnsureProgressList("worldBossQuestIDs")
        for i = 1, #ids do
            if ids[i] == val then return end
        end
        tinsert(ids, val)
        addBossBox:SetText("")
        RebuildBosses()
        NotifyStrip()
    end)
    addBossBox:SetScript("OnEnterPressed", function() addBossBtn:Click() end)

    addCurrBtn:SetScript("OnClick", function()
        local val = tonumber(addCurrBox:GetText()) or 0
        local addResult = ns:AddTrackedCurrencyID(val)
        if addResult == "invalid" then return end
        addCurrBox:SetText("")
        RebuildCurrencies()
        NotifyCurrencies()
    end)
    addCurrBox:SetScript("OnEnterPressed", function() addCurrBtn:Click() end)

    seasonResetBtn:SetScript("OnClick", function()
        ns:ResetSeasonCurrencyToggles()
        RebuildCurrencies()
        NotifyCurrencies()
    end)

    stack = OneWoW_GUI:StackVertically(sc, {
        identityWrap,
        introWrap,
        seasonBlock,
        bossBlock,
        currencyBlock,
        noteWrap,
    }, {
        gap = OneWoW_GUI:GetSpacing("MD"),
        topPadding = pad,
        sidePadding = pad,
        autoHeight = true,
    })

    trackingDialog = {
        frame = frame,
        Rebuild = Rebuild,
    }

    Rebuild()
    OneWoW_GUI:ApplyFontToFrame(frame)
    return trackingDialog
end

--- Open the Progress tracking dialog (currencies, world bosses, season raids).
function ns.UI.ShowProgressTrackingDialog()
    if not trackingDialog then
        BuildDialog()
    else
        trackingDialog.Rebuild()
        OneWoW_GUI:ApplyFontToFrame(trackingDialog.frame)
    end
    trackingDialog.frame:Show()
    trackingDialog.frame:Raise()
end
