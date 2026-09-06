local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["ESCPANEL_TITLE"] = "ESC 菜单面板",
    ["ESCPANEL_DESC"] = "在 ESC 菜单旁显示角色卡片、此地收藏与笔记，以及传送门条。角色卡片会显示信件、耐久度、宏伟宝库和商栈，并可选择显示文化节。地点卡片上的物品提醒图标对应购物清单、笔记、Trackers 和 Farming。有提醒的图标在 | 左侧，其余在右侧。将鼠标放在图标上可看详情，点击有提醒的图标即可打开。点击角色卡片打开角色界面，或点击地点卡片在目录中打开该区域。在下方选择各项使用哪一侧。",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "显示角色信息",
    ["ESCPANEL_TOGGLE_ENDEAVORS"] = "显示文化节",
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
