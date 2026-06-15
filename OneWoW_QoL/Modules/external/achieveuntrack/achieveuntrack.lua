local _, ns = ...
local AchieveUntrackModule = ns.ModuleRegistry:Current()
if not AchieveUntrackModule then return end

local ACHIEVE = Enum.ContentTrackingType.Achievement
local COLLECTED = Enum.ContentTrackingStopType.Collected

local function ScanAndUntrack()
    local tracked = C_ContentTracking.GetTrackedIDs(ACHIEVE) or {}
    for _, achievementID in ipairs(tracked) do
        local id, _, _, completed = GetAchievementInfo(achievementID)
        if (not id) or completed then
            C_ContentTracking.StopTracking(ACHIEVE, achievementID, COLLECTED)
            local link = GetAchievementLink(achievementID) or ("<removed:" .. achievementID .. ">")
            print("|cFFFFD100OneWoW QoL|r: Untracked completed achievement: " .. link)
        end
    end
end

function AchieveUntrackModule:OnEnable()
    OneWoW_QoL:RegisterEnteringWorldHandler("achieveuntrack", ScanAndUntrack)
end

function AchieveUntrackModule:OnDisable()
    OneWoW_QoL:UnregisterEnteringWorldHandler("achieveuntrack")
end
