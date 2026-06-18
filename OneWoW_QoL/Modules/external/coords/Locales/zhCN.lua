local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["COORDS_TITLE"] = "坐标显示",
    ["COORDS_DESC"] = "在小地图附近的一个可移动小框体中显示你当前的地图坐标。右键点击以复制坐标。",
    ["COORDS_TOGGLE_MAPID"] = "显示地图 ID",
    ["COORDS_TOGGLE_MAPID_DESC"] = "在坐标旁显示数字地图 ID。",
    ["COORDS_TOGGLE_ZONE"] = "显示区域名称",
    ["COORDS_TOGGLE_ZONE_DESC"] = "在坐标下方显示当前区域名称。",
    ["COORDS_TOGGLE_SUBZONE"] = "显示子区域",
    ["COORDS_TOGGLE_SUBZONE_DESC"] = "显示当前子区域或地区名称。",
    ["COORDS_TOGGLE_FACING"] = "显示朝向",
    ["COORDS_TOGGLE_FACING_DESC"] = "以角度和罗盘方向显示你当前的朝向。",
    ["COORDS_TOGGLE_SPEED"] = "显示速度",
    ["COORDS_TOGGLE_SPEED_DESC"] = "以每秒码数显示你当前的移动速度。",
    ["COORDS_TOGGLE_HIDE_INSTANCE"] = "在副本中隐藏",
    ["COORDS_TOGGLE_HIDE_INSTANCE_DESC"] = "当你身处地下城、团队副本或其他副本中时，自动隐藏坐标显示。",
    ["COORDS_MAP"] = "地图：%d",
    ["COORDS_COPIED"] = "坐标已复制：%s",
    ["COORDS_COPY_TITLE"] = "坐标",
})
