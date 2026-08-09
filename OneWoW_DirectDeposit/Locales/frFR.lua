local ADDON_NAME = ...

OneWoW.Locale:Register(ADDON_NAME, "frFR", {

    ["CTX_OPEN_DD"] = "Ouvrir Direct Deposit",
    ["ADDON_TITLE"] = "Dépôt Direct",
    ["ADDON_SUBTITLE"] = "Gestion Automatique de l'Or de la Banque de bataillon",


    ["TAB_GOLD"] = "Or",

    ["DIRECT_DEPOSIT_TITLE"] = "Dépôt Direct",
    ["DIRECT_DEPOSIT_DESCRIPTION"] = "Gérez automatiquement l'or entre votre personnage et la Banque de bataillon. Définissez un montant cible à conserver sur votre personnage, et le système déposera l'or excédentaire ou retirera lorsque vous manquez. Parfait pour gérer l'or entre plusieurs personnages.",
    ["DIRECT_DEPOSIT_ENABLE"] = "Activer le Dépôt Direct",
    ["DIRECT_DEPOSIT_ENABLE_DESC"] = "Déposer ou retirer automatiquement de l'or de votre Banque de bataillon pour maintenir un montant cible sur votre personnage lorsque vous ouvrez la banque.",

    ["ACCOUNT_SETTINGS"] = "Paramètres du Compte",
    ["ACCOUNT_SETTINGS_DESC"] = "Ces paramètres s'appliquent à tous les personnages de votre compte.",

    ["CHARACTER_SETTINGS"] = "Remplacement Spécifique au Personnage",
    ["CHARACTER_SETTINGS_DESC"] = "Remplacer les paramètres du compte avec des paramètres personnalisés pour ce personnage spécifique. Utile pour les alts bancaires ou les personnages ayant des besoins spéciaux en gestion d'or.",

    ["USE_CHAR_SETTINGS"] = "Utiliser les Paramètres Spécifiques au Personnage",
    ["USE_CHAR_SETTINGS_DESC"] = "Activez ceci pour utiliser différents paramètres pour ce personnage au lieu des paramètres du compte.",

    ["TARGET_GOLD"] = "Montant à Conserver sur le Personnage",
    ["TARGET_GOLD_DESC"] = "Entrez le montant d'or (en pièces d'or) que vous souhaitez maintenir sur votre personnage. Laissez vide pour désactiver les transferts automatiques jusqu'à saisie d'une valeur. 0 = ne garder aucun or sur le personnage.",
    ["GOLD"] = "or",

    ["DEPOSIT_ENABLE"] = "Déposer l'Or dans la Banque de bataillon",
    ["DEPOSIT_ENABLE_DESC"] = "Lorsque vous avez plus que le montant cible, déposez automatiquement l'excédent dans votre Banque de bataillon.",

    ["WITHDRAW_ENABLE"] = "Retirer l'Or de la Banque de bataillon",
    ["WITHDRAW_ENABLE_DESC"] = "Lorsque vous avez moins que le montant cible, retirez automatiquement de votre Banque de bataillon pour atteindre l'objectif.",

    ["ITEM_DEPOSIT"] = "Dépôt Automatique d'Objets",
    ["ITEM_DEPOSIT_ENABLE"] = "Activer le Dépôt Automatique d'Objets",
    ["ITEM_DEPOSIT_ENABLE_DESC"] = "Déposer automatiquement des objets spécifiques dans votre banque choisie lors de l'ouverture de la banque.",
    ["ITEM_DEPOSIT_LIST"] = "Liste d'Objets à Déposer Automatiquement",
    ["ITEM_DEPOSIT_ADD_PROMPT"] = "Entrez l'ID de l'objet ou shift+clic sur un objet pour ajouter :",
    ["ITEM_DEPOSIT_WARBAND"] = "Bataillon",
    ["ITEM_DEPOSIT_PERSONAL"] = "Personnel",

    ["CLEAR"] = "Effacer",


    ["MINIMAP_TOOLTIP_HINT"] = "Cliquez pour afficher les paramètres",

    ["ADDON_CHAT_PREFIX"] = "|cFFFFD100Direct Deposit:|r",
    ["DEPOSIT_NOW"] = "Déposer Maintenant",

    ["TAB_KEYBINDS"] = "Raccourcis",

    ["KEYBIND_SECTION"] = "Raccourcis d'Ajout Rapide",
    ["KEYBIND_DESC"] = "Survolez un objet et appuyez sur un raccourci pour l'ajouter instantanément à la liste de dépôt. Assignez les touches dans Menu du Jeu > Raccourcis Clavier > OneWoW Direct Deposit.",
    ["KEYBIND_ADD_PERSONAL"] = "Ajouter l'Objet Survolé - Banque Personnelle",
    ["KEYBIND_ADD_WARBAND"] = "Ajouter l'Objet Survolé - Banque de bataillon",
    ["KEYBIND_ADD_GUILD"] = "Ajouter l'Objet Survolé - Banque de Guilde",
    ["KEYBIND_NO_ITEM"] = "Aucun objet trouvé - survolez d'abord un objet.",

    ["WARBOUND_SECTION"] = "Dépôt Automatique de bataillon",
    ["WARBOUND_ENABLE"] = "Déposer Automatiquement Tous les Objets de bataillon",
    ["WARBOUND_ENABLE_DESC"] = "À l'ouverture de n'importe quelle banque, dépose automatiquement tous les objets liés au bataillon (liés au compte) de vos sacs dans la Banque de bataillon. Les objets déjà présents dans votre liste de dépôt ci-dessus sont exclus.",

    ["WARBOUND_EXCLUDE_KEYWORD_LABEL"] = "Conserver par Mot-Clé",
    ["WARBOUND_EXCLUDE_KEYWORD_DESC"] = "Les objets correspondant à cette expression de mot-clé sont conservés dans vos sacs et ne sont jamais déposés automatiquement. Utilisez des mots-clés comme #potion, #flask, #elixir, #consumable, séparés par | pour \"ou\". Exemple : #potion | #flask",
    ["WARBOUND_EXCLUDE_KEYWORD_PLACEHOLDER"] = "p. ex. #potion | #flask",
    ["WARBOUND_EXCLUDE_ITEMS_LABEL"] = "Conserver des Objets Spécifiques",
    ["WARBOUND_EXCLUDE_ITEMS_DESC"] = "Ces objets sont toujours conservés dans vos sacs, même s'ils sont liés au bataillon. Glissez un objet ici ou saisissez son ID d'objet.",

    ["TOOLTIP_SECTION"] = "Superposition d'Infobulle",
    ["TOOLTIP_ENABLE"] = "Afficher l'État de Dépôt dans les Infobulles",
    ["TOOLTIP_ENABLE_DESC"] = "Les objets en attente de dépôt affichent leur banque de destination en bas de leur infobulle.",
    ["TOOLTIP_LABEL"] = "Dépôt en cours :",
    ["TOOLTIP_PERSONAL"] = "Personnel",
    ["TOOLTIP_WARBAND"] = "Bataillon",

    ["BINDING_HEADER_ONEWOW_DIRECTDEPOSIT"] = "|cFF00FF00OneWoW|r Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_TOGGLE"] = "Afficher/Masquer la Fenêtre Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_DEPOSIT"] = "Déposer les Objets Maintenant",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_PERSONAL"] = "Ajout Rapide : Banque Personnelle",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_WARBAND"] = "Ajout Rapide : Banque de bataillon",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_GUILD"] = "Ajout Rapide : Banque de Guilde",
})
