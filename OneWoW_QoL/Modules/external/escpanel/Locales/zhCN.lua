local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["ESCPANEL_TITLE"] = "ESC 菜单面板",
    ["ESCPANEL_DESC"] = "在 ESC 菜单旁显示角色信息、警报、区域笔记和传送门条。在下方选择各项使用哪一侧。",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "显示角色信息",
    ["ESCPANEL_TOGGLE_ALERTS"] = "显示警报",
    ["ESCPANEL_TOGGLE_ZONE_NOTES"] = "显示区域笔记",
    ["ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY"] = "为空时隐藏区域笔记",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "显示传送门",
    ["ESCPANEL_LAYOUT_HEADER"] = "布局",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "信息面板侧",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "传送门侧",
    ["ESCPANEL_SIDE_LEFT"] = "菜单左侧",
    ["ESCPANEL_SIDE_RIGHT"] = "菜单右侧",
    ["ESCPANEL_LAYOUT_DESC"] = "当两者位于同一侧时，传送门位于外侧（离菜单更远），面板紧邻菜单。",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "传送门图标大小",
})
