local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local QUEST_LIST_ROW_HEIGHT = 48
local QUEST_LIST_ROW_FRAME_HEIGHT = 44
local QUEST_LIST_BUFFER_ROWS = 5

ns.UI = ns.UI or {}

local selectedQuest    = nil
local questListButtons = {}
local detailElements   = {}
local visibleRewardItemRows = {}
local visibleQuestNameRows = {}
local visibleNPCNameRows = {}
local questListGroupExpanded = {}
local questChainGroupExpanded = {}
local searchText       = ""
local expansionFilter  = -1
local zoneFilter       = ""
local typeFilter       = "all"
local questTypeFilter  = "all"
local completionFilter = "all"
local categoryFilter   = "all"
local flagFilter       = "all"
local professionFilter = "all"
local classFilter      = "all"
local raceFilter       = "all"
local factionFilter    = "all"
local storyFilter      = "all"
local runtimeFilter    = "all"
local advancedOpen     = false
local availableFilterCache = {}
local dataAddon        = nil
local questRowStatusCache = {}
local questGroupStatusCache = {}
local RefreshQuestList
local ShowQuestDetail
local OpenQuestByID
local UpdateVisibleQuestRows

local QUEST_SEARCH_STOP_WORDS = {
    a = true,
    an = true,
    ["and"] = true,
    ["at"] = true,
    ["by"] = true,
    ["for"] = true,
    ["from"] = true,
    ["in"] = true,
    ["of"] = true,
    ["on"] = true,
    ["or"] = true,
    ["the"] = true,
    ["to"] = true,
    ["with"] = true,
}

local function NormalizeQuestSearchText(value)
    value = tostring(value or ""):lower()

    local terms = {}

    for word in value:gmatch("[%w']+") do
        if not QUEST_SEARCH_STOP_WORDS[word] then
            table.insert(terms, word)
        end
    end

    return table.concat(terms, " ")
end

local function IsDatabaseMode()
    return (searchText and NormalizeQuestSearchText(searchText) ~= "")
        or expansionFilter ~= -1
        or zoneFilter ~= ""
        or completionFilter ~= "all"
        or typeFilter ~= "all"
        or questTypeFilter ~= "all"
        or categoryFilter ~= "all"
        or flagFilter ~= "all"
        or professionFilter ~= "all"
        or classFilter ~= "all"
        or raceFilter ~= "all"
        or factionFilter ~= "all"
        or storyFilter ~= "all"
        or runtimeFilter ~= "all"
end

local function ResetAdvancedFilters()
    typeFilter       = "all"
    questTypeFilter  = "all"
    categoryFilter   = "all"
    flagFilter       = "all"
    professionFilter = "all"
    classFilter      = "all"
    raceFilter       = "all"
    factionFilter    = "all"
    storyFilter      = "all"
    runtimeFilter    = "all"
end

local function BuildAdvancedFilters()
    return {
        groupType  = typeFilter,
        questType  = questTypeFilter,
        category   = categoryFilter,
        flag       = flagFilter,
        profession = professionFilter,
        class      = classFilter,
        race       = raceFilter,
        faction    = factionFilter,
        story      = storyFilter,
        runtime    = runtimeFilter,
    }
end

local function CountAdvancedFilters()
    local count = 0
    local values = {
        typeFilter,
        questTypeFilter,
        categoryFilter,
        flagFilter,
        professionFilter,
        classFilter,
        raceFilter,
        factionFilter,
        storyFilter,
        runtimeFilter,
    }

    for _, value in ipairs(values) do
        if value and value ~= "all" then
            count = count + 1
        end
    end

    return count
end

local function GetAdvancedButtonText()
    local count = CountAdvancedFilters()
    if count > 0 then
        return "Advanced (" .. tostring(count) .. ")"
    end
    return "Advanced"
end

local function SetButtonText(button, text)
    if not button then return end
    if button.SetText then
        button:SetText(text)
    elseif button.text and button.text.SetText then
        button.text:SetText(text)
    elseif button.Text and button.Text.SetText then
        button.Text:SetText(text)
    end
end

local function UpdateFavoritesFilterButton(button)
    if not button then return end

    SetButtonText(button, "Favorites")

    if button.SetActive then
        button:SetActive(runtimeFilter == "favorite")
    elseif button.SetBackdropColor then
        if runtimeFilter == "favorite" then
            button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        else
            button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        end

        if button.SetBackdropBorderColor then
            if runtimeFilter == "favorite" then
                button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            else
                button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end
        end
    end
end

local function ContainsAnyLower(text, tokens)
    if not text or text == "" then return false end

    for _, token in ipairs(tokens) do
        if token and token ~= "" and text:find(token, 1, true) then
            return true
        end
    end

    return false
end

local ACTIVE_QUEST_NAME_FILTERS = {
    "capstone",
    "dnt",
    "nth",
    "ph]",
    "(ph)",
    "[nyi]",
    "[removed]",
    "removed]",
    "placeholder",
    "reward test",
    "test case",
    "test quest",
    "test currency",
    "nav test",
    "tracking quest",
    "reward quest",
    "quest start",
    "navigation playtest",
    "event tracking",
    "unused",
    "do not use",
    "vignette",
}

local function IsInternalActiveQuestName(name, questID)
    if not name or name == "" then return true end

    local lowerName = tostring(name):lower()

    if lowerName:match("^level%s+%d+$") then
        return true
    end

    if questID ~= 71153 and lowerName:find("bonus objective", 1, true) then
        return true
    end

    if lowerName:find("%[%s*[%a%s]+%s*%]") then
        return true
    end

    if lowerName:find("%[%[deprecated%]%]") then
        return true
    end

    if lowerName:find("%f[%a]poi%f[%A]") then
        return true
    end

    if lowerName:match("^zz") or lowerName == "test" then
        return true
    end

    return ContainsAnyLower(lowerName, ACTIVE_QUEST_NAME_FILTERS)
end

local function IsVisibleActiveQuestLogInfo(info)
    if not info or info.isHeader or info.isHidden then
        return false
    end

    if info.isTask or info.isBounty then
        return false
    end

    return true
end

