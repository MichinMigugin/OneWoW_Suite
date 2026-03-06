-- OneWoW AltTracker Addon File
-- OneWoW_AltTracker/UI/t-progress.lua
-- Created by MichinMigugin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local HEADER_HEIGHT = 30
local DUNGEON_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_Map01"
local CURRENCY_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

local SEASON_DUNGEONS = {
    {key = "sd1", name = "Magisters' Terrace",       short = "MAGT",  mapID = 558},
    {key = "sd2", name = "Maisara Caverns",           short = "MAIS",  mapID = 560},
    {key = "sd3", name = "Nexus-Point Xenas",         short = "XENA",  mapID = 559},
    {key = "sd4", name = "Windrunner Spire",          short = "WSPIR", mapID = 557},
    {key = "sd5", name = "Algeth'ar Academy",         short = "ACAD",  mapID = 402},
    {key = "sd6", name = "Seat of the Triumvirate",   short = "SEAT",  mapID = 239},
    {key = "sd7", name = "Skyreach",                  short = "SKY",   mapID = 161},
    {key = "sd8", name = "Pit of Saron",              short = "POS",   mapID = 556},
}

local SEASON_RAID_DIFFS = {
    {key = "rLFR", label = "LFR", diffFind = "Looking"},
    {key = "rNor", label = "NOR", diffFind = "Normal"},
    {key = "rHer", label = "HER", diffFind = "Heroic"},
    {key = "rMyt", label = "MYT", diffFind = "Mythic"},
}

local SEASON_RAID_TOTAL = 6

local SEASON_CURRENCIES = {
    {key = "cur_3383", currencyID = 3383, name = "Adventurer Dawncrest", width = 45},
    {key = "cur_3341", currencyID = 3341, name = "Veteran Dawncrest",    width = 45},
    {key = "cur_3343", currencyID = 3343, name = "Champion Dawncrest",   width = 45},
    {key = "cur_3345", currencyID = 3345, name = "Hero Dawncrest",       width = 45},
    {key = "cur_3347", currencyID = 3347, name = "Myth Dawncrest",       width = 45},
    {key = "cur_3303", currencyID = 3303, name = "Untethered Coin",      width = 50},
    {key = "cur_3309", currencyID = 3309, name = "Hellstone Shard",      width = 45},
    {key = "cur_3378", currencyID = 3378, name = "Dawnlight Manaflux",   width = 50},
    {key = "cur_3379", currencyID = 3379, name = "Brimming Arcana",      width = 45},
    {key = "cur_3385", currencyID = 3385, name = "Luminous Dust",        width = 45},
    {key = "cur_3316", currencyID = 3316, name = "Voidlight Marl",       width = 45},
}

local subTabState = {
    mythicplus = { sortColumn = nil, sortAscending = true, rows = {}, columns = {} },
    raids      = { sortColumn = nil, sortAscending = true, rows = {}, columns = {} },
    currencies = { sortColumn = nil, sortAscending = true, rows = {}, columns = {} },
}
local currentSubTab = "mythicplus"

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

local function GetCurrencyCapString(endgameData)
    local lines = GetTrackedCurrencyData(endgameData)
    if #lines > 0 then
        local first = lines[1]
        return first.name and (ns.ShortNames:GetShortName(first.name, 10) .. ": " .. first.text) or first.text
    end
    if endgameData and endgameData.pvp and endgameData.pvp.currencies and endgameData.pvp.currencies.conquest then
        local c = endgameData.pvp.currencies.conquest
        local earned = c.quantityEarnedThisWeek or 0
        local cap = c.maxWeeklyQuantity or 0
        if cap > 0 then return earned .. "/" .. cap end
    end
    return "--"
end

local function GetVaultCompletedString(endgameData)
    if not endgameData or not endgameData.greatVault or not endgameData.greatVault.activities then
        return "0/0/0"
    end
    local acts = endgameData.greatVault.activities
    local function CountCompleted(list)
        if not list then return 0 end
        local n = 0
        for _, act in ipairs(list) do
            if (act.threshold or 0) > 0 and (act.progress or 0) >= act.threshold then
                n = n + 1
            end
        end
        return n
    end
    return string.format("%d/%d/%d", CountCompleted(acts.raid), CountCompleted(acts.dungeon), CountCompleted(acts.world))
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

local function GetDiffAbbr(difficultyName)
    local dn = difficultyName or ""
    if dn:find("Mythic") then return "M"
    elseif dn:find("Heroic") then return "H"
    elseif dn:find("Normal") then return "N"
    elseif dn:find("Looking") then return "LFR"
    end
    return ""
end

local KNOWN_BOSS_NAMES = {}

