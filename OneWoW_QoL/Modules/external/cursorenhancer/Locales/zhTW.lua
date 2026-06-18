local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["CURSORENHANCER_TITLE"] = "游標增強",
    ["CURSORENHANCER_DESC"] = "在你的游標周圍顯示一個可自訂的光環，並可選滑鼠拖尾效果。",
    ["CURSORENHANCER_OUTER_RING"] = "顯示外環",
    ["CURSORENHANCER_MIDDLE_RING"] = "顯示中環",
    ["CURSORENHANCER_CENTER_MARKER"] = "顯示中心標記",
    ["CURSORENHANCER_SHOW_OOC"] = "脫離戰鬥時顯示",
    ["CURSORENHANCER_SHOW_INSTANCE"] = "僅在副本中顯示",
    ["CURSORENHANCER_MOUSE_TRAIL"] = "顯示滑鼠拖尾",
    ["CURSORENHANCER_MODULE_TOGGLES"] = "模組開關",
    ["CURSORENHANCER_MARKER_TOGGLES"] = "標記開關",
    ["CURSORENHANCER_COLORS_HEADER"] = "光環顏色",
    ["CURSORENHANCER_OUTER_RING_COLOR"] = "外環顏色",
    ["CURSORENHANCER_MIDDLE_RING_COLOR"] = "中環顏色",
    ["CURSORENHANCER_CENTER_MARKER_COLOR"] = "中心標記顏色",
    ["CURSORENHANCER_TRAIL_COLOR"] = "拖尾顏色",
})