local function GetActiveQuestLogQuests(addon)
    local quests = {}

    local numEntries = C_QuestLog.GetNumQuestLogEntries()

    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)

        if IsVisibleActiveQuestLogInfo(info) then
            local title = info.title

            if title
                and title ~= ""
            then
                local questID = info.questID

                if questID
                    and C_QuestLog.IsOnQuest
                    and C_QuestLog.IsOnQuest(questID)
                    and not IsInternalActiveQuestName(title, questID)
                then
                    local stored =
                        addon.QuestData
                        and addon.QuestData:GetQuest(questID)

                    local quest = {}

                    if stored then
                        for key, value in pairs(stored) do
                            quest[key] = value
                        end
                    end

                    quest.id = questID
                    quest.name = title or quest.name
                    quest.level = info.level or quest.level
                    quest.campaign = info.campaign
                    quest.isTask = info.isTask
                    quest.isBounty = info.isBounty
                    quest.isStory = info.isStory
                    quest.frequency = info.frequency

                    table.insert(quests, quest)
                end
            end
        end
    end

    table.sort(quests, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    return quests
end

local function GetDataAddon()
    if dataAddon then return dataAddon end
    if ns.Catalog and ns.Catalog.GetDataAddon then
        dataAddon = ns.Catalog:GetDataAddon("quests")
    end
    return dataAddon
end

local function ClearDetailElements()
    for _, element in ipairs(detailElements) do
        if element.Hide then element:Hide() end
        if element.SetParent then element:SetParent(nil) end
    end
    wipe(detailElements)
    wipe(visibleRewardItemRows)
    wipe(visibleQuestNameRows)
end

local function ClearQuestList()
    for _, btn in ipairs(questListButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(questListButtons)
end

local function GetQuestTypeLabel(quest)
    if not quest then return L["QUESTS_TYPE_NORMAL"] end
    if quest.isDaily   then return L["QUESTS_TYPE_DAILY"]   end
    if quest.isWeekly  then return L["QUESTS_TYPE_WEEKLY"]  end
    if quest.isCampaign then return L["QUESTS_TYPE_CAMPAIGN"] end
    if quest.isWorldQuest then return L["QUESTS_TYPE_WORLDQUEST"] end
    local cls = quest.classification
    if cls == 1 then return L["QUESTS_TYPE_LEGENDARY"] end
    if cls == 5 then return L["QUESTS_TYPE_REPEATABLE"] end
    return L["QUESTS_TYPE_NORMAL"]
end

local function GetGroupTypeLabel(quest)
    if not quest then return L["QUESTS_TYPE_SOLO"] end
    local sg = quest.suggestedGroup or 0
    if sg >= 10 then return L["QUESTS_TYPE_RAID"]  end
    if sg >= 2  then return L["QUESTS_TYPE_GROUP"] end
    return L["QUESTS_TYPE_SOLO"]
end

local function GetQuestProgressLabel(questID)
    if questID and C_QuestLog.IsOnQuest(questID) then
        return L["QUESTS_PROGRESS_ACTIVE"]
    end

    if questID and C_QuestLog.IsQuestFlaggedCompleted(questID) then
        return L["QUESTS_PROGRESS_COMPLETED"]
    end

    if questID and C_QuestLog.IsQuestFlaggedCompletedOnAccount
        and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID)
    then
        return L["QUESTS_PROGRESS_WARBAND"]
    end

    return L["QUESTS_PROGRESS_NOT_COMPLETED"]
end

local function GetQuestRewardSummary(quest)
    if not quest then
        return "-"
    end

    local parts = {}

    if quest.rewardGold and quest.rewardGold > 0 then
        table.insert(parts, GetCoinTextureString(quest.rewardGold))
    end

    if quest.rewardXP and quest.rewardXP > 0 then
        table.insert(parts, tostring(quest.rewardXP) .. " XP")
    end

    if quest.rewardItems and #quest.rewardItems > 0 then
        table.insert(parts, tostring(#quest.rewardItems) .. " items")
    end

    if quest.rewardCurrencies and #quest.rewardCurrencies > 0 then
        local label = #quest.rewardCurrencies == 1 and "currency" or "currencies"
        table.insert(parts, tostring(#quest.rewardCurrencies) .. " " .. label)
    end

    return #parts > 0 and table.concat(parts, ", ") or "-"
end

local function GetCurrencyRewardInfo(rewardCurrency)
    local currencyID
    local quantity = 1
    local icon
    local name

    if type(rewardCurrency) == "number" then
        currencyID = rewardCurrency
    elseif type(rewardCurrency) == "table" then
        currencyID = rewardCurrency.currencyID or rewardCurrency.id
        quantity = rewardCurrency.quantity or rewardCurrency.count or rewardCurrency.amount or 1
        icon = rewardCurrency.icon or rewardCurrency.texture
        name = rewardCurrency.name
    end

    currencyID = tonumber(currencyID)
    quantity = tonumber(quantity) or 1

    if not currencyID or currencyID <= 0 then
        return nil
    end

    local info =
        C_CurrencyInfo
        and C_CurrencyInfo.GetCurrencyInfo
        and C_CurrencyInfo.GetCurrencyInfo(currencyID)

    if info then
        name = info.name
        icon = icon or info.iconFileID
    end

    return currencyID, quantity, icon or 134400, name or ("Currency #" .. tostring(currencyID))
end

local function FormatQuestMetadataValue(value)
    if value == nil or tostring(value) == "" then
        return "-"
    end

    value = tostring(value):gsub("_", " ")
    return value:gsub("^%l", string.upper)
end

local function GetFirstMetadataValue(values)
    if type(values) ~= "table" then
        return nil
    end

    for _, value in ipairs(values) do
        if value ~= nil and tostring(value) ~= "" then
            return value
        end
    end

    return nil
end

local function ResolveQuestZoneName(quest)
    if not quest then
        return L["QUESTS_UNKNOWN"]
    end

    if quest.zoneName and quest.zoneName ~= "" then
        return quest.zoneName
    end

    if quest.mapID and quest.mapID ~= 0 and C_Map and C_Map.GetMapInfo then
        local mapInfo = C_Map.GetMapInfo(quest.mapID)
        if mapInfo and mapInfo.name and mapInfo.name ~= "" then
            quest.zoneName = mapInfo.name
            return mapInfo.name
        end
    end

    return L["QUESTS_UNKNOWN"]
end

local function CreateSeparatorLine(parent, yOffset)
    return OneWoW_GUI:CreateDivider(parent, { yOffset = yOffset })
end

local function CreateLabel(parent, text, fontSize, yOffset, xLeft, textColor)
    local fs = OneWoW_GUI:CreateFS(parent, fontSize or 10)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", xLeft or 10, yOffset)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(text)
    if textColor then
        fs:SetTextColor(table.unpack(textColor))
    else
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    return fs
end

local npcNameCache = {}
local npcNameRefreshPending = {}
local NPC_NAME_REFRESH_DELAYS = { 0.1, 0.25, 0.5, 1.0 }
local questNameCache = {}
local questNameRefreshPending = {}

local CLASS_NAMES = {
    [1] = "Warrior",
    [2] = "Paladin",
    [3] = "Hunter",
    [4] = "Rogue",
    [5] = "Priest",
    [6] = "Death Knight",
    [7] = "Shaman",
    [8] = "Mage",
    [9] = "Warlock",
    [10] = "Monk",
    [11] = "Druid",
    [12] = "Demon Hunter",
    [13] = "Evoker",
}

local RACE_NAMES = {
    [1] = "Human",
    [2] = "Orc",
    [3] = "Dwarf",
    [4] = "Night Elf",
    [5] = "Undead",
    [6] = "Tauren",
    [7] = "Gnome",
    [8] = "Troll",
    [9] = "Goblin",
    [10] = "Blood Elf",
    [11] = "Draenei",
    [22] = "Worgen",
    [24] = "Pandaren",
    [25] = "Pandaren",
    [26] = "Pandaren",
    [27] = "Nightborne",
    [28] = "Highmountain Tauren",
    [29] = "Void Elf",
    [30] = "Lightforged Draenei",
    [31] = "Zandalari Troll",
    [32] = "Kul Tiran",
    [34] = "Dark Iron Dwarf",
    [35] = "Vulpera",
    [36] = "Mag'har Orc",
    [37] = "Mechagnome",
    [52] = "Dracthyr",
    [70] = "Dracthyr",
    [84] = "Earthen",
    [85] = "Earthen",
}

local detailRenderVersion = 0
local pendingRewardItemIDs = {}
local rewardItemSearchWarmQueue = {}
local rewardItemSearchWarmSeen = {}
local rewardItemSearchWarmRunning = false
local rewardItemSearchWarmToken = 0
local rewardItemSearchRefreshQueued = false
local REWARD_ITEM_SEARCH_WARM_PER_TICK = 3
local REWARD_ITEM_SEARCH_WARM_DELAY = 0.1
local REWARD_ITEM_SEARCH_WARM_MAX = 900

local function RememberRewardItemName(itemID, itemName)
    if not itemID or not itemName or itemName == "" then
        return false
    end

    itemName = tostring(itemName)

    -- RETRIEVING_ITEM_INFO is the locale-correct placeholder Blizzard shows
    -- while an item is uncached; never memorize it as a real name.
    if itemName == RETRIEVING_ITEM_INFO then
        return false
    end

    local addon = GetDataAddon()

    if addon
        and addon.QuestData
        and addon.QuestData.RememberItemName
    then
        addon.QuestData:RememberItemName(itemID, itemName)
        return true
    end

    return false
end

local function ApplyVisibleRewardItemName(itemID, itemName)
    itemID = tonumber(itemID)
    if not itemID or not itemName or itemName == "" then
        return false
    end

    local rows = visibleRewardItemRows[itemID]
    if not rows then
        return false
    end

    local applied = false
    local remaining = {}

    for _, row in ipairs(rows) do
        if row
            and row.renderVersion == detailRenderVersion
            and row.apply
        then
            row.apply(itemName)
            applied = true
            table.insert(remaining, row)
        end
    end

    if #remaining > 0 then
        visibleRewardItemRows[itemID] = remaining
    else
        visibleRewardItemRows[itemID] = nil
    end

    return applied
end

local function RememberAndApplyRewardItemName(itemID, itemName)
    if not RememberRewardItemName(itemID, itemName) then
        return false
    end

    ApplyVisibleRewardItemName(itemID, itemName)
    return true
end

local function GetVisibleTooltipItemName()
    local tooltipTitle = GameTooltip.TextLeft1
    local text =
        tooltipTitle
        and tooltipTitle.GetText
        and tooltipTitle:GetText()

    if text and text ~= "" and text ~= RETRIEVING_ITEM_INFO then
        return text
    end

    return nil
end

local function RequestVisibleRewardItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return
    end

    if pendingRewardItemIDs[itemID] then
        return
    end

    local loader = ns.GetItemDataLoader()

    local cachedItem = loader:GetCachedItem(itemID)
    if cachedItem and cachedItem.name then
        RememberAndApplyRewardItemName(itemID, cachedItem.name)
        return
    end

    pendingRewardItemIDs[itemID] = true

    loader:LoadItemData(itemID, function(_, itemData)
        pendingRewardItemIDs[itemID] = nil

        if not itemData or not itemData.name then
            return
        end

        RememberAndApplyRewardItemName(itemID, itemData.name)
    end)
end

local function GetRewardItemID(entry)
    if type(entry) == "number" then
        return entry
    elseif type(entry) == "table" then
        return entry.itemID or entry.id
    end

    return nil
end

local function CatalogItemCacheHasName(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    local cached = ns.GetItemDataLoader():GetCachedItem(itemID)
    return cached ~= nil and cached.name ~= nil and cached.name ~= ""
end

local function QueueRewardItemSearchRefresh(panels, token)
    if rewardItemSearchRefreshQueued then
        return
    end

    rewardItemSearchRefreshQueued = true

    C_Timer.After(1.5, function()
        rewardItemSearchRefreshQueued = false

        if token ~= rewardItemSearchWarmToken then
            return
        end

        if panels and RefreshQuestList then
            RefreshQuestList(panels)
        end
    end)
end

local function CancelRewardItemSearchWarmup()
    rewardItemSearchWarmToken = rewardItemSearchWarmToken + 1
    rewardItemSearchWarmRunning = false
    rewardItemSearchRefreshQueued = false
    wipe(rewardItemSearchWarmQueue)
    wipe(rewardItemSearchWarmSeen)
end

local function ProcessRewardItemSearchWarmQueue(panels, token)
    if token ~= rewardItemSearchWarmToken then
        return
    end

    local loader = ns.GetItemDataLoader()

    local processed = 0

    while processed < REWARD_ITEM_SEARCH_WARM_PER_TICK and #rewardItemSearchWarmQueue > 0 do
        local itemID = table.remove(rewardItemSearchWarmQueue, 1)

        if itemID and not CatalogItemCacheHasName(itemID) then
            processed = processed + 1

            loader:LoadItemData(itemID, function(_, itemData)
                if token ~= rewardItemSearchWarmToken then
                    return
                end

                if itemData and itemData.name then
                    RememberAndApplyRewardItemName(itemID, itemData.name)
                    QueueRewardItemSearchRefresh(panels, token)
                end
            end)
        end
    end

    if #rewardItemSearchWarmQueue > 0 then
        C_Timer.After(REWARD_ITEM_SEARCH_WARM_DELAY, function()
            ProcessRewardItemSearchWarmQueue(panels, token)
        end)
    else
        rewardItemSearchWarmRunning = false
    end
end

local function LooksLikeItemNameSearch(value)
    value = NormalizeQuestSearchText(value):gsub("^%s+", ""):gsub("%s+$", "")

    if value == "" or #value < 3 then
        return false
    end

    if tonumber(value) then
        return false
    end

    if value:match("^item:%s*%d+$") then
        return false
    end

    return value:match("[%a]") ~= nil
end

local function StartRewardItemSearchWarmup(panels, addon, resultCount)
    if not LooksLikeItemNameSearch(searchText) then
        return
    end

    if resultCount and resultCount > 40 then
        return
    end

    if not addon
        or not addon.QuestData
        or not addon.QuestData.GetQuestsForExpansion
    then
        return
    end

    rewardItemSearchWarmToken = rewardItemSearchWarmToken + 1
    rewardItemSearchWarmRunning = false
    wipe(rewardItemSearchWarmQueue)
    wipe(rewardItemSearchWarmSeen)

    local quests = addon.QuestData:GetQuestsForExpansion(expansionFilter)
    local queued = 0

    local function addItems(items)
        if queued >= REWARD_ITEM_SEARCH_WARM_MAX or type(items) ~= "table" then
            return
        end

        for _, rewardItem in ipairs(items) do
            local itemID = tonumber(GetRewardItemID(rewardItem))
            if itemID
                and not rewardItemSearchWarmSeen[itemID]
                and not CatalogItemCacheHasName(itemID)
            then
                rewardItemSearchWarmSeen[itemID] = true
                table.insert(rewardItemSearchWarmQueue, itemID)
                queued = queued + 1

                if queued >= REWARD_ITEM_SEARCH_WARM_MAX then
                    return
                end
            end
        end
    end

    for _, quest in pairs(quests or {}) do
        if zoneFilter == ""
            or quest.zoneName == zoneFilter
            or ResolveQuestZoneName(quest) == zoneFilter
        then
            addItems(quest.rewardItems)
            addItems(quest.rewardChoices)
        end

        if queued >= REWARD_ITEM_SEARCH_WARM_MAX then
            break
        end
    end

    if queued == 0 then
        return
    end

    if not rewardItemSearchWarmRunning then
        rewardItemSearchWarmRunning = true
        ProcessRewardItemSearchWarmQueue(panels, rewardItemSearchWarmToken)
    end
end

local function IsGenericNPCName(name)
    return not name
        or name == ""
        or name:find("^NPC %d") ~= nil
        or name:find("^NPC #%d") ~= nil
end

local function ResolveNPCName(npcID, knownName)
    if not npcID then
        return nil
    end

    if not IsGenericNPCName(knownName) then
        return knownName
    end

    if npcNameCache[npcID] then
        return npcNameCache[npcID]
    end

    local hyperlink = ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID)
    local tooltipData = C_TooltipInfo.GetHyperlink(hyperlink)

    if tooltipData and tooltipData.lines then
        for _, line in ipairs(tooltipData.lines) do
            if line.leftText and line.leftText ~= "" and line.leftText ~= RETRIEVING_ITEM_INFO then
                npcNameCache[npcID] = line.leftText
                return line.leftText
            end
        end
    end

    return nil
end

local function ApplyVisibleNPCName(npcID, npcName)
    npcID = tonumber(npcID)
    if not npcID or not npcName or npcName == "" then
        return false
    end

    local rows = visibleNPCNameRows[npcID]
    if not rows then
        return false
    end

    local applied = false
    local remaining = {}

    for _, row in ipairs(rows) do
        if row
            and row.renderVersion == detailRenderVersion
            and row.setName
        then
            row.setName(npcName)
            applied = true
            table.insert(remaining, row)
        end
    end

    if #remaining > 0 then
        visibleNPCNameRows[npcID] = remaining
    else
        visibleNPCNameRows[npcID] = nil
    end

    return applied
end

local function RegisterVisibleNPCName(npcID, setName)
    npcID = tonumber(npcID)
    if not npcID or not setName then
        return
    end

    visibleNPCNameRows[npcID] = visibleNPCNameRows[npcID] or {}
    table.insert(visibleNPCNameRows[npcID], {
        setName = setName,
        renderVersion = detailRenderVersion,
    })
end

local function ScheduleNPCNameRefresh(npcID, questData)
    if not npcID or npcNameRefreshPending[npcID] then
        return
    end

    local state = { attempt = 1 }
    npcNameRefreshPending[npcID] = state

    local function retry()
        if npcNameCache[npcID] then
            npcNameRefreshPending[npcID] = nil
            ApplyVisibleNPCName(npcID, npcNameCache[npcID])
            return
        end

        local npcName = ResolveNPCName(npcID)
        if npcName then
            npcNameRefreshPending[npcID] = nil
            ApplyVisibleNPCName(npcID, npcName)
            return
        end

        state.attempt = state.attempt + 1

        local delay = NPC_NAME_REFRESH_DELAYS[state.attempt]
        if delay
            and selectedQuest
            and questData
            and selectedQuest.id == questData.id
        then
            C_Timer.After(delay, retry)
        else
            npcNameRefreshPending[npcID] = nil
        end
    end

    C_Timer.After(NPC_NAME_REFRESH_DELAYS[state.attempt], retry)
end

local function GetNPCName(npcID, questData)
    if not npcID then
        return nil
    end

    if npcNameCache[npcID] then
        return npcNameCache[npcID]
    end

    if questData then
        ScheduleNPCNameRefresh(npcID, questData)
    end

    return nil
end

local function ResolveQuestName(questID)
    questID = tonumber(questID)
    if not questID then return nil end

    if questNameCache[questID] then
        return questNameCache[questID]
    end

    local questName

    questName = C_QuestLog.GetTitleForQuestID(questID)

    if (not questName or questName == "") and QuestUtils_GetQuestName then
        questName = QuestUtils_GetQuestName(questID)
    end

    if questName and questName ~= "" then
        questNameCache[questID] = questName
        return questName
    end

    return nil
end

local function ApplyVisibleQuestName(questID, questName)
    questID = tonumber(questID)
    if not questID or not questName or questName == "" then
        return false
    end

    local rows = visibleQuestNameRows[questID]
    if not rows then
        return false
    end

    local applied = false
    local remaining = {}

    for _, row in ipairs(rows) do
        if row
            and row.renderVersion == detailRenderVersion
            and row.text
            and row.text.SetText
        then
            row.text:SetText(
                (row.prefix or "")
                    .. (row.format and row.format(questName) or questName)
                    .. (row.suffix or "")
            )
            applied = true
            table.insert(remaining, row)
        end
    end

    if #remaining > 0 then
        visibleQuestNameRows[questID] = remaining
    else
        visibleQuestNameRows[questID] = nil
    end

    return applied
end

local function RegisterVisibleQuestName(questID, textObject, prefix, suffix, formatter)
    questID = tonumber(questID)
    if not questID or not textObject then
        return
    end

    visibleQuestNameRows[questID] = visibleQuestNameRows[questID] or {}
    table.insert(visibleQuestNameRows[questID], {
        text = textObject,
        prefix = prefix or "",
        suffix = suffix or "",
        format = formatter,
        renderVersion = detailRenderVersion,
    })
end

local function ScheduleQuestNameRefresh(questID, questData)
    questID = tonumber(questID)
    if not questID or questNameRefreshPending[questID] then
        return
    end

    local state = { attempt = 1 }
    questNameRefreshPending[questID] = state

    local function retry()
        if questNameCache[questID] then
            questNameRefreshPending[questID] = nil
            ApplyVisibleQuestName(questID, questNameCache[questID])
            return
        end

        local questName = ResolveQuestName(questID)
        if questName then
            questNameRefreshPending[questID] = nil
            ApplyVisibleQuestName(questID, questName)
            return
        end

        state.attempt = state.attempt + 1

        local delay = NPC_NAME_REFRESH_DELAYS[state.attempt]
        if delay
            and selectedQuest
            and questData
            and selectedQuest.id == questData.id
        then
            C_Timer.After(delay, retry)
        else
            questNameRefreshPending[questID] = nil
        end
    end

    C_Timer.After(NPC_NAME_REFRESH_DELAYS[state.attempt], retry)
end

local function GetQuestDisplayName(questID, questData)
    local addon = GetDataAddon()
    local quest =
        addon
        and addon.QuestData
        and addon.QuestData:GetQuest(questID)

    local questName =
        quest
        and quest.name
        or ResolveQuestName(questID)

    if not questName and questData then
        ScheduleQuestNameRefresh(questID, questData)
    end

    return questName or ("Quest " .. tostring(questID))
end

local function GetClassDisplayName(value)
    local classID = tonumber(value)

    if classID then
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info and info.className then
            return info.className
        end

        if GetClassInfo then
            local className = GetClassInfo(classID)
            if className then
                return className
            end
        end

        return CLASS_NAMES[classID] or ("Class " .. tostring(classID))
    end

    return tostring(value)
end

local function GetRaceDisplayName(value)
    local raceID = tonumber(value)

    if raceID then
        local info = C_CreatureInfo.GetRaceInfo(raceID)
        if info and info.raceName then
            return info.raceName
        end

        return RACE_NAMES[raceID] or ("Race " .. tostring(raceID))
    end

    return tostring(value)
end

local function GetFactionFilterValue(value)
    if value == nil or tostring(value) == "" then
        return nil
    end

    value = tostring(value):lower()

    if value == "none" or value == "both" or value == "neutral" then
        return "neutral"
    end

    return value
end

local function GetFactionDisplayName(value)
    value = GetFactionFilterValue(value)

    if value == "alliance" then
        return "Alliance"
    elseif value == "horde" then
        return "Horde"
    elseif value == "neutral" then
        return "Both / Neutral"
    end

    return value and FormatQuestMetadataValue(value) or "-"
end

local function GetAdvancedValueText(fieldName, value)
    if not value or value == "all" then
        return nil
    end

    if fieldName == "class" then
        return GetClassDisplayName(value)
    elseif fieldName == "race" then
        return GetRaceDisplayName(value)
    elseif fieldName == "faction" then
        return GetFactionDisplayName(value)
    end

    return tostring(value)
end

local function GetQuestStarterData(questData)
    if not questData then return nil end

    -- Future scraper schema
    if questData.starts and questData.starts[1] then
        return questData.starts[1]
    end

    -- Legacy compatibility
    if questData.questGiverID then
        return {
            npcID = questData.questGiverID,
            npcName = questData.questGiverName,
        }
    end

    return nil
end

local function GetQuestEnderData(questData)
    if not questData then return nil end

    if questData.ends and questData.ends[1] then
        return questData.ends[1]
    end

    return nil
end

local function AddUniqueQuestID(ids, seen, questID)
    questID = tonumber(questID)
    if questID and not seen[questID] then
        seen[questID] = true
        table.insert(ids, questID)
    end
end

local function GetQuestChainIDs(questData)
    if not questData then return nil end

    local ids = {}
    local seen = {}

    if questData.storyline and #questData.storyline > 1 then
        for _, questID in ipairs(questData.storyline) do
            AddUniqueQuestID(ids, seen, questID)
        end
    elseif questData.series and #questData.series > 0 then
        AddUniqueQuestID(ids, seen, questData.id)

        for _, questID in ipairs(questData.series) do
            AddUniqueQuestID(ids, seen, questID)
        end

        table.sort(ids)
    end

    if #ids <= 1 then
        return nil
    end

    return ids
end

local function GetQuestChainColor(questID, tracker)
    if C_QuestLog.IsOnQuest(questID) then
        return 0.3, 1, 0.3
    end

    if tracker and tracker.IsCompletedByCurrentChar and tracker:IsCompletedByCurrentChar(questID) then
        return 0.72, 0.72, 0.72
    end

    return 1, 0.82, 0
end

local function GetQuestMapTarget(questData)
    if not questData then return nil end

    local starterData = GetQuestStarterData(questData)
    if starterData and starterData.mapID and starterData.x and starterData.y then
        return starterData.mapID, starterData.x, starterData.y
    end

    if questData.coords and questData.coords.mapID and questData.coords.x and questData.coords.y then
        return questData.coords.mapID, questData.coords.x, questData.coords.y
    end

    return questData.mapID, nil, nil
end

local function HandleItemPreviewClick(itemID, itemLink)
    if not IsControlKeyDown or not IsControlKeyDown() then
        return false
    end

    itemLink = itemLink
        or select(2, C_Item.GetItemInfo(itemID))
        or ("item:" .. tostring(itemID))

    if HandleModifiedItemClick and HandleModifiedItemClick(itemLink) then
        return true
    end

    if DressUpItemLink then
        DressUpItemLink(itemLink)
        return true
    end

    return false
end

local function AddRewardItemToNotes(itemID, itemName, itemLink, itemTexture, itemQuality)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    if ns.Navigation and ns.Navigation.OpenItemNote then
        return ns.Navigation:OpenItemNote(itemID, {
            name = itemName,
            link = itemLink,
            icon = itemTexture,
            quality = itemQuality,
            category = "Quest",
            storage = "account",
        })
    end

    return false
end

local function OpenRewardItemInItemSearch(itemID, itemName)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    OneWoW.UI:Show("catalog")
    OneWoW.UI:SelectSubTab("catalog", "itemsearch")

    C_Timer.After(0.05, function()
        if ns.UI and ns.UI.OpenItemSearch then
            ns.UI.OpenItemSearch(itemID, itemName)
        end
    end)

    return true
end

function ShowQuestDetail(panels, questData)
    detailRenderVersion = detailRenderVersion + 1

    selectedQuest = questData
    ClearDetailElements()

    if not questData then
        if panels.emptyDetail then
            panels.emptyDetail:SetText(L["QUESTS_SELECT"])
            panels.emptyDetail:Show()
        end
        panels.detailScrollChild:SetHeight(100)
        return
    end

    if panels.emptyDetail then panels.emptyDetail:Hide() end

    local parent  = panels.detailScrollChild
    local addon   = GetDataAddon()
    if not addon then return end
    local tracker = addon.CompletionTracker

    local contentWidth = parent:GetWidth()
    if contentWidth < 50 then
        C_Timer.After(0.05, function()
            if selectedQuest
                and questData
                and selectedQuest.id == questData.id
            then
                ShowQuestDetail(panels, questData)
            end
        end)
        return
    end

    if addon.QuestData then
        if not questData.mapID then
            local liveMapID = GetQuestUiMapID(questData.id)
            if liveMapID and liveMapID ~= 0 then
                local mapInfo = C_Map.GetMapInfo(liveMapID)
                questData.mapID    = liveMapID
                questData.zoneName = mapInfo and mapInfo.name or questData.zoneName

                addon.QuestData:StoreQuestInfo(questData.id, {
                    mapID = liveMapID,
                    zoneName = questData.zoneName
                })
            end
        end

        if not questData.classification
            and C_QuestInfoSystem
            and C_QuestInfoSystem.GetQuestClassification
        then
            local cls = C_QuestInfoSystem.GetQuestClassification(questData.id)

            if cls then
                questData.classification = cls

                addon.QuestData:StoreQuestInfo(questData.id, {
                    classification = cls
                })
            end
        end

        if not questData.tagName then
            local tagInfo = C_QuestLog.GetQuestTagInfo(questData.id)

            if tagInfo and tagInfo.tagName then
                questData.tagName = tagInfo.tagName
                questData.isElite = tagInfo.isElite

                addon.QuestData:StoreQuestInfo(questData.id, {
                    tagName = tagInfo.tagName,
                    isElite = tagInfo.isElite
                })
            end
        end
    end

    local yOffset = -12
    local PAD     = 10
    local W       = contentWidth - PAD * 2

    local function track(elem)
        table.insert(detailElements, elem)
        return elem
    end

    local function addSep()
        local sep = CreateSeparatorLine(parent, yOffset - 6)
        track(sep)
        yOffset = yOffset - 20
    end

    local function addVSpace(h)
        yOffset = yOffset - (h or 8)
    end

    local function FormatQuestText(text)
        if not text or text == "" then
            return text
        end

        local playerName = UnitName("player") or "Player"

        -- Blizzard-style quest tokens
        text = text:gsub("%$p", playerName)

        -- Legacy/custom tokens seen in some quest text
        text = text:gsub("<name>", playerName)

        return text
    end

    local function ParseDetailSearchTerms()
        local terms = {}
        local text = tostring(searchText or "")
        local length = #text
        local index = 1

        while index <= length do
            while index <= length and text:sub(index, index):match("%s") do
                index = index + 1
            end

            if index > length then
                break
            end

            local quoted = false
            local value

            if text:sub(index, index) == "\"" then
                quoted = true
                local closeIndex = text:find("\"", index + 1, true)
                if closeIndex then
                    value = text:sub(index + 1, closeIndex - 1)
                    index = closeIndex + 1
                else
                    value = text:sub(index + 1)
                    index = length + 1
                end
            else
                local nextSpace = text:find("%s", index)
                if nextSpace then
                    value = text:sub(index, nextSpace - 1)
                    index = nextSpace + 1
                else
                    value = text:sub(index)
                    index = length + 1
                end
            end

            value = value and value:gsub("^%s+", ""):gsub("%s+$", "")
            local lowerValue = value and value:lower()
            if value
                and #value >= 2
                and not QUEST_SEARCH_STOP_WORDS[lowerValue]
            then
                table.insert(terms, {
                    text = value,
                    lower = lowerValue,
                    quoted = quoted,
                    wordExact = quoted and value:find("%s") == nil and value:match("^%w+$") ~= nil,
                })
            end
        end

        return terms
    end

    local detailSearchTerms = ParseDetailSearchTerms()

    local function FindNextHighlightMatch(lowerText, cursor, terms)
        local bestStart, bestEnd

        for _, term in ipairs(terms) do
            local startIndex, endIndex

            if term.wordExact then
                startIndex, endIndex = lowerText:find("%f[%w]" .. term.lower .. "%f[%W]", cursor)
            else
                startIndex, endIndex = lowerText:find(term.lower, cursor, true)
            end

            if startIndex
                and (
                    not bestStart
                    or startIndex < bestStart
                    or (startIndex == bestStart and endIndex > bestEnd)
                )
            then
                bestStart = startIndex
                bestEnd = endIndex
            end
        end

        return bestStart, bestEnd
    end

    local function HighlightSearchText(text)
        if not text or text == "" then
            return text
        end

        text = tostring(text)

        if #detailSearchTerms == 0 then
            return text
        end

        local lowerText = text:lower()
        local pieces = {}
        local cursor = 1

        while cursor <= #text do
            local startIndex, endIndex = FindNextHighlightMatch(lowerText, cursor, detailSearchTerms)
            if not startIndex then
                table.insert(pieces, text:sub(cursor))
                break
            end

            if startIndex > cursor then
                table.insert(pieces, text:sub(cursor, startIndex - 1))
            end

            table.insert(pieces, "|cffffff00" .. text:sub(startIndex, endIndex) .. "|r")
            cursor = endIndex + 1
        end

        return table.concat(pieces)
    end

    local function FormatAndHighlightQuestText(text)
        return HighlightSearchText(FormatQuestText(text))
    end

    local function addWrappedText(text, fontSize, color)
        local fs = track(OneWoW_GUI:CreateFS(parent, fontSize or 12))

        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
        fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)

        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(FormatAndHighlightQuestText(text))
        fs:SetWidth(W)

        if color then
            local r, g, b, a = table.unpack(color)
            fs:SetTextColor(r, g, b, a or 1)
        else
            fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        yOffset = yOffset - fs:GetStringHeight() - 8

        return fs
    end

    local titleFrame = track(CreateFrame("Frame", nil, parent))
    titleFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
    titleFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)
    titleFrame:SetHeight(24)

    local titleText = OneWoW_GUI:CreateFS(titleFrame, 16)
    titleText:SetPoint("TOPLEFT", titleFrame, "TOPLEFT", 0, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(true)
    titleText:SetWidth(ns.Favorites and (W - 22) or W)
    titleText:SetText(
        FormatAndHighlightQuestText(
            questData.name
            or string.format(L["QUESTS_UNNAMED"], questData.id or 0)
        )
    )
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    if ns.Favorites then
        titleText:SetWidth(math.min((titleText:GetStringWidth() or 0) + 2, W - 22))
    end

    if ns.Favorites then
        local detailFavBtn = OneWoW_GUI:CreateFavoriteToggleButton(titleFrame, {
            size = 14,
            favorite = ns.Favorites:IsFavorite("quests", questData.id),
            tooltipTitle = L["CATALOG_FAVORITE"],
            tooltipText = L["CATALOG_FAVORITE_TT"],
            onClick = function(_, on)
                ns.Favorites:SetFavorite("quests", questData.id, on)
                if panels and RefreshQuestList then
                    RefreshQuestList(panels)
                end
            end,
        })
        detailFavBtn:SetPoint("LEFT", titleText, "RIGHT", 4, 4)
        track(detailFavBtn)
    end

    local titleHeight = math.max(titleText:GetStringHeight() or 18, 18)
    titleFrame:SetHeight(titleHeight)
    yOffset = yOffset - titleHeight - 8

    local expName  =
        (questData.expansion ~= nil)
        and addon.QuestData:GetExpansionName(questData.expansion)
        or L["QUESTS_UNKNOWN"]

    local zoneName = ResolveQuestZoneName(questData)
    local progressName = GetQuestProgressLabel(questData.id)
    local rewardSummary = GetQuestRewardSummary(questData)
    local categoryName = FormatQuestMetadataValue(
        GetFirstMetadataValue(questData.categories)
    )
    local factionName = GetFactionDisplayName(questData.faction)
    local flagName = GetFirstMetadataValue(questData.flags)
    local mapID    = questData.mapID or 0
    local questID  = questData.id or 0
    local pinMapID, pinX, pinY = GetQuestMapTarget(questData)
    local displayMapID = pinMapID or mapID

    local function addNPCNavigationRow(label, npcData)
        if not npcData or not npcData.npcID then return end

        local npcID = tonumber(npcData.npcID)
        local fallbackNPCName = string.format(L["QUESTS_NPC_UNNAMED"], npcID or 0)
        local npcName =
            (npcID and ResolveNPCName(npcID, npcData.npcName or npcData.name))
            or (npcID and npcNameCache[npcID])
            or fallbackNPCName

        if npcID and IsGenericNPCName(npcName) then
            ScheduleNPCNameRefresh(npcID, questData)
        end

        local npcBtn = track(CreateFrame("Button", nil, parent))

        npcBtn:RegisterForClicks("LeftButtonUp")
        npcBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset + 2)
        npcBtn:SetSize(W, 16)

        local npcText = OneWoW_GUI:CreateFS(npcBtn, 11)

        npcText:SetAllPoints()
        npcText:SetJustifyH("LEFT")

        local function setLinkText(color)
            npcText:SetText(
                "|cff888888"
                .. label
                .. ": |cff"
                .. color
                .. npcName
            )
        end

        setLinkText("4dbfff")

        if npcID and IsGenericNPCName(npcName) then
            RegisterVisibleNPCName(npcID, function(resolvedName)
                if resolvedName and resolvedName ~= npcName then
                    npcName = resolvedName
                    setLinkText("4dbfff")
                end
            end)

            local rowQuestID = questData and questData.id
            local rowVersion = detailRenderVersion

            local function patchResolvedName()
                if rowVersion ~= detailRenderVersion
                    or not selectedQuest
                    or selectedQuest.id ~= rowQuestID
                then
                    return
                end

                local resolvedName = ResolveNPCName(npcID)
                if resolvedName and resolvedName ~= npcName then
                    npcName = resolvedName
                    setLinkText("4dbfff")
                end
            end

            C_Timer.After(0.2, patchResolvedName)
            C_Timer.After(0.6, patchResolvedName)
            C_Timer.After(1.2, patchResolvedName)
            C_Timer.After(2.0, patchResolvedName)
            C_Timer.After(3.0, patchResolvedName)
        end

        npcBtn:SetScript("OnEnter", function(self)
            local resolvedName =
                (npcID and ResolveNPCName(npcID, npcData.npcName or npcData.name))
                or (npcID and npcNameCache[npcID])

            if resolvedName and resolvedName ~= npcName then
                npcName = resolvedName
                setLinkText("ffd100")
            end

            setLinkText("ffd100")

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

            GameTooltip:AddLine(
                npcName,
                1,
                0.82,
                0
            )

            GameTooltip:AddLine(
                "NPC ID: " .. tostring(npcData.npcID),
                0.6,
                0.6,
                0.6
            )

            GameTooltip:AddLine(" ")

            GameTooltip:AddLine(
                "Click to add NPC to Notes and open Notes navigation",
                0,
                1,
                0
            )

            GameTooltip:Show()
        end)

        npcBtn:SetScript("OnLeave", function()
            setLinkText("4dbfff")
            GameTooltip:Hide()
        end)

        npcBtn:SetScript("OnClick", function()
            if ns.Navigation and ns.Navigation.OpenNPC then
                local resolvedName =
                    (npcID and ResolveNPCName(npcID, npcData.npcName or npcData.name))
                    or (npcID and npcNameCache[npcID])

                ns.Navigation:OpenNPC(npcData.npcID, {
                    name = resolvedName or npcName,
                    mapID = npcData.mapID or questData.mapID,
                    x = npcData.x,
                    y = npcData.y,
                    zone = questData.zoneName,
                    category = "Quest Givers",
                })
            end
        end)

        yOffset = yOffset - 20
    end

    local starterData = GetQuestStarterData(questData)
    local enderData = GetQuestEnderData(questData)

    addNPCNavigationRow(L["QUESTS_QUEST_GIVER"], starterData)

    if enderData
        and enderData.npcID
        and (
            not starterData
            or starterData.npcID ~= enderData.npcID
        )
    then
        addNPCNavigationRow(L["QUESTS_TURN_IN"], enderData)
    end

    local metaFrame = track(CreateFrame("Frame", nil, parent))

    metaFrame:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        PAD,
        yOffset
    )

    metaFrame:SetSize(W, 38)

    local metaLeft = OneWoW_GUI:CreateFS(metaFrame, 10)

    metaLeft:SetPoint("TOPLEFT", metaFrame, "TOPLEFT", 0, 0)
    metaLeft:SetPoint("TOPRIGHT", metaFrame, "TOPRIGHT", 0, 0)
    metaLeft:SetJustifyH("LEFT")
    metaLeft:SetWordWrap(true)
    metaLeft:SetWidth(W)

    local metaParts = {
        string.format("%s: %s", L["QUESTS_EXPANSION"], expName),
        string.format("%s: %s", L["QUESTS_ZONE"], zoneName),
        string.format("%s: %s", L["QUESTS_PROGRESS_LABEL"], progressName),
        string.format("%s: %s", L["QUESTS_REWARDS"], rewardSummary),
        string.format("Faction: %s", factionName),
        string.format("Category: %s", categoryName),
    }

    if flagName then
        table.insert(
            metaParts,
            string.format("Flag: %s", FormatQuestMetadataValue(flagName))
        )
    end

    metaLeft:SetText(table.concat(metaParts, "  |  "))

    metaLeft:SetTextColor(
        OneWoW_GUI:GetThemeColor("TEXT_MUTED")
    )

    local metaHeight = math.max(metaLeft:GetStringHeight() or 12, 12)
    local idMapFrame = track(CreateFrame("Frame", nil, metaFrame))
    idMapFrame:SetPoint("TOPLEFT", metaFrame, "TOPLEFT", 0, -metaHeight - 2)
    idMapFrame:SetSize(W, 16)

    local questIDText = OneWoW_GUI:CreateFS(idMapFrame, 10)
    questIDText:SetPoint("LEFT", idMapFrame, "LEFT", 0, 0)
    questIDText:SetText(HighlightSearchText(string.format("%s: %d  |  ", L["QUESTS_QUESTID"], questID)))
    questIDText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local mapBtn = track(CreateFrame("Button", nil, idMapFrame))
    mapBtn:SetPoint("LEFT", questIDText, "RIGHT", 0, 0)

    local mapText = OneWoW_GUI:CreateFS(mapBtn, 10)
    mapText:SetPoint("LEFT", mapBtn, "LEFT", 0, 0)
    mapText:SetText(string.format("%s: %d", L["QUESTS_MAPID"], displayMapID or 0))
    mapText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    mapBtn:SetSize((mapText:GetStringWidth() or 0) + 4, 16)

    metaFrame:SetHeight(metaHeight + 18)

    mapBtn:SetScript("OnEnter", function(self)
        mapText:SetTextColor(1, 0.82, 0)

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        GameTooltip:AddLine(
            zoneName,
            1,
            0.82,
            0
        )

        GameTooltip:AddLine(
            "Map ID: " .. tostring(displayMapID or 0),
            0.6,
            0.6,
            0.6
        )

        if pinX and pinY then
            GameTooltip:AddLine(
                string.format("Pin: %.1f, %.1f", pinX <= 1 and pinX * 100 or pinX, pinY <= 1 and pinY * 100 or pinY),
                0.6,
                0.6,
                0.6
            )
        end

        GameTooltip:AddLine(" ")

        GameTooltip:AddLine(
            pinX and pinY and "Click to open map and add quest giver pin" or "Click to open map",
            0,
            1,
            0
        )

        GameTooltip:Show()
    end)

    mapBtn:SetScript("OnLeave", function()
        mapText:SetTextColor(
            OneWoW_GUI:GetThemeColor("TEXT_ACCENT")
        )

        GameTooltip:Hide()
    end)

    mapBtn:SetScript("OnClick", function(_, button)
        if button and button ~= "LeftButton" then
            return
        end

        if ns.Navigation and ns.Navigation.OpenMapPin then
            ns.Navigation:OpenMapPin(
                displayMapID,
                pinX,
                pinY,
                questData.name or ("Quest " .. tostring(questID))
            )
        end
    end)

    yOffset = yOffset - metaFrame:GetHeight() - 8

    addSep()

    local descLabel = track(OneWoW_GUI:CreateFS(parent, 10))

    descLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
    descLabel:SetText(L["QUESTS_DESCRIPTION"])

    descLabel:SetTextColor(
        OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
    )

    yOffset = yOffset - 18

    -- Description Section

    local function HasDisplayQuestText(text)
        if not text then
            return false
        end

        text = tostring(text):gsub("^%s+", ""):gsub("%s+$", "")

        if text == "" then
            return false
        end

        if text == "Accept this quest to record its description and rewards." then
            return false
        end

        return true
    end

    if HasDisplayQuestText(questData.description) then
        addWrappedText(
            questData.description,
            12
        )
    else
        local noDescFs = track(OneWoW_GUI:CreateFS(parent, 12))

        noDescFs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
        noDescFs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)

        noDescFs:SetJustifyH("LEFT")
        noDescFs:SetWordWrap(true)

        noDescFs:SetText(L["QUESTS_NO_DESCRIPTION"])
        noDescFs:SetWidth(W)

        noDescFs:SetTextColor(
            OneWoW_GUI:GetThemeColor("TEXT_MUTED")
        )

        yOffset = yOffset - noDescFs:GetStringHeight() - 8
    end

    -- Objectives Section

    if questData.objectivesText
        and questData.objectivesText ~= ""
    then
        addVSpace(4)

        local objLabel = track(
            OneWoW_GUI:CreateFS(parent, 10)
        )

        objLabel:SetPoint(
            "TOPLEFT",
            parent,
            "TOPLEFT",
            PAD,
            yOffset
        )

        objLabel:SetText(L["QUESTS_OBJECTIVES"])

        objLabel:SetTextColor(
            OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
        )

        yOffset = yOffset - 16

        local objFs = track(
            OneWoW_GUI:CreateFS(parent, 12)
        )

        objFs:SetPoint(
            "TOPLEFT",
            parent,
            "TOPLEFT",
            PAD + 8,
            yOffset
        )

        objFs:SetPoint(
            "TOPRIGHT",
            parent,
            "TOPRIGHT",
            -PAD,
            yOffset
        )

        objFs:SetJustifyH("LEFT")
        objFs:SetWordWrap(true)

        objFs:SetText(
            FormatAndHighlightQuestText(questData.objectivesText)
        )

        objFs:SetWidth(W - 8)

        objFs:SetTextColor(
            OneWoW_GUI:GetThemeColor("TEXT_MUTED")
        )

        yOffset = yOffset - objFs:GetStringHeight() - 8
    end

    -- Rewards Section

    local hasRewards =
        (questData.rewardGold and questData.rewardGold > 0)
        or (questData.rewardXP and questData.rewardXP > 0)
        or (questData.rewardItems and #questData.rewardItems > 0)
        or (questData.rewardCurrencies and #questData.rewardCurrencies > 0)

    if hasRewards then

        addSep()

        local rwdLabel = track(
            OneWoW_GUI:CreateFS(parent, 10)
        )

        rwdLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
        rwdLabel:SetText(L["QUESTS_REWARDS"])

        rwdLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        yOffset = yOffset - 18

        if questData.rewardGold and questData.rewardGold > 0 then
            local goldText = track(OneWoW_GUI:CreateFS(parent, 12))

            goldText:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            goldText:SetText(L["QUESTS_GOLD"] .. ": " .. OneWoW.Format.FormatGold(questData.rewardGold))
            goldText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            yOffset = yOffset - 18
        end

        if questData.rewardXP and questData.rewardXP > 0 then
            local xpText = track(OneWoW_GUI:CreateFS(parent, 12))

            xpText:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            xpText:SetText(L["QUESTS_XP"] .. ": " .. OneWoW.Format.FormatNumber(questData.rewardXP))
            xpText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            yOffset = yOffset - 18
        end

        if questData.rewardCurrencies and #questData.rewardCurrencies > 0 then
            local currHdr = track(OneWoW_GUI:CreateFS(parent, 10))

            currHdr:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            currHdr:SetText("Currencies:")

            currHdr:SetTextColor(
                OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
            )

            yOffset = yOffset - 18

            for _, rewardCurrency in ipairs(questData.rewardCurrencies) do
                local currencyID, quantity, iconTexture, currencyName =
                    GetCurrencyRewardInfo(rewardCurrency)

                if currencyID then
                    local currencyFrame = track(CreateFrame("Button", nil, parent))
                    currencyFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 16, yOffset)
                    currencyFrame:SetSize(W - 24, 18)

                    local icon = currencyFrame:CreateTexture(nil, "ARTWORK")
                    icon:SetSize(14, 14)
                    icon:SetPoint("LEFT", currencyFrame, "LEFT", 0, 0)
                    icon:SetTexture(iconTexture)

                    local currencyText = OneWoW_GUI:CreateFS(currencyFrame, 12)
                    currencyText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
                    currencyText:SetPoint("RIGHT", currencyFrame, "RIGHT", -2, 0)
                    currencyText:SetJustifyH("LEFT")
                    currencyText:SetWordWrap(false)
                    currencyText:SetText(
                        currencyName
                        .. (
                            quantity and quantity > 1
                            and (" x" .. tostring(quantity))
                            or ""
                        )
                    )
                    currencyText:SetTextColor(
                        OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
                    )

                    currencyFrame:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

                        GameTooltip:SetCurrencyByID(currencyID, quantity)

                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Currency ID: " .. tostring(currencyID), 0.6, 0.6, 0.6)
                        GameTooltip:Show()
                    end)

                    currencyFrame:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)

                    yOffset = yOffset - 20
                end
            end
        end

        if questData.rewardItems and #questData.rewardItems > 0 then
            local itemHdr = track(OneWoW_GUI:CreateFS(parent, 10))

            itemHdr:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)

            itemHdr:SetText(L["QUESTS_ITEMS"] .. ":")

            itemHdr:SetTextColor(
                OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
            )

            yOffset = yOffset - 18

            local gridGap = 8
            local rowHeight = 22
            local gridWidth = W - 16
            local itemColumns = math.max(1, math.min(5, math.floor((gridWidth + gridGap) / 190)))
            local itemColumnWidth = math.floor((gridWidth - (gridGap * (itemColumns - 1))) / itemColumns)
            local rewardItemEntries = {}
            local immediateItemInfoBudget = 8
            local immediateTooltipInfoBudget = 8

            for _, rewardItem in ipairs(questData.rewardItems) do
                local itemID
                local itemCount = 1

                if type(rewardItem) == "number" then
                    itemID = rewardItem
                elseif type(rewardItem) == "table" then
                    itemID = rewardItem.itemID
                    itemCount = rewardItem.count or 1
                end

                if itemID then
                    table.insert(rewardItemEntries, {
                        itemID = itemID,
                        itemCount = itemCount,
                    })
                end
            end

            local function renderRewardItem(entry, itemIndex)
                local itemID = entry.itemID
                local itemCount = entry.itemCount or 1

                if itemID then
                    local itemName =
                        addon.QuestData
                        and addon.QuestData.GetCachedItemName
                        and addon.QuestData:GetCachedItemName(itemID)

                    local itemLink, itemQuality, itemTexture
                    local itemIsQueued = pendingRewardItemIDs[itemID]

                    local loader = ns.GetItemDataLoader()
                    local cachedItem = loader:GetCachedItem(itemID)

                    if cachedItem then
                        itemName = itemName or cachedItem.name
                        itemLink = itemLink or cachedItem.link
                        itemQuality = itemQuality or cachedItem.quality
                        itemTexture = itemTexture or cachedItem.icon
                    end

                    if not itemIsQueued and immediateItemInfoBudget > 0 then
                        immediateItemInfoBudget = immediateItemInfoBudget - 1

                        local fetchedName
                        fetchedName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture =
                            C_Item.GetItemInfo(itemID)

                        if fetchedName then
                            itemName = fetchedName
                        end
                    end

                    if not itemName
                        and not itemIsQueued
                        and immediateTooltipInfoBudget > 0
                    then
                        immediateTooltipInfoBudget = immediateTooltipInfoBudget - 1
                        itemName = loader:GetTooltipItemName(itemID)
                    end

                    if itemName and addon.QuestData and addon.QuestData.RememberItemName then
                        pendingRewardItemIDs[itemID] = nil
                        RememberAndApplyRewardItemName(itemID, itemName)
                    elseif not itemName then
                        RequestVisibleRewardItem(itemID)
                    end

                    local itemNameUnresolved = not itemName

                    itemName =
                        itemName
                        or string.format(L["QUESTS_ITEM_UNNAMED"], itemID)

                    if not itemTexture then
                        itemTexture = select(5, C_Item.GetItemInfoInstant(itemID))
                    end

                    itemTexture =
                        itemTexture
                        or 134400

                    local itemFrame = track(
                        CreateFrame("Button", nil, parent)
                    )

                    local columnIndex = ((itemIndex - 1) % itemColumns)
                    local rowIndex = math.floor((itemIndex - 1) / itemColumns)
                    local itemX = PAD + 16 + (columnIndex * (itemColumnWidth + gridGap))
                    local itemY = yOffset - (rowIndex * rowHeight)

                    itemFrame:SetPoint(
                        "TOPLEFT",
                        parent,
                        "TOPLEFT",
                        itemX,
                        itemY
                    )

                    itemFrame:SetSize(itemColumnWidth, 18)

                    local icon = itemFrame:CreateTexture(
                        nil,
                        "ARTWORK"
                    )

                    icon:SetSize(14, 14)
                    icon:SetPoint("LEFT", itemFrame, "LEFT", 0, 0)
                    icon:SetTexture(itemTexture)

                    local itemText = OneWoW_GUI:CreateFS(
                        itemFrame,
                        12
                    )

                    itemText:SetPoint(
                        "LEFT",
                        icon,
                        "RIGHT",
                        6,
                        0
                    )

                    itemText:SetPoint(
                        "RIGHT",
                        itemFrame,
                        "RIGHT",
                        -2,
                        0
                    )

                    itemText:SetJustifyH("LEFT")
                    itemText:SetWordWrap(false)

                    local countStr =
                        (itemCount and itemCount > 1)
                        and (" x" .. itemCount)
                        or ""

                    itemText:SetText(HighlightSearchText(itemName) .. countStr)

                    if itemNameUnresolved then
                        visibleRewardItemRows[itemID] = visibleRewardItemRows[itemID] or {}

                        table.insert(visibleRewardItemRows[itemID], {
                            renderVersion = detailRenderVersion,
                            apply = function(resolvedName)
                                if not resolvedName or resolvedName == "" then
                                    return
                                end

                                itemName = resolvedName
                                itemNameUnresolved = false
                                itemText:SetText(HighlightSearchText(itemName) .. countStr)

                                local _, _, resolvedQuality = C_Item.GetItemInfo(itemID)
                                if resolvedQuality then
                                    local r, g, b = GetItemQualityColor(resolvedQuality)
                                    itemText:SetTextColor(r, g, b)
                                end
                            end,
                        })
                    end

                    if itemQuality then
                        local r, g, b =
                            GetItemQualityColor(itemQuality)

                        itemText:SetTextColor(r, g, b)
                    else
                        itemText:SetTextColor(
                            OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
                        )
                    end

                    itemFrame:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(
                            self,
                            "ANCHOR_RIGHT"
                        )

                        GameTooltip:SetItemByID(itemID)

                        local tooltipName =
                            GetVisibleTooltipItemName()
                            or ns.GetItemDataLoader():GetTooltipItemName(itemID)

                        if tooltipName
                            and tooltipName ~= itemName
                            and RememberAndApplyRewardItemName(itemID, tooltipName)
                        then
                            itemName = tooltipName
                            pendingRewardItemIDs[itemID] = nil
                            itemText:SetText(HighlightSearchText(itemName) .. countStr)
                        end

                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(L["QUESTS_TT_ITEM_OPEN_SEARCH"], 0, 1, 0)
                        GameTooltip:AddLine(L["QUESTS_TT_ITEM_PREVIEW"], 0, 1, 0)
                        GameTooltip:AddLine(L["QUESTS_TT_ITEM_ADD_NOTES"], 0, 1, 0)
                        GameTooltip:Show()
                    end)

                    itemFrame:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)

                    itemFrame:SetScript("OnClick", function()
                        if HandleItemPreviewClick(itemID, itemLink) then
                            return
                        end

                        -- Pass nil rather than the localized "Item #N"
                        -- placeholder when the real name never resolved.
                        local resolvedName = not itemNameUnresolved and itemName or nil

                        if IsShiftKeyDown and IsShiftKeyDown() then
                            AddRewardItemToNotes(
                                itemID,
                                resolvedName,
                                itemLink,
                                itemTexture,
                                itemQuality
                            )
                            return
                        end

                        OpenRewardItemInItemSearch(itemID, resolvedName)
                    end)
                end
            end

            for itemIndex = 1, #rewardItemEntries do
                renderRewardItem(rewardItemEntries[itemIndex], itemIndex)
            end

            local itemIndex = #rewardItemEntries

            if itemIndex > 0 then
                yOffset = yOffset - (math.ceil(itemIndex / itemColumns) * rowHeight)
            end
        end

        addVSpace(4)
    end

    addSep()

    local compLabel = track(OneWoW_GUI:CreateFS(parent, 10))

    compLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
    compLabel:SetText(L["QUESTS_COMPLETION"])

    compLabel:SetTextColor(
        OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
    )

    yOffset = yOffset - 18

    local completedChars =
        tracker and tracker:GetCompletedCharacters(questData.id)
        or {}

    if #completedChars == 0 then
        local noCharText = track(OneWoW_GUI:CreateFS(parent, 12))

        noCharText:SetPoint(
            "TOPLEFT",
            parent,
            "TOPLEFT",
            PAD + 8,
            yOffset
        )

        noCharText:SetText(L["QUESTS_NOT_COMPLETED"])

        noCharText:SetTextColor(
            OneWoW_GUI:GetThemeColor("TEXT_MUTED")
        )

        yOffset = yOffset - 18
    else
        for _, charInfo in ipairs(completedChars) do
            local rowFrame = track(CreateFrame("Frame", nil, parent))

            rowFrame:SetHeight(18)

            rowFrame:SetPoint(
                "TOPLEFT",
                parent,
                "TOPLEFT",
                PAD + 8,
                yOffset
            )

            rowFrame:SetPoint(
                "TOPRIGHT",
                parent,
                "TOPRIGHT",
                -PAD,
                yOffset
            )

            local checkTex = rowFrame:CreateTexture(nil, "ARTWORK")

            checkTex:SetSize(14, 14)
            checkTex:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)

            checkTex:SetTexture(
                "Interface\\Buttons\\UI-CheckBox-Check"
            )

            checkTex:SetVertexColor(
                OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED")
            )

            local charText = OneWoW_GUI:CreateFS(rowFrame, 12)

            charText:SetPoint("LEFT", checkTex, "RIGHT", 4, 0)
            charText:SetText(charInfo.name)

            charText:SetTextColor(
                OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED")
            )

            yOffset = yOffset - 20
        end
    end

    addVSpace(4)

    local chainIDs = GetQuestChainIDs(questData)
    if chainIDs then
        addSep()

        local chainLabel = track(OneWoW_GUI:CreateFS(parent, 10))
        chainLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
        chainLabel:SetText(L["QUESTS_CHAIN"])
        chainLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        yOffset = yOffset - 20

        local xOffset = PAD + 8
        local rowY = yOffset
        local rowHeight = 20

        local function getChainName(chainQuestID)
            local chainQuest =
                addon.QuestData
                and addon.QuestData:GetQuest(chainQuestID)

            return chainQuest
                and chainQuest.name
                or GetQuestDisplayName(chainQuestID, questData)
                or ("Quest " .. tostring(chainQuestID))
        end

        local segments = {}
        local index = 1
        while index <= #chainIDs do
            local chainQuestID = chainIDs[index]
            local chainName = getChainName(chainQuestID)
            local run = { chainQuestID }
            local nextIndex = index + 1

            while nextIndex <= #chainIDs
                and getChainName(chainIDs[nextIndex]) == chainName
            do
                table.insert(run, chainIDs[nextIndex])
                nextIndex = nextIndex + 1
            end

            if #run >= 3 then
                table.insert(segments, {
                    type = "group",
                    name = chainName,
                    ids = run,
                    key = tostring(questData.id or 0) .. ":" .. tostring(index) .. ":" .. chainName,
                })
            else
                for _, runQuestID in ipairs(run) do
                    table.insert(segments, {
                        type = "quest",
                        id = runQuestID,
                        name = getChainName(runQuestID),
                    })
                end
            end

            index = nextIndex
        end

        local function getGroupColor(segment)
            local hasActive = false
            local allCompleted = true

            for _, groupQuestID in ipairs(segment.ids) do
                if C_QuestLog.IsOnQuest(groupQuestID) then
                    hasActive = true
                end

                if not (tracker and tracker.IsCompletedByCurrentChar and tracker:IsCompletedByCurrentChar(groupQuestID)) then
                    allCompleted = false
                end
            end

            if hasActive then
                return 0.3, 1, 0.3
            elseif allCompleted then
                return 0.72, 0.72, 0.72
            end

            return 1, 0.82, 0
        end

        local function addChainToken(text, r, g, b, onClick, onEnter, onLeave, questID)
            local questBtn = track(CreateFrame("Button", nil, parent))
            local questText = OneWoW_GUI:CreateFS(questBtn, 12)
            questText:SetPoint("LEFT", questBtn, "LEFT", 0, 0)
            questText:SetText(HighlightSearchText(text))
            questText:SetTextColor(r, g, b)
            RegisterVisibleQuestName(questID, questText, nil, nil, HighlightSearchText)

            local btnWidth = questText:GetStringWidth() + 4
            if xOffset + btnWidth > W and xOffset > PAD + 8 then
                xOffset = PAD + 8
                rowY = rowY - rowHeight
            end

            questBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, rowY)
            questBtn:SetSize(btnWidth, 18)
            questBtn:SetScript("OnClick", onClick)
            questBtn:SetScript("OnEnter", function(self)
                questText:SetTextColor(1, 1, 1)
                if onEnter then
                    onEnter(self)
                end
            end)
            questBtn:SetScript("OnLeave", function()
                questText:SetTextColor(r, g, b)
                if onLeave then
                    onLeave()
                end
            end)

            xOffset = xOffset + btnWidth
        end

        for segmentIndex, segment in ipairs(segments) do
            if segment.type == "group" then
                local r, g, b = getGroupColor(segment)
                local groupText = segment.name .. " x" .. tostring(#segment.ids)

                addChainToken(
                    groupText,
                    r,
                    g,
                    b,
                    function()
                        questChainGroupExpanded[segment.key] =
                            not questChainGroupExpanded[segment.key]
                        ShowQuestDetail(panels, questData)
                    end,
                    function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(groupText, 1, 0.82, 0)
                        GameTooltip:AddLine(tostring(#segment.ids) .. " quests grouped by shared name", 0.6, 0.6, 0.6)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(
                            questChainGroupExpanded[segment.key] and "Click to collapse" or "Click to expand",
                            0,
                            1,
                            0
                        )
                        GameTooltip:Show()
                    end,
                    function()
                        GameTooltip:Hide()
                    end,
                    nil
                )
            else
                local r, g, b = GetQuestChainColor(segment.id, tracker)

                addChainToken(
                    segment.name,
                    r,
                    g,
                    b,
                    function()
                        if OpenQuestByID then
                            OpenQuestByID(segment.id, panels)
                        end
                    end,
                    function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(segment.name, 1, 0.82, 0)
                        GameTooltip:AddLine("Quest ID: " .. tostring(segment.id), 0.6, 0.6, 0.6)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Click to open this quest", 0, 1, 0)
                        GameTooltip:Show()
                    end,
                    function()
                        GameTooltip:Hide()
                    end,
                    segment.id
                )
            end

            if segmentIndex < #segments then
                local sepText = track(OneWoW_GUI:CreateFS(parent, 12))
                sepText:SetText(" > ")
                sepText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                local sepWidth = sepText:GetStringWidth()
                if xOffset + sepWidth > W then
                    xOffset = PAD + 8
                    rowY = rowY - rowHeight
                end

                sepText:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, rowY)
                xOffset = xOffset + sepWidth
            end
        end

        yOffset = rowY - rowHeight - 4

        for _, segment in ipairs(segments) do
            if segment.type == "group" and questChainGroupExpanded[segment.key] then
                local groupLabel = track(OneWoW_GUI:CreateFS(parent, 10))
                groupLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 16, yOffset)
                groupLabel:SetText(HighlightSearchText(segment.name) .. " (" .. tostring(#segment.ids) .. ")")
                groupLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                yOffset = yOffset - 18

                for _, groupQuestID in ipairs(segment.ids) do
                    local groupQuestName = getChainName(groupQuestID)
                    local r, g, b = GetQuestChainColor(groupQuestID, tracker)
                    local childBtn = track(CreateFrame("Button", nil, parent))
                    childBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 24, yOffset)
                    childBtn:SetSize(W - 32, 16)

                    local childText = OneWoW_GUI:CreateFS(childBtn, 11)
                    childText:SetPoint("LEFT", childBtn, "LEFT", 0, 0)
                    childText:SetPoint("RIGHT", childBtn, "RIGHT", 0, 0)
                    childText:SetJustifyH("LEFT")
                    childText:SetWordWrap(false)
                    childText:SetText(tostring(groupQuestID) .. " - " .. HighlightSearchText(groupQuestName))
                    childText:SetTextColor(r, g, b)
                    RegisterVisibleQuestName(groupQuestID, childText, tostring(groupQuestID) .. " - ", nil, HighlightSearchText)

                    childBtn:SetScript("OnClick", function()
                        if OpenQuestByID then
                            OpenQuestByID(groupQuestID, panels)
                        end
                    end)
                    childBtn:SetScript("OnEnter", function(self)
                        childText:SetTextColor(1, 1, 1)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(groupQuestName, 1, 0.82, 0)
                        GameTooltip:AddLine("Quest ID: " .. tostring(groupQuestID), 0.6, 0.6, 0.6)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Click to open this quest", 0, 1, 0)
                        GameTooltip:Show()
                    end)
                    childBtn:SetScript("OnLeave", function()
                        childText:SetTextColor(r, g, b)
                        GameTooltip:Hide()
                    end)

                    yOffset = yOffset - 18
                end

                yOffset = yOffset - 4
            end
        end
    end

    panels.detailScrollChild:SetHeight(math.abs(yOffset) + 20)
end

local function UpdateQuestListEntry(btn, quest, panels)
    local addon   = GetDataAddon()
    if not addon then return end
    local tracker = addon.CompletionTracker

    local entry = quest
    quest = entry and entry.quest or entry

    btn.entry = entry
    btn.quest = quest
    btn.isGroup = entry and entry.type == "group"
    btn.isChild = entry and entry.type == "child"
    btn.isSection = entry and entry.type == "section"

    if btn.isSection then
        if btn.groupToggle then btn.groupToggle:Hide() end
        if btn.checkTex then btn.checkTex:Hide() end
        if btn.favBtn then btn.favBtn:Hide() end
        if btn.subText then btn.subText:SetText("") end

        if btn.nameText then
            btn.nameText:ClearAllPoints()
            btn.nameText:SetPoint("LEFT", btn, "LEFT", 8, 0)
            btn.nameText:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
            btn.nameText:SetText(entry.label or "Favorites")
            btn.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end

        btn:SetBackdropColor(0.025, 0.04, 0.03, 0.9)
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        return
    end

    if btn.groupToggle then
        if btn.isGroup then
            if btn.groupToggleText then
                btn.groupToggleText:SetText(questListGroupExpanded[entry.key] and "v" or ">")
            end
            btn.groupToggle:Show()
        else
            btn.groupToggle:Hide()
        end
    end

    if btn.nameText then
        local nameText =
            btn.isGroup
            and ((entry.name or "Grouped Quests") .. " x" .. tostring(entry.count or 0))
            or (
                quest.name
                or string.format(L["QUESTS_UNNAMED"], quest.id or 0)
            )

        btn.nameText:ClearAllPoints()
        btn.nameText:SetPoint("TOPLEFT", btn, "TOPLEFT", btn.isChild and 28 or 8, -6)
        btn.nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", btn.isGroup and -58 or -44, -6)
        btn.nameText:SetText(nameText)

        if selectedQuest and quest and selectedQuest.id == quest.id then
            btn.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        elseif btn.isGroup then
            btn.nameText:SetTextColor(1, 0.82, 0)
        else
            btn.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    local expName = ""
    if btn.isGroup and entry.expansionName then
        expName = entry.expansionName
    elseif quest and quest.expansion ~= nil then
        expName = addon.QuestData:GetExpansionName(quest.expansion) or ""
    end

    if btn.subText then
        btn.subText:ClearAllPoints()
        btn.subText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", btn.isChild and 28 or 8, 6)
        btn.subText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -44, 6)
        btn.subText:SetText(expName)
    end

    local isCompleted = false
    local hasActive = false

    if btn.isGroup then
        local groupStatus = questGroupStatusCache[entry.key]

        if not groupStatus then
            groupStatus = { isCompleted = true, hasActive = false }

            for _, childQuest in ipairs(entry.quests or {}) do
                if C_QuestLog.IsOnQuest(childQuest.id) then
                    groupStatus.hasActive = true
                end

                if not (tracker and tracker:IsCompletedByCurrentChar(childQuest.id)) then
                    groupStatus.isCompleted = false
                end
            end

            questGroupStatusCache[entry.key] = groupStatus
        end

        isCompleted = groupStatus.isCompleted
        hasActive = groupStatus.hasActive
    else
        local rowStatus =
            quest
            and quest.id
            and questRowStatusCache[quest.id]

        if not rowStatus and quest and quest.id then
            rowStatus = {
                isCompleted =
                    tracker
                    and tracker:IsCompletedByCurrentChar(quest.id),

                hasActive =
                    C_QuestLog
                    and C_QuestLog.IsOnQuest
                    and C_QuestLog.IsOnQuest(quest.id),

                isFavorite =
                    ns.Favorites
                    and ns.Favorites:IsFavorite("quests", quest.id),
            }

            questRowStatusCache[quest.id] = rowStatus
        end

        if rowStatus then
            isCompleted = rowStatus.isCompleted
            hasActive = rowStatus.hasActive
        end
    end

    if btn.checkTex then
        btn.checkTex:ClearAllPoints()
        btn.checkTex:SetPoint("RIGHT", btn, "RIGHT", btn.isGroup and -40 or -28, 0)

        if isCompleted or hasActive then
            if hasActive and not isCompleted then
                btn.checkTex:SetVertexColor(0.3, 1, 0.3)
            else
                btn.checkTex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            end
            btn.checkTex:Show()
        else
            btn.checkTex:Hide()
        end
    end

    if btn.favBtn and ns.Favorites then
        if btn.isGroup then
            btn.favBtn:Hide()
        else
            btn.favBtn:Show()
            local rowStatus =
                quest
                and quest.id
                and questRowStatusCache[quest.id]
            btn.favBtn:SetFavorite(rowStatus and rowStatus.isFavorite)
        end
    end

    if selectedQuest and quest and selectedQuest.id == quest.id then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
    elseif btn.isChild then
        btn:SetBackdropColor(0.035, 0.06, 0.04, 0.82)
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    end
end

