local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["MAPWORLD_TITLE"] = "地图（世界）工具",
    ["MAPWORLD_DESC"] = "世界地图：根据客户端数据显示未探索地形、可选着色、战场地图调整、坐标，以及一些便利/清理选项。",

    ["MAPWORLD_GROUP_EXPLORE"] = "探索（地图美术）",
    ["MAPWORLD_GROUP_FOGOVERLAY"] = "迷雾覆盖层（暗层）",
    ["MAPWORLD_GROUP_FRAME"] = "地图窗口",
    ["MAPWORLD_GROUP_COMFORT"] = "便利",
    ["MAPWORLD_GROUP_CLEANUP"] = "清理",
    ["MAPWORLD_GROUP_COORDS"] = "坐标",
    ["MAPWORLD_GROUP_POI"] = "兴趣点",
    ["MAPWORLD_GROUP_BATTLE"] = "战场地图",
    ["MAPWORLD_GROUP_POLISH"] = "润色",
    ["MAPWORLD_GROUP_CANVAS"] = "全图覆盖层",
    ["MAPWORLD_GROUP_MAP"] = "世界地图框体",

    ["MAPWORLD_REVEAL_MAP"] = "显示未探索区域",
    ["MAPWORLD_REVEAL_MAP_DESC"] = "使用内置的地图美术数据绘制缺失的探索地图图块（与揭开纸质地图的原理相同）。在世界地图和战场地图上均有效。",

    ["MAPWORLD_TINT_UNEXPLORED"] = "为未探索区域着色",
    ["MAPWORLD_TINT_UNEXPLORED_DESC"] = "为上方选项揭示的图块应用颜色着色（仅限区域地图）。",

    ["MAPWORLD_UNEX_R"] = "未探索 红",
    ["MAPWORLD_UNEX_G"] = "未探索 绿",
    ["MAPWORLD_UNEX_B"] = "未探索 蓝",
    ["MAPWORLD_UNEX_A"] = "未探索 不透明度",

    ["MAPWORLD_REMOVE_FOG"] = "隐藏暗色迷雾层",
    ["MAPWORLD_REMOVE_FOG_DESC"] = "隐藏地图上方暴雪的战争迷雾框体（与绘制缺失的探索美术无关）。",

    ["MAPWORLD_FOG_TINT"] = "为迷雾层着色（战争迷雾）",
    ["MAPWORLD_FOG_TINT_DESC"] = "当暗色迷雾层可见时，对其颜色进行叠加。",

    ["MAPWORLD_CLEAR_BLACKOUT"] = "可点击地图后方的世界",
    ["MAPWORLD_CLEAR_BLACKOUT_DESC"] = "使地图后方变暗的“黑幕”变得透明且不阻挡点击，让你清楚地看到世界。",

    ["MAPWORLD_NO_MAP_FADE"] = "移动时禁用地图淡出",
    ["MAPWORLD_NO_MAP_FADE_DESC"] = "设置 mapFade，使角色移动时地图不会变为半透明。",

    ["MAPWORLD_NO_MAP_EMOTE"] = "禁用阅读表情",
    ["MAPWORLD_NO_MAP_EMOTE_DESC"] = "打开地图时取消阅读表情。",

    ["MAPWORLD_HIDE_FILTER_RESET"] = "隐藏筛选重置界面",
    ["MAPWORLD_HIDE_FILTER_RESET_DESC"] = "隐藏世界地图筛选重置控件及相关的计数横幅。",

    ["MAPWORLD_HIDE_MAP_TUTORIAL"] = "屏蔽地图教程",
    ["MAPWORLD_HIDE_MAP_TUTORIAL_DESC"] = "隐藏世界地图教程框体，并在信息框体中将其标记为已关闭。",

    ["MAPWORLD_SHOW_COORDS"] = "显示坐标",
    ["MAPWORLD_SHOW_COORDS_DESC"] = "在地图窗口显示光标和玩家位置。",

    ["MAPWORLD_COORDS_LARGE"] = "大号坐标字体",
    ["MAPWORLD_COORDS_LARGE_DESC"] = "为坐标读数使用更大的字体。",

    ["MAPWORLD_COORDS_BG"] = "坐标栏背景",
    ["MAPWORLD_COORDS_BG_DESC"] = "在坐标文字后显示一条深色条带。",

    ["MAPWORLD_HIDE_CONTINENT_POI"] = "在大陆上隐藏城镇/城市兴趣点",
    ["MAPWORLD_HIDE_CONTINENT_POI_DESC"] = "在大陆和世界地图视图中隐藏特定的家园、阵营和城市标记。",

    ["MAPWORLD_ENHANCE_BATTLE_MAP"] = "增强战场地图",
    ["MAPWORLD_ENHANCE_BATTLE_MAP_DESC"] = "在战场地图上显示小队，并启用下方选项。",

    ["MAPWORLD_UNLOCK_BATTLEFIELD"] = "拖动以移动战场地图",
    ["MAPWORLD_UNLOCK_BATTLEFIELD_DESC"] = "通过战场地图的内部区域拖动它。",

    ["MAPWORLD_BATTLE_CENTER"] = "使战场地图保持以玩家为中心",
    ["MAPWORLD_BATTLE_CENTER_DESC"] = "将战场地图重新居中到你的位置。拖动时按住 Shift 可暂停。",

    ["MAPWORLD_BATTLE_OPACITY"] = "战场地图可见度",
    ["MAPWORLD_BATTLE_GROUP"] = "小队图标大小",
    ["MAPWORLD_BATTLE_PLAYER"] = "玩家箭头大小",

    ["MAPWORLD_TINT_MENU"] = "世界地图菜单着色开关",
    ["MAPWORLD_TINT_MENU_DESC"] = "在地图追踪菜单中添加一个“为未探索着色”复选框（若菜单 API 改变可能无法加载）。",

    ["MAPWORLD_CANVAS_TINT"] = "全图颜色覆盖",
    ["MAPWORLD_CANVAS_TINT_DESC"] = "用半透明颜色为整个地图画布着色（与探索着色无关）。",

    ["MAPWORLD_MAP_ALPHA"] = "世界地图不透明度",
    ["MAPWORLD_MAP_ALPHA_DESC"] = "降低整个世界地图窗口的不透明度（框体透明度）。",

    ["MAPWORLD_MAP_ALPHA_SLIDER"] = "地图窗口不透明度",
    ["MAPWORLD_RED"] = "红",
    ["MAPWORLD_GREEN"] = "绿",
    ["MAPWORLD_BLUE"] = "蓝",

    ["MAPWORLD_CURSOR"] = "光标",
})
