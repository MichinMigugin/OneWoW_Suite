local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["PREYBAR_TITLE"] = "Prey Hunt Bar",
    ["PREYBAR_DESC"] = "Shows a movable bar tracking your prey hunt progress (Cold > Warm > Hot > Ready) for the current zone, with the active hunt's boss, difficulty, and affixes. Unlock it to drag it into place.",

    ["PREYBAR_TOGGLE_BOSS"] = "Show Boss Name",
    ["PREYBAR_TOGGLE_BOSS_DESC"] = "Display the name of the active prey hunt above the bar.",
    ["PREYBAR_TOGGLE_DIFFICULTY"] = "Show Difficulty",
    ["PREYBAR_TOGGLE_DIFFICULTY_DESC"] = "Display the hunt difficulty (Normal, Hard, Nightmare).",
    ["PREYBAR_TOGGLE_AFFIXES"] = "Show Affixes",
    ["PREYBAR_TOGGLE_AFFIXES_DESC"] = "Display the active hunt's affix icons below the bar.",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD"] = "Hide Blizzard Widget",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD_DESC"] = "Hide Blizzard's default prey hunt progress widget while this bar is active.",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT"] = "Click to Set Waypoint",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT_DESC"] = "When the prey is ready, click the bar to set a map waypoint to the hunt.",
    ["PREYBAR_TOGGLE_LOCK"] = "Lock Position",
    ["PREYBAR_TOGGLE_LOCK_DESC"] = "Lock the bar so it can't be dragged. Turn this off and open this settings panel to reposition the bar using the sample preview.",

    ["PREYBAR_STATE_COLD"] = "Cold",
    ["PREYBAR_STATE_WARM"] = "Warm",
    ["PREYBAR_STATE_HOT"] = "Hot",
    ["PREYBAR_STATE_READY"] = "Ready",

    ["PREYBAR_DIFFICULTY_NORMAL"] = "Normal",
    ["PREYBAR_DIFFICULTY_HARD"] = "Hard",
    ["PREYBAR_DIFFICULTY_NIGHTMARE"] = "Nightmare",

    ["PREYBAR_AFFIX_AMBUSH"] = "Ambush",
    ["PREYBAR_AFFIX_TORMENT"] = "Torment",
    ["PREYBAR_AFFIX_SEEPING_GORE"] = "Seeping Gore",
    ["PREYBAR_AFFIX_ECHO"] = "Echo of Predation",
    ["PREYBAR_AFFIX_BLOODY"] = "Bloody Command",

    ["PREYBAR_ADVICE_AMBUSHED"] = "Ambushed!",
    ["PREYBAR_ADVICE_KILL"] = "Kill something!",
    ["PREYBAR_ADVICE_READY"] = "Prey is ready - hunt it!",

    ["PREYBAR_STATE_LABEL"] = "%s  %d%%",
    ["PREYBAR_DEMO_BOSS"] = "Sample Prey",
    ["PREYBAR_DRAG_HINT"] = "Unlock to drag  -  Prey Hunt Bar",
    ["PREYBAR_CLICK_WAYPOINT_HINT"] = "Click to set a waypoint to your prey",
    ["PREYBAR_OPACITY_FMT"] = "Opacity: %d%%",
    ["PREYBAR_SAMPLE_BAR_HEADER"] = "Sample Bar",
    ["PREYBAR_SETTINGS_HINT"] = "A sample bar is shown while this panel is open so you can position it. Turn off Lock Position to drag it, then lock it again. Outside of this panel the bar only appears during an active prey hunt.",
})
