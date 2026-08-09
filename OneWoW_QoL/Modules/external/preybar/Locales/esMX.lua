local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["PREYBAR_TITLE"] = "Barra de caza de presa",
    ["PREYBAR_DESC"] = "Muestra una barra movible que sigue tu progreso de caza de presa (Frío > Tibio > Caliente > Listo) en la zona actual, con el jefe, la dificultad y los afijos de la caza activa. Desbloquéala para arrastrarla a su lugar.",

    ["PREYBAR_TOGGLE_BOSS"] = "Mostrar nombre del jefe",
    ["PREYBAR_TOGGLE_BOSS_DESC"] = "Muestra el nombre de la caza de presa activa sobre la barra.",
    ["PREYBAR_TOGGLE_DIFFICULTY"] = "Mostrar dificultad",
    ["PREYBAR_TOGGLE_DIFFICULTY_DESC"] = "Muestra la dificultad de la caza (Normal, Difícil, Pesadilla).",
    ["PREYBAR_TOGGLE_AFFIXES"] = "Mostrar afijos",
    ["PREYBAR_TOGGLE_AFFIXES_DESC"] = "Muestra los iconos de afijos de la caza activa bajo la barra.",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD"] = "Ocultar widget de Blizzard",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD_DESC"] = "Oculta el widget de progreso de caza de presa predeterminado de Blizzard mientras esta barra está activa.",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT"] = "Clic para marcar la ruta",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT_DESC"] = "Cuando la presa esté lista, haz clic en la barra para marcar en el mapa una ruta hacia la caza.",
    ["PREYBAR_TOGGLE_LOCK"] = "Bloquear posición",
    ["PREYBAR_TOGGLE_LOCK_DESC"] = "Bloquea la barra para que no se pueda arrastrar. Desactiva esto y abre este panel de ajustes para reposicionar la barra usando la vista previa de muestra.",

    ["PREYBAR_STATE_COLD"] = "Frío",
    ["PREYBAR_STATE_WARM"] = "Tibio",
    ["PREYBAR_STATE_HOT"] = "Caliente",
    ["PREYBAR_STATE_READY"] = "Listo",

    ["PREYBAR_DIFFICULTY_NORMAL"] = "Normal",
    ["PREYBAR_DIFFICULTY_HARD"] = "Difícil",
    ["PREYBAR_DIFFICULTY_NIGHTMARE"] = "Pesadilla",

    ["PREYBAR_AFFIX_AMBUSH"] = "Emboscada",
    ["PREYBAR_AFFIX_TORMENT"] = "Tormento",
    ["PREYBAR_AFFIX_SEEPING_GORE"] = "Sangre rezumante",
    ["PREYBAR_AFFIX_ECHO"] = "Eco de depredación",
    ["PREYBAR_AFFIX_BLOODY"] = "Orden sangrienta",

    ["PREYBAR_ADVICE_AMBUSHED"] = "¡Emboscado!",
    ["PREYBAR_ADVICE_KILL"] = "¡Mata algo!",
    ["PREYBAR_ADVICE_READY"] = "La presa está lista, ¡cázala!",

    ["PREYBAR_STATE_LABEL"] = "%s  %d%%",
    ["PREYBAR_DEMO_BOSS"] = "Presa de muestra",
    ["PREYBAR_DRAG_HINT"] = "Desbloquear para arrastrar  -  Barra de caza de presa",
    ["PREYBAR_CLICK_WAYPOINT_HINT"] = "Haz clic para marcar una ruta hacia tu presa",
    ["PREYBAR_OPACITY_FMT"] = "Opacidad: %d%%",
    ["PREYBAR_SAMPLE_BAR_HEADER"] = "Barra de ejemplo",
    ["PREYBAR_SETTINGS_HINT"] = "Se muestra una barra de ejemplo mientras este panel está abierto para que puedas posicionarla. Desactiva Bloquear posición para arrastrarla y luego vuelve a bloquearla. Fuera de este panel, la barra solo aparece durante una caza de presa activa.",
})
