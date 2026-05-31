local addonName, ns = ...

ns.Achievements = {}
local Module = ns.Achievements

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    if not charData.achievements then
        charData.achievements = {}
    end

    local achievementsData = charData.achievements

    local totalPoints, completedAchievements = GetTotalAchievementPoints()
    achievementsData.totalPoints = totalPoints or 0
    achievementsData.completedCount = completedAchievements or 0

    local recentlyCompleted = {}
    for i = 1, 25 do
        local achievementID, name, points, completed, month, day, year = GetAchievementInfo(i)
        if achievementID and completed then
            table.insert(recentlyCompleted, {
                achievementID = achievementID,
                name = name,
                points = points,
                month = month,
                day = day,
                year = year,
            })
        end
    end
    achievementsData.recent = recentlyCompleted

    charData.lastUpdate = time()

    return true
end

function Module:GetAchievementInfo(achievementID)
    if not achievementID then return nil end

    local id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy = GetAchievementInfo(achievementID)

    if not id then return nil end

    local info = {
        achievementID = id,
        name = name,
        points = points,
        completed = completed,
        month = month,
        day = day,
        year = year,
        description = description,
        flags = flags,
        icon = icon,
        rewardText = rewardText,
        isGuild = isGuild,
        wasEarnedByMe = wasEarnedByMe,
        earnedBy = earnedBy,
    }

    local numCriteria = GetAchievementNumCriteria(achievementID)
    if numCriteria and numCriteria > 0 then
        local criteria = {}
        for i = 1, numCriteria do
            local criteriaString, criteriaType, criteriaCompleted, quantity, reqQuantity, charName, flags, assetID, quantityString = GetAchievementCriteriaInfo(achievementID, i)
            table.insert(criteria, {
                index = i,
                description = criteriaString,
                type = criteriaType,
                completed = criteriaCompleted,
                quantity = quantity,
                reqQuantity = reqQuantity,
                charName = charName,
                flags = flags,
                assetID = assetID,
                quantityString = quantityString,
            })
        end
        info.criteria = criteria
        info.numCriteria = numCriteria
    end

    return info
end
