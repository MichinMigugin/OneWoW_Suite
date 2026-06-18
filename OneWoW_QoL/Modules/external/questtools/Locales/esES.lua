local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["QUESTTOOLS_TITLE"] = "Herramientas de misión",
    ["QUESTTOOLS_DESC"] = "Automatiza la aceptación de misiones, la entrega, el resaltado de recompensas y el diálogo etiquetado como misión opcional. Mantén Mayús al abrir un diálogo de misión o de conversación para omitir la auto-aceptación o el auto-diálogo.",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "Aceptar misiones automáticamente",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "Acepta automáticamente las misiones cuando aparece el diálogo de misión. Mantén Mayús al abrir el diálogo para omitir la auto-aceptación.",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "Entregar misiones automáticamente",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "Completa y entrega misiones automáticamente cuando has cumplido todos los requisitos. Si hay varias recompensas disponibles, espera a que elijas.",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "Resaltar la mejor recompensa",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "Muestra un icono de moneda de oro en el objeto de recompensa de misión con el mayor valor de venta al vendedor.",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "Auto-diálogo (líneas etiquetadas como misión)",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "Selecciona automáticamente las opciones de diálogo marcadas como etiquetadas de misión (QuestLabelPrepend), es decir, las mismas líneas que la interfaz muestra con la etiqueta de estilo misión. Si hay más de una válida, usa el texto visible de la línea para decidir. Mantén Mayús al abrir el diálogo para omitir. Requiere compatibilidad con C_GossipInfo y QuestLabelPrepend (FlagsUtil / Enum.GossipOptionRecFlags) en tu cliente.",
})
