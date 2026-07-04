local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["FRAMEMOVER_TITLE"] = "Spostatore di riquadri",
    ["FRAMEMOVER_DESC"] = "Trascina i riquadri dell'interfaccia Blizzard per riposizionarli. Usa Ctrl+Rotellina per ridimensionare. Tieni premuto Alt durante il trascinamento per spostare i riquadri parzialmente fuori dallo schermo quando «Limita allo schermo» è attivo. Posizioni e scale possono persistere tra le sessioni.",

    ["FRAMEMOVER_TOGGLE_REQUIRE_SHIFT"] = "Richiedi Maiusc per trascinare",
    ["FRAMEMOVER_TOGGLE_ENABLE_SCALING"] = "Ridimensionamento Ctrl+Rotellina",
    ["FRAMEMOVER_TOGGLE_SAVE_POSITIONS"] = "Ricorda posizioni",
    ["FRAMEMOVER_TOGGLE_SAVE_SCALES"] = "Ricorda scale",
    ["FRAMEMOVER_TOGGLE_CLAMP_SCREEN"] = "Limita allo schermo",
    ["FRAMEMOVER_TOGGLE_MODIFY_HUD"] = "Mostra popup scala",

    ["FRAMEMOVER_GROUP_BEHAVIOR"] = "Comportamento",
    ["FRAMEMOVER_GROUP_SAVING"] = "Persistenza",

    ["FRAMEMOVER_CAT_CORE"] = "Interfaccia principale",
    ["FRAMEMOVER_CAT_COLLECTIONS"] = "Collezioni e diari",
    ["FRAMEMOVER_CAT_PROFESSIONS"] = "Professioni ed economia",
    ["FRAMEMOVER_CAT_GROUP"] = "Contenuti di gruppo",
    ["FRAMEMOVER_CAT_CHARACTER"] = "Personaggio e talenti",
    ["FRAMEMOVER_CAT_SOCIAL"] = "Sociale e gilde",
    ["FRAMEMOVER_CAT_MISC"] = "Varie",
    ["FRAMEMOVER_CAT_HOUSING"] = "Alloggio",

    ["FRAMEMOVER_FRAMES_HEADER"] = "Riquadri spostabili",
    ["FRAMEMOVER_FILTER_EMPTY"] = "Nessun riquadro corrisponde alla ricerca.",
    ["FRAMEMOVER_RESET_POSITIONS"] = "Reimposta tutte le posizioni",
    ["FRAMEMOVER_RESET_SCALES"] = "Reimposta tutte le scale",
    ["FRAMEMOVER_RESET_POS_DONE"] = "Posizioni reimpostate. Riapri i riquadri per vedere i valori predefiniti.",
    ["FRAMEMOVER_RESET_SCALE_DONE"] = "Scale reimpostate. Riapri i riquadri per vedere i valori predefiniti.",
    ["FRAMEMOVER_ENABLED_TOOLTIP"] = "Clic sinistro per attivare/disattivare. Ctrl+Rotellina su un riquadro per ridimensionarlo. Tieni premuto Alt durante il trascinamento per ignorare il limite dello schermo.",
    ["FEATURES_ON"] = "Attivo",
    ["FEATURES_OFF"] = "Disattivo",
})
