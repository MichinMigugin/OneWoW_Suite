local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local L = ns.L
ns.UI = ns.UI or {}

local HEADER_HEIGHT = 30
local DUNGEON_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_Map01"
local CURRENCY_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"
local DOT_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local DOT_COLOR_ALL  = {0.20, 0.90, 0.20, 1}
local DOT_COLOR_SOME = {0.94, 0.78, 0.20, 1}
local DOT_COLOR_NONE = {0.70, 0.20, 0.20, 1}
local DOT_COLOR_EMPTY = {0.25, 0.25, 0.25, 1}
local BOX_COLOR_MET  = {0.15, 0.55, 0.15, 0.85}
local BOX_COLOR_UNMET = {0.55, 0.15, 0.15, 0.85}

local function GetSeasonData()
    return ns.SeasonData
end

local function GetSeasonDungeons()
    local sd = GetSeasonData()
    local list = sd.dungeons
    for _, dung in ipairs(list) do
        sd:ResolveDungeonMapID(dung)
    end
    return list
end

local function GetSeasonRaids()
    local sd = GetSeasonData()
    return (sd and sd.raids) or {}
end

local function GetRaidDifficulties(raid)
    local sd = GetSeasonData()
    if not sd then
        return {}
    end
    return sd:GetRaidDifficulties(raid)
end

local function RaidDisplayName(raid)
    local sd = GetSeasonData()
    if sd then
        local journalInstanceID = sd:ResolveRaid(raid)
        if journalInstanceID then
            local name = EJ_GetInstanceInfo(journalInstanceID)
            if name then
                return name
            end
        end
    end
    return raid.label
end

local function DifficultyDisplayName(diff)
    local name = GetDifficultyInfo(diff.id)
    if name and name ~= "" then
        return name
    end
    return diff.label
end

local CURRENCY_COL_WIDTH = 45

local function CurrencyDisplayName(id)
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if info and info.name and info.name ~= "" then
        return info.name
    end
    return CURRENCY .. " " .. id
end

--- Progress Currencies columns follow the same effective list as collection.
local function GetCurrencyColumnDefs()
    local cols = {}
    local ids = ns:GetProgressList("trackedCurrencyIDs")
    for i = 1, #ids do
        local id = ids[i]
        table.insert(cols, {
            key = "cur_" .. id,
            currencyID = id,
            name = CurrencyDisplayName(id),
            width = CURRENCY_COL_WIDTH,
        })
    end
    return cols
end

local subTabState = {
    mythicplus = { sortColumn = nil, sortAscending = true, rows = {}, columns = {} },
    raids      = { sortColumn = nil, sortAscending = true, rows = {}, columns = {} },
    currencies = { sortColumn = nil, sortAscending = true, rows = {}, columns = {} },
    weekly     = { sortColumn = nil, sortAscending = true, rows = {}, columns = {} },
}
local currentSubTab = "mythicplus"

local function GetWeeklyActivitiesList()
    return ns:GetProgressList("weeklyActivityQuests")
end

local function GetWeeklyActivityLabel(entry)
    if entry.localeKey and L[entry.localeKey] then
        return L[entry.localeKey]
    end
    if entry.name then
        return entry.name
    end
    local ids = entry.questIDs
    if type(ids) == "table" and ids[1] then
        return C_QuestLog.GetTitleForQuestID(ids[1]) or entry.key or "?"
    end
    if entry.questID then
        return C_QuestLog.GetTitleForQuestID(entry.questID) or entry.key or "?"
    end
    return entry.key or "?"
end

local function GetWeeklyActivityCompleted(endgameData, activityKey)
    if not activityKey or not endgameData or not endgameData.weeklyActivities or not endgameData.weeklyActivities.activities then
        return false
    end
    local a = endgameData.weeklyActivities.activities[activityKey]
    return a and a.completed or false
end

local function GetWeeklyActivityCounts(endgameData)
    local activities = GetWeeklyActivitiesList()
    local done = 0
    local total = #activities
    for _, entry in ipairs(activities) do
        if GetWeeklyActivityCompleted(endgameData, entry.key) then
            done = done + 1
        end
    end
    return done, total
end

local function GetBestTimedRun(endgameData)
    if not endgameData or not endgameData.mythicPlus or not endgameData.mythicPlus.seasonBest then
        return nil, nil
    end
    local bestLevel = 0
    local bestMapID = nil
    for mapID, mapInfo in pairs(endgameData.mythicPlus.seasonBest) do
        if mapInfo.intime and mapInfo.intime.level and mapInfo.intime.level > bestLevel then
            bestLevel = mapInfo.intime.level
            bestMapID = mapID
        end
    end
    if bestLevel > 0 and bestMapID then
        return bestLevel, bestMapID
    end
    return nil, nil
end

local function GetBestRunString(endgameData)
    local level = GetBestTimedRun(endgameData)
    if not level then return "--" end
    return "+" .. level
end

local function GetBestRunFullString(endgameData)
    local level, mapID = GetBestTimedRun(endgameData)
    if not level then return nil end
    local mapName = mapID and C_ChallengeMode.GetMapUIInfo(mapID)
    if mapName then return "+" .. level .. " " .. mapName end
    return "+" .. level
end

