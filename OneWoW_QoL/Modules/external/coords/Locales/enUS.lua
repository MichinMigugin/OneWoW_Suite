local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["COORDS_TITLE"] = "Coords Display",
    ["COORDS_DESC"] = "Displays your current map coordinates in a small movable frame near the minimap. Right-click to copy coordinates.",
    ["COORDS_TOGGLE_MAPID"] = "Show Map ID",
    ["COORDS_TOGGLE_MAPID_DESC"] = "Display the numeric map ID alongside your coordinates.",
    ["COORDS_TOGGLE_ZONE"] = "Show Zone Name",
    ["COORDS_TOGGLE_ZONE_DESC"] = "Display the name of the current zone below the coordinates.",
    ["COORDS_TOGGLE_SUBZONE"] = "Show Subzone",
    ["COORDS_TOGGLE_SUBZONE_DESC"] = "Display the current subzone or area name.",
    ["COORDS_TOGGLE_FACING"] = "Show Facing",
    ["COORDS_TOGGLE_FACING_DESC"] = "Display your current heading in degrees and compass direction.",
    ["COORDS_TOGGLE_SPEED"] = "Show Speed",
    ["COORDS_TOGGLE_SPEED_DESC"] = "Display your current movement speed in yards per second.",
    ["COORDS_TOGGLE_HIDE_INSTANCE"] = "Hide in Instances",
    ["COORDS_TOGGLE_HIDE_INSTANCE_DESC"] = "Automatically hide the coordinate display when inside a dungeon, raid, or other instance.",
    ["COORDS_MAP"] = "Map: %d",
    ["COORDS_COPIED"] = "Coordinates copied: %s",
    ["COORDS_COPY_TITLE"] = "Coordinates",
})
