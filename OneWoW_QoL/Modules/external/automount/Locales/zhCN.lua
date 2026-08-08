local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["AUTOMOUNT_TITLE"] = "自动坐骑",
    ["AUTOMOUNT_DESC"] = "当你在可使用坐骑的区域停止移动时，自动召唤可用的最快坐骑。采集后会重新召唤坐骑。",
    ["AUTOMOUNT_MOUNT_PREFS"] = "坐骑偏好",
    ["AUTOMOUNT_GROUND_LABEL"] = "地面坐骑",
    ["AUTOMOUNT_FLYING_LABEL"] = "飞行坐骑",
    ["AUTOMOUNT_AQUATIC_LABEL"] = "水上坐骑",
    ["AUTOMOUNT_CAT_ON"] = "开",
    ["AUTOMOUNT_CAT_OFF"] = "关",
    ["AUTOMOUNT_RANDOM_FAVORITE"] = "随机收藏",
    ["AUTOMOUNT_SELECT_TITLE"] = "选择%s坐骑",
    ["AUTOMOUNT_SELECT_TOOLTIP"] = "点击以选择一个坐骑",
    ["AUTOMOUNT_SELECT_TOOLTIP_DESC"] = "选择特定坐骑，或让自动选择挑选可用的最快坐骑。",
    ["AUTOMOUNT_DRUID_SECTION"] = "德鲁伊",
    ["AUTOMOUNT_DRUID_MODE_LABEL"] = "德鲁伊模式",
    ["AUTOMOUNT_DRUID_MODE_DESC"] = "启用时将跳过自动召唤坐骑，以便你在采集后手动变为旅行形态。",
    ["AUTOMOUNT_STATUS_LABEL"] = "坐骑状态",
    ["AUTOMOUNT_STATUS_READY"] = "可以召唤坐骑",
    ["AUTOMOUNT_STATUS_MOUNTED"] = "当前已骑乘",
    ["AUTOMOUNT_STATUS_DISABLED"] = "自动坐骑已禁用",
    ["AUTOMOUNT_TIMING_SECTION"] = "时机",
    ["AUTOMOUNT_DISMOUNT_DELAY"] = "下坐骑延迟",
    ["AUTOMOUNT_DISMOUNT_DELAY_DESC"] = "下坐骑后多久恢复自动召唤坐骑。",
    ["AUTOMOUNT_FISHING_DELAY"] = "钓鱼延迟",
    ["AUTOMOUNT_FISHING_DELAY_DESC"] = "钓鱼后多久恢复自动召唤坐骑。",
    ["AUTOMOUNT_GATHER_DELAY"] = "采集后重新召唤延迟",
    ["AUTOMOUNT_GATHER_DELAY_DESC"] = "采集后多快重新召唤坐骑。",
    ["AUTOMOUNT_DRUID_CANCEL_LABEL"] = "自动取消旅行形态",
    ["AUTOMOUNT_DRUID_CANCEL_DESC"] = "当你进入可飞行区域时自动取消旅行形态，使你可以改为召唤飞行坐骑。",
})
