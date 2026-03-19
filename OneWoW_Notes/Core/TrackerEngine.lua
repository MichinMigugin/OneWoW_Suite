local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.TrackerEngine = {}
local TE = ns.TrackerEngine
local TD

local pairs, ipairs, type, tonumber, tostring = pairs, ipairs, type, tonumber, tostring
local tinsert, tremove, wipe = tinsert, tremove, wipe
local format = format
local time = time

local eventFrame = nil
local spellIndex = {}
local killIndex = {}
local lootIndex = {}
local npcIndex = {}
local lastScanTime = 0
local SCAN_THROTTLE = 1.0
local initialized = false
local pinnedWindows = {}
local callbacks = {}

function TE:RegisterCallback(event, fn)
    callbacks[event] = callbacks[event] or {}
    tinsert(callbacks[event], fn)
end

local function FireCallbacks(event, ...)
    if callbacks[event] then
        for _, fn in ipairs(callbacks[event]) do
            fn(...)
        end
    end
end

local activeEventsCache = {}
local lastEventCheck = 0

local function RefreshActiveEvents()
    local now = time()
    if (now - lastEventCheck) < 300 then return end
    lastEventCheck = now
    wipe(activeEventsCache)
    local currentDate = C_DateAndTime.GetCurrentCalendarTime()
    if not currentDate then return end
    local numEvents = C_Calendar.GetNumDayEvents(0, currentDate.monthDay)
    for i = 1, numEvents do
        local event = C_Calendar.GetDayEvent(0, currentDate.monthDay, i)
        if event and event.eventID then
            activeEventsCache[event.eventID] = true
        end
    end
end

function TE:IsEventActive(eventID)
    if not eventID then return true end
    RefreshActiveEvents()
    return activeEventsCache[tonumber(eventID)] or false
end

function TE:HasProfession(baseSkillLineID)
    if not baseSkillLineID then return true end
    baseSkillLineID = tonumber(baseSkillLineID)
    if not baseSkillLineID then return true end
    local prof1, prof2 = GetProfessions()
    for _, idx in ipairs({ prof1, prof2 }) do
        if idx then
            local _, _, _, _, _, _, skillLineID = GetProfessionInfo(idx)
            if skillLineID == baseSkillLineID then return true end
        end
    end
    return false
end

function TE:IsStepVisible(step, section)
    if step and step.professionRequired and not self:HasProfession(step.professionRequired) then
        return false
    end
    if step and step.eventRequired and not self:IsEventActive(step.eventRequired) then
        return false
    end
    if section and section.professionRequired and not self:HasProfession(section.professionRequired) then
        return false
    end
    if section and section.eventRequired and not self:IsEventActive(section.eventRequired) then
        return false
    end
    return true
end

function TE:IsSectionVisible(section)
    if section and section.professionRequired and not self:HasProfession(section.professionRequired) then
        return false
    end
    if section and section.eventRequired and not self:IsEventActive(section.eventRequired) then
        return false
    end
    return true
end

