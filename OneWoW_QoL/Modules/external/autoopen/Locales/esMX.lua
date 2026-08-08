local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["AUTOOPEN_TITLE"] = "Apertura automática",
    ["AUTOOPEN_DESC"] = "Abre automáticamente bolsas, cajas y otros objetos contenedores cuando aparecen en tu inventario. No abre objetos en un banco, buzón o comerciante. Los objetos que aún no puedes abrir (cofres cerrados, nivel/clase/profesión incorrectos, o mientras la ranura está ocupada) se omiten automáticamente.",
    ["AUTOOPEN_OPENING"] = "Abriendo automáticamente: %s",
    ["AUTOOPEN_BLACKLIST_DESC"] = "Añade objetos para evitar que Apertura automática los abra.",
    ["AUTOOPEN_BLACKLIST_REMOVED"] = "Eliminado de la lista negra: %s",
})
