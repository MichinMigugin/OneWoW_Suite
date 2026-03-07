local addonName, ns = ...

ns.RoutinesEngine = {}
local Engine = ns.RoutinesEngine

local engineFrame = nil
local pinnedWindows = {}

local function EnsureEngineFrame()
    if not engineFrame then
        engineFrame = CreateFrame("Frame", "OneWoW_Notes_RoutinesEngineFrame", UIParent)
        engineFrame:Hide()
    end
    return engineFrame
end

local spellIndex = {}

local function BuildSpellIndex()
    wipe(spellIndex)
    local routines = ns.RoutinesData:GetAllRoutines()
    for routineID, routine in pairs(routines) do
        if type(routine) == "table" and routine.sections then
            for _, section in ipairs(routine.sections) do
                for _, task in ipairs(section.tasks or {}) do
                    if task.trackType == "spell" and task.trackParams and task.trackParams.spellId then
                        spellIndex[task.trackParams.spellId] = {
                            routineID = routineID,
                            sectionKey = section.key,
                            taskKey = task.key,
                            amount = task.trackParams.spellAmount or 1,
                            max = task.max or 1,
                        }
                    end
                end
            end
        end
    end
end

function Engine:Initialize()
    local frame = EnsureEngineFrame()
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    frame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    frame:RegisterEvent("ENCOUNTER_END")
    frame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    frame:RegisterEvent("UPDATE_FACTION")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:RegisterEvent("TRADE_SKILL_SHOW")
    frame:RegisterEvent("TRADE_SKILL_DETAILS_UPDATE")
    frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
    frame:RegisterEvent("SKILL_LINES_CHANGED")
    frame:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED")

    local lastScan = 0
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            ns.RoutinesData:CheckWeeklyReset()
            Engine:RestorePinnedWindows()
            C_Timer.After(2, function()
                BuildSpellIndex()
                Engine:Scan()
                Engine:RefreshAllPinnedWindows()
            end)
            return
        end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit, _, spellID = ...
            if unit ~= "player" then return end
            local entry = spellIndex[spellID]
            if entry then
                ns.RoutinesData:BumpProgress(entry.routineID, entry.sectionKey, entry.taskKey, entry.amount, entry.max)
                Engine:RefreshAllPinnedWindows()
            end
            return
        end
        if event == "GET_ITEM_INFO_RECEIVED" then
            Engine:RefreshAllPinnedWindows()
            return
        end
        if event == "ENCOUNTER_END" then
            local _, _, _, _, success = ...
            if success == 1 then
                C_Timer.After(1.5, function() Engine:Scan() end)
            end
            return
        end
        local now = GetTime()
        if now - lastScan < 1 then return end
        lastScan = now
        Engine:Scan()
    end)
end

function Engine:RebuildSpellIndex()
    BuildSpellIndex()
end

function Engine:GetTaskDisplayLabel(task)
    if task.trackParams and task.trackParams.itemId then
        local name = C_Item.GetItemNameByID(task.trackParams.itemId)
        if name then return name end
        C_Item.RequestLoadItemDataByID(task.trackParams.itemId)
    end
    return task.label or ""
end