local function BuildIndices()
    wipe(spellIndex)
    wipe(killIndex)
    wipe(lootIndex)
    wipe(npcIndex)

    local lists = TD:GetListsDB()
    for listID, list in pairs(lists) do
        for _, sec in ipairs(list.sections) do
            for _, step in ipairs(sec.steps or {}) do
                local tt = step.trackType
                local tp = step.trackParams or {}

                if tt == "spell_cast" and tp.spellID then
                    local sid = tonumber(tp.spellID)
                    if sid then
                        spellIndex[sid] = spellIndex[sid] or {}
                        tinsert(spellIndex[sid], { listID = listID, sectionKey = sec.key, stepKey = step.key, max = step.max })
                    end
                end

                if tt == "kill_count" and tp.creatureID then
                    local cid = tonumber(tp.creatureID)
                    if cid then
                        killIndex[cid] = killIndex[cid] or {}
                        tinsert(killIndex[cid], { listID = listID, sectionKey = sec.key, stepKey = step.key, max = step.max })
                    end
                end

                if tt == "loot_item" and tp.itemID then
                    local iid = tonumber(tp.itemID)
                    if iid then
                        lootIndex[iid] = lootIndex[iid] or {}
                        tinsert(lootIndex[iid], { listID = listID, sectionKey = sec.key, stepKey = step.key })
                    end
                end

                if tt == "npc_interact" and tp.npcID then
                    local nid = tonumber(tp.npcID)
                    if nid then
                        npcIndex[nid] = npcIndex[nid] or {}
                        tinsert(npcIndex[nid], { listID = listID, sectionKey = sec.key, stepKey = step.key })
                    end
                end

                for _, obj in ipairs(step.objectives or {}) do
                    local ot = obj.type
                    local op = obj.params or {}

                    if ot == "spell_cast" and op.spellID then
                        local sid = tonumber(op.spellID)
                        if sid then
                            spellIndex[sid] = spellIndex[sid] or {}
                            tinsert(spellIndex[sid], {
                                listID = listID, sectionKey = sec.key,
                                stepKey = step.key, objKey = obj.key,
                                max = tonumber(op.count) or 1,
                            })
                        end
                    end

                    if ot == "kill_count" and op.creatureID then
                        local cid = tonumber(op.creatureID)
                        if cid then
                            killIndex[cid] = killIndex[cid] or {}
                            tinsert(killIndex[cid], {
                                listID = listID, sectionKey = sec.key,
                                stepKey = step.key, objKey = obj.key,
                                max = tonumber(op.count) or 1,
                            })
                        end
                    end

                    if ot == "npc_interact" and op.npcID then
                        local nid = tonumber(op.npcID)
                        if nid then
                            npcIndex[nid] = npcIndex[nid] or {}
                            tinsert(npcIndex[nid], {
                                listID = listID, sectionKey = sec.key,
                                stepKey = step.key, objKey = obj.key,
                            })
                        end
                    end
                end
            end
        end
    end
end

