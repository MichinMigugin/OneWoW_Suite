local _, ns = ...

-- ============================================================================
-- Housing (account-wide, collection only)
-- ============================================================================
-- Writes OneWoW_AltTracker_Character_DB.account.housing. No interiors.
-- House level/favor and owned decor are async: request, then persist on the
-- matching gameplay events. Keep this file small so it can move later.
--
-- Do not call GetPlayerOwnedHouses. It fires PLAYER_HOUSE_LIST_UPDATED on the
-- same stack (re-entry crash if we persist from it) and caches the list so
-- the Housing dashboard OnLoad fires before House Info has subscribed,
-- leaving Blizzard's playerHouseList nil. Copy houses from the event only.
-- ============================================================================

ns.Housing = {}
local Module = ns.Housing

local C_Housing = C_Housing
local C_HousingCatalog = C_HousingCatalog
local C_NeighborhoodInitiative = C_NeighborhoodInitiative
local C_Timer = C_Timer
local Enum = Enum

local MAX_OWNED_DECOR = 2500

local houseList = {}
local favorByGuid = {}
local rewardsByLevel = {}
local rewardsRequested = false
local searcher
local retryArmed = false
local persistBusy = false

local function SlimHouse(info)
    if type(info) ~= "table" then
        return nil
    end
    local guid = info.houseGUID
    local row = {
        houseGuid = guid,
        houseName = info.houseName,
        ownerName = info.ownerName,
        neighborhoodName = info.neighborhoodName,
        neighborhoodGuid = info.neighborhoodGUID,
        plotId = info.plotID,
    }
    local fav = guid and favorByGuid[guid]
    if fav then
        row.level = fav.houseLevel
        row.favor = fav.houseFavor
    end
    return row
end

