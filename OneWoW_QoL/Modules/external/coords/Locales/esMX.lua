local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["COORDS_TITLE"] = "Visor de coordenadas",
    ["COORDS_DESC"] = "Muestra tus coordenadas de mapa actuales en un pequeño marco movible cerca del minimapa. Clic derecho para copiar las coordenadas.",
    ["COORDS_TOGGLE_MAPID"] = "Mostrar ID de mapa",
    ["COORDS_TOGGLE_MAPID_DESC"] = "Muestra el ID numérico del mapa junto a tus coordenadas.",
    ["COORDS_TOGGLE_ZONE"] = "Mostrar nombre de zona",
    ["COORDS_TOGGLE_ZONE_DESC"] = "Muestra el nombre de la zona actual debajo de las coordenadas.",
    ["COORDS_TOGGLE_SUBZONE"] = "Mostrar subzona",
    ["COORDS_TOGGLE_SUBZONE_DESC"] = "Muestra la subzona o el nombre del área actual.",
    ["COORDS_TOGGLE_FACING"] = "Mostrar orientación",
    ["COORDS_TOGGLE_FACING_DESC"] = "Muestra tu rumbo actual en grados y dirección de brújula.",
    ["COORDS_TOGGLE_SPEED"] = "Mostrar velocidad",
    ["COORDS_TOGGLE_SPEED_DESC"] = "Muestra tu velocidad de movimiento actual en metros por segundo.",
    ["COORDS_TOGGLE_HIDE_INSTANCE"] = "Ocultar en instancias",
    ["COORDS_TOGGLE_HIDE_INSTANCE_DESC"] = "Oculta automáticamente el visor de coordenadas cuando estás dentro de una mazmorra, banda u otra instancia.",
    ["COORDS_MAP"] = "Mapa: %d",
    ["COORDS_COPIED"] = "Coordenadas copiadas: %s",
    ["COORDS_COPY_TITLE"] = "Coordenadas",
})
