local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["FASTFORWARD_TITLE"] = "Avance rápido",
    ["FASTFORWARD_DESC"] = "Omite automáticamente las películas y cinemáticas del juego. Mantén cualquier tecla modificadora mientras empieza una película o cinemática para verla en su lugar.",
    ["FASTFORWARD_TOGGLE_MOVIES"] = "Omitir películas",
    ["FASTFORWARD_TOGGLE_MOVIES_DESC"] = "Detiene automáticamente las películas del juego cuando comienzan a reproducirse.",
    ["FASTFORWARD_TOGGLE_CINEMATICS"] = "Omitir cinemáticas",
    ["FASTFORWARD_TOGGLE_CINEMATICS_DESC"] = "Cancela automáticamente las secuencias cinemáticas del juego cuando comienzan.",
    ["FASTFORWARD_TOGGLE_INSTANCE"] = "Solo en instancias",
    ["FASTFORWARD_TOGGLE_INSTANCE_DESC"] = "Solo omite películas y cinemáticas mientras estás dentro de una mazmorra, banda u otra instancia.",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE"] = "Respetar las no cancelables",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE_DESC"] = "No intenta omitir las cinemáticas que el juego marca como no cancelables.",
})