local function GetRaidProgString(endgameData)
    if not endgameData or not endgameData.raids or not endgameData.raids.lockouts then return "--" end
    local lockouts = endgameData.raids.lockouts
    if #lockouts == 0 then return "--" end
    local best = nil
    local bestScore = -1
    for _, l in ipairs(lockouts) do
        local score = (l.encounterProgress or 0) * 100 + (#(l.difficultyName or "") > 0 and 1 or 0)
        if score > bestScore then bestScore = score; best = l end
    end
    if not best then best = lockouts[1] end
    if best then
        local d = GetDiffAbbr(best.difficultyName)
        local prog = (best.encounterProgress or 0) .. "/" .. (best.numEncounters or 0)
        local abbr = ns.ShortNames:GetShortName(best.name or "", 8)
        return abbr .. " " .. prog .. (d ~= "" and d or "")
    end
    return "--"
end

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

local function IsFavorite(charKey)
    if not OneWoW_AltTracker or not OneWoW_AltTracker.db then return false end
    return OneWoW_AltTracker.db.global.favorites and OneWoW_AltTracker.db.global.favorites[charKey] == true
end

local function SetFavorite(charKey, value)
    if not OneWoW_AltTracker or not OneWoW_AltTracker.db then return end
    if not OneWoW_AltTracker.db.global.favorites then
        OneWoW_AltTracker.db.global.favorites = {}
    end
    OneWoW_AltTracker.db.global.favorites[charKey] = value or nil
end

local function GetSortedCharacters(subTabKey)
    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return {} end
    if not _G.OneWoW_AltTracker_Endgame_DB then return {} end

    local allChars = {}
    for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
        table.insert(allChars, { key = charKey, data = charData })
    end
    if #allChars == 0 then return {} end

    local currentChar = UnitName("player")
    local currentRealm = GetRealmName()
    local currentCharKey = currentChar .. "-" .. currentRealm
    local state = subTabState[subTabKey]

    table.sort(allChars, function(a, b)
        local aFav = IsFavorite(a.key)
        local bFav = IsFavorite(b.key)
        if aFav and not bFav then return true end
        if bFav and not aFav then return false end

        local aIsCurrent = (a.key == currentCharKey)
        local bIsCurrent = (b.key == currentCharKey)
        if aIsCurrent and not bIsCurrent then return true end
        if bIsCurrent and not aIsCurrent then return false end

        if state.sortColumn then
            local aVal, bVal
            local aEndgame = _G.OneWoW_AltTracker_Endgame_DB.characters and _G.OneWoW_AltTracker_Endgame_DB.characters[a.key]
            local bEndgame = _G.OneWoW_AltTracker_Endgame_DB.characters and _G.OneWoW_AltTracker_Endgame_DB.characters[b.key]

            if state.sortColumn == "name" then
                aVal = a.data.name or ""
                bVal = b.data.name or ""
            elseif state.sortColumn == "server" then
                aVal = a.data.realm or ""
                bVal = b.data.realm or ""
            elseif state.sortColumn == "level" then
                aVal = a.data.level or 0
                bVal = b.data.level or 0
            elseif state.sortColumn == "ilvl" then
                aVal = a.data.itemLevel or 0
                bVal = b.data.itemLevel or 0
            elseif state.sortColumn == "rating" then
                aVal = (aEndgame and aEndgame.mythicPlus and aEndgame.mythicPlus.overallScore) or 0
                bVal = (bEndgame and bEndgame.mythicPlus and bEndgame.mythicPlus.overallScore) or 0
            elseif state.sortColumn == "bestTime" then
                local aLevel = GetBestTimedRun(aEndgame)
                local bLevel = GetBestTimedRun(bEndgame)
                aVal = aLevel or 0
                bVal = bLevel or 0
            elseif state.sortColumn == "keystone" then
                aVal = (aEndgame and aEndgame.mythicPlus and aEndgame.mythicPlus.currentKeystone and aEndgame.mythicPlus.currentKeystone.level) or 0
                bVal = (bEndgame and bEndgame.mythicPlus and bEndgame.mythicPlus.currentKeystone and bEndgame.mythicPlus.currentKeystone.level) or 0
            elseif state.sortColumn == "worldBoss" then
                local aKilled = GetWorldBossKilled(aEndgame)
                local bKilled = GetWorldBossKilled(bEndgame)
                aVal = aKilled and 1 or 0
                bVal = bKilled and 1 or 0
            elseif state.sortColumn:sub(1, 4) == "cur_" then
                local cid = tonumber(state.sortColumn:sub(5))
                local function getCurrQty(edg, id)
                    if not edg or not edg.currencies or not edg.currencies.tracked then return 0 end
                    local c = edg.currencies.tracked[id]
                    return c and (c.quantity or 0) or 0
                end
                aVal = getCurrQty(aEndgame, cid)
                bVal = getCurrQty(bEndgame, cid)
            elseif state.sortColumn == "vaultRaid" then
                aVal = GetVaultTypeString(aEndgame, "raid")
                bVal = GetVaultTypeString(bEndgame, "raid")
            elseif state.sortColumn == "vaultDungeon" then
                aVal = GetVaultTypeString(aEndgame, "dungeon")
                bVal = GetVaultTypeString(bEndgame, "dungeon")
            elseif state.sortColumn == "vaultWorld" then
                aVal = GetVaultTypeString(aEndgame, "world")
                bVal = GetVaultTypeString(bEndgame, "world")
            else
                local isDungKey = false
                for _, dung in ipairs(SEASON_DUNGEONS) do
                    if dung.key == state.sortColumn then
                        isDungKey = true
                        local function getDungLevel(edg)
                            if not edg or not edg.mythicPlus or not edg.mythicPlus.seasonBest then return 0 end
                            local best = edg.mythicPlus.seasonBest[dung.mapID]
                            if best and best.intime then return best.intime.level or 0 end
                            return 0
                        end
                        aVal = getDungLevel(aEndgame)
                        bVal = getDungLevel(bEndgame)
                        break
                    end
                end
                if not isDungKey then
                    for _, diff in ipairs(SEASON_RAID_DIFFS) do
                        if diff.key == state.sortColumn then
                            local function getRaidProg(edg)
                                if not edg or not edg.raids or not edg.raids.lockouts then return 0 end
                                for _, lockout in ipairs(edg.raids.lockouts) do
                                    if (lockout.difficultyName or ""):find(diff.diffFind) then
                                        return lockout.encounterProgress or 0
                                    end
                                end
                                return 0
                            end
                            aVal = getRaidProg(aEndgame)
                            bVal = getRaidProg(bEndgame)
                            break
                        end
                    end
                end
                if aVal == nil then
                    aVal = a.data.name or ""
                    bVal = b.data.name or ""
                end
            end

            if type(aVal) == "number" then
                if state.sortAscending then return aVal < bVal else return aVal > bVal end
            else
                if state.sortAscending then return aVal < bVal else return aVal > bVal end
            end
        end

        return (a.data.name or "") < (b.data.name or "")
    end)

    return allChars
end

local function CreateSubTabContent(contentFrame, columnsConfig, subTabKey)
    local state = subTabState[subTabKey]
    state.columns = columnsConfig

    local rosterPanel = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
    rosterPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    rosterPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    rosterPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    rosterPanel:SetBackdropColor(T("BG_PRIMARY"))
    rosterPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local listContainer = CreateFrame("Frame", nil, rosterPanel)
    listContainer:SetPoint("TOPLEFT", rosterPanel, "TOPLEFT", 8, -8)
    listContainer:SetPoint("BOTTOMRIGHT", rosterPanel, "BOTTOMRIGHT", -8, 8)

    local scrollBarWidth = 10
    local colGap = 4

    local headerRow = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
    headerRow:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, 0)
    headerRow:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", -scrollBarWidth, 0)
    headerRow:SetHeight(HEADER_HEIGHT)
    headerRow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    headerRow:SetBackdropColor(T("BG_TERTIARY"))
    headerRow:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    headerRow.columnButtons = {}
    headerRow.columns = columnsConfig

    local function UpdateAllRowCells()
        if not headerRow or not headerRow.columnButtons then return end
        if not state.rows then return end
        for _, charRow in ipairs(state.rows) do
            if charRow.cells then
                for i, cell in ipairs(charRow.cells) do
                    local btn = headerRow.columnButtons[i]
                    if btn and btn.columnWidth and btn.columnX then
                        local width = btn.columnWidth
                        local x = btn.columnX
                        cell:ClearAllPoints()
                        local col = columnsConfig[i]
                        if not col then
                        elseif col.key == "expand" then
                            cell:SetSize(width, 32)
                            cell:SetPoint("LEFT", charRow, "LEFT", x, 0)
                        elseif col.key == "faction" or col.key == "mail" then
                            cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
                        elseif col.key == "star" then
                            cell:SetSize(width, 32)
                            cell:SetPoint("LEFT", charRow, "LEFT", x, 0)
                        elseif col.key == "name" or col.key == "server" or col.key == "bestTime" or col.key == "keystone" or col.key == "worldBoss" then
                            cell:SetWidth(width - 6)
                            cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
                        else
                            cell:SetWidth(width - 6)
                            cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
                        end
                    end
                end
            end
        end
    end

    local function UpdateColumnLayout()
        local availableWidth = headerRow:GetWidth() - 10
        if availableWidth <= 0 then return end

        local fixedWidth = 0
        local flexCount = 0
        for _, col in ipairs(columnsConfig) do
            if col.fixed then
                fixedWidth = fixedWidth + col.width
            else
                flexCount = flexCount + 1
            end
        end

        local totalGaps = (#columnsConfig - 1) * colGap
        local remainingWidth = availableWidth - fixedWidth - totalGaps
        local flexWidth = flexCount > 0 and math.max(0, remainingWidth / flexCount) or 0

        local xOffset = 5
        for i, col in ipairs(columnsConfig) do
            local btn = headerRow.columnButtons[i]
            if btn then
                local width = col.fixed and col.width or math.max(col.width, flexWidth)
                btn:SetWidth(width)
                btn:ClearAllPoints()
                btn:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", xOffset, 2)
                btn.columnWidth = width
                btn.columnX = xOffset
                xOffset = xOffset + width + colGap
            end
        end

        UpdateAllRowCells()
    end

    local function UpdateSortIndicators()
        if not headerRow or not headerRow.columnButtons then return end
        for i, btn in ipairs(headerRow.columnButtons) do
            local col = columnsConfig[i]
            if btn.sortArrow then btn.sortArrow:Hide() end
            if col and col.key == state.sortColumn then
                if not btn.sortArrow then
                    btn.sortArrow = btn:CreateTexture(nil, "OVERLAY")
                    btn.sortArrow:SetSize(8, 8)
                    btn.sortArrow:SetPoint("RIGHT", btn, "RIGHT", -3, 0)
                end
                if state.sortAscending then
                    btn.sortArrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
                    btn.sortArrow:SetTexCoord(0, 1, 1, 0)
                else
                    btn.sortArrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
                    btn.sortArrow:SetTexCoord(0, 1, 0, 1)
                end
                btn.sortArrow:Show()
            end
        end
    end

    for i, col in ipairs(columnsConfig) do
        local btn = CreateFrame("Button", nil, headerRow, "BackdropTemplate")
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(T("BG_TERTIARY"))
        btn:SetBackdropBorderColor(T("BORDER_DEFAULT"))
        btn:SetHeight(HEADER_HEIGHT - 4)

        if col.key == "expand" then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(14, 14)
            icon:SetPoint("CENTER")
            icon:SetAtlas("Gamepad_Rev_Plus_64")
            btn.icon = icon
        elseif col.key == "faction" then
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("CENTER")
            text:SetText("F")
            text:SetTextColor(T("TEXT_PRIMARY"))
            btn.text = text
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
            icon:SetTexture("Interface/Common/FavoritesIcon")
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
        elseif col.raidDiff then
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("CENTER")
            text:SetText(col.raidDiff.label)
            text:SetTextColor(T("TEXT_PRIMARY"))
            btn.text = text
        else
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("CENTER")
            text:SetText(col.label or "")
            text:SetTextColor(T("TEXT_PRIMARY"))
            btn.text = text
        end

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
            if btn.text then btn.text:SetTextColor(T("TEXT_ACCENT")) end
            if col.ttTitle and col.ttDesc then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(col.ttTitle, 1, 1, 1)
                GameTooltip:AddLine(col.ttDesc, nil, nil, nil, true)
                GameTooltip:Show()
            elseif col.currencyData then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(col.currencyData.name, 1, 1, 1)
                GameTooltip:Show()
            elseif col.dungData then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(col.dungData.name, 1, 1, 1)
                GameTooltip:Show()
            end
        end)

        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
            if btn.text then btn.text:SetTextColor(T("TEXT_PRIMARY")) end
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function(self)
            if col.key == "expand" or col.key == "faction" or col.key == "mail" or col.key == "star" then
                return
            end
            if state.sortColumn == col.key then
                state.sortAscending = not state.sortAscending
            else
                state.sortColumn = col.key
                state.sortAscending = true
            end
            local refreshFunc = contentFrame.refreshFunc
            if refreshFunc then
                refreshFunc(contentFrame)
                C_Timer.After(0.1, function() UpdateSortIndicators() end)
            end
        end)

        table.insert(headerRow.columnButtons, btn)
    end

    headerRow:SetScript("OnSizeChanged", function()
        C_Timer.After(0.1, function() UpdateColumnLayout() end)
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, listContainer)
    scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -scrollBarWidth, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 40))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 40))
        end
    end)

    local scrollTrack = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", -2, 0)
    scrollTrack:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -2, 0)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollTrack:SetBackdropColor(T("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(30)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollThumb:SetBackdropColor(T("ACCENT_PRIMARY"))

    local function UpdateScrollThumb()
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        if maxScroll <= 0 then
            scrollThumb:Hide()
            return
        end
        scrollThumb:Show()
        local viewHeight = scrollFrame:GetHeight()
        local trackHeight = scrollTrack:GetHeight()
        local thumbHeight = math.max(20, trackHeight * (viewHeight / (viewHeight + maxScroll)))
        local thumbRange = trackHeight - thumbHeight
        local thumbPos = (scrollFrame:GetVerticalScroll() / maxScroll) * thumbRange
        scrollThumb:SetHeight(thumbHeight)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -thumbPos)
    end

    scrollFrame:SetScript("OnVerticalScroll", function() UpdateScrollThumb() end)
    scrollFrame:SetScript("OnScrollRangeChanged", function() UpdateScrollThumb() end)

    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")
    scrollThumb:SetScript("OnDragStart", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnDragStop", function(self) self.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self.dragStartY - curY
        local trackHeight = scrollTrack:GetHeight()
        local thumbRange = trackHeight - self:GetHeight()
        if thumbRange > 0 then
            local maxScroll = scrollFrame:GetVerticalScrollRange()
            local newScroll = self.dragStartScroll + (delta / thumbRange) * maxScroll
            scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, newScroll)))
        end
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(scrollFrame:GetWidth())
    scrollContent:SetHeight(400)
    scrollFrame:SetScrollChild(scrollContent)

    scrollFrame:HookScript("OnSizeChanged", function(self, width, height)
        scrollContent:SetWidth(width)
        UpdateScrollThumb()
    end)

    C_Timer.After(0.2, function() UpdateColumnLayout() end)

    contentFrame.rosterPanel = rosterPanel
    contentFrame.listContainer = listContainer
    contentFrame.headerRow = headerRow
    contentFrame.scrollFrame = scrollFrame
    contentFrame.scrollContent = scrollContent
    contentFrame.UpdateColumnLayout = UpdateColumnLayout
    contentFrame.UpdateSortIndicators = UpdateSortIndicators

    return contentFrame
