local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["CHARINFO_TITLE"] = "Hoja de info del personaje",
    ["CHARINFO_DESC"] = "Muestra un panel de info limpio junto a cada objeto equipado en tu hoja de personaje, indicando el nivel de objeto (coloreado por calidad), el estado de encantamiento, el estado de las ranuras y el porcentaje de durabilidad.",
    ["CHARINFO_ENCHANTED"] = "Encantado",
    ["CHARINFO_MISSING_ENCHANT"] = "Falta encantamiento",
    ["CHARINFO_NO_ENCHANT_NEEDED"] = "No necesita encantamiento",
    ["CHARINFO_ALL_SOCKETS_EMPTY"] = "Todas las ranuras vacías",
    ["CHARINFO_SOME_SOCKETS_EMPTY"] = "Algunas ranuras vacías",
    ["CHARINFO_ALL_SOCKETS_FILLED"] = "Todas las ranuras llenas",
    ["CHARINFO_NO_SOCKETS"] = "Sin ranuras",
    ["CHARINFO_TOGGLE_DURABILITY"] = "Mostrar durabilidad",
    ["CHARINFO_TOGGLE_DURABILITY_DESC"] = "Muestra el porcentaje de durabilidad en los botones de objeto",
    ["CHARINFO_TOGGLE_SOCKETS"] = "Mostrar icono de sin ranura",
    ["CHARINFO_TOGGLE_SOCKETS_DESC"] = "Muestra un icono cuando los objetos no tienen ranuras",
    ["CHARINFO_ENCHANT_SLOTS_HEADER"] = "Seguimiento de espacios de encantamiento",
    ["CHARINFO_ENCHANT_SLOTS_DESC"] = "Elige qué espacios de equipo seguir para encantamientos. Los espacios desactivados no mostrarán iconos de estado de encantamiento.",
    ["CHARINFO_SLOT_HEAD"] = "Cabeza",
    ["CHARINFO_SLOT_NECK"] = "Cuello",
    ["CHARINFO_SLOT_SHOULDER"] = "Hombros",
    ["CHARINFO_SLOT_CHEST"] = "Pecho",
    ["CHARINFO_SLOT_WAIST"] = "Cintura",
    ["CHARINFO_SLOT_LEGS"] = "Piernas",
    ["CHARINFO_SLOT_FEET"] = "Pies",
    ["CHARINFO_SLOT_WRIST"] = "Muñecas",
    ["CHARINFO_SLOT_HANDS"] = "Manos",
    ["CHARINFO_SLOT_RING1"] = "Anillo 1",
    ["CHARINFO_SLOT_RING2"] = "Anillo 2",
    ["CHARINFO_SLOT_BACK"] = "Espalda",
    ["CHARINFO_SLOT_MAINHAND"] = "Mano derecha",
    ["CHARINFO_SLOT_OFFHAND"] = "Mano izquierda",
    ["FEATURES_ON"] = "Activado",
    ["FEATURES_OFF"] = "Desactivado",
})
