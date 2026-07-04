local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["FRAMEMOVER_TITLE"] = "框体移动器",
    ["FRAMEMOVER_DESC"] = "拖动暴雪界面框体以重新摆放它们。使用 Ctrl+滚轮进行缩放。在启用“限制在屏幕内”时，按住 Alt 拖动可将框体部分移出屏幕。位置和缩放可在会话之间保留。",

    ["FRAMEMOVER_TOGGLE_REQUIRE_SHIFT"] = "需按住 Shift 才能拖动",
    ["FRAMEMOVER_TOGGLE_ENABLE_SCALING"] = "Ctrl+滚轮缩放",
    ["FRAMEMOVER_TOGGLE_SAVE_POSITIONS"] = "记住位置",
    ["FRAMEMOVER_TOGGLE_SAVE_SCALES"] = "记住缩放",
    ["FRAMEMOVER_TOGGLE_CLAMP_SCREEN"] = "限制在屏幕内",
    ["FRAMEMOVER_TOGGLE_MODIFY_HUD"] = "显示缩放弹出框",

    ["FRAMEMOVER_GROUP_BEHAVIOR"] = "行为",
    ["FRAMEMOVER_GROUP_SAVING"] = "持久化",

    ["FRAMEMOVER_CAT_CORE"] = "核心界面",
    ["FRAMEMOVER_CAT_COLLECTIONS"] = "收藏与日志",
    ["FRAMEMOVER_CAT_PROFESSIONS"] = "专业与经济",
    ["FRAMEMOVER_CAT_GROUP"] = "组队内容",
    ["FRAMEMOVER_CAT_CHARACTER"] = "角色与天赋",
    ["FRAMEMOVER_CAT_SOCIAL"] = "社交与公会",
    ["FRAMEMOVER_CAT_MISC"] = "杂项",
    ["FRAMEMOVER_CAT_HOUSING"] = "住宅",

    ["FRAMEMOVER_FRAMES_HEADER"] = "可移动框体",
    ["FRAMEMOVER_FILTER_EMPTY"] = "没有匹配搜索的框体。",
    ["FRAMEMOVER_RESET_POSITIONS"] = "重置所有位置",
    ["FRAMEMOVER_RESET_SCALES"] = "重置所有缩放",
    ["FRAMEMOVER_RESET_POS_DONE"] = "位置已重置。重新打开框体以查看默认值。",
    ["FRAMEMOVER_RESET_SCALE_DONE"] = "缩放已重置。重新打开框体以查看默认值。",
    ["FRAMEMOVER_ENABLED_TOOLTIP"] = "左键点击以切换。在框体上方使用 Ctrl+滚轮对其进行缩放。按住 Alt 拖动可忽略屏幕限制。",
    ["FEATURES_ON"] = "开",
    ["FEATURES_OFF"] = "关",
})
