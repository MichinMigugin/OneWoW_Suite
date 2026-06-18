local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["MAPWORLD_TITLE"] = "Outils de carte (monde)",
    ["MAPWORLD_DESC"] = "Carte du monde : révélez le terrain inexploré à partir des données du client, teintes optionnelles, ajustements de la carte du champ de bataille, coordonnées et petites options de confort/nettoyage.",

    ["MAPWORLD_GROUP_EXPLORE"] = "Exploration (illustration de carte)",
    ["MAPWORLD_GROUP_FOGOVERLAY"] = "Superposition de brouillard (couche sombre)",
    ["MAPWORLD_GROUP_FRAME"] = "Fenêtre de carte",
    ["MAPWORLD_GROUP_COMFORT"] = "Confort",
    ["MAPWORLD_GROUP_CLEANUP"] = "Nettoyage",
    ["MAPWORLD_GROUP_COORDS"] = "Coordonnées",
    ["MAPWORLD_GROUP_POI"] = "Points d'intérêt",
    ["MAPWORLD_GROUP_BATTLE"] = "Carte du champ de bataille",
    ["MAPWORLD_GROUP_POLISH"] = "Finitions",
    ["MAPWORLD_GROUP_CANVAS"] = "Superposition pleine carte",
    ["MAPWORLD_GROUP_MAP"] = "Fenêtre de la carte du monde",

    ["MAPWORLD_REVEAL_MAP"] = "Afficher les zones inexplorées",
    ["MAPWORLD_REVEAL_MAP_DESC"] = "Dessine les tuiles d'exploration manquantes à l'aide des données d'illustration fournies (même principe que révéler la carte papier). Fonctionne sur les cartes du monde et du champ de bataille.",

    ["MAPWORLD_TINT_UNEXPLORED"] = "Teinter les zones inexplorées",
    ["MAPWORLD_TINT_UNEXPLORED_DESC"] = "Applique une teinte de couleur aux tuiles révélées par l'option ci-dessus (cartes de zone uniquement).",

    ["MAPWORLD_UNEX_R"] = "Inexploré rouge",
    ["MAPWORLD_UNEX_G"] = "Inexploré vert",
    ["MAPWORLD_UNEX_B"] = "Inexploré bleu",
    ["MAPWORLD_UNEX_A"] = "Opacité inexploré",

    ["MAPWORLD_REMOVE_FOG"] = "Masquer la couche de brouillard sombre",
    ["MAPWORLD_REMOVE_FOG_DESC"] = "Masque le cadre du brouillard de guerre de Blizzard au-dessus de la carte (distinct du dessin de l'illustration d'exploration manquante).",

    ["MAPWORLD_FOG_TINT"] = "Teinter la couche de brouillard (BdG)",
    ["MAPWORLD_FOG_TINT_DESC"] = "Lorsque la couche de brouillard sombre est visible, multiplie sa couleur.",

    ["MAPWORLD_CLEAR_BLACKOUT"] = "Monde cliquable derrière la carte",
    ["MAPWORLD_CLEAR_BLACKOUT_DESC"] = "Rend le « masque » assombri derrière la carte transparent et non bloquant pour les clics, afin de voir clairement le monde.",

    ["MAPWORLD_NO_MAP_FADE"] = "Désactiver l'estompage de la carte en mouvement",
    ["MAPWORLD_NO_MAP_FADE_DESC"] = "Définit mapFade pour que la carte ne devienne pas semi-transparente quand votre personnage se déplace.",

    ["MAPWORLD_NO_MAP_EMOTE"] = "Désactiver l'emote de lecture",
    ["MAPWORLD_NO_MAP_EMOTE_DESC"] = "Annule l'emote de lecture à l'ouverture de la carte.",

    ["MAPWORLD_HIDE_FILTER_RESET"] = "Masquer l'UI de réinitialisation des filtres",
    ["MAPWORLD_HIDE_FILTER_RESET_DESC"] = "Masque le contrôle de réinitialisation des filtres de la carte du monde et les bannières de compteur associées.",

    ["MAPWORLD_HIDE_MAP_TUTORIAL"] = "Supprimer le tutoriel de la carte",
    ["MAPWORLD_HIDE_MAP_TUTORIAL_DESC"] = "Masque le cadre du tutoriel de la carte du monde et le marque comme fermé dans les cadres d'info.",

    ["MAPWORLD_SHOW_COORDS"] = "Afficher les coordonnées",
    ["MAPWORLD_SHOW_COORDS_DESC"] = "Affiche la position du curseur et du joueur dans la fenêtre de carte.",

    ["MAPWORLD_COORDS_LARGE"] = "Grande police des coordonnées",
    ["MAPWORLD_COORDS_LARGE_DESC"] = "Utilise une police plus grande pour l'affichage des coordonnées.",

    ["MAPWORLD_COORDS_BG"] = "Fond de la barre de coordonnées",
    ["MAPWORLD_COORDS_BG_DESC"] = "Affiche une bande sombre derrière le texte des coordonnées.",

    ["MAPWORLD_HIDE_CONTINENT_POI"] = "Masquer les points d'intérêt de ville sur les continents",
    ["MAPWORLD_HIDE_CONTINENT_POI_DESC"] = "Masque certains points de foyer, de faction et de ville sur les vues de continent et de carte du monde.",

    ["MAPWORLD_ENHANCE_BATTLE_MAP"] = "Améliorer la carte du champ de bataille",
    ["MAPWORLD_ENHANCE_BATTLE_MAP_DESC"] = "Affiche le groupe sur la carte du champ de bataille et active les options ci-dessous.",

    ["MAPWORLD_UNLOCK_BATTLEFIELD"] = "Glisser pour déplacer la carte du champ de bataille",
    ["MAPWORLD_UNLOCK_BATTLEFIELD_DESC"] = "Glissez la carte du champ de bataille par sa zone intérieure.",

    ["MAPWORLD_BATTLE_CENTER"] = "Garder la carte du champ de bataille centrée sur le joueur",
    ["MAPWORLD_BATTLE_CENTER_DESC"] = "Recentre la carte du champ de bataille sur votre position. Maintenez Maj en glissant pour mettre en pause.",

    ["MAPWORLD_BATTLE_OPACITY"] = "Visibilité de la carte du champ de bataille",
    ["MAPWORLD_BATTLE_GROUP"] = "Taille des icônes de groupe",
    ["MAPWORLD_BATTLE_PLAYER"] = "Taille de la flèche du joueur",

    ["MAPWORLD_TINT_MENU"] = "Bascule de teinte du menu de la carte du monde",
    ["MAPWORLD_TINT_MENU_DESC"] = "Ajoute une case « Teinter les inexplorées » au menu de pistage de la carte (peut ne pas se charger si l'API du menu change).",

    ["MAPWORLD_CANVAS_TINT"] = "Superposition de couleur pleine carte",
    ["MAPWORLD_CANVAS_TINT_DESC"] = "Teinte tout le canevas de la carte avec une couleur translucide (distinct de la teinte d'exploration).",

    ["MAPWORLD_MAP_ALPHA"] = "Opacité de la carte du monde",
    ["MAPWORLD_MAP_ALPHA_DESC"] = "Réduit l'opacité de toute la fenêtre de la carte du monde (alpha du cadre).",

    ["MAPWORLD_MAP_ALPHA_SLIDER"] = "Opacité de la fenêtre de carte",
    ["MAPWORLD_RED"] = "Rouge",
    ["MAPWORLD_GREEN"] = "Vert",
    ["MAPWORLD_BLUE"] = "Bleu",

    ["MAPWORLD_CURSOR"] = "Curseur",
})
