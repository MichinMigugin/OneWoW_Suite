local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["AFKPANEL_TITLE"] = "暫離面板",
    ["AFKPANEL_DESC"] = "當你暫離時，顯示一個全螢幕暫離覆蓋層，包含你的角色資訊、警報和筆記。",
    ["AFKPANEL_CAMERA_SPIN"] = "鏡頭旋轉",
    ["AFKPANEL_SHOW_DAILY"] = "顯示每日筆記",
    ["AFKPANEL_SHOW_WEEKLY"] = "顯示每週筆記",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - 暫離模式",
    ["AFKPANEL_CHARACTER_INFO"] = "角色資訊",
    ["AFKPANEL_ALERTS"] = "警報",
    ["AFKPANEL_NO_ALERTS"] = "目前沒有警報",
    ["AFKPANEL_AFK_TIME"] = "暫離：%s",
    ["AFKPANEL_DAILY_NOTES"] = "每日筆記",
    ["AFKPANEL_WEEKLY_NOTES"] = "每週筆記",
    ["AFKPANEL_NO_NOTES"] = "沒有可顯示的筆記",
    ["AFKPANEL_NO_GUILD"] = "無公會",
})
