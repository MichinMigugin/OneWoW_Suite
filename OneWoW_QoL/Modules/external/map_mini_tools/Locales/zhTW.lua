local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["MMSKIN_TITLE"] = "地圖（小）工具",
    ["MMSKIN_DESC"] = "自訂你的小地圖區塊：形狀、邊框、區域文字、時鐘、點擊動作、縮放控制、元素顯示等。支援佈景主題且完全可設定。",

    ["MMSKIN_GROUP_SHAPE"] = "形狀與外觀",
    ["MMSKIN_GROUP_INFO"] = "資訊覆蓋層",
    ["MMSKIN_GROUP_ZOOM"] = "縮放與捲動",
    ["MMSKIN_GROUP_CLICKS"] = "點擊動作",
    ["MMSKIN_GROUP_ELEMENTS"] = "元素顯示",
    ["MMSKIN_GROUP_EXTRAS"] = "額外",
    ["MMSKIN_GROUP_COMPAT"] = "相容性",

    ["MMSKIN_SQUARE"] = "方形小地圖",
    ["MMSKIN_SQUARE_DESC"] = "將小地圖形狀從圓形改為方形。停用需要重新載入介面。",
    ["MMSKIN_BORDER"] = "顯示邊框",
    ["MMSKIN_BORDER_DESC"] = "在小地圖周圍顯示彩色邊框。",
    ["MMSKIN_CLASS_BORDER"] = "職業顏色邊框",
    ["MMSKIN_CLASS_BORDER_DESC"] = "使用你的職業顏色作為小地圖邊框，而非佈景主題顏色。",
    ["MMSKIN_UNLOCK"] = "解鎖小地圖",
    ["MMSKIN_UNLOCK_DESC"] = "將小地圖從預設位置分離，使其可自由拖曳。",
    ["MMSKIN_LOCK_POS"] = "鎖定位置",
    ["MMSKIN_LOCK_POS_DESC"] = "防止拖曳小地圖，同時將其保持在目前位置。",

    ["MMSKIN_ZONE_TEXT"] = "區域文字",
    ["MMSKIN_ZONE_TEXT_DESC"] = "在小地圖上方顯示目前區域名稱，並採用 PvP 類型著色。",
    ["MMSKIN_CLOCK"] = "時鐘",
    ["MMSKIN_CLOCK_DESC"] = "在小地圖下方顯示時鐘。提示資訊顯示伺服器/本地時間以及每日/每週重置計時器。",
    ["MMSKIN_CLASS_CLOCK_COLOR"] = "職業顏色時鐘",
    ["MMSKIN_CLASS_CLOCK_COLOR_DESC"] = "使用你的職業顏色作為時鐘文字顏色，而非佈景主題顏色。",
    ["MMSKIN_ZONE_ALIGN_LABEL"] = "區域名稱對齊",
    ["MMSKIN_CLOCK_ALIGN_LABEL"] = "時鐘對齊",
    ["MMSKIN_ALIGN_LEFT"] = "靠左",
    ["MMSKIN_ALIGN_CENTER"] = "置中",
    ["MMSKIN_ALIGN_RIGHT"] = "靠右",

    ["MMSKIN_ZONE_CLOCK_INSIDE"] = "區域與時鐘置於小地圖內",
    ["MMSKIN_ZONE_CLOCK_INSIDE_DESC"] = "將區域名稱和時鐘固定在小地圖的內邊緣，而非其上方和下方。",

    ["MMSKIN_ZONE_CLOCK_DRAG"] = "拖曳區域與時鐘（按住 Shift）",
    ["MMSKIN_ZONE_CLOCK_DRAG_DESC"] = "拖曳區域名稱或時鐘以在螢幕上移動它們時，必須按住 Shift 鍵。位置會被儲存。放開 Shift 進行正常點擊（時鐘仍會開啟時間管理員）。",

    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM"] = "將區域與時鐘錨定到小地圖",
    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM_DESC"] = "啟用拖曳時，將區域名稱和時鐘錨定到小地圖，使其隨小地圖移動而一同移動。若將它們疊放在一起，則會作為整體移動。",

    ["MMSKIN_WHEEL_ZOOM"] = "滑鼠滾輪縮放",
    ["MMSKIN_WHEEL_ZOOM_DESC"] = "使用滑鼠滾輪放大和縮小小地圖。",
    ["MMSKIN_AUTO_ZOOM"] = "自動縮小",
    ["MMSKIN_AUTO_ZOOM_DESC"] = "放大後自動將小地圖縮小回去。",

    ["MMSKIN_CLICK_ACTIONS"] = "點擊動作",
    ["MMSKIN_CLICK_ACTIONS_DESC"] = "啟用小地圖上的右鍵、中鍵及額外滑鼠按鍵動作。",

    ["MMSKIN_MAIL"] = "郵件指示器",
    ["MMSKIN_MAIL_DESC"] = "在小地圖上顯示郵件指示器。",
    ["MMSKIN_CRAFTING"] = "製造訂單",
    ["MMSKIN_CRAFTING_DESC"] = "在小地圖上顯示製造訂單指示器。",
    ["MMSKIN_DIFFICULTY"] = "難度圖示",
    ["MMSKIN_DIFFICULTY_DESC"] = "在小地圖上顯示副本難度圖示。",

    ["MMSKIN_TRACKING"] = "追蹤篩選",
    ["MMSKIN_TRACKING_DESC"] = "顯示小地圖追蹤篩選（資源 / 草藥 / 礦石 / 等下拉選單）。關閉它會移除小地圖旁的小圓環/控制項。",
    ["MMSKIN_MISSIONS"] = "任務按鈕",
    ["MMSKIN_MISSIONS_DESC"] = "顯示資料片登陸頁面 / 任務按鈕。",
    ["MMSKIN_GAMETIME"] = "行事曆圖示",
    ["MMSKIN_GAMETIME_DESC"] = "在小地圖上顯示行事曆（GameTime）按鈕。",

    ["MMSKIN_PLUMBER_HIDE_BLIZZARD"] = "使用 Plumber 時隱藏重複的暴雪資料片按鈕",
    ["MMSKIN_PLUMBER_HIDE_BLIZZARD_DESC"] = "當 Plumber 已載入時，保持暴雪的資料片小地圖按鈕隱藏，使其僅顯示 Plumber 的資料片摘要控制項。關閉則同時顯示兩者（不建議）。",
    ["MMSKIN_PLUMBER_STATUS_ON"] = "Plumber 已載入——此選項生效。",
    ["MMSKIN_PLUMBER_STATUS_OFF"] = "Plumber 未載入——請在登入前啟用此項，或在安裝 Plumber 後重新載入。",

    ["MMSKIN_HIDE_ADDONS"] = "隱藏插件圖示",
    ["MMSKIN_HIDE_ADDONS_DESC"] = "隱藏小地圖插件按鈕，直到你將滑鼠游標停在小地圖區域上。",
    ["MMSKIN_COMBAT_FADE"] = "戰鬥淡出",
    ["MMSKIN_COMBAT_FADE_DESC"] = "戰鬥期間降低小地圖不透明度。",
    ["MMSKIN_PET_HIDE"] = "寵物對戰時隱藏",
    ["MMSKIN_PET_HIDE_DESC"] = "在寵物對戰期間隱藏小地圖。",

    ["MMSKIN_SCALE_LABEL"] = "小地圖區塊縮放",
    ["MMSKIN_SECTION_BORDER"] = "邊框設定",
    ["MMSKIN_BORDER_SIZE"] = "邊框大小",
    ["MMSKIN_BORDER_RED"] = "紅",
    ["MMSKIN_BORDER_GREEN"] = "綠",
    ["MMSKIN_BORDER_BLUE"] = "藍",
    ["MMSKIN_USE_THEME_COLOR"] = "使用佈景主題顏色",

    ["MMSKIN_ZONE_BG"] = "區域背景",
    ["MMSKIN_CLOCK_BG"] = "時鐘背景",

    ["MMSKIN_AUTO_ZOOM_DELAY"] = "自動縮小延遲",
    ["MMSKIN_SHOW_ZOOM_BTNS"] = "顯示縮放按鈕",

    ["MMSKIN_HIDE_WM_BTN"] = "隱藏世界地圖按鈕",
    ["MMSKIN_HIDE_WM_BTN_DESC"] = "隱藏小地圖上的小型世界地圖切換按鈕（你仍可使用其快捷鍵開啟地圖）。",

    ["MMSKIN_SECTION_COMBAT"] = "戰鬥淡出設定",
    ["MMSKIN_COMBAT_ALPHA"] = "戰鬥不透明度",

    ["MMSKIN_SECTION_CLICKS"] = "點擊綁定設定",
    ["MMSKIN_CLICK_RIGHT"] = "右鍵點擊",
    ["MMSKIN_CLICK_MIDDLE"] = "中鍵點擊",
    ["MMSKIN_CLICK_BTN4"] = "按鍵 4",
    ["MMSKIN_CLICK_BTN5"] = "按鍵 5",
    ["MMSKIN_ACTION_NONE"] = "無",
    ["MMSKIN_ACTION_CALENDAR"] = "行事曆",
    ["MMSKIN_ACTION_TRACKING"] = "追蹤",
    ["MMSKIN_ACTION_MISSIONS"] = "任務",
    ["MMSKIN_ACTION_MAP"] = "地圖",
    ["MMSKIN_WORLD_MAP_BUTTON"] = "世界地圖",

    ["MMSKIN_SHOW_COMPARTMENT"] = "插件附掛欄",

    ["MMSKIN_CLOCK_TT_TOGGLE"] = "點擊以切換時間管理員",

    ["MMSKIN_UNCLAMP"] = "解除螢幕邊緣限制",

    ["MMSKIN_ZONE_FONT_LABEL"] = "字型",
    ["MMSKIN_CLOCK_FONT_LABEL"] = "字型",
    ["MMSKIN_FONT_GLOBAL"] = "全域字型",
    ["MMSKIN_FONT_WOW_DEFAULT"] = "WoW 預設（小）",

    ["MMSKIN_SECTION_OPACITY"] = "縮放與不透明度",
    ["MMSKIN_OPACITY"] = "小地圖不透明度",

    ["MMSKIN_SECTION_DEBUG"] = "開發者工具",
    ["MMSKIN_DEBUG_SHOW"] = "顯示除錯圖示",
    ["MMSKIN_DEBUG_HIDE"] = "隱藏除錯圖示",
    ["MMSKIN_DEBUG_DESC"] = "強制顯示所有被追蹤的圖示並帶有彩色標籤。拖曳任意標籤即可將該圖示放置到小地圖上；位置會被儲存。隱藏除錯可將圖示返回到區塊（除非小地圖已分離）。當圖示未被主動觸發時（例如信箱中沒有郵件）很有用。",
    ["MMSKIN_DEBUG_TT_DRAG_HINT"] = "左鍵點擊並拖曳以在小地圖上移動此圖示。",
    ["MMSKIN_DEBUG_TT_POS_FMT"] = "已儲存偏移：%.0f, %.0f",

    ["MMSKIN_RELOAD_PROMPT"] = "變更小地圖形狀需要重新載入介面。\n現在重新載入嗎？",
})