end

local function CreateCommonCells(charRow, charData, charKey, endgameData, rowHeight, progressTab, subTabKey)
    local cells = {}

    local expandBtn = CreateFrame("Button", nil, charRow)
    expandBtn:SetSize(25, rowHeight)
    local expandIcon = expandBtn:CreateTexture(nil, "ARTWORK")
    expandIcon:SetSize(14, 14)
    expandIcon:SetPoint("CENTER")
    expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
    expandBtn.icon = expandIcon
    table.insert(cells, expandBtn)

    local factionIcon = charRow:CreateTexture(nil, "ARTWORK")
    factionIcon:SetSize(18, 18)
    if charData.faction == "Alliance" then
        factionIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
    elseif charData.faction == "Horde" then
        factionIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-Horde")
    else
        factionIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
        factionIcon:SetDesaturated(true)
    end
    table.insert(cells, factionIcon)

    local mailIcon = charRow:CreateTexture(nil, "ARTWORK")
    mailIcon:SetSize(16, 16)
    mailIcon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
    local hasMail = false
    if StorageAPI then
        local mailData = StorageAPI.GetMail(charKey)
        hasMail = mailData and mailData.hasNewMail
    end
    if hasMail then
        mailIcon:SetVertexColor(1, 1, 0, 1)
    else
        mailIcon:SetVertexColor(0.3, 0.3, 0.3, 0.5)
    end
    table.insert(cells, mailIcon)

    local nameText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetText(charData.name or charKey)
    local className = charData.class or charData.className
    if className then className = string.upper(className) end
    local classColor = className and RAID_CLASS_COLORS[className]
    if classColor then
        nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        nameText:SetTextColor(1, 1, 1)
    end
    nameText:SetJustifyH("LEFT")
    table.insert(cells, nameText)

    local realmText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    realmText:SetText(charData.realm or "")
    realmText:SetTextColor(T("TEXT_SECONDARY"))
    realmText:SetJustifyH("LEFT")
    table.insert(cells, realmText)

    local levelText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelText:SetText(tostring(charData.level or 0))
    levelText:SetTextColor(T("TEXT_PRIMARY"))
    table.insert(cells, levelText)

    local ilvlText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local ilvl = charData.itemLevel or 0
    ilvlText:SetText(ilvl > 0 and tostring(ilvl) or "--")
    ilvlText:SetTextColor(T("TEXT_PRIMARY"))
    if charData.itemLevelColor then
        ilvlText:SetTextColor(charData.itemLevelColor.r, charData.itemLevelColor.g, charData.itemLevelColor.b)
    end
    table.insert(cells, ilvlText)

    local ratingText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local rating = (endgameData and endgameData.mythicPlus and endgameData.mythicPlus.overallScore) or 0
    ratingText:SetText(tostring(rating))
    ratingText:SetTextColor(T("TEXT_PRIMARY"))
    table.insert(cells, ratingText)

    return cells, expandBtn, expandIcon
end

