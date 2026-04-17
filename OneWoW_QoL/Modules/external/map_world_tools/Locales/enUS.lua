local addonName, ns = ...
if not ns.L_enUS then ns.L_enUS = {} end
local L = ns.L_enUS

L["MAPWORLD_TITLE"]            = "Map (World) Tools"
L["MAPWORLD_DESC"]             = "World map options: hide undiscovered fog, tint fog layers, full-map color overlay, and optional world map window opacity."

L["MAPWORLD_GROUP_FOG"]        = "Fog of War"
L["MAPWORLD_GROUP_CANVAS"]     = "Map Overlay"
L["MAPWORLD_GROUP_MAP"]        = "World Map Frame"

L["MAPWORLD_REMOVE_FOG"]       = "Remove Battle Fog"
L["MAPWORLD_REMOVE_FOG_DESC"]  = "Hide the fog-of-war overlay on the world map so unexplored areas appear like the rest of the map."

L["MAPWORLD_FOG_TINT"]         = "Tint Fog Layer"
L["MAPWORLD_FOG_TINT_DESC"]    = "When fog is visible, multiply its color (use with Remove Battle Fog off)."

L["MAPWORLD_CANVAS_TINT"]      = "Full Map Color Overlay"
L["MAPWORLD_CANVAS_TINT_DESC"] = "Tint the entire map canvas with a translucent color (separate from fog)."

L["MAPWORLD_SECTION_FOG_RGB"]   = "Fog Tint Color"
L["MAPWORLD_SECTION_CANVAS"]   = "Overlay Color"
L["MAPWORLD_RED"]              = "Red"
L["MAPWORLD_GREEN"]            = "Green"
L["MAPWORLD_BLUE"]             = "Blue"
L["MAPWORLD_ALPHA"]            = "Opacity"

L["MAPWORLD_MAP_ALPHA"]        = "World Map Opacity"
L["MAPWORLD_MAP_ALPHA_DESC"]   = "Lower the opacity of the entire world map window (frame alpha). Separate from overlay tint."
L["MAPWORLD_MAP_ALPHA_SLIDER"] = "Map window opacity"
