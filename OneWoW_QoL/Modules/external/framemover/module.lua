local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id             = "framemover",
    title          = "FRAMEMOVER_TITLE",
    category       = "INTERFACE",
    description    = "FRAMEMOVER_DESC",
    version        = "1.0",
    author         = "Ricky",
    contact        = "ricky@wow2.xyz",
    link           = "https://www.wow2.xyz",
    toggles        = {
        { id = "require_shift",  label = "FRAMEMOVER_TOGGLE_REQUIRE_SHIFT",  default = false, group = "FRAMEMOVER_GROUP_BEHAVIOR" },
        { id = "clamp_to_screen",label = "FRAMEMOVER_TOGGLE_CLAMP_SCREEN",   default = true,  group = "FRAMEMOVER_GROUP_BEHAVIOR" },
        { id = "enable_scaling", label = "FRAMEMOVER_TOGGLE_ENABLE_SCALING", default = true,  group = "FRAMEMOVER_GROUP_BEHAVIOR" },
        { id = "show_modify_hud",label = "FRAMEMOVER_TOGGLE_MODIFY_HUD",     default = true,  group = "FRAMEMOVER_GROUP_BEHAVIOR" },
        { id = "save_positions", label = "FRAMEMOVER_TOGGLE_SAVE_POSITIONS", default = true,  group = "FRAMEMOVER_GROUP_SAVING" },
        { id = "save_scales",    label = "FRAMEMOVER_TOGGLE_SAVE_SCALES",    default = true,  group = "FRAMEMOVER_GROUP_SAVING" },
    },
    preview        = false,
    defaultEnabled = false,
})