local function BuildExpandedPanels(ef, endgameData, charData, subTabKey)
    local function MakePanel(title)
        local p = CreateFrame("Frame", nil, ef, "BackdropTemplate")
        p:SetPoint("TOPLEFT", ef, "TOPLEFT", 4, -4)
        p:SetPoint("BOTTOMLEFT", ef, "BOTTOMLEFT", 4, 4)
        p:SetWidth(100)
        p:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        p:SetBackdropColor(T("BG_TERTIARY"))
        p:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        local titleFS = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        titleFS:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -5)
        titleFS:SetText(title)
        titleFS:SetTextColor(T("ACCENT_PRIMARY"))
        p.titleFS = titleFS
        p.dy = -18
        return p
    end

    local function AddLine(panel, text, color)
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, panel.dy)
        fs:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, panel.dy)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        if color then
            fs:SetTextColor(unpack(color))
        else
            fs:SetTextColor(T("TEXT_PRIMARY"))
        end
        panel.dy = panel.dy - 14
    end

    local panels = {}

    if subTabKey == "mythicplus" then
        local p1 = MakePanel(L["PROGRESS_GREAT_VAULT_DETAIL"])
        if endgameData and endgameData.greatVault and endgameData.greatVault.activities then
            local acts = endgameData.greatVault.activities
            local function VaultTypeStr(list, label)
                if not list or #list == 0 then
                    AddLine(p1, label .. ": --", {T("TEXT_SECONDARY")})
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
                AddLine(p1, label .. ": " .. table.concat(parts, "  "))
            end
            VaultTypeStr(acts.raid, L["PROGRESS_VAULT_RAID"])
            VaultTypeStr(acts.dungeon, L["PROGRESS_VAULT_DUNGEON"])
            VaultTypeStr(acts.world, L["PROGRESS_VAULT_WORLD"])
        else
            AddLine(p1, L["PROGRESS_VAULT_RAID"] .. ": --", {T("TEXT_SECONDARY")})
            AddLine(p1, L["PROGRESS_VAULT_DUNGEON"] .. ": --", {T("TEXT_SECONDARY")})
            AddLine(p1, L["PROGRESS_VAULT_WORLD"] .. ": --", {T("TEXT_SECONDARY")})
        end
        table.insert(panels, p1)

        local p2 = MakePanel(L["PROGRESS_MPLUS_SEASON_BEST"])
        if endgameData and endgameData.mythicPlus then
            local mp = endgameData.mythicPlus
            local bestStr = GetBestRunString(endgameData)
            AddLine(p2, L["PROGRESS_BEST_RUN"] .. " " .. bestStr)
            local score = (mp.overallScore and mp.overallScore > 0) and tostring(mp.overallScore) or "--"
            AddLine(p2, L["PROGRESS_SCORE"] .. " " .. score)
            if mp.currentKeystone and mp.currentKeystone.level and mp.currentKeystone.level > 0 then
                local ksName = mp.currentKeystone.mapName or ""
                local ksStr = "+" .. mp.currentKeystone.level
                if ksName ~= "" then ksStr = ksStr .. " " .. ksName end
                AddLine(p2, L["PROGRESS_CURRENT_KEY"] .. " " .. ksStr)
            else
                AddLine(p2, L["PROGRESS_CURRENT_KEY"] .. " --", {0.6, 0.6, 0.6})
            end
        else
            AddLine(p2, L["PROGRESS_BEST_RUN"] .. " --", {0.6, 0.6, 0.6})
            AddLine(p2, L["PROGRESS_SCORE"] .. " --", {0.6, 0.6, 0.6})
            AddLine(p2, L["PROGRESS_CURRENT_KEY"] .. " --", {0.6, 0.6, 0.6})
        end
        table.insert(panels, p2)

        local p3 = MakePanel(L["PROGRESS_CURRENCY_TRACKER"])
        local currLines = GetTrackedCurrencyData(endgameData)
        if #currLines > 0 then
            for _, cl in ipairs(currLines) do
                local capPct = (cl.cap and cl.cap > 0) and (cl.qty / cl.cap) or nil
                local color = {0.9, 0.9, 0.9}
                if capPct and capPct >= 1 then color = {0.2, 0.9, 0.2}
                elseif capPct and capPct >= 0.7 then color = {1, 0.8, 0.2}
                end
                AddLine(p3, cl.name .. ": " .. cl.text, color)
            end
        else
            AddLine(p3, "--", {0.5, 0.5, 0.5})
        end
        table.insert(panels, p3)

    elseif subTabKey == "raids" then
        local p1 = MakePanel(L["PROGRESS_GREAT_VAULT_DETAIL"])
        if endgameData and endgameData.greatVault and endgameData.greatVault.activities then
            local acts = endgameData.greatVault.activities
            local function VaultTypeStr(list, label)
                if not list or #list == 0 then
                    AddLine(p1, label .. ": --", {T("TEXT_SECONDARY")})
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
                AddLine(p1, label .. ": " .. table.concat(parts, "  "))
            end
            VaultTypeStr(acts.raid, L["PROGRESS_VAULT_RAID"])
            VaultTypeStr(acts.dungeon, L["PROGRESS_VAULT_DUNGEON"])
            VaultTypeStr(acts.world, L["PROGRESS_VAULT_WORLD"])
        else
            AddLine(p1, L["PROGRESS_VAULT_RAID"] .. ": --", {T("TEXT_SECONDARY")})
            AddLine(p1, L["PROGRESS_VAULT_DUNGEON"] .. ": --", {T("TEXT_SECONDARY")})
            AddLine(p1, L["PROGRESS_VAULT_WORLD"] .. ": --", {T("TEXT_SECONDARY")})
        end
        table.insert(panels, p1)

        local p2 = MakePanel(L["PROGRESS_WEEKLY_ACTIVITIES"])
        local bossKilled, bossName = GetWorldBossKilled(endgameData)
        if bossKilled then
            local bossStr = L["PROGRESS_BOSS_KILLED"]
            if bossName then bossStr = bossStr .. ": " .. bossName end
            AddLine(p2, "Boss: " .. bossStr, {0.2, 0.9, 0.2})
        else
            AddLine(p2, "Boss: " .. L["PROGRESS_BOSS_NONE"], {0.6, 0.6, 0.6})
        end
        local capStr = GetCurrencyCapString(endgameData)
        AddLine(p2, L["PROGRESS_CURRENCY_CAP"] .. " " .. capStr)
        table.insert(panels, p2)

        local p3 = MakePanel(L["PROGRESS_RAID_PROG_LABEL"])
        if endgameData and endgameData.raids and endgameData.raids.lockouts then
            local lockCount = #endgameData.raids.lockouts
            if lockCount > 0 then
                for _, lockout in ipairs(endgameData.raids.lockouts) do
                    local prog = lockout.encounterProgress or 0
                    local total = lockout.numEncounters or 0
                    local d = GetDiffAbbr(lockout.difficultyName)
                    AddLine(p3, (lockout.name or "Unknown") .. " " .. d .. ": " .. prog .. "/" .. total)
                end
            else
                AddLine(p3, "--", {0.6, 0.6, 0.6})
            end
        else
            AddLine(p3, "--", {0.6, 0.6, 0.6})
        end
        table.insert(panels, p3)

    elseif subTabKey == "currencies" then
        local p1 = MakePanel(L["PROGRESS_CURRENCY_TRACKER"])
        local currLines = GetTrackedCurrencyData(endgameData)
        if #currLines > 0 then
            for _, cl in ipairs(currLines) do
                local capPct = (cl.cap and cl.cap > 0) and (cl.qty / cl.cap) or nil
                local color = {0.9, 0.9, 0.9}
                if capPct and capPct >= 1 then color = {0.2, 0.9, 0.2}
                elseif capPct and capPct >= 0.7 then color = {1, 0.8, 0.2}
                end
                AddLine(p1, cl.name .. ": " .. cl.text, color)
            end
        else
            AddLine(p1, "--", {0.5, 0.5, 0.5})
        end
        table.insert(panels, p1)

        local p2 = MakePanel(L["PROGRESS_GREAT_VAULT_DETAIL"])
        if endgameData and endgameData.greatVault and endgameData.greatVault.activities then
            local acts = endgameData.greatVault.activities
            local function VaultTypeStr(list, label)
                if not list or #list == 0 then
                    AddLine(p2, label .. ": --", {T("TEXT_SECONDARY")})
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
                AddLine(p2, label .. ": " .. table.concat(parts, "  "))
            end
            VaultTypeStr(acts.raid, L["PROGRESS_VAULT_RAID"])
            VaultTypeStr(acts.dungeon, L["PROGRESS_VAULT_DUNGEON"])
            VaultTypeStr(acts.world, L["PROGRESS_VAULT_WORLD"])
        else
            AddLine(p2, L["PROGRESS_VAULT_RAID"] .. ": --", {T("TEXT_SECONDARY")})
            AddLine(p2, L["PROGRESS_VAULT_DUNGEON"] .. ": --", {T("TEXT_SECONDARY")})
            AddLine(p2, L["PROGRESS_VAULT_WORLD"] .. ": --", {T("TEXT_SECONDARY")})
        end
        table.insert(panels, p2)
    end

    local function LayoutPanels()
        local w = ef:GetWidth()
        if w <= 10 then return end
        local numPanels = #panels
        if numPanels == 0 then return end
        local gap = 8
        local panelWidth = (w - gap * (numPanels + 1)) / numPanels
        for i, p in ipairs(panels) do
            p:ClearAllPoints()
            local xOff = gap + (i - 1) * (panelWidth + gap)
            p:SetPoint("TOPLEFT", ef, "TOPLEFT", xOff, -4)
            p:SetPoint("BOTTOMLEFT", ef, "BOTTOMLEFT", xOff, 4)
            p:SetWidth(panelWidth)
        end
    end

    ef:SetScript("OnSizeChanged", function() LayoutPanels() end)
    C_Timer.After(0.05, function() LayoutPanels() end)
end