local function CreateQuestListEntry(parent, quest, yOffset, panels, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(QUEST_LIST_ROW_FRAME_HEIGHT)
    btn:SetPoint("TOPLEFT",  parent, "TOPLEFT",  4, yOffset)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yOffset)
    btn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local nameText = OneWoW_GUI:CreateFS(btn, 12)
    nameText:SetPoint("TOPLEFT",  btn, "TOPLEFT",  8, -6)
    nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -44, -6)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    btn.nameText = nameText

    local subText = OneWoW_GUI:CreateFS(btn, 10)
    subText:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  8, 6)
    subText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -44, 6)
    subText:SetJustifyH("LEFT")
    subText:SetWordWrap(false)
    subText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    btn.subText = subText

    local checkTex = btn:CreateTexture(nil, "ARTWORK")
    checkTex:SetSize(14, 14)
    checkTex:SetPoint("RIGHT", btn, "RIGHT", -28, 0)
    checkTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkTex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    checkTex:Hide()
    btn.checkTex = checkTex

    local groupToggle = CreateFrame("Button", nil, btn, "BackdropTemplate")
    groupToggle:SetSize(18, 18)
    groupToggle:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    groupToggle:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    groupToggle:SetBackdropColor(0.08, 0.06, 0.01, 0.9)
    groupToggle:SetBackdropBorderColor(1, 0.82, 0)

    local groupToggleText = OneWoW_GUI:CreateFS(groupToggle, 16)
    groupToggleText:SetAllPoints()
    groupToggleText:SetJustifyH("CENTER")
    groupToggleText:SetJustifyV("MIDDLE")
    groupToggleText:SetTextColor(1, 0.82, 0)

    groupToggle:SetScript("OnClick", function()
        if onClick and btn.entry then
            onClick(btn.entry, btn)
        end
    end)
    groupToggle:Hide()
    btn.groupToggle = groupToggle
    btn.groupToggleText = groupToggleText

    if ns.Favorites then
        local favBtn = OneWoW_GUI:CreateFavoriteToggleButton(btn, {
            size     = 18,
            favorite = false,
            tooltipTitle = L["CATALOG_FAVORITE"],
            tooltipText  = L["CATALOG_FAVORITE_TT"],
            onClick = function(favSelf, on)
                if not btn.quest then return end
                ns.Favorites:SetFavorite("quests", btn.quest.id, on)
                RefreshQuestList(panels)
            end,
        })
        favBtn:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -4, -6)
        btn.favBtn = favBtn
    end

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        if self.nameText then
            self.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.isSection then
            self:SetBackdropColor(0.025, 0.04, 0.03, 0.9)
            if self.nameText then
                self.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            end
        elseif selectedQuest and self.quest and selectedQuest.id == self.quest.id then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            if self.nameText then
                self.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        elseif self.isGroup then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            if self.nameText then
                self.nameText:SetTextColor(1, 0.82, 0)
            end
        elseif self.isChild then
            self:SetBackdropColor(0.035, 0.06, 0.04, 0.82)
            if self.nameText then
                self.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            if self.nameText then
                self.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end
    end)
    btn:SetScript("OnClick", function(self)
        if onClick and self.entry then
            onClick(self.entry, self)
        end
    end)

    if quest then
        UpdateQuestListEntry(btn, quest, panels)
    end

    return btn
