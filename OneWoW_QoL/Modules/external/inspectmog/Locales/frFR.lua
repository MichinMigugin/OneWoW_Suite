local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["INSPECTMOG_TITLE"] = "Inspecter l'équipement",
    ["INSPECTMOG_DESC"] = "Ajoute un panneau latéral à la fenêtre d'inspection répertoriant l'équipement porté par le joueur que vous inspectez. Enregistrez toute la liste dans une note de joueur OneWoW Notes, ou Maj-cliquez un objet pour l'ajouter à vos notes d'objets.",

    ["INSPECTMOG_ADD_NOTE"] = "Ajouter à la note du joueur",
    ["INSPECTMOG_ADD_ALL"] = "Tout ajouter",
    ["INSPECTMOG_EMPTY"] = "Aucun équipement inspectable pour l'instant.",
    ["INSPECTMOG_PANEL_TITLE"] = "Outil d'inspection de transmog",
    ["INSPECTMOG_NO_DATA"] = "Aucune donnée d'inspection disponible.",
    ["INSPECTMOG_UNKNOWN_PLAYER"] = "Joueur inspecté",
    ["INSPECTMOG_NATIVE_APPEARANCE"] = "Apparence d'origine",
    ["INSPECTMOG_SOURCE_FORMAT"] = "Source #%d",
    ["INSPECTMOG_APPEARANCE_SOURCE_FORMAT"] = "Source d'apparence : %d",

    ["INSPECTMOG_TT_PREVIEW"] = "Ctrl-clic pour prévisualiser dans la cabine d'essayage",
    ["INSPECTMOG_TT_NOTES"] = "Maj-clic pour ajouter à Notes > Objets",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED"] = "Maj-clic pour ajouter l'objet équipé à Notes > Objets",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED_COLL"] = "Maj-clic pour ajouter l'apparence de cet objet à Notes > Objets de collection",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE"] = "Maj-clic pour ajouter l'apparence de transmog à Notes > Objets",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE_COLL"] = "Maj-clic pour ajouter l'apparence de transmog à Notes > Objets de collection",
    ["INSPECTMOG_ROUTE_COLLECTIBLES"] = "Ajouter les apparences aux Objets de collection",
    ["INSPECTMOG_TT_PREVIEW_EQUIPPED"] = "Ctrl-clic pour prévisualiser l'objet équipé",
    ["INSPECTMOG_TT_PREVIEW_APPEARANCE"] = "Ctrl-clic pour prévisualiser l'apparence de transmog",
    ["INSPECTMOG_TT_HIDDEN_APPEARANCE"] = "Les apparences masquées ne sont pas ajoutées aux notes d'objets",
    ["INSPECTMOG_TT_ADD_ALL_TITLE"] = "Ajouter tout le transmog",
    ["INSPECTMOG_TT_ADD_ALL_DESC"] = "Ajoute tous les objets d'apparence de transmog visibles à Notes > Objets.",

    ["INSPECTMOG_TT_ADD_NOTE_TITLE"] = "Enregistrer l'équipement dans la note du joueur",
    ["INSPECTMOG_TT_ADD_NOTE_DESC"] = "Écrit chaque emplacement et objet répertorié dans la note de ce joueur dans OneWoW Notes. Réenregistrer met à jour le bloc d'équipement et conserve le reste de la note.",

    ["INSPECTMOG_NOTE_HEADER"] = "[OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_FOOTER"] = "[/OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_UPDATED"] = "Inspecté : %s",
    ["INSPECTMOG_NOTE_LINE"] = "%s - %s",

    ["INSPECTMOG_ITEM_STAMP"] = "TMOG inspecté le %s - %s",

    ["INSPECTMOG_STATUS_NOTE_SAVED"] = "Équipement enregistré dans la note de %s.",
    ["INSPECTMOG_STATUS_NOTE_UPDATED"] = "Équipement mis à jour dans la note de %s.",
    ["INSPECTMOG_STATUS_ITEM_ADDED"] = "%s ajouté aux notes d'objets.",
    ["INSPECTMOG_STATUS_NOTES_MISSING"] = "OneWoW Notes n'est pas installé.",
    ["INSPECTMOG_STATUS_NO_DATA"] = "Aucune donnée d'équipement disponible pour l'instant.",
})
