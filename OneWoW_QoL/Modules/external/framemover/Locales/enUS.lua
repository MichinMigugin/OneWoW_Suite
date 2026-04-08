local addonName, ns = ...
local L = ns.L or {}
ns.L = L

-- Module info
L["FRAMEMOVER_TITLE"]       = "Frame Mover"
L["FRAMEMOVER_DESC"]        = "Drag Blizzard UI frames to reposition them. Use Ctrl+Scroll to scale. Positions and scales can persist across sessions."

-- Toggle labels
L["FRAMEMOVER_TOGGLE_REQUIRE_SHIFT"]  = "Require Shift to Drag"
L["FRAMEMOVER_TOGGLE_ENABLE_SCALING"] = "Ctrl+Scroll Scaling"
L["FRAMEMOVER_TOGGLE_SAVE_POSITIONS"] = "Remember Positions"
L["FRAMEMOVER_TOGGLE_SAVE_SCALES"]    = "Remember Scales"
L["FRAMEMOVER_TOGGLE_CLAMP_SCREEN"]   = "Clamp to Screen"

-- Toggle groups
L["FRAMEMOVER_GROUP_BEHAVIOR"] = "Behavior"
L["FRAMEMOVER_GROUP_SAVING"]   = "Persistence"

-- Frame categories
L["FRAMEMOVER_CAT_CORE"]        = "Core UI"
L["FRAMEMOVER_CAT_COLLECTIONS"] = "Collections & Journals"
L["FRAMEMOVER_CAT_PROFESSIONS"] = "Professions & Economy"
L["FRAMEMOVER_CAT_GROUP"]       = "Group Content"
L["FRAMEMOVER_CAT_CHARACTER"]   = "Character & Talents"
L["FRAMEMOVER_CAT_SOCIAL"]      = "Social & Guilds"
L["FRAMEMOVER_CAT_MISC"]        = "Miscellaneous"
L["FRAMEMOVER_CAT_HOUSING"]     = "Housing"

-- Custom detail UI
L["FRAMEMOVER_FRAMES_HEADER"]     = "Movable Frames"
L["FRAMEMOVER_RESET_POSITIONS"]   = "Reset All Positions"
L["FRAMEMOVER_RESET_SCALES"]      = "Reset All Scales"
L["FRAMEMOVER_RESET_POS_DONE"]    = "Positions reset. Reopen frames to see defaults."
L["FRAMEMOVER_RESET_SCALE_DONE"]  = "Scales reset. Reopen frames to see defaults."
L["FRAMEMOVER_ENABLED_TOOLTIP"]   = "Left-click to toggle. Ctrl+Scroll over a frame to scale it."
