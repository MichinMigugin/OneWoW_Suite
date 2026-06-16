local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["MAPWORLD_TITLE"] = "Map (World) Tools",
    ["MAPWORLD_DESC"] = "World map: reveal unexplored terrain from client data, optional tints, battlefield map tweaks, coordinates, and small comfort/cleanup options.",

    ["MAPWORLD_GROUP_EXPLORE"] = "Exploration (map art)",
    ["MAPWORLD_GROUP_FOGOVERLAY"] = "Fog overlay (dark layer)",
    ["MAPWORLD_GROUP_FRAME"] = "Map window",
    ["MAPWORLD_GROUP_COMFORT"] = "Comfort",
    ["MAPWORLD_GROUP_CLEANUP"] = "Cleanup",
    ["MAPWORLD_GROUP_COORDS"] = "Coordinates",
    ["MAPWORLD_GROUP_POI"] = "Points of interest",
    ["MAPWORLD_GROUP_BATTLE"] = "Battlefield minimap",
    ["MAPWORLD_GROUP_POLISH"] = "Polish",
    ["MAPWORLD_GROUP_CANVAS"] = "Full-map overlay",
    ["MAPWORLD_GROUP_MAP"] = "World Map Frame",

    ["MAPWORLD_REVEAL_MAP"] = "Show unexplored areas",
    ["MAPWORLD_REVEAL_MAP_DESC"] = "Draw missing exploration map tiles using bundled map-art data (same idea as revealing the paper map). Works on world and battlefield maps.",

    ["MAPWORLD_TINT_UNEXPLORED"] = "Tint unexplored areas",
    ["MAPWORLD_TINT_UNEXPLORED_DESC"] = "Apply a color tint to tiles revealed by the option above (zone maps only).",

    ["MAPWORLD_UNEX_R"] = "Unexplored red",
    ["MAPWORLD_UNEX_G"] = "Unexplored green",
    ["MAPWORLD_UNEX_B"] = "Unexplored blue",
    ["MAPWORLD_UNEX_A"] = "Unexplored opacity",

    ["MAPWORLD_REMOVE_FOG"] = "Hide dark fog layer",
    ["MAPWORLD_REMOVE_FOG_DESC"] = "Hide Blizzard's Fog-of-War frame on top of the map (separate from drawing missing exploration art).",

    ["MAPWORLD_FOG_TINT"] = "Tint fog layer (FoW)",
    ["MAPWORLD_FOG_TINT_DESC"] = "When the dark fog layer is visible, multiply its color.",

    ["MAPWORLD_CLEAR_BLACKOUT"] = "Click-through world behind map",
    ["MAPWORLD_CLEAR_BLACKOUT_DESC"] = "Make the dimmed \"blackout\" behind the map transparent and non-click-blocking so you see the world clearly.",

    ["MAPWORLD_NO_MAP_FADE"] = "Disable map fade while moving",
    ["MAPWORLD_NO_MAP_FADE_DESC"] = "Sets mapFade so the map does not go semi-transparent when your character moves.",

    ["MAPWORLD_NO_MAP_EMOTE"] = "Disable reading emote",
    ["MAPWORLD_NO_MAP_EMOTE_DESC"] = "Cancel the READ emote when opening the map.",

    ["MAPWORLD_HIDE_FILTER_RESET"] = "Hide filter reset UI",
    ["MAPWORLD_HIDE_FILTER_RESET_DESC"] = "Hide the world map filter reset control and related counter banners.",

    ["MAPWORLD_HIDE_MAP_TUTORIAL"] = "Suppress map tutorial",
    ["MAPWORLD_HIDE_MAP_TUTORIAL_DESC"] = "Hide the world map tutorial frame and mark it closed in info frames.",

    ["MAPWORLD_SHOW_COORDS"] = "Show coordinates",
    ["MAPWORLD_SHOW_COORDS_DESC"] = "Show cursor and player position on the map window.",

    ["MAPWORLD_COORDS_LARGE"] = "Large coordinate font",
    ["MAPWORLD_COORDS_LARGE_DESC"] = "Use a larger font for the coordinate readout.",

    ["MAPWORLD_COORDS_BG"] = "Coordinate bar background",
    ["MAPWORLD_COORDS_BG_DESC"] = "Show a dark strip behind coordinate text.",

    ["MAPWORLD_HIDE_CONTINENT_POI"] = "Hide town/city POI on continents",
    ["MAPWORLD_HIDE_CONTINENT_POI_DESC"] = "Hide specific home, faction, and city pins on continent and world map views.",

    ["MAPWORLD_ENHANCE_BATTLE_MAP"] = "Enhance battlefield map",
    ["MAPWORLD_ENHANCE_BATTLE_MAP_DESC"] = "Show party on the battlefield map and enable the options below.",

    ["MAPWORLD_UNLOCK_BATTLEFIELD"] = "Drag to move battlefield map",
    ["MAPWORLD_UNLOCK_BATTLEFIELD_DESC"] = "Drag the battlefield map by its inner area.",

    ["MAPWORLD_BATTLE_CENTER"] = "Keep battlefield map centered on player",
    ["MAPWORLD_BATTLE_CENTER_DESC"] = "Recenter the battlefield map on your position. Hold Shift while dragging to pause.",

    ["MAPWORLD_BATTLE_OPACITY"] = "Battlefield map visibility",
    ["MAPWORLD_BATTLE_GROUP"] = "Group icon size",
    ["MAPWORLD_BATTLE_PLAYER"] = "Player arrow size",

    ["MAPWORLD_TINT_MENU"] = "World map menu tint toggle",
    ["MAPWORLD_TINT_MENU_DESC"] = "Add a \"Tint unexplored\" checkbox to the map tracking menu (may not load if the menu API changes).",

    ["MAPWORLD_CANVAS_TINT"] = "Full Map Color Overlay",
    ["MAPWORLD_CANVAS_TINT_DESC"] = "Tint the entire map canvas with a translucent color (separate from exploration tint).",

    ["MAPWORLD_MAP_ALPHA"] = "World Map Opacity",
    ["MAPWORLD_MAP_ALPHA_DESC"] = "Lower the opacity of the entire world map window (frame alpha).",

    ["MAPWORLD_MAP_ALPHA_SLIDER"] = "Map window opacity",
    ["MAPWORLD_RED"] = "Red",
    ["MAPWORLD_GREEN"] = "Green",
    ["MAPWORLD_BLUE"] = "Blue",

    ["MAPWORLD_CURSOR"] = "Cursor",
})