function Engine:BuildTaskTooltip(task, section, anchorFrame)
    local displayLabel = self:GetTaskDisplayLabel(task)
    GameTooltip:SetOwner(anchorFrame, "ANCHOR_RIGHT")
    GameTooltip:SetText(displayLabel, 1, 1, 1, 1, true)

    local trackType = task.trackType or "manual"
    local effectiveReset = task.resetType or (section and section.resetType) or "weekly"

    if trackType == "manual" then
        GameTooltip:AddLine("Manual tracking", 0.8, 0.8, 0.5)
        GameTooltip:AddLine("Left click to advance, right click to undo", 0.55, 0.55, 0.55)
    elseif trackType == "quest" then
        GameTooltip:AddLine("Auto-tracked from game data", 0.4, 0.85, 0.4)
        if effectiveReset == "never" then
            GameTooltip:AddLine("Reflects any progress made before installing the addon", 0.65, 0.65, 0.45)
        end
    elseif trackType == "currency" then
        GameTooltip:AddLine("Auto-tracked - currency", 0.4, 0.85, 0.4)
        if task.trackParams and task.trackParams.currencyId then
            local info = C_CurrencyInfo.GetCurrencyInfo(task.trackParams.currencyId)
            if info and info.name then
                GameTooltip:AddLine(info.name, 0.7, 0.7, 0.7)
            end
        end
    elseif trackType == "vault_raid" or trackType == "vault_dungeon" or trackType == "vault_world" then
        GameTooltip:AddLine("Auto-tracked - Great Vault", 0.4, 0.85, 0.4)
        local actType = trackType == "vault_raid" and 3 or (trackType == "vault_dungeon" and 1 or 4)
        local tierName, tierColor = self:GetVaultTierInfo(actType)
        if tierName then
            GameTooltip:AddLine("Current tier: |cff" .. tierColor .. tierName .. "|r", 0.7, 0.7, 0.7)
        end
    elseif trackType == "renown" then
        GameTooltip:AddLine("Auto-tracked - faction renown", 0.4, 0.85, 0.4)
        if task.trackParams and task.trackParams.factionId then
            local data = C_MajorFactions.GetMajorFactionData(task.trackParams.factionId)
            if data then
                local rep = data.renownReputationEarned or 0
                local needed = data.renownLevelThreshold or 2500
                GameTooltip:AddLine(string.format("Progress to next level: %d / %d", rep, needed), 0.65, 0.65, 0.65)
            end
        end
    elseif trackType == "reputation" then
        GameTooltip:AddLine("Auto-tracked - reputation", 0.4, 0.85, 0.4)
        if task.trackParams and task.trackParams.factionId then
            local factionData = C_Reputation.GetFactionDataByID(task.trackParams.factionId)
            if factionData then
                local cur = factionData.currentStanding or 0
                local low = factionData.currentReactionThreshold or 0
                local high = factionData.nextReactionThreshold or 0
                if high > low then
                    GameTooltip:AddLine(string.format("Standing: %d / %d", cur - low, high - low), 0.65, 0.65, 0.65)
                end
            end
        end
    elseif trackType == "prof_skill" then
        GameTooltip:AddLine("Auto-tracked - profession skill level", 0.4, 0.85, 0.4)
    elseif trackType == "prof_concentration" then
        GameTooltip:AddLine("Auto-tracked - concentration", 0.4, 0.85, 0.4)
        GameTooltip:AddLine("Recharges over time", 0.65, 0.65, 0.65)
    elseif trackType == "prof_knowledge" then
        GameTooltip:AddLine("Auto-tracked - knowledge tree", 0.4, 0.85, 0.4)
        GameTooltip:AddLine("Shows spent (unspent) / max", 0.65, 0.65, 0.65)
        GameTooltip:AddLine("Reflects any points spent before installing the addon", 0.65, 0.65, 0.45)
    elseif trackType == "prof_firstcraft" then
        GameTooltip:AddLine("Auto-tracked - first crafts done", 0.4, 0.85, 0.4)
        GameTooltip:AddLine("Requires profession window opened at least once", 0.55, 0.55, 0.55)
    elseif trackType == "prof_catchup" then
        GameTooltip:AddLine("Auto-tracked - catch-up currency", 0.4, 0.85, 0.4)
        GameTooltip:AddLine("Drops from patron orders once weekly sources are done", 0.65, 0.65, 0.65)
    end

    if effectiveReset == "never" then
        GameTooltip:AddLine("Permanent - never resets", 0.55, 0.55, 0.35)
    elseif effectiveReset == "weekly" then
        GameTooltip:AddLine("Resets every Tuesday", 0.5, 0.5, 0.5)
    elseif effectiveReset == "daily" then
        GameTooltip:AddLine("Resets every day", 0.5, 0.5, 0.5)
    end

    GameTooltip:Show()
end

function Engine:EvaluateProfessionKnowledge(skillLineVariantID)
    if not skillLineVariantID then return nil, nil, nil end
    local configID = C_ProfSpecs.GetConfigIDForSkillLine(skillLineVariantID)
    if not configID or configID <= 0 then return nil, nil, nil end
    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs then return nil, nil, nil end
    local spent, maxKnow = 0, 0
    for _, treeID in ipairs(configInfo.treeIDs) do
        local treeNodes = C_Traits.GetTreeNodes(treeID)
        if treeNodes then
            for _, nodeID in ipairs(treeNodes) do
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                if nodeInfo then
                    if nodeInfo.ranksPurchased and nodeInfo.ranksPurchased > 1 then
                        spent = spent + (nodeInfo.currentRank - 1)
                    end
                    if nodeInfo.maxRanks and nodeInfo.maxRanks > 1 then
                        maxKnow = maxKnow + (nodeInfo.maxRanks - 1)
                    end
                end
            end
        end
    end
    local unspent = 0
    local concInfo = C_ProfSpecs.GetCurrencyInfoForSkillLine(skillLineVariantID)
    if concInfo then unspent = concInfo.numAvailable or 0 end
    return spent, unspent, maxKnow
end

