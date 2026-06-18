local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["DECLINEDUEL_TITLE"] = "自動拒絕決鬥",
    ["DECLINEDUEL_DESC"] = "自動拒絕決鬥請求，使彈窗永遠不會停留在你的螢幕上。",
    ["DECLINEDUEL_TOGGLE_PET"] = "也拒絕寵物決鬥",
    ["DECLINEDUEL_TOGGLE_PET_DESC"] = "也自動拒絕寵物對戰決鬥請求。",
})
