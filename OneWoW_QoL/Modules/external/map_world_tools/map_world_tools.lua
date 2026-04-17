local addonName, ns = ...

local MapWorldToolsModule = {
    id             = "map_world_tools",
    title          = "MAPWORLD_TITLE",
    category       = "INTERFACE",
    description    = "MAPWORLD_DESC",
    version        = "1.1",
    author         = "Ricky",
    contact        = "ricky@wow2.xyz",
    link           = "https://www.wow2.xyz",
    preview        = false,
    defaultEnabled = false,

    toggles = {
        { id = "revealMap",          label = "MAPWORLD_REVEAL_MAP",          description = "MAPWORLD_REVEAL_MAP_DESC",          default = true,  group = "MAPWORLD_GROUP_EXPLORE", detailOnly = true },
        { id = "tintUnexplored",    label = "MAPWORLD_TINT_UNEXPLORED",     description = "MAPWORLD_TINT_UNEXPLORED_DESC",    default = false, group = "MAPWORLD_GROUP_EXPLORE", detailOnly = true },
        { id = "removeBattleFog",   label = "MAPWORLD_REMOVE_FOG",          description = "MAPWORLD_REMOVE_FOG_DESC",          default = false, group = "MAPWORLD_GROUP_FOGOVERLAY", detailOnly = true },
        { id = "fogTint",           label = "MAPWORLD_FOG_TINT",            description = "MAPWORLD_FOG_TINT_DESC",            default = false, group = "MAPWORLD_GROUP_FOGOVERLAY", detailOnly = true },
        { id = "clearBlackout",     label = "MAPWORLD_CLEAR_BLACKOUT",      description = "MAPWORLD_CLEAR_BLACKOUT_DESC",      default = true,  group = "MAPWORLD_GROUP_FRAME", detailOnly = true },
        { id = "noMapFade",         label = "MAPWORLD_NO_MAP_FADE",         description = "MAPWORLD_NO_MAP_FADE_DESC",         default = true,  group = "MAPWORLD_GROUP_COMFORT", detailOnly = true },
        { id = "noMapEmote",        label = "MAPWORLD_NO_MAP_EMOTE",        description = "MAPWORLD_NO_MAP_EMOTE_DESC",        default = true,  group = "MAPWORLD_GROUP_COMFORT", detailOnly = true },
        { id = "hideFilterReset",   label = "MAPWORLD_HIDE_FILTER_RESET",   description = "MAPWORLD_HIDE_FILTER_RESET_DESC",   default = true,  group = "MAPWORLD_GROUP_CLEANUP", detailOnly = true },
        { id = "hideMapTutorial",   label = "MAPWORLD_HIDE_MAP_TUTORIAL",   description = "MAPWORLD_HIDE_MAP_TUTORIAL_DESC",   default = true,  group = "MAPWORLD_GROUP_CLEANUP", detailOnly = true },
        { id = "showCoords",        label = "MAPWORLD_SHOW_COORDS",         description = "MAPWORLD_SHOW_COORDS_DESC",         default = false, group = "MAPWORLD_GROUP_COORDS", detailOnly = true },
        { id = "coordsLargeFont",   label = "MAPWORLD_COORDS_LARGE",         description = "MAPWORLD_COORDS_LARGE_DESC",        default = false, group = "MAPWORLD_GROUP_COORDS", detailOnly = true },
        { id = "coordsBackground",  label = "MAPWORLD_COORDS_BG",          description = "MAPWORLD_COORDS_BG_DESC",          default = true,  group = "MAPWORLD_GROUP_COORDS", detailOnly = true },
        { id = "hideContinentPoi",  label = "MAPWORLD_HIDE_CONTINENT_POI",  description = "MAPWORLD_HIDE_CONTINENT_POI_DESC",  default = false, group = "MAPWORLD_GROUP_POI", detailOnly = true },
        { id = "enhanceBattleMap",  label = "MAPWORLD_ENHANCE_BATTLE_MAP",  description = "MAPWORLD_ENHANCE_BATTLE_MAP_DESC",  default = false, group = "MAPWORLD_GROUP_BATTLE", detailOnly = true },
        { id = "unlockBattlefield", label = "MAPWORLD_UNLOCK_BATTLEFIELD",  description = "MAPWORLD_UNLOCK_BATTLEFIELD_DESC",  default = true,  group = "MAPWORLD_GROUP_BATTLE", detailOnly = true },
        { id = "battleCenterOnPlayer", label = "MAPWORLD_BATTLE_CENTER",    description = "MAPWORLD_BATTLE_CENTER_DESC",       default = false, group = "MAPWORLD_GROUP_BATTLE", detailOnly = true },
        { id = "tintMenuShortcut",  label = "MAPWORLD_TINT_MENU",           description = "MAPWORLD_TINT_MENU_DESC",           default = false, group = "MAPWORLD_GROUP_POLISH", detailOnly = true },
        { id = "canvasTint",        label = "MAPWORLD_CANVAS_TINT",         description = "MAPWORLD_CANVAS_TINT_DESC",         default = false, group = "MAPWORLD_GROUP_CANVAS", detailOnly = true },
        { id = "useMapFrameAlpha",  label = "MAPWORLD_MAP_ALPHA",           description = "MAPWORLD_MAP_ALPHA_DESC",           default = false, group = "MAPWORLD_GROUP_MAP", detailOnly = true },
    },
}

ns.MapWorldToolsModule = MapWorldToolsModule
