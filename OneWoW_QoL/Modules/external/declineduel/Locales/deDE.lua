local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["DECLINEDUEL_TITLE"] = "Duelle automatisch ablehnen",
    ["DECLINEDUEL_DESC"] = "Lehnt Duellanfragen automatisch ab, sodass das Popup nie auf deinem Bildschirm verweilt.",
    ["DECLINEDUEL_TOGGLE_PET"] = "Auch Haustierduelle ablehnen",
    ["DECLINEDUEL_TOGGLE_PET_DESC"] = "Lehnt auch Haustierkampf-Duellanfragen automatisch ab.",
})