local function RefreshSubTabContent(contentFrame, subTabKey, progressTab, buildCellsFunc, buildTooltipFunc)
    local state = subTabState[subTabKey]
    local scrollContent = contentFrame.scrollContent
    if not scrollContent then return end

    for _, row in ipairs(state.rows) do
        if row.expandedFrame then
            row.expandedFrame:Hide()
            row.expandedFrame = nil
        end
        row:Hide()
        row:SetParent(nil)
    end
    wipe(state.rows)

    local allChars = GetSortedCharacters(subTabKey)
    if #allChars == 0 then return end

    local yOffset = -5
    local rowHeight = 32
    local rowGap = 2
    local columnsConfig = state.columns

    local function RepositionAllRows()
        local yo = -5
        for _, row in ipairs(state.rows) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yo)
            row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yo)
            yo = yo - (rowHeight + rowGap)
            if row.isExpanded and row.expandedFrame and row.expandedFrame:IsShown() then
                yo = yo - (row.expandedFrame:GetHeight() + rowGap)
            end
        end
        local totalHeight = math.max(400, math.abs(yo) + 50)
        scrollContent:SetHeight(totalHeight)
    end

    for charIndex, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local charData = charInfo.data
        local endgameData = _G.OneWoW_AltTracker_Endgame_DB.characters and _G.OneWoW_AltTracker_Endgame_DB.characters[charKey]

        local charRow = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        charRow:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
        charRow:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        charRow:SetHeight(rowHeight)
        charRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        charRow:SetBackdropColor(T("BG_TERTIARY"))
        charRow.charKey = charKey
        charRow.cells = {}

        local commonCells, expandBtn, expandIcon = CreateCommonCells(charRow, charData, charKey, endgameData, rowHeight, progressTab, subTabKey)
        for _, cell in ipairs(commonCells) do
            table.insert(charRow.cells, cell)
        end

        buildCellsFunc(charRow, charData, charKey, endgameData, progressTab)

        local function BuildExpandedRow()
            if charRow.expandedFrame then return end
            local ef = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
            ef:SetPoint("TOPLEFT", charRow, "BOTTOMLEFT", 0, -2)
            ef:SetPoint("TOPRIGHT", charRow, "BOTTOMRIGHT", 0, -2)
            ef:SetHeight(160)
            ef:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            ef:SetBackdropColor(T("BG_SECONDARY"))
            charRow.expandedFrame = ef
            BuildExpandedPanels(ef, endgameData, charData, subTabKey)
        end

        local function ToggleExpanded()
            charRow.isExpanded = not (charRow.isExpanded or false)
            if charRow.isExpanded then
                expandIcon:SetAtlas("Gamepad_Rev_Minus_64")
                BuildExpandedRow()
                charRow.expandedFrame:Show()
            else
                expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
                if charRow.expandedFrame then
                    charRow.expandedFrame:Hide()
                end
            end
            RepositionAllRows()
        end

        expandBtn:SetScript("OnClick", function() ToggleExpanded() end)

        local hdrRow = contentFrame.headerRow
        if hdrRow and hdrRow.columnButtons then
            for i, cell in ipairs(charRow.cells) do
                local btn = hdrRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX
                    local col = columnsConfig[i]
                    cell:ClearAllPoints()
                    if not col then
                    elseif col.key == "expand" then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", charRow, "LEFT", x, 0)
                    elseif col.key == "faction" or col.key == "mail" then
                        cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
                    elseif col.key == "star" then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", charRow, "LEFT", x, 0)
                    elseif col.key == "name" or col.key == "server" or col.key == "bestTime" or col.key == "keystone" or col.key == "worldBoss" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
                    else
                        cell:SetWidth(width - 6)
                        cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
                    end
                end
            end
        end

        charRow:EnableMouse(true)
        charRow:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
            if buildTooltipFunc then
                buildTooltipFunc(self, endgameData, charData, charKey, contentFrame)
            end
        end)
        charRow:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
            GameTooltip:Hide()
        end)
        charRow:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                ToggleExpanded()
            end
        end)

        charRow:Show()
        table.insert(state.rows, charRow)
        yOffset = yOffset - (rowHeight + rowGap)
    end

    local newHeight = math.max(400, #state.rows * (rowHeight + rowGap) + 10)
    scrollContent:SetHeight(newHeight)

    if progressTab and progressTab.statusText then
        progressTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], #allChars, ""))
    end
end

local function CreateMythicPlusColumns()
    local cols = {
        {key = "expand",    label = "",                          width = 25,  fixed = true,  ttTitle = L["TT_COL_EXPAND"],      ttDesc = L["TT_COL_EXPAND_DESC"]},
        {key = "faction",   label = "F",                         width = 25,  fixed = true,  ttTitle = L["TT_COL_FACTION"],     ttDesc = L["TT_COL_FACTION_DESC"]},
        {key = "mail",      label = "",                          width = 35,  fixed = true,  ttTitle = L["TT_COL_MAIL"],        ttDesc = L["TT_COL_MAIL_DESC"]},
        {key = "name",      label = L["COL_CHARACTER"],          width = 135, fixed = false, ttTitle = L["TT_COL_CHARACTER"],   ttDesc = L["TT_COL_CHARACTER_DESC"]},
        {key = "server",    label = L["COL_SERVER"],             width = 50,  fixed = false, ttTitle = L["TT_COL_SERVER"],      ttDesc = L["TT_COL_SERVER_DESC"]},
        {key = "level",     label = L["COL_LEVEL"],              width = 40,  fixed = true,  ttTitle = L["TT_COL_LEVEL"],       ttDesc = L["TT_COL_LEVEL_DESC"]},
        {key = "ilvl",      label = L["PROGRESS_COL_ILVL"],      width = 55,  fixed = true,  ttTitle = L["TT_COL_ILVL"],        ttDesc = L["TT_COL_ILVL_DESC"]},
        {key = "rating",    label = L["PROGRESS_COL_RATING"],    width = 50,  fixed = true,  ttTitle = L["TT_COL_RATING"],      ttDesc = L["TT_COL_RATING_DESC"]},
        {key = "bestTime",  label = L["PROGRESS_COL_BEST_RUN"] or "Best Run", width = 55, fixed = true, ttTitle = L["TT_COL_BEST_TIME"], ttDesc = L["TT_COL_BEST_TIME_DESC"]},
        {key = "star",      label = "",                          width = 30,  fixed = true,  ttTitle = L["TT_COL_STAR"],        ttDesc = L["TT_COL_STAR_DESC"]},
        {key = "keystone",  label = L["PROGRESS_COL_KEYSTONE"],  width = 65,  fixed = true,  ttTitle = L["TT_COL_KEYSTONE"],    ttDesc = L["TT_COL_KEYSTONE_DESC"]},
    }
    for _, dung in ipairs(SEASON_DUNGEONS) do
        table.insert(cols, {
            key      = dung.key,
            label    = dung.short,
            width    = 40,
            fixed    = true,
            ttTitle  = dung.name,
            ttDesc   = dung.name,
            dungData = dung,
        })
    end
    return cols
end

local function CreateRaidsColumns()
    local cols = {
        {key = "expand",      label = "",                          width = 25,  fixed = true,  ttTitle = L["TT_COL_EXPAND"],      ttDesc = L["TT_COL_EXPAND_DESC"]},
        {key = "faction",     label = "F",                         width = 25,  fixed = true,  ttTitle = L["TT_COL_FACTION"],     ttDesc = L["TT_COL_FACTION_DESC"]},
        {key = "mail",        label = "",                          width = 35,  fixed = true,  ttTitle = L["TT_COL_MAIL"],        ttDesc = L["TT_COL_MAIL_DESC"]},
        {key = "name",        label = L["COL_CHARACTER"],          width = 135, fixed = false, ttTitle = L["TT_COL_CHARACTER"],   ttDesc = L["TT_COL_CHARACTER_DESC"]},
        {key = "server",      label = L["COL_SERVER"],             width = 50,  fixed = false, ttTitle = L["TT_COL_SERVER"],      ttDesc = L["TT_COL_SERVER_DESC"]},
        {key = "level",       label = L["COL_LEVEL"],              width = 40,  fixed = true,  ttTitle = L["TT_COL_LEVEL"],       ttDesc = L["TT_COL_LEVEL_DESC"]},
        {key = "ilvl",        label = L["PROGRESS_COL_ILVL"],      width = 55,  fixed = true,  ttTitle = L["TT_COL_ILVL"],        ttDesc = L["TT_COL_ILVL_DESC"]},
        {key = "rating",      label = L["PROGRESS_COL_RATING"],    width = 50,  fixed = true,  ttTitle = L["TT_COL_RATING"],      ttDesc = L["TT_COL_RATING_DESC"]},
    }
    for _, diff in ipairs(SEASON_RAID_DIFFS) do
        table.insert(cols, {
            key      = diff.key,
            label    = diff.label,
            width    = 40,
            fixed    = true,
            ttTitle  = diff.label .. " Raid",
            ttDesc   = diff.label .. " raid difficulty progress",
            raidDiff = diff,
        })
    end
    table.insert(cols, {key = "worldBoss",    label = L["PROGRESS_COL_WORLD_BOSS"] or "W.Boss",  width = 55, fixed = true, ttTitle = L["TT_COL_WORLD_BOSS"], ttDesc = L["TT_COL_WORLD_BOSS_DESC"]})
    table.insert(cols, {key = "vaultRaid",    label = L["PROGRESS_COL_VAULT_RAID"] or "V:Raid",   width = 50, fixed = true, ttTitle = L["PROGRESS_VAULT_RAID"], ttDesc = "Great Vault raid progress"})
    table.insert(cols, {key = "vaultDungeon", label = L["PROGRESS_COL_VAULT_DUNGEON"] or "V:Dung", width = 50, fixed = true, ttTitle = L["PROGRESS_VAULT_DUNGEON"], ttDesc = "Great Vault dungeon progress"})
    table.insert(cols, {key = "vaultWorld",   label = L["PROGRESS_COL_VAULT_WORLD"] or "V:World",  width = 50, fixed = true, ttTitle = L["PROGRESS_VAULT_WORLD"], ttDesc = "Great Vault world progress"})
    return cols
end

