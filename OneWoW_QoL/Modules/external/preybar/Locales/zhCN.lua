local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["PREYBAR_TITLE"] = "猎物狩猎栏",
    ["PREYBAR_DESC"] = "显示一个可移动的栏，追踪你在当前区域的猎物狩猎进度（冷 > 温 > 热 > 就绪），并显示当前狩猎的首领、难度和词缀。解锁后可将其拖到合适的位置。",

    ["PREYBAR_TOGGLE_BOSS"] = "显示首领名称",
    ["PREYBAR_TOGGLE_BOSS_DESC"] = "在栏上方显示当前猎物狩猎的名称。",
    ["PREYBAR_TOGGLE_DIFFICULTY"] = "显示难度",
    ["PREYBAR_TOGGLE_DIFFICULTY_DESC"] = "显示狩猎难度（普通、困难、噩梦）。",
    ["PREYBAR_TOGGLE_AFFIXES"] = "显示词缀",
    ["PREYBAR_TOGGLE_AFFIXES_DESC"] = "在栏下方显示当前狩猎的词缀图标。",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD"] = "隐藏暴雪小部件",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD_DESC"] = "当此栏处于活动状态时，隐藏暴雪默认的猎物狩猎进度小部件。",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT"] = "点击设置路径点",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT_DESC"] = "当猎物就绪时，点击该栏可在地图上设置前往狩猎的路径点。",
    ["PREYBAR_TOGGLE_LOCK"] = "锁定位置",
    ["PREYBAR_TOGGLE_LOCK_DESC"] = "锁定该栏使其无法被拖动。关闭此项并打开此设置面板，即可使用示例预览重新摆放该栏。",

    ["PREYBAR_STATE_COLD"] = "冷",
    ["PREYBAR_STATE_WARM"] = "温",
    ["PREYBAR_STATE_HOT"] = "热",
    ["PREYBAR_STATE_READY"] = "就绪",

    ["PREYBAR_DIFFICULTY_NORMAL"] = "普通",
    ["PREYBAR_DIFFICULTY_HARD"] = "困难",
    ["PREYBAR_DIFFICULTY_NIGHTMARE"] = "噩梦",

    ["PREYBAR_AFFIX_AMBUSH"] = "伏击",
    ["PREYBAR_AFFIX_TORMENT"] = "折磨",
    ["PREYBAR_AFFIX_SEEPING_GORE"] = "渗血",
    ["PREYBAR_AFFIX_ECHO"] = "掠食回响",
    ["PREYBAR_AFFIX_BLOODY"] = "血腥命令",

    ["PREYBAR_ADVICE_AMBUSHED"] = "遭到伏击！",
    ["PREYBAR_ADVICE_KILL"] = "击杀点什么！",
    ["PREYBAR_ADVICE_READY"] = "猎物已就绪——狩猎它！",

    ["PREYBAR_STATE_LABEL"] = "%s  %d%%",
    ["PREYBAR_DEMO_BOSS"] = "示例猎物",
    ["PREYBAR_DRAG_HINT"] = "解锁以拖动  -  猎物狩猎栏",
    ["PREYBAR_CLICK_WAYPOINT_HINT"] = "点击设置前往猎物的路径点",
    ["PREYBAR_OPACITY_FMT"] = "不透明度：%d%%",
    ["PREYBAR_SAMPLE_BAR_HEADER"] = "示例栏",
    ["PREYBAR_SETTINGS_HINT"] = "此面板打开时会显示一个示例栏，便于你摆放它。关闭“锁定位置”即可拖动它，然后再次锁定。在此面板之外，该栏仅在进行中的猎物狩猎期间出现。",
})
