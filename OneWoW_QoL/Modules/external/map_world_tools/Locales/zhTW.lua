local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["MAPWORLD_TITLE"] = "地圖（世界）工具",
    ["MAPWORLD_DESC"] = "世界地圖：根據客戶端資料顯示未探索地形、可選著色、戰場地圖調整、座標，以及一些便利/清理選項。",

    ["MAPWORLD_GROUP_EXPLORE"] = "探索（地圖美術）",
    ["MAPWORLD_GROUP_FOGOVERLAY"] = "迷霧覆蓋層（暗層）",
    ["MAPWORLD_GROUP_FRAME"] = "地圖視窗",
    ["MAPWORLD_GROUP_COMFORT"] = "便利",
    ["MAPWORLD_GROUP_CLEANUP"] = "清理",
    ["MAPWORLD_GROUP_COORDS"] = "座標",
    ["MAPWORLD_GROUP_POI"] = "興趣點",
    ["MAPWORLD_GROUP_BATTLE"] = "戰場地圖",
    ["MAPWORLD_GROUP_POLISH"] = "潤飾",
    ["MAPWORLD_GROUP_CANVAS"] = "全圖覆蓋層",
    ["MAPWORLD_GROUP_MAP"] = "世界地圖框體",

    ["MAPWORLD_REVEAL_MAP"] = "顯示未探索區域",
    ["MAPWORLD_REVEAL_MAP_DESC"] = "使用內建的地圖美術資料繪製缺少的探索地圖圖塊（與揭開紙本地圖的原理相同）。在世界地圖和戰場地圖上均有效。",

    ["MAPWORLD_TINT_UNEXPLORED"] = "為未探索區域著色",
    ["MAPWORLD_TINT_UNEXPLORED_DESC"] = "為上方選項揭示的圖塊套用顏色著色（僅限區域地圖）。",

    ["MAPWORLD_UNEX_R"] = "未探索 紅",
    ["MAPWORLD_UNEX_G"] = "未探索 綠",
    ["MAPWORLD_UNEX_B"] = "未探索 藍",
    ["MAPWORLD_UNEX_A"] = "未探索 不透明度",

    ["MAPWORLD_REMOVE_FOG"] = "隱藏暗色迷霧層",
    ["MAPWORLD_REMOVE_FOG_DESC"] = "隱藏地圖上方暴雪的戰爭迷霧框體（與繪製缺少的探索美術無關）。",

    ["MAPWORLD_FOG_TINT"] = "為迷霧層著色（戰爭迷霧）",
    ["MAPWORLD_FOG_TINT_DESC"] = "當暗色迷霧層可見時，對其顏色進行疊加。",

    ["MAPWORLD_CLEAR_BLACKOUT"] = "可點擊地圖後方的世界",
    ["MAPWORLD_CLEAR_BLACKOUT_DESC"] = "使地圖後方變暗的「黑幕」變得透明且不阻擋點擊，讓你清楚地看到世界。",

    ["MAPWORLD_NO_MAP_FADE"] = "移動時停用地圖淡出",
    ["MAPWORLD_NO_MAP_FADE_DESC"] = "設定 mapFade，使角色移動時地圖不會變為半透明。",

    ["MAPWORLD_NO_MAP_EMOTE"] = "停用閱讀表情",
    ["MAPWORLD_NO_MAP_EMOTE_DESC"] = "開啟地圖時取消閱讀表情。",

    ["MAPWORLD_HIDE_FILTER_RESET"] = "隱藏篩選重設介面",
    ["MAPWORLD_HIDE_FILTER_RESET_DESC"] = "隱藏世界地圖篩選重設控制項及相關的計數橫幅。",

    ["MAPWORLD_HIDE_MAP_TUTORIAL"] = "屏蔽地圖教學",
    ["MAPWORLD_HIDE_MAP_TUTORIAL_DESC"] = "隱藏世界地圖教學框體，並在資訊框體中將其標記為已關閉。",

    ["MAPWORLD_SHOW_COORDS"] = "顯示座標",
    ["MAPWORLD_SHOW_COORDS_DESC"] = "在地圖視窗顯示游標和玩家位置。",

    ["MAPWORLD_COORDS_LARGE"] = "大號座標字型",
    ["MAPWORLD_COORDS_LARGE_DESC"] = "為座標讀數使用更大的字型。",

    ["MAPWORLD_COORDS_BG"] = "座標列背景",
    ["MAPWORLD_COORDS_BG_DESC"] = "在座標文字後顯示一條深色條帶。",

    ["MAPWORLD_HIDE_CONTINENT_POI"] = "在大陸上隱藏城鎮/城市興趣點",
    ["MAPWORLD_HIDE_CONTINENT_POI_DESC"] = "在大陸和世界地圖檢視中隱藏特定的家園、陣營和城市標記。",

    ["MAPWORLD_ENHANCE_BATTLE_MAP"] = "增強戰場地圖",
    ["MAPWORLD_ENHANCE_BATTLE_MAP_DESC"] = "在戰場地圖上顯示小隊，並啟用下方選項。",

    ["MAPWORLD_UNLOCK_BATTLEFIELD"] = "拖曳以移動戰場地圖",
    ["MAPWORLD_UNLOCK_BATTLEFIELD_DESC"] = "透過戰場地圖的內部區域拖曳它。",

    ["MAPWORLD_BATTLE_CENTER"] = "使戰場地圖保持以玩家為中心",
    ["MAPWORLD_BATTLE_CENTER_DESC"] = "將戰場地圖重新置中到你的位置。拖曳時按住 Shift 可暫停。",

    ["MAPWORLD_BATTLE_OPACITY"] = "戰場地圖可見度",
    ["MAPWORLD_BATTLE_GROUP"] = "小隊圖示大小",
    ["MAPWORLD_BATTLE_PLAYER"] = "玩家箭頭大小",

    ["MAPWORLD_TINT_MENU"] = "世界地圖選單著色開關",
    ["MAPWORLD_TINT_MENU_DESC"] = "在地圖追蹤選單中新增一個「為未探索著色」核取方塊（若選單 API 改變可能無法載入）。",

    ["MAPWORLD_CANVAS_TINT"] = "全圖顏色覆蓋",
    ["MAPWORLD_CANVAS_TINT_DESC"] = "用半透明顏色為整個地圖畫布著色（與探索著色無關）。",

    ["MAPWORLD_MAP_ALPHA"] = "世界地圖不透明度",
    ["MAPWORLD_MAP_ALPHA_DESC"] = "降低整個世界地圖視窗的不透明度（框體透明度）。",

    ["MAPWORLD_MAP_ALPHA_SLIDER"] = "地圖視窗不透明度",
    ["MAPWORLD_RED"] = "紅",
    ["MAPWORLD_GREEN"] = "綠",
    ["MAPWORLD_BLUE"] = "藍",

    ["MAPWORLD_CURSOR"] = "游標",
})
