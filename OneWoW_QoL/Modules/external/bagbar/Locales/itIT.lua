local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["BAGBAR_TITLE"] = "Barra delle borse",
    ["BAGBAR_DESC"] = "Mostra gli oggetti utilizzabili delle borse su una barra spostabile. Gli oggetti vengono scelti con un'espressione di parole chiave (come la ricerca nelle borse). L'equipaggiamento indossabile e gli oggetti missione sono sempre esclusi dalla barra (applicato automaticamente, non mostrato nell'editor).",
    ["BAGBAR_LOCK_POSITION"] = "Blocca posizione",
    ["BAGBAR_MAX_BUTTONS"] = "Pulsanti massimi",
    ["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"] = "Maiusc+clic destro per saltare questa sessione",
    ["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"] = "Alt+clic destro per inserire definitivamente nella lista nera",
    ["BAGBAR_MANUAL_ITEMS_HEADER"] = "Oggetti manuali",
    ["BAGBAR_MANUAL_DESC"] = "Fissa oggetti specifici per dare loro priorità più alta nella barra. Devono comunque corrispondere al tuo filtro a espressione e alle regole di utilizzabilità della barra.",
    ["BAGBAR_MACROS_HEADER"] = "Macro manuali",
    ["BAGBAR_MACROS_DESC"] = "Aggiungi le tue macro alla barra come pulsanti personalizzati. Trascina una macro dalla finestra delle macro nell'area di rilascio, oppure digita un nome di macro e clicca su Aggiungi. Le macro appaiono prima degli oggetti delle borse.",
    ["BAGBAR_MACRO_NAME_LABEL"] = "Nome macro:",
    ["BAGBAR_DRAG_MACRO_HERE"] = "Trascina qui la macro",
    ["BAGBAR_MACRO_LEFT_CLICK_TO_RUN"] = "Clic sinistro per eseguire la macro",
    ["BAGBAR_MACRO_MISSING"] = "(mancante)",
    ["BAGBAR_BLACKLIST_DESC"] = "Maiusc+clic destro sugli oggetti nella barra per saltarli in questa sessione. Alt+clic destro per inserirli definitivamente nella lista nera.",
    ["BAGBAR_COLUMNS"] = "Colonne",
    ["BAGBAR_CONTEXT_LOCK"] = "Blocca posizione",
    ["BAGBAR_GROW_RIGHT"] = "Destra",
    ["BAGBAR_GROW_LEFT"] = "Sinistra",
    ["BAGBAR_EXPRESSION_FILTER_HEADER"] = "Filtro a espressione",
    ["BAGBAR_EXPRESSION_FILTER_DESC"] = "Espressione di parole chiave che determina quali oggetti delle borse appaiono (stesse parole chiave della ricerca nelle borse). Clicca su ? per l'aiuto. L'equipaggiamento indossabile e gli oggetti missione vengono esclusi automaticamente da questa espressione.",
    ["BAGBAR_EXPRESSION_FILTER_PLACEHOLDER"] = "es. #usable & #mount",
})
