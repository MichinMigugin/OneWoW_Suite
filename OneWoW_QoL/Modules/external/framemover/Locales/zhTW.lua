local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["FRAMEMOVER_TITLE"] = "框體移動器",
    ["FRAMEMOVER_DESC"] = "拖曳暴雪介面框體以重新擺放它們。使用 Ctrl+滾輪進行縮放。在啟用「限制在螢幕內」時，按住 Alt 拖曳可將框體部分移出螢幕。位置和縮放可在連線之間保留。",

    ["FRAMEMOVER_TOGGLE_REQUIRE_SHIFT"] = "需按住 Shift 才能拖曳",
    ["FRAMEMOVER_TOGGLE_ENABLE_SCALING"] = "Ctrl+滾輪縮放",
    ["FRAMEMOVER_TOGGLE_SAVE_POSITIONS"] = "記住位置",
    ["FRAMEMOVER_TOGGLE_SAVE_SCALES"] = "記住縮放",
    ["FRAMEMOVER_TOGGLE_CLAMP_SCREEN"] = "限制在螢幕內",
    ["FRAMEMOVER_TOGGLE_MODIFY_HUD"] = "顯示縮放彈出框",

    ["FRAMEMOVER_GROUP_BEHAVIOR"] = "行為",
    ["FRAMEMOVER_GROUP_SAVING"] = "持久化",

    ["FRAMEMOVER_CAT_CORE"] = "核心介面",
    ["FRAMEMOVER_CAT_COLLECTIONS"] = "收藏與日誌",
    ["FRAMEMOVER_CAT_PROFESSIONS"] = "專業與經濟",
    ["FRAMEMOVER_CAT_GROUP"] = "組隊內容",
    ["FRAMEMOVER_CAT_CHARACTER"] = "角色與天賦",
    ["FRAMEMOVER_CAT_SOCIAL"] = "社交與公會",
    ["FRAMEMOVER_CAT_MISC"] = "雜項",
    ["FRAMEMOVER_CAT_HOUSING"] = "住宅",

    ["FRAMEMOVER_FRAMES_HEADER"] = "可移動框體",
    ["FRAMEMOVER_FILTER_EMPTY"] = "沒有符合搜尋的框體。",
    ["FRAMEMOVER_RESET_POSITIONS"] = "重置所有位置",
    ["FRAMEMOVER_RESET_SCALES"] = "重置所有縮放",
    ["FRAMEMOVER_RESET_POS_DONE"] = "位置已重置。重新開啟框體以查看預設值。",
    ["FRAMEMOVER_RESET_SCALE_DONE"] = "縮放已重置。重新開啟框體以查看預設值。",
    ["FRAMEMOVER_ENABLED_TOOLTIP"] = "左鍵點擊以切換。在框體上方使用 Ctrl+滾輪對其進行縮放。按住 Alt 拖曳可忽略螢幕限制。",
    ["FEATURES_ON"] = "開",
    ["FEATURES_OFF"] = "關",
})
