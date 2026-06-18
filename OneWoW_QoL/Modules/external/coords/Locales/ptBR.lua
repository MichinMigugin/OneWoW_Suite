local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["COORDS_TITLE"] = "Visor de coordenadas",
    ["COORDS_DESC"] = "Exibe suas coordenadas de mapa atuais em um pequeno quadro movível perto do minimapa. Clique direito para copiar as coordenadas.",
    ["COORDS_TOGGLE_MAPID"] = "Mostrar ID do mapa",
    ["COORDS_TOGGLE_MAPID_DESC"] = "Exibe o ID numérico do mapa ao lado das suas coordenadas.",
    ["COORDS_TOGGLE_ZONE"] = "Mostrar nome da zona",
    ["COORDS_TOGGLE_ZONE_DESC"] = "Exibe o nome da zona atual abaixo das coordenadas.",
    ["COORDS_TOGGLE_SUBZONE"] = "Mostrar subzona",
    ["COORDS_TOGGLE_SUBZONE_DESC"] = "Exibe a subzona ou o nome da área atual.",
    ["COORDS_TOGGLE_FACING"] = "Mostrar direção",
    ["COORDS_TOGGLE_FACING_DESC"] = "Exibe sua direção atual em graus e direção da bússola.",
    ["COORDS_TOGGLE_SPEED"] = "Mostrar velocidade",
    ["COORDS_TOGGLE_SPEED_DESC"] = "Exibe sua velocidade de movimento atual em metros por segundo.",
    ["COORDS_TOGGLE_HIDE_INSTANCE"] = "Ocultar em instâncias",
    ["COORDS_TOGGLE_HIDE_INSTANCE_DESC"] = "Oculta automaticamente o visor de coordenadas quando você está dentro de uma masmorra, raide ou outra instância.",
    ["COORDS_MAP"] = "Mapa: %d",
    ["COORDS_COPIED"] = "Coordenadas copiadas: %s",
    ["COORDS_COPY_TITLE"] = "Coordenadas",
})