local function CreateCurrenciesColumns()
    local cols = {
        {key = "expand",    label = "",                          width = 25,  fixed = true,  ttTitle = L["TT_COL_EXPAND"],      ttDesc = L["TT_COL_EXPAND_DESC"]},
        {key = "faction",   label = "F",                         width = 25,  fixed = true,  ttTitle = L["TT_COL_FACTION"],     ttDesc = L["TT_COL_FACTION_DESC"]},
        {key = "mail",      label = "",                          width = 35,  fixed = true,  ttTitle = L["TT_COL_MAIL"],        ttDesc = L["TT_COL_MAIL_DESC"]},
        {key = "name",      label = L["COL_CHARACTER"],          width = 135, fixed = false, ttTitle = L["TT_COL_CHARACTER"],   ttDesc = L["TT_COL_CHARACTER_DESC"]},
        {key = "server",    label = L["COL_SERVER"],             width = 50,  fixed = false, ttTitle = L["TT_COL_SERVER"],      ttDesc = L["TT_COL_SERVER_DESC"]},
        {key = "level",     label = L["COL_LEVEL"],              width = 40,  fixed = true,  ttTitle = L["TT_COL_LEVEL"],       ttDesc = L["TT_COL_LEVEL_DESC"]},
        {key = "ilvl",      label = L["PROGRESS_COL_ILVL"],      width = 55,  fixed = true,  ttTitle = L["TT_COL_ILVL"],        ttDesc = L["TT_COL_ILVL_DESC"]},
        {key = "rating",    label = L["PROGRESS_COL_RATING"],    width = 50,  fixed = true,  ttTitle = L["TT_COL_RATING"],      ttDesc = L["TT_COL_RATING_DESC"]},
    }
    for _, cur in ipairs(SEASON_CURRENCIES) do
        table.insert(cols, {
            key          = cur.key,
            label        = "",
            width        = cur.width,
            fixed        = true,
            currencyData = cur,
        })
    end
    return cols
end

