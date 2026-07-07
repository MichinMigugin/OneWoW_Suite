local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["MMSKIN_TITLE"] = "Herramientas de mapa (mini)",
    ["MMSKIN_DESC"] = "Personaliza el conjunto de tu minimapa: forma, borde, texto de zona, reloj, acciones de clic, controles de zoom, visibilidad de elementos y más. Compatible con temas y totalmente configurable.",

    ["MMSKIN_GROUP_SHAPE"] = "Forma y apariencia",
    ["MMSKIN_GROUP_INFO"] = "Superposiciones de información",
    ["MMSKIN_GROUP_ZOOM"] = "Zoom y desplazamiento",
    ["MMSKIN_GROUP_CLICKS"] = "Acciones de clic",
    ["MMSKIN_GROUP_ELEMENTS"] = "Visibilidad de elementos",
    ["MMSKIN_GROUP_EXTRAS"] = "Extras",
    ["MMSKIN_GROUP_COMPAT"] = "Compatibilidad",

    ["MMSKIN_SQUARE"] = "Minimapa cuadrado",
    ["MMSKIN_SQUARE_DESC"] = "Cambia la forma del minimapa de redonda a cuadrada. Desactivarlo requiere recargar la interfaz.",
    ["MMSKIN_BORDER"] = "Mostrar borde",
    ["MMSKIN_BORDER_DESC"] = "Muestra un borde de color alrededor del minimapa.",
    ["MMSKIN_CLASS_BORDER"] = "Borde con color de clase",
    ["MMSKIN_CLASS_BORDER_DESC"] = "Usa el color de tu clase para el borde del minimapa en lugar del color del tema.",
    ["MMSKIN_UNLOCK"] = "Desbloquear minimapa",
    ["MMSKIN_UNLOCK_DESC"] = "Separa el minimapa de su posición predeterminada y permite moverlo libremente.",
    ["MMSKIN_LOCK_POS"] = "Bloquear posición",
    ["MMSKIN_LOCK_POS_DESC"] = "Impide que el minimapa se arrastre, manteniéndolo en su posición actual.",

    ["MMSKIN_ZONE_TEXT"] = "Texto de zona",
    ["MMSKIN_ZONE_TEXT_DESC"] = "Muestra el nombre de la zona actual sobre el minimapa con coloración de tipo JcJ.",
    ["MMSKIN_CLOCK"] = "Reloj",
    ["MMSKIN_CLOCK_DESC"] = "Muestra un reloj debajo del minimapa. La información emergente muestra la hora del reino/local y los temporizadores de reinicio diario/semanal.",
    ["MMSKIN_CLASS_CLOCK_COLOR"] = "Reloj con color de clase",
    ["MMSKIN_CLASS_CLOCK_COLOR_DESC"] = "Usa el color de tu clase para el texto del reloj en lugar del color del tema.",
    ["MMSKIN_ZONE_ALIGN_LABEL"] = "Alineación del nombre de zona",
    ["MMSKIN_CLOCK_ALIGN_LABEL"] = "Alineación del reloj",
    ["MMSKIN_ALIGN_LEFT"] = "Izquierda",
    ["MMSKIN_ALIGN_CENTER"] = "Centro",
    ["MMSKIN_ALIGN_RIGHT"] = "Derecha",

    ["MMSKIN_ZONE_CLOCK_INSIDE"] = "Zona y reloj dentro del minimapa",
    ["MMSKIN_ZONE_CLOCK_INSIDE_DESC"] = "Ancla el nombre de zona y el reloj en los bordes interiores del minimapa en lugar de encima y debajo.",

    ["MMSKIN_ZONE_CLOCK_DRAG"] = "Arrastrar zona y reloj (mantener Mayús)",
    ["MMSKIN_ZONE_CLOCK_DRAG_DESC"] = "Debes mantener pulsada la tecla Mayús mientras arrastras el nombre de zona o el reloj para moverlos por la pantalla. Las posiciones se guardan. Suelta Mayús para los clics normales (el reloj sigue abriendo el gestor de tiempo).",

    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM"] = "Anclar zona y reloj al minimapa",
    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM_DESC"] = "Mientras el arrastre está activado, ancla el nombre de zona y el reloj al minimapa para que lo acompañen cuando se mueva. Si los apilas uno sobre otro, se mueven como uno solo.",

    ["MMSKIN_WHEEL_ZOOM"] = "Zoom con la rueda del ratón",
    ["MMSKIN_WHEEL_ZOOM_DESC"] = "Acerca y aleja el minimapa con la rueda del ratón.",
    ["MMSKIN_AUTO_ZOOM"] = "Alejar automáticamente",
    ["MMSKIN_AUTO_ZOOM_DESC"] = "Aleja automáticamente el minimapa después de acercarlo.",

    ["MMSKIN_CLICK_ACTIONS"] = "Acciones de clic",
    ["MMSKIN_CLICK_ACTIONS_DESC"] = "Activa las acciones de clic derecho, clic central y botones adicionales del ratón en el minimapa.",

    ["MMSKIN_MAIL"] = "Indicador de correo",
    ["MMSKIN_MAIL_DESC"] = "Muestra el indicador de correo en el minimapa.",
    ["MMSKIN_CRAFTING"] = "Pedidos de creación",
    ["MMSKIN_CRAFTING_DESC"] = "Muestra el indicador de pedidos de creación en el minimapa.",
    ["MMSKIN_DIFFICULTY"] = "Icono de dificultad",
    ["MMSKIN_DIFFICULTY_DESC"] = "Muestra el icono de dificultad de la instancia en el minimapa.",

    ["MMSKIN_TRACKING"] = "Filtro de rastreo",
    ["MMSKIN_TRACKING_DESC"] = "Muestra el filtro de rastreo del minimapa (menú desplegable de recursos / hierbas / mineral / etc.). Desactivarlo elimina el pequeño anillo/control junto al minimapa.",
    ["MMSKIN_MISSIONS"] = "Botón de misiones",
    ["MMSKIN_MISSIONS_DESC"] = "Muestra el botón de la página de inicio de expansión / misiones.",
    ["MMSKIN_GAMETIME"] = "Icono de calendario",
    ["MMSKIN_GAMETIME_DESC"] = "Muestra el botón del calendario (GameTime) en el minimapa.",

    ["MMSKIN_PLUMBER_HIDE_BLIZZARD"] = "Ocultar el botón de expansión duplicado de Blizzard con Plumber",
    ["MMSKIN_PLUMBER_HIDE_BLIZZARD_DESC"] = "Cuando Plumber está cargado, mantiene oculto el botón de expansión del minimapa de Blizzard para que solo se muestre el control Resumen de Expansión de Plumber. Desactívalo para mostrar ambos (no recomendado).",
    ["MMSKIN_PLUMBER_STATUS_ON"] = "Plumber está cargado: esta opción se aplica.",
    ["MMSKIN_PLUMBER_STATUS_OFF"] = "Plumber no está cargado: actívalo antes de iniciar sesión, o recarga tras instalar Plumber.",

    ["MMSKIN_HIDE_ADDONS"] = "Ocultar iconos de addons",
    ["MMSKIN_HIDE_ADDONS_DESC"] = "Oculta los botones de addons del minimapa hasta que pases el cursor sobre el área del minimapa.",
    ["MMSKIN_COMBAT_FADE"] = "Atenuar en combate",
    ["MMSKIN_COMBAT_FADE_DESC"] = "Reduce la opacidad del minimapa durante el combate.",
    ["MMSKIN_PET_HIDE"] = "Ocultar en combates de mascotas",
    ["MMSKIN_PET_HIDE_DESC"] = "Oculta el minimapa durante los combates de mascotas.",

    ["MMSKIN_SCALE_LABEL"] = "Escala del conjunto del minimapa",
    ["MMSKIN_SECTION_BORDER"] = "Ajustes del borde",
    ["MMSKIN_BORDER_SIZE"] = "Tamaño del borde",
    ["MMSKIN_BORDER_RED"] = "Rojo",
    ["MMSKIN_BORDER_GREEN"] = "Verde",
    ["MMSKIN_BORDER_BLUE"] = "Azul",
    ["MMSKIN_USE_THEME_COLOR"] = "Usar color del tema",

    ["MMSKIN_ZONE_BG"] = "Fondo de zona",
    ["MMSKIN_CLOCK_BG"] = "Fondo del reloj",

    ["MMSKIN_AUTO_ZOOM_DELAY"] = "Retardo de alejado automático",
    ["MMSKIN_SHOW_ZOOM_BTNS"] = "Mostrar botones de zoom",

    ["MMSKIN_HIDE_WM_BTN"] = "Ocultar botón del mapa del mundo",
    ["MMSKIN_HIDE_WM_BTN_DESC"] = "Oculta el pequeño botón del mapa del mundo en el minimapa (aún puedes abrir el mapa con su atajo).",

    ["MMSKIN_SECTION_COMBAT"] = "Ajustes de atenuación en combate",
    ["MMSKIN_COMBAT_ALPHA"] = "Opacidad en combate",

    ["MMSKIN_SECTION_CLICKS"] = "Ajustes de asignación de clics",
    ["MMSKIN_CLICK_RIGHT"] = "Clic derecho",
    ["MMSKIN_CLICK_MIDDLE"] = "Clic central",
    ["MMSKIN_CLICK_BTN4"] = "Botón 4",
    ["MMSKIN_CLICK_BTN5"] = "Botón 5",
    ["MMSKIN_ACTION_NONE"] = "Ninguna",
    ["MMSKIN_ACTION_CALENDAR"] = "Calendario",
    ["MMSKIN_ACTION_TRACKING"] = "Rastreo",
    ["MMSKIN_ACTION_MISSIONS"] = "Misiones",
    ["MMSKIN_ACTION_MAP"] = "Mapa",
    ["MMSKIN_WORLD_MAP_BUTTON"] = "Mapa del mundo",

    ["MMSKIN_SHOW_COMPARTMENT"] = "Compartimento de addons",

    ["MMSKIN_CLOCK_TT_TOGGLE"] = "Haz clic para abrir/cerrar el gestor de tiempo",

    ["MMSKIN_UNCLAMP"] = "Desanclar del borde de la pantalla",

    ["MMSKIN_ZONE_FONT_LABEL"] = "Fuente",
    ["MMSKIN_CLOCK_FONT_LABEL"] = "Fuente",
    ["MMSKIN_FONT_GLOBAL"] = "Fuente global",
    ["MMSKIN_FONT_WOW_DEFAULT"] = "Predeterminada de WoW (pequeña)",

    ["MMSKIN_SECTION_OPACITY"] = "Escala y opacidad",
    ["MMSKIN_OPACITY"] = "Opacidad del minimapa",

    ["MMSKIN_SECTION_DEBUG"] = "Herramientas de desarrollador",
    ["MMSKIN_DEBUG_SHOW"] = "Mostrar iconos de depuración",
    ["MMSKIN_DEBUG_HIDE"] = "Ocultar iconos de depuración",
    ["MMSKIN_DEBUG_DESC"] = "Fuerza la visibilidad de todos los iconos rastreados con etiquetas de color. Arrastra cualquier etiqueta para colocar ese icono en el minimapa; las posiciones se guardan. Oculta la depuración para devolver los iconos al conjunto (salvo que el minimapa esté separado). Útil cuando los iconos no se activan de forma natural (p. ej., sin correo en tu buzón).",
    ["MMSKIN_DEBUG_TT_DRAG_HINT"] = "Clic izquierdo y arrastrar para mover este icono en el minimapa.",
    ["MMSKIN_DEBUG_TT_POS_FMT"] = "Desplazamiento guardado: %.0f, %.0f",

    ["MMSKIN_RELOAD_PROMPT"] = "Cambiar la forma del minimapa requiere recargar la interfaz.\n¿Recargar ahora?",
})
