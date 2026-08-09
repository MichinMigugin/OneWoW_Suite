local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["PLAYMOUNTS_TITLE"] = "玩家坐騎",
    ["PLAYMOUNTS_DESC"] = "偵測並顯示其他玩家目前使用的坐騎或移動形態。",
    ["PLAYMOUNTS_TOGGLE_CHAT"] = "在聊天中通知",
    ["PLAYMOUNTS_TOGGLE_CHAT_DESC"] = "當你選取一名已騎乘的玩家時，在聊天視窗中顯示坐騎名稱。",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT"] = "比對坐騎",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT_DESC"] = "在玩家身上新增一個右鍵選項，以召喚與其所騎相同類型的坐騎。",
    ["PLAYMOUNTS_COLLECTED"] = "（已收集）",
    ["PLAYMOUNTS_NOT_COLLECTED"] = "（未收集）",
    ["PLAYMOUNTS_USING"] = "%s 正在使用 %s",
    ["PLAYMOUNTS_SOURCE"] = "來源：%s",
    ["PLAYMOUNTS_DISPLAYMODE_DESC"] = "控制在提示資訊和聊天輸出中顯示多少坐騎資訊。",
    ["PLAYMOUNTS_MODE_NAME"] = "名稱",
    ["PLAYMOUNTS_MODE_NAMETYPE"] = "名稱 + 類型",
    ["PLAYMOUNTS_MODE_ALL"] = "完整詳情",
    ["PLAYMOUNTS_TOOLTIP_HEADER"] = "提示資訊整合",
    ["PLAYMOUNTS_TOOLTIP_REQUIRES"] = "需要：OneWoW Core",
    ["PLAYMOUNTS_TOOLTIP_DETECTED"] = "狀態：已偵測到",
    ["PLAYMOUNTS_TOOLTIP_NOT_DETECTED"] = "狀態：未偵測到",
    ["PLAYMOUNTS_TOOLTIP_NOTE"] = "可在 QoL → 滑鼠提示 → 玩家坐騎 中啟用或停用坐騎提示行。",
    ["PLAYMOUNTS_TOOLTIP_VIEW_BTN"] = "檢視設定",
})
