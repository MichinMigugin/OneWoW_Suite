local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — pending native review
OneWoW.Locale:Register(ADDON_NAME, "itIT", {

    ["ADDON_TITLE"] = "OneWoW - QoL",
    ["ADDON_TITLE_SHORT"] = "QoL",
    ["ADDON_TITLE_FRAME"] = "OneWoW - QoL",
    ["ADDON_LOADED"] = "caricato.",

    ["TAB_FEATURES"] = "Funzioni QoL",
    ["TAB_TOGGLES"] = "Interruttori",

    ["FEATURES_LIST_TITLE"] = "Funzioni",
    ["FEATURES_FAVORITE_TT_TITLE"] = "Preferito",
    ["FEATURES_FAVORITE_TT_DESC"] = "Fissa questa funzione nella sezione Preferiti in alto. Clicca di nuovo per rimuoverla dai Preferiti.",
    ["FEATURES_DETAIL_TITLE"] = "Dettagli",
    ["FEATURES_EMPTY"] = "Nessun modulo caricato.",
    ["FEATURES_NO_SELECTION"] = "Seleziona una funzione dall'elenco.",
    ["FEATURES_ENABLED"] = "Attivato",
    ["FEATURES_DISABLED"] = "Disattivato",
    ["FEATURES_CATEGORY_LABEL"] = "Categoria:",
    ["FEATURES_VERSION_LABEL"] = "Versione:",
    ["FEATURES_AUTHOR_LABEL"] = "Autore:",
    ["FEATURES_CONTACT_LABEL"] = "Contatto:",
    ["FEATURES_LINK_LABEL"] = "Link:",
    ["FEATURES_DETAILS_BTN"] = "Dettagli",
    ["FEATURES_DETAILS_TITLE"] = "Dettagli del modulo",
    ["FEATURES_TOGGLES_HEADER"] = "Interruttori del modulo",
    ["FEATURES_ON"] = "Sì",
    ["FEATURES_OFF"] = "No",
    ["FEATURES_PREVIEW_LABEL"] = "Anteprima:",

    ["CATEGORY_AUTOMATION"] = "Automazione",
    ["CATEGORY_INTERFACE"] = "Interfaccia",
    ["CATEGORY_SOCIAL"] = "Sociale",
    ["CATEGORY_COMBAT"] = "Combattimento",
    ["CATEGORY_ECONOMY"] = "Economia",
    ["CATEGORY_UTILITY"] = "Utilità",

    ["TOGGLES_LIST_TITLE"] = "Indicatori di gioco",
    ["TOGGLES_FAVORITE_TT_TITLE"] = "Preferito",
    ["TOGGLES_FAVORITE_TT_DESC"] = "Fissa questo interruttore nella sezione Preferiti in alto. Clicca di nuovo per rimuoverlo dai Preferiti.",
    ["TOGGLES_DETAIL_TITLE"] = "Dettagli dell'indicatore",
    ["TOGGLES_COMING_SOON"] = "Gli indicatori di gioco saranno aggiunti in un futuro aggiornamento.",
    ["TOGGLES_NO_SELECTION"] = "Seleziona un indicatore dall'elenco.",

    ["SETTINGS_THEME_HEADER"] = "Tema dei colori",
    ["SETTINGS_THEME_DESC"] = "Scegli un tema di colori. Le modifiche si applicano all'istante.",
    ["SETTINGS_LANGUAGE_DESC"] = "Scegli la tua lingua preferita. Le modifiche si applicano all'istante.",
    ["SETTINGS_DEVELOPER_HEADER"] = "Informazioni per sviluppatori",
    ["SETTINGS_DEVELOPER_DESC"] = "Questo addon supporta moduli esterni. Aggiungi funzioni QoL creando una cartella di modulo in Modules\\external\\. Usa il pulsante Aiuto sviluppatori per la documentazione completa.",
    ["SETTINGS_DEV_HELP_BTN"] = "Aiuto sviluppatori",

    ["DEVHELP_TITLE"] = "Guida per sviluppatori di moduli",
    ["DEVHELP_BODY"] = [[SISTEMA DI MODULI PLUG-IN

Crea la tua cartella:
  Modules\external\yourmodule\

File (module.lua si carica PER PRIMO):
  module.lua      - Metadati + registrazione
  yourmodule.lua  - Logica del modulo
  Locales\enUS.lua  (koKR.lua facoltativo)

In module.lua definisci il tuo modulo
(l'id esiste SOLO qui):
  local ADDON_NAME, ns = ...
  ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "yourmodule",
    title       = "MY_TITLE",
    category    = "AUTOMATION",
    description = "MY_DESC",
    version     = "1.0",
    author      = "Il tuo nome",
    contact     = "tua@email.com",
    link        = "https://tuosito.com",
    toggles = {
      { id = "myToggle", label = "MY_TOGGLE_LABEL",
        description = "MY_TOGGLE_DESC", default = true },
    },
    defaultEnabled = true,
  })

In yourmodule.lua recuperalo + la tua
vista locale (cattura al caricamento, mai a runtime):
  local _, ns = ...
  local M, L = ns.ModuleRegistry:Current()
  if not M then return end

  function M:OnEnable() end
  function M:OnDisable() end
  function M:OnToggle(id, val) end

In Locales\enUS.lua:
  local _, ns = ...
  local M = ns.ModuleRegistry:Current()
  OneWoW.Locale:Register(M._scope, "enUS", {
    ["MY_TITLE"] = "My Title",
    ["MY_DESC"]  = "What it does",
  })

Lo scope è ADDON_NAME .. "." .. id, ad es.
OneWoW_QoL.yourmodule (derivato, nessuna
stringa di scope scritta a mano).

Fai riferimento a un altro modulo tramite id:
  ns.ModuleRegistry:GetById("othermodule")
Non usare mai ns.<X>Module.

I valori title, description, nonché l'etichetta
e la descrizione degli interruttori sono chiavi
di locale. author, contact e link sono
facoltativi. contact e link compaiono come
caselle copiabili nella finestra Dettagli del modulo.

Categorie disponibili:
  AUTOMATION  INTERFACE  SOCIAL
  COMBAT      ECONOMY    UTILITY

Aggiungi i tuoi file al TOC sotto EXTERNAL
MODULES. Ordine: module.lua PER PRIMO, poi
i Locales, poi i tuoi file di codice.

Spazio del database SavedVariables:
  OneWoW_QoL_DB.modules.yourmodule

Vedi Modules\external\autodelete\ per un
esempio completo e funzionante.]],

    ["MINIMAP_TOOLTIP_TITLE"] = "OneWoW - QoL",
    ["MINIMAP_TOOLTIP_HINT"] = "Clicca per aprire",
    ["MINIMAP_RIGHT_CLICK"] = "Clic destro per le opzioni",
    ["MINIMAP_OPEN"] = "Apri QoL",

    ["LANG_ENGLISH"] = "Inglese",
    ["LANG_KOREAN"] = "Coreano",


    ["SEARCH_HINT"] = "Filtra...",
    ["TOGGLES_STATUS_ALL"] = "%d CVar mostrate",
    ["TOGGLES_STATUS_FILTERED"] = "%d di %d mostrate",
    ["FEATURES_STATUS_ENABLED"] = "%d di %d attivate",

    ["TOGGLES_CVAR_LABEL"] = "CVar:",
    ["TOGGLES_ON"] = "Sì",
    ["TOGGLES_OFF"] = "No",
    ["TOGGLES_VALUE_LABEL"] = "Valore:",

    ["TOGGLE_CAT_GAMEPLAY"] = "Gioco",
    ["TOGGLE_CAT_INTERFACE"] = "Interfaccia",
    ["TOGGLE_CAT_NAMEPLATES"] = "Targhette",
    ["TOGGLE_CAT_COMBAT_TEXT"] = "Testo di combattimento",
    ["TOGGLE_CAT_CAMERA"] = "Telecamera",
    ["TOGGLE_CAT_CHAT"] = "Chat e sociale",
    ["TOGGLE_CAT_AUDIO"] = "Audio",
    ["TOGGLE_CAT_GRAPHICS"] = "Grafica",
    ["TOGGLE_CAT_NETWORK"] = "Rete",

    ["TOGGLE_NAME_autoLootDefault"] = "Saccheggio automatico",
    ["TOGGLE_NAME_autoSelfCast"] = "Lancio automatico su sé stessi",
    ["TOGGLE_NAME_autoDismount"] = "Smonta automaticamente",
    ["TOGGLE_NAME_autoDismountFlying"] = "Smonta in volo",
    ["TOGGLE_NAME_autoStand"] = "Alzati automaticamente",
    ["TOGGLE_NAME_autoUnshift"] = "Abbandona forma automaticamente",
    ["TOGGLE_NAME_assistAttack"] = "Attacco di assistenza",
    ["TOGGLE_NAME_ActionButtonUseKeyDown"] = "Pulsanti azione alla pressione",
    ["TOGGLE_NAME_deselectOnClick"] = "Deseleziona bersaglio al clic",
    ["TOGGLE_NAME_stopAutoAttackOnTargetChange"] = "Ferma l'attacco automatico al cambio bersaglio",
    ["TOGGLE_NAME_lootUnderMouse"] = "Finestra del bottino sotto il mouse",
    ["TOGGLE_NAME_lootLeftmostBag"] = "Saccheggia nella borsa più a sinistra",
    ["TOGGLE_NAME_interactOnLeftClick"] = "Interagisci con clic sinistro",
    ["TOGGLE_NAME_autointeract"] = "Interazione automatica",
    ["TOGGLE_NAME_autoClearAFK"] = "Rimuovi assenza automaticamente",

    ["TOGGLE_NAME_countdownForCooldowns"] = "Conto alla rovescia dei recuperi",
    ["TOGGLE_NAME_displaySpellActivationOverlays"] = "Bagliore di proc delle magie",
    ["TOGGLE_NAME_alwaysShowActionBars"] = "Mostra sempre le barre delle azioni",
    ["TOGGLE_NAME_lockActionBars"] = "Blocca le barre delle azioni",
    ["TOGGLE_NAME_bottomLeftActionBar"] = "Barra delle azioni in basso a sinistra",
    ["TOGGLE_NAME_bottomRightActionBar"] = "Barra delle azioni in basso a destra",
    ["TOGGLE_NAME_rightActionBar"] = "Barra delle azioni a destra",
    ["TOGGLE_NAME_rightTwoActionBar"] = "Barra delle azioni a destra 2",
    ["TOGGLE_NAME_displayFreeBagSlots"] = "Mostra spazi liberi nelle borse",
    ["TOGGLE_NAME_buffDurations"] = "Mostra la durata dei benefici",
    ["TOGGLE_NAME_showTargetOfTarget"] = "Mostra bersaglio del bersaglio",
    ["TOGGLE_NAME_showTargetCastbar"] = "Mostra barra di lancio del bersaglio",
    ["TOGGLE_NAME_fullSizeFocusFrame"] = "Riquadro del focus a dimensione piena",
    ["TOGGLE_NAME_breakUpLargeNumbers"] = "Formatta i numeri grandi",
    ["TOGGLE_NAME_alwaysCompareItems"] = "Confronta sempre gli oggetti",
    ["TOGGLE_NAME_missingTransmogSourceInItemTooltips"] = "Fonte di trasmogrificazione mancante",
    ["TOGGLE_NAME_autoQuestWatch"] = "Traccia automaticamente le missioni",
    ["TOGGLE_NAME_autoQuestProgress"] = "Avvisi di progresso missione",
    ["TOGGLE_NAME_mapFade"] = "La mappa sfuma in movimento",
    ["TOGGLE_NAME_rotateMinimap"] = "Ruota la minimappa",
    ["TOGGLE_NAME_useUiScale"] = "Attiva scala interfaccia personalizzata",
    ["TOGGLE_NAME_uiScale"] = "Scala dell'interfaccia",

    ["TOGGLE_NAME_nameplateShowEnemies"] = "Mostra targhette nemiche",
    ["TOGGLE_NAME_nameplateShowFriends"] = "Mostra targhette alleate",
    ["TOGGLE_NAME_nameplateShowSelf"] = "Mostra targhetta personale",
    ["TOGGLE_NAME_nameplatePersonalShowAlways"] = "Targhetta personale sempre visibile",
    ["TOGGLE_NAME_nameplatePersonalShowInCombat"] = "Targhetta personale in combattimento",
    ["TOGGLE_NAME_ShowClassColorInNameplate"] = "Colori di classe sulle targhette nemiche",
    ["TOGGLE_NAME_ShowClassColorInFriendlyNameplate"] = "Colori di classe sulle targhette alleate",
    ["TOGGLE_NAME_ShowNamePlateLoseAggroFlash"] = "Lampeggio alla perdita di minaccia",
    ["TOGGLE_NAME_namePlateEnemyClickThrough"] = "Targhette nemiche non cliccabili",
    ["TOGGLE_NAME_namePlateFriendlyClickThrough"] = "Targhette alleate non cliccabili",
    ["TOGGLE_NAME_nameplateMaxDistance"] = "Distanza di visualizzazione delle targhette",
    ["TOGGLE_NAME_nameplateGlobalScale"] = "Scala globale delle targhette",
    ["TOGGLE_NAME_namePlateEnemySize"] = "Dimensione delle targhette nemiche",
    ["TOGGLE_NAME_namePlateFriendlySize"] = "Dimensione delle targhette alleate",

    ["TOGGLE_NAME_enableFloatingCombatText"] = "Testo di combattimento fluttuante",
    ["TOGGLE_NAME_enableCombatText"] = "Testo di combattimento predefinito",
    ["TOGGLE_NAME_fctCombatState"] = "Testo di stato del combattimento",
    ["TOGGLE_NAME_floatingCombatTextCombatDamage"] = "Numeri dei danni",
    ["TOGGLE_NAME_floatingCombatTextCombatHealing"] = "Numeri delle cure",
    ["TOGGLE_NAME_floatingCombatTextCombatState"] = "Testo di entrata/uscita dal combattimento",
    ["TOGGLE_NAME_floatingCombatTextAuras"] = "Testo di cambio benefici/penalità",
    ["TOGGLE_NAME_floatingCombatTextDodgeParryMiss"] = "Testo di schivata/parata/mancato",
    ["TOGGLE_NAME_floatingCombatTextHonorGains"] = "Guadagni di onore",
    ["TOGGLE_NAME_floatingCombatTextRepChanges"] = "Cambi di reputazione",
    ["TOGGLE_NAME_floatingCombatTextEnergyGains"] = "Guadagni di energia/mana",
    ["TOGGLE_NAME_floatingCombatTextComboPoints"] = "Guadagni di punti combo",
    ["TOGGLE_NAME_floatingCombatTextReactives"] = "Proc reattivi",
    ["TOGGLE_NAME_floatingCombatTextPetMeleeDamage"] = "Danno in mischia del famiglio",

    ["TOGGLE_NAME_cameraBobbing"] = "Oscillazione della telecamera",
    ["TOGGLE_NAME_cameraWaterCollision"] = "Collisione della telecamera con l'acqua",
    ["TOGGLE_NAME_flightAngleLookAhead"] = "Anticipo dell'angolo di volo",
    ["TOGGLE_NAME_cameraDynamicPitch"] = "Inclinazione dinamica della telecamera",
    ["TOGGLE_NAME_cameraDistanceMaxZoomFactor"] = "Distanza massima di zoom indietro",
    ["TOGGLE_NAME_cameraYawMoveSpeed"] = "Velocità di rotazione orizzontale della telecamera",
    ["TOGGLE_NAME_cameraPitchMoveSpeed"] = "Velocità di inclinazione verticale della telecamera",
    ["TOGGLE_NAME_cameraZoomSpeed"] = "Velocità di zoom della telecamera",

    ["TOGGLE_NAME_chatBubbles"] = "Fumetti (/dire)",
    ["TOGGLE_NAME_chatBubblesParty"] = "Fumetti (Gruppo)",
    ["TOGGLE_NAME_colorChatNamesByClass"] = "Colori di classe nella chat",
    ["TOGGLE_NAME_blockTrades"] = "Blocca richieste di scambio",
    ["TOGGLE_NAME_blockChannelInvites"] = "Blocca inviti ai canali",
    ["TOGGLE_NAME_guildMemberNotify"] = "Avvisi di accesso della gilda",
    ["TOGGLE_NAME_removeChatDelay"] = "Rimuovi il ritardo della chat",
    ["TOGGLE_NAME_chatMouseScroll"] = "Scorri la chat con la rotellina",
    ["TOGGLE_NAME_profanityFilter"] = "Filtro volgarità",
    ["TOGGLE_NAME_chatStyle"] = "Stile della chat",

    ["TOGGLE_NAME_Sound_EnableAllSound"] = "Tutti i suoni",
    ["TOGGLE_NAME_Sound_EnableMusic"] = "Musica",
    ["TOGGLE_NAME_Sound_EnableSFX"] = "Effetti sonori",
    ["TOGGLE_NAME_Sound_EnableDialog"] = "Dialoghi / Voce",
    ["TOGGLE_NAME_Sound_EnableAmbience"] = "Ambiente",
    ["TOGGLE_NAME_Sound_EnablePetSounds"] = "Suoni del famiglio",
    ["TOGGLE_NAME_FootstepSounds"] = "Suoni dei passi",
    ["TOGGLE_NAME_Sound_MasterVolume"] = "Volume principale",
    ["TOGGLE_NAME_Sound_MusicVolume"] = "Volume della musica",
    ["TOGGLE_NAME_Sound_SFXVolume"] = "Volume degli effetti",

    ["TOGGLE_NAME_ffxDeath"] = "Effetto schermo di morte",
    ["TOGGLE_NAME_ffxGlow"] = "Effetto bagliore / bloom",
    ["TOGGLE_NAME_ffxNether"] = "Effetto visivo del Nether",
    ["TOGGLE_NAME_emphasizeMySpellEffects"] = "Enfatizza i miei effetti magici",
    ["TOGGLE_NAME_doNotFlashLowHealthWarning"] = "Disattiva il lampeggio per salute bassa",
    ["TOGGLE_NAME_hdPlayerModels"] = "Modelli dei giocatori in HD",
    ["TOGGLE_NAME_findYourselfAnywhere"] = "Evidenziazione del personaggio",
    ["TOGGLE_NAME_gxVSync"] = "VSync",
    ["TOGGLE_NAME_gxTripleBuffer"] = "Triplo buffer",
    ["TOGGLE_NAME_particleDensity"] = "Densità delle particelle",
    ["TOGGLE_NAME_maxFPS"] = "FPS max (primo piano)",
    ["TOGGLE_NAME_maxFPSBk"] = "FPS max (sfondo)",
    ["TOGGLE_NAME_gxMaxFrameLatency"] = "Latenza massima dei fotogrammi",
    ["TOGGLE_NAME_RenderScale"] = "Scala di rendering",
    ["TOGGLE_NAME_graphicsQuality"] = "Preimpostazione qualità grafica",
    ["TOGGLE_NAME_ffxAntiAliasingMode"] = "Modalità anti-aliasing",
    ["TOGGLE_NAME_colorblindMode"] = "Modalità daltonici",

    ["TOGGLE_NAME_disableServerNagle"] = "Disattiva l'algoritmo di Nagle",
    ["TOGGLE_NAME_gxFixLag"] = "Correggi il ritardo di input",
    ["TOGGLE_NAME_reducedLagTolerance"] = "Tolleranza al ritardo ridotta",
    ["TOGGLE_NAME_SpellQueueWindow"] = "Finestra di coda delle magie",

    ["TOGGLE_DESC_autoLootDefault"] = "Raccoglie automaticamente tutto il bottino senza cliccare su ogni oggetto.",
    ["TOGGLE_DESC_autoSelfCast"] = "Lancia le magie benefiche su te stesso quando non hai alcun bersaglio selezionato.",
    ["TOGGLE_DESC_autoDismount"] = "Ti fa smontare automaticamente dalla cavalcatura quando provi a raccogliere, parlare con i PNG o entrare in combattimento.",
    ["TOGGLE_DESC_autoDismountFlying"] = "Ti fa smontare automaticamente anche in volo. Attenzione: cadrai!",
    ["TOGGLE_DESC_autoStand"] = "Ti alza automaticamente quando provi a muoverti o ad agire mentre sei seduto.",
    ["TOGGLE_DESC_autoUnshift"] = "Abbandona automaticamente le forme quando usi un'abilità che lo richiede.",
    ["TOGGLE_DESC_assistAttack"] = "Quando assisti un bersaglio alleato, attacchi automaticamente il suo bersaglio.",
    ["TOGGLE_DESC_ActionButtonUseKeyDown"] = "Attivato: le magie partono all'istante alla pressione del tasto. Disattivato: le magie partono al rilascio, lasciandoti prima verificare la portata.",
    ["TOGGLE_DESC_deselectOnClick"] = "Annulla il tuo bersaglio quando clicchi sul terreno vuoto.",
    ["TOGGLE_DESC_stopAutoAttackOnTargetChange"] = "Ferma l'attacco automatico quando passi a un nuovo bersaglio.",
    ["TOGGLE_DESC_lootUnderMouse"] = "Apre la finestra del bottino dove si trova il cursore del mouse invece che in una posizione fissa.",
    ["TOGGLE_DESC_lootLeftmostBag"] = "Mette il bottino nella borsa più a sinistra invece che in quella più a destra.",
    ["TOGGLE_DESC_interactOnLeftClick"] = "Clicca con il sinistro su PNG e oggetti per interagire invece del clic destro.",
    ["TOGGLE_DESC_autointeract"] = "Cliccare con il destro su un PNG gli parla o lo saccheggia automaticamente.",
    ["TOGGLE_DESC_autoClearAFK"] = "Rimuove automaticamente il tuo stato di assenza quando ti muovi o compi un'azione.",

    ["TOGGLE_DESC_countdownForCooldowns"] = "Mostra i numeri del conto alla rovescia al centro delle icone delle abilità durante il recupero.",
    ["TOGGLE_DESC_displaySpellActivationOverlays"] = "Mostra bordi luminosi sulle abilità quando si attivano i proc, come quelli di lancio istantaneo.",
    ["TOGGLE_DESC_alwaysShowActionBars"] = "Mantiene visibili le barre delle azioni anche se vuote, impedendo che si nascondano.",
    ["TOGGLE_DESC_lockActionBars"] = "Impedisce di trascinare accidentalmente le abilità fuori dalle barre delle azioni.",
    ["TOGGLE_DESC_bottomLeftActionBar"] = "Mostra la barra delle azioni aggiuntiva sopra la barra principale, sul lato sinistro.",
    ["TOGGLE_DESC_bottomRightActionBar"] = "Mostra la barra delle azioni aggiuntiva sopra la barra principale, sul lato destro.",
    ["TOGGLE_DESC_rightActionBar"] = "Mostra la barra delle azioni verticale sul lato destro dello schermo.",
    ["TOGGLE_DESC_rightTwoActionBar"] = "Mostra una seconda barra delle azioni verticale sul lato destro dello schermo.",
    ["TOGGLE_DESC_displayFreeBagSlots"] = "Mostra il numero di spazi liberi nelle borse sulla barra delle borse.",
    ["TOGGLE_DESC_buffDurations"] = "Mostra il tempo rimanente dei tuoi benefici come numeri di conto alla rovescia.",
    ["TOGGLE_DESC_showTargetOfTarget"] = "Mostra chi sta bersagliando il tuo bersaglio. Utile per tank e guaritori.",
    ["TOGGLE_DESC_showTargetCastbar"] = "Mostra una barra di lancio per il tuo bersaglio attuale così da vedere cosa sta lanciando.",
    ["TOGGLE_DESC_fullSizeFocusFrame"] = "Usa un riquadro unità a dimensione piena per il tuo focus invece del riquadro piccolo.",
    ["TOGGLE_DESC_breakUpLargeNumbers"] = "Mostra i numeri grandi con i separatori, ad esempio 1.000.000 invece di 1000000.",
    ["TOGGLE_DESC_alwaysCompareItems"] = "Mostra automaticamente la descrizione comparativa al passaggio sull'equipaggiamento. Nessun tasto Maiusc necessario.",
    ["TOGGLE_DESC_missingTransmogSourceInItemTooltips"] = "Indica nelle descrizioni se possiedi questo aspetto, ma non da questa specifica fonte dell'oggetto.",
    ["TOGGLE_DESC_autoQuestWatch"] = "Aggiunge automaticamente le nuove missioni al tracciatore sul lato destro dello schermo.",
    ["TOGGLE_DESC_autoQuestProgress"] = "Mostra avvisi pop-up quando fai progressi nelle missioni.",
    ["TOGGLE_DESC_mapFade"] = "Rende la mappa trasparente quando ti muovi così da vedere ancora il mondo di gioco.",
    ["TOGGLE_DESC_rotateMinimap"] = "La minimappa ruota in base al tuo orientamento come una bussola invece di restare fissa con il nord in alto.",
    ["TOGGLE_DESC_useUiScale"] = "Consente di personalizzare la scala dell'interfaccia. Attivalo per usare il cursore della scala.",
    ["TOGGLE_DESC_uiScale"] = "Dimensione complessiva dell'interfaccia. Richiede che la scala dell'interfaccia personalizzata sia attiva.",

    ["TOGGLE_DESC_nameplateShowEnemies"] = "Mostra targhette con barra della salute sopra le unità nemiche.",
    ["TOGGLE_DESC_nameplateShowFriends"] = "Mostra targhette con barra della salute sopra le unità alleate.",
    ["TOGGLE_DESC_nameplateShowSelf"] = "Mostra la tua barra delle risorse personale come targhetta sopra il tuo personaggio.",
    ["TOGGLE_DESC_nameplatePersonalShowAlways"] = "Mostra sempre la tua targhetta delle risorse personale, anche fuori dal combattimento.",
    ["TOGGLE_DESC_nameplatePersonalShowInCombat"] = "Mostra la tua targhetta delle risorse personale solo durante il combattimento.",
    ["TOGGLE_DESC_ShowClassColorInNameplate"] = "Colora le targhette nemiche per classe nel PvP.",
    ["TOGGLE_DESC_ShowClassColorInFriendlyNameplate"] = "Colora le targhette alleate per classe.",
    ["TOGGLE_DESC_ShowNamePlateLoseAggroFlash"] = "Fa lampeggiare una targhetta quando perdi la minaccia su un nemico come tank.",
    ["TOGGLE_DESC_namePlateEnemyClickThrough"] = "Permette di cliccare attraverso le targhette nemiche. Vedi le barre della salute ma non puoi cliccare per bersagliare.",
    ["TOGGLE_DESC_namePlateFriendlyClickThrough"] = "Permette di cliccare attraverso le targhette alleate. Vedi le barre della salute ma non puoi cliccare per bersagliare gli alleati.",
    ["TOGGLE_DESC_nameplateMaxDistance"] = "Distanza massima in metri a cui sono visibili le targhette. Il massimo è 60 nelle istanze.",
    ["TOGGLE_DESC_nameplateGlobalScale"] = "Moltiplicatore di dimensione principale per tutte le targhette. Agisce dopo le altre impostazioni di scala.",
    ["TOGGLE_DESC_namePlateEnemySize"] = "Moltiplicatore di dimensione delle targhette nemiche. Più grande le rende più facili da vedere in combattimento.",
    ["TOGGLE_DESC_namePlateFriendlySize"] = "Moltiplicatore di dimensione delle targhette dei giocatori alleati.",

    ["TOGGLE_DESC_enableFloatingCombatText"] = "Mostra numeri fluttuanti di danno e cura che salgono da nemici e alleati.",
    ["TOGGLE_DESC_enableCombatText"] = "Mostra numeri di danno e cura nell'area di testo di combattimento predefinita, vicino al tuo personaggio.",
    ["TOGGLE_DESC_fctCombatState"] = "Mostra avvisi di testo fluttuante come «Ora sei in combattimento!» tramite il sistema di testo di combattimento predefinito.",
    ["TOGGLE_DESC_floatingCombatTextCombatDamage"] = "Mostra il danno che infliggi come numeri fluttuanti.",
    ["TOGGLE_DESC_floatingCombatTextCombatHealing"] = "Mostra le cure che ricevi come numeri verdi fluttuanti.",
    ["TOGGLE_DESC_floatingCombatTextCombatState"] = "Mostra l'entrata e l'uscita dal combattimento come messaggi di testo fluttuante.",
    ["TOGGLE_DESC_floatingCombatTextAuras"] = "Mostra come testo fluttuante quando ottieni o perdi benefici e penalità.",
    ["TOGGLE_DESC_floatingCombatTextDodgeParryMiss"] = "Mostra i risultati di Schivata, Parata e Mancato come testo fluttuante.",
    ["TOGGLE_DESC_floatingCombatTextHonorGains"] = "Mostra i guadagni di punti onore come testo fluttuante nel PvP.",
    ["TOGGLE_DESC_floatingCombatTextRepChanges"] = "Mostra i guadagni e le perdite di reputazione come testo fluttuante.",
    ["TOGGLE_DESC_floatingCombatTextEnergyGains"] = "Mostra i guadagni di energia, ira e mana come testo fluttuante.",
    ["TOGGLE_DESC_floatingCombatTextComboPoints"] = "Mostra i guadagni di punti combo come testo fluttuante.",
    ["TOGGLE_DESC_floatingCombatTextReactives"] = "Mostra i proc delle abilità reattive come testo fluttuante.",
    ["TOGGLE_DESC_floatingCombatTextPetMeleeDamage"] = "Mostra il danno in mischia del tuo famiglio come numeri fluttuanti.",

    ["TOGGLE_DESC_cameraBobbing"] = "La telecamera ondeggia dolcemente su e giù mentre cammini e corri. Più immersivo ma può causare nausea.",
    ["TOGGLE_DESC_cameraWaterCollision"] = "Impedisce alla telecamera di andare sott'acqua quando il tuo personaggio è sopra la superficie.",
    ["TOGGLE_DESC_flightAngleLookAhead"] = "La tua cavalcatura volante si inclina per mostrare la direzione che segui, per una sensazione più realistica.",
    ["TOGGLE_DESC_cameraDynamicPitch"] = "La telecamera si inclina automaticamente in base alla tua direzione di movimento. È la funzione Action Cam.",
    ["TOGGLE_DESC_cameraDistanceMaxZoomFactor"] = "Moltiplicatore della distanza massima di zoom indietro. Valori più alti permettono di allontanarsi di più.",
    ["TOGGLE_DESC_cameraYawMoveSpeed"] = "Quanto velocemente la telecamera ruota a sinistra e a destra.",
    ["TOGGLE_DESC_cameraPitchMoveSpeed"] = "Quanto velocemente la telecamera si inclina su e giù.",
    ["TOGGLE_DESC_cameraZoomSpeed"] = "Quanto velocemente la telecamera zooma avanti e indietro con la rotellina.",

    ["TOGGLE_DESC_chatBubbles"] = "Mostra fumetti sopra le teste dei personaggi quando usano /dire o /urlare.",
    ["TOGGLE_DESC_chatBubblesParty"] = "Mostra fumetti per i messaggi di gruppo e incursione sopra le teste dei personaggi.",
    ["TOGGLE_DESC_colorChatNamesByClass"] = "Colora i nomi dei giocatori nella chat in base alla loro classe.",
    ["TOGGLE_DESC_blockTrades"] = "Impedisce ad altri giocatori di aprire finestre di scambio con te.",
    ["TOGGLE_DESC_blockChannelInvites"] = "Impedisce ad altri giocatori di invitarti nei canali di chat.",
    ["TOGGLE_DESC_guildMemberNotify"] = "Mostra un messaggio in chat quando i membri della gilda accedono o si disconnettono.",
    ["TOGGLE_DESC_removeChatDelay"] = "Rimuove il ritardo anti-spam tra l'invio dei messaggi in chat.",
    ["TOGGLE_DESC_chatMouseScroll"] = "Scorri la cronologia della chat con la rotellina del mouse.",
    ["TOGGLE_DESC_profanityFilter"] = "Sostituisce le parolacce con simboli nella chat.",
    ["TOGGLE_DESC_chatStyle"] = "Classico usa finestre di chat separate. Moderno usa uno stile di chat a schede.",

    ["TOGGLE_DESC_Sound_EnableAllSound"] = "Interruttore principale di tutto l'audio di gioco. Disattivarlo silenzia tutto.",
    ["TOGGLE_DESC_Sound_EnableMusic"] = "Riproduce la musica di sottofondo nelle zone e durante gli eventi.",
    ["TOGGLE_DESC_Sound_EnableSFX"] = "Riproduce gli effetti sonori, comprese abilità, suoni di combattimento e clic dell'interfaccia.",
    ["TOGGLE_DESC_Sound_EnableDialog"] = "Riproduce il doppiaggio dei PNG e l'audio dei dialoghi delle missioni.",
    ["TOGGLE_DESC_Sound_EnableAmbience"] = "Riproduce i suoni ambientali come vento, uccelli e acqua.",
    ["TOGGLE_DESC_Sound_EnablePetSounds"] = "Riproduce i suoni del tuo famiglio come ringhi e movimenti.",
    ["TOGGLE_DESC_FootstepSounds"] = "Riproduce i suoni dei passi mentre cammini e corri.",
    ["TOGGLE_DESC_Sound_MasterVolume"] = "Volume generale del gioco. Influisce su tutti gli altri cursori del volume.",
    ["TOGGLE_DESC_Sound_MusicVolume"] = "Volume della musica di sottofondo.",
    ["TOGGLE_DESC_Sound_SFXVolume"] = "Volume degli effetti sonori, comprese abilità e combattimento.",

    ["TOGGLE_DESC_ffxDeath"] = "Mostra un effetto schermo desaturato in scala di grigi quando muori.",
    ["TOGGLE_DESC_ffxGlow"] = "Attiva il morbido effetto bagliore bloom attorno agli oggetti luminosi.",
    ["TOGGLE_DESC_ffxNether"] = "Attiva effetti visivi speciali nel Nether e nelle zone del vuoto.",
    ["TOGGLE_DESC_emphasizeMySpellEffects"] = "Rende i tuoi effetti magici più visibili rispetto a quelli degli altri giocatori.",
    ["TOGGLE_DESC_doNotFlashLowHealthWarning"] = "Disattiva il lampeggio rosso dello schermo che appare quando la tua salute è criticamente bassa.",
    ["TOGGLE_DESC_hdPlayerModels"] = "Usa modelli dei personaggi ad alta definizione. Più belli ma consumano più memoria.",
    ["TOGGLE_DESC_findYourselfAnywhere"] = "Mostra un cerchio luminoso sotto il tuo personaggio per ritrovarti sempre nella folla.",
    ["TOGGLE_DESC_gxVSync"] = "Limita i fotogrammi alla frequenza di aggiornamento del monitor. Evita il tearing ma aggiunge un piccolo ritardo di input.",
    ["TOGGLE_DESC_gxTripleBuffer"] = "Triplo buffer per un ritmo dei fotogrammi più fluido. Aggiunge un lieve ritardo di input.",
    ["TOGGLE_DESC_particleDensity"] = "Quanti effetti magici e particelle appaiono contemporaneamente. Valori più bassi migliorano gli FPS nelle incursioni affollate.",
    ["TOGGLE_DESC_maxFPS"] = "Fotogrammi al secondo massimi quando la finestra di gioco è attiva. Imposta 0 per illimitato.",
    ["TOGGLE_DESC_maxFPSBk"] = "Fotogrammi al secondo massimi quando la finestra di gioco è in secondo piano. Valori più bassi risparmiano energia in alt-tab.",
    ["TOGGLE_DESC_gxMaxFrameLatency"] = "Numero massimo di fotogrammi in coda per il rendering. Valori più bassi riducono il ritardo di input. Valori più alti producono un output più fluido.",
    ["TOGGLE_DESC_RenderScale"] = "Moltiplicatore della risoluzione interna. Valori sopra 1.0 applicano il supersampling per un'immagine più nitida. Sotto 1.0 migliorano le prestazioni.",
    ["TOGGLE_DESC_graphicsQuality"] = "Preimpostazione principale della qualità grafica. Modificarla regola automaticamente tutte le altre impostazioni grafiche.",
    ["TOGGLE_DESC_ffxAntiAliasingMode"] = "Leviga i bordi frastagliati degli oggetti. Le modalità superiori offrono qualità migliore ma usano più risorse della GPU.",
    ["TOGGLE_DESC_colorblindMode"] = "Attiva regolazioni dei colori adatte ai daltonici. Scegli una modalità adatta al tuo tipo di deficit della visione dei colori.",

    ["TOGGLE_DESC_disableServerNagle"] = "Riduce la latenza di rete disattivando il raggruppamento dei pacchetti. Può aumentare leggermente l'uso della banda.",
    ["TOGGLE_DESC_gxFixLag"] = "Riduce il ritardo di input del cursore del mouse su alcuni sistemi modificando la coda di rendering.",
    ["TOGGLE_DESC_reducedLagTolerance"] = "Ottimizza le prestazioni di rete per connessioni a bassa latenza. Può influire sull'accodamento delle magie.",
    ["TOGGLE_DESC_SpellQueueWindow"] = "Con quanti millisecondi di anticipo puoi accodare la prossima magia prima che finisca quella attuale. Valori più alti sono più tolleranti nei tempi.",

    ["TOGGLE_OPT_chatStyle_classic"] = "Classico",
    ["TOGGLE_OPT_chatStyle_im"] = "Moderno",
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
    ["TOGGLE_OPT_ffxAntiAliasingMode_0"] = "No",
    ["TOGGLE_OPT_ffxAntiAliasingMode_1"] = "CMAA",
    ["TOGGLE_OPT_ffxAntiAliasingMode_2"] = "FXAA basso",
    ["TOGGLE_OPT_ffxAntiAliasingMode_3"] = "FXAA alto",
    ["TOGGLE_OPT_colorblindMode_0"] = "No",
    ["TOGGLE_OPT_colorblindMode_1"] = "Protanopia",
    ["TOGGLE_OPT_colorblindMode_2"] = "Deuteranopia",
    ["TOGGLE_OPT_colorblindMode_3"] = "Tritanopia",

    ["BINDING_HEADER_ONEWOW_QOL"] = "|cFF00FF00OneWoW|r QoL",
    ["BINDING_NAME_QUESTITEM_1"] = "Oggetto missione 1",
    ["BINDING_NAME_QUESTITEM_2"] = "Oggetto missione 2",
    ["BINDING_NAME_QUESTITEM_3"] = "Oggetto missione 3",
    ["BINDING_NAME_QUESTITEM_4"] = "Oggetto missione 4",
    ["BINDING_NAME_BAGITEM_1"] = "Oggetto borsa 1",
    ["BINDING_NAME_BAGITEM_2"] = "Oggetto borsa 2",
    ["BINDING_NAME_BAGITEM_3"] = "Oggetto borsa 3",
    ["BINDING_NAME_BAGITEM_4"] = "Oggetto borsa 4",
    ["BINDING_NAME_COPY_TEXT"] = "Copia testo",
})