function TE:EvaluateObjective(obj)
    if not obj then return nil end
    local ot = obj.type
    local op = obj.params or {}

    if ot == "manual" then
        return nil

    elseif ot == "quest" or ot == "rare_quest" then
        local qid = tonumber(op.questID)
        if qid then
            return C_QuestLog.IsQuestFlaggedCompleted(qid) and 1 or 0, 1
        end
        if op.questIDs then
            local done = 0
            for _, id in ipairs(op.questIDs) do
                if C_QuestLog.IsQuestFlaggedCompleted(tonumber(id)) then
                    done = done + 1
                end
            end
            return done, #op.questIDs
        end

    elseif ot == "quest_account" then
        local qid = tonumber(op.questID)
        if qid then
            if C_QuestLog.IsQuestFlaggedCompletedOnAccount then
                return C_QuestLog.IsQuestFlaggedCompletedOnAccount(qid) and 1 or 0, 1
            end
            return C_QuestLog.IsQuestFlaggedCompleted(qid) and 1 or 0, 1
        end
        if op.questIDs then
            local done = 0
            local checkFn = C_QuestLog.IsQuestFlaggedCompletedOnAccount or C_QuestLog.IsQuestFlaggedCompleted
            for _, id in ipairs(op.questIDs) do
                if checkFn(tonumber(id)) then
                    done = done + 1
                end
            end
            return done, #op.questIDs
        end

    elseif ot == "quest_pool" then
        if op.questIDs then
            local done = 0
            for _, id in ipairs(op.questIDs) do
                if C_QuestLog.IsQuestFlaggedCompleted(tonumber(id)) then
                    done = done + 1
                end
            end
            local pick = tonumber(op.pick) or #op.questIDs
            return done, pick
        end

    elseif ot == "quest_pool_account" then
        if op.questIDs then
            local done = 0
            local checkFn = C_QuestLog.IsQuestFlaggedCompletedOnAccount or C_QuestLog.IsQuestFlaggedCompleted
            for _, id in ipairs(op.questIDs) do
                if checkFn(tonumber(id)) then
                    done = done + 1
                end
            end
            local pick = tonumber(op.pick) or #op.questIDs
            return done, pick
        end

    elseif ot == "quest_progress" then
        local qid = tonumber(op.questID)
        local objIdx = tonumber(op.objectiveIndex) or 1
        if qid then
            if C_QuestLog.IsQuestFlaggedCompleted(qid) then
                local objectives = C_QuestLog.GetQuestObjectives(qid)
                if objectives and objectives[objIdx] then
                    return objectives[objIdx].numRequired or 1, objectives[objIdx].numRequired or 1
                end
                return 1, 1
            end
            local objectives = C_QuestLog.GetQuestObjectives(qid)
            if objectives and objectives[objIdx] then
                return objectives[objIdx].numFulfilled or 0, objectives[objIdx].numRequired or 1
            end
            return 0, 1
        end

    elseif ot == "quest_active" then
        local qid = tonumber(op.questID)
        if qid then
            return C_QuestLog.IsOnQuest(qid) and 1 or 0, 1
        end

    elseif ot == "quest_world" then
        local qid = tonumber(op.questID)
        if qid then
            if C_QuestLog.IsQuestFlaggedCompleted(qid) then return 1, 1 end
            if C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(qid) then
                return 0, 1
            end
            return 0, 1
        end

    elseif ot == "level" then
        local req = tonumber(op.level) or 1
        local current = UnitLevel("player") or 1
        return current, req

    elseif ot == "item" then
        local itemID = tonumber(op.itemID)
        local needed = tonumber(op.count) or 1
        if itemID then
            local count = C_Item.GetItemCount(itemID, true) or 0
            return count, needed
        end

    elseif ot == "currency" then
        local currID = tonumber(op.currencyID)
        local needed = tonumber(op.amount) or 0
        if currID then
            local info = C_CurrencyInfo.GetCurrencyInfo(currID)
            if info then
                local current = info.quantity or 0
                if needed == 0 then
                    local weekCap = info.maxWeeklyQuantity or 0
                    local totalCap = info.maxQuantity or 0
                    local dynamicCap = (weekCap > 0) and weekCap or totalCap
                    if dynamicCap > 0 then
                        return current, dynamicCap
                    end
                    return current, 0
                end
                return current, needed
            end
        end

    elseif ot == "achievement" then
        local achID = tonumber(op.achievementID)
        if achID then
            local _, _, _, completed = GetAchievementInfo(achID)
            return completed and 1 or 0, 1
        end

    elseif ot == "reputation" then
        local factionID = tonumber(op.factionID)
        local reqStanding = tonumber(op.standing) or 6
        if factionID then
            local data = C_Reputation.GetFactionDataByID(factionID)
            if data then
                return data.currentStanding or 0, reqStanding
            end
        end

    elseif ot == "renown" then
        local factionID = tonumber(op.factionID)
        local reqLevel = tonumber(op.level) or 1
        if factionID then
            local data = C_MajorFactions.GetMajorFactionData(factionID)
            if data then
                return data.renownLevel or 0, reqLevel
            end
        end

    elseif ot == "spell_known" then
        local spellID = tonumber(op.spellID)
        if spellID then
            return IsSpellKnown(spellID) and 1 or 0, 1
        end

    elseif ot == "spell_cast" then
        return nil

    elseif ot == "ilvl" then
        local req = tonumber(op.ilvl) or 1
        local current = select(2, GetAverageItemLevel()) or 0
        return math.floor(current), req

    elseif ot == "location" then
        local mapID = tonumber(op.mapID)
        if mapID then
            local currentMap = C_Map.GetBestMapForUnit("player")
            return (currentMap == mapID) and 1 or 0, 1
        end

    elseif ot == "coordinates" then
        local mapID = tonumber(op.mapID)
        local tx = tonumber(op.x)
        local ty = tonumber(op.y)
        local radius = tonumber(op.radius) or 15
        if mapID and tx and ty then
            local currentMap = C_Map.GetBestMapForUnit("player")
            if currentMap == mapID then
                local pos = C_Map.GetPlayerMapPosition(currentMap, "player")
                if pos then
                    local px, py = pos:GetXY()
                    px = px * 100
                    py = py * 100
                    local dx = px - tx
                    local dy = py - ty
                    local dist = math.sqrt(dx * dx + dy * dy)
                    return (dist <= radius) and 1 or 0, 1
                end
            end
            return 0, 1
        end

    elseif ot == "npc_interact" then
        return nil

    elseif ot == "kill_count" then
        return nil

    elseif ot == "loot_item" then
        return nil

    elseif ot == "toy" then
        local itemID = tonumber(op.itemID)
        if itemID then
            return PlayerHasToy(itemID) and 1 or 0, 1
        end

    elseif ot == "mount" then
        local mountID = tonumber(op.mountID)
        if mountID then
            local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            return isCollected and 1 or 0, 1
        end

    elseif ot == "pet" then
        local speciesID = tonumber(op.speciesID)
        if speciesID then
            local numCollected, limit = C_PetJournal.GetNumCollectedInfo(speciesID)
            return numCollected or 0, 1
        end

    elseif ot == "transmog" then
        local appearanceID = tonumber(op.itemModifiedAppearanceID)
        if appearanceID then
            return C_TransmogCollection.PlayerHasTransmog(appearanceID) and 1 or 0, 1
        end

    elseif ot == "buff" then
        local spellID = tonumber(op.spellID)
        if spellID then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
            return aura and 1 or 0, 1
        end

    elseif ot == "exploration" then
        local areaID = tonumber(op.areaID)
        if areaID then
            local mapID = C_Map.GetBestMapForUnit("player")
            if mapID then
                local explored = C_MapExplorationInfo.GetExploredMapTextures(mapID)
                if explored then
                    for _, info in ipairs(explored) do
                        if info.textureWidth and info.textureHeight then
                            return 1, 1
                        end
                    end
                end
            end
            return 0, 1
        end

    elseif ot == "vault_raid" then
        local activities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Raid)
        if activities then
            local best = 0
            for _, act in ipairs(activities) do
                if act.progress > best then best = act.progress end
            end
            local maxNeeded = activities[1] and activities[1].threshold or 1
            return best, maxNeeded
        end

    elseif ot == "vault_dungeon" then
        local activities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.MythicPlus)
        if activities then
            local best = 0
            for _, act in ipairs(activities) do
                if act.progress > best then best = act.progress end
            end
            local maxNeeded = activities[1] and activities[1].threshold or 1
            return best, maxNeeded
        end

    elseif ot == "vault_world" then
        local activities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World)
        if activities then
            local best = 0
            for _, act in ipairs(activities) do
                if act.progress > best then best = act.progress end
            end
            local maxNeeded = activities[1] and activities[1].threshold or 1
            return best, maxNeeded
        end

    elseif ot == "prof_skill" then
        local baseID = tonumber(op.baseSkillLineID)
        if baseID then
            local prof1, prof2 = GetProfessions()
            for _, idx in ipairs({ prof1, prof2 }) do
                if idx then
                    local name, icon, skillLevel, maxSkillLevel, numAbilities, spellOffset, skillLineID = GetProfessionInfo(idx)
                    if skillLineID == baseID then
                        return skillLevel or 0, maxSkillLevel or 1
                    end
                end
            end
        end

    elseif ot == "prof_concentration" then
        local currID = tonumber(op.currencyID)
        if currID then
            local info = C_CurrencyInfo.GetCurrencyInfo(currID)
            if info then
                return info.quantity or 0, info.maxQuantity or 1000
            end
        end

    elseif ot == "prof_knowledge" then
        local skillLineVariantID = tonumber(op.skillLineVariantID)
        if skillLineVariantID then
            local configID = C_ProfSpecs and C_ProfSpecs.GetConfigIDForSkillLine and C_ProfSpecs.GetConfigIDForSkillLine(skillLineVariantID)
            if configID then
                local configInfo = C_Traits.GetConfigInfo(configID)
                if configInfo and configInfo.treeIDs then
                    local treeID = configInfo.treeIDs[1]
                    if treeID then
                        local nodes = C_Traits.GetTreeNodes(treeID)
                        local totalSpent = 0
                        if nodes then
                            for _, nodeID in ipairs(nodes) do
                                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                                if nodeInfo and nodeInfo.currentRank then
                                    totalSpent = totalSpent + nodeInfo.currentRank
                                end
                            end
                        end
                        local currencyInfo = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
                        local unspent = 0
                        if currencyInfo then
                            for _, ci in ipairs(currencyInfo) do
                                unspent = unspent + (ci.quantity or 0)
                            end
                        end
                        return totalSpent + unspent, 0
                    end
                end
            end
        end

    elseif ot == "prof_firstcraft" then
        local spellIDs = op.spellIDs or (op.spellID and { op.spellID }) or {}
        local done = 0
        for _, sid in ipairs(spellIDs) do
            sid = tonumber(sid)
            if sid and C_TradeSkillUI.IsRecipeFirstCraft(sid) == false then
                done = done + 1
            end
        end
        return done, #spellIDs

    elseif ot == "prof_catchup" then
        local currID = tonumber(op.currencyID)
        if currID then
            local info = C_CurrencyInfo.GetCurrencyInfo(currID)
            if info then
                local max = info.maxQuantity or 0
                if max > 0 then
                    return info.quantity or 0, max
                end
                return info.quantity or 0, 0
            end
        end

    elseif ot == "campaign" then
        local campaignID = tonumber(op.campaignID)
        if campaignID and C_CampaignInfo then
            local info = C_CampaignInfo.GetCampaignInfo(campaignID)
            if info then
                if info.complete then return 1, 1 end
                local chapters = C_CampaignInfo.GetChapterIDs(campaignID)
                if chapters then
                    local done = 0
                    for _, chapterID in ipairs(chapters) do
                        local chapterInfo = C_CampaignInfo.GetCampaignChapterInfo(chapterID)
                        if chapterInfo and chapterInfo.completed then
                            done = done + 1
                        end
                    end
                    return done, #chapters
                end
            end
        end

    elseif ot == "custom_timer" then
        return nil
    end

    return nil
