local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — pending native review
OneWoW.Locale:Register(ADDON_NAME, "frFR", {

    ["ADDON_TITLE"] = "OneWoW - QoL",
    ["ADDON_TITLE_SHORT"] = "QoL",
    ["ADDON_TITLE_FRAME"] = "OneWoW - QoL",
    ["ADDON_LOADED"] = "chargé.",

    ["TAB_FEATURES"] = "Fonctionnalités QoL",
    ["TAB_TOGGLES"] = "Options",

    ["FEATURES_LIST_TITLE"] = "Fonctionnalités",
    ["FEATURES_FAVORITE_TT_TITLE"] = "Favori",
    ["FEATURES_FAVORITE_TT_DESC"] = "Épingle cette fonctionnalité dans la section Favoris en haut. Cliquez à nouveau pour la retirer des Favoris.",
    ["FEATURES_DETAIL_TITLE"] = "Détails",
    ["FEATURES_EMPTY"] = "Aucun module chargé.",
    ["FEATURES_NO_SELECTION"] = "Sélectionnez une fonctionnalité dans la liste.",
    ["FEATURES_ENABLED"] = "Activé",
    ["FEATURES_DISABLED"] = "Désactivé",
    ["FEATURES_CATEGORY_LABEL"] = "Catégorie :",
    ["FEATURES_VERSION_LABEL"] = "Version :",
    ["FEATURES_AUTHOR_LABEL"] = "Auteur :",
    ["FEATURES_CONTACT_LABEL"] = "Contact :",
    ["FEATURES_LINK_LABEL"] = "Lien :",
    ["FEATURES_DETAILS_BTN"] = "Détails",
    ["FEATURES_DETAILS_TITLE"] = "Détails du module",
    ["FEATURES_TOGGLES_HEADER"] = "Options du module",
    ["FEATURES_ON"] = "Activé",
    ["FEATURES_OFF"] = "Désactivé",
    ["FEATURES_PREVIEW_LABEL"] = "Aperçu :",

    ["CATEGORY_AUTOMATION"] = "Automatisation",
    ["CATEGORY_INTERFACE"] = "Interface",
    ["CATEGORY_SOCIAL"] = "Social",
    ["CATEGORY_COMBAT"] = "Combat",
    ["CATEGORY_ECONOMY"] = "Économie",
    ["CATEGORY_UTILITY"] = "Utilitaire",

    ["TOGGLES_LIST_TITLE"] = "Indicateurs de jeu",
    ["TOGGLES_FAVORITE_TT_TITLE"] = "Favori",
    ["TOGGLES_FAVORITE_TT_DESC"] = "Épingle cette option dans la section Favoris en haut. Cliquez à nouveau pour la retirer des Favoris.",
    ["TOGGLES_DETAIL_TITLE"] = "Détails de l'indicateur",
    ["TOGGLES_COMING_SOON"] = "Les indicateurs de jeu seront ajoutés dans une future mise à jour.",
    ["TOGGLES_NO_SELECTION"] = "Sélectionnez un indicateur dans la liste.",

    ["SETTINGS_THEME_HEADER"] = "Thème de couleurs",
    ["SETTINGS_THEME_DESC"] = "Choisissez un thème de couleurs. Les changements s'appliquent instantanément.",
    ["SETTINGS_LANGUAGE_DESC"] = "Choisissez votre langue préférée. Les changements s'appliquent instantanément.",
    ["SETTINGS_DEVELOPER_HEADER"] = "Informations pour développeurs",
    ["SETTINGS_DEVELOPER_DESC"] = "Cet addon prend en charge des modules externes. Ajoutez des fonctionnalités QoL en créant un dossier de module dans Modules\\external\\. Utilisez le bouton Aide aux développeurs pour la documentation complète.",
    ["SETTINGS_DEV_HELP_BTN"] = "Aide aux développeurs",

    ["DEVHELP_TITLE"] = "Guide du développeur de modules",
    ["DEVHELP_BODY"] = [[SYSTÈME DE MODULES PRÊTS À L'EMPLOI

Créez votre dossier :
  Modules\external\yourmodule\

Fichiers (module.lua se charge EN PREMIER) :
  module.lua      - Métadonnées + enregistrement
  yourmodule.lua  - Logique du module
  Locales\enUS.lua  (koKR.lua optionnel)

Dans module.lua, définissez votre module
(l'id n'existe QU'ici) :
  local ADDON_NAME, ns = ...
  ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "yourmodule",
    title       = "MY_TITLE",
    category    = "AUTOMATION",
    description = "MY_DESC",
    version     = "1.0",
    author      = "Votre nom",
    contact     = "votre@email.com",
    link        = "https://votresite.com",
    toggles = {
      { id = "myToggle", label = "MY_TOGGLE_LABEL",
        description = "MY_TOGGLE_DESC", default = true },
    },
    defaultEnabled = true,
  })

Dans yourmodule.lua, récupérez-le + votre
vue de locale (capturée au chargement, jamais à l'exécution) :
  local _, ns = ...
  local M, L = ns.ModuleRegistry:Current()
  if not M then return end

  function M:OnEnable() end
  function M:OnDisable() end
  function M:OnToggle(id, val) end

Dans Locales\enUS.lua :
  local _, ns = ...
  local M = ns.ModuleRegistry:Current()
  OneWoW.Locale:Register(M._scope, "enUS", {
    ["MY_TITLE"] = "My Title",
    ["MY_DESC"]  = "What it does",
  })

Le scope est ADDON_NAME .. "." .. id, par ex.
OneWoW_QoL.yourmodule (dérivé, aucune
chaîne de scope codée en dur).

Référencez un autre module par son id :
  ns.ModuleRegistry:GetById("othermodule")
N'utilisez jamais ns.<X>Module.

Les valeurs title, description, ainsi que le
label et la description des options sont des
clés de locale. author, contact et link sont
optionnels. contact et link s'affichent dans
des cases copiables de la fenêtre Détails du module.

Catégories disponibles :
  AUTOMATION  INTERFACE  SOCIAL
  COMBAT      ECONOMY    UTILITY

Ajoutez vos fichiers au TOC sous EXTERNAL
MODULES. Ordre : module.lua EN PREMIER, puis
les Locales, puis vos fichiers de code.

Espace de base de données SavedVariables :
  OneWoW_QoL_DB.modules.yourmodule

Voir Modules\external\autodelete\ pour un
exemple complet et fonctionnel.]],

    ["MINIMAP_TOOLTIP_TITLE"] = "OneWoW - QoL",
    ["MINIMAP_TOOLTIP_HINT"] = "Cliquez pour ouvrir",
    ["MINIMAP_RIGHT_CLICK"] = "Clic droit pour les options",
    ["MINIMAP_OPEN"] = "Ouvrir QoL",

    ["LANG_ENGLISH"] = "Anglais",
    ["LANG_KOREAN"] = "Coréen",


    ["SEARCH_HINT"] = "Filtrer...",
    ["TOGGLES_STATUS_ALL"] = "%d CVars affichées",
    ["TOGGLES_STATUS_FILTERED"] = "%d sur %d affichées",
    ["FEATURES_STATUS_ENABLED"] = "%d sur %d activés",

    ["TOGGLES_CVAR_LABEL"] = "CVar :",
    ["TOGGLES_ON"] = "Activé",
    ["TOGGLES_OFF"] = "Désactivé",
    ["TOGGLES_VALUE_LABEL"] = "Valeur :",

    ["TOGGLE_CAT_GAMEPLAY"] = "Jeu",
    ["TOGGLE_CAT_INTERFACE"] = "Interface",
    ["TOGGLE_CAT_NAMEPLATES"] = "Barres d'unité",
    ["TOGGLE_CAT_COMBAT_TEXT"] = "Texte de combat",
    ["TOGGLE_CAT_CAMERA"] = "Caméra",
    ["TOGGLE_CAT_CHAT"] = "Discussion et social",
    ["TOGGLE_CAT_AUDIO"] = "Audio",
    ["TOGGLE_CAT_GRAPHICS"] = "Graphismes",
    ["TOGGLE_CAT_NETWORK"] = "Réseau",

    ["TOGGLE_NAME_autoLootDefault"] = "Ramassage automatique",
    ["TOGGLE_NAME_autoSelfCast"] = "Lancement automatique sur soi",
    ["TOGGLE_NAME_autoDismount"] = "Descente de monture automatique",
    ["TOGGLE_NAME_autoDismountFlying"] = "Descente de monture en vol",
    ["TOGGLE_NAME_autoStand"] = "Se lever automatiquement",
    ["TOGGLE_NAME_autoUnshift"] = "Quitter la forme automatiquement",
    ["TOGGLE_NAME_assistAttack"] = "Attaque assistée",
    ["TOGGLE_NAME_ActionButtonUseKeyDown"] = "Boutons d'action à l'appui",
    ["TOGGLE_NAME_deselectOnClick"] = "Désélectionner la cible au clic",
    ["TOGGLE_NAME_stopAutoAttackOnTargetChange"] = "Arrêter l'attaque auto au changement de cible",
    ["TOGGLE_NAME_lootUnderMouse"] = "Fenêtre de butin sous la souris",
    ["TOGGLE_NAME_lootLeftmostBag"] = "Butin dans le sac le plus à gauche",
    ["TOGGLE_NAME_interactOnLeftClick"] = "Interaction au clic gauche",
    ["TOGGLE_NAME_autointeract"] = "Interaction automatique",
    ["TOGGLE_NAME_autoClearAFK"] = "Annuler l'absence automatiquement",

    ["TOGGLE_NAME_countdownForCooldowns"] = "Compte à rebours des recharges",
    ["TOGGLE_NAME_displaySpellActivationOverlays"] = "Halo de proc de sort",
    ["TOGGLE_NAME_alwaysShowActionBars"] = "Toujours afficher les barres d'action",
    ["TOGGLE_NAME_lockActionBars"] = "Verrouiller les barres d'action",
    ["TOGGLE_NAME_bottomLeftActionBar"] = "Barre d'action inférieure gauche",
    ["TOGGLE_NAME_bottomRightActionBar"] = "Barre d'action inférieure droite",
    ["TOGGLE_NAME_rightActionBar"] = "Barre d'action de droite",
    ["TOGGLE_NAME_rightTwoActionBar"] = "Barre d'action de droite 2",
    ["TOGGLE_NAME_displayFreeBagSlots"] = "Afficher les emplacements de sac libres",
    ["TOGGLE_NAME_buffDurations"] = "Afficher la durée des améliorations",
    ["TOGGLE_NAME_showTargetOfTarget"] = "Afficher la cible de la cible",
    ["TOGGLE_NAME_showTargetCastbar"] = "Afficher la barre d'incantation de la cible",
    ["TOGGLE_NAME_fullSizeFocusFrame"] = "Cadre de focalisation en pleine taille",
    ["TOGGLE_NAME_breakUpLargeNumbers"] = "Formater les grands nombres",
    ["TOGGLE_NAME_alwaysCompareItems"] = "Toujours comparer les objets",
    ["TOGGLE_NAME_missingTransmogSourceInItemTooltips"] = "Source de transmogrification manquante",
    ["TOGGLE_NAME_autoQuestWatch"] = "Suivi automatique des quêtes",
    ["TOGGLE_NAME_autoQuestProgress"] = "Fenêtres de progression des quêtes",
    ["TOGGLE_NAME_mapFade"] = "La carte s'estompe en mouvement",
    ["TOGGLE_NAME_rotateMinimap"] = "Faire pivoter la mini-carte",
    ["TOGGLE_NAME_useUiScale"] = "Activer l'échelle d'interface personnalisée",
    ["TOGGLE_NAME_uiScale"] = "Échelle de l'interface",

    ["TOGGLE_NAME_nameplateShowEnemies"] = "Afficher les barres d'unité ennemies",
    ["TOGGLE_NAME_nameplateShowFriends"] = "Afficher les barres d'unité alliées",
    ["TOGGLE_NAME_nameplateShowSelf"] = "Afficher sa barre d'unité personnelle",
    ["TOGGLE_NAME_nameplatePersonalShowAlways"] = "Barre d'unité personnelle toujours visible",
    ["TOGGLE_NAME_nameplatePersonalShowInCombat"] = "Barre d'unité personnelle en combat",
    ["TOGGLE_NAME_ShowClassColorInNameplate"] = "Couleurs de classe sur les barres ennemies",
    ["TOGGLE_NAME_ShowClassColorInFriendlyNameplate"] = "Couleurs de classe sur les barres alliées",
    ["TOGGLE_NAME_ShowNamePlateLoseAggroFlash"] = "Clignotement de perte de menace",
    ["TOGGLE_NAME_namePlateEnemyClickThrough"] = "Barres ennemies non cliquables",
    ["TOGGLE_NAME_namePlateFriendlyClickThrough"] = "Barres alliées non cliquables",
    ["TOGGLE_NAME_nameplateMaxDistance"] = "Distance d'affichage des barres d'unité",
    ["TOGGLE_NAME_nameplateGlobalScale"] = "Échelle globale des barres d'unité",
    ["TOGGLE_NAME_namePlateEnemySize"] = "Taille des barres d'unité ennemies",
    ["TOGGLE_NAME_namePlateFriendlySize"] = "Taille des barres d'unité alliées",

    ["TOGGLE_NAME_enableFloatingCombatText"] = "Texte de combat flottant",
    ["TOGGLE_NAME_enableCombatText"] = "Texte de combat par défaut",
    ["TOGGLE_NAME_fctCombatState"] = "Texte d'état de combat",
    ["TOGGLE_NAME_floatingCombatTextCombatDamage"] = "Nombres de dégâts",
    ["TOGGLE_NAME_floatingCombatTextCombatHealing"] = "Nombres de soins",
    ["TOGGLE_NAME_floatingCombatTextCombatState"] = "Texte d'entrée/sortie de combat",
    ["TOGGLE_NAME_floatingCombatTextAuras"] = "Texte de changement d'amélioration/affaiblissement",
    ["TOGGLE_NAME_floatingCombatTextDodgeParryMiss"] = "Texte d'esquive/parade/échec",
    ["TOGGLE_NAME_floatingCombatTextHonorGains"] = "Gains d'honneur",
    ["TOGGLE_NAME_floatingCombatTextRepChanges"] = "Changements de réputation",
    ["TOGGLE_NAME_floatingCombatTextEnergyGains"] = "Gains d'énergie/mana",
    ["TOGGLE_NAME_floatingCombatTextComboPoints"] = "Gains de points de combo",
    ["TOGGLE_NAME_floatingCombatTextReactives"] = "Procs réactifs",
    ["TOGGLE_NAME_floatingCombatTextPetMeleeDamage"] = "Dégâts de mêlée du familier",

    ["TOGGLE_NAME_cameraBobbing"] = "Balancement de la caméra",
    ["TOGGLE_NAME_cameraWaterCollision"] = "Collision de la caméra avec l'eau",
    ["TOGGLE_NAME_flightAngleLookAhead"] = "Anticipation de l'angle de vol",
    ["TOGGLE_NAME_cameraDynamicPitch"] = "Inclinaison dynamique de la caméra",
    ["TOGGLE_NAME_cameraDistanceMaxZoomFactor"] = "Distance de zoom arrière maximale",
    ["TOGGLE_NAME_cameraYawMoveSpeed"] = "Vitesse de rotation horizontale de la caméra",
    ["TOGGLE_NAME_cameraPitchMoveSpeed"] = "Vitesse d'inclinaison verticale de la caméra",
    ["TOGGLE_NAME_cameraZoomSpeed"] = "Vitesse de zoom de la caméra",

    ["TOGGLE_NAME_chatBubbles"] = "Bulles de dialogue (/dire)",
    ["TOGGLE_NAME_chatBubblesParty"] = "Bulles de dialogue (Groupe)",
    ["TOGGLE_NAME_colorChatNamesByClass"] = "Couleurs de classe dans la discussion",
    ["TOGGLE_NAME_blockTrades"] = "Bloquer les demandes d'échange",
    ["TOGGLE_NAME_blockChannelInvites"] = "Bloquer les invitations aux canaux",
    ["TOGGLE_NAME_guildMemberNotify"] = "Notifications de connexion de guilde",
    ["TOGGLE_NAME_removeChatDelay"] = "Supprimer le délai de discussion",
    ["TOGGLE_NAME_chatMouseScroll"] = "Défilement de la discussion à la molette",
    ["TOGGLE_NAME_profanityFilter"] = "Filtre anti-grossièretés",
    ["TOGGLE_NAME_chatStyle"] = "Style de discussion",

    ["TOGGLE_NAME_Sound_EnableAllSound"] = "Tous les sons",
    ["TOGGLE_NAME_Sound_EnableMusic"] = "Musique",
    ["TOGGLE_NAME_Sound_EnableSFX"] = "Effets sonores",
    ["TOGGLE_NAME_Sound_EnableDialog"] = "Dialogues / Voix",
    ["TOGGLE_NAME_Sound_EnableAmbience"] = "Ambiance",
    ["TOGGLE_NAME_Sound_EnablePetSounds"] = "Sons du familier",
    ["TOGGLE_NAME_FootstepSounds"] = "Bruits de pas",
    ["TOGGLE_NAME_Sound_MasterVolume"] = "Volume principal",
    ["TOGGLE_NAME_Sound_MusicVolume"] = "Volume de la musique",
    ["TOGGLE_NAME_Sound_SFXVolume"] = "Volume des effets",

    ["TOGGLE_NAME_ffxDeath"] = "Effet d'écran de mort",
    ["TOGGLE_NAME_ffxGlow"] = "Effet de halo / bloom",
    ["TOGGLE_NAME_ffxNether"] = "Effet visuel du Néant",
    ["TOGGLE_NAME_emphasizeMySpellEffects"] = "Accentuer mes effets de sorts",
    ["TOGGLE_NAME_doNotFlashLowHealthWarning"] = "Désactiver le flash de vie basse",
    ["TOGGLE_NAME_hdPlayerModels"] = "Modèles de joueurs HD",
    ["TOGGLE_NAME_findYourselfAnywhere"] = "Surbrillance du personnage",
    ["TOGGLE_NAME_gxVSync"] = "VSync",
    ["TOGGLE_NAME_gxTripleBuffer"] = "Triple mise en mémoire tampon",
    ["TOGGLE_NAME_particleDensity"] = "Densité de particules",
    ["TOGGLE_NAME_maxFPS"] = "FPS max (premier plan)",
    ["TOGGLE_NAME_maxFPSBk"] = "FPS max (arrière-plan)",
    ["TOGGLE_NAME_gxMaxFrameLatency"] = "Latence d'image maximale",
    ["TOGGLE_NAME_RenderScale"] = "Échelle de rendu",
    ["TOGGLE_NAME_graphicsQuality"] = "Préréglage de qualité graphique",
    ["TOGGLE_NAME_ffxAntiAliasingMode"] = "Mode d'anticrénelage",
    ["TOGGLE_NAME_colorblindMode"] = "Mode daltonien",

    ["TOGGLE_NAME_disableServerNagle"] = "Désactiver l'algorithme de Nagle",
    ["TOGGLE_NAME_gxFixLag"] = "Corriger la latence d'entrée",
    ["TOGGLE_NAME_reducedLagTolerance"] = "Tolérance de latence réduite",
    ["TOGGLE_NAME_SpellQueueWindow"] = "Fenêtre de file d'attente des sorts",

    ["TOGGLE_DESC_autoLootDefault"] = "Ramasse automatiquement tout le butin sans cliquer sur chaque objet.",
    ["TOGGLE_DESC_autoSelfCast"] = "Lance les sorts bénéfiques sur vous-même lorsque vous n'avez aucune cible sélectionnée.",
    ["TOGGLE_DESC_autoDismount"] = "Descend automatiquement de votre monture quand vous récoltez, parlez à des PNJ ou entrez en combat.",
    ["TOGGLE_DESC_autoDismountFlying"] = "Descend automatiquement de votre monture même en vol. Attention : vous tomberez !",
    ["TOGGLE_DESC_autoStand"] = "Vous lève automatiquement quand vous tentez de bouger ou d'agir en étant assis.",
    ["TOGGLE_DESC_autoUnshift"] = "Quitte automatiquement les formes lorsque vous utilisez une capacité qui le nécessite.",
    ["TOGGLE_DESC_assistAttack"] = "Quand vous assistez une cible alliée, attaque automatiquement sa cible.",
    ["TOGGLE_DESC_ActionButtonUseKeyDown"] = "Activé : les sorts se lancent dès l'appui sur la touche. Désactivé : les sorts se lancent au relâchement, vous laissant d'abord vérifier la portée.",
    ["TOGGLE_DESC_deselectOnClick"] = "Annule votre cible lorsque vous cliquez sur le sol vide.",
    ["TOGGLE_DESC_stopAutoAttackOnTargetChange"] = "Arrête l'attaque automatique lorsque vous changez de cible.",
    ["TOGGLE_DESC_lootUnderMouse"] = "Ouvre la fenêtre de butin à l'emplacement du curseur plutôt qu'à une position fixe.",
    ["TOGGLE_DESC_lootLeftmostBag"] = "Place le butin dans votre sac le plus à gauche plutôt que le plus à droite.",
    ["TOGGLE_DESC_interactOnLeftClick"] = "Clic gauche sur les PNJ et objets pour interagir au lieu du clic droit.",
    ["TOGGLE_DESC_autointeract"] = "Le clic droit sur un PNJ lui parle ou le dépouille automatiquement.",
    ["TOGGLE_DESC_autoClearAFK"] = "Retire automatiquement votre statut Absent lorsque vous bougez ou agissez.",

    ["TOGGLE_DESC_countdownForCooldowns"] = "Affiche les chiffres du compte à rebours au centre des icônes de capacités en recharge.",
    ["TOGGLE_DESC_displaySpellActivationOverlays"] = "Affiche des bordures lumineuses sur les capacités lorsqu'un proc se déclenche, comme les procs de lancement instantané.",
    ["TOGGLE_DESC_alwaysShowActionBars"] = "Garde les barres d'action visibles même vides, les empêchant de se masquer.",
    ["TOGGLE_DESC_lockActionBars"] = "Empêche de retirer accidentellement des capacités de vos barres d'action.",
    ["TOGGLE_DESC_bottomLeftActionBar"] = "Affiche la barre d'action supplémentaire au-dessus de votre barre principale, côté gauche.",
    ["TOGGLE_DESC_bottomRightActionBar"] = "Affiche la barre d'action supplémentaire au-dessus de votre barre principale, côté droit.",
    ["TOGGLE_DESC_rightActionBar"] = "Affiche la barre d'action verticale sur le côté droit de l'écran.",
    ["TOGGLE_DESC_rightTwoActionBar"] = "Affiche une seconde barre d'action verticale sur le côté droit de l'écran.",
    ["TOGGLE_DESC_displayFreeBagSlots"] = "Affiche le nombre d'emplacements de sac vides sur votre barre de sacs.",
    ["TOGGLE_DESC_buffDurations"] = "Affiche le temps restant sur vos améliorations sous forme de compte à rebours.",
    ["TOGGLE_DESC_showTargetOfTarget"] = "Affiche la cible de votre cible. Utile pour les tanks et les soigneurs.",
    ["TOGGLE_DESC_showTargetCastbar"] = "Affiche une barre d'incantation pour votre cible actuelle afin de voir ce qu'elle lance.",
    ["TOGGLE_DESC_fullSizeFocusFrame"] = "Utilise un cadre d'unité pleine taille pour votre focalisation au lieu du petit cadre.",
    ["TOGGLE_DESC_breakUpLargeNumbers"] = "Affiche les grands nombres avec des séparateurs, comme 1 000 000 au lieu de 1000000.",
    ["TOGGLE_DESC_alwaysCompareItems"] = "Affiche automatiquement l'infobulle de comparaison au survol de l'équipement. Aucune touche Maj nécessaire.",
    ["TOGGLE_DESC_missingTransmogSourceInItemTooltips"] = "Indique dans les infobulles si vous possédez cette apparence, mais pas via cette source d'objet précise.",
    ["TOGGLE_DESC_autoQuestWatch"] = "Ajoute automatiquement les nouvelles quêtes à votre suivi de quêtes à droite de l'écran.",
    ["TOGGLE_DESC_autoQuestProgress"] = "Affiche des notifications contextuelles lorsque vous progressez dans une quête.",
    ["TOGGLE_DESC_mapFade"] = "Rend la carte transparente quand vous bougez afin de voir encore le monde du jeu.",
    ["TOGGLE_DESC_rotateMinimap"] = "La mini-carte pivote selon votre orientation comme une boussole au lieu de rester nord en haut.",
    ["TOGGLE_DESC_useUiScale"] = "Autorise la personnalisation de l'échelle de l'interface. Activez ceci pour utiliser le curseur d'échelle.",
    ["TOGGLE_DESC_uiScale"] = "Taille générale de l'interface. Nécessite que l'échelle d'interface personnalisée soit activée.",

    ["TOGGLE_DESC_nameplateShowEnemies"] = "Affiche des barres d'unité avec barre de vie au-dessus des ennemis.",
    ["TOGGLE_DESC_nameplateShowFriends"] = "Affiche des barres d'unité avec barre de vie au-dessus des alliés.",
    ["TOGGLE_DESC_nameplateShowSelf"] = "Affiche votre barre de ressource personnelle comme une barre d'unité au-dessus de votre personnage.",
    ["TOGGLE_DESC_nameplatePersonalShowAlways"] = "Affiche toujours votre barre de ressource personnelle, même hors combat.",
    ["TOGGLE_DESC_nameplatePersonalShowInCombat"] = "N'affiche votre barre de ressource personnelle que pendant le combat.",
    ["TOGGLE_DESC_ShowClassColorInNameplate"] = "Colore les barres d'unité ennemies par classe en JcJ.",
    ["TOGGLE_DESC_ShowClassColorInFriendlyNameplate"] = "Colore les barres d'unité alliées par classe.",
    ["TOGGLE_DESC_ShowNamePlateLoseAggroFlash"] = "Fait clignoter une barre d'unité quand vous perdez la menace sur un ennemi en tant que tank.",
    ["TOGGLE_DESC_namePlateEnemyClickThrough"] = "Rend les barres d'unité ennemies non cliquables. Vous voyez les barres de vie mais ne pouvez pas cliquer pour cibler.",
    ["TOGGLE_DESC_namePlateFriendlyClickThrough"] = "Rend les barres d'unité alliées non cliquables. Vous voyez les barres de vie mais ne pouvez pas cliquer pour cibler des alliés.",
    ["TOGGLE_DESC_nameplateMaxDistance"] = "Distance maximale en mètres à laquelle les barres d'unité sont visibles. Le maximum est de 60 en instance.",
    ["TOGGLE_DESC_nameplateGlobalScale"] = "Multiplicateur de taille principal pour toutes les barres d'unité. Affecte tout après les autres réglages d'échelle.",
    ["TOGGLE_DESC_namePlateEnemySize"] = "Multiplicateur de taille des barres d'unité ennemies. Plus grand les rend plus visibles en combat.",
    ["TOGGLE_DESC_namePlateFriendlySize"] = "Multiplicateur de taille des barres d'unité des joueurs alliés.",

    ["TOGGLE_DESC_enableFloatingCombatText"] = "Affiche des nombres de dégâts et de soins flottants qui montent depuis les ennemis et alliés.",
    ["TOGGLE_DESC_enableCombatText"] = "Affiche les nombres de dégâts et de soins dans la zone de texte de combat par défaut, près de votre personnage.",
    ["TOGGLE_DESC_fctCombatState"] = "Affiche des notifications de texte flottant « Vous êtes maintenant en combat ! » via le système de texte de combat par défaut.",
    ["TOGGLE_DESC_floatingCombatTextCombatDamage"] = "Affiche les dégâts que vous infligez sous forme de nombres flottants.",
    ["TOGGLE_DESC_floatingCombatTextCombatHealing"] = "Affiche les soins que vous recevez sous forme de nombres verts flottants.",
    ["TOGGLE_DESC_floatingCombatTextCombatState"] = "Affiche l'entrée et la sortie de combat sous forme de messages texte flottants.",
    ["TOGGLE_DESC_floatingCombatTextAuras"] = "Affiche quand vous gagnez ou perdez des améliorations et affaiblissements sous forme de texte flottant.",
    ["TOGGLE_DESC_floatingCombatTextDodgeParryMiss"] = "Affiche les résultats Esquive, Parade et Échec sous forme de texte flottant.",
    ["TOGGLE_DESC_floatingCombatTextHonorGains"] = "Affiche les gains de points d'honneur sous forme de texte flottant en JcJ.",
    ["TOGGLE_DESC_floatingCombatTextRepChanges"] = "Affiche les gains et pertes de réputation sous forme de texte flottant.",
    ["TOGGLE_DESC_floatingCombatTextEnergyGains"] = "Affiche les gains d'énergie, de rage et de mana sous forme de texte flottant.",
    ["TOGGLE_DESC_floatingCombatTextComboPoints"] = "Affiche les gains de points de combo sous forme de texte flottant.",
    ["TOGGLE_DESC_floatingCombatTextReactives"] = "Affiche les procs de capacités réactives en texte flottant.",
    ["TOGGLE_DESC_floatingCombatTextPetMeleeDamage"] = "Affiche les dégâts de mêlée de votre familier sous forme de nombres flottants.",

    ["TOGGLE_DESC_cameraBobbing"] = "La caméra rebondit doucement de haut en bas en marchant et en courant. Plus immersif mais peut provoquer le mal des transports.",
    ["TOGGLE_DESC_cameraWaterCollision"] = "Empêche la caméra de passer sous l'eau quand votre personnage est au-dessus de la surface.",
    ["TOGGLE_DESC_flightAngleLookAhead"] = "Votre monture volante s'incline pour montrer la direction que vous suivez, pour plus de réalisme.",
    ["TOGGLE_DESC_cameraDynamicPitch"] = "La caméra s'incline automatiquement selon votre direction de déplacement. C'est la fonctionnalité Action Cam.",
    ["TOGGLE_DESC_cameraDistanceMaxZoomFactor"] = "Multiplicateur de la distance de zoom arrière maximale. Des valeurs plus élevées permettent de dézoomer davantage.",
    ["TOGGLE_DESC_cameraYawMoveSpeed"] = "Vitesse à laquelle la caméra tourne à gauche et à droite.",
    ["TOGGLE_DESC_cameraPitchMoveSpeed"] = "Vitesse à laquelle la caméra s'incline de haut en bas.",
    ["TOGGLE_DESC_cameraZoomSpeed"] = "Vitesse à laquelle la caméra zoome avant et arrière avec la molette.",

    ["TOGGLE_DESC_chatBubbles"] = "Affiche des bulles de dialogue au-dessus de la tête des personnages quand ils utilisent /dire ou /crier.",
    ["TOGGLE_DESC_chatBubblesParty"] = "Affiche des bulles de dialogue pour les messages de groupe et de raid au-dessus des têtes.",
    ["TOGGLE_DESC_colorChatNamesByClass"] = "Colore les noms des joueurs dans la discussion selon leur classe.",
    ["TOGGLE_DESC_blockTrades"] = "Empêche les autres joueurs d'ouvrir des fenêtres d'échange avec vous.",
    ["TOGGLE_DESC_blockChannelInvites"] = "Empêche les autres joueurs de vous inviter dans des canaux de discussion.",
    ["TOGGLE_DESC_guildMemberNotify"] = "Affiche un message dans la discussion quand des membres de la guilde se connectent ou se déconnectent.",
    ["TOGGLE_DESC_removeChatDelay"] = "Supprime le délai anti-spam entre l'envoi des messages de discussion.",
    ["TOGGLE_DESC_chatMouseScroll"] = "Faites défiler l'historique de la discussion avec la molette de la souris.",
    ["TOGGLE_DESC_profanityFilter"] = "Remplace les gros mots par des symboles dans la discussion.",
    ["TOGGLE_DESC_chatStyle"] = "Classique utilise des fenêtres de discussion séparées. Moderne utilise un style de discussion à onglets.",

    ["TOGGLE_DESC_Sound_EnableAllSound"] = "Interrupteur principal pour tout l'audio du jeu. Le désactiver coupe tout le son.",
    ["TOGGLE_DESC_Sound_EnableMusic"] = "Joue la musique d'ambiance dans les zones et pendant les événements.",
    ["TOGGLE_DESC_Sound_EnableSFX"] = "Joue les effets sonores, y compris les capacités, les sons de combat et les clics d'interface.",
    ["TOGGLE_DESC_Sound_EnableDialog"] = "Joue le doublage des PNJ et l'audio des dialogues de quête.",
    ["TOGGLE_DESC_Sound_EnableAmbience"] = "Joue les sons d'ambiance environnementaux comme le vent, les oiseaux et l'eau.",
    ["TOGGLE_DESC_Sound_EnablePetSounds"] = "Joue les sons de votre familier comme les grognements et les déplacements.",
    ["TOGGLE_DESC_FootstepSounds"] = "Joue les bruits de pas en marchant et en courant.",
    ["TOGGLE_DESC_Sound_MasterVolume"] = "Volume général du jeu. Cela affecte tous les autres curseurs de volume.",
    ["TOGGLE_DESC_Sound_MusicVolume"] = "Volume de la musique d'ambiance.",
    ["TOGGLE_DESC_Sound_SFXVolume"] = "Volume des effets sonores, y compris les capacités et le combat.",

    ["TOGGLE_DESC_ffxDeath"] = "Affiche un effet d'écran désaturé en niveaux de gris quand vous mourez.",
    ["TOGGLE_DESC_ffxGlow"] = "Active l'effet de halo doux autour des objets lumineux.",
    ["TOGGLE_DESC_ffxNether"] = "Active des effets visuels spéciaux dans le Néant et les zones du vide.",
    ["TOGGLE_DESC_emphasizeMySpellEffects"] = "Rend vos propres effets de sorts plus visibles par rapport à ceux des autres joueurs.",
    ["TOGGLE_DESC_doNotFlashLowHealthWarning"] = "Désactive le flash rouge de l'écran qui apparaît quand votre vie est critique.",
    ["TOGGLE_DESC_hdPlayerModels"] = "Utilise des modèles de personnages haute définition. Plus beaux mais consomment plus de mémoire.",
    ["TOGGLE_DESC_findYourselfAnywhere"] = "Affiche un cercle de surbrillance sous votre personnage pour toujours vous retrouver dans la foule.",
    ["TOGGLE_DESC_gxVSync"] = "Limite les images au taux de rafraîchissement de votre écran. Évite le déchirement mais ajoute un léger délai d'entrée.",
    ["TOGGLE_DESC_gxTripleBuffer"] = "Triple mise en mémoire tampon pour une cadence d'images plus fluide. Ajoute un léger délai d'entrée.",
    ["TOGGLE_DESC_particleDensity"] = "Nombre d'effets de sorts et de particules affichés simultanément. Des valeurs plus basses améliorent les FPS dans les raids chargés.",
    ["TOGGLE_DESC_maxFPS"] = "Images par seconde maximales quand la fenêtre du jeu est active. 0 pour illimité.",
    ["TOGGLE_DESC_maxFPSBk"] = "Images par seconde maximales quand la fenêtre du jeu est en arrière-plan. Des valeurs plus basses économisent l'énergie en alt-tab.",
    ["TOGGLE_DESC_gxMaxFrameLatency"] = "Nombre maximal d'images en file pour le rendu. Des valeurs plus basses réduisent la latence d'entrée. Des valeurs plus hautes produisent un rendu plus fluide.",
    ["TOGGLE_DESC_RenderScale"] = "Multiplicateur de résolution interne. Au-dessus de 1.0, suréchantillonne pour une image plus nette. En dessous de 1.0, améliore les performances.",
    ["TOGGLE_DESC_graphicsQuality"] = "Préréglage principal de qualité graphique. Le modifier ajuste automatiquement tous les autres réglages graphiques.",
    ["TOGGLE_DESC_ffxAntiAliasingMode"] = "Lisse les bords crénelés des objets. Les modes supérieurs offrent une meilleure qualité mais consomment plus de ressources GPU.",
    ["TOGGLE_DESC_colorblindMode"] = "Active des ajustements de couleurs adaptés au daltonisme. Choisissez un mode correspondant à votre type de déficience de la vision des couleurs.",

    ["TOGGLE_DESC_disableServerNagle"] = "Réduit la latence réseau en désactivant le regroupement de paquets. Peut légèrement augmenter l'usage de la bande passante.",
    ["TOGGLE_DESC_gxFixLag"] = "Réduit la latence d'entrée du curseur de souris sur certains systèmes en modifiant la file de rendu.",
    ["TOGGLE_DESC_reducedLagTolerance"] = "Optimise les performances réseau pour les connexions à faible latence. Peut affecter la mise en file des sorts.",
    ["TOGGLE_DESC_SpellQueueWindow"] = "Combien de millisecondes à l'avance vous pouvez mettre votre prochain sort en file avant la fin du sort en cours. Des valeurs plus élevées sont plus tolérantes pour le timing.",

    ["TOGGLE_OPT_chatStyle_classic"] = "Classique",
    ["TOGGLE_OPT_chatStyle_im"] = "Moderne",
    ["TOGGLE_OPT_graphicsQuality_1"] = "1",
    ["TOGGLE_OPT_graphicsQuality_2"] = "2",
    ["TOGGLE_OPT_graphicsQuality_3"] = "3",
    ["TOGGLE_OPT_graphicsQuality_4"] = "4",
    ["TOGGLE_OPT_graphicsQuality_5"] = "5",
    ["TOGGLE_OPT_graphicsQuality_6"] = "6",
    ["TOGGLE_OPT_graphicsQuality_7"] = "7",
    ["TOGGLE_OPT_graphicsQuality_8"] = "8",
    ["TOGGLE_OPT_graphicsQuality_9"] = "9",
    ["TOGGLE_OPT_graphicsQuality_10"] = "10",
    ["TOGGLE_OPT_ffxAntiAliasingMode_0"] = "Désactivé",
    ["TOGGLE_OPT_ffxAntiAliasingMode_1"] = "CMAA",
    ["TOGGLE_OPT_ffxAntiAliasingMode_2"] = "FXAA faible",
    ["TOGGLE_OPT_ffxAntiAliasingMode_3"] = "FXAA élevé",
    ["TOGGLE_OPT_colorblindMode_0"] = "Désactivé",
    ["TOGGLE_OPT_colorblindMode_1"] = "Protanopie",
    ["TOGGLE_OPT_colorblindMode_2"] = "Deutéranopie",
    ["TOGGLE_OPT_colorblindMode_3"] = "Tritanopie",

    ["BINDING_HEADER_ONEWOW_QOL"] = "|cFF00FF00OneWoW|r QoL",
    ["BINDING_NAME_QUESTITEM_1"] = "Objet de quête 1",
    ["BINDING_NAME_QUESTITEM_2"] = "Objet de quête 2",
    ["BINDING_NAME_QUESTITEM_3"] = "Objet de quête 3",
    ["BINDING_NAME_QUESTITEM_4"] = "Objet de quête 4",
    ["BINDING_NAME_BAGITEM_1"] = "Objet de sac 1",
    ["BINDING_NAME_BAGITEM_2"] = "Objet de sac 2",
    ["BINDING_NAME_BAGITEM_3"] = "Objet de sac 3",
    ["BINDING_NAME_BAGITEM_4"] = "Objet de sac 4",
    ["BINDING_NAME_COPY_TEXT"] = "Copier le texte",
})
