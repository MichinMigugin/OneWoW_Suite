local _, ns = ...

local ipairs = ipairs
local tinsert = tinsert
local C_QuestLog, C_QuestInfoSystem = C_QuestLog, C_QuestInfoSystem
local C_Map, C_Timer = C_Map, C_Timer

ns.QuestScanner = {}
local QuestScanner = ns.QuestScanner

local SCAN_BATCH_SIZE  = 50
local SCAN_BATCH_DELAY = 0.1
local pendingQuestDetails = {}
local EnsureNotesNPC

local INTERNAL_PATTERNS = {
    "tracking quest",
    "^decor ",
    "^deprecated",
    "^test ",
    "^qa ",
}

local BOARD_QUEST_PATTERNS = {
    "^hero's call:",
    "^warchief's command:",
    "^adventurers wanted:",
}

local BOARD_SOURCE_PATTERNS = {
    "call board",
    "command board",
    "adventure guide",
}

local function IsInternalQuest(name, info)
    if not name then return true end
    if info and info.isHidden then return true end
    local lower = name:lower()
    for _, pattern in ipairs(INTERNAL_PATTERNS) do
        if lower:find(pattern) then return true end
    end
    return false
end

local function MatchesAnyPattern(value, patterns)
    if not value then
        return false
    end

    local lower = tostring(value):lower()
    for _, pattern in ipairs(patterns) do
        if lower:find(pattern) then
            return true
        end
    end

    return false
end

local function IsBoardSourcedQuest(name, sourceName)
    return MatchesAnyPattern(name, BOARD_QUEST_PATTERNS)
        or MatchesAnyPattern(sourceName, BOARD_SOURCE_PATTERNS)
end

local function GetQuestLogIndex(questID)
    local count = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, count do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID == questID then
            return i
        end
    end
    return nil
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then
        return a, b, c, d, e, f, g, h
    end

    return nil
end