end

function TE:EvaluateStep(listID, sectionKey, step)
    if not step then return end

    if step.objectives and #step.objectives > 0 then
        local allComplete = true
        for _, obj in ipairs(step.objectives) do
            local current, max = self:EvaluateObjective(obj)
            if current ~= nil then
                local complete = max and max > 0 and current >= max
                TD:SetObjectiveComplete(listID, sectionKey, step.key, obj.key, complete)
                if not complete then allComplete = false end
            else
                if not TD:GetObjectiveProgress(listID, sectionKey, step.key, obj.key) then
                    allComplete = false
                end
            end
        end

        local sp = TD:GetStepProgress(listID, sectionKey, step.key)
        sp.completed = allComplete
        sp.current = allComplete and 1 or 0
    else
        local current, max = self:EvaluateObjective({
            type = step.trackType,
            params = step.trackParams or {},
        })

        if current ~= nil then
            local sp = TD:GetStepProgress(listID, sectionKey, step.key)
            sp.current = current
            local effectiveMax = step.noMax and 0 or (step.max or 1)
            if effectiveMax > 0 and current >= effectiveMax then
                sp.completed = true
            elseif effectiveMax > 0 then
                sp.completed = false
            end
        end
    end
end

function TE:FullScan()
    local now = time()
    if (now - lastScanTime) < SCAN_THROTTLE then return end
    lastScanTime = now

    local lists = TD:GetListsDB()
    for listID, list in pairs(lists) do
        for _, sec in ipairs(list.sections) do
            if self:IsSectionVisible(sec) then
                for _, step in ipairs(sec.steps or {}) do
                    if self:IsStepVisible(step, sec) then
                        if step.trackType ~= "manual" and step.trackType ~= "spell_cast" and
                           step.trackType ~= "kill_count" and step.trackType ~= "npc_interact" and
                           step.trackType ~= "loot_item" then
                            self:EvaluateStep(listID, sec.key, step)
                        end

                        if step.objectives then
                            for _, obj in ipairs(step.objectives) do
                                if obj.type ~= "manual" and obj.type ~= "spell_cast" and
                                   obj.type ~= "kill_count" and obj.type ~= "npc_interact" and
                                   obj.type ~= "loot_item" then
                                    local current, max = self:EvaluateObjective(obj)
                                    if current ~= nil then
                                        local complete = max and max > 0 and current >= max
                                        TD:SetObjectiveComplete(listID, sec.key, step.key, obj.key, complete)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    FireCallbacks("OnScanComplete")
    self:RefreshAllPinnedWindows()
