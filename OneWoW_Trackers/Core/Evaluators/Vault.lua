local _, ns = ...

local E = ns.TrackerEvaluators
local ipairs = ipairs

local function EvalVault(thresholdType)
    local activities = C_WeeklyRewards.GetActivities(thresholdType)
    if not activities then return end
    local best = 0
    for _, act in ipairs(activities) do
        if act.progress > best then best = act.progress end
    end
    local maxNeeded = activities[1] and activities[1].threshold or 1
    return best, maxNeeded
end

E.Register("vault_raid", function()
    return EvalVault(Enum.WeeklyRewardChestThresholdType.Raid)
end)

E.Register("vault_dungeon", function()
    return EvalVault(Enum.WeeklyRewardChestThresholdType.Activities)
end)

E.Register("vault_world", function()
    return EvalVault(Enum.WeeklyRewardChestThresholdType.World)
end)