end

local function GetQuestListGroupName(quest)
    return quest
        and (
            quest.name
            or string.format(L["QUESTS_UNNAMED"], quest.id or 0)
        )
        or ""
end

local function GetQuestListGroupKey(quest)
    return table.concat({
        GetQuestListGroupName(quest),
        tostring(quest and quest.expansion or ""),
    }, "\031")
end

local function BuildQuestListEntries(quests)
    local addon = GetDataAddon()
    local entries = {}
    local index = 1

    while index <= #quests do
        local quest = quests[index]
        local groupKey = GetQuestListGroupKey(quest)
        local groupName = GetQuestListGroupName(quest)
        local groupQuests = { quest }
        local nextIndex = index + 1

        while nextIndex <= #quests
            and GetQuestListGroupKey(quests[nextIndex]) == groupKey
        do
            table.insert(groupQuests, quests[nextIndex])
            nextIndex = nextIndex + 1
        end

        if #groupQuests >= 3 then
            local expansionName = ""
            if addon and addon.QuestData and quest.expansion ~= nil then
                expansionName = addon.QuestData:GetExpansionName(quest.expansion) or ""
            end

            table.insert(entries, {
                type = "group",
                key = groupKey,
                name = groupName,
                expansionName = expansionName,
                count = #groupQuests,
                quests = groupQuests,
                quest = groupQuests[1],
            })

            if questListGroupExpanded[groupKey] then
                for _, childQuest in ipairs(groupQuests) do
                    table.insert(entries, {
                        type = "child",
                        key = groupKey .. ":" .. tostring(childQuest.id),
                        parentKey = groupKey,
                        quest = childQuest,
                    })
                end
            end
        else
            for _, runQuest in ipairs(groupQuests) do
                table.insert(entries, {
                    type = "quest",
                    quest = runQuest,
                })
            end
        end

        index = nextIndex
    end

    return entries
