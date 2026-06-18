local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["MAPWORLD_TITLE"] = "Herramientas de mapa (mundo)",
    ["MAPWORLD_DESC"] = "Mapa del mundo: revela el terreno inexplorado desde los datos del cliente, tintes opcionales, ajustes del mapa de campo de batalla, coordenadas y pequeñas opciones de comodidad/limpieza.",

    ["MAPWORLD_GROUP_EXPLORE"] = "Exploración (arte del mapa)",
    ["MAPWORLD_GROUP_FOGOVERLAY"] = "Superposición de niebla (capa oscura)",
    ["MAPWORLD_GROUP_FRAME"] = "Ventana del mapa",
    ["MAPWORLD_GROUP_COMFORT"] = "Comodidad",
    ["MAPWORLD_GROUP_CLEANUP"] = "Limpieza",
    ["MAPWORLD_GROUP_COORDS"] = "Coordenadas",
    ["MAPWORLD_GROUP_POI"] = "Puntos de interés",
    ["MAPWORLD_GROUP_BATTLE"] = "Mapa del campo de batalla",
    ["MAPWORLD_GROUP_POLISH"] = "Acabado",
    ["MAPWORLD_GROUP_CANVAS"] = "Superposición de mapa completo",
    ["MAPWORLD_GROUP_MAP"] = "Ventana del mapa del mundo",

    ["MAPWORLD_REVEAL_MAP"] = "Mostrar áreas inexploradas",
    ["MAPWORLD_REVEAL_MAP_DESC"] = "Dibuja las casillas de exploración que faltan usando los datos de arte de mapa incluidos (la misma idea que revelar el mapa en papel). Funciona en mapas del mundo y de campo de batalla.",

    ["MAPWORLD_TINT_UNEXPLORED"] = "Tintar áreas inexploradas",
    ["MAPWORLD_TINT_UNEXPLORED_DESC"] = "Aplica un tinte de color a las casillas reveladas por la opción anterior (solo mapas de zona).",

    ["MAPWORLD_UNEX_R"] = "Inexplorado rojo",
    ["MAPWORLD_UNEX_G"] = "Inexplorado verde",
    ["MAPWORLD_UNEX_B"] = "Inexplorado azul",
    ["MAPWORLD_UNEX_A"] = "Opacidad inexplorado",

    ["MAPWORLD_REMOVE_FOG"] = "Ocultar capa de niebla oscura",
    ["MAPWORLD_REMOVE_FOG_DESC"] = "Oculta el marco de niebla de guerra de Blizzard sobre el mapa (independiente de dibujar el arte de exploración que falta).",

    ["MAPWORLD_FOG_TINT"] = "Tintar capa de niebla (NdG)",
    ["MAPWORLD_FOG_TINT_DESC"] = "Cuando la capa de niebla oscura es visible, multiplica su color.",

    ["MAPWORLD_CLEAR_BLACKOUT"] = "Mundo clicable detrás del mapa",
    ["MAPWORLD_CLEAR_BLACKOUT_DESC"] = "Hace que el «oscurecimiento» atenuado detrás del mapa sea transparente y no bloquee los clics, para que veas el mundo con claridad.",

    ["MAPWORLD_NO_MAP_FADE"] = "Desactivar atenuación del mapa al moverse",
    ["MAPWORLD_NO_MAP_FADE_DESC"] = "Establece mapFade para que el mapa no se vuelva semitransparente cuando tu personaje se mueve.",

    ["MAPWORLD_NO_MAP_EMOTE"] = "Desactivar gesto de lectura",
    ["MAPWORLD_NO_MAP_EMOTE_DESC"] = "Cancela el gesto de lectura al abrir el mapa.",

    ["MAPWORLD_HIDE_FILTER_RESET"] = "Ocultar IU de reinicio de filtros",
    ["MAPWORLD_HIDE_FILTER_RESET_DESC"] = "Oculta el control de reinicio de filtros del mapa del mundo y los carteles de contador relacionados.",

    ["MAPWORLD_HIDE_MAP_TUTORIAL"] = "Suprimir tutorial del mapa",
    ["MAPWORLD_HIDE_MAP_TUTORIAL_DESC"] = "Oculta el marco del tutorial del mapa del mundo y lo marca como cerrado en los marcos de información.",

    ["MAPWORLD_SHOW_COORDS"] = "Mostrar coordenadas",
    ["MAPWORLD_SHOW_COORDS_DESC"] = "Muestra la posición del cursor y del jugador en la ventana del mapa.",

    ["MAPWORLD_COORDS_LARGE"] = "Fuente de coordenadas grande",
    ["MAPWORLD_COORDS_LARGE_DESC"] = "Usa una fuente más grande para la lectura de coordenadas.",

    ["MAPWORLD_COORDS_BG"] = "Fondo de la barra de coordenadas",
    ["MAPWORLD_COORDS_BG_DESC"] = "Muestra una franja oscura detrás del texto de coordenadas.",

    ["MAPWORLD_HIDE_CONTINENT_POI"] = "Ocultar puntos de interés de ciudad en continentes",
    ["MAPWORLD_HIDE_CONTINENT_POI_DESC"] = "Oculta determinados marcadores de hogar, facción y ciudad en las vistas de continente y mapa del mundo.",

    ["MAPWORLD_ENHANCE_BATTLE_MAP"] = "Mejorar mapa del campo de batalla",
    ["MAPWORLD_ENHANCE_BATTLE_MAP_DESC"] = "Muestra el grupo en el mapa del campo de batalla y activa las opciones de abajo.",

    ["MAPWORLD_UNLOCK_BATTLEFIELD"] = "Arrastrar para mover el mapa del campo de batalla",
    ["MAPWORLD_UNLOCK_BATTLEFIELD_DESC"] = "Arrastra el mapa del campo de batalla por su área interior.",

    ["MAPWORLD_BATTLE_CENTER"] = "Mantener el mapa del campo de batalla centrado en el jugador",
    ["MAPWORLD_BATTLE_CENTER_DESC"] = "Vuelve a centrar el mapa del campo de batalla en tu posición. Mantén Mayús mientras arrastras para pausar.",

    ["MAPWORLD_BATTLE_OPACITY"] = "Visibilidad del mapa del campo de batalla",
    ["MAPWORLD_BATTLE_GROUP"] = "Tamaño de los iconos de grupo",
    ["MAPWORLD_BATTLE_PLAYER"] = "Tamaño de la flecha del jugador",

    ["MAPWORLD_TINT_MENU"] = "Interruptor de tinte del menú del mapa del mundo",
    ["MAPWORLD_TINT_MENU_DESC"] = "Añade una casilla «Tintar inexploradas» al menú de rastreo del mapa (puede no cargarse si cambia la API del menú).",

    ["MAPWORLD_CANVAS_TINT"] = "Superposición de color de mapa completo",
    ["MAPWORLD_CANVAS_TINT_DESC"] = "Tinta todo el lienzo del mapa con un color translúcido (independiente del tinte de exploración).",

    ["MAPWORLD_MAP_ALPHA"] = "Opacidad del mapa del mundo",
    ["MAPWORLD_MAP_ALPHA_DESC"] = "Reduce la opacidad de toda la ventana del mapa del mundo (alfa del marco).",

    ["MAPWORLD_MAP_ALPHA_SLIDER"] = "Opacidad de la ventana del mapa",
    ["MAPWORLD_RED"] = "Rojo",
    ["MAPWORLD_GREEN"] = "Verde",
    ["MAPWORLD_BLUE"] = "Azul",

    ["MAPWORLD_CURSOR"] = "Cursor",
})
