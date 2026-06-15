local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["AUTOINVITE_TITLE"] = "Auto-Accept Party Invites",
    ["AUTOINVITE_DESC"] = "Automatically accepts party invites that come from people you trust. Choose which sources are allowed below.",
    ["AUTOINVITE_TOGGLE_FRIENDS"] = "From Friends",
    ["AUTOINVITE_TOGGLE_FRIENDS_DESC"] = "Accept invites from WoW friends and Battle.net friends.",
    ["AUTOINVITE_TOGGLE_GUILD"] = "From Guild",
    ["AUTOINVITE_TOGGLE_GUILD_DESC"] = "Accept invites from members of your guild.",
    ["AUTOINVITE_TOGGLE_ALL"] = "From Anyone",
    ["AUTOINVITE_TOGGLE_ALL_DESC"] = "Accept any party invite, regardless of who sent it. Overrides the other toggles when enabled.",
})