local function VaultTypeStr(grid, panel, list, label)
    if not list or #list == 0 then
        grid:AddLine(panel, label .. ": --", {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
        return
    end
    local parts = {}
    for _, act in ipairs(list) do
        local prog = act.progress or 0
        local thresh = act.threshold or 0
        if prog >= thresh and thresh > 0 then
            table.insert(parts, "|cFF00FF00" .. prog .. "/" .. thresh .. "|r")
        else
            table.insert(parts, prog .. "/" .. thresh)
        end
    end
    grid:AddLine(panel, label .. ": " .. table.concat(parts, "  "))
end

local function GetVaultTrackTotal(list)
    if not list then return 0 end
    local highest = 0
    for _, act in ipairs(list) do
        local prog = act.progress or 0
        if prog > highest then highest = prog end
    end
    return highest
end

local function GetHoveredColumnKey(self, columns, contentFrame)
    local x = GetCursorPosition() / UIParent:GetEffectiveScale()
    local rowLeft = self:GetLeft()
    if not rowLeft then return nil end
    local relX = x - rowLeft
    local hdrRow = contentFrame.headerRow
    if hdrRow and hdrRow.columnButtons then
        for i, btn in ipairs(hdrRow.columnButtons) do
            if btn.columnX and btn.columnWidth then
                if relX >= btn.columnX and relX <= btn.columnX + btn.columnWidth then
                    if columns[i] then return columns[i].key end
                    return nil
                end
            end
        end
    end
    return nil
end

local function GetTrackedCurrencyData(endgameData)
    local lines = {}
    if endgameData and endgameData.currencies and endgameData.currencies.tracked then
        local order = {}
        for id, info in pairs(endgameData.currencies.tracked) do
            if info and info.name then
                table.insert(order, {id = id, info = info})
            end
        end
        table.sort(order, function(a, b) return (a.id or 0) < (b.id or 0) end)
        for _, entry in ipairs(order) do
            local info = entry.info
            local qty = info.quantity or 0
            local maxQty = info.maxQuantity or 0
            local weeklyEarned = info.quantityEarnedThisWeek
            local weeklyCap = info.maxWeeklyQuantity
            local displayStr
            if weeklyCap and weeklyCap > 0 then
                displayStr = (weeklyEarned or qty) .. "/" .. weeklyCap .. " " .. L["PROGRESS_THIS_WEEK"]
            elseif maxQty > 0 then
                displayStr = qty .. "/" .. maxQty
            else
                displayStr = tostring(qty)
            end
            table.insert(lines, {name = info.name, text = displayStr, qty = qty, cap = maxQty})
        end
    end
    return lines
end

local function GetVaultTypeString(endgameData, vaultType)
    if not endgameData or not endgameData.greatVault or not endgameData.greatVault.activities then
        return "--"
    end
    local list = endgameData.greatVault.activities[vaultType]
    if not list or #list == 0 then return "--" end
    local completed = 0
    local total = #list
    for _, act in ipairs(list) do
        if (act.threshold or 0) > 0 and (act.progress or 0) >= act.threshold then
            completed = completed + 1
        end
    end
    return completed .. "/" .. total
end

local KNOWN_BOSS_NAMES = {
    [92123] = "Cragpine",
    [92560] = "Lu'ashal",
    [92636] = "Predaxas",
    [92034] = "Thorm'belan",
    [96472] = "Nexus-Captain Leth'ir",
    [96473] = "Imperator Pertinax",
    [97128] = "Nymrissa Wavecaller",
}

local function GetWorldBossKilled(endgameData)
    if not endgameData or not endgameData.worldBoss then return false, nil end
    local wb = endgameData.worldBoss
    if wb.questCompleted then
        return true, wb.questBossName or (wb.questBossID and KNOWN_BOSS_NAMES[wb.questBossID])
    end
    if wb.killedBosses and #wb.killedBosses > 0 then
        return true, wb.killedBosses[1].name
    end
    return false, nil
end

local function GetProgressSortValue(charKey, charData, sortColumn)
    local endgameDB = OneWoW_AltTracker_Endgame_API and OneWoW_AltTracker_Endgame_API.GetAllCharacters()
    local edg = endgameDB and endgameDB[charKey]

    if sortColumn == "name" then
        return charData.name or ""
    elseif sortColumn == "server" then
        return charData.realm or ""
    elseif sortColumn == "level" then
        return charData.level or 0
    elseif sortColumn == "ilvl" then
        return charData.itemLevel or 0
    elseif sortColumn == "rating" then
        return (edg and edg.mythicPlus and edg.mythicPlus.overallScore) or 0
    elseif sortColumn == "bestTime" then
        return GetBestTimedRun(edg) or 0
    elseif sortColumn == "keystone" then
        return (edg and edg.mythicPlus and edg.mythicPlus.currentKeystone and edg.mythicPlus.currentKeystone.level) or 0
    elseif sortColumn == "worldBoss" then
        return GetWorldBossKilled(edg) and 1 or 0
    elseif sortColumn:sub(1, 4) == "cur_" then
        local cid = tonumber(sortColumn:sub(5))
        if not edg or not edg.currencies or not edg.currencies.tracked then return 0 end
        local c = edg.currencies.tracked[cid]
        return c and (c.quantity or 0) or 0
    elseif sortColumn == "vaultRaid" then
        return GetVaultTypeString(edg, "raid")
    elseif sortColumn == "vaultDungeon" then
        return GetVaultTypeString(edg, "dungeon")
    elseif sortColumn == "vaultWorld" then
        return GetVaultTypeString(edg, "world")
    elseif sortColumn == "weeklyCount" then
        local done = GetWeeklyActivityCounts(edg)
        return done or 0
    elseif sortColumn:sub(1, 3) == "wa_" then
        return GetWeeklyActivityCompleted(edg, sortColumn:sub(4)) and 1 or 0
    elseif sortColumn:sub(1, 5) == "raid_" then
        local raidKey = sortColumn:sub(6)
        if edg and edg.raids and edg.raids.bosses and edg.raids.bosses[raidKey] then
            local prog = edg.raids.bosses[raidKey].progress or {}
            local best = 0
            for _, p in pairs(prog) do
                if p > best then best = p end
            end
            return best
        end
        return 0
    else
        for _, dung in ipairs(GetSeasonDungeons()) do
            if dung.key == sortColumn then
                if not edg or not edg.mythicPlus or not edg.mythicPlus.seasonBest then return 0 end
                local best = edg.mythicPlus.seasonBest[dung.mapID]
                if best and best.intime then return best.intime.level or 0 end
                return 0
            end
        end
    end
    return charData.name or ""
end

local function GetSortedCharacters(subTabKey)
    if not OneWoW_AltTracker_Endgame_API then return {} end
    local state = subTabState[subTabKey]
    return ns.UI.GetSortedCharacters(GetProgressSortValue, state.sortColumn, state.sortAscending)
end

local _measureFS = nil
local function MeasureTextWidth(text, fontSize)
    if not text or text == "" then return 0 end
    if not _measureFS then
        _measureFS = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        _measureFS:Hide()
    end
    OneWoW_GUI:SafeSetFont(_measureFS, OneWoW_GUI:GetFont(), fontSize or 12)
    _measureFS:SetText(text)
    return math.ceil(_measureFS:GetStringWidth() or 0)
end

local function UpdateCharServerMinWidths(contentFrame, allChars)
    local cols = contentFrame.headerRow and contentFrame.headerRow.columns
    if not cols then return end

    local nameIdx, serverIdx = nil, nil
    for i, c in ipairs(cols) do
        if c.key == "name" then nameIdx = i
        elseif c.key == "server" then serverIdx = i end
    end

    local maxName = 0
    local maxServer = 0
    for _, charInfo in ipairs(allChars) do
        local charData = charInfo.data or {}
        local nameW = MeasureTextWidth(charData.name or "", 12)
        if nameW > maxName then maxName = nameW end
        local serverW = MeasureTextWidth(charData.realm or "", 12)
        if serverW > maxServer then maxServer = serverW end
    end

    if nameIdx and cols[nameIdx] then
        cols[nameIdx].minWidth = math.max(cols[nameIdx].width or 135, maxName + 16)
    end
    if serverIdx and cols[serverIdx] then
        cols[serverIdx].minWidth = math.max(cols[serverIdx].width or 50, maxServer + 12)
    end
end

local function CreateSubTabContent(contentFrame, columnsConfig, subTabKey)
    local state = subTabState[subTabKey]
    state.columns = columnsConfig

    local function onHeaderCreate(btn, col, _)
        if col.key == "expand" then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(14, 14)
            icon:SetPoint("CENTER")
            icon:SetAtlas("Gamepad_Rev_Plus_64")
            btn.icon = icon
        elseif col.key == "mail" then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(12, 12)
            icon:SetPoint("CENTER")
            icon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
            btn.icon = icon
        elseif col.key == "star" then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(12, 12)
            icon:SetPoint("CENTER")
            OneWoW_GUI:SetFavoriteAtlasTexture(icon)
            btn.icon = icon
        elseif col.dungData then
            local dung = col.dungData
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(22, 22)
            icon:SetPoint("CENTER")
            local tex = nil
            if dung.mapID and dung.mapID > 0 then
                local _, _, _, texture = C_ChallengeMode.GetMapUIInfo(dung.mapID)
                if texture and texture > 0 then tex = texture end
            end
            if tex then
                icon:SetTexture(tex)
            else
                icon:SetTexture(DUNGEON_ICON_FALLBACK)
            end
            btn.icon = icon
            if btn.text then btn.text:SetText("") end
        elseif col.raidData then
            local raid = col.raidData
            local tex = nil
            local sd = GetSeasonData()
            if sd then
                local _, _, buttonImage = sd:ResolveRaid(raid)
                if buttonImage and buttonImage > 0 then
                    tex = buttonImage
                end
            end
            if tex then
                local icon = btn:CreateTexture(nil, "ARTWORK")
                icon:SetSize(22, 22)
                icon:SetPoint("CENTER")
                icon:SetTexture(tex)
                btn.icon = icon
                if btn.text then btn.text:SetText("") end
            end
        elseif col.currencyData then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18)
            icon:SetPoint("CENTER")
            local iconID = nil
            if col.currencyData.currencyID then
                local info = C_CurrencyInfo.GetCurrencyInfo(col.currencyData.currencyID)
                if info and info.iconFileID and info.iconFileID > 0 then
                    iconID = info.iconFileID
                end
            end
            icon:SetTexture(iconID or CURRENCY_ICON_FALLBACK)
            btn.icon = icon
            if btn.text then btn.text:SetText("") end
        end
    end

    local dt
    dt = OneWoW_GUI:CreateDataTable(contentFrame, {
        columns = columnsConfig,
        headerHeight = HEADER_HEIGHT,
        rowHeight = 32,
        onHeaderCreate = onHeaderCreate,
        onSort = function(sortColumn, sortAscending)
            state.sortColumn = sortColumn
            state.sortAscending = sortAscending
            local refreshFunc = contentFrame.refreshFunc
            if refreshFunc then
                refreshFunc(contentFrame)
                C_Timer.After(0.1, function() dt.UpdateSortIndicators() end)
            end
        end,
    })

    contentFrame.dataTable = dt
    contentFrame.headerRow = dt.headerRow
    contentFrame.scrollContent = dt.scrollContent
    contentFrame.UpdateColumnLayout = dt.UpdateColumnLayout
    contentFrame.UpdateSortIndicators = dt.UpdateSortIndicators

    return contentFrame
end

local function CreateCommonCells(charRow, charData, charKey, endgameData, _)
    ns.UI.AddCommonCells(charRow, charKey, charData)

    local realmText = OneWoW_GUI:CreateFS(charRow, 12)
    realmText:SetText(charData.realm or "")
    realmText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    realmText:SetJustifyH("LEFT")
    table.insert(charRow.cells, realmText)

    ns.UI.AddLevelCell(charRow, charData)

    local ilvlText = OneWoW_GUI:CreateFS(charRow, 12)
    local ilvl = charData.itemLevel or 0
    ilvlText:SetText(ilvl > 0 and tostring(ilvl) or "--")
    ilvlText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    if charData.itemLevelColor then
        ilvlText:SetTextColor(charData.itemLevelColor.r, charData.itemLevelColor.g, charData.itemLevelColor.b)
    end
    table.insert(charRow.cells, ilvlText)

    local ratingText = OneWoW_GUI:CreateFS(charRow, 12)
    local rating = (endgameData and endgameData.mythicPlus and endgameData.mythicPlus.overallScore) or 0
    ratingText:SetText(tostring(rating))
    ratingText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    table.insert(charRow.cells, ratingText)
end

local EXPAND_LINE_H = 14
local EXPAND_PAD = 6

local RAID_EXPAND_DIFF_COL = 18

local VAULT_EXPAND_SLOT_COL = 54
local VAULT_EXPAND_TOTAL_COL = 28
local VAULT_EXPAND_SLOTS = 3

local EXPAND_VALUE_COL = 44

local function ExpandVaultReservedWidth()
    return EXPAND_PAD + VAULT_EXPAND_TOTAL_COL + VAULT_EXPAND_SLOTS * VAULT_EXPAND_SLOT_COL
end

local function ExpandVaultSlotRightOffset(slotIndex)
    return EXPAND_PAD + (VAULT_EXPAND_SLOTS - slotIndex) * VAULT_EXPAND_SLOT_COL
end

local function ExpandVaultTotalRightOffset()
    return EXPAND_PAD + VAULT_EXPAND_SLOTS * VAULT_EXPAND_SLOT_COL + VAULT_EXPAND_TOTAL_COL
end

local function AddExpandMutedLine(panel, text)
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SafeSetFont(fs, OneWoW_GUI:GetFont(), 10)
    fs:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, panel.dy)
    fs:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, panel.dy)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panel.dy = panel.dy - EXPAND_LINE_H
end

local function AddExpandLabelValueRow(panel, label, value, color, valueColWidth)
    local valueWidth = valueColWidth or EXPAND_VALUE_COL
    local labelFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SafeSetFont(labelFS, OneWoW_GUI:GetFont(), 10)
    labelFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, panel.dy)
    labelFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(EXPAND_PAD + valueWidth), panel.dy)
    labelFS:SetJustifyH("LEFT")
    labelFS:SetWordWrap(false)
    labelFS:SetText(label)
    labelFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local valueFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SafeSetFont(valueFS, OneWoW_GUI:GetFont(), 10)
    valueFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -EXPAND_PAD, panel.dy)
    valueFS:SetWidth(valueWidth)
    valueFS:SetJustifyH("RIGHT")
    valueFS:SetText(value)
    if color then
        if type(color) == "table" then
            valueFS:SetTextColor(unpack(color))
        else
            valueFS:SetTextColor(color)
        end
    else
        valueFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    panel.dy = panel.dy - EXPAND_LINE_H
end

local function FormatVaultSlotDisplay(act)
    if not act then return "-", false end
    local prog = act.progress or 0
    local thresh = act.threshold or 0
    if thresh <= 0 then return "-", false end
    local met = prog >= thresh
    local itemLevel = act.itemLevel
    if met and itemLevel then
        return "[" .. thresh .. "=" .. itemLevel .. "]", true
    elseif met then
        return "[" .. thresh .. "]", true
    end
    return "[" .. prog .. "/" .. thresh .. "]", false
end