end

local function OnSpellCast(spellID)
    spellID = tonumber(spellID)
    if not spellID or not spellIndex[spellID] then return end

    for _, ref in ipairs(spellIndex[spellID]) do
        if ref.objKey then
            local sp = TD:GetStepProgress(ref.listID, ref.sectionKey, ref.stepKey)
            sp.objectives = sp.objectives or {}
            local prev = sp.objectives[ref.objKey]
            if not prev then
                TD:SetObjectiveComplete(ref.listID, ref.sectionKey, ref.stepKey, ref.objKey, true)
            end
        else
            TD:BumpStepProgress(ref.listID, ref.sectionKey, ref.stepKey, 1, ref.max)
        end
    end

    FireCallbacks("OnProgressChanged")
    TE:RefreshAllPinnedWindows()
end

local function OnCreatureKill(creatureID)
    creatureID = tonumber(creatureID)
    if not creatureID or not killIndex[creatureID] then return end

    for _, ref in ipairs(killIndex[creatureID]) do
        if ref.objKey then
            TD:SetObjectiveComplete(ref.listID, ref.sectionKey, ref.stepKey, ref.objKey, true)
        else
            TD:BumpStepProgress(ref.listID, ref.sectionKey, ref.stepKey, 1, ref.max)
        end
    end

    FireCallbacks("OnProgressChanged")
    TE:RefreshAllPinnedWindows()
end

