local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["COORDS_TITLE"] = "座標顯示",
    ["COORDS_DESC"] = "在小地圖附近的一個可移動小框體中顯示你目前的地圖座標。右鍵點擊以複製座標。",
    ["COORDS_TOGGLE_MAPID"] = "顯示地圖 ID",
    ["COORDS_TOGGLE_MAPID_DESC"] = "在座標旁顯示數字地圖 ID。",
    ["COORDS_TOGGLE_ZONE"] = "顯示區域名稱",
    ["COORDS_TOGGLE_ZONE_DESC"] = "在座標下方顯示目前區域名稱。",
    ["COORDS_TOGGLE_SUBZONE"] = "顯示子區域",
    ["COORDS_TOGGLE_SUBZONE_DESC"] = "顯示目前子區域或地區名稱。",
    ["COORDS_TOGGLE_FACING"] = "顯示朝向",
    ["COORDS_TOGGLE_FACING_DESC"] = "以角度和羅盤方向顯示你目前的朝向。",
    ["COORDS_TOGGLE_SPEED"] = "顯示速度",
    ["COORDS_TOGGLE_SPEED_DESC"] = "以每秒碼數顯示你目前的移動速度。",
    ["COORDS_TOGGLE_HIDE_INSTANCE"] = "在副本中隱藏",
    ["COORDS_TOGGLE_HIDE_INSTANCE_DESC"] = "當你身處地城、團隊副本或其他副本中時，自動隱藏座標顯示。",
    ["COORDS_MAP"] = "地圖：%d",
    ["COORDS_COPIED"] = "座標已複製：%s",
    ["COORDS_COPY_TITLE"] = "座標",
})
