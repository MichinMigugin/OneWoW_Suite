local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.UI = ns.UI or {}

local currentSortColumn = nil
local currentSortAscending = true
local characterRows = {}

local columnsConfig = {
    {key = "expand", label = "", width = 25, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_EXPAND"], ttDesc = L["TT_COL_EXPAND_DESC"]},
    {key = "star", label = "", width = 30, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_STAR"], ttDesc = L["TT_COL_STAR_DESC"]},
    {key = "faction", label = L["COL_FACTION"], width = 25, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_FACTION"], ttDesc = L["TT_COL_FACTION_DESC"]},
    {key = "mail", label = L["COL_MAIL"], width = 35, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_MAIL"], ttDesc = L["TT_COL_MAIL_DESC"]},
    {key = "name", label = L["COL_CHARACTER"], width = 135, fixed = false, align = "left", ttTitle = L["TT_COL_CHARACTER"], ttDesc = L["TT_COL_CHARACTER_DESC"]},
    {key = "level", label = L["COL_LEVEL"], width = 40, fixed = true, align = "center", ttTitle = L["TT_COL_LEVEL"], ttDesc = L["TT_COL_LEVEL_DESC"]},
    {key = "lockout1", label = L["LOCKOUTS_COL_LOCKOUT_1"], width = 120, fixed = false, align = "left", ttTitle = L["TT_COL_LOCKOUT_1"], ttDesc = L["TT_COL_LOCKOUT_1_DESC"]},
    {key = "lockout2", label = L["LOCKOUTS_COL_LOCKOUT_2"], width = 120, fixed = false, align = "left", ttTitle = L["TT_COL_LOCKOUT_2"], ttDesc = L["TT_COL_LOCKOUT_2_DESC"]},
    {key = "lockout3", label = L["LOCKOUTS_COL_LOCKOUT_3"], width = 120, fixed = false, align = "left", ttTitle = L["TT_COL_LOCKOUT_3"], ttDesc = L["TT_COL_LOCKOUT_3_DESC"]},
    {key = "lockout4", label = L["LOCKOUTS_COL_LOCKOUT_4"], width = 120, fixed = false, align = "left", ttTitle = L["TT_COL_LOCKOUT_4"], ttDesc = L["TT_COL_LOCKOUT_4_DESC"]},
    {key = "expires", label = L["LOCKOUTS_COL_EXPIRES"], width = 80, fixed = false, align = "left", ttTitle = L["TT_COL_EXPIRES"], ttDesc = L["TT_COL_EXPIRES_DESC"]}
}

local onHeaderCreate = function(btn, col, index)
    if col.key == "expand" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("CENTER")
        icon:SetAtlas("Gamepad_Rev_Plus_64")
        btn.icon = icon
        if btn.text then btn.text:SetText("") end
    elseif col.key == "faction" then
        if btn.text then btn.text:SetText("") end
    elseif col.key == "mail" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(12, 12)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
        btn.icon = icon
        if btn.text then btn.text:SetText("") end
    elseif col.key == "star" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(12, 12)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface/Common/FavoritesIcon")
        btn.icon = icon
        if btn.text then btn.text:SetText("") end
    end
end

function ns.UI.CreateLockoutsTab(parent)
    local overview = OneWoW_GUI:CreateOverviewPanel(parent, {
        title = L["LOCKOUTS_OVERVIEW"],
        height = 70,
        columns = 5,
        stats = {
            { label = L["LOCKOUTS_ATTENTION"], value = "0", ttTitle = L["TT_LOCKOUTS_ATTENTION"], ttDesc = L["TT_LOCKOUTS_ATTENTION_DESC"] },
            { label = L["LOCKOUTS_ACTIVE"], value = "0", ttTitle = L["TT_LOCKOUTS_ACTIVE"], ttDesc = L["TT_LOCKOUTS_ACTIVE_DESC"] },
            { label = L["LOCKOUTS_DUNGEONS"], value = "0", ttTitle = L["TT_LOCKOUTS_DUNGEONS"], ttDesc = L["TT_LOCKOUTS_DUNGEONS_DESC"] },
            { label = L["LOCKOUTS_RAIDS"], value = "0", ttTitle = L["TT_LOCKOUTS_RAIDS"], ttDesc = L["TT_LOCKOUTS_RAIDS_DESC"] },
            { label = L["LOCKOUTS_NEXT_IN"], value = "0m", ttTitle = L["TT_LOCKOUTS_NEXT_IN"], ttDesc = L["TT_LOCKOUTS_NEXT_IN_DESC"] },
        },
    })

    local rosterPanel = OneWoW_GUI:CreateRosterPanel(parent, overview.panel)

    local dt
    dt = OneWoW_GUI:CreateDataTable(rosterPanel, {
        columns = columnsConfig,
        headerHeight = 26,
        onHeaderCreate = onHeaderCreate,
        onSort = function(sortColumn, sortAscending)
            currentSortColumn = sortColumn
            currentSortAscending = sortAscending
            ns.UI.RefreshLockoutsTab(parent)
            C_Timer.After(0.1, function() dt.UpdateSortIndicators() end)
        end,
    })

    local statusBar = OneWoW_GUI:CreateStatusBar(parent, rosterPanel, {
        text = string.format(L["CHARACTERS_TRACKED"], 0, ""),
    })

    parent.dataTable = dt
    parent.headerRow = dt.headerRow
    parent.scrollContent = dt.scrollContent
    parent.rosterPanel = rosterPanel
    parent.statBoxes = overview.statBoxes
    parent.statusText = statusBar.text
    parent.statusBar = statusBar.bar

    OneWoW_GUI:ApplyFontToFrame(parent)

    C_Timer.After(0.5, function()
        if ns.UI.RefreshLockoutsTab then
            ns.UI.RefreshLockoutsTab(parent)
        end
    end)

    if ns.UI.RegisterRosterTabFrame then
        ns.UI.RegisterRosterTabFrame("lockouts", parent)
    end
end

function ns.UI.RefreshLockoutsTab(lockoutsTab)
    if not lockoutsTab then return end
    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return end
    if not _G.OneWoW_AltTracker_Endgame_DB or not _G.OneWoW_AltTracker_Endgame_DB.characters then return end

    local allChars = ns.UI.GetSortedCharacters(function(charKey, charData, col)
        if col == "name" then
            return charData.name or ""
        elseif col == "level" then
            return charData.level or 0
        elseif col == "lockout1" or col == "lockout2" or col == "lockout3" or col == "lockout4" then
            local lockoutIndex = tonumber(string.match(col, "%d+"))
            local endgame = _G.OneWoW_AltTracker_Endgame_DB and _G.OneWoW_AltTracker_Endgame_DB.characters and _G.OneWoW_AltTracker_Endgame_DB.characters[charKey]
            return (endgame and endgame.raids and endgame.raids.lockouts and endgame.raids.lockouts[lockoutIndex] and endgame.raids.lockouts[lockoutIndex].name) or ""
        elseif col == "expires" then
            local endgame = _G.OneWoW_AltTracker_Endgame_DB and _G.OneWoW_AltTracker_Endgame_DB.characters and _G.OneWoW_AltTracker_Endgame_DB.characters[charKey]
            local currentTime = time()
            local soonest = 999999999
            if endgame and endgame.raids and endgame.raids.lockouts then
                for _, lockout in ipairs(endgame.raids.lockouts) do
                    if lockout.reset and lockout.reset > 0 then
                        local expiresAt = currentTime + lockout.reset
                        if expiresAt < soonest then
                            soonest = expiresAt
                        end
                    end
                end
            end
            return soonest
        else
            return charData.name or ""
        end
    end, currentSortColumn, currentSortAscending)
    if #allChars == 0 then return end

    local scrollContent = lockoutsTab.scrollContent
    local dt = lockoutsTab.dataTable
    if not scrollContent then return end

    OneWoW_GUI:ClearDataRows(scrollContent)
    wipe(characterRows)
    if dt then dt:ClearRows() end

    local rowHeight = 32
    local rowGap = 2

    for charIndex, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local charData = charInfo.data

        local endgameData = _G.OneWoW_AltTracker_Endgame_DB.characters[charKey]
        local lockouts = {}
        local currentTime = time()

        if endgameData and endgameData.raids and endgameData.raids.lockouts then
            for _, lockout in ipairs(endgameData.raids.lockouts) do
                local expiresAt = currentTime + (lockout.reset or 0)
                if lockout.reset and lockout.reset > 0 then
                    table.insert(lockouts, {
                        name = lockout.name,
                        id = lockout.id,
                        difficulty = lockout.difficultyName,
                        expiresAt = expiresAt,
                        isRaid = true,
                        encounterProgress = lockout.encounterProgress or 0,
                        totalEncounters = lockout.numEncounters or 0,
                    })
                end
            end
        end

        table.sort(lockouts, function(a, b)
            if a.isRaid ~= b.isRaid then
                return a.isRaid
            end
            return (a.expiresAt or 0) < (b.expiresAt or 0)
        end)

        local charRow = OneWoW_GUI:CreateDataRow(scrollContent, {
            rowHeight = rowHeight,
            expandedHeight = 160,
            rowGap = rowGap,
            data = {
                charKey = charKey,
                charData = charData,
                lockouts = lockouts,
                currentTime = currentTime,
            },
            createDetails = function(ef, d)
                local grid = OneWoW_GUI:CreateExpandedPanelGrid(ef, T)

                local raidList = {}
                local dungeonList = {}

                for _, lockout in ipairs(d.lockouts) do
                    if lockout.isRaid then
                        table.insert(raidList, lockout)
                    else
                        table.insert(dungeonList, lockout)
                    end
                end

                local pRaids = grid:AddPanel(L["LOCKOUTS_RAIDS"])
                local pDungeons = grid:AddPanel(L["LOCKOUTS_DUNGEONS"])

                if #raidList > 0 then
                    for _, lockout in ipairs(raidList) do
                        local timeLeft = lockout.expiresAt - d.currentTime
                        local daysLeft = math.floor(timeLeft / 86400)
                        local hoursLeft = math.floor((timeLeft % 86400) / 3600)
                        local timeLeftText = daysLeft > 0 and string.format("%dd %dh", daysLeft, hoursLeft) or string.format("%dh", hoursLeft)
                        local progressText = string.format("(%d/%d)", lockout.encounterProgress, lockout.totalEncounters)
                        grid:AddLine(pRaids, string.format("%s %s", lockout.difficulty or "", lockout.name or ""))
                        grid:AddLine(pRaids, "  " .. progressText .. " - " .. timeLeftText, {OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY")})
                    end
                else
                    grid:AddLine(pRaids, L["LOCKOUTS_NO_RAID"], {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
                end

                if #dungeonList > 0 then
                    for _, lockout in ipairs(dungeonList) do
                        local timeLeft = lockout.expiresAt - d.currentTime
                        local daysLeft = math.floor(timeLeft / 86400)
                        local hoursLeft = math.floor((timeLeft % 86400) / 3600)
                        local timeLeftText = daysLeft > 0 and string.format("%dd %dh", daysLeft, hoursLeft) or string.format("%dh", hoursLeft)
                        grid:AddLine(pDungeons, string.format("%s %s", lockout.difficulty or "", lockout.name or ""))
                        grid:AddLine(pDungeons, "  " .. timeLeftText, {OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY")})
                    end
                else
                    grid:AddLine(pDungeons, L["LOCKOUTS_NO_DUNGEON"], {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
                end

                grid:Finish()
                OneWoW_GUI:ApplyFontToFrame(ef)
            end,
        })
        charRow.charKey = charKey

        ns.UI.AddCommonCells(charRow, charKey, charData)
        ns.UI.AddLevelCell(charRow, charData)

        local lockoutTexts = {}
        for i = 1, 4 do
            local lockout = lockouts[i]
            local lockoutText = OneWoW_GUI:CreateFS(charRow, 10)
            lockoutText:SetJustifyH("LEFT")

            if lockout then
                local displayText = lockout.name or ""
                if lockout.isRaid and lockout.totalEncounters and lockout.totalEncounters > 0 then
                    displayText = string.format("%s (%d/%d)", displayText, lockout.encounterProgress or 0, lockout.totalEncounters)
                end

                lockoutText:SetText(displayText)
                lockoutText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

                lockoutText:EnableMouse(true)
                lockoutText:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(lockout.name or "", 1, 1, 1)
                    GameTooltip:AddLine(string.format("%s: %s", L["LOCKOUTS_DIFFICULTY"], lockout.difficulty or ""), 0.7, 0.7, 0.7)
                    if lockout.isRaid and lockout.totalEncounters and lockout.totalEncounters > 0 then
                        GameTooltip:AddLine(string.format("%s: %d/%d", L["PROGRESS"], lockout.encounterProgress or 0, lockout.totalEncounters), 1, 0.82, 0)
                    end
                    if lockout.expiresAt then
                        local timeLeft = lockout.expiresAt - currentTime
                        local daysLeft = math.floor(timeLeft / 86400)
                        local hoursLeft = math.floor((timeLeft % 86400) / 3600)
                        local minutesLeft = math.floor((timeLeft % 3600) / 60)
                        local timeLeftText = ""
                        if daysLeft > 0 then
                            timeLeftText = string.format("%dd %dh", daysLeft, hoursLeft)
                        elseif hoursLeft > 0 then
                            timeLeftText = string.format("%dh %dm", hoursLeft, minutesLeft)
                        else
                            timeLeftText = string.format("%dm", minutesLeft)
                        end
                        GameTooltip:AddLine(string.format("%s: %s", L["LOCKOUTS_UNLOCKS_IN"], timeLeftText), 0.5, 0.9, 1)
                    end
                    GameTooltip:Show()
                end)
                lockoutText:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
            else
                lockoutText:SetText("-")
                lockoutText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            end

            table.insert(charRow.cells, lockoutText)
            table.insert(lockoutTexts, lockoutText)
        end

        local expiresText = OneWoW_GUI:CreateFS(charRow, 10)
        expiresText:SetJustifyH("LEFT")
        if #lockouts > 0 then
            local soonestLockout = lockouts[1]
            if soonestLockout and soonestLockout.expiresAt then
                local timeLeft = soonestLockout.expiresAt - currentTime
                local daysLeft = math.floor(timeLeft / 86400)
                local hoursLeft = math.floor((timeLeft % 86400) / 3600)
                if daysLeft > 0 then
                    expiresText:SetText(string.format("%dd %dh", daysLeft, hoursLeft))
                else
                    expiresText:SetText(string.format("%dh", hoursLeft))
                end
                expiresText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
            else
                expiresText:SetText("-")
                expiresText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            end
        else
            expiresText:SetText("-")
            expiresText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        table.insert(charRow.cells, expiresText)

        if dt and dt.headerRow and dt.headerRow.columnButtons and columnsConfig then
            for i, cell in ipairs(charRow.cells) do
                local btn = dt.headerRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX
                    local col = columnsConfig[i]
                    cell:ClearAllPoints()
                    if col and col.align == "icon" then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", charRow, "LEFT", x, 0)
                    elseif col and col.align == "center" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("CENTER", charRow, "LEFT", x + width / 2, 0)
                    elseif col and col.align == "right" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("RIGHT", charRow, "LEFT", x + width - 3, 0)
                    else
                        cell:SetWidth(width - 6)
                        cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
                    end
                end
            end
        end

        table.insert(characterRows, charRow)
        if dt then dt:RegisterRow(charRow) end
    end

    OneWoW_GUI:LayoutDataRows(scrollContent)

    if lockoutsTab.statusText then
        lockoutsTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], #allChars, ""))
    end

    ns.UI.RefreshLockoutsStats(lockoutsTab)

    OneWoW_GUI:ApplyFontToFrame(lockoutsTab)

    C_Timer.After(0.1, function()
        if lockoutsTab.headerRow then
            lockoutsTab.headerRow:GetScript("OnSizeChanged")(lockoutsTab.headerRow)
        end
    end)
end

function ns.UI.RefreshLockoutsStats(lockoutsTab)
    if not lockoutsTab or not lockoutsTab.statBoxes then return end
    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return end
    if not _G.OneWoW_AltTracker_Endgame_DB or not _G.OneWoW_AltTracker_Endgame_DB.characters then return end

    local stats = {
        attention = 0,
        active = 0,
        dungeons = 0,
        raids = 0,
        nextReset = nil
    }

    local currentTime = time()
    local soonestReset = nil

    for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
        local endgameData = _G.OneWoW_AltTracker_Endgame_DB.characters[charKey]

        local hasLockouts = false
        if endgameData and endgameData.raids and endgameData.raids.lockouts then
            for _, lockout in ipairs(endgameData.raids.lockouts) do
                if lockout.reset and lockout.reset > 0 then
                    local expiresAt = currentTime + lockout.reset
                    stats.active = stats.active + 1
                    hasLockouts = true

                    stats.raids = stats.raids + 1

                    if not soonestReset or expiresAt < soonestReset then
                        soonestReset = expiresAt
                    end
                end
            end
        end

        if not hasLockouts then
            stats.attention = stats.attention + 1
        end
    end

    local statBoxes = lockoutsTab.statBoxes
    if statBoxes then
        if statBoxes[1] then statBoxes[1].value:SetText(tostring(stats.attention)) end
        if statBoxes[2] then statBoxes[2].value:SetText(tostring(stats.active)) end
        if statBoxes[3] then statBoxes[3].value:SetText(tostring(stats.dungeons)) end
        if statBoxes[4] then statBoxes[4].value:SetText(tostring(stats.raids)) end
        if statBoxes[5] then
            if soonestReset then
                local timeLeft = soonestReset - currentTime
                local daysLeft = math.floor(timeLeft / 86400)
                local hoursLeft = math.floor((timeLeft % 86400) / 3600)
                local minutesLeft = math.floor((timeLeft % 3600) / 60)

                if daysLeft > 0 then
                    statBoxes[5].value:SetText(string.format("%dd %dh", daysLeft, hoursLeft))
                elseif hoursLeft > 0 then
                    statBoxes[5].value:SetText(string.format("%dh %dm", hoursLeft, minutesLeft))
                else
                    statBoxes[5].value:SetText(string.format("%dm", minutesLeft))
                end
            else
                statBoxes[5].value:SetText("-")
            end
        end
    end
end