local function OnItemLooted(itemID)
    itemID = tonumber(itemID)
    if not itemID or not lootIndex[itemID] then return end

    for _, ref in ipairs(lootIndex[itemID]) do
        if ref.objKey then
            TD:SetObjectiveComplete(ref.listID, ref.sectionKey, ref.stepKey, ref.objKey, true)
        else
            TD:BumpStepProgress(ref.listID, ref.sectionKey, ref.stepKey, 1, 1)
        end
    end

    FireCallbacks("OnProgressChanged")
    TE:RefreshAllPinnedWindows()
end

local function OnNPCInteract(npcID)
    npcID = tonumber(npcID)
    if not npcID or not npcIndex[npcID] then return end

    for _, ref in ipairs(npcIndex[npcID]) do
        if ref.objKey then
            TD:SetObjectiveComplete(ref.listID, ref.sectionKey, ref.stepKey, ref.objKey, true)
        else
            TD:BumpStepProgress(ref.listID, ref.sectionKey, ref.stepKey, 1, 1)
        end
    end

    FireCallbacks("OnProgressChanged")
    TE:RefreshAllPinnedWindows()
end

local function OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        TD:CheckResets()
        TD:CheckCustomTimerResets()
        BuildIndices()
        C_Timer.After(2, function() TE:FullScan() end)
        C_Timer.After(3, function()
            if C_Calendar and C_Calendar.OpenCalendar then
                C_Calendar.OpenCalendar()
            end
        end)
        TE:RestorePinnedWindows()

    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_TURNED_IN" then
        C_Timer.After(0.5, function() TE:FullScan() end)

    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        C_Timer.After(0.5, function() TE:FullScan() end)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if unit == "player" and spellID then
            OnSpellCast(spellID)
        end

    elseif event == "CHAT_MSG_LOOT" then
        local msg = ...
        if msg then
            local itemID = msg:match("item:(%d+)")
            if itemID then
                OnItemLooted(itemID)
            end
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        local targetGUID = UnitGUID("target")
        if targetGUID and UnitIsDead("target") then
            local npcType, _, _, _, _, npcID = strsplit("-", targetGUID)
            if npcType == "Creature" then
                OnCreatureKill(npcID)
            end
        end

    elseif event == "GOSSIP_SHOW" then
        local npcGUID = UnitGUID("npc")
        if npcGUID then
            local npcType, _, _, _, _, npcID = strsplit("-", npcGUID)
            if npcType == "Creature" then
                OnNPCInteract(npcID)
            end
        end

    elseif event == "WEEKLY_REWARDS_UPDATE" or event == "CHALLENGE_MODE_COMPLETED" or event == "ENCOUNTER_END" then
        C_Timer.After(1, function() TE:FullScan() end)

    elseif event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" or event == "UPDATE_FACTION" then
        C_Timer.After(0.5, function() TE:FullScan() end)

    elseif event == "BAG_UPDATE_DELAYED" then
        C_Timer.After(0.5, function() TE:FullScan() end)

    elseif event == "PLAYER_LEVEL_UP" then
        C_Timer.After(0.5, function() TE:FullScan() end)

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
        C_Timer.After(1, function() TE:FullScan() end)

    elseif event == "SKILL_LINES_CHANGED" or event == "TRAIT_TREE_CURRENCY_INFO_UPDATED" then
        C_Timer.After(0.5, function() TE:FullScan() end)

    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        C_Timer.After(0.5, function() TE:FullScan() end)

    elseif event == "NEW_TOY_ADDED" or event == "NEW_MOUNT_ADDED" or event == "NEW_PET_ADDED" then
        C_Timer.After(0.5, function() TE:FullScan() end)

    elseif event == "TRANSMOG_COLLECTION_UPDATED" then
        C_Timer.After(0.5, function() TE:FullScan() end)

    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            C_Timer.After(0.2, function() TE:FullScan() end)
        end

    elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
        lastEventCheck = 0
        C_Timer.After(1, function() TE:FullScan() end)
    end
end

local function EnsureEventFrame()
    if not eventFrame then
        eventFrame = CreateFrame("Frame", "OneWoW_Notes_TrackerEngineFrame", UIParent)
        eventFrame:Hide()
    end
    return eventFrame
end