local function BuildMythicPlusCells(charRow, charData, charKey, endgameData, progressTab)
    local bestTimeText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bestTimeText:SetText(GetBestRunString(endgameData))
    bestTimeText:SetTextColor(T("TEXT_PRIMARY"))
    bestTimeText:SetJustifyH("LEFT")
    table.insert(charRow.cells, bestTimeText)

    local starBtn = CreateFrame("Button", nil, charRow)
    starBtn:SetSize(30, 32)
    local starIcon = starBtn:CreateTexture(nil, "ARTWORK")
    starIcon:SetSize(14, 14)
    starIcon:SetPoint("CENTER")
    starIcon:SetTexture("Interface/Common/FavoritesIcon")
    if IsFavorite(charKey) then
        starIcon:SetVertexColor(1, 0.82, 0, 1)
    else
        starIcon:SetVertexColor(0.4, 0.4, 0.4, 0.6)
    end
    starBtn:SetScript("OnClick", function()
        local nowFav = IsFavorite(charKey)
        SetFavorite(charKey, not nowFav)
        if progressTab and progressTab.subTabFrames then
            local f = progressTab.subTabFrames["mythicplus"]
            if f and f.refreshFunc then f.refreshFunc(f) end
        end
    end)
    starBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(starBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TT_COL_STAR"], 1, 1, 1)
        GameTooltip:AddLine(L["TT_COL_STAR_DESC"], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    starBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(charRow.cells, starBtn)

    local keystoneText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local keystoneLevel = (endgameData and endgameData.mythicPlus and endgameData.mythicPlus.currentKeystone and endgameData.mythicPlus.currentKeystone.level) or 0
    local keystoneName = (endgameData and endgameData.mythicPlus and endgameData.mythicPlus.currentKeystone and endgameData.mythicPlus.currentKeystone.mapName) or ""
    if keystoneLevel > 0 and keystoneName ~= "" then
        keystoneText:SetText("+" .. keystoneLevel .. " " .. ns.ShortNames:GetShortName(keystoneName, 10))
    elseif keystoneLevel > 0 then
        keystoneText:SetText("+" .. keystoneLevel)
    else
        keystoneText:SetText("--")
    end
    keystoneText:SetTextColor(T("TEXT_PRIMARY"))
    keystoneText:SetJustifyH("LEFT")
    table.insert(charRow.cells, keystoneText)

    for _, dung in ipairs(SEASON_DUNGEONS) do
        local dungText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local dungLevel = nil
        if dung.mapID and dung.mapID > 0 and endgameData and endgameData.mythicPlus and endgameData.mythicPlus.seasonBest then
            local best = endgameData.mythicPlus.seasonBest[dung.mapID]
            if best and best.intime then dungLevel = best.intime.level end
        end
        dungText:SetText(dungLevel and ("+" .. dungLevel) or "--")
        dungText:SetTextColor(T("TEXT_PRIMARY"))
        dungText:SetJustifyH("CENTER")
        table.insert(charRow.cells, dungText)
    end
end

local function BuildMythicPlusTooltip(self, edg, chd, chk, contentFrame)
    local x = GetCursorPosition() / UIParent:GetEffectiveScale()
    local rowLeft = self:GetLeft()
    if not rowLeft then GameTooltip:Hide(); return end
    local relX = x - rowLeft
    local colKey = nil
    local hdrRow = contentFrame.headerRow
    local cols = subTabState["mythicplus"].columns
    if hdrRow and hdrRow.columnButtons then
        for i, btn in ipairs(hdrRow.columnButtons) do
            if btn.columnX and btn.columnWidth then
                if relX >= btn.columnX and relX <= btn.columnX + btn.columnWidth then
                    if cols[i] then colKey = cols[i].key end
                    break
                end
            end
        end
    end
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
        GameTooltip:SetText(L["TT_COL_RATING"], 1, 1, 1)
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
            GameTooltip:AddLine(L["PROGRESS_MPLUS_SEASON_BEST"], T("ACCENT_PRIMARY"))
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
        for _, dung in ipairs(SEASON_DUNGEONS) do
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

local function BuildRaidsCells(charRow, charData, charKey, endgameData, progressTab)
    for _, diff in ipairs(SEASON_RAID_DIFFS) do
        local raidText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local progress, total = 0, SEASON_RAID_TOTAL
        if endgameData and endgameData.raids and endgameData.raids.lockouts then
            for _, lockout in ipairs(endgameData.raids.lockouts) do
                if (lockout.difficultyName or ""):find(diff.diffFind) then
                    progress = lockout.encounterProgress or 0
                    total    = lockout.numEncounters or SEASON_RAID_TOTAL
                    break
                end
            end
        end
        raidText:SetText(progress .. "/" .. total)
        if progress > 0 and progress >= total then
            raidText:SetTextColor(0.2, 0.9, 0.2)
        elseif progress > 0 then
            raidText:SetTextColor(1, 0.8, 0.2)
        else
            raidText:SetTextColor(T("TEXT_PRIMARY"))
        end
        raidText:SetJustifyH("CENTER")
        table.insert(charRow.cells, raidText)
    end

    local worldBossText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local wbKilled, wbName = GetWorldBossKilled(endgameData)
    if wbKilled then
        worldBossText:SetText(ns.ShortNames:GetShortName(wbName or L["PROGRESS_BOSS_KILLED"], 9))
        worldBossText:SetTextColor(0.2, 0.9, 0.2)
    else
        worldBossText:SetText("--")
        worldBossText:SetTextColor(0.4, 0.4, 0.4)
    end
    worldBossText:SetJustifyH("LEFT")
    table.insert(charRow.cells, worldBossText)

    local vaultRaidText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vaultRaidText:SetText(GetVaultTypeString(endgameData, "raid"))
    vaultRaidText:SetTextColor(T("TEXT_PRIMARY"))
    vaultRaidText:SetJustifyH("CENTER")
    table.insert(charRow.cells, vaultRaidText)

    local vaultDungeonText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vaultDungeonText:SetText(GetVaultTypeString(endgameData, "dungeon"))
    vaultDungeonText:SetTextColor(T("TEXT_PRIMARY"))
    vaultDungeonText:SetJustifyH("CENTER")
    table.insert(charRow.cells, vaultDungeonText)

    local vaultWorldText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vaultWorldText:SetText(GetVaultTypeString(endgameData, "world"))
    vaultWorldText:SetTextColor(T("TEXT_PRIMARY"))
    vaultWorldText:SetJustifyH("CENTER")
    table.insert(charRow.cells, vaultWorldText)
end

local function BuildRaidsTooltip(self, edg, chd, chk, contentFrame)
    local x = GetCursorPosition() / UIParent:GetEffectiveScale()
    local rowLeft = self:GetLeft()
    if not rowLeft then GameTooltip:Hide(); return end
    local relX = x - rowLeft
    local colKey = nil
    local hdrRow = contentFrame.headerRow
    local cols = subTabState["raids"].columns
    if hdrRow and hdrRow.columnButtons then
        for i, btn in ipairs(hdrRow.columnButtons) do
            if btn.columnX and btn.columnWidth then
                if relX >= btn.columnX and relX <= btn.columnX + btn.columnWidth then
                    if cols[i] then colKey = cols[i].key end
                    break
                end
            end
        end
    end
    if not colKey or colKey == "expand" or colKey == "faction" or colKey == "mail" then
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
            GameTooltip:AddLine(L["PROGRESS_BOSS_NONE"], 0.5, 0.5, 0.5)
        end
    elseif colKey == "vaultRaid" or colKey == "vaultDungeon" or colKey == "vaultWorld" then
        GameTooltip:SetText(L["TT_COL_VAULT"], 1, 1, 1)
        if edg and edg.greatVault and edg.greatVault.activities then
            local acts = edg.greatVault.activities
            local function VaultTT(list, label)
                if not list or #list == 0 then
                    GameTooltip:AddLine(label .. ": --", 0.5, 0.5, 0.5)
                    return
                end
                for j, act in ipairs(list) do
                    local prog = act.progress or 0
                    local thresh = act.threshold or 0
                    local done = thresh > 0 and prog >= thresh
                    if done then
                        GameTooltip:AddLine(label .. " " .. j .. ": " .. prog .. "/" .. thresh, 0.2, 0.9, 0.2)
                    else
                        GameTooltip:AddLine(label .. " " .. j .. ": " .. prog .. "/" .. thresh, 0.8, 0.8, 0.8)
                    end
                end
            end
            VaultTT(acts.raid, L["PROGRESS_VAULT_RAID"])
            VaultTT(acts.dungeon, L["PROGRESS_VAULT_DUNGEON"])
            VaultTT(acts.world, L["PROGRESS_VAULT_WORLD"])
        else
            GameTooltip:AddLine("--", 0.5, 0.5, 0.5)
        end
    else
        for _, diff in ipairs(SEASON_RAID_DIFFS) do
            if diff.key == colKey then
                GameTooltip:SetText(diff.label .. " Raid", 1, 1, 1)
                local progress, total = 0, SEASON_RAID_TOTAL
                if edg and edg.raids and edg.raids.lockouts then
                    for _, lockout in ipairs(edg.raids.lockouts) do
                        if (lockout.difficultyName or ""):find(diff.diffFind) then
                            progress = lockout.encounterProgress or 0
                            total    = lockout.numEncounters or SEASON_RAID_TOTAL
                            break
                        end
                    end
                end
                GameTooltip:AddLine(progress .. "/" .. total .. " bosses", 0.9, 0.9, 0.9)
                break
            end
        end
        if colKey == "rating" then
            GameTooltip:SetText(L["TT_COL_RATING"], 1, 1, 1)
            GameTooltip:AddLine(tostring((edg and edg.mythicPlus and edg.mythicPlus.overallScore) or 0), 0.9, 0.9, 0.9)
        end
    end
    GameTooltip:Show()
end

local function BuildCurrenciesCells(charRow, charData, charKey, endgameData, progressTab)
    for _, cur in ipairs(SEASON_CURRENCIES) do
        local curText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local qty = 0
        local maxQty = 0
        if endgameData and endgameData.currencies and endgameData.currencies.tracked then
            local cData = endgameData.currencies.tracked[cur.currencyID]
            if cData then
                qty = cData.quantity or 0
                maxQty = cData.maxQuantity or 0
            end
        end
        if maxQty > 0 then
            curText:SetText(qty .. "/" .. maxQty)
            if qty >= maxQty then
                curText:SetTextColor(0.2, 0.9, 0.2)
            else
                curText:SetTextColor(T("TEXT_PRIMARY"))
            end
        elseif qty > 0 then
            curText:SetText(tostring(qty))
            curText:SetTextColor(T("TEXT_PRIMARY"))
        else
            curText:SetText("--")
            curText:SetTextColor(0.4, 0.4, 0.4)
        end
        curText:SetJustifyH("CENTER")
        table.insert(charRow.cells, curText)
    end
end

local function BuildCurrenciesTooltip(self, edg, chd, chk, contentFrame)
    local x = GetCursorPosition() / UIParent:GetEffectiveScale()
    local rowLeft = self:GetLeft()
    if not rowLeft then GameTooltip:Hide(); return end
    local relX = x - rowLeft
    local colKey = nil
    local hdrRow = contentFrame.headerRow
    local cols = subTabState["currencies"].columns
    if hdrRow and hdrRow.columnButtons then
        for i, btn in ipairs(hdrRow.columnButtons) do
            if btn.columnX and btn.columnWidth then
                if relX >= btn.columnX and relX <= btn.columnX + btn.columnWidth then
                    if cols[i] then colKey = cols[i].key end
                    break
                end
            end
        end
    end
    if not colKey or colKey == "expand" or colKey == "faction" or colKey == "mail" then
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
        local curName = colKey
        for _, cur in ipairs(SEASON_CURRENCIES) do
            if cur.currencyID == cid then curName = cur.name; break end
        end
        GameTooltip:SetText(curName, 1, 1, 1)
        if edg and edg.currencies and edg.currencies.tracked then
            local cData = edg.currencies.tracked[cid]
            if cData then
                local qty = cData.quantity or 0
                local maxQty = cData.maxQuantity or 0
                local weeklyEarned = cData.quantityEarnedThisWeek
                local weeklyCap = cData.maxWeeklyQuantity
                if maxQty > 0 then
                    GameTooltip:AddLine("Total: " .. qty .. "/" .. maxQty, 0.9, 0.9, 0.9)
                else
                    GameTooltip:AddLine("Total: " .. qty, 0.9, 0.9, 0.9)
                end
                if weeklyCap and weeklyCap > 0 then
                    GameTooltip:AddLine("This Week: " .. (weeklyEarned or 0) .. "/" .. weeklyCap, 0.8, 0.8, 0.8)
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

function ns.UI.CreateProgressTab(parent)
    local overviewPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    overviewPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    overviewPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)
    overviewPanel:SetHeight(70)
    overviewPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    overviewPanel:SetBackdropColor(T("BG_SECONDARY"))
    overviewPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local overviewTitle = overviewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overviewTitle:SetPoint("TOPLEFT", overviewPanel, "TOPLEFT", 10, -6)
    overviewTitle:SetText(L["PROGRESS_OVERVIEW"])
    overviewTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local statsContainer = CreateFrame("Frame", nil, overviewPanel)
    statsContainer:SetPoint("TOPLEFT", overviewTitle, "BOTTOMLEFT", 0, -8)
    statsContainer:SetPoint("BOTTOMRIGHT", overviewPanel, "BOTTOMRIGHT", -10, 6)

    local statLabels = {
        L["PROGRESS_CHARACTERS"], L["PROGRESS_KEYS"], L["PROGRESS_VAULT"],
        L["PROGRESS_HIGHEST_KEY"], L["PROGRESS_AVG_RATING"],
        L["PROGRESS_AVG_ILVL"], L["PROGRESS_WORLD_BOSSES"]
    }

    local statTooltipTitles = {
        L["TT_PROGRESS_CHARACTERS"], L["TT_PROGRESS_KEYS"], L["TT_PROGRESS_VAULT"],
        L["TT_PROGRESS_HIGHEST_KEY"], L["TT_PROGRESS_AVG_RATING"],
        L["TT_PROGRESS_AVG_ILVL"], L["TT_PROGRESS_WORLD_BOSSES"]
    }

    local statTooltips = {
        L["TT_PROGRESS_CHARACTERS_DESC"], L["TT_PROGRESS_KEYS_DESC"], L["TT_PROGRESS_VAULT_DESC"],
        L["TT_PROGRESS_HIGHEST_KEY_DESC"], L["TT_PROGRESS_AVG_RATING_DESC"],
        L["TT_PROGRESS_AVG_ILVL_DESC"], L["TT_PROGRESS_WORLD_BOSSES_DESC"]
    }

    local statValues = { "0", "0", "0", "0", "0", "0", "0" }

    local cols = 7
    local rows = 1
    local statBoxes = {}

    for i = 1, #statLabels do
        local statBox = CreateFrame("Frame", nil, statsContainer, "BackdropTemplate")
        statBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        statBox:SetBackdropColor(T("BG_TERTIARY"))
        statBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local label = statBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOP", statBox, "TOP", 0, -5)
        label:SetText(statLabels[i])
        label:SetTextColor(T("TEXT_SECONDARY"))

        local value = statBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("BOTTOM", statBox, "BOTTOM", 0, 6)
        value:SetText(statValues[i])
        value:SetTextColor(T("TEXT_PRIMARY"))

        statBox.label = label
        statBox.value = value

        statBox:EnableMouse(true)
        statBox:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(statTooltipTitles[i], 1, 1, 1)
            GameTooltip:AddLine(statTooltips[i], nil, nil, nil, true)
            if self.extraTooltipLines and #self.extraTooltipLines > 0 then
                GameTooltip:AddLine(" ")
                for _, line in ipairs(self.extraTooltipLines) do
                    GameTooltip:AddLine(line.text, line.r or 0.8, line.g or 0.8, line.b or 0.8, line.wrap)
                end
            end
            GameTooltip:Show()
        end)
        statBox:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
            GameTooltip:Hide()
        end)

        table.insert(statBoxes, statBox)
    end

    statsContainer:SetScript("OnSizeChanged", function(self, width, height)
        local boxWidth = (width - (cols + 1) * 3) / cols
        local boxHeight = (height - (rows + 1) * 3) / rows

        for i, box in ipairs(statBoxes) do
            local row = math.ceil(i / cols)
            local col = ((i - 1) % cols) + 1
            local xp = 3 + (col - 1) * (boxWidth + 3)
            local yp = -3 - (row - 1) * (boxHeight + 3)
            box:SetSize(boxWidth, boxHeight)
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", self, "TOPLEFT", xp, yp)
        end
    end)

    local trackingBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    trackingBar:SetPoint("TOPLEFT", overviewPanel, "BOTTOMLEFT", 0, -4)
    trackingBar:SetPoint("TOPRIGHT", overviewPanel, "BOTTOMRIGHT", 0, -4)
    trackingBar:SetHeight(22)
    trackingBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    trackingBar:SetBackdropColor(T("BG_SECONDARY"))
    trackingBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local trackingText = trackingBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    trackingText:SetPoint("LEFT", trackingBar, "LEFT", 10, 0)
    trackingText:SetPoint("RIGHT", trackingBar, "RIGHT", -10, 0)
    trackingText:SetJustifyH("LEFT")
    trackingText:SetText("")
    trackingText:SetTextColor(T("TEXT_SECONDARY"))

    local subTabBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    subTabBar:SetPoint("TOPLEFT", trackingBar, "BOTTOMLEFT", 0, -4)
    subTabBar:SetPoint("TOPRIGHT", trackingBar, "BOTTOMRIGHT", 0, -4)
    subTabBar:SetHeight(28)
    subTabBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    subTabBar:SetBackdropColor(T("BG_SECONDARY"))
    subTabBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local subTabButtons = {}
    local subTabFrames = {}
    local subTabOrder = {"mythicplus", "raids", "currencies"}
    local subTabNames = {
        mythicplus = L["SUBTAB_MYTHICPLUS"] or "Mythic+",
        raids      = L["SUBTAB_RAIDS"] or "Raids",
        currencies = L["SUBTAB_CURRENCIES"] or "Currencies",
    }

    local statusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    statusBar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 5, 5)
    statusBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 5)
    statusBar:SetHeight(25)
    statusBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    statusBar:SetBackdropColor(T("BG_SECONDARY"))
    statusBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", statusBar, "LEFT", 10, 0)
    statusText:SetText(string.format(L["CHARACTERS_TRACKED"], 0, "s"))
    statusText:SetTextColor(T("TEXT_SECONDARY"))

    local function SelectSubTab(name)
        currentSubTab = name
        for n, frame in pairs(subTabFrames) do
            if n == name then frame:Show() else frame:Hide() end
        end
        for n, btn in pairs(subTabButtons) do
            if n == name then
                btn:SetBackdropColor(T("BG_ACTIVE"))
                btn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                btn.label:SetTextColor(T("TEXT_ACCENT"))
            else
                btn:SetBackdropColor(T("BG_SECONDARY"))
                btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                btn.label:SetTextColor(T("TEXT_PRIMARY"))
            end
        end
        if subTabFrames[name] and subTabFrames[name].refreshFunc then
            subTabFrames[name].refreshFunc(subTabFrames[name])
        end
    end

    for _, tabKey in ipairs(subTabOrder) do
        local btn = CreateFrame("Button", nil, subTabBar, "BackdropTemplate")
        btn:SetHeight(28)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(T("BG_SECONDARY"))
        btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local btnLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnLabel:SetPoint("CENTER")
        btnLabel:SetText(subTabNames[tabKey])
        btnLabel:SetTextColor(T("TEXT_PRIMARY"))
        btn.label = btnLabel
        btn.tabKey = tabKey

        btn:SetScript("OnEnter", function(self)
            if currentSubTab ~= self.tabKey then
                self:SetBackdropColor(T("BG_HOVER"))
                self.label:SetTextColor(T("TEXT_ACCENT"))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if currentSubTab ~= self.tabKey then
                self:SetBackdropColor(T("BG_SECONDARY"))
                self.label:SetTextColor(T("TEXT_PRIMARY"))
            end
        end)
        btn:SetScript("OnClick", function() SelectSubTab(tabKey) end)

        subTabButtons[tabKey] = btn

        local contentFrame = CreateFrame("Frame", nil, parent)
        contentFrame:SetPoint("TOPLEFT", subTabBar, "BOTTOMLEFT", 0, -4)
        contentFrame:SetPoint("BOTTOMRIGHT", statusBar, "TOPRIGHT", 0, 5)
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

    local curCols = CreateCurrenciesColumns()
    CreateSubTabContent(subTabFrames["currencies"], curCols, "currencies")
    subTabFrames["currencies"].refreshFunc = function(frame)
        RefreshSubTabContent(frame, "currencies", parent, BuildCurrenciesCells, BuildCurrenciesTooltip)
    end

    parent.overviewPanel = overviewPanel
    parent.statsContainer = statsContainer
    parent.statBoxes = statBoxes
    parent.trackingBar = trackingBar
    parent.trackingText = trackingText
    parent.subTabBar = subTabBar
    parent.subTabButtons = subTabButtons
    parent.subTabFrames = subTabFrames
    parent.statusBar = statusBar
    parent.statusText = statusText

    C_Timer.After(0.5, function()
        SelectSubTab("mythicplus")
        if ns.UI.RefreshProgressStats then
            ns.UI.RefreshProgressStats(parent)
        end
    end)
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
end

