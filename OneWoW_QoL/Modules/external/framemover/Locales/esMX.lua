local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["FRAMEMOVER_TITLE"] = "Movedor de marcos",
    ["FRAMEMOVER_DESC"] = "Arrastra los marcos de la interfaz de Blizzard para reposicionarlos. Usa Ctrl+Rueda para escalar. Mantén Alt al arrastrar para mover los marcos parcialmente fuera de la pantalla cuando «Confinar a la pantalla» esté activado. Las posiciones y escalas pueden persistir entre sesiones.",

    ["FRAMEMOVER_TOGGLE_REQUIRE_SHIFT"] = "Requerir Mayús para arrastrar",
    ["FRAMEMOVER_TOGGLE_ENABLE_SCALING"] = "Escalado con Ctrl+Rueda",
    ["FRAMEMOVER_TOGGLE_SAVE_POSITIONS"] = "Recordar posiciones",
    ["FRAMEMOVER_TOGGLE_SAVE_SCALES"] = "Recordar escalas",
    ["FRAMEMOVER_TOGGLE_CLAMP_SCREEN"] = "Confinar a la pantalla",
    ["FRAMEMOVER_TOGGLE_MODIFY_HUD"] = "Mostrar ventana emergente de escala",

    ["FRAMEMOVER_GROUP_BEHAVIOR"] = "Comportamiento",
    ["FRAMEMOVER_GROUP_SAVING"] = "Persistencia",

    ["FRAMEMOVER_CAT_CORE"] = "Interfaz principal",
    ["FRAMEMOVER_CAT_COLLECTIONS"] = "Colecciones y diarios",
    ["FRAMEMOVER_CAT_PROFESSIONS"] = "Profesiones y economía",
    ["FRAMEMOVER_CAT_GROUP"] = "Contenido de grupo",
    ["FRAMEMOVER_CAT_CHARACTER"] = "Personaje y talentos",
    ["FRAMEMOVER_CAT_SOCIAL"] = "Social y hermandades",
    ["FRAMEMOVER_CAT_MISC"] = "Misceláneo",
    ["FRAMEMOVER_CAT_HOUSING"] = "Vivienda",

    ["FRAMEMOVER_FRAMES_HEADER"] = "Marcos movibles",
    ["FRAMEMOVER_FILTER_EMPTY"] = "Ningún marco coincide con tu búsqueda.",
    ["FRAMEMOVER_RESET_POSITIONS"] = "Restablecer todas las posiciones",
    ["FRAMEMOVER_RESET_SCALES"] = "Restablecer todas las escalas",
    ["FRAMEMOVER_RESET_POS_DONE"] = "Posiciones restablecidas. Vuelve a abrir los marcos para ver los valores predeterminados.",
    ["FRAMEMOVER_RESET_SCALE_DONE"] = "Escalas restablecidas. Vuelve a abrir los marcos para ver los valores predeterminados.",
    ["FRAMEMOVER_ENABLED_TOOLTIP"] = "Clic izquierdo para alternar. Ctrl+Rueda sobre un marco para escalarlo. Mantén Alt al arrastrar para anular el confinamiento.",
    ["FEATURES_ON"] = "Activado",
    ["FEATURES_OFF"] = "Desactivado",
})
