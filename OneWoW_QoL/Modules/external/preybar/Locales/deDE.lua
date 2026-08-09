local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["PREYBAR_TITLE"] = "Beutejagd-Leiste",
    ["PREYBAR_DESC"] = "Zeigt eine bewegliche Leiste, die deinen Beutejagd-Fortschritt (Kalt > Warm > Heiß > Bereit) für die aktuelle Zone verfolgt, mit Boss, Schwierigkeit und Affixen der aktiven Jagd. Entsperre sie, um sie an ihren Platz zu ziehen.",

    ["PREYBAR_TOGGLE_BOSS"] = "Bossnamen anzeigen",
    ["PREYBAR_TOGGLE_BOSS_DESC"] = "Zeigt den Namen der aktiven Beutejagd über der Leiste an.",
    ["PREYBAR_TOGGLE_DIFFICULTY"] = "Schwierigkeit anzeigen",
    ["PREYBAR_TOGGLE_DIFFICULTY_DESC"] = "Zeigt die Jagdschwierigkeit an (Normal, Schwer, Albtraum).",
    ["PREYBAR_TOGGLE_AFFIXES"] = "Affixe anzeigen",
    ["PREYBAR_TOGGLE_AFFIXES_DESC"] = "Zeigt die Affixsymbole der aktiven Jagd unter der Leiste an.",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD"] = "Blizzard-Widget ausblenden",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD_DESC"] = "Blendet Blizzards Standard-Widget für den Beutejagd-Fortschritt aus, während diese Leiste aktiv ist.",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT"] = "Zum Setzen des Wegpunkts klicken",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT_DESC"] = "Wenn die Beute bereit ist, klicke auf die Leiste, um einen Kartenwegpunkt zur Jagd zu setzen.",
    ["PREYBAR_TOGGLE_LOCK"] = "Position sperren",
    ["PREYBAR_TOGGLE_LOCK_DESC"] = "Sperrt die Leiste, sodass sie nicht gezogen werden kann. Schalte dies aus und öffne dieses Einstellungspanel, um die Leiste mit der Beispielvorschau neu zu positionieren.",

    ["PREYBAR_STATE_COLD"] = "Kalt",
    ["PREYBAR_STATE_WARM"] = "Warm",
    ["PREYBAR_STATE_HOT"] = "Heiß",
    ["PREYBAR_STATE_READY"] = "Bereit",

    ["PREYBAR_DIFFICULTY_NORMAL"] = "Normal",
    ["PREYBAR_DIFFICULTY_HARD"] = "Schwer",
    ["PREYBAR_DIFFICULTY_NIGHTMARE"] = "Albtraum",

    ["PREYBAR_AFFIX_AMBUSH"] = "Hinterhalt",
    ["PREYBAR_AFFIX_TORMENT"] = "Qual",
    ["PREYBAR_AFFIX_SEEPING_GORE"] = "Sickerndes Blut",
    ["PREYBAR_AFFIX_ECHO"] = "Echo der Jagd",
    ["PREYBAR_AFFIX_BLOODY"] = "Blutiger Befehl",

    ["PREYBAR_ADVICE_AMBUSHED"] = "Überfallen!",
    ["PREYBAR_ADVICE_KILL"] = "Töte etwas!",
    ["PREYBAR_ADVICE_READY"] = "Die Beute ist bereit – jage sie!",

    ["PREYBAR_STATE_LABEL"] = "%s  %d%%",
    ["PREYBAR_DEMO_BOSS"] = "Beispielbeute",
    ["PREYBAR_DRAG_HINT"] = "Entsperren zum Ziehen  -  Beutejagd-Leiste",
    ["PREYBAR_CLICK_WAYPOINT_HINT"] = "Klicken, um einen Wegpunkt zu deiner Beute zu setzen",
    ["PREYBAR_OPACITY_FMT"] = "Deckkraft: %d%%",
    ["PREYBAR_SAMPLE_BAR_HEADER"] = "Beispielleiste",
    ["PREYBAR_SETTINGS_HINT"] = "Während dieses Panel geöffnet ist, wird eine Beispielleiste angezeigt, damit du sie positionieren kannst. Schalte „Position sperren“ aus, um sie zu ziehen, und sperre sie dann wieder. Außerhalb dieses Panels erscheint die Leiste nur während einer aktiven Beutejagd.",
})
