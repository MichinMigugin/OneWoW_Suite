local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["ACHIEVEUNTRACK_TITLE"] = "Dejar de seguir logros completados",
    ["ACHIEVEUNTRACK_DESC"] = "Busca y deja de seguir automáticamente los logros ya completados al iniciar sesión. Libera ranuras de seguimiento ocultas que pueden quedar bloqueadas tras un fallo o una finalización entre personajes.",
})
