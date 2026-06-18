local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["ESCPANEL_TITLE"] = "ESC 選單面板",
    ["ESCPANEL_DESC"] = "在 ESC 選單旁顯示角色資訊、警報、區域筆記和傳送門條。在下方選擇各項使用哪一側。",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "顯示角色資訊",
    ["ESCPANEL_TOGGLE_ALERTS"] = "顯示警報",
    ["ESCPANEL_TOGGLE_ZONE_NOTES"] = "顯示區域筆記",
    ["ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY"] = "為空時隱藏區域筆記",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "顯示傳送門",
    ["ESCPANEL_LAYOUT_HEADER"] = "佈局",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "資訊面板側",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "傳送門側",
    ["ESCPANEL_SIDE_LEFT"] = "選單左側",
    ["ESCPANEL_SIDE_RIGHT"] = "選單右側",
    ["ESCPANEL_LAYOUT_DESC"] = "當兩者位於同一側時，傳送門位於外側（離選單更遠），面板緊鄰選單。",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "傳送門圖示大小",
})
