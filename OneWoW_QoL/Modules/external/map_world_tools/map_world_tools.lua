local addonName, ns = ...

local MapWorldToolsModule = {
    id             = "map_world_tools",
    title          = "MAPWORLD_TITLE",
    category       = "INTERFACE",
    description    = "MAPWORLD_DESC",
    version        = "1.0",
    author         = "Ricky",
    contact        = "ricky@wow2.xyz",
    link           = "https://www.wow2.xyz",
    preview        = false,
    defaultEnabled = false,

    toggles = {
        { id = "removeBattleFog", label = "MAPWORLD_REMOVE_FOG",       description = "MAPWORLD_REMOVE_FOG_DESC",       default = false, group = "MAPWORLD_GROUP_FOG", detailOnly = true },
        { id = "fogTint",         label = "MAPWORLD_FOG_TINT",           description = "MAPWORLD_FOG_TINT_DESC",           default = false, group = "MAPWORLD_GROUP_FOG", detailOnly = true },
        { id = "canvasTint",      label = "MAPWORLD_CANVAS_TINT",        description = "MAPWORLD_CANVAS_TINT_DESC",        default = false, group = "MAPWORLD_GROUP_CANVAS", detailOnly = true },
        { id = "useMapFrameAlpha", label = "MAPWORLD_MAP_ALPHA",       description = "MAPWORLD_MAP_ALPHA_DESC",        default = false, group = "MAPWORLD_GROUP_MAP", detailOnly = true },
    },
}

ns.MapWorldToolsModule = MapWorldToolsModule
