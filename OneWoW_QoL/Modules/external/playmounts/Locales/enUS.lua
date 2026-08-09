local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["PLAYMOUNTS_TITLE"] = "Player Mounts",
    ["PLAYMOUNTS_DESC"] = "Detects and displays the mount or movement form currently being used by other players.",
    ["PLAYMOUNTS_TOGGLE_CHAT"] = "Announce in Chat",
    ["PLAYMOUNTS_TOGGLE_CHAT_DESC"] = "Prints the mount name to your chat window when you select a player who is mounted.",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT"] = "Match Mount",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT_DESC"] = "Adds a right-click option on players to summon a mount of the same type they are riding.",
    ["PLAYMOUNTS_COLLECTED"] = "(Collected)",
    ["PLAYMOUNTS_NOT_COLLECTED"] = "(Not Collected)",
    ["PLAYMOUNTS_USING"] = "%s is using %s",
    ["PLAYMOUNTS_SOURCE"] = "Source: %s",
    ["PLAYMOUNTS_DISPLAYMODE_DESC"] = "Controls how much mount information is shown in tooltips and chat output.",
    ["PLAYMOUNTS_MODE_NAME"] = "Name",
    ["PLAYMOUNTS_MODE_NAMETYPE"] = "Name + Type",
    ["PLAYMOUNTS_MODE_ALL"] = "Full Details",
    ["PLAYMOUNTS_TOOLTIP_HEADER"] = "Tooltip Integration",
    ["PLAYMOUNTS_TOOLTIP_REQUIRES"] = "Requires: OneWoW Core",
    ["PLAYMOUNTS_TOOLTIP_DETECTED"] = "Status: Detected",
    ["PLAYMOUNTS_TOOLTIP_NOT_DETECTED"] = "Status: Not Detected",
    ["PLAYMOUNTS_TOOLTIP_NOTE"] = "Enable or disable mount tooltip lines under QoL → Tooltips → Player Mounts.",
    ["PLAYMOUNTS_TOOLTIP_VIEW_BTN"] = "View Settings",
})
