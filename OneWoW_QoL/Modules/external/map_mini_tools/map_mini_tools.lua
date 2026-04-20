local addonName, ns = ...

local MapMiniToolsModule = {
    id             = "map_mini_tools",
    title          = "MMSKIN_TITLE",
    category       = "INTERFACE",
    description    = "MMSKIN_DESC",
    version        = "1.0",
    author         = "Ricky",
    contact        = "ricky@wow2.xyz",
    link           = "https://www.wow2.xyz",
    preview        = false,
    defaultEnabled = false,

    toggles = {
        { id = "squareShape",    label = "MMSKIN_SQUARE",       description = "MMSKIN_SQUARE_DESC",       default = false, group = "MMSKIN_GROUP_SHAPE" },
        { id = "showBorder",     label = "MMSKIN_BORDER",       description = "MMSKIN_BORDER_DESC",       default = true,  group = "MMSKIN_GROUP_SHAPE" },
        { id = "classBorder",    label = "MMSKIN_CLASS_BORDER", description = "MMSKIN_CLASS_BORDER_DESC", default = false, group = "MMSKIN_GROUP_SHAPE" },
        { id = "unlockMinimap", label = "MMSKIN_UNLOCK",       description = "MMSKIN_UNLOCK_DESC",       default = false, group = "MMSKIN_GROUP_SHAPE" },
        { id = "lockPosition",  label = "MMSKIN_LOCK_POS",     description = "MMSKIN_LOCK_POS_DESC",     default = false, group = "MMSKIN_GROUP_SHAPE" },

        { id = "showZoneText",   label = "MMSKIN_ZONE_TEXT",    description = "MMSKIN_ZONE_TEXT_DESC",    default = true,  group = "MMSKIN_GROUP_INFO",   detailOnly = true },
        { id = "showClock",      label = "MMSKIN_CLOCK",        description = "MMSKIN_CLOCK_DESC",        default = true,  group = "MMSKIN_GROUP_INFO",   detailOnly = true },
        { id = "classClockColor", label = "MMSKIN_CLASS_CLOCK_COLOR", description = "MMSKIN_CLASS_CLOCK_COLOR_DESC", default = false, group = "MMSKIN_GROUP_INFO", detailOnly = true },
        { id = "zoneClockInside", label = "MMSKIN_ZONE_CLOCK_INSIDE", description = "MMSKIN_ZONE_CLOCK_INSIDE_DESC", default = false, group = "MMSKIN_GROUP_INFO", detailOnly = true },
        { id = "zoneClockDraggable", label = "MMSKIN_ZONE_CLOCK_DRAG", description = "MMSKIN_ZONE_CLOCK_DRAG_DESC", default = false, group = "MMSKIN_GROUP_INFO", detailOnly = true },

        { id = "mouseWheelZoom", label = "MMSKIN_WHEEL_ZOOM",   description = "MMSKIN_WHEEL_ZOOM_DESC",   default = true,  group = "MMSKIN_GROUP_ZOOM" },
        { id = "autoZoomOut",    label = "MMSKIN_AUTO_ZOOM",    description = "MMSKIN_AUTO_ZOOM_DESC",    default = true,  group = "MMSKIN_GROUP_ZOOM",   detailOnly = true },

        { id = "clickActions",   label = "MMSKIN_CLICK_ACTIONS", description = "MMSKIN_CLICK_ACTIONS_DESC", default = true, group = "MMSKIN_GROUP_CLICKS", detailOnly = true },

        { id = "showMail",         label = "MMSKIN_MAIL",       description = "MMSKIN_MAIL_DESC",         default = true,  group = "MMSKIN_GROUP_ELEMENTS" },
        { id = "showCraftingOrder", label = "MMSKIN_CRAFTING",   description = "MMSKIN_CRAFTING_DESC",     default = true,  group = "MMSKIN_GROUP_ELEMENTS" },
        { id = "showDifficulty",   label = "MMSKIN_DIFFICULTY",  description = "MMSKIN_DIFFICULTY_DESC",   default = true,  group = "MMSKIN_GROUP_ELEMENTS" },
        { id = "showTracking",     label = "MMSKIN_TRACKING",    description = "MMSKIN_TRACKING_DESC",     default = true,  group = "MMSKIN_GROUP_ELEMENTS" },
        { id = "showMissions",     label = "MMSKIN_MISSIONS",    description = "MMSKIN_MISSIONS_DESC",     default = true,  group = "MMSKIN_GROUP_ELEMENTS" },
        { id = "showGameTime",     label = "MMSKIN_GAMETIME",    description = "MMSKIN_GAMETIME_DESC",     default = true,  group = "MMSKIN_GROUP_ELEMENTS" },

        { id = "hideBlizzardExpansionWhenPlumber", label = "MMSKIN_PLUMBER_HIDE_BLIZZARD", description = "MMSKIN_PLUMBER_HIDE_BLIZZARD_DESC", default = true, group = "MMSKIN_GROUP_COMPAT", detailOnly = true },

        { id = "hideAddonIcons", label = "MMSKIN_HIDE_ADDONS",  description = "MMSKIN_HIDE_ADDONS_DESC",  default = false, group = "MMSKIN_GROUP_EXTRAS" },
        { id = "hideWorldMapButton", label = "MMSKIN_HIDE_WM_BTN", description = "MMSKIN_HIDE_WM_BTN_DESC", default = false, group = "MMSKIN_GROUP_ZOOM", detailOnly = true },
        { id = "combatFade",     label = "MMSKIN_COMBAT_FADE",  description = "MMSKIN_COMBAT_FADE_DESC",  default = false, group = "MMSKIN_GROUP_EXTRAS", detailOnly = true },
        { id = "petBattleHide",  label = "MMSKIN_PET_HIDE",     description = "MMSKIN_PET_HIDE_DESC",     default = true,  group = "MMSKIN_GROUP_EXTRAS" },
    },
}

ns.MapMiniToolsModule = MapMiniToolsModule
