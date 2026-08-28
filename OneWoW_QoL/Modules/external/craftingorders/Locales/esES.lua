local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["CRAFTORDERS_TITLE"] = "Pedidos de fabricacion",
    ["CRAFTORDERS_DESC"] = "Sustituye la lista de pedidos por Se puede fabricar ahora y Faltan materiales. Anade los componentes que faltan a una lista de la compra. Empieza, fabrica y completa con un solo boton.",
    ["CRAFTORDERS_SECTION_READY"] = "Se puede fabricar ahora",
    ["CRAFTORDERS_SECTION_MISSING"] = "Faltan materiales",
    ["CRAFTORDERS_WEEKLY_NOT_ACCEPTED"] = "Semanal: no aceptada",
    ["CRAFTORDERS_WEEKLY_NOT_LEARNED"] = "Semanal: no aprendida",
    ["CRAFTORDERS_WEEKLY_COMPLETE"] = "Semanal: completada",
    ["CRAFTORDERS_WEEKLY_PROGRESS"] = "Semanal: %d / %d cubiertos",
    ["CRAFTORDERS_LOADING"] = "Cargando pedidos...",
    ["CRAFTORDERS_ADD_ACTIVE"] = "Anadir a %s",
    ["CRAFTORDERS_MAKE_LIST"] = "Crear lista",
    ["CRAFTORDERS_ADD_MENU_HINT"] = "Clic derecho para crear una lista o elegir otra.",
    ["CRAFTORDERS_ELSEWHERE_TIP"] = "Tambien en: %s",
    ["CRAFTORDERS_COL_CRAFT"] = "Pedido",
    ["CRAFTORDERS_COL_YOU"] = "Tu aportas",
    ["CRAFTORDERS_COL_CART"] = "Lista",
    ["CRAFTORDERS_COL_CUSTOMER"] = "Cliente aporta",
    ["CRAFTORDERS_COL_REWARD"] = "Recibes",
    ["CRAFTORDERS_USE_WOWUI"] = "WoW UI",
    ["CRAFTORDERS_USE_ONEUI"] = "One UI",
    ["CRAFTORDERS_TOGGLE_WOWUI"] = "Usar lista de WoW",
    ["CRAFTORDERS_TOGGLE_WOWUI_DESC"] = "Mostrar la tabla de pedidos de Blizzard en lugar de Se puede fabricar ahora y Faltan materiales.",
    ["CRAFTORDERS_TOGGLE_HIDE_UNLEARNED"] = "Ocultar recetas sin aprender",
    ["CRAFTORDERS_TOGGLE_HIDE_UNLEARNED_DESC"] = "Ocultar pedidos cuya receta no has aprendido.",
    ["CRAFTORDERS_BUCKET_COUNT"] = "%d pedidos",
    ["CRAFTORDERS_ORDER_LIST_NAME"] = "Pedido: %s",
    ["CRAFTORDERS_NO_SHOPPING"] = "Activa la lista de la compra para anadir componentes.",
    ["CRAFTORDERS_KP"] = "%d PC",
    ["CRAFTORDERS_ACUITY"] = "Agudeza x%d",
    ["CRAFTORDERS_INCOMPATIBLE_TITLE"] = "Otros addons de lista de pedidos",
    ["CRAFTORDERS_INCOMPATIBLE_BODY"] = "%s esta activo. Esos addons siguen cargados. Activa esto para One UI, o desactivalo para usarlos.",
})