local function AddExpandVaultTrackHeader(panel)
    local headers = {
        {text = "T", offset = ExpandVaultTotalRightOffset(), width = VAULT_EXPAND_TOTAL_COL},
        {text = "1", offset = ExpandVaultSlotRightOffset(1), width = VAULT_EXPAND_SLOT_COL},
        {text = "2", offset = ExpandVaultSlotRightOffset(2), width = VAULT_EXPAND_SLOT_COL},
        {text = "3", offset = ExpandVaultSlotRightOffset(3), width = VAULT_EXPAND_SLOT_COL},
    }
    for _, hdr in ipairs(headers) do
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        OneWoW_GUI:SafeSetFont(fs, OneWoW_GUI:GetFont(), 10)
        fs:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -hdr.offset, panel.dy)
        fs:SetWidth(hdr.width)
        fs:SetJustifyH("CENTER")
        fs:SetText(hdr.text)
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    end
    panel.dy = panel.dy - EXPAND_LINE_H
end

local function AddExpandVaultTrackRow(panel, label, list)
    local reserved = ExpandVaultReservedWidth()
    local labelFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SafeSetFont(labelFS, OneWoW_GUI:GetFont(), 10)
    labelFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, panel.dy)
    labelFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -reserved, panel.dy)
    labelFS:SetJustifyH("LEFT")
    labelFS:SetWordWrap(false)
    labelFS:SetText(label)
    labelFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    if not list or not (list[1] or list[2] or list[3]) then
        local emptyFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        OneWoW_GUI:SafeSetFont(emptyFS, OneWoW_GUI:GetFont(), 10)
        emptyFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -EXPAND_PAD, panel.dy)
        emptyFS:SetWidth(reserved - EXPAND_PAD)
        emptyFS:SetJustifyH("RIGHT")
        emptyFS:SetText("--")
        emptyFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        panel.dy = panel.dy - EXPAND_LINE_H
        return
    end

    local totalFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SafeSetFont(totalFS, OneWoW_GUI:GetFont(), 10)
    totalFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -ExpandVaultTotalRightOffset(), panel.dy)
    totalFS:SetWidth(VAULT_EXPAND_TOTAL_COL)
    totalFS:SetJustifyH("CENTER")
    totalFS:SetText(tostring(GetVaultTrackTotal(list)))
    totalFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    for j = 1, VAULT_EXPAND_SLOTS do
        local text, met = FormatVaultSlotDisplay(list[j])
        local slotFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        OneWoW_GUI:SafeSetFont(slotFS, OneWoW_GUI:GetFont(), 10)
        slotFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -ExpandVaultSlotRightOffset(j), panel.dy)
        slotFS:SetWidth(VAULT_EXPAND_SLOT_COL)
        slotFS:SetJustifyH("CENTER")
        slotFS:SetText(text)
        if met then
            slotFS:SetTextColor(DOT_COLOR_ALL[1], DOT_COLOR_ALL[2], DOT_COLOR_ALL[3], DOT_COLOR_ALL[4] or 1)
        else
            slotFS:SetTextColor(DOT_COLOR_NONE[1], DOT_COLOR_NONE[2], DOT_COLOR_NONE[3], DOT_COLOR_NONE[4] or 1)
        end
    end
    panel.dy = panel.dy - EXPAND_LINE_H
end

local function RaidExpandDiffRightOffset(diffIndex, numDiffs)
    return EXPAND_PAD + (numDiffs - diffIndex) * RAID_EXPAND_DIFF_COL
end

local function AddRaidExpandDifficultyHeader(panel, difficulties)
    local numDiffs = #difficulties
    for i, diff in ipairs(difficulties) do
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        OneWoW_GUI:SafeSetFont(fs, OneWoW_GUI:GetFont(), 10)
        fs:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -RaidExpandDiffRightOffset(i, numDiffs), panel.dy)
        fs:SetWidth(RAID_EXPAND_DIFF_COL)
        fs:SetJustifyH("CENTER")
        fs:SetText(diff.label)
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    end
    panel.dy = panel.dy - EXPAND_LINE_H
end

local function AddRaidExpandBossRow(panel, enc, difficulties)
    local numDiffs = #difficulties
    local nameFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SafeSetFont(nameFS, OneWoW_GUI:GetFont(), 10)
    nameFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, panel.dy)
    nameFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(EXPAND_PAD + numDiffs * RAID_EXPAND_DIFF_COL), panel.dy)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetWordWrap(false)
    nameFS:SetText(enc.name or UNKNOWN)
    nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    for i, diff in ipairs(difficulties) do
        local killed = enc.killed and enc.killed[diff.id]
        local markFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        OneWoW_GUI:SafeSetFont(markFS, OneWoW_GUI:GetFont(), 10)
        markFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -RaidExpandDiffRightOffset(i, numDiffs), panel.dy)
        markFS:SetWidth(RAID_EXPAND_DIFF_COL)
        markFS:SetJustifyH("CENTER")
        if killed then
            markFS:SetText("X")
            markFS:SetTextColor(DOT_COLOR_ALL[1], DOT_COLOR_ALL[2], DOT_COLOR_ALL[3], DOT_COLOR_ALL[4] or 1)
        else
            markFS:SetText("-")
            markFS:SetTextColor(DOT_COLOR_EMPTY[1], DOT_COLOR_EMPTY[2], DOT_COLOR_EMPTY[3], DOT_COLOR_EMPTY[4] or 1)
        end
    end
    panel.dy = panel.dy - EXPAND_LINE_H
end

