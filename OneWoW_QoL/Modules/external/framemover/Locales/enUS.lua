local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["FRAMEMOVER_TITLE"] = "Frame Mover",
    ["FRAMEMOVER_DESC"] = "Drag Blizzard UI frames to reposition them. Use Ctrl+Scroll to scale. Hold Alt while dragging to move frames partially off-screen when Clamp to Screen is enabled. Positions and scales can persist across sessions.",

    ["FRAMEMOVER_TOGGLE_REQUIRE_SHIFT"] = "Require Shift to Drag",
    ["FRAMEMOVER_TOGGLE_ENABLE_SCALING"] = "Ctrl+Scroll Scaling",
    ["FRAMEMOVER_TOGGLE_SAVE_POSITIONS"] = "Remember Positions",
    ["FRAMEMOVER_TOGGLE_SAVE_SCALES"] = "Remember Scales",
    ["FRAMEMOVER_TOGGLE_CLAMP_SCREEN"] = "Clamp to Screen",
    ["FRAMEMOVER_TOGGLE_MODIFY_HUD"] = "Show Scale Popup",

    ["FRAMEMOVER_GROUP_BEHAVIOR"] = "Behavior",
    ["FRAMEMOVER_GROUP_SAVING"] = "Persistence",

    ["FRAMEMOVER_CAT_CORE"] = "Core UI",
    ["FRAMEMOVER_CAT_COLLECTIONS"] = "Collections & Journals",
    ["FRAMEMOVER_CAT_PROFESSIONS"] = "Professions & Economy",
    ["FRAMEMOVER_CAT_GROUP"] = "Group Content",
    ["FRAMEMOVER_CAT_CHARACTER"] = "Character & Talents",
    ["FRAMEMOVER_CAT_SOCIAL"] = "Social & Guilds",
    ["FRAMEMOVER_CAT_MISC"] = "Miscellaneous",
    ["FRAMEMOVER_CAT_HOUSING"] = "Housing",

    ["FRAMEMOVER_FRAMES_HEADER"] = "Movable Frames",
    ["FRAMEMOVER_FILTER_EMPTY"] = "No frames match your search.",
    ["FRAMEMOVER_RESET_POSITIONS"] = "Reset All Positions",
    ["FRAMEMOVER_RESET_SCALES"] = "Reset All Scales",
    ["FRAMEMOVER_RESET_POS_DONE"] = "Positions reset. Reopen frames to see defaults.",
    ["FRAMEMOVER_RESET_SCALE_DONE"] = "Scales reset. Reopen frames to see defaults.",
    ["FRAMEMOVER_ENABLED_TOOLTIP"] = "Left-click to toggle. Ctrl+Scroll over a frame to scale it. Hold Alt while dragging to override clamp.",
    ["FEATURES_ON"] = "On",
    ["FEATURES_OFF"] = "Off",
})
