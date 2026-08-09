local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["PREYBAR_TITLE"] = "Barra di caccia alla preda",
    ["PREYBAR_DESC"] = "Mostra una barra spostabile che tiene traccia dei tuoi progressi di caccia alla preda (Freddo > Tiepido > Caldo > Pronto) per la zona attuale, con boss, difficoltà e affissi della caccia attiva. Sbloccala per trascinarla al suo posto.",

    ["PREYBAR_TOGGLE_BOSS"] = "Mostra nome del boss",
    ["PREYBAR_TOGGLE_BOSS_DESC"] = "Mostra il nome della caccia alla preda attiva sopra la barra.",
    ["PREYBAR_TOGGLE_DIFFICULTY"] = "Mostra difficoltà",
    ["PREYBAR_TOGGLE_DIFFICULTY_DESC"] = "Mostra la difficoltà della caccia (Normale, Difficile, Incubo).",
    ["PREYBAR_TOGGLE_AFFIXES"] = "Mostra affissi",
    ["PREYBAR_TOGGLE_AFFIXES_DESC"] = "Mostra le icone degli affissi della caccia attiva sotto la barra.",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD"] = "Nascondi widget Blizzard",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD_DESC"] = "Nasconde il widget predefinito di progresso della caccia alla preda di Blizzard mentre questa barra è attiva.",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT"] = "Clic per impostare il waypoint",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT_DESC"] = "Quando la preda è pronta, clicca sulla barra per impostare sulla mappa un waypoint verso la caccia.",
    ["PREYBAR_TOGGLE_LOCK"] = "Blocca posizione",
    ["PREYBAR_TOGGLE_LOCK_DESC"] = "Blocca la barra in modo che non possa essere trascinata. Disattiva questa opzione e apri questo pannello delle impostazioni per riposizionare la barra usando l'anteprima di esempio.",

    ["PREYBAR_STATE_COLD"] = "Freddo",
    ["PREYBAR_STATE_WARM"] = "Tiepido",
    ["PREYBAR_STATE_HOT"] = "Caldo",
    ["PREYBAR_STATE_READY"] = "Pronto",

    ["PREYBAR_DIFFICULTY_NORMAL"] = "Normale",
    ["PREYBAR_DIFFICULTY_HARD"] = "Difficile",
    ["PREYBAR_DIFFICULTY_NIGHTMARE"] = "Incubo",

    ["PREYBAR_AFFIX_AMBUSH"] = "Imboscata",
    ["PREYBAR_AFFIX_TORMENT"] = "Tormento",
    ["PREYBAR_AFFIX_SEEPING_GORE"] = "Sangue colante",
    ["PREYBAR_AFFIX_ECHO"] = "Eco di predazione",
    ["PREYBAR_AFFIX_BLOODY"] = "Comando sanguinario",

    ["PREYBAR_ADVICE_AMBUSHED"] = "In imboscata!",
    ["PREYBAR_ADVICE_KILL"] = "Uccidi qualcosa!",
    ["PREYBAR_ADVICE_READY"] = "La preda è pronta - cacciala!",

    ["PREYBAR_STATE_LABEL"] = "%s  %d%%",
    ["PREYBAR_DEMO_BOSS"] = "Preda di esempio",
    ["PREYBAR_DRAG_HINT"] = "Sblocca per trascinare  -  Barra di caccia alla preda",
    ["PREYBAR_CLICK_WAYPOINT_HINT"] = "Clicca per impostare un waypoint verso la tua preda",
    ["PREYBAR_OPACITY_FMT"] = "Opacità: %d%%",
    ["PREYBAR_SAMPLE_BAR_HEADER"] = "Barra di esempio",
    ["PREYBAR_SETTINGS_HINT"] = "Mentre questo pannello è aperto viene mostrata una barra di esempio così puoi posizionarla. Disattiva Blocca posizione per trascinarla, poi bloccala di nuovo. Al di fuori di questo pannello la barra appare solo durante una caccia alla preda attiva.",
})
