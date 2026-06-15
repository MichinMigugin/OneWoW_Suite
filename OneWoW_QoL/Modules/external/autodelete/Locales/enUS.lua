local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["AUTODELETE_TITLE"] = "Auto Delete",
    ["AUTODELETE_DESC"] = "Skip typing DELETE when destroying items. The confirmation button becomes immediately available without requiring you to type anything.",
    ["AUTODELETE_TOGGLE_SKIP"] = "Skip Typed Confirmation",
    ["AUTODELETE_TOGGLE_SKIP_DESC"] = "Automatically enables the Delete button without requiring you to type DELETE.",
    ["AUTODELETE_TOGGLE_LINK"] = "Show Item Link",
    ["AUTODELETE_TOGGLE_LINK_DESC"] = "Shows the item link in the confirmation popup so you can see what you are about to delete.",
})
