-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/screenshotachievements/screenshotachievements.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local ScreenshotAchievementsModule = {
    id          = "screenshotachievements",
    title       = "SCREENSHOTACH_TITLE",
    category    = "AUTOMATION",
    description = "SCREENSHOTACH_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    preview     = true,
    defaultEnabled = false,
    _frame      = nil,
}

-- Delay before the screenshot so the achievement toast and surrounding UI have
-- time to render. Tuned to match the default Blizzard alert timing.
local SCREENSHOT_DELAY = 1.5

function ScreenshotAchievementsModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_ScreenshotAchievements")
        self._frame:SetScript("OnEvent", function(_, event, ...)
            if event == "ACHIEVEMENT_EARNED" then
                self:ACHIEVEMENT_EARNED()
            end
        end)
    end
    self._frame:RegisterEvent("ACHIEVEMENT_EARNED")
end

function ScreenshotAchievementsModule:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
end

function ScreenshotAchievementsModule:ACHIEVEMENT_EARNED()
    -- Screenshot is a C function and C_Timer.After rejects cfunctions as the
    -- callback (it requires a Lua function). Wrap it in a closure.
    C_Timer.After(SCREENSHOT_DELAY, function()
        Screenshot()
    end)
end

ns.ScreenshotAchievementsModule = ScreenshotAchievementsModule
