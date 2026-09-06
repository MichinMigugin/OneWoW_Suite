local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["AFKPANEL_TITLE"] = "暂离面板",
    ["AFKPANEL_DESC"] = "全屏暂离覆盖层，使用与 ESC 菜单相同的 You / Here 卡片、实时邮件与拍卖提醒，并在启用笔记时可选显示每日/每周笔记。",
    ["AFKPANEL_CAMERA_SPIN"] = "镜头旋转",
    ["AFKPANEL_SHOW_DAILY"] = "显示每日笔记",
    ["AFKPANEL_SHOW_WEEKLY"] = "显示每周笔记",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - 暂离模式",
    ["AFKPANEL_CHARACTER_INFO"] = "角色信息",
    ["AFKPANEL_ALERTS"] = "警报",
    ["AFKPANEL_NO_ALERTS"] = "当前没有警报",
    ["AFKPANEL_AFK_TIME"] = "暂离：%s",
    ["AFKPANEL_DAILY_NOTES"] = "每日笔记",
    ["AFKPANEL_WEEKLY_NOTES"] = "每周笔记",
    ["AFKPANEL_NO_NOTES"] = "没有可显示的笔记",
    ["AFKPANEL_NO_GUILD"] = "无公会",
})