end

local function GetFavoriteQuestsOutsideActiveList(addon, activeQuests)
    if not (addon and addon.QuestData and ns.Favorites) then
        return {}
    end

    local activeIDs = {}
    for _, quest in ipairs(activeQuests or {}) do
        if quest and quest.id then
            activeIDs[quest.id] = true
        end
    end

    local favorites = {}
    local favBucket =
        ns.addon
        and ns.addon.db
        and ns.addon.db.global
        and ns.addon.db.global.favorites
        and ns.addon.db.global.favorites.quests

    if not favBucket then
        return favorites
    end

    for questID in pairs(favBucket) do
        questID = tonumber(questID)
        local quest =
            questID
            and not activeIDs[questID]
            and addon.QuestData:GetQuest(questID)

        if quest and quest.id then
            table.insert(favorites, quest)
        end
    end

    table.sort(favorites, function(a, b)
        local aName = a.name or ""
        local bName = b.name or ""
        if aName ~= bName then
            return aName < bName
        end
        return (a.id or 0) < (b.id or 0)
    end)

    return favorites
end

local function BuildQuestListDisplayEntries(quests, favoriteQuests)
    local entries = BuildQuestListEntries(quests or {})

    if favoriteQuests and #favoriteQuests > 0 then
        table.insert(entries, {
            type = "section",
            key = "favorites-section",
            label = "Favorites",
        })

        local favoriteEntries = BuildQuestListEntries(favoriteQuests)
        for _, entry in ipairs(favoriteEntries) do
            table.insert(entries, entry)
        end
    end

    return entries