local function SafeCallResults(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local results = { pcall(fn, ...) }
    if not results[1] then
        return nil
    end

    table.remove(results, 1)
    return results
end

local function AddUnique(tbl, value)
    if not value then return end
    for _, existing in ipairs(tbl) do
        if existing == value then
            return
        end
    end
    tinsert(tbl, value)
end

local function EnsureList(data, field)
    data[field] = data[field] or {}
    return data[field]
end

local function AddFlag(data, flag)
    AddUnique(EnsureList(data, "flags"), flag)
end

local function AddCategory(data, category)
    AddUnique(EnsureList(data, "categories"), category)
end

local function GetCurrencyMetadata(currencyID)
    local info =
        currencyID
        and C_CurrencyInfo
        and C_CurrencyInfo.GetCurrencyInfo
        and SafeCall(C_CurrencyInfo.GetCurrencyInfo, currencyID)

    if info then
        return info.name, info.iconFileID
    end

    return nil, nil
end

local function AddRewardCurrency(data, currencyID, quantity, icon, name)
    currencyID = tonumber(currencyID)
    if not currencyID or currencyID <= 0 then
        return
    end

    local metaName, metaIcon = GetCurrencyMetadata(currencyID)
    name = name or metaName
    icon = icon or metaIcon

    local currencies = EnsureList(data, "rewardCurrencies")
    for _, currency in ipairs(currencies) do
        if type(currency) == "table"
            and tonumber(currency.currencyID or currency.id) == currencyID
        then
            currency.quantity = quantity or currency.quantity or 1
            currency.icon = icon or currency.icon
            currency.name = name or currency.name
            return
        end
    end

    tinsert(currencies, {
        currencyID = currencyID,
        quantity = quantity or 1,
        icon = icon,
        name = name,
    })
end

local function HasUsefulResults(results)
    if not results then return false end
    for i = 1, 8 do
        local value = results[i]
        if value ~= nil and value ~= false and value ~= "" and value ~= 0 then
            return true
        end
    end
    return false
end

local function CaptureRewardSpellFromCall(data, fn, ...)
    local results = SafeCallResults(fn, ...)
    if not HasUsefulResults(results) then
        return
    end

    local spell = {}
    for i = 1, 8 do
        local value = results[i]
        if type(value) == "string" and value ~= "" and not spell.name then
            spell.name = value
        elseif type(value) == "number" and value > 0 then
            if value > 1000 and not spell.spellID then
                spell.spellID = value
            elseif not spell.texture then
                spell.texture = value
            end
        elseif type(value) == "boolean" then
            spell.isTradeskill = value
        end
    end

    data.rewardSpell = spell
end

local function CaptureSpecialQuestItem(data, logIndex)
    local itemLink, texture, charges, showItemWhenComplete =
        SafeCall(GetQuestLogSpecialItemInfo, logIndex)

    if not itemLink then
        return
    end

    local itemID =
        type(itemLink) == "string"
        and tonumber(itemLink:match("item:(%d+)"))

    data.specialItem = {
        itemID = itemID,
        link = itemLink,
        texture = texture,
        charges = charges,
        showItemWhenComplete = showItemWhenComplete and true or false,
    }
end

local function GetMapName(mapID)
    local mapInfo =
        mapID
        and C_Map
        and C_Map.GetMapInfo
        and SafeCall(C_Map.GetMapInfo, mapID)

    return mapInfo and mapInfo.name or nil
end

local function AddCurrentPlayerCoords(data, mapID)
    if not mapID
        or not C_Map
        or not C_Map.GetPlayerMapPosition
    then
        return
    end

    local pos = SafeCall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not pos or not pos.GetXY then
        return
    end

    local x, y = pos:GetXY()
    if not x or not y then
        return
    end

    data.coords = data.coords or {
        mapID = mapID,
        x = x * 100,
        y = y * 100,
    }
end

local function NormalizeName(name)
    if not name then
        return nil
    end

    name = tostring(name):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        return nil
    end

    return name:lower()
end

local function NamesMatch(a, b)
    local na = NormalizeName(a)
    local nb = NormalizeName(b)

    return na and nb and na == nb
end

local function GetQuestFrameSourceName()
    local fs =
        _G.QuestFrameNpcNameText
        or _G.QuestFrameNpcName

    if fs and fs.GetText then
        local name = SafeCall(fs.GetText, fs)
        if name and name ~= "" then
            return name
        end
    end

    return nil
end

local function GetTargetNPCData()
    local notes = _G.OneWoW_Notes
    local targetInfo =
        notes
        and notes.NPCs
        and notes.NPCs.GetTargetNPCInfo
        and notes.NPCs:GetTargetNPCInfo()

    if not (targetInfo and targetInfo.id) then
        return nil
    end

    local npcData = {
        npcID = targetInfo.id,
        npcName = targetInfo.name,
        name = targetInfo.name,
        mapID = targetInfo.mapID,
        zoneName = targetInfo.zone,
    }

    if targetInfo.coords then
        npcData.x = targetInfo.coords.x
        npcData.y = targetInfo.coords.y
    end

    return npcData, targetInfo
end

local function CaptureTargetNPC(data, field, expectedName)
    local npcData = GetTargetNPCData()
    if not npcData then
        return "none"
    end

    if expectedName and not NamesMatch(npcData.npcName, expectedName) then
        data[field] = {}

        if field == "starts" then
            data.questGiverID = false
            data.questGiverName = false
            data.questGiverCleared = true
        elseif field == "ends" then
            data.questTurnInID = false
            data.questTurnInName = false
            data.questTurnInCleared = true
        end

        return "mismatch"
    end

    data[field] = data[field] or {}
    data[field][1] = npcData

    if field == "starts" then
        data.questGiverID = npcData.npcID
        data.questGiverName = npcData.npcName
    elseif field == "ends" then
        data.questTurnInID = npcData.npcID
        data.questTurnInName = npcData.npcName
    end

    if npcData.mapID and not data.mapID then
        data.mapID = npcData.mapID
        data.zoneName = GetMapName(npcData.mapID) or npcData.zoneName or data.zoneName
    end

    if npcData.mapID and npcData.x and npcData.y then
        data.coords = data.coords or {
            mapID = npcData.mapID,
            x = npcData.x,
            y = npcData.y,
        }
    end

    return "captured"
end

local function MarkNPCFieldCleared(data, field)
    data[field] = {}

    if field == "starts" then
        data.questGiverID = false
        data.questGiverName = false
        data.questGiverCleared = true
    elseif field == "ends" then
        data.questTurnInID = false
        data.questTurnInName = false
        data.questTurnInCleared = true
    end
end

local function CaptureMapData(data, questID, capturePlayerCoords)
    local mapID =
        SafeCall(GetQuestUiMapID, questID)
        or (
            C_QuestLog
            and C_QuestLog.GetQuestUiMapID
            and SafeCall(C_QuestLog.GetQuestUiMapID, questID)
        )

    if mapID and mapID ~= 0 then
        data.mapID = mapID
        data.zoneName = GetMapName(mapID) or data.zoneName

        if capturePlayerCoords then
            AddCurrentPlayerCoords(data, mapID)
        end
    end
end

local function CaptureQuestLogFields(data, logInfo)
    if not logInfo then
        return
    end

    local valueFields = {
        "level",
        "requiredLevel",
        "difficultyLevel",
        "suggestedGroup",
        "campaignID",
        "frequency",
        "overridesSortOrder",
    }

    local boolFields = {
        "isHeader",
        "isHidden",
        "isTask",
        "isBounty",
        "isStory",
        "isOnMap",
        "hasLocalPOI",
        "isDisabled",
        "startEvent",
        "readyForTranslation",
        "isScaling",
        "isComplete",
        "isAutoComplete",
        "isLegendary",
        "useMinimalHeader",
        "sortAsNormalQuest",
    }

    for _, field in ipairs(valueFields) do
        if logInfo[field] ~= nil then
            data[field] = logInfo[field]
        end
    end

    for _, field in ipairs(boolFields) do
        if logInfo[field] ~= nil then
            data[field] = logInfo[field] and true or false
        end
    end

    data.suggestedGroup = data.suggestedGroup or 0

    if data.isTask then AddCategory(data, "task") end
    if data.isBounty then AddCategory(data, "bounty") end
    if data.isStory then AddCategory(data, "story") end
    if data.isHidden then AddFlag(data, "hidden") end
    if data.isScaling then AddFlag(data, "scaling") end
    if data.isAutoComplete then AddFlag(data, "auto_complete") end
    if data.hasLocalPOI then AddFlag(data, "local_poi") end
    if data.isOnMap then AddFlag(data, "on_map") end
    if data.isDisabled then AddFlag(data, "disabled") end
    if data.startEvent then AddFlag(data, "start_event") end
end

local function CaptureRewardItemsFromQuestDialog(data)
    local rewardItems = EnsureList(data, "rewardItems")
    local rewardChoices = EnsureList(data, "rewardChoices")

    local numRewards = SafeCall(GetNumQuestRewards) or 0
    for i = 1, numRewards do
        local _, _, _, _, _, itemID = SafeCall(GetQuestItemInfo, "reward", i)
        AddUnique(rewardItems, itemID)
    end

    local numChoices = SafeCall(GetNumQuestChoices) or 0
    for i = 1, numChoices do
        local _, _, _, _, _, itemID = SafeCall(GetQuestItemInfo, "choice", i)
        if itemID then
            AddUnique(rewardChoices, itemID)
            AddUnique(rewardItems, itemID)
        end
    end

    if #rewardItems == 0 then data.rewardItems = nil end
    if #rewardChoices == 0 then data.rewardChoices = nil end
end

local function CaptureRewardItemsFromQuestLog(data, questID)
    local numRewards = SafeCall(GetNumQuestLogRewards, questID)

    if numRewards and numRewards > 0 then
        local items = data.rewardItems or {}

        for i = 1, numRewards do
            local _, _, quantity, _, _, itemID =
                SafeCall(GetQuestLogRewardInfo, i, questID)

            if itemID then
                AddUnique(items, itemID)
            end
        end

        if #items > 0 then
            data.rewardItems = items
        end
    end

    local numChoices = SafeCall(GetNumQuestLogChoices, questID) or 0
    if numChoices > 0 then
        local choices = data.rewardChoices or {}
        local items = data.rewardItems or {}

        for i = 1, numChoices do
            local _, _, quantity, _, _, itemID =
                SafeCall(GetQuestLogChoiceInfo, i, questID)

            if itemID then
                AddUnique(choices, itemID)
                AddUnique(items, itemID)
            end
        end

        if #choices > 0 then
            data.rewardChoices = choices
        end

        if #items > 0 then
            data.rewardItems = items
        end
    end
end

local function CaptureRewardCurrenciesFromQuestLog(data, questID)
    local count =
        SafeCall(GetNumQuestLogRewardCurrencies, questID)
        or 0

    if count <= 0 then
        return
    end

    local currencies = EnsureList(data, "rewardCurrencies")
    for i = 1, count do
        local name, texture, numItems, currencyID =
            SafeCall(GetQuestLogRewardCurrencyInfo, i, questID)

        AddRewardCurrency(data, currencyID, numItems, texture, name)
    end

    if #currencies == 0 then
        data.rewardCurrencies = nil
    end
end

local function CaptureRewardCurrenciesFromQuestDialog(data)
    local count = SafeCall(GetNumRewardCurrencies) or 0
    if count <= 0 then
        return
    end

    local currencies = EnsureList(data, "rewardCurrencies")
    for i = 1, count do
        local name, texture, numItems, currencyID =
            SafeCall(GetQuestCurrencyInfo, "reward", i)

        AddRewardCurrency(data, currencyID, numItems, texture, name)
    end

    if #currencies == 0 then
        data.rewardCurrencies = nil
    end
end

local function CaptureDialogRewardExtras(data)
    local rewardHonor = SafeCall(GetRewardHonor)
    if rewardHonor and rewardHonor > 0 then
        data.rewardHonor = rewardHonor
    end

    local rewardArtifactXP = SafeCall(GetRewardArtifactXP)
    if rewardArtifactXP and rewardArtifactXP > 0 then
        data.rewardArtifactXP = rewardArtifactXP
    end

    local rewardTitleID = SafeCall(GetRewardTitle)
    if rewardTitleID and rewardTitleID > 0 then
        data.rewardTitleID = rewardTitleID
    end

    local rewardSkillLineID = SafeCall(GetRewardSkillLineID)
    local rewardSkillUps = SafeCall(GetRewardNumSkillUps)
    if rewardSkillLineID or rewardSkillUps then
        data.rewardSkill = {
            skillLineID = rewardSkillLineID,
            skillUps = rewardSkillUps,
        }
    end

    CaptureRewardSpellFromCall(data, GetRewardSpell)
end

local function CaptureQuestLogRewardExtras(data, questID, logIndex)
    local rewardHonor = SafeCall(GetQuestLogRewardHonor, questID)
    if rewardHonor and rewardHonor > 0 then
        data.rewardHonor = rewardHonor
    end

    local rewardArtifactXP = SafeCall(GetQuestLogRewardArtifactXP, questID)
    if rewardArtifactXP and rewardArtifactXP > 0 then
        data.rewardArtifactXP = rewardArtifactXP
    end

    local rewardTitleID = SafeCall(GetQuestLogRewardTitle, questID)
    if rewardTitleID and rewardTitleID > 0 then
        data.rewardTitleID = rewardTitleID
    end

    local rewardSkillPoints = SafeCall(GetQuestLogRewardSkillPoints, questID)
    if rewardSkillPoints and rewardSkillPoints > 0 then
        data.rewardSkill = data.rewardSkill or {}
        data.rewardSkill.skillPoints = rewardSkillPoints
    end

    CaptureRewardSpellFromCall(data, GetQuestLogRewardSpell, questID)

    if logIndex then
        CaptureSpecialQuestItem(data, logIndex)
    end
end

local function CaptureClassificationData(data, questID, logInfo)
    local classification =
        C_QuestInfoSystem
        and C_QuestInfoSystem.GetQuestClassification
        and SafeCall(C_QuestInfoSystem.GetQuestClassification, questID)

    data.classification = classification

    if Enum and Enum.QuestClassification then
        if classification == Enum.QuestClassification.Campaign then
            data.isCampaign = true
            AddCategory(data, "campaign")
        elseif classification == Enum.QuestClassification.WorldQuest then
            data.isWorldQuest = true
            AddCategory(data, "world")
            AddCategory(data, "worldquest")
        elseif classification == Enum.QuestClassification.Legendary then
            AddCategory(data, "legendary")
        elseif classification == Enum.QuestClassification.Recurring then
            AddCategory(data, "repeatable")
        end
    end

    local tagInfo =
        C_QuestLog
        and C_QuestLog.GetQuestTagInfo
        and SafeCall(C_QuestLog.GetQuestTagInfo, questID)

    if tagInfo then
        data.tagName = tagInfo.tagName
        data.isElite = tagInfo.isElite or false

        if tagInfo.isElite then
            AddFlag(data, "elite")
        end

        if tagInfo.tagID then
            data.tagID = tagInfo.tagID
        end
    end

    if logInfo then
        data.frequency = logInfo.frequency

        if logInfo.frequency == 1 then
            data.isDaily = true
            AddCategory(data, "daily")
        elseif logInfo.frequency == 2 then
            data.isWeekly = true
            AddCategory(data, "weekly")
        end

        if logInfo.isHidden then
            AddFlag(data, "hidden")
        end

        if logInfo.isScaling then
            AddFlag(data, "scaling")
        end
    end

    local isPushable =
        C_QuestLog
        and C_QuestLog.IsPushableQuest
        and SafeCall(C_QuestLog.IsPushableQuest, questID)

    if isPushable ~= nil then
        data.sharable = isPushable and true or false
    end

    local timeLeft =
        C_TaskQuest
        and C_TaskQuest.GetQuestTimeLeftSeconds
        and SafeCall(C_TaskQuest.GetQuestTimeLeftSeconds, questID)

    if not timeLeft then
        timeLeft = SafeCall(GetQuestLogTimeLeft, questID)
    end

    timeLeft = tonumber(timeLeft)

    if timeLeft and timeLeft > 0 then
        data.timerSeconds = timeLeft
        AddFlag(data, "timed")
    end
end

local function CaptureQuestDetailSnapshot()
    local questID = SafeCall(GetQuestID)
    if not questID then
        return
    end

    local sourceName = GetQuestFrameSourceName()

    local data = {
        id = questID,
        name = SafeCall(GetTitleText),
        description = SafeCall(GetQuestText),
        objectivesText = SafeCall(GetObjectiveText),
        sourceName = sourceName,
        capturedFrom = "QUEST_DETAIL",
    }

    local rewardMoney = SafeCall(GetRewardMoney)
    if rewardMoney and rewardMoney > 0 then
        data.rewardGold = rewardMoney
    end

    local rewardXP = SafeCall(GetRewardXP)
    if rewardXP and rewardXP > 0 then
        data.rewardXP = rewardXP
    end

    CaptureMapData(data, questID, false)

    local starterStatus
    if IsBoardSourcedQuest(data.name, sourceName) then
        starterStatus = "board"
        MarkNPCFieldCleared(data, "starts")
    else
        starterStatus = CaptureTargetNPC(data, "starts", sourceName)
    end

    if starterStatus ~= "captured" then
        MarkNPCFieldCleared(data, "starts")
    end

    CaptureRewardItemsFromQuestDialog(data)
    CaptureRewardCurrenciesFromQuestDialog(data)
    CaptureDialogRewardExtras(data)

    pendingQuestDetails[questID] = data
end

local function CaptureQuestTurnInSnapshot(questID, sourceEvent)
    questID = questID or SafeCall(GetQuestID)
    if not questID then
        return
    end

    local sourceName = GetQuestFrameSourceName()

    local data = {
        id = questID,
        name =
            SafeCall(GetTitleText)
            or C_QuestLog.GetTitleForQuestID(questID),
        sourceName = sourceName,
        capturedFrom = sourceEvent or "QUEST_COMPLETE",
    }

    local desc = SafeCall(GetQuestText)
    if desc and desc ~= "" then
        data.description = desc
    end

    local obj = SafeCall(GetObjectiveText)
    if obj and obj ~= "" then
        data.objectivesText = obj
    end

    local rewardMoney = SafeCall(GetRewardMoney)
    if rewardMoney and rewardMoney > 0 then
        data.rewardGold = rewardMoney
    end

    local rewardXP = SafeCall(GetRewardXP)
    if rewardXP and rewardXP > 0 then
        data.rewardXP = rewardXP
    end

    CaptureMapData(data, questID, false)

    local enderStatus = CaptureTargetNPC(data, "ends", sourceName)
    if enderStatus ~= "captured" and sourceEvent then
        MarkNPCFieldCleared(data, "ends")
    end

    CaptureRewardItemsFromQuestDialog(data)
    CaptureRewardCurrenciesFromQuestDialog(data)
    CaptureDialogRewardExtras(data)

    ns.QuestData:StoreQuestInfo(questID, data)

    local ender =
        data.ends
        and data.ends[1]

    if ender and ender.npcID then
        EnsureNotesNPC(ender.npcID, {
            name = ender.npcName,
            mapID = ender.mapID or data.mapID,
            x = ender.x,
            y = ender.y,
            zone = ender.zoneName or data.zoneName,
            category = "Quest Givers",
        })
    end
end

function EnsureNotesNPC(npcID, npcInfo)
    local notes = _G.OneWoW_Notes
    if notes
        and notes.NPCs
        and notes.NPCs.EnsureNPC
    then
        notes.NPCs:EnsureNPC(npcID, npcInfo)
    end
end

local function EnsureQuestStarterNPC(questID)
    if not questID or not ns.QuestData then return end

    local quest = ns.QuestData:GetQuest(questID)
    local starter =
        quest
        and quest.starts
        and quest.starts[1]

    if starter and starter.npcID then
        EnsureNotesNPC(starter.npcID, {
            name = starter.npcName,
            mapID = starter.mapID or quest.mapID,
            x = starter.x,
            y = starter.y,
            zone = quest.zoneName,
            category = "Quest Givers",
        })
        return
    end

    if quest and quest.sourceName then
        return
    end

    local notes = _G.OneWoW_Notes
    if notes
        and notes.NPCs
        and notes.NPCs.GetTargetNPCInfo
    then
        local targetInfo = notes.NPCs:GetTargetNPCInfo()
        if targetInfo and targetInfo.id then
            targetInfo.category = "Quest Givers"
            notes.NPCs:EnsureNPC(targetInfo.id, targetInfo)
        end
    end
end

local function CaptureQuestFromLog(questID, addStarterToNotes)
    if not questID then return end

    local data = pendingQuestDetails[questID] or {}
    data.id = questID
    data.name = data.name or C_QuestLog.GetTitleForQuestID(questID)
    data.capturedFrom = data.capturedFrom or "QUEST_LOG"

    local logIndex = GetQuestLogIndex(questID)
    local logInfo  = logIndex and C_QuestLog.GetInfo(logIndex)
    if IsInternalQuest(data.name, logInfo) then
        ns.QuestData:StoreQuestInfo(questID, { id = questID, name = data.name, isInternal = true })
        return
    end

    if IsBoardSourcedQuest(data.name, data.sourceName) then
        MarkNPCFieldCleared(data, "starts")
    end

    CaptureMapData(data, questID, false)
    CaptureClassificationData(data, questID, logInfo)

    if logIndex then
        CaptureQuestLogFields(data, logInfo)

        local desc, obj = GetQuestLogQuestText(logIndex)
        if desc and desc ~= "" and not data.description then
            data.description = desc
        end
        if obj and obj ~= "" and not data.objectivesText then
            data.objectivesText = obj
        end
    end

    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if objectives and #objectives > 0 then
        local objList = {}
        local detailList = {}
        for _, obj in ipairs(objectives) do
            if obj.text and obj.text ~= "" then
                tinsert(objList, obj.text)
            end

            tinsert(detailList, {
                text = obj.text,
                objectiveType = obj.type,
                finished = obj.finished and true or false,
                numFulfilled = obj.numFulfilled,
                numRequired = obj.numRequired,
            })
        end
        if #objList > 0 then
            data.objectives = objList
        end
        if #detailList > 0 then
            data.objectiveDetails = detailList
        end
    end

    local requiredMoney = SafeCall(GetQuestLogRequiredMoney, questID)
    if requiredMoney and requiredMoney > 0 then
        data.requiredMoney = requiredMoney
    end

    local rewardMoney = GetQuestLogRewardMoney(questID)
    if rewardMoney and rewardMoney > 0 then
        data.rewardGold = rewardMoney
    end

    local rewardXP = GetQuestLogRewardXP(questID)
    if rewardXP and rewardXP > 0 then
        data.rewardXP = rewardXP
    end

    CaptureRewardItemsFromQuestLog(data, questID)
    CaptureRewardCurrenciesFromQuestLog(data, questID)
    CaptureQuestLogRewardExtras(data, questID, logIndex)

    ns.QuestData:StoreQuestInfo(questID, data)
    pendingQuestDetails[questID] = nil
    if addStarterToNotes then
        EnsureQuestStarterNPC(questID)
    end
end

local function ScanActiveQuestLog()
    local count = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, count do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and info.questID then
            CaptureQuestFromLog(info.questID, false)
        end
    end
end

local function ScanCompletedBatch(completedIDs, startIndex)
    local root = OneWoW_CatalogData_Quests_DB
    local db = root and (root.global or root) or nil
    if not db then return end
    db.quests = db.quests or {}

    local endIndex = math.min(startIndex + SCAN_BATCH_SIZE - 1, #completedIDs)
    for i = startIndex, endIndex do
        local questID = completedIDs[i]
        if questID and not db.quests[questID] then
            local name     = C_QuestLog.GetTitleForQuestID(questID)
            local internal = IsInternalQuest(name, nil)
            ns.QuestData:StoreQuestInfo(questID, { id = questID, name = name, isInternal = internal })
        end
    end

    if endIndex < #completedIDs then
        C_Timer.After(SCAN_BATCH_DELAY, function()
            ScanCompletedBatch(completedIDs, endIndex + 1)
        end)
    end
end

local scanFrame = CreateFrame("Frame")
scanFrame:RegisterEvent("QUEST_DETAIL")
scanFrame:RegisterEvent("QUEST_ACCEPTED")
scanFrame:RegisterEvent("QUEST_PROGRESS")
scanFrame:RegisterEvent("QUEST_COMPLETE")
scanFrame:RegisterEvent("QUEST_TURNED_IN")
scanFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "QUEST_DETAIL" then
        CaptureQuestDetailSnapshot()
    elseif event == "QUEST_ACCEPTED" then
        local questLogIndex, questID = ...
        local qID = questID or questLogIndex
        if qID and type(qID) == "number" then
            C_Timer.After(0, function()
                CaptureQuestFromLog(qID, true)
            end)
        end
    elseif event == "QUEST_PROGRESS" then
        CaptureQuestTurnInSnapshot(nil, "QUEST_PROGRESS")
    elseif event == "QUEST_COMPLETE" then
        CaptureQuestTurnInSnapshot(nil, "QUEST_COMPLETE")
    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        CaptureQuestTurnInSnapshot(questID, "QUEST_TURNED_IN")
        if questID and ns.CompletionTracker then
            ns.CompletionTracker:MarkCompleted(questID)
        end
    end
end)

function QuestScanner:Initialize()
    C_Timer.After(1.5, function()
        ScanActiveQuestLog()
        local completedIDs = C_QuestLog.GetAllCompletedQuestIDs()
        if completedIDs and #completedIDs > 0 then
            C_Timer.After(0.5, function()
                ScanCompletedBatch(completedIDs, 1)
            end)
        end
    end)
end