function TE:Initialize()
    TD = ns.TrackerData
    if not TD then return end
    if initialized then return end
    initialized = true

    local frame = EnsureEventFrame()
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:RegisterEvent("GOSSIP_SHOW")
    frame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    frame:RegisterEvent("ENCOUNTER_END")
    frame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    frame:RegisterEvent("UPDATE_FACTION")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("SKILL_LINES_CHANGED")
    frame:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED")
    frame:RegisterEvent("TRADE_SKILL_SHOW")
    frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
    frame:RegisterEvent("NEW_TOY_ADDED")
    frame:RegisterEvent("NEW_MOUNT_ADDED")
    frame:RegisterEvent("NEW_PET_ADDED")
    frame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    frame:RegisterEvent("UNIT_AURA")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")

    frame:SetScript("OnEvent", OnEvent)

    BuildIndices()

    C_Timer.NewTicker(30, function()
        TD:CheckCustomTimerResets()
    end)
end

function TE:RebuildIndices()
    BuildIndices()
end

function TE:CreatePinnedWindow(listID)
    if not ns.TrackerPinned then return end
    local list = TD:GetList(listID)
    if not list then return end

    if pinnedWindows[listID] then
        pinnedWindows[listID]:Show()
        return pinnedWindows[listID]
    end

    local win = ns.TrackerPinned:Create(listID)
    if win then
        pinnedWindows[listID] = win
        list.pinned = true
    end
    return win
end

function TE:DestroyPinnedWindow(listID)
    if pinnedWindows[listID] then
        pinnedWindows[listID]:Hide()
        pinnedWindows[listID] = nil
    end
    local list = TD:GetList(listID)
    if list then
        list.pinned = false
    end
end

function TE:GetPinnedWindow(listID)
    return pinnedWindows[listID]
end

function TE:RefreshAllPinnedWindows()
    for listID, win in pairs(pinnedWindows) do
        if win and win.Refresh then
            win:Refresh()
        end
    end
end

function TE:RestorePinnedWindows()
    local lists = TD:GetListsDB()
    for listID, list in pairs(lists) do
        if list.pinned then
            C_Timer.After(1, function()
                TE:CreatePinnedWindow(listID)
            end)
        end
    end
end

function TE:GetTrackTypeDisplayName(trackType)
    local L = ns.L
    local names = {
        manual          = L["TRACKER_TYPE_MANUAL"] or "Manual",
        quest           = L["TRACKER_TYPE_QUEST"] or "Quest",
        quest_account   = L["TRACKER_TYPE_QUEST_ACCOUNT"] or "Quest (Account)",
        quest_pool      = L["TRACKER_TYPE_QUEST_POOL"] or "Quest Pool",
        quest_pool_account = L["TRACKER_TYPE_QUEST_POOL_ACCOUNT"] or "Quest Pool (Account)",
        quest_progress  = L["TRACKER_TYPE_QUEST_PROGRESS"] or "Quest Progress",
        quest_active    = L["TRACKER_TYPE_QUEST_ACTIVE"] or "Quest Active",
        quest_world     = L["TRACKER_TYPE_QUEST_WORLD"] or "World Quest",
        level           = L["TRACKER_TYPE_LEVEL"] or "Level",
        item            = L["TRACKER_TYPE_ITEM"] or "Item",
        currency        = L["TRACKER_TYPE_CURRENCY"] or "Currency",
        achievement     = L["TRACKER_TYPE_ACHIEVEMENT"] or "Achievement",
        reputation      = L["TRACKER_TYPE_REPUTATION"] or "Reputation",
        renown          = L["TRACKER_TYPE_RENOWN"] or "Renown",
        spell_known     = L["TRACKER_TYPE_SPELL_KNOWN"] or "Spell Known",
        spell_cast      = L["TRACKER_TYPE_SPELL_CAST"] or "Spell Cast",
        ilvl            = L["TRACKER_TYPE_ILVL"] or "Item Level",
        location        = L["TRACKER_TYPE_LOCATION"] or "Zone",
        coordinates     = L["TRACKER_TYPE_COORDINATES"] or "Coordinates",
        npc_interact    = L["TRACKER_TYPE_NPC_INTERACT"] or "NPC Interact",
        kill_count      = L["TRACKER_TYPE_KILL_COUNT"] or "Kill Count",
        loot_item       = L["TRACKER_TYPE_LOOT_ITEM"] or "Loot Item",
        toy             = L["TRACKER_TYPE_TOY"] or "Toy",
        mount           = L["TRACKER_TYPE_MOUNT"] or "Mount",
        pet             = L["TRACKER_TYPE_PET"] or "Battle Pet",
        transmog        = L["TRACKER_TYPE_TRANSMOG"] or "Transmog",
        buff            = L["TRACKER_TYPE_BUFF"] or "Buff",
        exploration     = L["TRACKER_TYPE_EXPLORATION"] or "Exploration",
        vault_raid      = L["TRACKER_TYPE_VAULT_RAID"] or "Vault: Raid",
        vault_dungeon   = L["TRACKER_TYPE_VAULT_DUNGEON"] or "Vault: Dungeon",
        vault_world     = L["TRACKER_TYPE_VAULT_WORLD"] or "Vault: World",
        prof_skill      = L["TRACKER_TYPE_PROF_SKILL"] or "Prof. Skill",
        prof_concentration = L["TRACKER_TYPE_PROF_CONC"] or "Concentration",
        prof_knowledge  = L["TRACKER_TYPE_PROF_KNOW"] or "Prof. Knowledge",
        prof_firstcraft = L["TRACKER_TYPE_PROF_FIRST"] or "First Craft",
        prof_catchup    = L["TRACKER_TYPE_PROF_CATCHUP"] or "Catchup Currency",
        rare_quest      = L["TRACKER_TYPE_RARE_QUEST"] or "Rare Quest",
        custom_timer    = L["TRACKER_TYPE_CUSTOM_TIMER"] or "Custom Timer",
        campaign        = L["TRACKER_TYPE_CAMPAIGN"] or "Campaign",
    }
    return names[trackType] or trackType
