local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["AUTOMOUNT_TITLE"] = "自動坐騎",
    ["AUTOMOUNT_DESC"] = "當你在可使用坐騎的區域停止移動時，自動召喚可用的最快坐騎。採集後會重新召喚坐騎。",
    ["AUTOMOUNT_MOUNT_PREFS"] = "坐騎偏好",
    ["AUTOMOUNT_GROUND_LABEL"] = "地面坐騎",
    ["AUTOMOUNT_FLYING_LABEL"] = "飛行坐騎",
    ["AUTOMOUNT_AQUATIC_LABEL"] = "水上坐騎",
    ["AUTOMOUNT_CAT_ON"] = "開",
    ["AUTOMOUNT_CAT_OFF"] = "關",
    ["AUTOMOUNT_RANDOM_FAVORITE"] = "隨機收藏",
    ["AUTOMOUNT_SELECT_TITLE"] = "選擇%s坐騎",
    ["AUTOMOUNT_SELECT_TOOLTIP"] = "點擊以選擇一個坐騎",
    ["AUTOMOUNT_SELECT_TOOLTIP_DESC"] = "選擇特定坐騎，或讓自動選擇挑選可用的最快坐騎。",
    ["AUTOMOUNT_DRUID_SECTION"] = "德魯伊",
    ["AUTOMOUNT_DRUID_MODE_LABEL"] = "德魯伊模式",
    ["AUTOMOUNT_DRUID_MODE_DESC"] = "啟用時將跳過自動召喚坐騎，以便你在採集後手動變為旅行形態。",
    ["AUTOMOUNT_STATUS_LABEL"] = "坐騎狀態",
    ["AUTOMOUNT_STATUS_READY"] = "可以召喚坐騎",
    ["AUTOMOUNT_STATUS_MOUNTED"] = "目前已騎乘",
    ["AUTOMOUNT_STATUS_DISABLED"] = "自動坐騎已停用",
    ["AUTOMOUNT_TIMING_SECTION"] = "時機",
    ["AUTOMOUNT_DISMOUNT_DELAY"] = "下坐騎延遲",
    ["AUTOMOUNT_DISMOUNT_DELAY_DESC"] = "下坐騎後多久恢復自動召喚坐騎。",
    ["AUTOMOUNT_FISHING_DELAY"] = "釣魚延遲",
    ["AUTOMOUNT_FISHING_DELAY_DESC"] = "釣魚後多久恢復自動召喚坐騎。",
    ["AUTOMOUNT_GATHER_DELAY"] = "採集後重新召喚延遲",
    ["AUTOMOUNT_GATHER_DELAY_DESC"] = "採集後多快重新召喚坐騎。",
    ["AUTOMOUNT_DRUID_CANCEL_LABEL"] = "自動取消旅行形態",
    ["AUTOMOUNT_DRUID_CANCEL_DESC"] = "當你進入可飛行區域時自動取消旅行形態，使你可以改為召喚飛行坐騎。",
})
