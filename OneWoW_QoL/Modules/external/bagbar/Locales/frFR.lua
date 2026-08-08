local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["BAGBAR_TITLE"] = "Barre de sac",
    ["BAGBAR_DESC"] = "Affiche les objets de sac utilisables sur une barre déplaçable. Les objets sont choisis avec une expression de mots-clés (comme la recherche de sac). L'équipement équipable et les objets de quête sont toujours exclus de la barre (appliqué automatiquement, non affiché dans l'éditeur).",
    ["BAGBAR_LOCK_POSITION"] = "Verrouiller la position",
    ["BAGBAR_MAX_BUTTONS"] = "Boutons maximum",
    ["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"] = "Maj+clic droit pour ignorer cette session",
    ["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"] = "Alt+clic droit pour mettre sur liste noire définitivement",
    ["BAGBAR_MANUAL_ITEMS_HEADER"] = "Objets manuels",
    ["BAGBAR_MANUAL_DESC"] = "Épinglez des objets spécifiques pour leur donner une priorité plus élevée dans la barre. Ils doivent toujours correspondre à votre filtre d'expression et aux règles d'utilisabilité de la barre.",
    ["BAGBAR_MACROS_HEADER"] = "Macros manuelles",
    ["BAGBAR_MACROS_DESC"] = "Ajoutez vos macros à la barre comme boutons personnalisés. Glissez une macro depuis la fenêtre des macros sur la zone de dépôt, ou tapez un nom de macro et cliquez sur Ajouter. Les macros apparaissent avant les objets de sac.",
    ["BAGBAR_MACRO_NAME_LABEL"] = "Nom de la macro :",
    ["BAGBAR_DRAG_MACRO_HERE"] = "Glissez la macro ici",
    ["BAGBAR_MACRO_LEFT_CLICK_TO_RUN"] = "Clic gauche pour exécuter la macro",
    ["BAGBAR_MACRO_MISSING"] = "(manquante)",
    ["BAGBAR_BLACKLIST_DESC"] = "Maj+clic droit sur les objets de la barre pour les ignorer cette session. Alt+clic droit pour les mettre sur liste noire définitivement.",
    ["BAGBAR_COLUMNS"] = "Colonnes",
    ["BAGBAR_CONTEXT_LOCK"] = "Verrouiller la position",
    ["BAGBAR_GROW_RIGHT"] = "Droite",
    ["BAGBAR_GROW_LEFT"] = "Gauche",
    ["BAGBAR_EXPRESSION_FILTER_HEADER"] = "Filtre d'expression",
    ["BAGBAR_EXPRESSION_FILTER_DESC"] = "Expression de mots-clés déterminant quels objets de sac apparaissent (mêmes mots-clés que la recherche de sac). Cliquez sur ? pour l'aide. L'équipement équipable et les objets de quête sont exclus automatiquement de cette expression.",
    ["BAGBAR_EXPRESSION_FILTER_PLACEHOLDER"] = "p. ex. #usable & #mount",
})
