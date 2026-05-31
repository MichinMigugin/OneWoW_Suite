-- OneWoW AltTracker Addon File
-- OneWoW_AltTracker_Endgame/Modules/GreatVault.lua
-- Created by MichinMigugin (Ricky)
local addonName, ns = ...

ns.GreatVault = {}
local Module = ns.GreatVault

local function GetSortedActivities(thresholdType)
    if thresholdType == nil then return {} end
    local raw = C_WeeklyRewards.GetActivities(thresholdType)
    if type(raw) ~= "table" then return {} end
    local list = {}
    for _, info in ipairs(raw) do
        table.insert(list, info)
    end
    table.sort(list, function(a, b)
        return (a.index or 0) < (b.index or 0)
    end)
    return list
end

local function GetDetailedItemLevel(hyperlink)
    if type(hyperlink) ~= "string" or hyperlink == "" then return nil end
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local ilvl = C_Item.GetDetailedItemLevelInfo(hyperlink)
        if type(ilvl) == "number" and ilvl > 0 then return ilvl end
    end
    return nil
end

local function BuildActivityRow(activities)
    local row = {}
    for slot = 1, 3 do
        local info = activities[slot]
        if info then
            local itemLink, upgradeItemLink = nil, nil
            if info.id then
                itemLink, upgradeItemLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(info.id)
            end

            local itemLevel = GetDetailedItemLevel(itemLink)
            local upgradeItemLevel = GetDetailedItemLevel(upgradeItemLink)

            row[slot] = {
                id = info.id,
                type = info.type,
                index = info.index,
                level = info.level,
                progress = info.progress or 0,
                threshold = info.threshold or 0,
                itemLevel = itemLevel,
                upgradeItemLevel = upgradeItemLevel,
                itemLink = itemLink,
                upgradeItemLink = upgradeItemLink,
            }
        end
    end
    return row
end

local function ResolveDungeonThreshold(thresholdEnum)
    if thresholdEnum.MythicPlus ~= nil then return thresholdEnum.MythicPlus end
    if thresholdEnum.Activities ~= nil then return thresholdEnum.Activities end
    return nil
end

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local vaultData = {
        hasAvailableRewards = false,
        activities = {
            raid = {},
            dungeon = {},
            world = {},
        },
        lastUpdated = time(),
    }

    vaultData.hasAvailableRewards = C_WeeklyRewards.HasAvailableRewards() and true or false

    local thresholdEnum = Enum.WeeklyRewardChestThresholdType or {}
    local dungeonThreshold = ResolveDungeonThreshold(thresholdEnum)

    local raidActs = GetSortedActivities(thresholdEnum.Raid)
    local dungActs = GetSortedActivities(dungeonThreshold)
    local worldActs = GetSortedActivities(thresholdEnum.World)

    local existing = charData.greatVault
    local function PreserveIfEmpty(newRow, existingRow)
        if (newRow[1] or newRow[2] or newRow[3]) then return newRow end
        if existingRow and (existingRow[1] or existingRow[2] or existingRow[3]) then return existingRow end
        return newRow
    end

    local existingActs = existing and existing.activities or nil
    vaultData.activities.raid    = PreserveIfEmpty(BuildActivityRow(raidActs),  existingActs and existingActs.raid)
    vaultData.activities.dungeon = PreserveIfEmpty(BuildActivityRow(dungActs),  existingActs and existingActs.dungeon)
    vaultData.activities.world   = PreserveIfEmpty(BuildActivityRow(worldActs), existingActs and existingActs.world)

    charData.greatVault = vaultData

    return true
end
