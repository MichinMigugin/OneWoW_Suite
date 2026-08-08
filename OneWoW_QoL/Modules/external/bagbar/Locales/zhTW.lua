local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["BAGBAR_TITLE"] = "背包列",
    ["BAGBAR_DESC"] = "在可移動的列上顯示可用的背包物品。物品透過關鍵字運算式選擇（與背包搜尋相同）。可裝備的裝備和任務物品始終從列中排除（自動套用，不在編輯器中顯示）。",
    ["BAGBAR_LOCK_POSITION"] = "鎖定位置",
    ["BAGBAR_MAX_BUTTONS"] = "最大按鈕數",
    ["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"] = "Shift+右鍵點擊以在本次連線中跳過",
    ["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"] = "Alt+右鍵點擊以永久加入黑名單",
    ["BAGBAR_MANUAL_ITEMS_HEADER"] = "手動物品",
    ["BAGBAR_MANUAL_DESC"] = "釘選特定物品以在列中獲得更高優先順序。它們仍須符合你的運算式篩選和列的可用性規則。",
    ["BAGBAR_MACROS_HEADER"] = "手動巨集",
    ["BAGBAR_MACROS_DESC"] = "將你的巨集作為自訂按鈕新增到列中。從巨集視窗將巨集拖到放置區域，或輸入巨集名稱並點擊新增。巨集顯示在背包物品之前。",
    ["BAGBAR_MACRO_NAME_LABEL"] = "巨集名稱：",
    ["BAGBAR_DRAG_MACRO_HERE"] = "將巨集拖到此處",
    ["BAGBAR_MACRO_LEFT_CLICK_TO_RUN"] = "左鍵點擊以執行巨集",
    ["BAGBAR_MACRO_MISSING"] = "（缺少）",
    ["BAGBAR_BLACKLIST_DESC"] = "Shift+右鍵點擊列中的物品以在本次連線中跳過。Alt+右鍵點擊以永久加入黑名單。",
    ["BAGBAR_COLUMNS"] = "欄數",
    ["BAGBAR_CONTEXT_LOCK"] = "鎖定位置",
    ["BAGBAR_GROW_RIGHT"] = "右",
    ["BAGBAR_GROW_LEFT"] = "左",
    ["BAGBAR_EXPRESSION_FILTER_HEADER"] = "運算式篩選",
    ["BAGBAR_EXPRESSION_FILTER_DESC"] = "決定哪些背包物品出現的關鍵字運算式（與背包搜尋的關鍵字相同）。點擊 ? 取得說明。可裝備的裝備和任務物品會自動從此運算式中排除。",
    ["BAGBAR_EXPRESSION_FILTER_PLACEHOLDER"] = "例如 #usable & #mount",
})
