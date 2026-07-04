local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["FRAMEMOVER_TITLE"] = "Movedor de quadros",
    ["FRAMEMOVER_DESC"] = "Arraste os quadros da interface da Blizzard para reposicioná-los. Use Ctrl+Rolagem para dimensionar. Segure Alt ao arrastar para mover os quadros parcialmente para fora da tela quando «Confinar à tela» estiver ativado. Posições e escalas podem persistir entre sessões.",

    ["FRAMEMOVER_TOGGLE_REQUIRE_SHIFT"] = "Exigir Shift para arrastar",
    ["FRAMEMOVER_TOGGLE_ENABLE_SCALING"] = "Dimensionamento com Ctrl+Rolagem",
    ["FRAMEMOVER_TOGGLE_SAVE_POSITIONS"] = "Lembrar posições",
    ["FRAMEMOVER_TOGGLE_SAVE_SCALES"] = "Lembrar escalas",
    ["FRAMEMOVER_TOGGLE_CLAMP_SCREEN"] = "Confinar à tela",
    ["FRAMEMOVER_TOGGLE_MODIFY_HUD"] = "Mostrar popup de escala",

    ["FRAMEMOVER_GROUP_BEHAVIOR"] = "Comportamento",
    ["FRAMEMOVER_GROUP_SAVING"] = "Persistência",

    ["FRAMEMOVER_CAT_CORE"] = "Interface principal",
    ["FRAMEMOVER_CAT_COLLECTIONS"] = "Coleções e diários",
    ["FRAMEMOVER_CAT_PROFESSIONS"] = "Profissões e economia",
    ["FRAMEMOVER_CAT_GROUP"] = "Conteúdo de grupo",
    ["FRAMEMOVER_CAT_CHARACTER"] = "Personagem e talentos",
    ["FRAMEMOVER_CAT_SOCIAL"] = "Social e guildas",
    ["FRAMEMOVER_CAT_MISC"] = "Diversos",
    ["FRAMEMOVER_CAT_HOUSING"] = "Moradia",

    ["FRAMEMOVER_FRAMES_HEADER"] = "Quadros movíveis",
    ["FRAMEMOVER_FILTER_EMPTY"] = "Nenhum quadro corresponde à sua busca.",
    ["FRAMEMOVER_RESET_POSITIONS"] = "Redefinir todas as posições",
    ["FRAMEMOVER_RESET_SCALES"] = "Redefinir todas as escalas",
    ["FRAMEMOVER_RESET_POS_DONE"] = "Posições redefinidas. Reabra os quadros para ver os padrões.",
    ["FRAMEMOVER_RESET_SCALE_DONE"] = "Escalas redefinidas. Reabra os quadros para ver os padrões.",
    ["FRAMEMOVER_ENABLED_TOOLTIP"] = "Clique esquerdo para alternar. Ctrl+Rolagem sobre um quadro para dimensioná-lo. Segure Alt ao arrastar para ignorar o confinamento.",
    ["FEATURES_ON"] = "Ativado",
    ["FEATURES_OFF"] = "Desativado",
})
