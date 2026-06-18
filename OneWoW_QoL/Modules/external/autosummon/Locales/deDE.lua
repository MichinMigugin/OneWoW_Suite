local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["AUTOSUMMON_TITLE"] = "Beschwörung automatisch annehmen",
    ["AUTOSUMMON_DESC"] = "Nimmt automatisch Beschwörungsanfragen von Hexenmeistern und Beschwörungssteinen an.",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT"] = "Im Kampf überspringen",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT_DESC"] = "Nicht automatisch annehmen, während du im Kampf bist. Empfohlen aktiviert, damit du nicht mitten im Kampf weggezogen wirst.",
})
