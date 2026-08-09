local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["PREYBAR_TITLE"] = "獵物狩獵列",
    ["PREYBAR_DESC"] = "顯示一個可移動的列，追蹤你在目前區域的獵物狩獵進度（冷 > 溫 > 熱 > 就緒），並顯示目前狩獵的首領、難度和詞綴。解鎖後可將其拖到合適的位置。",

    ["PREYBAR_TOGGLE_BOSS"] = "顯示首領名稱",
    ["PREYBAR_TOGGLE_BOSS_DESC"] = "在列上方顯示目前獵物狩獵的名稱。",
    ["PREYBAR_TOGGLE_DIFFICULTY"] = "顯示難度",
    ["PREYBAR_TOGGLE_DIFFICULTY_DESC"] = "顯示狩獵難度（普通、困難、噩夢）。",
    ["PREYBAR_TOGGLE_AFFIXES"] = "顯示詞綴",
    ["PREYBAR_TOGGLE_AFFIXES_DESC"] = "在列下方顯示目前狩獵的詞綴圖示。",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD"] = "隱藏暴雪小工具",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD_DESC"] = "當此列處於作用中時，隱藏暴雪預設的獵物狩獵進度小工具。",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT"] = "點擊設定路徑點",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT_DESC"] = "當獵物就緒時，點擊該列可在地圖上設定前往狩獵的路徑點。",
    ["PREYBAR_TOGGLE_LOCK"] = "鎖定位置",
    ["PREYBAR_TOGGLE_LOCK_DESC"] = "鎖定該列使其無法被拖曳。關閉此項並開啟此設定面板，即可使用範例預覽重新擺放該列。",

    ["PREYBAR_STATE_COLD"] = "冷",
    ["PREYBAR_STATE_WARM"] = "溫",
    ["PREYBAR_STATE_HOT"] = "熱",
    ["PREYBAR_STATE_READY"] = "就緒",

    ["PREYBAR_DIFFICULTY_NORMAL"] = "普通",
    ["PREYBAR_DIFFICULTY_HARD"] = "困難",
    ["PREYBAR_DIFFICULTY_NIGHTMARE"] = "噩夢",

    ["PREYBAR_AFFIX_AMBUSH"] = "伏擊",
    ["PREYBAR_AFFIX_TORMENT"] = "折磨",
    ["PREYBAR_AFFIX_SEEPING_GORE"] = "滲血",
    ["PREYBAR_AFFIX_ECHO"] = "掠食迴響",
    ["PREYBAR_AFFIX_BLOODY"] = "血腥命令",

    ["PREYBAR_ADVICE_AMBUSHED"] = "遭到伏擊！",
    ["PREYBAR_ADVICE_KILL"] = "擊殺點什麼！",
    ["PREYBAR_ADVICE_READY"] = "獵物已就緒——狩獵牠！",

    ["PREYBAR_STATE_LABEL"] = "%s  %d%%",
    ["PREYBAR_DEMO_BOSS"] = "範例獵物",
    ["PREYBAR_DRAG_HINT"] = "解鎖以拖曳  -  獵物狩獵列",
    ["PREYBAR_CLICK_WAYPOINT_HINT"] = "點擊設定前往獵物的路徑點",
    ["PREYBAR_OPACITY_FMT"] = "不透明度：%d%%",
    ["PREYBAR_SAMPLE_BAR_HEADER"] = "範例列",
    ["PREYBAR_SETTINGS_HINT"] = "此面板開啟時會顯示一個範例列，便於你擺放它。關閉「鎖定位置」即可拖曳它，然後再次鎖定。在此面板之外，該列僅在進行中的獵物狩獵期間出現。",
})