function Engine:Scan()
    local routines = ns.RoutinesData:GetAllRoutines()
    local dirty = false

    for routineID, routine in pairs(routines) do
        if type(routine) == "table" and routine.sections then
            for _, section in ipairs(routine.sections) do
                for _, task in ipairs(section.tasks or {}) do
                    if task.trackType == "prof_knowledge" then
                        local params = task.trackParams or {}
                        local spent, unspent, maxKnow = self:EvaluateProfessionKnowledge(params.skillLineVariantID)
                        if spent ~= nil then
                            if maxKnow and maxKnow > 0 then task.max = maxKnow end
                            local effMax = (task.max and task.max > 0) and task.max or 9999
                            ns.RoutinesData:SetProgress(routineID, section.key, task.key, spent, effMax)
                            ns.RoutinesData:SetProgress(routineID, section.key, task.key .. "_u", unspent or 0, 9999)
                            dirty = true
                        end
                    else
                        local oldVal = ns.RoutinesData:GetProgress(routineID, section.key, task.key)
                        local newVal = self:EvaluateTask(task)
                        if newVal ~= nil and newVal ~= oldVal then
                            ns.RoutinesData:SetProgress(routineID, section.key, task.key, newVal, task.noMax and 999999 or task.max)
                            dirty = true
                        end
                    end
                end
            end
        end
    end

    if dirty then
        self:RefreshAllPinnedWindows()
    end
end

function Engine:EvaluateTask(task)
    local trackType = task.trackType
    local params = task.trackParams or {}

    if trackType == "quest" then
        if params.questIds then
            local done = 0
            for _, qid in ipairs(params.questIds) do
                if C_QuestLog.IsQuestFlaggedCompleted(qid) then
                    done = done + 1
                end
            end
            return math.min(done, task.max or done)
        end
        return nil

    elseif trackType == "currency" then
        if params.currencyId then
            local info = C_CurrencyInfo.GetCurrencyInfo(params.currencyId)
            if info then
                local raw = info.quantity or 0
                if info.maxQuantity and info.maxQuantity > 0 then
                    if info.useTotalEarnedForMaxQty and info.totalEarned ~= nil then
                        raw = info.totalEarned
                    end
                elseif info.maxWeeklyQuantity and info.maxWeeklyQuantity > 0 then
                    raw = info.quantityEarnedThisWeek or 0
                end
                return task.noMax and raw or math.min(raw, task.max or raw)
            end
        end
        return nil

    elseif trackType == "vault_raid" then
        return self:GetVaultProgress(3)

    elseif trackType == "vault_dungeon" then
        return self:GetVaultProgress(1)

    elseif trackType == "vault_world" then
        return self:GetVaultProgress(4)

    elseif trackType == "renown" then
        if params.factionId then
            local data = C_MajorFactions.GetMajorFactionData(params.factionId)
            if data then
                return data.renownLevel or 0
            end
        end
        return nil

    elseif trackType == "reputation" then
        if params.factionId then
            local factionData = C_Reputation.GetFactionDataByID(params.factionId)
            if factionData then
                return factionData.currentStanding or 0
            end
        end
        return nil

    elseif trackType == "spell" then
        return nil

    elseif trackType == "rare_quest" then
        if params.questId then
            if C_QuestLog.IsQuestFlaggedCompleted(params.questId) then
                return 1
            end
        end
        return 0

    elseif trackType == "manual" then
        return nil

    elseif trackType == "prof_skill" then
        if params.baseSkillLineID then
            local p1, p2 = GetProfessions()
            for _, idx in ipairs({p1, p2}) do
                if idx then
                    local _, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
                    if skillLine == params.baseSkillLineID and rank then
                        if maxRank and maxRank > 0 then task.max = maxRank end
                        return rank
                    end
                end
            end
        end
        return nil

    elseif trackType == "prof_concentration" then
        if params.currencyId and params.currencyId > 0 then
            local info = C_CurrencyInfo.GetCurrencyInfo(params.currencyId)
            if info then
                if info.maxQuantity and info.maxQuantity > 0 then
                    task.max = info.maxQuantity
                end
                return info.quantity or 0
            end
        end
        return nil

    elseif trackType == "prof_firstcraft" then
        if params.spellIds and #params.spellIds > 0 and C_TradeSkillUI.IsRecipeFirstCraft then
            local hasData = false
            local done = 0
            for _, spellID in ipairs(params.spellIds) do
                local result = C_TradeSkillUI.IsRecipeFirstCraft(spellID)
                if result ~= nil then
                    hasData = true
                    if result == false then
                        done = done + 1
                    end
                end
            end
            if hasData then return done end
        end
        return nil

    elseif trackType == "prof_catchup" then
        if params.currencyId and params.currencyId > 0 then
            local info = C_CurrencyInfo.GetCurrencyInfo(params.currencyId)
            if info then
                if info.maxQuantity and info.maxQuantity > 0 then
                    task.max = info.maxQuantity
                    task.noMax = false
                else
                    task.noMax = true
                end
                return info.quantity or 0
            end
        end
        return nil

    elseif trackType == "prof_knowledge" then
        return nil
    end

    return nil