end

local function GetQuestListVisibleRowCount(panels)
    local h =
        panels
        and panels.listScrollFrame
        and panels.listScrollFrame:GetHeight()
        or 0

    if h <= 0 then
        h = 560
    end

    return math.max(1, math.ceil(h / QUEST_LIST_ROW_HEIGHT))
end

local function GetQuestListVisibleCapacity(panels)
    local visibleRows = GetQuestListVisibleRowCount(panels)

    return math.max(
        8,
        visibleRows + QUEST_LIST_BUFFER_ROWS
    )
end

local function EnsureQuestListRows(panels, onClick)
    local capacity = GetQuestListVisibleCapacity(panels)
    local rowParent =
        panels.questListViewport
        or panels.listScrollFrame
        or panels.listScrollChild

    for i = #questListButtons + 1, capacity do
        local btn = CreateQuestListEntry(
            rowParent,
            nil,
            -4,
            panels,
            onClick
        )
        btn:Hide()
        table.insert(questListButtons, btn)
    end

    return capacity
end

UpdateVisibleQuestRows = function(panels)
    if not panels then return end

    local entries = panels._questListEntries or panels._questResults or {}
    local total = #entries
    local capacity = GetQuestListVisibleCapacity(panels)
    local visibleRows = GetQuestListVisibleRowCount(panels)

    if #questListButtons < capacity and panels._questListOnClick then
        EnsureQuestListRows(panels, panels._questListOnClick)
    end

    local offset = 0
    if panels.listScrollFrame
        and panels.listScrollFrame.GetVerticalScroll
    then
        offset = panels.listScrollFrame:GetVerticalScroll() or 0
    end

    local firstIndex = math.floor(offset / QUEST_LIST_ROW_HEIGHT) + 1
    local maxFirst = math.max(1, total - visibleRows + 1)

    if firstIndex > maxFirst then
        firstIndex = maxFirst
    end

    for rowIndex, btn in ipairs(questListButtons) do
        if rowIndex <= capacity then
            local questIndex = firstIndex + rowIndex - 1
            local entry = entries[questIndex]

            if entry then
                btn:ClearAllPoints()
                btn:SetPoint(
                    "TOPLEFT",
                    panels.questListViewport or panels.listScrollFrame or panels.listScrollChild,
                    "TOPLEFT",
                    4,
                    -4 - ((rowIndex - 1) * QUEST_LIST_ROW_HEIGHT)
                )
                btn:SetPoint(
                    "TOPRIGHT",
                    panels.questListViewport or panels.listScrollFrame or panels.listScrollChild,
                    "TOPRIGHT",
                    -4,
                    -4 - ((rowIndex - 1) * QUEST_LIST_ROW_HEIGHT)
                )
                UpdateQuestListEntry(btn, entry, panels)
                btn:Show()
            else
                btn:Hide()
            end
        else
            btn:Hide()
        end
    end
end

local function EnsureQuestVisible(panels, questIndex)
    if not panels
        or not questIndex
        or not panels.listScrollFrame
        or not panels.listScrollFrame.SetVerticalScroll
    then
        return
    end

    local viewHeight =
        panels.listScrollFrame.GetHeight
        and panels.listScrollFrame:GetHeight()
        or 0

    if viewHeight <= 0 then
        return
    end

    local currentScroll =
        panels.listScrollFrame.GetVerticalScroll
        and panels.listScrollFrame:GetVerticalScroll()
        or 0

    local rowTop = (questIndex - 1) * QUEST_LIST_ROW_HEIGHT
    local rowBottom = rowTop + QUEST_LIST_ROW_HEIGHT
    local targetScroll = currentScroll

    if rowTop < currentScroll then
        targetScroll = rowTop
    elseif rowBottom > currentScroll + viewHeight then
        targetScroll = rowBottom - viewHeight
    end

    local maxScroll = math.max(
        0,
        (panels.listScrollChild and panels.listScrollChild:GetHeight() or 0) - viewHeight
    )

    panels.listScrollFrame:SetVerticalScroll(math.max(0, math.min(targetScroll, maxScroll)))
end

local function ClampQuestListScroll(panels, requestedScroll)
    if not panels
        or not panels.listScrollFrame
        or not panels.listScrollFrame.SetVerticalScroll
        or not panels.listScrollChild
    then
        return 0
    end

    if panels.listScrollFrame.UpdateScrollChildRect then
        panels.listScrollFrame:UpdateScrollChildRect()
    end

    local frameHeight =
        panels.listScrollFrame.GetHeight
        and panels.listScrollFrame:GetHeight()
        or 0

    local childHeight =
        panels.listScrollChild.GetHeight
        and panels.listScrollChild:GetHeight()
        or 0

    local maxScroll = math.max(0, childHeight - frameHeight)
    local targetScroll = math.max(0, math.min(requestedScroll or 0, maxScroll))

    panels.listScrollFrame:SetVerticalScroll(targetScroll)
    return targetScroll
end

local function RefreshQuestListViewport(panels, requestedScroll, listVersion)
    local function repaint()
        if not panels or (listVersion and panels._questListVersion ~= listVersion) then
            return
        end

        ClampQuestListScroll(panels, requestedScroll)
        UpdateVisibleQuestRows(panels)
    end

    repaint()

    C_Timer.After(0, repaint)
    C_Timer.After(0.05, repaint)
end

local function SelectQuestFromList(panels, quest, questIndex)
    if not panels or not quest then
        return
    end

    selectedQuest = quest
    EnsureQuestVisible(panels, questIndex)
    ShowQuestDetail(panels, quest)
    UpdateVisibleQuestRows(panels)
end

