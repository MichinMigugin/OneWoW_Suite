local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted (Phase 4) — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["CURSORENHANCER_TITLE"] = "光标增强",
    ["CURSORENHANCER_DESC"] = "在你的光标周围显示一个可自定义的光环，并可选鼠标拖尾效果。",
    ["CURSORENHANCER_OUTER_RING"] = "显示外环",
    ["CURSORENHANCER_MIDDLE_RING"] = "显示中环",
    ["CURSORENHANCER_CENTER_MARKER"] = "显示中心标记",
    ["CURSORENHANCER_SHOW_OOC"] = "脱离战斗时显示",
    ["CURSORENHANCER_SHOW_INSTANCE"] = "仅在副本中显示",
    ["CURSORENHANCER_MOUSE_TRAIL"] = "显示鼠标拖尾",
    ["CURSORENHANCER_MODULE_TOGGLES"] = "模块开关",
    ["CURSORENHANCER_MARKER_TOGGLES"] = "标记开关",
    ["CURSORENHANCER_COLORS_HEADER"] = "光环颜色",
    ["CURSORENHANCER_OUTER_RING_COLOR"] = "外环颜色",
    ["CURSORENHANCER_MIDDLE_RING_COLOR"] = "中环颜色",
    ["CURSORENHANCER_CENTER_MARKER_COLOR"] = "中心标记颜色",
    ["CURSORENHANCER_TRAIL_COLOR"] = "拖尾颜色",
})
