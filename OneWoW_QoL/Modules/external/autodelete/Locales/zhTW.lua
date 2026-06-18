local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["AUTODELETE_TITLE"] = "自動刪除",
    ["AUTODELETE_DESC"] = "銷毀物品時無需輸入 DELETE。確認按鈕會立即可用，無需你輸入任何內容。",
    ["AUTODELETE_TOGGLE_SKIP"] = "跳過輸入確認",
    ["AUTODELETE_TOGGLE_SKIP_DESC"] = "自動啟用刪除按鈕，無需你輸入 DELETE。",
    ["AUTODELETE_TOGGLE_LINK"] = "顯示物品連結",
    ["AUTODELETE_TOGGLE_LINK_DESC"] = "在確認彈窗中顯示物品連結，讓你看清將要刪除的內容。",
})