local function MoveQuestSelection(panels, delta)
    local entries = panels and (panels._questListEntries or panels._questResults)
    if not entries or #entries == 0 then
        return
    end

    local selectedID = selectedQuest and selectedQuest.id
    local selectedIndex = nil

    if selectedID then
        for i, entry in ipairs(entries) do
            local quest = entry.quest or entry
            if quest and quest.id == selectedID then
                selectedIndex = i
                break
            end
        end
    end

    selectedIndex = selectedIndex or (delta > 0 and 0 or #entries + 1)

    local nextIndex = selectedIndex + delta
    while nextIndex >= 1 and nextIndex <= #entries do
        local entry = entries[nextIndex]
        if entry and entry.type ~= "group" and entry.quest then
            SelectQuestFromList(panels, entry.quest, nextIndex)
            return
        end

        nextIndex = nextIndex + delta
    end

    if nextIndex < 1 then
        for i = 1, #entries do
            local entry = entries[i]
            if entry and entry.type ~= "group" and entry.quest then
                SelectQuestFromList(panels, entry.quest, i)
                return
            end
        end
    elseif nextIndex > #entries then
        for i = #entries, 1, -1 do
            local entry = entries[i]
            if entry and entry.type ~= "group" and entry.quest then
                SelectQuestFromList(panels, entry.quest, i)
                return
            end
        end
    end
end

function RefreshQuestList(panels)
    local previousScroll = 0
    if panels
        and panels.listScrollFrame
        and panels.listScrollFrame.GetVerticalScroll
    then
        previousScroll = panels.listScrollFrame:GetVerticalScroll() or 0
    end

    ClearQuestList()
    panels._questListVersion = (panels._questListVersion or 0) + 1
    local listVersion = panels._questListVersion
    wipe(questRowStatusCache)
    wipe(questGroupStatusCache)

    local addon = GetDataAddon()
    if not addon or not addon.QuestData then
        panels._questResults = {}
        panels._questListEntries = {}
        if panels.emptyList then
            panels.emptyList:SetText(L["QUESTS_NO_DATA"])
            panels.emptyList:Show()
        end
        panels.listScrollChild:SetHeight(100)
        return
    end

    local quests
    local favoriteQuests = {}
    local databaseMode = IsDatabaseMode()

    if databaseMode then
        quests = addon.QuestData:GetSortedQuests(
            expansionFilter,
            zoneFilter,
            "all",
            "all",
            searchText,
            BuildAdvancedFilters()
        )

        StartRewardItemSearchWarmup(panels, addon, #quests)
    else
        quests = GetActiveQuestLogQuests(addon)
        favoriteQuests = GetFavoriteQuestsOutsideActiveList(addon, quests)
    end

    if completionFilter ~= "all" then
        local filtered = {}
        for _, quest in ipairs(quests) do
            if completionFilter == "completed" then
                if C_QuestLog.IsQuestFlaggedCompleted(quest.id) then table.insert(filtered, quest) end
            elseif completionFilter == "not_completed" then
                if not C_QuestLog.IsQuestFlaggedCompleted(quest.id) then table.insert(filtered, quest) end
            elseif completionFilter == "active" then
                if C_QuestLog.IsOnQuest(quest.id) then table.insert(filtered, quest) end
            elseif completionFilter == "warband" then
                if C_QuestLog.IsQuestFlaggedCompletedOnAccount(quest.id) then table.insert(filtered, quest) end
            end
        end
        quests = filtered
    end

    if runtimeFilter == "favorite" and ns.Favorites then
        local filtered = {}
        for _, quest in ipairs(quests) do
            if ns.Favorites:IsFavorite("quests", quest.id) then
                table.insert(filtered, quest)
            end
        end
        quests = filtered
    end

    if databaseMode and ns.Favorites and #quests > 0 then
        local origOrder = {}
        for i, q in ipairs(quests) do
            origOrder[q.id] = i
        end
        table.sort(quests, function(a, b)
            local fa = ns.Favorites:IsFavorite("quests", a.id)
            local fb = ns.Favorites:IsFavorite("quests", b.id)
            if fa ~= fb then return fa end
            return (origOrder[a.id] or 0) < (origOrder[b.id] or 0)
        end)
    end

    if selectedQuest then
        local selectedQuestVisible = false

        for _, quest in ipairs(quests) do
            if quest.id == selectedQuest.id then
                selectedQuestVisible = true
                break
            end
        end

        if not selectedQuestVisible then
            for _, quest in ipairs(favoriteQuests) do
                if quest.id == selectedQuest.id then
                    selectedQuestVisible = true
                    break
                end
            end
        end

        if not selectedQuestVisible then
            selectedQuest = nil
            ClearDetailElements()

            if panels.emptyDetail then
                panels.emptyDetail:Show()
            end

            if panels.detailScrollChild then
                panels.detailScrollChild:SetHeight(100)
            end
        end
    end

    if #quests == 0 and #favoriteQuests == 0 then
        panels._questResults = {}
        panels._favoriteQuestResults = {}
        panels._questListEntries = {}
        if panels.emptyList then
            panels.emptyList:SetText(
                (addon.QuestData:GetCapturedQuestCount() == 0)
                and L["QUESTS_NONE_YET"]
                or  L["QUESTS_EMPTY"]
            )
            panels.emptyList:Show()
        end
        panels.listScrollChild:SetHeight(100)
        if panels.leftStatusText then
            panels.leftStatusText:SetText(string.format(L["QUESTS_STATUS_COUNT"], 0))
        end
        return
    end

    if panels.emptyList then panels.emptyList:Hide() end

    panels._questResults = quests
    panels._favoriteQuestResults = favoriteQuests
    panels._questListEntries = BuildQuestListDisplayEntries(quests, favoriteQuests)

    local rowOnClick = function(entry)
        panels._questKeyboardNavActive = true

        if entry and entry.type == "group" then
            questListGroupExpanded[entry.key] =
                not questListGroupExpanded[entry.key]
            panels._questListEntries = BuildQuestListDisplayEntries(
                panels._questResults or {},
                panels._favoriteQuestResults or {}
            )

            panels.listScrollChild:SetHeight(
                math.max(100, (#panels._questListEntries * QUEST_LIST_ROW_HEIGHT) + 10)
            )

            if panels.listScrollFrame
                and panels.listScrollFrame.UpdateScrollChildRect
            then
                panels.listScrollFrame:UpdateScrollChildRect()
            end

            UpdateVisibleQuestRows(panels)
            return
        end

        if entry and entry.type == "section" then
            return
        end

        local q = entry and (entry.quest or entry)
        if not q then
            return
        end

        local questIndex
        for i, visibleEntry in ipairs(panels._questListEntries or {}) do
            local visibleQuest = visibleEntry.quest or visibleEntry
            if visibleQuest and visibleQuest.id == q.id then
                questIndex = i
                break
            end
        end

        SelectQuestFromList(panels, q, questIndex)
    end

    panels._questListOnClick = rowOnClick
    EnsureQuestListRows(panels, rowOnClick)

    panels.listScrollChild:SetHeight(
        math.max(100, (#panels._questListEntries * QUEST_LIST_ROW_HEIGHT) + 10)
    )

    RefreshQuestListViewport(panels, previousScroll, listVersion)

    if panels.leftStatusText then
        panels.leftStatusText:SetText(string.format(L["QUESTS_STATUS_COUNT"], #quests + #favoriteQuests))
    end

    if selectedQuest then
        ShowQuestDetail(panels, addon.QuestData:GetQuest(selectedQuest.id))
    end
end

function OpenQuestByID(questID, panels)
    questID = tonumber(questID)
    if not questID then return false end

    OneWoW.UI:Show("catalog")
    OneWoW.UI:SelectSubTab("catalog", "quests")

    panels = panels or ns.UI.questsPanels

    local addon = GetDataAddon()
    local quest =
        addon
        and addon.QuestData
        and addon.QuestData:GetQuest(questID)

    if not quest then return false end

    selectedQuest = quest
    searchText = "\"" .. tostring(questID) .. "\""
    expansionFilter = -1
    zoneFilter = ""
    completionFilter = "all"
    ResetAdvancedFilters()

    if panels then
        if panels.searchBox then
            panels.searchBox:SetText(searchText)
            panels.searchBox:ClearFocus()
        end

        if panels.expText then panels.expText:SetText(L["QUESTS_EXPANSION_ALL"]) end
        if panels.zoneText then panels.zoneText:SetText(L["QUESTS_ZONE_ALL"]) end
        if panels.progText then panels.progText:SetText(L["QUESTS_PROGRESS_ALL"]) end
        if panels.UpdateAdvancedTexts then panels.UpdateAdvancedTexts() end

        RefreshQuestList(panels)
        ShowQuestDetail(panels, quest)
    end

    return true
end

ns.UI.OpenQuest = function(questID)
    return OpenQuestByID(questID, ns.UI.questsPanels)
end

local PopulateZoneDropdown = function(panels)
    local addon = GetDataAddon()
    if not addon or not addon.QuestData then return end

    OneWoW_GUI:AttachFilterMenu(panels.zoneDropdown, {
        searchable = true,
        getActiveValue = function() return zoneFilter end,
        buildItems = function()
            local zones = addon.QuestData:GetAvailableZones(expansionFilter ~= -1 and expansionFilter or nil)
            local items = { { value = "", text = L["QUESTS_ZONE_ALL"] } }
            for _, zoneName in ipairs(zones) do
                table.insert(items, {
                    value   = zoneName,
                    text    = zoneName,
                })
            end
            return items
        end,
        onSelect = function(value, text)
            zoneFilter = value
            panels.zoneText:SetText(value == "" and L["QUESTS_ZONE_ALL"] or text)
            RefreshQuestList(panels)
        end,
    })
end

local function PopulateExpansionDropdown(panels)
    local addon = GetDataAddon()
    if not addon or not addon.QuestData then return end

    OneWoW_GUI:AttachFilterMenu(panels.expDropdown, {
        searchable = false,
        getActiveValue = function() return expansionFilter end,
        buildItems = function()
            local items = { { value = -1, text = L["QUESTS_EXPANSION_ALL"] } }
            local expansions = addon.QuestData:GetAvailableExpansions()
            for _, exp in ipairs(expansions) do
                table.insert(items, {
                    value   = exp.id,
                    text    = exp.name,
                })
            end
            return items
        end,
        onSelect = function(value, text)
            expansionFilter = value
            panels.expText:SetText(value == -1 and L["QUESTS_EXPANSION_ALL"] or text)
            zoneFilter = ""
            panels.zoneText:SetText(L["QUESTS_ZONE_ALL"])
            PopulateZoneDropdown(panels)
            RefreshQuestList(panels)
        end,
    })
end

local function SetupTypeDropdown(panels)
    OneWoW_GUI:AttachFilterMenu(panels.typeDropdown, {
        searchable = false,
        getActiveValue = function() return typeFilter end,
        buildItems = function()
            return {
                { value = "all",   text = L["QUESTS_TYPE_ALL"]   },
                { value = "solo",  text = L["QUESTS_TYPE_SOLO"]  },
                { value = "group", text = L["QUESTS_TYPE_GROUP"] },
                { value = "raid",  text = L["QUESTS_TYPE_RAID"]  },
            }
        end,
        onSelect = function(value, text)
            typeFilter = value
            panels.typeText:SetText(value == "all" and L["QUESTS_TYPE_ALL"] or text)
            RefreshQuestList(panels)
        end,
    })
end

local function SetupQuestTypeDropdown(panels)
    OneWoW_GUI:AttachFilterMenu(panels.qTypeDropdown, {
        searchable = false,
        getActiveValue = function() return questTypeFilter end,
        buildItems = function()
            return {
                { value = "all",        text = L["QUESTS_QTYPE_ALL"]       },
                { value = "normal",     text = L["QUESTS_TYPE_NORMAL"]     },
                { value = "daily",      text = L["QUESTS_TYPE_DAILY"]      },
                { value = "weekly",     text = L["QUESTS_TYPE_WEEKLY"]     },
                { value = "campaign",   text = L["QUESTS_TYPE_CAMPAIGN"]   },
                { value = "worldquest", text = L["QUESTS_TYPE_WORLDQUEST"] },
            }
        end,
        onSelect = function(value, text)
            questTypeFilter = value
            panels.qTypeText:SetText(value == "all" and L["QUESTS_QTYPE_ALL"] or text)
            RefreshQuestList(panels)
        end,
    })
end

local function SetupProgressDropdown(panels)
    OneWoW_GUI:AttachFilterMenu(panels.progDropdown, {
        searchable = false,
        getActiveValue = function() return completionFilter end,
        buildItems = function()
            return {
                { value = "all",           text = L["QUESTS_PROGRESS_ALL"]           },
                { value = "completed",     text = L["QUESTS_PROGRESS_COMPLETED"]     },
                { value = "not_completed", text = L["QUESTS_PROGRESS_NOT_COMPLETED"] },
                { value = "active",        text = L["QUESTS_PROGRESS_ACTIVE"]        },
                { value = "warband",       text = L["QUESTS_PROGRESS_WARBAND"]       },
            }
        end,
        onSelect = function(value, text)
            completionFilter = value
            panels.progText:SetText(value == "all" and L["QUESTS_PROGRESS_ALL"] or text)
            RefreshQuestList(panels)
        end,
    })
end

local function GetAvailableFilterValues(fieldName)
    local addon = GetDataAddon()
    if not addon or not addon.QuestData then return {} end

    local cacheKey =
        expansionFilter ~= -1
        and tostring(expansionFilter)
        or "all"

    if not availableFilterCache[cacheKey] then
        availableFilterCache[cacheKey] = {
            category = {},
            flag = {},
            profession = {},
            class = {},
            race = {},
            faction = {},
        }

        local function addValue(field, value)
            if value ~= nil and tostring(value) ~= "" then
                availableFilterCache[cacheKey][field][tostring(value)] = true
            end
        end

        local source =
            expansionFilter ~= -1
            and addon.QuestData:GetQuestsForExpansion(expansionFilter)
            or addon.QuestData:GetAllQuests()

        for _, quest in pairs(source) do
            for _, value in ipairs(quest.categories or {}) do
                addValue("category", value)
            end

            for _, value in ipairs(quest.flags or {}) do
                addValue("flag", value)
            end

            for _, value in ipairs(quest.requiredProfessions or {}) do
                addValue("profession", value)
            end

            for _, value in ipairs(quest.requiredClasses or {}) do
                addValue("class", value)
            end

            for _, value in ipairs(quest.requiredRaces or {}) do
                addValue("race", value)
            end

            addValue("faction", GetFactionFilterValue(quest.faction))
        end
    end

    local found = availableFilterCache[cacheKey][fieldName] or {}
    local results = {}
    for value in pairs(found) do
        table.insert(results, value)
    end

    table.sort(results)
    return results
end

local function CreateAdvancedDropdown(parent, label, defaultText)
    local labelText = OneWoW_GUI:CreateFS(parent, 10)
    labelText:SetText(label)
    labelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local dropdown, text = OneWoW_GUI:CreateDropdown(parent, {
        width = 10,
        text = defaultText,
    })

    return {
        label = labelText,
        dropdown = dropdown,
        text = text,
    }
end

local function SetupSimpleAdvancedDropdown(def)
    OneWoW_GUI:AttachFilterMenu(def.dropdown, {
        searchable = def.searchable == true,
        getActiveValue = def.getValue,
        buildItems = def.buildItems,
        onSelect = function(value, text)
            def.setValue(value)
            def.text:SetText(value == "all" and def.allText or text)
            if def.panels.UpdateAdvancedTexts then
                def.panels.UpdateAdvancedTexts()
            end
            RefreshQuestList(def.panels)
        end,
    })
end

local function SetupAdvancedDropdowns(panels)
    OneWoW_GUI:AttachFilterMenu(panels.advGroup.dropdown, {
        searchable = false,
        getActiveValue = function() return typeFilter end,
        buildItems = function()
            return {
                { value = "all",   text = L["QUESTS_TYPE_ALL"]   },
                { value = "solo",  text = L["QUESTS_TYPE_SOLO"]  },
                { value = "group", text = L["QUESTS_TYPE_GROUP"] },
                { value = "raid",  text = L["QUESTS_TYPE_RAID"]  },
            }
        end,
        onSelect = function(value, text)
            typeFilter = value
            panels.advGroup.text:SetText(value == "all" and L["QUESTS_TYPE_ALL"] or text)
            panels.UpdateAdvancedTexts()
            RefreshQuestList(panels)
        end,
    })

    OneWoW_GUI:AttachFilterMenu(panels.advQuestType.dropdown, {
        searchable = false,
        getActiveValue = function() return questTypeFilter end,
        buildItems = function()
            return {
                { value = "all",        text = L["QUESTS_QTYPE_ALL"]       },
                { value = "normal",     text = L["QUESTS_TYPE_NORMAL"]     },
                { value = "daily",      text = L["QUESTS_TYPE_DAILY"]      },
                { value = "weekly",     text = L["QUESTS_TYPE_WEEKLY"]     },
                { value = "campaign",   text = L["QUESTS_TYPE_CAMPAIGN"]   },
                { value = "worldquest", text = L["QUESTS_TYPE_WORLDQUEST"] },
                { value = "repeatable", text = "Repeatable" },
            }
        end,
        onSelect = function(value, text)
            questTypeFilter = value
            panels.advQuestType.text:SetText(value == "all" and L["QUESTS_QTYPE_ALL"] or text)
            panels.UpdateAdvancedTexts()
            RefreshQuestList(panels)
        end,
    })

    local dynamicDefs = {
        { frame = panels.advCategory,   field = "category",   allText = "All Categories",  get = function() return categoryFilter end,   set = function(v) categoryFilter = v end },
        { frame = panels.advFlag,       field = "flag",       allText = "All Flags",       get = function() return flagFilter end,       set = function(v) flagFilter = v end },
        { frame = panels.advProfession, field = "profession", allText = "All Professions", get = function() return professionFilter end, set = function(v) professionFilter = v end },
        { frame = panels.advClass,      field = "class",      allText = "All Classes",     get = function() return classFilter end,      set = function(v) classFilter = v end },
        { frame = panels.advRace,       field = "race",       allText = "All Races",       get = function() return raceFilter end,       set = function(v) raceFilter = v end },
        { frame = panels.advFaction,    field = "faction",    allText = "All Factions",    get = function() return factionFilter end,    set = function(v) factionFilter = v end },
    }

    for _, dynamic in ipairs(dynamicDefs) do
        local frame = dynamic.frame
        local field = dynamic.field
        local allText = dynamic.allText
        local getValue = dynamic.get
        local setValue = dynamic.set

        SetupSimpleAdvancedDropdown({
            panels = panels,
            dropdown = frame.dropdown,
            text = frame.text,
            allText = allText,
            searchable = true,
            getValue = getValue,
            setValue = setValue,
            buildItems = function()
                local items = { { value = "all", text = allText } }
                for _, value in ipairs(GetAvailableFilterValues(field)) do
                    table.insert(items, {
                        value = value,
                        text = GetAdvancedValueText(field, value) or value,
                    })
                end
                return items
            end,
        })
    end

    OneWoW_GUI:AttachFilterMenu(panels.advStory.dropdown, {
        searchable = false,
        getActiveValue = function() return storyFilter end,
        buildItems = function()
            return {
                { value = "all",        text = "All Story States" },
                { value = "chain",      text = "In Chain or Storyline" },
                { value = "storyline",  text = "Storyline" },
                { value = "standalone", text = "Standalone" },
            }
        end,
        onSelect = function(value, text)
            storyFilter = value
            panels.advStory.text:SetText(value == "all" and "All Story States" or text)
            panels.UpdateAdvancedTexts()
            RefreshQuestList(panels)
        end,
    })

    OneWoW_GUI:AttachFilterMenu(panels.advRuntime.dropdown, {
        searchable = false,
        getActiveValue = function() return runtimeFilter end,
        buildItems = function()
            return {
                { value = "all",              text = "All Runtime States" },
                { value = "favorite",         text = "Favorites" },
                { value = "has_location",     text = "Has Location" },
                { value = "missing_location", text = "Missing Location" },
                { value = "has_quest_giver",  text = "Has Quest Giver" },
                { value = "has_turnin",       text = "Has Turn-in" },
                { value = "has_rewards",      text = "Has Rewards" },
                { value = "has_reward_choices", text = "Has Reward Choices" },
            }
        end,
        onSelect = function(value, text)
            runtimeFilter = value
            panels.advRuntime.text:SetText(value == "all" and "All Runtime States" or text)
            panels.UpdateAdvancedTexts()
            RefreshQuestList(panels)
        end,
    })
end

-- Navigates the Catalog to the quests tab and opens the given quest's detail.
-- Used by Item Search's quest-reward cross-references.
function ns.UI.OpenToQuest(questID)
    questID = tonumber(questID)
    if not questID then return end

    if ns.oneWoWHubActive then
        OneWoW.UI:Show("catalog")
        OneWoW.UI:SelectSubTab("catalog", "quests")
    else
        ns.UI:Show("quests")
    end

    C_Timer.After(0.15, function()
        local panels = activePanels or ns.UI.questsPanels
        if not panels then return end
        local addon = GetDataAddon()
        if not addon or not addon.QuestData then return end
        local quest = addon.QuestData:GetQuest(questID)
        if quest then
            ShowQuestDetail(panels, quest)
        end
    end)
end

function ns.UI.CreateQuestsTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP    = ns.Constants.GUI.PANEL_GAP
    local HDR_H  = 42
    local DRAWER_H = 132

    local leftHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    leftHeader:ClearAllPoints()
    leftHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    leftHeader:SetWidth(LEFT_W)

    local rightHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    rightHeader:ClearAllPoints()
    rightHeader:SetPoint("TOPLEFT", leftHeader, "TOPRIGHT", GAP, 0)
    rightHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local advancedDrawer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    advancedDrawer:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -GAP)
    advancedDrawer:SetPoint("TOPRIGHT", rightHeader, "BOTTOMRIGHT", 0, -GAP)
    advancedDrawer:SetHeight(DRAWER_H)
    advancedDrawer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    advancedDrawer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    advancedDrawer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    advancedDrawer:SetShown(advancedOpen)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local function PositionContentArea()
        contentArea:ClearAllPoints()
        if advancedOpen then
            contentArea:SetPoint("TOPLEFT", advancedDrawer, "BOTTOMLEFT", 0, -GAP)
        else
            contentArea:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -GAP)
        end
        contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        advancedDrawer:SetShown(advancedOpen)
    end

    PositionContentArea()

    local panels = OneWoW_GUI:CreateSplitPanel(contentArea)
    panels.listTitle:SetText(L["QUESTS_LIST_TITLE"])
    panels.detailTitle:SetText(L["QUESTS_DETAIL_TITLE"])

    if panels.listScrollFrame then
        local questListViewport = CreateFrame("Frame", nil, panels.listScrollFrame)
        questListViewport:SetAllPoints(panels.listScrollFrame)
        if questListViewport.SetClipsChildren then
            questListViewport:SetClipsChildren(true)
        end
        if panels.listScrollFrame.GetFrameLevel and questListViewport.SetFrameLevel then
            questListViewport:SetFrameLevel((panels.listScrollFrame:GetFrameLevel() or 0) + 1)
        end
        questListViewport:EnableMouseWheel(true)
        questListViewport:SetScript("OnMouseWheel", function(_, delta)
            if not panels.listScrollFrame or not panels.listScrollFrame.SetVerticalScroll then
                return
            end

            local current =
                panels.listScrollFrame.GetVerticalScroll
                and panels.listScrollFrame:GetVerticalScroll()
                or 0

            local frameHeight =
                panels.listScrollFrame.GetHeight
                and panels.listScrollFrame:GetHeight()
                or 0

            local maxScroll = math.max(
                0,
                (panels.listScrollChild and panels.listScrollChild:GetHeight() or 0)
                - frameHeight
            )

            local target = current - (delta or 0) * QUEST_LIST_ROW_HEIGHT * 3
            panels.listScrollFrame:SetVerticalScroll(math.max(0, math.min(target, maxScroll)))
            UpdateVisibleQuestRows(panels)
        end)
        panels.questListViewport = questListViewport
    end

    contentArea:EnableKeyboard(true)
    if contentArea.SetPropagateKeyboardInput then
        contentArea:SetPropagateKeyboardInput(true)
    end
    contentArea:SetScript("OnKeyDown", function(_, key)
        local isQuestNavKey = key == "DOWN" or key == "UP"

        if not isQuestNavKey or not panels._questKeyboardNavActive then
            if contentArea.SetPropagateKeyboardInput then
                contentArea:SetPropagateKeyboardInput(true)
            end
            return
        end

        if contentArea.SetPropagateKeyboardInput then
            contentArea:SetPropagateKeyboardInput(false)
        end

        if key == "DOWN" then
            MoveQuestSelection(panels, 1)
        elseif key == "UP" then
            MoveQuestSelection(panels, -1)
        end
    end)
    contentArea:SetScript("OnKeyUp", function()
        if contentArea.SetPropagateKeyboardInput then
            contentArea:SetPropagateKeyboardInput(true)
        end
    end)

    if panels.listScrollFrame then
        panels.listScrollFrame:HookScript("OnVerticalScroll", function()
            UpdateVisibleQuestRows(panels)
        end)
        panels.listScrollFrame:HookScript("OnSizeChanged", function()
            UpdateVisibleQuestRows(panels)
        end)
    end

    if panels.detailScrollFrame then
        panels.detailScrollFrame:HookScript("OnSizeChanged", function(self, width)
            if not selectedQuest then
                return
            end

            width = width or self:GetWidth() or 0
            if math.abs((panels._lastDetailResizeWidth or 0) - width) < 2 then
                return
            end

            panels._lastDetailResizeWidth = width

            if panels._detailResizeTimer then
                panels._detailResizeTimer:Cancel()
            end

            panels._detailResizeTimer = C_Timer.NewTimer(0.05, function()
                if selectedQuest and ShowQuestDetail then
                    local addon = GetDataAddon()
                    local quest =
                        addon
                        and addon.QuestData
                        and addon.QuestData:GetQuest(selectedQuest.id)
                        or selectedQuest

                    ShowQuestDetail(panels, quest)
                end
            end)
        end)
    end

    local favFilterBtn = OneWoW_GUI:CreateFitTextButton(leftHeader, { text = "Favorites", height = 26, minWidth = 68, toggleable = true })
    favFilterBtn:SetPoint("TOPRIGHT", leftHeader, "TOPRIGHT", -8, -8)

    local clearBtn = OneWoW_GUI:CreateFitTextButton(leftHeader, { text = L["QUESTS_CLEAR"], height = 26, minWidth = 34 })
    clearBtn:SetPoint("TOPRIGHT", favFilterBtn, "TOPLEFT", -4, 0)

    local searchBox = OneWoW_GUI:CreateEditBox(leftHeader, {
        height = 26,
        placeholderText = L["QUESTS_SEARCH_ADVANCED"],
        onTextChanged = function(text)
            searchText = text
            CancelRewardItemSearchWarmup()
            if panels._searchTimer then panels._searchTimer:Cancel() end
            panels._searchTimer = C_Timer.NewTimer(0.3, function()
                RefreshQuestList(panels)
            end)
        end,
    })
    searchBox:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", -4, 0)

    local DD_GAP = 4
    local DD_PAD = 8

    local expDropdown, expText = OneWoW_GUI:CreateDropdown(rightHeader, { width = 10, text = L["QUESTS_EXPANSION_ALL"] })
    local zoneDropdown, zoneText = OneWoW_GUI:CreateDropdown(rightHeader, { width = 10, text = L["QUESTS_ZONE_ALL"] })
    local progDropdown, progText = OneWoW_GUI:CreateDropdown(rightHeader, { width = 10, text = L["QUESTS_PROGRESS_ALL"] })
    local advancedBtn = OneWoW_GUI:CreateFitTextButton(rightHeader, { text = GetAdvancedButtonText(), height = 26, minWidth = 92 })

    local drawerTitle = OneWoW_GUI:CreateFS(advancedDrawer, 11)
    drawerTitle:SetPoint("TOPLEFT", advancedDrawer, "TOPLEFT", 10, -8)
    drawerTitle:SetText("Advanced Filters")
    drawerTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local drawerClearBtn = OneWoW_GUI:CreateFitTextButton(advancedDrawer, { text = "Clear Advanced", height = 22, minWidth = 105 })
    drawerClearBtn:SetPoint("TOPRIGHT", advancedDrawer, "TOPRIGHT", -10, -6)

    local advGroup = CreateAdvancedDropdown(advancedDrawer, "Group", L["QUESTS_TYPE_ALL"])
    local advQuestType = CreateAdvancedDropdown(advancedDrawer, "Quest Type", L["QUESTS_QTYPE_ALL"])
    local advCategory = CreateAdvancedDropdown(advancedDrawer, "Category", "All Categories")
    local advFlag = CreateAdvancedDropdown(advancedDrawer, "Flag", "All Flags")
    local advProfession = CreateAdvancedDropdown(advancedDrawer, "Profession", "All Professions")
    local advClass = CreateAdvancedDropdown(advancedDrawer, "Class", "All Classes")
    local advRace = CreateAdvancedDropdown(advancedDrawer, "Race", "All Races")
    local advFaction = CreateAdvancedDropdown(advancedDrawer, "Faction", "All Factions")
    local advStory = CreateAdvancedDropdown(advancedDrawer, "Story", "All Story States")
    local advRuntime = CreateAdvancedDropdown(advancedDrawer, "Runtime", "All Runtime States")

    local function LayoutFilterDropdowns(w)
        local ddW = math.floor((w - (DD_PAD * 2) - (DD_GAP * 3)) / 4)
        expDropdown:ClearAllPoints()
        expDropdown:SetSize(ddW, 26)
        expDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD, -8)

        zoneDropdown:ClearAllPoints()
        zoneDropdown:SetSize(ddW, 26)
        zoneDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD + (ddW + DD_GAP), -8)

        progDropdown:ClearAllPoints()
        progDropdown:SetSize(ddW, 26)
        progDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD + (ddW + DD_GAP) * 2, -8)

        advancedBtn:ClearAllPoints()
        advancedBtn:SetSize(ddW, 26)
        advancedBtn:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD + (ddW + DD_GAP) * 3, -8)
    end

    local function LayoutAdvancedDrawer(w)
        local controls = {
            advGroup,
            advQuestType,
            advCategory,
            advFlag,
            advProfession,
            advClass,
            advRace,
            advFaction,
            advStory,
            advRuntime,
        }

        local pad = 10
        local gap = 6
        local cols = 5
        local cellW = math.floor((w - (pad * 2) - (gap * (cols - 1))) / cols)

        for index, control in ipairs(controls) do
            local col = (index - 1) % cols
            local row = math.floor((index - 1) / cols)
            local x = pad + col * (cellW + gap)
            local y = -30 - row * 48

            control.label:ClearAllPoints()
            control.label:SetPoint("TOPLEFT", advancedDrawer, "TOPLEFT", x, y)

            control.dropdown:ClearAllPoints()
            control.dropdown:SetSize(cellW, 24)
            control.dropdown:SetPoint("TOPLEFT", advancedDrawer, "TOPLEFT", x, y - 14)
        end
    end

    rightHeader:SetScript("OnSizeChanged", function(_, w)
        LayoutFilterDropdowns(w)
    end)

    advancedDrawer:SetScript("OnSizeChanged", function(_, w)
        LayoutAdvancedDrawer(w)
    end)

    C_Timer.After(0, function()
        local w = rightHeader:GetWidth()
        if w and w > 0 then LayoutFilterDropdowns(w) end
        local advW = advancedDrawer:GetWidth()
        if advW and advW > 0 then LayoutAdvancedDrawer(advW) end
    end)

    local emptyList = OneWoW_GUI:CreateFS(panels.listScrollChild, 12)
    emptyList:SetPoint("CENTER", panels.listScrollChild, "CENTER", 0, 0)
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyList = emptyList

    local emptyDetail = OneWoW_GUI:CreateFS(panels.detailPanel, 12)
    emptyDetail:SetPoint("CENTER", panels.detailPanel, "CENTER", 0, 0)
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyDetail = emptyDetail

    panels.expDropdown   = expDropdown
    panels.expText       = expText
    panels.zoneDropdown  = zoneDropdown
    panels.zoneText      = zoneText
    panels.progDropdown  = progDropdown
    panels.progText      = progText
    panels.searchBox     = searchBox
    panels.favFilterBtn  = favFilterBtn
    panels.advancedBtn   = advancedBtn
    panels.advancedDrawer = advancedDrawer
    panels.advGroup      = advGroup
    panels.advQuestType  = advQuestType
    panels.advCategory   = advCategory
    panels.advFlag       = advFlag
    panels.advProfession = advProfession
    panels.advClass      = advClass
    panels.advRace       = advRace
    panels.advFaction    = advFaction
    panels.advStory      = advStory
    panels.advRuntime    = advRuntime

    panels.UpdateAdvancedTexts = function()
        SetButtonText(advancedBtn, GetAdvancedButtonText())
        UpdateFavoritesFilterButton(favFilterBtn)
        advGroup.text:SetText(typeFilter == "all" and L["QUESTS_TYPE_ALL"] or typeFilter)
        advQuestType.text:SetText(questTypeFilter == "all" and L["QUESTS_QTYPE_ALL"] or questTypeFilter)
        advCategory.text:SetText(categoryFilter == "all" and "All Categories" or categoryFilter)
        advFlag.text:SetText(flagFilter == "all" and "All Flags" or flagFilter)
        advProfession.text:SetText(professionFilter == "all" and "All Professions" or professionFilter)
        advClass.text:SetText(classFilter == "all" and "All Classes" or GetClassDisplayName(classFilter))
        advRace.text:SetText(raceFilter == "all" and "All Races" or GetRaceDisplayName(raceFilter))
        advFaction.text:SetText(factionFilter == "all" and "All Factions" or GetFactionDisplayName(factionFilter))

        local storyText = "All Story States"
        if storyFilter == "chain" then storyText = "In Chain or Storyline"
        elseif storyFilter == "storyline" then storyText = "Storyline"
        elseif storyFilter == "standalone" then storyText = "Standalone" end
        advStory.text:SetText(storyText)

        local runtimeText = "All Runtime States"
        if runtimeFilter == "favorite" then runtimeText = "Favorites"
        elseif runtimeFilter == "has_location" then runtimeText = "Has Location"
        elseif runtimeFilter == "missing_location" then runtimeText = "Missing Location"
        elseif runtimeFilter == "has_quest_giver" then runtimeText = "Has Quest Giver"
        elseif runtimeFilter == "has_turnin" then runtimeText = "Has Turn-in"
        elseif runtimeFilter == "has_rewards" then runtimeText = "Has Rewards"
        elseif runtimeFilter == "has_reward_choices" then runtimeText = "Has Reward Choices" end
        advRuntime.text:SetText(runtimeText)
    end

    ns.UI.questsPanels = panels

    emptyList:SetText(L["QUESTS_EMPTY"])
    emptyDetail:SetText(L["QUESTS_SELECT"])
    panels.listScrollChild:SetHeight(100)
    panels.detailScrollChild:SetHeight(100)

    clearBtn:SetScript("OnClick", function()
        searchText      = ""
        expansionFilter = -1
        zoneFilter      = ""
        completionFilter = "all"
        ResetAdvancedFilters()
        searchBox:SetText("")
        searchBox:ClearFocus()
        expText:SetText(L["QUESTS_EXPANSION_ALL"])
        zoneText:SetText(L["QUESTS_ZONE_ALL"])
        progText:SetText(L["QUESTS_PROGRESS_ALL"])
        panels.UpdateAdvancedTexts()
        RefreshQuestList(panels)
    end)

    favFilterBtn:SetScript("OnClick", function()
        runtimeFilter = runtimeFilter == "favorite" and "all" or "favorite"
        panels.UpdateAdvancedTexts()
        RefreshQuestList(panels)
    end)

    drawerClearBtn:SetScript("OnClick", function()
        ResetAdvancedFilters()
        panels.UpdateAdvancedTexts()
        RefreshQuestList(panels)
    end)

    advancedBtn:SetScript("OnClick", function()
        advancedOpen = not advancedOpen
        PositionContentArea()
        panels.UpdateAdvancedTexts()
    end)

    C_Timer.After(0.5, function()
        PopulateExpansionDropdown(panels)
        PopulateZoneDropdown(panels)
        SetupProgressDropdown(panels)
        SetupAdvancedDropdowns(panels)
        panels.UpdateAdvancedTexts()
        RefreshQuestList(panels)
    end)

    ns.UI.RefreshQuestsList = function()
        RefreshQuestList(panels)
    end
end
