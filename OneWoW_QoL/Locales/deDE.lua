local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — pending native review
OneWoW.Locale:Register(ADDON_NAME, "deDE", {

    ["ADDON_TITLE"] = "OneWoW - QoL",
    ["ADDON_TITLE_SHORT"] = "QoL",
    ["ADDON_TITLE_FRAME"] = "OneWoW - QoL",
    ["ADDON_LOADED"] = "geladen.",

    ["TAB_FEATURES"] = "QoL-Funktionen",
    ["TAB_TOGGLES"] = "Schalter",

    ["FEATURES_LIST_TITLE"] = "Funktionen",
    ["FEATURES_FAVORITE_TT_TITLE"] = "Favorit",
    ["FEATURES_FAVORITE_TT_DESC"] = "Heftet diese Funktion oben an den Favoritenbereich. Erneut klicken, um sie aus den Favoriten zu entfernen.",
    ["FEATURES_DETAIL_TITLE"] = "Details",
    ["FEATURES_EMPTY"] = "Keine Module geladen.",
    ["FEATURES_NO_SELECTION"] = "Wählt eine Funktion aus der Liste.",
    ["FEATURES_ENABLED"] = "Aktiviert",
    ["FEATURES_DISABLED"] = "Deaktiviert",
    ["FEATURES_CATEGORY_LABEL"] = "Kategorie:",
    ["FEATURES_VERSION_LABEL"] = "Version:",
    ["FEATURES_AUTHOR_LABEL"] = "Autor:",
    ["FEATURES_CONTACT_LABEL"] = "Kontakt:",
    ["FEATURES_LINK_LABEL"] = "Link:",
    ["FEATURES_DETAILS_BTN"] = "Details",
    ["FEATURES_DETAILS_TITLE"] = "Moduldetails",
    ["FEATURES_TOGGLES_HEADER"] = "Modulschalter",
    ["FEATURES_ON"] = "An",
    ["FEATURES_OFF"] = "Aus",
    ["FEATURES_PREVIEW_LABEL"] = "Vorschau:",

    ["CATEGORY_AUTOMATION"] = "Automatisierung",
    ["CATEGORY_INTERFACE"] = "Interface",
    ["CATEGORY_SOCIAL"] = "Sozial",
    ["CATEGORY_COMBAT"] = "Kampf",
    ["CATEGORY_ECONOMY"] = "Wirtschaft",
    ["CATEGORY_UTILITY"] = "Werkzeuge",

    ["TOGGLES_LIST_TITLE"] = "Spielschalter",
    ["TOGGLES_FAVORITE_TT_TITLE"] = "Favorit",
    ["TOGGLES_FAVORITE_TT_DESC"] = "Heftet diesen Schalter oben an den Favoritenbereich. Erneut klicken, um ihn aus den Favoriten zu entfernen.",
    ["TOGGLES_DETAIL_TITLE"] = "Schalterdetails",
    ["TOGGLES_COMING_SOON"] = "Spielschalter werden in einem zukünftigen Update hinzugefügt.",
    ["TOGGLES_NO_SELECTION"] = "Wählt einen Schalter aus der Liste.",

    ["SETTINGS_THEME_HEADER"] = "Farbschema",
    ["SETTINGS_THEME_DESC"] = "Wählt ein Farbschema. Änderungen werden sofort übernommen.",
    ["SETTINGS_LANGUAGE_DESC"] = "Wählt eure bevorzugte Sprache. Änderungen werden sofort übernommen.",
    ["SETTINGS_DEVELOPER_HEADER"] = "Entwicklerinformationen",
    ["SETTINGS_DEVELOPER_DESC"] = "Dieses Addon unterstützt externe Module. Fügt QoL-Funktionen hinzu, indem ihr einen Modulordner in Modules\\external\\ erstellt. Nutzt die Schaltfläche „Entwicklerhilfe“ für die vollständige Dokumentation.",
    ["SETTINGS_DEV_HELP_BTN"] = "Entwicklerhilfe",

    ["DEVHELP_TITLE"] = "Entwicklerhandbuch für Module",
    ["DEVHELP_BODY"] = [[DROP-IN-MODULSYSTEM

Erstellt euren Ordner:
  Modules\external\yourmodule\

Dateien (module.lua wird ZUERST geladen):
  module.lua      - Metadaten + Registrierung
  yourmodule.lua  - Modullogik
  Locales\enUS.lua  (koKR.lua optional)

Definiert euer Modul in module.lua
(die id existiert NUR hier):
  local ADDON_NAME, ns = ...
  ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "yourmodule",
    title       = "MY_TITLE",
    category    = "AUTOMATION",
    description = "MY_DESC",
    version     = "1.0",
    author      = "Euer Name",
    contact     = "eure@email.com",
    link        = "https://eureseite.com",
    toggles = {
      { id = "myToggle", label = "MY_TOGGLE_LABEL",
        description = "MY_TOGGLE_DESC", default = true },
    },
    defaultEnabled = true,
  })

Holt es in yourmodule.lua + eure
Locale-Ansicht (beim Laden erfassen, nie zur Laufzeit):
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

Der Scope ist ADDON_NAME .. "." .. id, z. B.
OneWoW_QoL.yourmodule (abgeleitet, keine
fest codierte Scope-Zeichenkette).

Verweist per id auf ein anderes Modul:
  ns.ModuleRegistry:GetById("othermodule")
Verwendet niemals ns.<X>Module.

Die Werte title, description sowie das Label
und die Beschreibung der Schalter sind
Locale-Schlüssel. author, contact und link
sind optional. contact und link erscheinen als
kopierbare Felder im Modul-Detailfenster.

Verfügbare Kategorien:
  AUTOMATION  INTERFACE  SOCIAL
  COMBAT      ECONOMY    UTILITY

Fügt eure Dateien im TOC unter EXTERNAL
MODULES hinzu. Reihenfolge: module.lua ZUERST,
dann die Locales, dann eure Code-Dateien.

SavedVariables-Datenbankbereich:
  OneWoW_QoL_DB.modules.yourmodule

Siehe Modules\external\autodelete\ für ein
vollständiges, funktionierendes Beispiel.]],

    ["MINIMAP_TOOLTIP_TITLE"] = "OneWoW - QoL",
    ["MINIMAP_TOOLTIP_HINT"] = "Klicken zum Öffnen",
    ["MINIMAP_RIGHT_CLICK"] = "Rechtsklick für Optionen",
    ["MINIMAP_OPEN"] = "QoL öffnen",

    ["LANG_ENGLISH"] = "Englisch",
    ["LANG_KOREAN"] = "Koreanisch",


    ["SEARCH_HINT"] = "Filtern...",
    ["TOGGLES_STATUS_ALL"] = "%d CVars werden angezeigt",
    ["TOGGLES_STATUS_FILTERED"] = "%d von %d werden angezeigt",
    ["FEATURES_STATUS_ENABLED"] = "%d von %d aktiviert",

    ["TOGGLES_CVAR_LABEL"] = "CVar:",
    ["TOGGLES_ON"] = "An",
    ["TOGGLES_OFF"] = "Aus",
    ["TOGGLES_VALUE_LABEL"] = "Wert:",

    ["TOGGLE_CAT_GAMEPLAY"] = "Spielmechanik",
    ["TOGGLE_CAT_INTERFACE"] = "Interface",
    ["TOGGLE_CAT_NAMEPLATES"] = "Namensplaketten",
    ["TOGGLE_CAT_COMBAT_TEXT"] = "Kampftext",
    ["TOGGLE_CAT_CAMERA"] = "Kamera",
    ["TOGGLE_CAT_CHAT"] = "Chat & Sozial",
    ["TOGGLE_CAT_AUDIO"] = "Audio",
    ["TOGGLE_CAT_GRAPHICS"] = "Grafik",
    ["TOGGLE_CAT_NETWORK"] = "Netzwerk",

    ["TOGGLE_NAME_autoLootDefault"] = "Automatisch plündern",
    ["TOGGLE_NAME_autoSelfCast"] = "Automatisch auf sich selbst wirken",
    ["TOGGLE_NAME_autoDismount"] = "Automatisch absitzen",
    ["TOGGLE_NAME_autoDismountFlying"] = "Automatisch absitzen im Flug",
    ["TOGGLE_NAME_autoStand"] = "Automatisch aufstehen",
    ["TOGGLE_NAME_autoUnshift"] = "Automatisch Gestalt verlassen",
    ["TOGGLE_NAME_assistAttack"] = "Angriff unterstützen",
    ["TOGGLE_NAME_ActionButtonUseKeyDown"] = "Aktionstasten beim Drücken",
    ["TOGGLE_NAME_deselectOnClick"] = "Ziel bei Klick abwählen",
    ["TOGGLE_NAME_stopAutoAttackOnTargetChange"] = "Autoangriff bei Zielwechsel stoppen",
    ["TOGGLE_NAME_lootUnderMouse"] = "Beutefenster unter dem Mauszeiger",
    ["TOGGLE_NAME_lootLeftmostBag"] = "In linkste Tasche plündern",
    ["TOGGLE_NAME_interactOnLeftClick"] = "Interagieren per Linksklick",
    ["TOGGLE_NAME_autointeract"] = "Automatisch interagieren",
    ["TOGGLE_NAME_autoClearAFK"] = "Abwesend automatisch aufheben",

    ["TOGGLE_NAME_countdownForCooldowns"] = "Abklingzeit-Countdown",
    ["TOGGLE_NAME_displaySpellActivationOverlays"] = "Zauber-Proc-Leuchten",
    ["TOGGLE_NAME_alwaysShowActionBars"] = "Aktionsleisten immer anzeigen",
    ["TOGGLE_NAME_lockActionBars"] = "Aktionsleisten sperren",
    ["TOGGLE_NAME_bottomLeftActionBar"] = "Untere linke Aktionsleiste",
    ["TOGGLE_NAME_bottomRightActionBar"] = "Untere rechte Aktionsleiste",
    ["TOGGLE_NAME_rightActionBar"] = "Rechte Aktionsleiste",
    ["TOGGLE_NAME_rightTwoActionBar"] = "Rechte Aktionsleiste 2",
    ["TOGGLE_NAME_displayFreeBagSlots"] = "Freie Taschenplätze anzeigen",
    ["TOGGLE_NAME_buffDurations"] = "Stärkungszauberdauer anzeigen",
    ["TOGGLE_NAME_showTargetOfTarget"] = "Ziel des Ziels anzeigen",
    ["TOGGLE_NAME_showTargetCastbar"] = "Zauberleiste des Ziels anzeigen",
    ["TOGGLE_NAME_fullSizeFocusFrame"] = "Fokusfenster in voller Größe",
    ["TOGGLE_NAME_breakUpLargeNumbers"] = "Große Zahlen formatieren",
    ["TOGGLE_NAME_alwaysCompareItems"] = "Gegenstände immer vergleichen",
    ["TOGGLE_NAME_missingTransmogSourceInItemTooltips"] = "Fehlende Transmogrifizierungsquelle",
    ["TOGGLE_NAME_autoQuestWatch"] = "Quests automatisch verfolgen",
    ["TOGGLE_NAME_autoQuestProgress"] = "Quest-Fortschrittsfenster",
    ["TOGGLE_NAME_mapFade"] = "Karte beim Bewegen ausblenden",
    ["TOGGLE_NAME_rotateMinimap"] = "Minikarte drehen",
    ["TOGGLE_NAME_useUiScale"] = "Eigene UI-Skalierung aktivieren",
    ["TOGGLE_NAME_uiScale"] = "UI-Skalierung",

    ["TOGGLE_NAME_nameplateShowEnemies"] = "Feindliche Namensplaketten anzeigen",
    ["TOGGLE_NAME_nameplateShowFriends"] = "Freundliche Namensplaketten anzeigen",
    ["TOGGLE_NAME_nameplateShowSelf"] = "Persönliche Namensplakette anzeigen",
    ["TOGGLE_NAME_nameplatePersonalShowAlways"] = "Persönliche Plakette immer anzeigen",
    ["TOGGLE_NAME_nameplatePersonalShowInCombat"] = "Persönliche Plakette im Kampf",
    ["TOGGLE_NAME_ShowClassColorInNameplate"] = "Klassenfarben auf feindlichen Plaketten",
    ["TOGGLE_NAME_ShowClassColorInFriendlyNameplate"] = "Klassenfarben auf freundlichen Plaketten",
    ["TOGGLE_NAME_ShowNamePlateLoseAggroFlash"] = "Aufblinken bei Bedrohungsverlust",
    ["TOGGLE_NAME_namePlateEnemyClickThrough"] = "Feindliche Plaketten durchklickbar",
    ["TOGGLE_NAME_namePlateFriendlyClickThrough"] = "Freundliche Plaketten durchklickbar",
    ["TOGGLE_NAME_nameplateMaxDistance"] = "Sichtweite der Namensplaketten",
    ["TOGGLE_NAME_nameplateGlobalScale"] = "Globale Plakettenskalierung",
    ["TOGGLE_NAME_namePlateEnemySize"] = "Größe feindlicher Plaketten",
    ["TOGGLE_NAME_namePlateFriendlySize"] = "Größe freundlicher Plaketten",

    ["TOGGLE_NAME_enableFloatingCombatText"] = "Schwebender Kampftext",
    ["TOGGLE_NAME_enableCombatText"] = "Standard-Kampftext",
    ["TOGGLE_NAME_fctCombatState"] = "Kampfstatustext",
    ["TOGGLE_NAME_floatingCombatTextCombatDamage"] = "Schadenszahlen",
    ["TOGGLE_NAME_floatingCombatTextCombatHealing"] = "Heilungszahlen",
    ["TOGGLE_NAME_floatingCombatTextCombatState"] = "Text bei Kampfbeginn/-ende",
    ["TOGGLE_NAME_floatingCombatTextAuras"] = "Text bei Stärkungs-/Schwächungsänderung",
    ["TOGGLE_NAME_floatingCombatTextDodgeParryMiss"] = "Text bei Ausweichen/Parieren/Verfehlen",
    ["TOGGLE_NAME_floatingCombatTextHonorGains"] = "Ehregewinne",
    ["TOGGLE_NAME_floatingCombatTextRepChanges"] = "Rufänderungen",
    ["TOGGLE_NAME_floatingCombatTextEnergyGains"] = "Energie-/Managewinne",
    ["TOGGLE_NAME_floatingCombatTextComboPoints"] = "Kombopunktgewinne",
    ["TOGGLE_NAME_floatingCombatTextReactives"] = "Reaktive Procs",
    ["TOGGLE_NAME_floatingCombatTextPetMeleeDamage"] = "Nahkampfschaden des Begleiters",

    ["TOGGLE_NAME_cameraBobbing"] = "Kamerawackeln",
    ["TOGGLE_NAME_cameraWaterCollision"] = "Kamera-Wasserkollision",
    ["TOGGLE_NAME_flightAngleLookAhead"] = "Flugwinkel-Vorausblick",
    ["TOGGLE_NAME_cameraDynamicPitch"] = "Dynamische Kameraneigung",
    ["TOGGLE_NAME_cameraDistanceMaxZoomFactor"] = "Maximale Kamera-Zoomdistanz",
    ["TOGGLE_NAME_cameraYawMoveSpeed"] = "Horizontale Kamera-Drehgeschwindigkeit",
    ["TOGGLE_NAME_cameraPitchMoveSpeed"] = "Vertikale Kamera-Drehgeschwindigkeit",
    ["TOGGLE_NAME_cameraZoomSpeed"] = "Kamera-Zoomgeschwindigkeit",

    ["TOGGLE_NAME_chatBubbles"] = "Sprechblasen (/sagen)",
    ["TOGGLE_NAME_chatBubblesParty"] = "Sprechblasen (Gruppe)",
    ["TOGGLE_NAME_colorChatNamesByClass"] = "Klassenfarben im Chat",
    ["TOGGLE_NAME_blockTrades"] = "Handelsanfragen blockieren",
    ["TOGGLE_NAME_blockChannelInvites"] = "Kanaleinladungen blockieren",
    ["TOGGLE_NAME_guildMemberNotify"] = "Gildenanmeldungs-Benachrichtigungen",
    ["TOGGLE_NAME_removeChatDelay"] = "Chat-Verzögerung entfernen",
    ["TOGGLE_NAME_chatMouseScroll"] = "Chat mit Mausrad scrollen",
    ["TOGGLE_NAME_profanityFilter"] = "Schimpfwortfilter",
    ["TOGGLE_NAME_chatStyle"] = "Chat-Stil",

    ["TOGGLE_NAME_Sound_EnableAllSound"] = "Alle Geräusche",
    ["TOGGLE_NAME_Sound_EnableMusic"] = "Musik",
    ["TOGGLE_NAME_Sound_EnableSFX"] = "Soundeffekte",
    ["TOGGLE_NAME_Sound_EnableDialog"] = "Dialog / Stimme",
    ["TOGGLE_NAME_Sound_EnableAmbience"] = "Umgebung",
    ["TOGGLE_NAME_Sound_EnablePetSounds"] = "Begleitergeräusche",
    ["TOGGLE_NAME_FootstepSounds"] = "Schrittgeräusche",
    ["TOGGLE_NAME_Sound_MasterVolume"] = "Gesamtlautstärke",
    ["TOGGLE_NAME_Sound_MusicVolume"] = "Musiklautstärke",
    ["TOGGLE_NAME_Sound_SFXVolume"] = "Effektlautstärke",

    ["TOGGLE_NAME_ffxDeath"] = "Todesbildschirm-Effekt",
    ["TOGGLE_NAME_ffxGlow"] = "Bloom-/Leuchteffekt",
    ["TOGGLE_NAME_ffxNether"] = "Nether-Visualeffekt",
    ["TOGGLE_NAME_emphasizeMySpellEffects"] = "Eigene Zaubereffekte hervorheben",
    ["TOGGLE_NAME_doNotFlashLowHealthWarning"] = "Aufblinken bei niedrigem Leben deaktivieren",
    ["TOGGLE_NAME_hdPlayerModels"] = "HD-Spielermodelle",
    ["TOGGLE_NAME_findYourselfAnywhere"] = "Charakterhervorhebung",
    ["TOGGLE_NAME_gxVSync"] = "VSync",
    ["TOGGLE_NAME_gxTripleBuffer"] = "Triple Buffering",
    ["TOGGLE_NAME_particleDensity"] = "Partikeldichte",
    ["TOGGLE_NAME_maxFPS"] = "Max. FPS (Vordergrund)",
    ["TOGGLE_NAME_maxFPSBk"] = "Max. FPS (Hintergrund)",
    ["TOGGLE_NAME_gxMaxFrameLatency"] = "Maximale Bildlatenz",
    ["TOGGLE_NAME_RenderScale"] = "Renderskalierung",
    ["TOGGLE_NAME_graphicsQuality"] = "Grafikqualitäts-Voreinstellung",
    ["TOGGLE_NAME_ffxAntiAliasingMode"] = "Kantenglättungsmodus",
    ["TOGGLE_NAME_colorblindMode"] = "Farbenblindheitsmodus",

    ["TOGGLE_NAME_disableServerNagle"] = "Nagle-Algorithmus deaktivieren",
    ["TOGGLE_NAME_gxFixLag"] = "Eingabeverzögerung beheben",
    ["TOGGLE_NAME_reducedLagTolerance"] = "Reduzierte Verzögerungstoleranz",
    ["TOGGLE_NAME_SpellQueueWindow"] = "Zauberwarteschlangenfenster",

    ["TOGGLE_DESC_autoLootDefault"] = "Sammelt automatisch alle Beute auf, ohne jeden Gegenstand anzuklicken.",
    ["TOGGLE_DESC_autoSelfCast"] = "Wirkt hilfreiche Zauber auf euch selbst, wenn ihr kein Ziel ausgewählt habt.",
    ["TOGGLE_DESC_autoDismount"] = "Steigt automatisch vom Reittier ab, wenn ihr sammeln, mit NSCs sprechen oder in den Kampf eintreten wollt.",
    ["TOGGLE_DESC_autoDismountFlying"] = "Steigt automatisch ab, sogar im Flug. Warnung: Ihr werdet fallen!",
    ["TOGGLE_DESC_autoStand"] = "Steht automatisch auf, wenn ihr euch im Sitzen bewegen oder handeln wollt.",
    ["TOGGLE_DESC_autoUnshift"] = "Verlässt automatisch Gestalten, wenn ihr eine Fähigkeit nutzt, die das erfordert.",
    ["TOGGLE_DESC_assistAttack"] = "Wenn ihr ein freundliches Ziel unterstützt, greift ihr automatisch dessen Ziel an.",
    ["TOGGLE_DESC_ActionButtonUseKeyDown"] = "AN: Zauber werden sofort beim Tastendruck ausgelöst. AUS: Zauber werden beim Loslassen ausgelöst, sodass ihr zuvor die Reichweite prüfen könnt.",
    ["TOGGLE_DESC_deselectOnClick"] = "Hebt euer Ziel auf, wenn ihr auf leeren Boden klickt.",
    ["TOGGLE_DESC_stopAutoAttackOnTargetChange"] = "Stoppt den Autoangriff, wenn ihr zu einem neuen Ziel wechselt.",
    ["TOGGLE_DESC_lootUnderMouse"] = "Öffnet das Beutefenster dort, wo sich euer Mauszeiger befindet, statt an einer festen Position.",
    ["TOGGLE_DESC_lootLeftmostBag"] = "Legt erbeutete Gegenstände in eure linkste Tasche statt in die rechteste.",
    ["TOGGLE_DESC_interactOnLeftClick"] = "Linksklick auf NSCs und Objekte zum Interagieren statt Rechtsklick.",
    ["TOGGLE_DESC_autointeract"] = "Ein Rechtsklick auf einen NSC spricht ihn automatisch an oder plündert ihn.",
    ["TOGGLE_DESC_autoClearAFK"] = "Entfernt automatisch euren Abwesend-Status, wenn ihr euch bewegt oder handelt.",

    ["TOGGLE_DESC_countdownForCooldowns"] = "Zeigt Countdown-Zahlen in der Mitte von Fähigkeitssymbolen während der Abklingzeit an.",
    ["TOGGLE_DESC_displaySpellActivationOverlays"] = "Zeigt leuchtende Ränder an Fähigkeiten, wenn Procs auslösen, etwa Sofortzauber-Procs.",
    ["TOGGLE_DESC_alwaysShowActionBars"] = "Hält Aktionsleisten auch leer sichtbar und verhindert, dass sie sich verbergen.",
    ["TOGGLE_DESC_lockActionBars"] = "Verhindert versehentliches Herausziehen von Fähigkeiten aus euren Aktionsleisten.",
    ["TOGGLE_DESC_bottomLeftActionBar"] = "Zeigt die zusätzliche Aktionsleiste über eurer Hauptleiste auf der linken Seite.",
    ["TOGGLE_DESC_bottomRightActionBar"] = "Zeigt die zusätzliche Aktionsleiste über eurer Hauptleiste auf der rechten Seite.",
    ["TOGGLE_DESC_rightActionBar"] = "Zeigt die vertikale Aktionsleiste auf der rechten Bildschirmseite.",
    ["TOGGLE_DESC_rightTwoActionBar"] = "Zeigt eine zweite vertikale Aktionsleiste auf der rechten Bildschirmseite.",
    ["TOGGLE_DESC_displayFreeBagSlots"] = "Zeigt die Anzahl leerer Taschenplätze auf eurer Taschenleiste an.",
    ["TOGGLE_DESC_buffDurations"] = "Zeigt die verbleibende Zeit eurer Stärkungszauber als Countdown-Zahlen an.",
    ["TOGGLE_DESC_showTargetOfTarget"] = "Zeigt an, wen euer Ziel anvisiert. Nützlich für Tanks und Heiler.",
    ["TOGGLE_DESC_showTargetCastbar"] = "Zeigt eine Zauberleiste für euer aktuelles Ziel, damit ihr seht, was es wirkt.",
    ["TOGGLE_DESC_fullSizeFocusFrame"] = "Verwendet ein Einheitenfenster in voller Größe für euren Fokus statt des kleinen Fensters.",
    ["TOGGLE_DESC_breakUpLargeNumbers"] = "Zeigt große Zahlen mit Trennzeichen, etwa 1.000.000 statt 1000000.",
    ["TOGGLE_DESC_alwaysCompareItems"] = "Zeigt automatisch den Vergleichstooltip beim Überfahren von Ausrüstung. Keine Umschalttaste nötig.",
    ["TOGGLE_DESC_missingTransmogSourceInItemTooltips"] = "Zeigt in Gegenstandstooltips, ob ihr dieses Aussehen besitzt, aber nicht von dieser bestimmten Gegenstandsquelle.",
    ["TOGGLE_DESC_autoQuestWatch"] = "Fügt neue Quests automatisch eurer Questverfolgung auf der rechten Bildschirmseite hinzu.",
    ["TOGGLE_DESC_autoQuestProgress"] = "Zeigt Popup-Benachrichtigungen, wenn ihr bei Quests Fortschritte macht.",
    ["TOGGLE_DESC_mapFade"] = "Macht die Karte beim Bewegen transparent, damit ihr die Spielwelt weiter seht.",
    ["TOGGLE_DESC_rotateMinimap"] = "Die Minikarte dreht sich mit eurer Blickrichtung wie ein Kompass, statt mit Norden oben fixiert zu bleiben.",
    ["TOGGLE_DESC_useUiScale"] = "Erlaubt die Anpassung der UI-Skalierung. Aktiviert dies, um den UI-Skalierungsregler zu nutzen.",
    ["TOGGLE_DESC_uiScale"] = "Gesamtgröße der Benutzeroberfläche. Erfordert die aktivierte eigene UI-Skalierung.",

    ["TOGGLE_DESC_nameplateShowEnemies"] = "Zeigt Namensplaketten mit Lebensbalken über feindlichen Einheiten an.",
    ["TOGGLE_DESC_nameplateShowFriends"] = "Zeigt Namensplaketten mit Lebensbalken über freundlichen Einheiten an.",
    ["TOGGLE_DESC_nameplateShowSelf"] = "Zeigt eure persönliche Ressourcenleiste als Namensplakette über eurem Charakter.",
    ["TOGGLE_DESC_nameplatePersonalShowAlways"] = "Zeigt eure persönliche Ressourcen-Plakette immer an, auch außerhalb des Kampfes.",
    ["TOGGLE_DESC_nameplatePersonalShowInCombat"] = "Zeigt eure persönliche Ressourcen-Plakette nur im Kampf an.",
    ["TOGGLE_DESC_ShowClassColorInNameplate"] = "Färbt feindliche Namensplaketten im PvP nach Klasse.",
    ["TOGGLE_DESC_ShowClassColorInFriendlyNameplate"] = "Färbt freundliche Namensplaketten nach Klasse.",
    ["TOGGLE_DESC_ShowNamePlateLoseAggroFlash"] = "Lässt eine Namensplakette aufblinken, wenn ihr als Tank die Bedrohung gegen einen Gegner verliert.",
    ["TOGGLE_DESC_namePlateEnemyClickThrough"] = "Klickt durch feindliche Namensplaketten hindurch. Ihr seht Lebensbalken, könnt aber nicht zum Anvisieren klicken.",
    ["TOGGLE_DESC_namePlateFriendlyClickThrough"] = "Klickt durch freundliche Namensplaketten hindurch. Ihr seht Lebensbalken, könnt aber Verbündete nicht zum Anvisieren anklicken.",
    ["TOGGLE_DESC_nameplateMaxDistance"] = "Maximale Entfernung in Metern, in der Namensplaketten sichtbar sind. In Instanzen beträgt das Maximum 60.",
    ["TOGGLE_DESC_nameplateGlobalScale"] = "Hauptgrößenmultiplikator für alle Namensplaketten. Wirkt nach allen anderen Skalierungseinstellungen.",
    ["TOGGLE_DESC_namePlateEnemySize"] = "Größenmultiplikator für feindliche Namensplaketten. Größer macht sie im Kampf besser sichtbar.",
    ["TOGGLE_DESC_namePlateFriendlySize"] = "Größenmultiplikator für Namensplaketten freundlicher Spieler.",

    ["TOGGLE_DESC_enableFloatingCombatText"] = "Zeigt schwebende Schadens- und Heilungszahlen, die von Gegnern und Verbündeten aufsteigen.",
    ["TOGGLE_DESC_enableCombatText"] = "Zeigt Schadens- und Heilungszahlen im Standard-Kampftextbereich nahe eurem Charakter an.",
    ["TOGGLE_DESC_fctCombatState"] = "Zeigt schwebende Texthinweise wie „Ihr seid jetzt im Kampf!“ über das Standard-Kampftextsystem an.",
    ["TOGGLE_DESC_floatingCombatTextCombatDamage"] = "Zeigt den von euch verursachten Schaden als schwebende Zahlen.",
    ["TOGGLE_DESC_floatingCombatTextCombatHealing"] = "Zeigt die euch zuteilwerdende Heilung als schwebende grüne Zahlen.",
    ["TOGGLE_DESC_floatingCombatTextCombatState"] = "Zeigt Kampfbeginn und -ende als schwebende Textnachrichten.",
    ["TOGGLE_DESC_floatingCombatTextAuras"] = "Zeigt als schwebenden Text an, wenn ihr Stärkungs- und Schwächungszauber erhaltet oder verliert.",
    ["TOGGLE_DESC_floatingCombatTextDodgeParryMiss"] = "Zeigt die Ergebnisse Ausweichen, Parieren und Verfehlen als schwebenden Text.",
    ["TOGGLE_DESC_floatingCombatTextHonorGains"] = "Zeigt Ehregewinne im PvP als schwebenden Text.",
    ["TOGGLE_DESC_floatingCombatTextRepChanges"] = "Zeigt Rufgewinne und -verluste als schwebenden Text.",
    ["TOGGLE_DESC_floatingCombatTextEnergyGains"] = "Zeigt Energie-, Wut- und Managewinne als schwebenden Text.",
    ["TOGGLE_DESC_floatingCombatTextComboPoints"] = "Zeigt Kombopunktgewinne als schwebenden Text.",
    ["TOGGLE_DESC_floatingCombatTextReactives"] = "Zeigt Procs reaktiver Fähigkeiten als schwebenden Text.",
    ["TOGGLE_DESC_floatingCombatTextPetMeleeDamage"] = "Zeigt den Nahkampfschaden eures Begleiters als schwebende Zahlen.",

    ["TOGGLE_DESC_cameraBobbing"] = "Die Kamera wippt beim Gehen und Laufen sanft auf und ab. Immersiver, kann aber Übelkeit verursachen.",
    ["TOGGLE_DESC_cameraWaterCollision"] = "Verhindert, dass die Kamera unter Wasser gerät, wenn euer Charakter über der Oberfläche ist.",
    ["TOGGLE_DESC_flightAngleLookAhead"] = "Euer Flugreittier neigt sich, um die Flugrichtung anzuzeigen, für ein realistischeres Gefühl.",
    ["TOGGLE_DESC_cameraDynamicPitch"] = "Die Kamera neigt sich automatisch je nach Bewegungsrichtung. Das ist die Action-Cam-Funktion.",
    ["TOGGLE_DESC_cameraDistanceMaxZoomFactor"] = "Multiplikator für die maximale Kamera-Zoomdistanz. Höhere Werte erlauben weiteres Herauszoomen.",
    ["TOGGLE_DESC_cameraYawMoveSpeed"] = "Wie schnell sich die Kamera nach links und rechts dreht.",
    ["TOGGLE_DESC_cameraPitchMoveSpeed"] = "Wie schnell sich die Kamera nach oben und unten neigt.",
    ["TOGGLE_DESC_cameraZoomSpeed"] = "Wie schnell die Kamera mit dem Mausrad hinein- und herauszoomt.",

    ["TOGGLE_DESC_chatBubbles"] = "Zeigt Sprechblasen über den Köpfen von Charakteren, wenn sie /sagen oder /schreien nutzen.",
    ["TOGGLE_DESC_chatBubblesParty"] = "Zeigt Sprechblasen für Gruppen- und Schlachtzugchat über den Köpfen an.",
    ["TOGGLE_DESC_colorChatNamesByClass"] = "Färbt Spielernamen im Chat nach ihrer Klasse.",
    ["TOGGLE_DESC_blockTrades"] = "Verhindert, dass andere Spieler Handelsfenster mit euch öffnen.",
    ["TOGGLE_DESC_blockChannelInvites"] = "Verhindert, dass andere Spieler euch in Chatkanäle einladen.",
    ["TOGGLE_DESC_guildMemberNotify"] = "Zeigt eine Chatnachricht an, wenn Gildenmitglieder sich an- oder abmelden.",
    ["TOGGLE_DESC_removeChatDelay"] = "Entfernt die Anti-Spam-Verzögerung zwischen dem Senden von Chatnachrichten.",
    ["TOGGLE_DESC_chatMouseScroll"] = "Scrollt mit dem Mausrad durch den Chatverlauf.",
    ["TOGGLE_DESC_profanityFilter"] = "Ersetzt Schimpfwörter im Chat durch Symbole.",
    ["TOGGLE_DESC_chatStyle"] = "Klassisch verwendet getrennte Chatfenster. Modern verwendet einen Chatstil mit Reitern.",

    ["TOGGLE_DESC_Sound_EnableAllSound"] = "Hauptschalter für das gesamte Spielaudio. Ausschalten macht alles stumm.",
    ["TOGGLE_DESC_Sound_EnableMusic"] = "Spielt Hintergrundmusik in Gebieten und während Ereignissen.",
    ["TOGGLE_DESC_Sound_EnableSFX"] = "Spielt Soundeffekte, einschließlich Fähigkeiten, Kampfgeräusche und UI-Klicks.",
    ["TOGGLE_DESC_Sound_EnableDialog"] = "Spielt NSC-Sprachausgabe und Questdialog-Audio.",
    ["TOGGLE_DESC_Sound_EnableAmbience"] = "Spielt Umgebungsgeräusche wie Wind, Vögel und Wasser.",
    ["TOGGLE_DESC_Sound_EnablePetSounds"] = "Spielt Geräusche eures Begleiters wie Knurren und Bewegung.",
    ["TOGGLE_DESC_FootstepSounds"] = "Spielt Schrittgeräusche beim Gehen und Laufen.",
    ["TOGGLE_DESC_Sound_MasterVolume"] = "Gesamtlautstärke des Spiels. Beeinflusst alle anderen Lautstärkeregler.",
    ["TOGGLE_DESC_Sound_MusicVolume"] = "Lautstärke der Hintergrundmusik.",
    ["TOGGLE_DESC_Sound_SFXVolume"] = "Lautstärke der Soundeffekte, einschließlich Fähigkeiten und Kampf.",

    ["TOGGLE_DESC_ffxDeath"] = "Zeigt beim Tod einen entsättigten Graustufen-Bildschirmeffekt.",
    ["TOGGLE_DESC_ffxGlow"] = "Aktiviert den weichen Bloom-Leuchteffekt um helle Objekte.",
    ["TOGGLE_DESC_ffxNether"] = "Aktiviert besondere Visualeffekte im Nether und in Leerenbereichen.",
    ["TOGGLE_DESC_emphasizeMySpellEffects"] = "Macht eure eigenen Zaubereffekte im Vergleich zu denen anderer Spieler besser sichtbar.",
    ["TOGGLE_DESC_doNotFlashLowHealthWarning"] = "Deaktiviert das rote Aufblinken des Bildschirms bei kritisch niedrigem Leben.",
    ["TOGGLE_DESC_hdPlayerModels"] = "Verwendet hochauflösende Spielercharaktermodelle. Sehen besser aus, brauchen aber mehr Speicher.",
    ["TOGGLE_DESC_findYourselfAnywhere"] = "Zeigt einen Hervorhebungskreis unter eurem Charakter, damit ihr euch im Gewühl immer findet.",
    ["TOGGLE_DESC_gxVSync"] = "Begrenzt die Bilder auf die Bildwiederholrate eures Monitors. Verhindert Tearing, fügt aber eine leichte Eingabeverzögerung hinzu.",
    ["TOGGLE_DESC_gxTripleBuffer"] = "Triple Buffering für eine gleichmäßigere Bildausgabe. Fügt eine leichte Eingabeverzögerung hinzu.",
    ["TOGGLE_DESC_particleDensity"] = "Wie viele Zaubereffekte und Partikel gleichzeitig erscheinen. Niedrigere Werte verbessern die FPS in vollen Schlachtzügen.",
    ["TOGGLE_DESC_maxFPS"] = "Maximale Bilder pro Sekunde, wenn das Spielfenster aktiv ist. 0 für unbegrenzt.",
    ["TOGGLE_DESC_maxFPSBk"] = "Maximale Bilder pro Sekunde, wenn das Spielfenster im Hintergrund ist. Niedrigere Werte sparen Energie beim Alt-Tab.",
    ["TOGGLE_DESC_gxMaxFrameLatency"] = "Maximale Anzahl im Voraus zu berechnender Bilder. Niedrigere Werte verringern die Eingabeverzögerung. Höhere Werte erzeugen eine gleichmäßigere Ausgabe.",
    ["TOGGLE_DESC_RenderScale"] = "Interner Auflösungsmultiplikator. Werte über 1.0 nutzen Supersampling für ein schärferes Bild. Werte unter 1.0 verbessern die Leistung.",
    ["TOGGLE_DESC_graphicsQuality"] = "Haupt-Grafikqualitätsvoreinstellung. Ihre Änderung passt automatisch alle anderen Grafikeinstellungen an.",
    ["TOGGLE_DESC_ffxAntiAliasingMode"] = "Glättet ausgefranste Kanten an Objekten. Höhere Modi bieten bessere Qualität, brauchen aber mehr GPU-Ressourcen.",
    ["TOGGLE_DESC_colorblindMode"] = "Aktiviert farbenblindfreundliche Farbanpassungen. Wählt einen Modus passend zu eurer Art der Farbsehschwäche.",

    ["TOGGLE_DESC_disableServerNagle"] = "Verringert die Netzwerklatenz durch Deaktivieren der Paketbündelung. Kann die Bandbreitennutzung leicht erhöhen.",
    ["TOGGLE_DESC_gxFixLag"] = "Verringert auf manchen Systemen die Eingabeverzögerung des Mauszeigers durch Anpassen der Renderwarteschlange.",
    ["TOGGLE_DESC_reducedLagTolerance"] = "Optimiert die Netzwerkleistung für Verbindungen mit geringer Latenz. Kann das Zauberwarteschlangenverhalten beeinflussen.",
    ["TOGGLE_DESC_SpellQueueWindow"] = "Wie viele Millisekunden im Voraus ihr euren nächsten Zauber einreihen könnt, bevor der aktuelle endet. Höhere Werte sind beim Timing nachsichtiger.",

    ["TOGGLE_OPT_chatStyle_classic"] = "Klassisch",
    ["TOGGLE_OPT_chatStyle_im"] = "Modern",
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
    ["TOGGLE_OPT_ffxAntiAliasingMode_0"] = "Aus",
    ["TOGGLE_OPT_ffxAntiAliasingMode_1"] = "CMAA",
    ["TOGGLE_OPT_ffxAntiAliasingMode_2"] = "FXAA niedrig",
    ["TOGGLE_OPT_ffxAntiAliasingMode_3"] = "FXAA hoch",
    ["TOGGLE_OPT_colorblindMode_0"] = "Aus",
    ["TOGGLE_OPT_colorblindMode_1"] = "Protanopie",
    ["TOGGLE_OPT_colorblindMode_2"] = "Deuteranopie",
    ["TOGGLE_OPT_colorblindMode_3"] = "Tritanopie",

    ["BINDING_HEADER_ONEWOW_QOL"] = "|cFF00FF00OneWoW|r QoL",
    ["BINDING_NAME_QUESTITEM_1"] = "Questgegenstand 1",
    ["BINDING_NAME_QUESTITEM_2"] = "Questgegenstand 2",
    ["BINDING_NAME_QUESTITEM_3"] = "Questgegenstand 3",
    ["BINDING_NAME_QUESTITEM_4"] = "Questgegenstand 4",
    ["BINDING_NAME_BAGITEM_1"] = "Taschengegenstand 1",
    ["BINDING_NAME_BAGITEM_2"] = "Taschengegenstand 2",
    ["BINDING_NAME_BAGITEM_3"] = "Taschengegenstand 3",
    ["BINDING_NAME_BAGITEM_4"] = "Taschengegenstand 4",
    ["BINDING_NAME_COPY_TEXT"] = "Text kopieren",
})
