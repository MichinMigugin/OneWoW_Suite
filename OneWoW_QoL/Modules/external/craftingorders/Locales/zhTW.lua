local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW, pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["CRAFTORDERS_TITLE"] = "製造訂單",
    ["CRAFTORDERS_DESC"] = "用「現在可製造」和「缺少材料」取代訂單清單。把缺少的材料加入購物清單。用一個按鈕開始、製造並完成。",
    ["CRAFTORDERS_SECTION_READY"] = "現在可製造",
    ["CRAFTORDERS_SECTION_MISSING"] = "缺少材料",
    ["CRAFTORDERS_WEEKLY_NOT_ACCEPTED"] = "每週：未接受",
    ["CRAFTORDERS_WEEKLY_NOT_LEARNED"] = "每週：未學會",
    ["CRAFTORDERS_WEEKLY_COMPLETE"] = "每週：已完成",
    ["CRAFTORDERS_WEEKLY_PROGRESS"] = "每週：已完成 %d / %d",
    ["CRAFTORDERS_LOADING"] = "正在載入訂單...",
    ["CRAFTORDERS_ADD_ACTIVE"] = "加入%s",
    ["CRAFTORDERS_MAKE_LIST"] = "建立清單",
    ["CRAFTORDERS_ADD_MENU_HINT"] = "右鍵可建立清單或選擇其他清單。",
    ["CRAFTORDERS_ELSEWHERE_TIP"] = "也在：%s",
    ["CRAFTORDERS_COL_CRAFT"] = "訂單",
    ["CRAFTORDERS_COL_YOU"] = "你提供",
    ["CRAFTORDERS_COL_CART"] = "清單",
    ["CRAFTORDERS_COL_CUSTOMER"] = "顧客提供",
    ["CRAFTORDERS_COL_REWARD"] = "你獲得",
    ["CRAFTORDERS_USE_WOWUI"] = "WoW UI",
    ["CRAFTORDERS_USE_ONEUI"] = "One UI",
    ["CRAFTORDERS_TOGGLE_WOWUI"] = "使用 WoW 清單",
    ["CRAFTORDERS_TOGGLE_WOWUI_DESC"] = "顯示暴雪訂單表，而不是「現在可製造」和「缺少材料」。",
    ["CRAFTORDERS_TOGGLE_HIDE_UNLEARNED"] = "隱藏未習得配方",
    ["CRAFTORDERS_TOGGLE_HIDE_UNLEARNED_DESC"] = "隱藏你尚未學會配方的訂單。",
    ["CRAFTORDERS_BUCKET_COUNT"] = "%d份訂單",
    ["CRAFTORDERS_ORDER_LIST_NAME"] = "訂單：%s",
    ["CRAFTORDERS_NO_SHOPPING"] = "啟用購物清單才能加入材料。",
    ["CRAFTORDERS_KP"] = "知識 %d",
    ["CRAFTORDERS_ACUITY"] = "敏銳 x%d",
    ["CRAFTORDERS_INCOMPATIBLE_TITLE"] = "其他訂單清單插件",
    ["CRAFTORDERS_INCOMPATIBLE_BODY"] = "%s 已啟用。那些插件仍會載入。開啟此項使用 One UI，關閉則使用那些插件。",
})