end

function TE:GetListTypeDisplayName(listType)
    local L = ns.L
    local names = {
        guide     = L["TRACKER_LIST_GUIDE"] or "Guide",
        daily     = L["TRACKER_LIST_DAILY"] or "Daily",
        weekly    = L["TRACKER_LIST_WEEKLY"] or "Weekly",
        todo      = L["TRACKER_LIST_TODO"] or "To-Do",
        repeating = L["TRACKER_LIST_REPEATING"] or "Repeating",
    }
    return names[listType] or listType
end

function TE:BuildStepTooltip(tooltip, listID, sectionKey, step)
    if not tooltip or not step then return end

    tooltip:AddLine(step.label or "Step", 1, 1, 1)

    if step.description and step.description ~= "" then
        tooltip:AddLine(step.description, 0.7, 0.7, 0.7, true)
    end

    local tt = step.trackType or "manual"
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("Track Type:", self:GetTrackTypeDisplayName(tt), 0.5, 0.5, 0.5, 1, 0.82, 0)

    if tt ~= "manual" then
        local current, max = self:EvaluateObjective({
            type = tt,
            params = step.trackParams or {},
        })
        if current then
            tooltip:AddDoubleLine("Current:", format("%d / %s", current, max and tostring(max) or "?"), 0.5, 0.5, 0.5, 1, 1, 1)
        end
    end

    local sp = TD:GetStepProgress(listID, sectionKey, step.key)
    if sp.completed then
        tooltip:AddLine("Status: Complete", 0.4, 0.8, 0.4)
    else
        tooltip:AddLine("Status: In Progress", 1, 0.82, 0)
    end

    local list = TD:GetList(listID)
    local sec = TD:GetSection(listID, sectionKey)
    local resetType = TD:GetEffectiveResetType(list, sec, step)
    if resetType ~= "todo" then
        tooltip:AddDoubleLine("Reset:", self:GetListTypeDisplayName(resetType), 0.5, 0.5, 0.5, 0.7, 0.7, 0.7)
    end

    if step.mapID then
        local mapInfo = C_Map.GetMapInfo(step.mapID)
        if mapInfo then
            tooltip:AddDoubleLine("Location:", mapInfo.name, 0.5, 0.5, 0.5, 0.7, 0.7, 0.7)
        end
        if step.coordX and step.coordY then
            tooltip:AddDoubleLine("Coords:", format("%.1f, %.1f", step.coordX, step.coordY), 0.5, 0.5, 0.5, 0.7, 0.7, 0.7)
        end
    end

    if step.objectives and #step.objectives > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("Objectives:", 1, 0.82, 0)
        for _, obj in ipairs(step.objectives) do
            local complete = TD:GetObjectiveProgress(listID, sectionKey, step.key, obj.key)
            local prefix = complete and "|cFF66CC66Done|r" or "|cFFFF6666Todo|r"
            tooltip:AddDoubleLine("  " .. (obj.description or obj.type), prefix, 0.8, 0.8, 0.8)
        end
    end
end
