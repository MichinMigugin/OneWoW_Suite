local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["ACHIEVEUNTRACK_TITLE"] = "Abgeschlossene Erfolge nicht mehr verfolgen",
    ["ACHIEVEUNTRACK_DESC"] = "Sucht beim Einloggen automatisch nach bereits abgeschlossenen Erfolgen und hebt deren Verfolgung auf. Macht versteckte Verfolgungsplätze frei, die nach einem Absturz oder einem charakterübergreifenden Abschluss hängenbleiben können.",
})
