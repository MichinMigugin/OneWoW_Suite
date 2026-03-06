local addonName, ns = ...

ns.GreatVault = {}
local Module = ns.GreatVault

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

    vaultData.hasAvailableRewards = C_WeeklyRewards.HasAvailableRewards()

    local activities = C_WeeklyRewards.GetActivities()
    if activities then
        for _, activity in ipairs(activities) do
            local activityData = {
                type = activity.type,
                index = activity.index,
                level = activity.level,
                progress = activity.progress,
                threshold = activity.threshold,
                rewards = {},
            }

            local exampleRewards = C_WeeklyRewards.GetExampleRewardItemHyperlinks(activity.id)
            if exampleRewards then
                if type(exampleRewards) == "string" then
                    exampleRewards = {exampleRewards}
                end

                if type(exampleRewards) == "table" then
                    for _, hyperlink in ipairs(exampleRewards) do
                        if type(hyperlink) == "string" then
                            local itemID = tonumber(hyperlink:match("item:(%d+)"))
                            if itemID then
                                local itemName, itemLink, itemQuality, itemLevel = GetItemInfo(itemID)
                                table.insert(activityData.rewards, {
                                    itemID = itemID,
                                    itemLevel = itemLevel,
                                    itemQuality = itemQuality,
                                    hyperlink = hyperlink,
                                })
                            end
                        end
                    end
                end
            end

            if activity.type == 1 then
                table.insert(vaultData.activities.raid, activityData)
            elseif activity.type == 2 then
                table.insert(vaultData.activities.dungeon, activityData)
            elseif activity.type == 3 then
                table.insert(vaultData.activities.world, activityData)
            end
        end
    end

    charData.greatVault = vaultData

    return true
end
