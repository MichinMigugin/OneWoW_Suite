local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["FASTLOOT_TITLE"] = "Saqueo rápido",
    ["FASTLOOT_DESC"] = "Saquea automáticamente todos los objetos de un cadáver o cofre en el momento en que la ventana de botín está lista. Funciona junto con el ajuste de auto-saqueo del juego.",
})