function ns.UI.RefreshProgressStats(progressTab)
    if not progressTab or not progressTab.statBoxes then return end
    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return end

    local charDB = _G.OneWoW_AltTracker_Character_DB.characters
    local endgameDB = _G.OneWoW_AltTracker_Endgame_DB and _G.OneWoW_AltTracker_Endgame_DB.characters

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
    if not progressTab or not progressTab.trackingText then return end
    local charDB = _G.OneWoW_AltTracker_Character_DB and _G.OneWoW_AltTracker_Character_DB.characters
    local endgameDB = _G.OneWoW_AltTracker_Endgame_DB and _G.OneWoW_AltTracker_Endgame_DB.characters

    local raidName = ""
    local bossName = ""
    local raidAuto = false
    local bossAuto = false

    if charDB and endgameDB then
        local counts = {}
        for charKey in pairs(charDB) do
            local edg = endgameDB[charKey]
            if edg and edg.raids and edg.raids.lockouts then
                for _, l in ipairs(edg.raids.lockouts) do
                    local nm = l.name or ""
                    if nm ~= "" then counts[nm] = (counts[nm] or 0) + 1 end
                end
            end
        end
        local best, bestCount = "", 0
        for nm, c in pairs(counts) do
            if c > bestCount then bestCount = c; best = nm end
        end
        if best ~= "" then raidName = best; raidAuto = true end
    end

    if bossName == "" and charDB and endgameDB then
        for charKey in pairs(charDB) do
            local edg = endgameDB[charKey]
            if edg and edg.worldBoss then
                local killed, nm = GetWorldBossKilled(edg)
                if killed and nm and nm ~= "" then
                    bossName = nm; bossAuto = true; break
                end
            end
        end
    end
    if bossName == "" then
        local questIDs = (OneWoW_AltTracker and OneWoW_AltTracker.db and
                          OneWoW_AltTracker.db.global.overrides and
                          OneWoW_AltTracker.db.global.overrides.progress and
                          OneWoW_AltTracker.db.global.overrides.progress.worldBossQuestIDs) or {}
        local names = {}
        for _, qid in ipairs(questIDs) do
            local nm = KNOWN_BOSS_NAMES[qid]
            if nm then table.insert(names, nm) end
        end
        if #names > 0 then
            bossName = table.concat(names, " / ")
        end
    end

    local currencyNames = {}
    if charDB and endgameDB then
        for charKey in pairs(charDB) do
            local edg = endgameDB[charKey]
            if edg and edg.currencies and edg.currencies.tracked then
                local order = {}
                for id, info in pairs(edg.currencies.tracked) do
                    if info and info.name then table.insert(order, {id = id, name = info.name}) end
                end
                table.sort(order, function(a, b) return a.id < b.id end)
                for _, entry in ipairs(order) do
                    table.insert(currencyNames, entry.name)
                end
                break
            end
        end
    end

    local raidStr = raidName ~= "" and (raidName .. (raidAuto and " " .. L["TRACKING_BAR_AUTO"] or "")) or L["TRACKING_BAR_NOT_SET"]
    local bossStr = bossName ~= "" and (bossName .. (bossAuto and " " .. L["TRACKING_BAR_AUTO"] or "")) or L["TRACKING_BAR_NOT_SET"]
    local currStr = #currencyNames > 0 and table.concat(currencyNames, "  |  ") or L["TRACKING_BAR_NOT_SET"]

    progressTab.trackingText:SetText(
        L["TRACKING_BAR_RAID"] .. " " .. raidStr .. "     " ..
        L["TRACKING_BAR_BOSS"] .. " " .. bossStr .. "     " ..
        L["TRACKING_BAR_CURRENCIES"] .. " " .. currStr
    )
end
