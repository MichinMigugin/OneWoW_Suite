local addonName, ns = ...

local AchieveUntrackModule = {
    id          = "achieveuntrack",
    title       = "ACHIEVEUNTRACK_TITLE",
    category    = "AUTOMATION",
    description = "ACHIEVEUNTRACK_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    preview     = false,
    _frame      = nil,
}

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
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_AchieveUntrack")
        self._frame:SetScript("OnEvent", function()
            ScanAndUntrack()
        end)
    end
    self._frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function AchieveUntrackModule:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
end

ns.AchieveUntrackModule = AchieveUntrackModule