local function BuildExpandedPanels(ef, endgameData, _, subTabKey)
    local grid = OneWoW_GUI:CreateExpandedPanelGrid(ef)

    if subTabKey == "mythicplus" then
        local p1 = grid:AddPanel(L["PROGRESS_GREAT_VAULT_DETAIL"])
        if endgameData and endgameData.greatVault and endgameData.greatVault.activities then
            local acts = endgameData.greatVault.activities
            VaultTypeStr(grid, p1, acts.raid, RAID)
            VaultTypeStr(grid, p1, acts.dungeon, L["PROGRESS_VAULT_DUNGEON"])
            VaultTypeStr(grid, p1, acts.world, WORLD)
        else
            grid:AddLine(p1, RAID .. ": --", {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
            grid:AddLine(p1, L["PROGRESS_VAULT_DUNGEON"] .. ": --", {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
            grid:AddLine(p1, WORLD .. ": --", {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
        end

        local p2 = grid:AddPanel(L["PROGRESS_MPLUS_SEASON_BEST"])
        if endgameData and endgameData.mythicPlus then
            local mp = endgameData.mythicPlus
            local bestStr = GetBestRunString(endgameData)
            grid:AddLine(p2, L["PROGRESS_BEST_RUN"] .. " " .. bestStr)
            local score = (mp.overallScore and mp.overallScore > 0) and tostring(mp.overallScore) or "--"
            grid:AddLine(p2, L["PROGRESS_SCORE"] .. " " .. score)
            if mp.currentKeystone and mp.currentKeystone.level and mp.currentKeystone.level > 0 then
                local ksName = mp.currentKeystone.mapName or ""
                local ksStr = "+" .. mp.currentKeystone.level
                if ksName ~= "" then ksStr = ksStr .. " " .. ksName end
                grid:AddLine(p2, L["PROGRESS_CURRENT_KEY"] .. " " .. ksStr)
            else
                grid:AddLine(p2, L["PROGRESS_CURRENT_KEY"] .. " --", {OneWoW_GUI:GetThemeColor("TEXT_MUTED")})
            end
        else
            grid:AddLine(p2, L["PROGRESS_BEST_RUN"] .. " --", {OneWoW_GUI:GetThemeColor("TEXT_MUTED")})
            grid:AddLine(p2, L["PROGRESS_SCORE"] .. " --", {OneWoW_GUI:GetThemeColor("TEXT_MUTED")})
            grid:AddLine(p2, L["PROGRESS_CURRENT_KEY"] .. " --", {OneWoW_GUI:GetThemeColor("TEXT_MUTED")})
        end

        local p3 = grid:AddPanel(L["PROGRESS_CURRENCY_TRACKER"])
        local currLines = GetTrackedCurrencyData(endgameData)
        if #currLines > 0 then
            for _, cl in ipairs(currLines) do
                local capPct = (cl.cap and cl.cap > 0) and (cl.qty / cl.cap) or nil
                local color = {OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")}
                if capPct and capPct >= 1 then color = {OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED")}
                elseif capPct and capPct >= 0.7 then color = {OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")}
                end
                grid:AddLine(p3, cl.name .. ": " .. cl.text, color)
            end
        else
            grid:AddLine(p3, "--", {OneWoW_GUI:GetThemeColor("TEXT_MUTED")})
        end

    elseif subTabKey == "raids" then
        for _, raid in ipairs(GetSeasonRaids()) do
            local difficulties = GetRaidDifficulties(raid)
            local raidBlock = endgameData and endgameData.raids and endgameData.raids.bosses and endgameData.raids.bosses[raid.key]
            local total = (raidBlock and raidBlock.numEncounters) or 0
            local bestKilled = 0
            if raidBlock and raidBlock.progress then
                for _, diff in ipairs(difficulties) do
                    local k = raidBlock.progress[diff.id] or 0
                    if k > bestKilled then bestKilled = k end
                end
            end
            local header = RaidDisplayName(raid) .. "  " .. bestKilled .. "/" .. total
            local panel = grid:AddPanel(header)

            AddRaidExpandDifficultyHeader(panel, difficulties)

            if raidBlock and raidBlock.encounters then
                local ordered = {}
                for _, enc in pairs(raidBlock.encounters) do
                    tinsert(ordered, enc)
                end
                sort(ordered, function(a, b)
                    return (a.journalEncounterID or 0) < (b.journalEncounterID or 0)
                end)
                for _, enc in ipairs(ordered) do
                    AddRaidExpandBossRow(panel, enc, difficulties)
                end
            else
                AddExpandMutedLine(panel, L["PROGRESS_RAID_NO_DATA"])
            end
        end

    elseif subTabKey == "weekly" then
        local p1 = grid:AddPanel(L["PROGRESS_GREAT_VAULT_DETAIL"])
        AddExpandVaultTrackHeader(p1)
        if endgameData and endgameData.greatVault and endgameData.greatVault.activities then
            local acts = endgameData.greatVault.activities
            AddExpandVaultTrackRow(p1, RAID, acts.raid)
            AddExpandVaultTrackRow(p1, L["PROGRESS_VAULT_DUNGEON"], acts.dungeon)
            AddExpandVaultTrackRow(p1, WORLD, acts.world)
        else
            AddExpandVaultTrackRow(p1, RAID, nil)
            AddExpandVaultTrackRow(p1, L["PROGRESS_VAULT_DUNGEON"], nil)
            AddExpandVaultTrackRow(p1, WORLD, nil)
        end

        local resetSec = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if resetSec and resetSec > 0 then
            local days = math.floor(resetSec / 86400)
            local hours = math.floor((resetSec % 86400) / 3600)
            local mins = math.floor((resetSec % 3600) / 60)
            local resetStr = string.format("%dd %dh %dm", days, hours, mins)
            grid:AddLine(p1, (L["PROGRESS_WEEKLY_RESET"]) .. " " .. resetStr, {OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")})
        end

        local p2 = grid:AddPanel(L["PROGRESS_WEEKLY_ACTIVITIES"])
        local activities = GetWeeklyActivitiesList()
        if #activities > 0 then
            for _, entry in ipairs(activities) do
                local done = GetWeeklyActivityCompleted(endgameData, entry.key)
                local label = GetWeeklyActivityLabel(entry)
                local value = done and DONE or L["PROGRESS_WEEKLY_NOT_DONE"]
                local color = done
                    and {OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED")}
                    or  {OneWoW_GUI:GetThemeColor("TEXT_MUTED")}
                AddExpandLabelValueRow(p2, label, value, color)
            end
        else
            AddExpandMutedLine(p2, "--")
        end
        local bossKilled, bossName = GetWorldBossKilled(endgameData)
        if bossKilled then
            AddExpandLabelValueRow(p2, L["TT_COL_WORLD_BOSS"], bossName or L["PROGRESS_BOSS_KILLED"], {OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED")}, 120)
        else
            AddExpandLabelValueRow(p2, L["TT_COL_WORLD_BOSS"], NONE, {OneWoW_GUI:GetThemeColor("TEXT_MUTED")})
        end

    elseif subTabKey == "currencies" then
        local p1 = grid:AddPanel(L["PROGRESS_CURRENCY_TRACKER"])
        local currLines = GetTrackedCurrencyData(endgameData)
        if #currLines > 0 then
            for _, cl in ipairs(currLines) do
                local capPct = (cl.cap and cl.cap > 0) and (cl.qty / cl.cap) or nil
                local color = {OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")}
                if capPct and capPct >= 1 then color = {OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED")}
                elseif capPct and capPct >= 0.7 then color = {OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")}
                end
                grid:AddLine(p1, cl.name .. ": " .. cl.text, color)
            end
        else
            grid:AddLine(p1, "--", {OneWoW_GUI:GetThemeColor("TEXT_MUTED")})
        end

        local p2 = grid:AddPanel(L["PROGRESS_GREAT_VAULT_DETAIL"])
        if endgameData and endgameData.greatVault and endgameData.greatVault.activities then
            local acts = endgameData.greatVault.activities
            VaultTypeStr(grid, p2, acts.raid, RAID)
            VaultTypeStr(grid, p2, acts.dungeon, L["PROGRESS_VAULT_DUNGEON"])
            VaultTypeStr(grid, p2, acts.world, WORLD)
        else
            grid:AddLine(p2, RAID .. ": --", {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
            grid:AddLine(p2, L["PROGRESS_VAULT_DUNGEON"] .. ": --", {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
            grid:AddLine(p2, WORLD .. ": --", {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
        end
    end

    grid:Finish()
end

local function RefreshSubTabContent(contentFrame, subTabKey, progressTab, buildCellsFunc, buildTooltipFunc)
    local state = subTabState[subTabKey]
    local scrollContent = contentFrame.scrollContent
    if not scrollContent then return end

    OneWoW_GUI:ClearDataRows(scrollContent)
    wipe(state.rows)

    local dt = contentFrame.dataTable
    if dt then dt:ClearRows() end

    local allChars = GetSortedCharacters(subTabKey)
    if #allChars == 0 then return end

    UpdateCharServerMinWidths(contentFrame, allChars)
    if contentFrame.UpdateColumnLayout then
        contentFrame.UpdateColumnLayout()
    end

    local rowHeight = 32
    local rowGap = 2
    local columnsConfig = state.columns

    for _, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local charData = charInfo.data
        local endgameData = OneWoW_AltTracker_Endgame_API and OneWoW_AltTracker_Endgame_API.GetCharacterData(charKey)

        local charRow = OneWoW_GUI:CreateDataRow(scrollContent, {
            rowHeight = rowHeight,
            expandedHeight = 160,
            rowGap = rowGap,
            data = { charKey = charKey, charData = charData, endgameData = endgameData, subTabKey = subTabKey },
            createDetails = function(ef, d)
                BuildExpandedPanels(ef, d.endgameData, d.charData, d.subTabKey)
                OneWoW_GUI:ApplyFontToFrame(ef)
            end,
            onEnter = function(self)
                if buildTooltipFunc then
                    buildTooltipFunc(self, endgameData, charData, charKey, contentFrame)
                end
            end,
            onLeave = function()
                GameTooltip:Hide()
            end,
        })
        charRow.charKey = charKey

        CreateCommonCells(charRow, charData, charKey, endgameData, rowHeight)

        buildCellsFunc(charRow, charData, charKey, endgameData, progressTab)

        local hdrRow = contentFrame.headerRow
        if hdrRow and hdrRow.columnButtons then
            for i, cell in ipairs(charRow.cells) do
                local btn = hdrRow.columnButtons[i]
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
                    else
                        cell:SetWidth(width - 6)
                        cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
                    end
                end
            end
        end

        table.insert(state.rows, charRow)
        if dt then dt:RegisterRow(charRow) end
    end

    OneWoW_GUI:LayoutDataRows(scrollContent, { rowHeight = rowHeight, rowGap = rowGap })

    -- First-open hint: auto-expand row 1 the first time each sub-tab renders
    -- rows in the current session so users discover the per-character expand
    -- panel. Per-session and per-sub-tab; the flag lives on the sub-tab state
    -- (resets on /reload). User-initiated collapse/expand is preserved on
    -- subsequent refreshes.
    if not state._didInitialExpand and state.rows[1] then
        state.rows[1]:Expand()
        state._didInitialExpand = true
    end

    if progressTab and progressTab.statusText then
        progressTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], #allChars, ""))
    end

    OneWoW_GUI:ApplyFontToFrame(contentFrame)
end

local function BuildCommonColumns()
    return {
        {key = "expand",  label = "",                  width = 25,  fixed = true,  align = "icon",   sortable = false, ttTitle = L["TT_COL_EXPAND"],    ttDesc = L["TT_COL_EXPAND_DESC"]},
        {key = "star",    label = "",                  width = 30,  fixed = true,  align = "icon",   sortable = false, ttTitle = L["TT_COL_STAR"],      ttDesc = L["TT_COL_STAR_DESC"]},
        {key = "faction", label = "F",                 width = 25,  fixed = true,  align = "center", sortable = false, ttTitle = FACTION,   ttDesc = L["TT_COL_FACTION_DESC"]},
        {key = "mail",    label = "",                  width = 35,  fixed = true,  align = "center", sortable = false, ttTitle = L["MAIL"],      ttDesc = L["TT_COL_MAIL_DESC"]},
        {key = "name",    label = CHARACTER,  width = 135, minWidth = 135, flexWeight = 4, align = "left",                  ttTitle = CHARACTER, ttDesc = L["TT_COL_CHARACTER_DESC"]},
        {key = "server",  label = L["COL_SERVER"],     width = 50,  minWidth = 50,  flexWeight = 3, align = "left",                  ttTitle = L["COL_SERVER"],    ttDesc = L["TT_COL_SERVER_DESC"]},
        {key = "level",   label = L["COL_LEVEL"],      width = 40,  minWidth = 40,  flexWeight = 1, align = "center",                ttTitle = LEVEL,     ttDesc = L["TT_COL_LEVEL_DESC"]},
        {key = "ilvl",    label = L["COL_ITEM_LEVEL"], width = 55, minWidth = 55, flexWeight = 1, align = "center",              ttTitle = L["TT_COL_ILVL"],      ttDesc = L["TT_COL_ILVL_DESC"]},
        {key = "rating",  label = RATING, width = 50, minWidth = 50, flexWeight = 1, align = "center",            ttTitle = RATING,    ttDesc = L["TT_COL_RATING_DESC"]},
    }
end

local function CreateMythicPlusColumns()
    local cols = BuildCommonColumns()
    table.insert(cols, {key = "bestTime", label = L["PROGRESS_COL_BEST_RUN"], width = 55, minWidth = 55, flexWeight = 1, align = "left", ttTitle = L["TT_COL_BEST_TIME"], ttDesc = L["TT_COL_BEST_TIME_DESC"]})
    table.insert(cols, {key = "keystone", label = L["PROGRESS_COL_KEYSTONE"],               width = 65, minWidth = 65, flexWeight = 1, align = "left", ttTitle = L["TT_COL_KEYSTONE"],  ttDesc = L["TT_COL_KEYSTONE_DESC"]})
    for _, dung in ipairs(GetSeasonDungeons()) do
        table.insert(cols, {
            key        = dung.key,
            label      = dung.short,
            width      = 40,
            minWidth   = 40,
            flexWeight = 1,
            align      = "center",
            ttTitle    = dung.name,
            ttDesc     = dung.name,
            dungData   = dung,
        })
    end
    return cols
end

local function GetRaidProgressSummary(endgameData, raidKey)
    if not endgameData or not endgameData.raids or not endgameData.raids.bosses then
        return nil
    end
    return endgameData.raids.bosses[raidKey]
end

local function CreateRaidsColumns()
    local cols = BuildCommonColumns()
    for _, raid in ipairs(GetSeasonRaids()) do
        table.insert(cols, {
            key        = "raid_" .. raid.key,
            label      = raid.short or raid.label,
            width      = 80,
            minWidth   = 80,
            flexWeight = 1,
            align      = "center",
            ttTitle    = RaidDisplayName(raid),
            ttDesc     = RaidDisplayName(raid),
            raidData   = raid,
        })
    end
    return cols
end

local function CreateRaidDotCell(parent, raidBlock, difficulties)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetSize(80, 18)
    cell.dots = {}
    local dotSize = 10
    local spacing = 4
    local total = (raidBlock and raidBlock.numEncounters) or 0
    local numDiffs = #difficulties
    local totalWidth = numDiffs * dotSize + (numDiffs - 1) * spacing
    local startX = -totalWidth / 2
    for i, diff in ipairs(difficulties) do
        local dot = cell:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(DOT_TEXTURE)
        dot:SetSize(dotSize, dotSize)
        dot:SetPoint("CENTER", cell, "CENTER", startX + (i - 1) * (dotSize + spacing) + dotSize / 2, 0)
        local color = DOT_COLOR_EMPTY
        if raidBlock and raidBlock.progress and total > 0 then
            local killed = raidBlock.progress[diff.id] or 0
            if killed >= total then color = DOT_COLOR_ALL
            elseif killed > 0 then color = DOT_COLOR_SOME
            else color = DOT_COLOR_NONE end
        end
        dot:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        cell.dots[i] = dot
    end
    return cell
end

local function GetVaultActivities(endgameData, vaultType)
    if not endgameData or not endgameData.greatVault or not endgameData.greatVault.activities then
        return nil
    end
    return endgameData.greatVault.activities[vaultType]
end

local function CreateVaultTrackCell(parent, list)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetSize(110, 18)

    local total = GetVaultTrackTotal(list)
    local tPrefix = (L["PROGRESS_VAULT_TOTAL"]) .. total
    local tText = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tText:SetPoint("LEFT", cell, "LEFT", 2, 0)
    tText:SetText(tPrefix)
    tText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local boxWidth, boxHeight = 22, 14
    local spacing = 2
    local startX = 36
    for i = 1, 3 do
        local act = list and list[i]
        local thresh = act and (act.threshold or 0) or 0
        local prog = act and (act.progress or 0) or 0
        local itemLevel = act and act.itemLevel
        local met = thresh > 0 and prog >= thresh

        local box = CreateFrame("Frame", nil, cell)
        box:SetSize(boxWidth, boxHeight)
        box:SetPoint("LEFT", cell, "LEFT", startX + (i - 1) * (boxWidth + spacing), 0)

        local bg = box:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(DOT_TEXTURE)
        if thresh <= 0 then
            bg:SetVertexColor(0.15, 0.15, 0.15, 0.85)
        elseif met then
            bg:SetVertexColor(BOX_COLOR_MET[1], BOX_COLOR_MET[2], BOX_COLOR_MET[3], BOX_COLOR_MET[4])
        else
            bg:SetVertexColor(BOX_COLOR_UNMET[1], BOX_COLOR_UNMET[2], BOX_COLOR_UNMET[3], BOX_COLOR_UNMET[4])
        end

        local label = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER")
        if thresh <= 0 then
            label:SetText("-")
        elseif met and itemLevel then
            label:SetText(tostring(itemLevel))
        else
            label:SetText(tostring(thresh))
        end
        label:SetTextColor(1, 1, 1)
    end

    return cell
end

local function CreateWeeklyColumns()
    local cols = BuildCommonColumns()
    table.insert(cols, {key = "vaultRaid",    label = L["PROGRESS_COL_VAULT_R"], width = 115, minWidth = 115, flexWeight = 1, align = "left", ttTitle = RAID,    ttDesc = L["TT_COL_VAULT_R_DESC"]})
    table.insert(cols, {key = "vaultDungeon", label = L["PROGRESS_COL_VAULT_D"], width = 115, minWidth = 115, flexWeight = 1, align = "left", ttTitle = L["PROGRESS_VAULT_DUNGEON"], ttDesc = L["TT_COL_VAULT_D_DESC"]})
    table.insert(cols, {key = "vaultWorld",   label = L["PROGRESS_COL_VAULT_W"], width = 115, minWidth = 115, flexWeight = 1, align = "left", ttTitle = WORLD,   ttDesc = L["TT_COL_VAULT_W_DESC"]})
    table.insert(cols, {key = "worldBoss",    label = L["PROGRESS_COL_WORLD_BOSS"], width = 65, minWidth = 65, flexWeight = 1, align = "left", ttTitle = L["TT_COL_WORLD_BOSS"], ttDesc = L["TT_COL_WORLD_BOSS_DESC"]})
    for _, entry in ipairs(GetWeeklyActivitiesList()) do
        local fullName = GetWeeklyActivityLabel(entry)
        local label = ns.ShortNames:GetShortName(fullName, 8)
        table.insert(cols, {
            key          = "wa_" .. entry.key,
            label        = label,
            width        = 70,
            minWidth     = 70,
            flexWeight   = 1,
            align        = "center",
            ttTitle      = fullName,
            ttDesc       = fullName,
            activityData = entry,
        })
    end
    return cols
end

local function CreateCurrenciesColumns()
    local cols = BuildCommonColumns()
    for _, cur in ipairs(GetCurrencyColumnDefs()) do
        table.insert(cols, {
            key          = cur.key,
            label        = "",
            width        = cur.width,
            minWidth     = cur.width,
            flexWeight   = 1,
            align        = "center",
            ttTitle      = cur.name,
            ttDesc       = cur.name,
            currencyData = cur,
        })
    end
    return cols
end

--- Rebuild Currencies headers and rows after Override on/off or add/remove.
function ns.UI.NotifyTrackedCurrenciesChanged()
    local progressTab = ns.UI.progressTabFrame
    if not progressTab then return end

    local newCols = CreateCurrenciesColumns()
    local state = subTabState.currencies
    state.columns = newCols
    local sortCol = state.sortColumn
    if sortCol and sortCol:sub(1, 4) == "cur_" then
        local found = false
        for i = 1, #newCols do
            if newCols[i].key == sortCol then
                found = true
                break
            end
        end
        if not found then
            state.sortColumn = nil
        end
    end

    local frame = progressTab.subTabFrames and progressTab.subTabFrames.currencies
    if frame and frame.dataTable then
        frame.dataTable:SetColumns(newCols)
        if not state.sortColumn then
            frame.dataTable:SetSortState(nil, true)
        end
        if currentSubTab == "currencies" and frame.refreshFunc then
            frame.refreshFunc(frame)
        end
    end
    ns.UI.RefreshTrackingBar(progressTab)
end

local function BuildMythicPlusCells(charRow, _, _, endgameData, _)
    local bestTimeText = OneWoW_GUI:CreateFS(charRow, 12)
    bestTimeText:SetText(GetBestRunString(endgameData))
    bestTimeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    bestTimeText:SetJustifyH("LEFT")
    table.insert(charRow.cells, bestTimeText)

    local keystoneText = OneWoW_GUI:CreateFS(charRow, 12)
    local keystoneLevel = (endgameData and endgameData.mythicPlus and endgameData.mythicPlus.currentKeystone and endgameData.mythicPlus.currentKeystone.level) or 0
    local keystoneName = (endgameData and endgameData.mythicPlus and endgameData.mythicPlus.currentKeystone and endgameData.mythicPlus.currentKeystone.mapName) or ""
    if keystoneLevel > 0 and keystoneName ~= "" then
        keystoneText:SetText("+" .. keystoneLevel .. " " .. ns.ShortNames:GetShortName(keystoneName, 10))
    elseif keystoneLevel > 0 then
        keystoneText:SetText("+" .. keystoneLevel)
    else
        keystoneText:SetText("--")
    end
    keystoneText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    keystoneText:SetJustifyH("LEFT")
    table.insert(charRow.cells, keystoneText)

    for _, dung in ipairs(GetSeasonDungeons()) do
        local dungText = OneWoW_GUI:CreateFS(charRow, 12)
        local dungLevel = nil
        if dung.mapID and dung.mapID > 0 and endgameData and endgameData.mythicPlus and endgameData.mythicPlus.seasonBest then
            local best = endgameData.mythicPlus.seasonBest[dung.mapID]
            if best and best.intime then dungLevel = best.intime.level end
        end
        dungText:SetText(dungLevel and ("+" .. dungLevel) or "--")
        dungText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        dungText:SetJustifyH("CENTER")
        table.insert(charRow.cells, dungText)
    end
end

local function BuildMythicPlusTooltip(self, edg, chd, chk, contentFrame)
    local cols = subTabState["mythicplus"].columns
    local colKey = GetHoveredColumnKey(self, cols, contentFrame)
    if not colKey or colKey == "expand" or colKey == "faction" or colKey == "mail" or colKey == "star" then
        GameTooltip:Hide()
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if colKey == "name" then
        GameTooltip:SetText(chd.name or chk, 1, 1, 1)
        if chd.class then GameTooltip:AddLine(chd.class, 1, 1, 1) end
        if chd.guild and chd.guild.name then GameTooltip:AddLine("<" .. chd.guild.name .. ">", 0.8, 0.8, 0.8) end
    elseif colKey == "level" then
        GameTooltip:SetText(L["COL_LEVEL"], 1, 1, 1)
        GameTooltip:AddLine(tostring(chd.level or 0), 0.9, 0.9, 0.9)
    elseif colKey == "ilvl" then
        GameTooltip:SetText(L["TT_COL_ILVL"], 1, 1, 1)
        GameTooltip:AddLine(tostring(chd.itemLevel or 0), 0.9, 0.9, 0.9)
    elseif colKey == "rating" then
        GameTooltip:SetText(RATING, 1, 1, 1)
        GameTooltip:AddLine(tostring((edg and edg.mythicPlus and edg.mythicPlus.overallScore) or 0), 0.9, 0.9, 0.9)
    elseif colKey == "bestTime" then
        GameTooltip:SetText(L["TT_COL_BEST_TIME"], 1, 1, 1)
        local full = GetBestRunFullString(edg)
        if full then GameTooltip:AddLine(full, 1, 1, 0) end
        if edg and edg.mythicPlus and edg.mythicPlus.seasonBest then
            local entries = {}
            for mapID, mapInfo in pairs(edg.mythicPlus.seasonBest) do
                if mapInfo.intime then
                    local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
                    table.insert(entries, {level = mapInfo.intime.level, name = mapName or "?"})
                end
            end
            table.sort(entries, function(a, b) return a.level > b.level end)
            if #entries > 0 then GameTooltip:AddLine(" ") end
            for j = 1, math.min(8, #entries) do
                GameTooltip:AddLine("+" .. entries[j].level .. " " .. entries[j].name, 0.8, 0.8, 0.8)
            end
        end
    elseif colKey == "keystone" then
        GameTooltip:SetText(L["TT_COL_KEYSTONE"], 1, 1, 1)
        if edg and edg.mythicPlus and edg.mythicPlus.currentKeystone then
            local ks = edg.mythicPlus.currentKeystone
            if (ks.level or 0) > 0 then
                GameTooltip:AddLine(L["PROGRESS_CURRENT_KEY"] .. " +" .. ks.level .. " " .. (ks.mapName or ""), 1, 1, 0)
            else
                GameTooltip:AddLine(L["PROGRESS_CURRENT_KEY"] .. " --", 0.5, 0.5, 0.5)
            end
        end
        local mapTable = C_ChallengeMode.GetMapTable()
        if mapTable and edg then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["PROGRESS_MPLUS_SEASON_BEST"], OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            local seasonBest = (edg.mythicPlus and edg.mythicPlus.seasonBest) or {}
            for _, mapID in ipairs(mapTable) do
                local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
                if mapName then
                    local bestData = seasonBest[mapID]
                    if bestData and bestData.intime then
                        local level = bestData.intime.level or 0
                        local hasOvertime = bestData.overtime ~= nil
                        local suffix = hasOvertime and " *" or ""
                        GameTooltip:AddLine("  " .. mapName .. ": +" .. level .. suffix, 0.2, 0.9, 0.2)
                    else
                        GameTooltip:AddLine("  " .. mapName .. ": --", 0.5, 0.5, 0.5)
                    end
                end
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("* overtime (not timed)", 0.6, 0.6, 0.6)
        end
    else
        for _, dung in ipairs(GetSeasonDungeons()) do
            if dung.key == colKey then
                GameTooltip:SetText(dung.name, 1, 1, 1)
                local dungLevel = nil
                if dung.mapID and dung.mapID > 0 and edg and edg.mythicPlus and edg.mythicPlus.seasonBest then
                    local best = edg.mythicPlus.seasonBest[dung.mapID]
                    if best and best.intime then dungLevel = best.intime.level end
                end
                if dungLevel then
                    GameTooltip:AddLine("Best: +" .. dungLevel, 0.2, 0.9, 0.2)
                else
                    GameTooltip:AddLine("Best: --", 0.5, 0.5, 0.5)
                end
                break
            end
        end
    end
    GameTooltip:Show()
end

local function BuildRaidsCells(charRow, _, _, endgameData, _)
    for _, raid in ipairs(GetSeasonRaids()) do
        local difficulties = GetRaidDifficulties(raid)
        local raidBlock = GetRaidProgressSummary(endgameData, raid.key)
        local cell = CreateRaidDotCell(charRow, raidBlock, difficulties)
        table.insert(charRow.cells, cell)
    end
end

local function BuildRaidsTooltip(self, edg, chd, chk, contentFrame)
    local cols = subTabState["raids"].columns
    local colKey = GetHoveredColumnKey(self, cols, contentFrame)
    if not colKey or colKey == "expand" or colKey == "star" or colKey == "faction" or colKey == "mail" then
        GameTooltip:Hide()
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if colKey == "name" then
        GameTooltip:SetText(chd.name or chk, 1, 1, 1)
        if chd.class then GameTooltip:AddLine(chd.class, 1, 1, 1) end
        if chd.guild and chd.guild.name then GameTooltip:AddLine("<" .. chd.guild.name .. ">", 0.8, 0.8, 0.8) end
    elseif colKey == "rating" then
        GameTooltip:SetText(RATING, 1, 1, 1)
        GameTooltip:AddLine(tostring((edg and edg.mythicPlus and edg.mythicPlus.overallScore) or 0), 0.9, 0.9, 0.9)
    elseif colKey == "ilvl" then
        GameTooltip:SetText(L["TT_COL_ILVL"], 1, 1, 1)
        GameTooltip:AddLine(tostring(chd.itemLevel or 0), 0.9, 0.9, 0.9)
    elseif colKey == "level" then
        GameTooltip:SetText(L["COL_LEVEL"], 1, 1, 1)
        GameTooltip:AddLine(tostring(chd.level or 0), 0.9, 0.9, 0.9)
    elseif colKey:sub(1, 5) == "raid_" then
        local raidKey = colKey:sub(6)
        local raidEntry
        for _, r in ipairs(GetSeasonRaids()) do
            if r.key == raidKey then raidEntry = r; break end
        end
        if raidEntry then
            GameTooltip:SetText(RaidDisplayName(raidEntry), 1, 1, 1)
            local raidBlock = GetRaidProgressSummary(edg, raidKey)
            local total = raidBlock and raidBlock.numEncounters or 0
            GameTooltip:AddLine(total .. " bosses", 0.7, 0.7, 0.7)
            GameTooltip:AddLine(" ")
            local difficulties = GetRaidDifficulties(raidEntry)
            for _, diff in ipairs(difficulties) do
                local killed = (raidBlock and raidBlock.progress and raidBlock.progress[diff.id]) or 0
                local line = DifficultyDisplayName(diff) .. ": " .. killed .. "/" .. total
                if total > 0 and killed >= total then
                    GameTooltip:AddLine(line, 0.2, 0.9, 0.2)
                elseif killed > 0 then
                    GameTooltip:AddLine(line, 0.94, 0.78, 0.20)
                else
                    GameTooltip:AddLine(line, 0.5, 0.5, 0.5)
                end
            end
        else
            GameTooltip:SetText(colKey, 1, 1, 1)
        end
    else
        GameTooltip:SetText(colKey, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function BuildCurrenciesCells(charRow, _, _, endgameData, _)
    for _, cur in ipairs(GetCurrencyColumnDefs()) do
        local curText = OneWoW_GUI:CreateFS(charRow, 12)
        local qty = 0
        local maxQty = 0
        if endgameData and endgameData.currencies and endgameData.currencies.tracked then
            local cData = endgameData.currencies.tracked[cur.currencyID]
            if cData then
                qty = cData.quantity or 0
                maxQty = cData.maxQuantity or 0
            end
        end
        if qty > 0 then
            curText:SetText(tostring(qty))
            if maxQty > 0 and qty >= maxQty then
                curText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                curText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        else
            curText:SetText("--")
            curText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
        curText:SetJustifyH("CENTER")
        table.insert(charRow.cells, curText)
    end
end

local function BuildCurrenciesTooltip(self, edg, chd, chk, contentFrame)
    local cols = subTabState["currencies"].columns
    local colKey = GetHoveredColumnKey(self, cols, contentFrame)
    if not colKey or colKey == "expand" or colKey == "star" or colKey == "faction" or colKey == "mail" then
        GameTooltip:Hide()
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if colKey == "name" then
        GameTooltip:SetText(chd.name or chk, 1, 1, 1)
        if chd.class then GameTooltip:AddLine(chd.class, 1, 1, 1) end
        if chd.guild and chd.guild.name then GameTooltip:AddLine("<" .. chd.guild.name .. ">", 0.8, 0.8, 0.8) end
    elseif colKey:sub(1, 4) == "cur_" then
        local cid = tonumber(colKey:sub(5))
        local curName = cid and CurrencyDisplayName(cid) or colKey
        GameTooltip:SetText(curName, 1, 1, 1)
        if edg and edg.currencies and edg.currencies.tracked then
            local cData = edg.currencies.tracked[cid]
            if cData then
                local qty = cData.quantity or 0
                local maxQty = cData.maxQuantity or 0
                local weeklyEarned = cData.quantityEarnedThisWeek
                local weeklyCap = cData.maxWeeklyQuantity
                GameTooltip:AddLine("Total: " .. qty, 0.9, 0.9, 0.9)
                if maxQty > 0 then
                    GameTooltip:AddLine("Cap: " .. maxQty, 0.8, 0.8, 0.8)
                end
                if weeklyCap and weeklyCap > 0 then
                    GameTooltip:AddLine("Weekly: " .. (weeklyEarned or 0) .. "/" .. weeklyCap, 0.8, 0.8, 0.8)
                end
            else
                GameTooltip:AddLine("--", 0.5, 0.5, 0.5)
            end
        else
            GameTooltip:AddLine("--", 0.5, 0.5, 0.5)
        end
    else
        GameTooltip:SetText(colKey, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function BuildWeeklyCells(charRow, _, _, endgameData, _)
    local vaultRaidCell = CreateVaultTrackCell(charRow, GetVaultActivities(endgameData, "raid"))
    table.insert(charRow.cells, vaultRaidCell)

    local vaultDungeonCell = CreateVaultTrackCell(charRow, GetVaultActivities(endgameData, "dungeon"))
    table.insert(charRow.cells, vaultDungeonCell)

    local vaultWorldCell = CreateVaultTrackCell(charRow, GetVaultActivities(endgameData, "world"))
    table.insert(charRow.cells, vaultWorldCell)

    local worldBossText = OneWoW_GUI:CreateFS(charRow, 10)
    local wbKilled, wbName = GetWorldBossKilled(endgameData)
    if wbKilled then
        worldBossText:SetText(ns.ShortNames:GetShortName(wbName or L["PROGRESS_BOSS_KILLED"], 9))
        worldBossText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        worldBossText:SetText("--")
        worldBossText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
    worldBossText:SetJustifyH("LEFT")
    table.insert(charRow.cells, worldBossText)

    for _, entry in ipairs(GetWeeklyActivitiesList()) do
        local cellText = OneWoW_GUI:CreateFS(charRow, 12)
        local done = GetWeeklyActivityCompleted(endgameData, entry.key)
        cellText:SetText(done and "1/1" or "0/1")
        if done then
            cellText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            cellText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
        cellText:SetJustifyH("CENTER")
        table.insert(charRow.cells, cellText)
    end
end

local function BuildWeeklyTooltip(self, edg, chd, chk, contentFrame)
    local cols = subTabState["weekly"].columns
    local colKey = GetHoveredColumnKey(self, cols, contentFrame)
    if not colKey or colKey == "expand" or colKey == "star" or colKey == "faction" or colKey == "mail" then
        GameTooltip:Hide()
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if colKey == "name" then
        GameTooltip:SetText(chd.name or chk, 1, 1, 1)
        if chd.class then GameTooltip:AddLine(chd.class, 1, 1, 1) end
        if chd.guild and chd.guild.name then GameTooltip:AddLine("<" .. chd.guild.name .. ">", 0.8, 0.8, 0.8) end
    elseif colKey == "worldBoss" then
        GameTooltip:SetText(L["TT_COL_WORLD_BOSS"], 1, 1, 1)
        local killed, bossName = GetWorldBossKilled(edg)
        if killed then
            GameTooltip:AddLine(L["PROGRESS_BOSS_KILLED"] .. ": " .. (bossName or ""), 0.2, 0.9, 0.2)
        else
            GameTooltip:AddLine(NONE, 0.5, 0.5, 0.5)
        end
    elseif colKey == "vaultRaid" or colKey == "vaultDungeon" or colKey == "vaultWorld" then
        local vaultType = (colKey == "vaultRaid" and "raid") or (colKey == "vaultDungeon" and "dungeon") or "world"
        local headerL = (vaultType == "raid" and RAID) or (vaultType == "dungeon" and L["PROGRESS_VAULT_DUNGEON"]) or WORLD
        GameTooltip:SetText(headerL, 1, 1, 1)
        local list = GetVaultActivities(edg, vaultType)
        if list and (list[1] or list[2] or list[3]) then
            local total = GetVaultTrackTotal(list)
            GameTooltip:AddLine((L["PROGRESS_VAULT_TOTAL"]) .. total, 0.9, 0.9, 0.9)
            GameTooltip:AddLine(" ")

            local unlockVerb
            if vaultType == "raid" then
                unlockVerb = "Defeat %d raid bosses this week to unlock this reward."
            elseif vaultType == "dungeon" then
                unlockVerb = "Complete %d dungeons this week to unlock this reward."
            else
                unlockVerb = "Complete %d world activities this week to unlock this reward."
            end

            for j = 1, 3 do
                local act = list[j]
                if act then
                    local prog = act.progress or 0
                    local thresh = act.threshold or 0
                    local met = thresh > 0 and prog >= thresh
                    local itemLevel = act.itemLevel
                    local upgradeItemLevel = act.upgradeItemLevel

                    if met then
                        local header = string.format("Slot %d - Unlocked", j)
                        GameTooltip:AddLine(header, 0.20, 0.90, 0.20)
                        if vaultType == "world" and act.level and act.level > 0 then
                            if itemLevel then
                                GameTooltip:AddLine(string.format("  Item Level %d  (Tier %d)", itemLevel, act.level), 1, 1, 1)
                            else
                                GameTooltip:AddLine(string.format("  Tier %d", act.level), 1, 1, 1)
                            end
                        elseif itemLevel then
                            GameTooltip:AddLine(string.format("  Item Level %d", itemLevel), 1, 1, 1)
                        end
                        if upgradeItemLevel and itemLevel and upgradeItemLevel > itemLevel then
                            GameTooltip:AddLine(string.format("  Upgrades to Item Level %d", upgradeItemLevel), 0.60, 0.85, 1.00)
                        elseif itemLevel then
                            GameTooltip:AddLine("  Reward at Highest Item Level", 0.20, 0.90, 0.20)
                        end
                    else
                        local header = string.format("Slot %d - %d/%d", j, prog, thresh)
                        GameTooltip:AddLine(header, 0.80, 0.30, 0.30)
                        if thresh > 0 then
                            local remaining = thresh - prog
                            GameTooltip:AddLine(string.format("  " .. unlockVerb, thresh), 0.85, 0.85, 0.85)
                            if remaining > 0 then
                                GameTooltip:AddLine(string.format("  %d more to unlock", remaining), 1, 0.82, 0)
                            end
                        end
                        if itemLevel then
                            GameTooltip:AddLine(string.format("  Preview reward: Item Level %d", itemLevel), 0.55, 0.55, 0.55)
                        end
                    end

                    if j < 3 and list[j + 1] then
                        GameTooltip:AddLine(" ")
                    end
                end
            end
        else
            GameTooltip:AddLine("No vault data yet - log in to scan.", 0.5, 0.5, 0.5)
        end
    elseif colKey:sub(1, 3) == "wa_" then
        local activityKey = colKey:sub(4)
        local entry
        for _, e in ipairs(GetWeeklyActivitiesList()) do
            if e.key == activityKey then entry = e; break end
        end
        local label = entry and GetWeeklyActivityLabel(entry) or activityKey
        GameTooltip:SetText(label, 1, 1, 1)
        local completed = GetWeeklyActivityCompleted(edg, activityKey)
        if completed then
            GameTooltip:AddLine(DONE, 0.2, 0.9, 0.2)
        else
            GameTooltip:AddLine(L["PROGRESS_WEEKLY_NOT_DONE"], 0.5, 0.5, 0.5)
        end
        local ids = entry and (entry.questIDs or (entry.questID and { entry.questID }))
        if ids and #ids > 0 then
            GameTooltip:AddLine("Quest ID: " .. table.concat(ids, ", "), 0.6, 0.6, 0.6)
        end
    elseif colKey == "rating" then
        GameTooltip:SetText(RATING, 1, 1, 1)
        GameTooltip:AddLine(tostring((edg and edg.mythicPlus and edg.mythicPlus.overallScore) or 0), 0.9, 0.9, 0.9)
    elseif colKey == "ilvl" then
        GameTooltip:SetText(L["TT_COL_ILVL"], 1, 1, 1)
        GameTooltip:AddLine(tostring(chd.itemLevel or 0), 0.9, 0.9, 0.9)
    elseif colKey == "level" then
        GameTooltip:SetText(L["COL_LEVEL"], 1, 1, 1)
        GameTooltip:AddLine(tostring(chd.level or 0), 0.9, 0.9, 0.9)
    else
        GameTooltip:SetText(colKey, 1, 1, 1)
    end
    GameTooltip:Show()
end

function ns.UI.CreateProgressTab(parent)
    local overview = OneWoW_GUI:CreateOverviewPanel(parent, {
        height = 70,
        columns = 7,
        stats = {
            {label = L["CHARACTERS"],   value = "0", ttTitle = L["CHARACTERS"],   ttDesc = L["TT_PROGRESS_CHARACTERS_DESC"]},
            {label = L["PROGRESS_KEYS"],         value = "0", ttTitle = L["PROGRESS_KEYS"],         ttDesc = L["TT_PROGRESS_KEYS_DESC"]},
            {label = L["PROGRESS_VAULT"],        value = "0", ttTitle = L["PROGRESS_VAULT"],        ttDesc = L["TT_PROGRESS_VAULT_DESC"]},
            {label = L["PROGRESS_HIGHEST_KEY"],  value = "0", ttTitle = L["TT_PROGRESS_HIGHEST_KEY"],  ttDesc = L["TT_PROGRESS_HIGHEST_KEY_DESC"]},
            {label = L["PROGRESS_AVG_RATING"],   value = "0", ttTitle = L["PROGRESS_AVG_RATING"],   ttDesc = L["TT_PROGRESS_AVG_RATING_DESC"]},
            {label = L["PROGRESS_AVG_ILVL"],     value = "0", ttTitle = L["TT_PROGRESS_AVG_ILVL"],     ttDesc = L["TT_PROGRESS_AVG_ILVL_DESC"]},
            {label = L["PROGRESS_WORLD_BOSSES"], value = "0", ttTitle = L["TT_PROGRESS_WORLD_BOSSES"], ttDesc = L["TT_PROGRESS_WORLD_BOSSES_DESC"]},
        },
    })

    local trackingBar = OneWoW_GUI:CreateFrame(parent, { bgColor = "BG_SECONDARY", borderColor = "BORDER_SUBTLE" })
    trackingBar:SetPoint("TOPLEFT", overview.panel, "BOTTOMLEFT", 0, -4)
    trackingBar:SetPoint("TOPRIGHT", overview.panel, "BOTTOMRIGHT", 0, -4)
    trackingBar:SetHeight(36)

    local trackingPad = OneWoW_GUI:GetSpacing("SM")
    local trackingConfigBtn = OneWoW_GUI:CreateFitTextButton(trackingBar, { text = OPTIONS, height = 24 })
    trackingConfigBtn:SetPoint("RIGHT", trackingBar, "RIGHT", -trackingPad, 0)
    trackingConfigBtn:SetScript("OnClick", function()
        ns.UI.ShowProgressTrackingDialog()
    end)

    local seasonTitle = OneWoW_GUI:CreateFS(trackingBar, 13)
    seasonTitle:SetJustifyH("LEFT")
    seasonTitle:SetWordWrap(false)
    seasonTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local seasonVersion = OneWoW_GUI:CreateFS(trackingBar, 11)
    seasonVersion:SetJustifyH("RIGHT")
    seasonVersion:SetWordWrap(false)
    seasonVersion:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local function LayoutTrackingBar()
        local verW = math.max(seasonVersion:GetStringWidth() or 0, 1)
        seasonVersion:ClearAllPoints()
        seasonVersion:SetPoint("RIGHT", trackingConfigBtn, "LEFT", -trackingPad, 0)
        seasonVersion:SetWidth(verW)
        seasonTitle:ClearAllPoints()
        seasonTitle:SetPoint("LEFT", trackingBar, "LEFT", trackingPad, 0)
        seasonTitle:SetPoint("RIGHT", seasonVersion, "LEFT", -trackingPad, 0)
    end

    trackingBar:SetScript("OnSizeChanged", LayoutTrackingBar)
    C_Timer.After(0.05, LayoutTrackingBar)

    parent.trackingBar = trackingBar
    parent.seasonTitleText = seasonTitle
    parent.seasonVersionText = seasonVersion
    parent.LayoutTrackingBar = LayoutTrackingBar
    ns.UI.RefreshTrackingBar(parent)

    local subTabBar = OneWoW_GUI:CreateFrame(parent, { height = 28, bgColor = "BG_SECONDARY", borderColor = "BORDER_SUBTLE" })
    subTabBar:SetPoint("TOPLEFT", trackingBar, "BOTTOMLEFT", 0, -4)
    subTabBar:SetPoint("TOPRIGHT", trackingBar, "BOTTOMRIGHT", 0, -4)

    local subTabButtons = {}
    local subTabFrames = {}
    local subTabOrder = {"mythicplus", "raids", "weekly", "currencies"}
    local subTabNames = {
        mythicplus = L["SUBTAB_MYTHICPLUS"],
        raids      = RAIDS,
        weekly     = WEEKLY,
        currencies = L["SUBTAB_CURRENCIES"],
    }

    local status = OneWoW_GUI:CreateStatusBar(parent, nil, {
        anchorPoint = "BOTTOM",
        text = string.format(L["CHARACTERS_TRACKED"], 0, "s"),
    })

    local function SelectSubTab(name)
        currentSubTab = name
        for n, frame in pairs(subTabFrames) do
            if n == name then frame:Show() else frame:Hide() end
        end
        for n, btn in pairs(subTabButtons) do
            if n == name then
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                btn.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            else
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                btn.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end
        if subTabFrames[name] and subTabFrames[name].refreshFunc then
            subTabFrames[name].refreshFunc(subTabFrames[name])
        end
    end

    for _, tabKey in ipairs(subTabOrder) do
        local btn = OneWoW_GUI:CreateButton(subTabBar, { text = subTabNames[tabKey], width = 100, height = 28 })
        btn.label = btn.text
        btn.tabKey = tabKey

        btn:SetScript("OnEnter", function(self)
            if currentSubTab ~= self.tabKey then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                self.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if currentSubTab ~= self.tabKey then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                self.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end)
        btn:SetScript("OnClick", function() SelectSubTab(tabKey) end)

        subTabButtons[tabKey] = btn

        local contentFrame = CreateFrame("Frame", nil, parent)
        contentFrame:SetPoint("TOPLEFT", subTabBar, "BOTTOMLEFT", 0, -4)
        contentFrame:SetPoint("BOTTOMRIGHT", status.bar, "TOPRIGHT", 0, 5)
        contentFrame:Hide()
        subTabFrames[tabKey] = contentFrame
    end

    local function LayoutSubTabButtons()
        local containerWidth = subTabBar:GetWidth()
        local numButtons = #subTabOrder
        if numButtons == 0 or containerWidth <= 0 then return end
        local buttonWidth = containerWidth / numButtons
        for i, name in ipairs(subTabOrder) do
            local btn = subTabButtons[name]
            btn:SetWidth(buttonWidth)
            btn:ClearAllPoints()
            if i == 1 then
                btn:SetPoint("LEFT", subTabBar, "LEFT", 0, 0)
            else
                local prevBtn = subTabButtons[subTabOrder[i-1]]
                btn:SetPoint("LEFT", prevBtn, "RIGHT", 0, 0)
            end
        end
    end

    subTabBar:SetScript("OnSizeChanged", LayoutSubTabButtons)
    C_Timer.After(0.1, LayoutSubTabButtons)

    local mpCols = CreateMythicPlusColumns()
    CreateSubTabContent(subTabFrames["mythicplus"], mpCols, "mythicplus")
    subTabFrames["mythicplus"].refreshFunc = function(frame)
        RefreshSubTabContent(frame, "mythicplus", parent, BuildMythicPlusCells, BuildMythicPlusTooltip)
    end

    local raidCols = CreateRaidsColumns()
    CreateSubTabContent(subTabFrames["raids"], raidCols, "raids")
    subTabFrames["raids"].refreshFunc = function(frame)
        RefreshSubTabContent(frame, "raids", parent, BuildRaidsCells, BuildRaidsTooltip)
    end

    local weeklyCols = CreateWeeklyColumns()
    CreateSubTabContent(subTabFrames["weekly"], weeklyCols, "weekly")
    subTabFrames["weekly"].refreshFunc = function(frame)
        RefreshSubTabContent(frame, "weekly", parent, BuildWeeklyCells, BuildWeeklyTooltip)
    end

    local curCols = CreateCurrenciesColumns()
    CreateSubTabContent(subTabFrames["currencies"], curCols, "currencies")
    subTabFrames["currencies"].refreshFunc = function(frame)
        RefreshSubTabContent(frame, "currencies", parent, BuildCurrenciesCells, BuildCurrenciesTooltip)
    end

    parent.overviewPanel = overview.panel
    parent.statsContainer = overview.statsContainer
    parent.statBoxes = overview.statBoxes
    parent.trackingBar = trackingBar
    parent.subTabBar = subTabBar
    parent.subTabButtons = subTabButtons
    parent.subTabFrames = subTabFrames
    parent.statusBar = status.bar
    parent.statusText = status.text

    OneWoW_GUI:ApplyFontToFrame(parent)

    C_Timer.After(0.5, function()
        SelectSubTab("mythicplus")
        if ns.UI.RefreshProgressStats then
            ns.UI.RefreshProgressStats(parent)
        end
    end)

    local function RefreshProgress()
        if ns.UI.RefreshProgressTab then
            ns.UI.RefreshProgressTab(parent)
        end
    end
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Character", RefreshProgress)
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Endgame", RefreshProgress)

    if ns.UI.RegisterRosterTabFrame then
        ns.UI.RegisterRosterTabFrame("progress", parent)
    end
    ns.UI.progressTabFrame = parent
end

function ns.UI.RefreshProgressTab(progressTab)
    if not progressTab then return end

    ns.UI.RefreshProgressStats(progressTab)
    ns.UI.RefreshTrackingBar(progressTab)

    if progressTab.subTabFrames and progressTab.subTabFrames[currentSubTab] then
        local frame = progressTab.subTabFrames[currentSubTab]
        if frame.refreshFunc then
            frame.refreshFunc(frame)
        end
    end

    OneWoW_GUI:ApplyFontToFrame(progressTab)
end

function ns.UI.RefreshProgressStats(progressTab)
    if not progressTab or not progressTab.statBoxes then return end
    if not OneWoW_AltTracker_Character_API then return end

    local charDB = OneWoW_AltTracker_Character_API.GetAllCharacters()
    local endgameDB = OneWoW_AltTracker_Endgame_API and OneWoW_AltTracker_Endgame_API.GetAllCharacters()

    local stats = {
        total = 0,
        keysHeld = 0,
        vaultReady = 0,
        bestRunLevel = 0,
        bestRunName = nil,
        bestRunChar = nil,
        bestRating = 0,
        bestRatingChar = nil,
        totalIlvl = 0,
        ilvlCount = 0,
        worldBossDone = 0,
    }

    for charKey, charData in pairs(charDB) do
        stats.total = stats.total + 1
        local edg = endgameDB and endgameDB[charKey]

        if edg and edg.mythicPlus then
            local mp = edg.mythicPlus
            if mp.currentKeystone and (mp.currentKeystone.level or 0) > 0 then
                stats.keysHeld = stats.keysHeld + 1
            end
            if mp.overallScore and mp.overallScore > stats.bestRating then
                stats.bestRating = mp.overallScore
                stats.bestRatingChar = charData.name or charKey
            end
            if mp.seasonBest then
                for mapID, mapInfo in pairs(mp.seasonBest) do
                    if mapInfo.intime and (mapInfo.intime.level or 0) > stats.bestRunLevel then
                        stats.bestRunLevel = mapInfo.intime.level
                        local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
                        stats.bestRunName = mapName
                        stats.bestRunChar = charData.name or charKey
                    end
                end
            end
        end

        if edg and edg.greatVault and edg.greatVault.activities then
            local acts = edg.greatVault.activities
            local function HasCompleted(list)
                if not list then return false end
                for _, act in ipairs(list) do
                    if (act.threshold or 0) > 0 and (act.progress or 0) >= act.threshold then
                        return true
                    end
                end
                return false
            end
            if HasCompleted(acts.raid) or HasCompleted(acts.dungeon) or HasCompleted(acts.world) then
                stats.vaultReady = stats.vaultReady + 1
            end
        end

        if charData.itemLevel and charData.itemLevel > 0 then
            stats.totalIlvl = stats.totalIlvl + charData.itemLevel
            stats.ilvlCount = stats.ilvlCount + 1
        end

        local wbKilled = GetWorldBossKilled(edg)
        if wbKilled then stats.worldBossDone = stats.worldBossDone + 1 end
    end

    local avgIlvl = stats.ilvlCount > 0 and math.floor(stats.totalIlvl / stats.ilvlCount) or 0
    local total = stats.total

    local statBoxes = progressTab.statBoxes
    if not statBoxes then return end

    if statBoxes[1] then
        statBoxes[1].value:SetText(tostring(total))
        statBoxes[1].extraTooltipLines = nil
    end

    if statBoxes[2] then
        statBoxes[2].value:SetText(total > 0 and (stats.keysHeld .. "/" .. total) or "0")
        statBoxes[2].extraTooltipLines = nil
    end

    if statBoxes[3] then
        statBoxes[3].value:SetText(total > 0 and (stats.vaultReady .. "/" .. total) or "0")
        statBoxes[3].extraTooltipLines = nil
    end

    if statBoxes[4] then
        if stats.bestRunLevel > 0 then
            statBoxes[4].value:SetText("+" .. stats.bestRunLevel)
            statBoxes[4].extraTooltipLines = {}
            if stats.bestRunName then
                table.insert(statBoxes[4].extraTooltipLines, {text = "+" .. stats.bestRunLevel .. " " .. stats.bestRunName, r = 1, g = 1, b = 0})
            end
            if stats.bestRunChar then
                table.insert(statBoxes[4].extraTooltipLines, {text = stats.bestRunChar, r = 0.7, g = 0.7, b = 0.7})
            end
        else
            statBoxes[4].value:SetText("--")
            statBoxes[4].extraTooltipLines = nil
        end
    end

    if statBoxes[5] then
        if stats.bestRating > 0 then
            statBoxes[5].value:SetText(tostring(stats.bestRating))
            statBoxes[5].extraTooltipLines = {}
            if stats.bestRatingChar then
                table.insert(statBoxes[5].extraTooltipLines, {text = stats.bestRatingChar, r = 0.7, g = 0.7, b = 0.7})
            end
        else
            statBoxes[5].value:SetText("--")
            statBoxes[5].extraTooltipLines = nil
        end
    end

    if statBoxes[6] then
        statBoxes[6].value:SetText(avgIlvl > 0 and tostring(avgIlvl) or "--")
        statBoxes[6].extraTooltipLines = nil
    end

    if statBoxes[7] then
        statBoxes[7].value:SetText(total > 0 and (stats.worldBossDone .. "/" .. total) or "0")
        statBoxes[7].extraTooltipLines = nil
    end

    ns.UI.RefreshTrackingBar(progressTab)
end

function ns.UI.RefreshTrackingBar(progressTab)
    if not progressTab then return end
    local title, version = ns.UI.GetSeasonIdentity()
    if progressTab.seasonTitleText then
        progressTab.seasonTitleText:SetText(title)
    end
    if progressTab.seasonVersionText then
        progressTab.seasonVersionText:SetText(version)
    end
    if progressTab.LayoutTrackingBar then
        progressTab.LayoutTrackingBar()
    end
end