end

function Engine:GetVaultProgress(activityType)
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return nil end
    local activities = C_WeeklyRewards.GetActivities()
    if not activities then return nil end
    local maxProgress = 0
    for _, act in ipairs(activities) do
        if act.type == activityType then
            local prog = act.progress or 0
            if prog > maxProgress then
                maxProgress = prog
            end
        end
    end
    return maxProgress
end

function Engine:GetVaultTierInfo(activityType)
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return nil, nil end
    local activities = C_WeeklyRewards.GetActivities()
    if not activities then return nil, nil end

    if activityType == 1 then
        local maxLevel = 0
        for _, act in ipairs(activities) do
            if act.type == 1 and (act.level or 0) > maxLevel then
                maxLevel = act.level or 0
            end
        end
        if maxLevel >= 10 then return "Myth", "ff8000"
        elseif maxLevel >= 7 then return "Hero", "0070dd"
        elseif maxLevel >= 4 then return "Champion", "f1c232"
        elseif maxLevel >= 2 then return "Veteran", "1eff00"
        else return "Follower", "b7b7b7" end

    elseif activityType == 3 then
        local DIFF_RANK = { [17]=1, [14]=2, [15]=3, [16]=4 }
        local RAID_DIFF = {
            [14] = { "Normal", "1eff00" },
            [15] = { "Heroic", "0070dd" },
            [16] = { "Mythic", "ff8000" },
            [17] = { "LFR",    "b7b7b7" },
        }
        local bestDiff = 14
        for _, act in ipairs(activities) do
            if act.type == 3 then
                local newRank = DIFF_RANK[act.difficultyId]
                if newRank and newRank > (DIFF_RANK[bestDiff] or 0) then
                    bestDiff = act.difficultyId
                end
            end
        end
        local d = RAID_DIFF[bestDiff]
        return d and d[1] or "Normal", d and d[2] or "1eff00"

    elseif activityType == 4 then
        return nil, nil
    end

    return nil, nil
end

function Engine:PinRoutine(routineID)
    local routine = ns.RoutinesData:GetRoutine(routineID)
    if not routine then return end
    routine.pinned = true
    routine.modified = GetServerTime()
    if not pinnedWindows[routineID] then
        self:CreatePinnedWindow(routineID)
    end
    if pinnedWindows[routineID] then
        pinnedWindows[routineID]:Show()
        if pinnedWindows[routineID].Refresh then
            pinnedWindows[routineID]:Refresh()
        end
    end
end

function Engine:UnpinRoutine(routineID)
    local routine = ns.RoutinesData:GetRoutine(routineID)
    if routine then
        routine.pinned = false
        routine.modified = GetServerTime()
    end
    if pinnedWindows[routineID] then
        pinnedWindows[routineID]:Hide()
    end
end

function Engine:TogglePin(routineID)
    local routine = ns.RoutinesData:GetRoutine(routineID)
    if not routine then return end
    if routine.pinned then
        self:UnpinRoutine(routineID)
    else
        self:PinRoutine(routineID)
    end
end

function Engine:RestorePinnedWindows()
    local routines = ns.RoutinesData:GetAllRoutines()
    for routineID, routine in pairs(routines) do
        if type(routine) == "table" and routine.pinned then
            C_Timer.After(1, function()
                Engine:PinRoutine(routineID)
                Engine:Scan()
            end)
        end
    end
end

function Engine:CreatePinnedWindow(routineID)
    if pinnedWindows[routineID] then return pinnedWindows[routineID] end

    local win = ns.UI.CreateRoutinePinnedWindow(routineID)
    if win then
        pinnedWindows[routineID] = win
    end
    return win
end

function Engine:GetPinnedWindow(routineID)
    return pinnedWindows[routineID]
end

function Engine:RefreshAllPinnedWindows()
    for routineID, win in pairs(pinnedWindows) do
        if win and win:IsShown() and win.Refresh then
            win:Refresh()
        end
    end
end

function Engine:RefreshPinnedWindow(routineID)
    local win = pinnedWindows[routineID]
    if win and win:IsShown() and win.Refresh then
        win:Refresh()
    end
end

function Engine:DestroyPinnedWindow(routineID)
    local win = pinnedWindows[routineID]
    if win then
        win:Hide()
        pinnedWindows[routineID] = nil
    end
end