local function NormalizeHouseList(owned)
    local houses = {}
    if type(owned) ~= "table" then
        return houses
    end
    if owned.houseGUID or owned.houseName then
        houses[1] = SlimHouse(owned)
        return houses
    end
    for i = 1, #owned do
        local row = SlimHouse(owned[i])
        if row then
            houses[#houses + 1] = row
        end
    end
    return houses
end

local function SlimReward(reward)
    return {
        type = reward.type,
        name = reward.objectName,
        valueType = reward.valueType,
        oldValue = reward.oldValue,
        newValue = reward.newValue,
        tooltip = reward.tooltipText,
    }
end

local function SlimTask(task)
    return {
        id = task.ID,
        name = task.taskName,
        description = task.description,
        completed = task.completed and true or false,
        inProgress = task.inProgress and true or false,
        timesCompleted = task.timesCompleted or 0,
        contribution = task.progressContributionAmount or 0,
    }
end

local function SlimMilestone(ms)
    local rewards = {}
    local list = ms.rewards
    if type(list) == "table" then
        for i = 1, #list do
            local r = list[i]
            rewards[#rewards + 1] = {
                title = r.title,
                description = r.description,
                decorId = r.decorID,
                quantity = r.decorQuantity,
                favor = r.favor,
            }
        end
    end
    return {
        order = ms.milestoneOrderIndex,
        required = ms.requiredContributionAmount,
        rewards = rewards,
    }
end

function Module:Bucket()
    local account = ns:GetAccountBucket()
    local housing = account.housing
    if type(housing) ~= "table" then
        housing = {}
        account.housing = housing
    end
    return housing
end

function Module:RequestFavor(guid)
    if guid then
        C_Housing.GetCurrentHouseLevelFavor(guid)
    end
end

function Module:RequestFavorForHouses(houses)
    for i = 1, #houses do
        self:RequestFavor(houses[i].houseGuid)
    end
end

function Module:RequestRewards()
    if rewardsRequested then
        return
    end
    rewardsRequested = true
    local maxLevel = C_Housing.GetMaxHouseLevel()
    for i = 1, maxLevel do
        C_Housing.GetHouseLevelRewardsForLevel(i)
    end
end

function Module:RequestLive()
    C_Housing.RequestCurrentHouseInfo()
    C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
    self:RequestRewards()
    local tracked = C_Housing.GetTrackedHouseGuid()
    if tracked then
        self:RequestFavor(tracked)
    end
    local current = C_Housing.GetCurrentHouseInfo()
    if current and current.houseGUID then
        self:RequestFavor(current.houseGUID)
    end
    self:RequestFavorForHouses(houseList)
end

function Module:ApplyFavor(houseLevelFavor)
    if type(houseLevelFavor) ~= "table" then
        return
    end
    local guid = houseLevelFavor.houseGUID
    if guid then
        favorByGuid[guid] = houseLevelFavor
    else
        favorByGuid._current = houseLevelFavor
    end
end

function Module:PrimaryFavor()
    local current = C_Housing.GetCurrentHouseInfo()
    local guid = current and current.houseGUID
    if guid and favorByGuid[guid] then
        return favorByGuid[guid]
    end
    local tracked = C_Housing.GetTrackedHouseGuid()
    if tracked and favorByGuid[tracked] then
        return favorByGuid[tracked]
    end
    if houseList[1] and houseList[1].houseGuid and favorByGuid[houseList[1].houseGuid] then
        return favorByGuid[houseList[1].houseGuid]
    end
    return favorByGuid._current
end

function Module:CollectEndeavor()
    local enabled = C_NeighborhoodInitiative.IsInitiativeEnabled()
    local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
    local tasks = {}
    local milestones = {}
    if info and info.tasks then
        for i = 1, #info.tasks do
            tasks[#tasks + 1] = SlimTask(info.tasks[i])
        end
    end
    if info and info.milestones then
        for i = 1, #info.milestones do
            milestones[#milestones + 1] = SlimMilestone(info.milestones[i])
        end
    end
    return {
        enabled = enabled and true or false,
        hasAccess = C_NeighborhoodInitiative.PlayerHasInitiativeAccess() and true or false,
        requiredLevel = C_NeighborhoodInitiative.GetRequiredLevel(),
        availableHouseXP = C_NeighborhoodInitiative.GetAvailableHouseXP(),
        loaded = info and info.isLoaded and true or false,
        title = info and info.title or nil,
        description = info and info.description or nil,
        progress = info and info.currentProgress or 0,
        progressRequired = info and info.progressRequired or 0,
        playerContribution = info and info.playerTotalContribution or 0,
        duration = info and info.duration or 0,
        tasks = tasks,
        milestones = milestones,
    }
end

function Module:CollectSync()
    if persistBusy then
        return self:Bucket()
    end
    persistBusy = true

    for i = 1, #houseList do
        houseList[i] = SlimHouse({
            houseGUID = houseList[i].houseGuid,
            houseName = houseList[i].houseName,
            ownerName = houseList[i].ownerName,
            neighborhoodName = houseList[i].neighborhoodName,
            neighborhoodGUID = houseList[i].neighborhoodGuid,
            plotID = houseList[i].plotId,
        })
    end

    local current = C_Housing.GetCurrentHouseInfo()
    local currentSlim = current and SlimHouse(current) or nil
    local fav = self:PrimaryFavor()
    local level = fav and fav.houseLevel or 0
    local favor = fav and fav.houseFavor or 0
    local favorForLevel = C_Housing.GetHouseLevelFavorForLevel(level)
    local favorForNext = C_Housing.GetHouseLevelFavorForLevel(level + 1)
    local maxLevel = C_Housing.GetMaxHouseLevel()
    local nextRewards = rewardsByLevel[level + 1] or {}
    local total, exempt = C_HousingCatalog.GetDecorTotalOwnedCount()

    local housing = self:Bucket()
    housing.collectedAt = time()
    housing.hasAccess = C_Housing.HasHousingExpansionAccess()
    housing.houses = houseList
    housing.current = currentSlim
    housing.level = level
    housing.favor = favor
    housing.favorForLevel = favorForLevel
    housing.favorForNext = favorForNext
    housing.maxLevel = maxLevel
    housing.weekly = {
        favor = favor,
        level = level,
    }
    housing.rewards = nextRewards
    housing.endeavor = self:CollectEndeavor()
    housing.ownedDecorCount = total
    housing.ownedDecorExempt = exempt
    housing.ownedDecorMax = C_HousingCatalog.GetDecorMaxOwnedCount()
    persistBusy = false
    return housing
end

function Module:EnsureSearcher()
    if searcher then
        return searcher
    end
    searcher = C_HousingCatalog.CreateCatalogSearcher()
    searcher:SetAutoUpdateOnParamChanges(false)
    searcher:SetStoredOnly(false)
    searcher:SetBaseVariantOnly(true)
    searcher:SetCollected(true)
    searcher:SetUncollected(false)
    searcher:SetResultsUpdatedCallback(function()
        Module:OnCatalogResults()
    end)
    return searcher
end

function Module:RunOwnedDecorSearch()
    self:EnsureSearcher():RunSearch()
end

function Module:OnCatalogResults()
    local entries = self:EnsureSearcher():GetCatalogSearchResults()
    local owned = {}
    if type(entries) == "table" then
        for i = 1, #entries do
            if #owned >= MAX_OWNED_DECOR then
                break
            end
            local entry = entries[i]
            local info = C_HousingCatalog.GetCatalogEntryInfo(entry)
            if not info and entry and entry.recordID then
                info = C_HousingCatalog.GetCatalogEntryInfoByRecordID(
                    entry.entryType or Enum.HousingCatalogEntryType.Decor,
                    entry.recordID
                )
            end
            if info and info.entryType == Enum.HousingCatalogEntryType.Decor then
                local stored = info.totalNumStored or 0
                local placed = info.totalNumPlaced or 0
                local redeemable = info.remainingRedeemable or 0
                local count = stored + placed + redeemable
                if count > 0 then
                    owned[#owned + 1] = {
                        id = info.recordID,
                        itemId = info.itemID,
                        name = info.name,
                        count = count,
                        stored = stored,
                        placed = placed,
                        source = info.sourceText,
                    }
                end
            end
        end
    end
    local housing = self:CollectSync()
    housing.ownedDecor = owned
end

function Module:OnEvent(event, ...)
    if event == "PLAYER_HOUSE_LIST_UPDATED" then
        houseList = NormalizeHouseList(...)
        self:RequestFavorForHouses(houseList)
        self:CollectSync()
    elseif event == "CURRENT_HOUSE_INFO_UPDATED" or event == "CURRENT_HOUSE_INFO_RECIEVED" then
        local info = ...
        if type(info) == "table" and info.houseGUID then
            self:RequestFavor(info.houseGUID)
        end
        self:CollectSync()
    elseif event == "HOUSE_LEVEL_FAVOR_UPDATED" then
        self:ApplyFavor(...)
        self:CollectSync()
    elseif event == "HOUSE_LEVEL_CHANGED" then
        local levelInfo = ...
        if type(levelInfo) == "table" and levelInfo.level then
            local housing = self:Bucket()
            housing.budgets = {
                interior = levelInfo.interiorDecorPlacementBudget,
                exterior = levelInfo.exteriorDecorPlacementBudget,
                rooms = levelInfo.roomPlacementBudget,
                fixtures = levelInfo.exteriorFixtureBudget,
            }
        end
        self:CollectSync()
    elseif event == "RECEIVED_HOUSE_LEVEL_REWARDS" then
        local level, rewards = ...
        local slim = {}
        if type(rewards) == "table" then
            for i = 1, #rewards do
                slim[#slim + 1] = SlimReward(rewards[i])
            end
        end
        rewardsByLevel[level] = slim
        self:CollectSync()
    elseif event == "NEIGHBORHOOD_INITIATIVE_UPDATED"
        or event == "INITIATIVE_TASK_COMPLETED"
        or event == "INITIATIVE_COMPLETED" then
        self:CollectSync()
    elseif event == "HOUSING_STORAGE_UPDATED" then
        self:RunOwnedDecorSearch()
    end
end

function Module:CollectAccount()
    self:RequestLive()
    self:CollectSync()
    self:RunOwnedDecorSearch()
    if not retryArmed then
        retryArmed = true
        C_Timer.After(2, function()
            retryArmed = false
            Module:RequestLive()
            Module:CollectSync()
            Module:RunOwnedDecorSearch()
        end)
    end
    return true
end
