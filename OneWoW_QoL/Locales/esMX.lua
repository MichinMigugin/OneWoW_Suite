local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — esMX mirrored from esES, pending Latin-American review.
OneWoW.Locale:Register(ADDON_NAME, "esMX", {

    ["ADDON_TITLE"] = "OneWoW - QoL",
    ["ADDON_TITLE_SHORT"] = "QoL",
    ["ADDON_TITLE_FRAME"] = "OneWoW - QoL",
    ["ADDON_LOADED"] = "cargado.",

    ["TAB_FEATURES"] = "Funciones QoL",
    ["TAB_TOGGLES"] = "Interruptores",

    ["FEATURES_LIST_TITLE"] = "Funciones",
    ["FEATURES_FAVORITE_TT_TITLE"] = "Favorito",
    ["FEATURES_FAVORITE_TT_DESC"] = "Fija esta función en la sección de Favoritos en la parte superior. Haz clic de nuevo para quitarla de Favoritos.",
    ["FEATURES_DETAIL_TITLE"] = "Detalles",
    ["FEATURES_EMPTY"] = "Ningún módulo cargado.",
    ["FEATURES_NO_SELECTION"] = "Selecciona una función de la lista.",
    ["FEATURES_ENABLED"] = "Activado",
    ["FEATURES_DISABLED"] = "Desactivado",
    ["FEATURES_CATEGORY_LABEL"] = "Categoría:",
    ["FEATURES_VERSION_LABEL"] = "Versión:",
    ["FEATURES_AUTHOR_LABEL"] = "Autor:",
    ["FEATURES_CONTACT_LABEL"] = "Contacto:",
    ["FEATURES_LINK_LABEL"] = "Enlace:",
    ["FEATURES_DETAILS_BTN"] = "Detalles",
    ["FEATURES_DETAILS_TITLE"] = "Detalles del módulo",
    ["FEATURES_TOGGLES_HEADER"] = "Interruptores del módulo",
    ["FEATURES_ON"] = "Sí",
    ["FEATURES_OFF"] = "No",
    ["FEATURES_PREVIEW_LABEL"] = "Vista previa:",

    ["CATEGORY_AUTOMATION"] = "Automatización",
    ["CATEGORY_INTERFACE"] = "Interfaz",
    ["CATEGORY_SOCIAL"] = "Social",
    ["CATEGORY_COMBAT"] = "Combate",
    ["CATEGORY_ECONOMY"] = "Economía",
    ["CATEGORY_UTILITY"] = "Utilidad",

    ["TOGGLES_LIST_TITLE"] = "Indicadores del juego",
    ["TOGGLES_FAVORITE_TT_TITLE"] = "Favorito",
    ["TOGGLES_FAVORITE_TT_DESC"] = "Fija este interruptor en la sección de Favoritos en la parte superior. Haz clic de nuevo para quitarlo de Favoritos.",
    ["TOGGLES_DETAIL_TITLE"] = "Detalles del indicador",
    ["TOGGLES_COMING_SOON"] = "Los indicadores del juego se añadirán en una futura actualización.",
    ["TOGGLES_NO_SELECTION"] = "Selecciona un indicador de la lista.",

    ["SETTINGS_THEME_HEADER"] = "Tema de color",
    ["SETTINGS_THEME_DESC"] = "Elige un tema de color. Los cambios se aplican al instante.",
    ["SETTINGS_LANGUAGE_DESC"] = "Elige tu idioma preferido. Los cambios se aplican al instante.",
    ["SETTINGS_DEVELOPER_HEADER"] = "Información para desarrolladores",
    ["SETTINGS_DEVELOPER_DESC"] = "Este addon admite módulos externos. Añade funciones QoL creando una carpeta de módulo en Modules\\external\\. Usa el botón Ayuda al desarrollador para la documentación completa.",
    ["SETTINGS_DEV_HELP_BTN"] = "Ayuda al desarrollador",

    ["DEVHELP_TITLE"] = "Guía del desarrollador de módulos",
    ["DEVHELP_BODY"] = [[SISTEMA DE MÓDULOS DE INSERCIÓN

Crea tu carpeta:
  Modules\external\yourmodule\

Archivos (module.lua se carga PRIMERO):
  module.lua      - Metadatos + registro
  yourmodule.lua  - Lógica del módulo
  Locales\enUS.lua  (koKR.lua opcional)

En module.lua define tu módulo
(el id existe SOLO aquí):
  local ADDON_NAME, ns = ...
  ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "yourmodule",
    title       = "MY_TITLE",
    category    = "AUTOMATION",
    description = "MY_DESC",
    version     = "1.0",
    author      = "Tu nombre",
    contact     = "tu@email.com",
    link        = "https://tusitio.com",
    toggles = {
      { id = "myToggle", label = "MY_TOGGLE_LABEL",
        description = "MY_TOGGLE_DESC", default = true },
    },
    defaultEnabled = true,
  })

En yourmodule.lua, obtenlo + tu
vista de locale (captúrala al cargar, nunca en ejecución):
  local _, ns = ...
  local M, L = ns.ModuleRegistry:Current()
  if not M then return end

  function M:OnEnable() end
  function M:OnDisable() end
  function M:OnToggle(id, val) end

En Locales\enUS.lua:
  local _, ns = ...
  local M = ns.ModuleRegistry:Current()
  OneWoW.Locale:Register(M._scope, "enUS", {
    ["MY_TITLE"] = "My Title",
    ["MY_DESC"]  = "What it does",
  })

El scope es ADDON_NAME .. "." .. id, p. ej.
OneWoW_QoL.yourmodule (derivado, sin
cadena de scope codificada a mano).

Referencia otro módulo por su id:
  ns.ModuleRegistry:GetById("othermodule")
Nunca uses ns.<X>Module.

Los valores title, description, así como la
etiqueta y la descripción de los interruptores
son claves de locale. author, contact y link
son opcionales. contact y link aparecen como
cuadros copiables en la ventana de Detalles del módulo.

Categorías disponibles:
  AUTOMATION  INTERFACE  SOCIAL
  COMBAT      ECONOMY    UTILITY

Añade tus archivos al TOC bajo EXTERNAL
MODULES. Orden: module.lua PRIMERO, luego
los Locales, luego tus archivos de código.

Espacio de base de datos SavedVariables:
  OneWoW_QoL_DB.modules.yourmodule

Consulta Modules\external\autodelete\ para un
ejemplo completo y funcional.]],

    ["MINIMAP_TOOLTIP_TITLE"] = "OneWoW - QoL",
    ["MINIMAP_TOOLTIP_HINT"] = "Haz clic para abrir",
    ["MINIMAP_RIGHT_CLICK"] = "Clic derecho para opciones",
    ["MINIMAP_OPEN"] = "Abrir QoL",

    ["LANG_ENGLISH"] = "Inglés",
    ["LANG_KOREAN"] = "Coreano",


    ["SEARCH_HINT"] = "Filtrar...",
    ["TOGGLES_STATUS_ALL"] = "Mostrando %d CVars",
    ["TOGGLES_STATUS_FILTERED"] = "Mostrando %d de %d",
    ["FEATURES_STATUS_ENABLED"] = "%d de %d activados",

    ["TOGGLES_CVAR_LABEL"] = "CVar:",
    ["TOGGLES_ON"] = "Sí",
    ["TOGGLES_OFF"] = "No",
    ["TOGGLES_VALUE_LABEL"] = "Valor:",

    ["TOGGLE_CAT_GAMEPLAY"] = "Jugabilidad",
    ["TOGGLE_CAT_INTERFACE"] = "Interfaz",
    ["TOGGLE_CAT_NAMEPLATES"] = "Placas de identificación",
    ["TOGGLE_CAT_COMBAT_TEXT"] = "Texto de combate",
    ["TOGGLE_CAT_CAMERA"] = "Cámara",
    ["TOGGLE_CAT_CHAT"] = "Chat y social",
    ["TOGGLE_CAT_AUDIO"] = "Audio",
    ["TOGGLE_CAT_GRAPHICS"] = "Gráficos",
    ["TOGGLE_CAT_NETWORK"] = "Red",

    ["TOGGLE_NAME_autoLootDefault"] = "Saqueo automático",
    ["TOGGLE_NAME_autoSelfCast"] = "Lanzamiento automático sobre uno mismo",
    ["TOGGLE_NAME_autoDismount"] = "Desmontar automáticamente",
    ["TOGGLE_NAME_autoDismountFlying"] = "Desmontar en vuelo",
    ["TOGGLE_NAME_autoStand"] = "Levantarse automáticamente",
    ["TOGGLE_NAME_autoUnshift"] = "Abandonar forma automáticamente",
    ["TOGGLE_NAME_assistAttack"] = "Ataque de asistencia",
    ["TOGGLE_NAME_ActionButtonUseKeyDown"] = "Botones de acción al pulsar",
    ["TOGGLE_NAME_deselectOnClick"] = "Deseleccionar objetivo al hacer clic",
    ["TOGGLE_NAME_stopAutoAttackOnTargetChange"] = "Parar ataque automático al cambiar de objetivo",
    ["TOGGLE_NAME_lootUnderMouse"] = "Ventana de botín bajo el ratón",
    ["TOGGLE_NAME_lootLeftmostBag"] = "Saquear en la bolsa más a la izquierda",
    ["TOGGLE_NAME_interactOnLeftClick"] = "Interactuar con clic izquierdo",
    ["TOGGLE_NAME_autointeract"] = "Interacción automática",
    ["TOGGLE_NAME_autoClearAFK"] = "Quitar ausencia automáticamente",

    ["TOGGLE_NAME_countdownForCooldowns"] = "Cuenta atrás de reutilización",
    ["TOGGLE_NAME_displaySpellActivationOverlays"] = "Destello de proc de hechizo",
    ["TOGGLE_NAME_alwaysShowActionBars"] = "Mostrar siempre las barras de acción",
    ["TOGGLE_NAME_lockActionBars"] = "Bloquear barras de acción",
    ["TOGGLE_NAME_bottomLeftActionBar"] = "Barra de acción inferior izquierda",
    ["TOGGLE_NAME_bottomRightActionBar"] = "Barra de acción inferior derecha",
    ["TOGGLE_NAME_rightActionBar"] = "Barra de acción derecha",
    ["TOGGLE_NAME_rightTwoActionBar"] = "Barra de acción derecha 2",
    ["TOGGLE_NAME_displayFreeBagSlots"] = "Mostrar espacios de bolsa libres",
    ["TOGGLE_NAME_buffDurations"] = "Mostrar duración de beneficios",
    ["TOGGLE_NAME_showTargetOfTarget"] = "Mostrar objetivo del objetivo",
    ["TOGGLE_NAME_showTargetCastbar"] = "Mostrar barra de lanzamiento del objetivo",
    ["TOGGLE_NAME_fullSizeFocusFrame"] = "Marco de foco a tamaño completo",
    ["TOGGLE_NAME_breakUpLargeNumbers"] = "Formatear números grandes",
    ["TOGGLE_NAME_alwaysCompareItems"] = "Comparar objetos siempre",
    ["TOGGLE_NAME_missingTransmogSourceInItemTooltips"] = "Fuente de transfiguración ausente",
    ["TOGGLE_NAME_autoQuestWatch"] = "Seguir misiones automáticamente",
    ["TOGGLE_NAME_autoQuestProgress"] = "Avisos de progreso de misión",
    ["TOGGLE_NAME_mapFade"] = "El mapa se atenúa al moverse",
    ["TOGGLE_NAME_rotateMinimap"] = "Rotar minimapa",
    ["TOGGLE_NAME_useUiScale"] = "Activar escala de interfaz personalizada",
    ["TOGGLE_NAME_uiScale"] = "Escala de la interfaz",

    ["TOGGLE_NAME_nameplateShowEnemies"] = "Mostrar placas de enemigos",
    ["TOGGLE_NAME_nameplateShowFriends"] = "Mostrar placas de aliados",
    ["TOGGLE_NAME_nameplateShowSelf"] = "Mostrar placa personal",
    ["TOGGLE_NAME_nameplatePersonalShowAlways"] = "Placa personal siempre visible",
    ["TOGGLE_NAME_nameplatePersonalShowInCombat"] = "Placa personal en combate",
    ["TOGGLE_NAME_ShowClassColorInNameplate"] = "Colores de clase en placas enemigas",
    ["TOGGLE_NAME_ShowClassColorInFriendlyNameplate"] = "Colores de clase en placas aliadas",
    ["TOGGLE_NAME_ShowNamePlateLoseAggroFlash"] = "Destello al perder la amenaza",
    ["TOGGLE_NAME_namePlateEnemyClickThrough"] = "Placas enemigas no clicables",
    ["TOGGLE_NAME_namePlateFriendlyClickThrough"] = "Placas aliadas no clicables",
    ["TOGGLE_NAME_nameplateMaxDistance"] = "Distancia de visión de las placas",
    ["TOGGLE_NAME_nameplateGlobalScale"] = "Escala global de las placas",
    ["TOGGLE_NAME_namePlateEnemySize"] = "Tamaño de las placas enemigas",
    ["TOGGLE_NAME_namePlateFriendlySize"] = "Tamaño de las placas aliadas",

    ["TOGGLE_NAME_enableFloatingCombatText"] = "Texto de combate flotante",
    ["TOGGLE_NAME_enableCombatText"] = "Texto de combate predeterminado",
    ["TOGGLE_NAME_fctCombatState"] = "Texto de estado de combate",
    ["TOGGLE_NAME_floatingCombatTextCombatDamage"] = "Números de daño",
    ["TOGGLE_NAME_floatingCombatTextCombatHealing"] = "Números de sanación",
    ["TOGGLE_NAME_floatingCombatTextCombatState"] = "Texto de entrada/salida de combate",
    ["TOGGLE_NAME_floatingCombatTextAuras"] = "Texto de cambio de beneficio/perjuicio",
    ["TOGGLE_NAME_floatingCombatTextDodgeParryMiss"] = "Texto de esquivar/parar/fallar",
    ["TOGGLE_NAME_floatingCombatTextHonorGains"] = "Ganancias de honor",
    ["TOGGLE_NAME_floatingCombatTextRepChanges"] = "Cambios de reputación",
    ["TOGGLE_NAME_floatingCombatTextEnergyGains"] = "Ganancias de energía/maná",
    ["TOGGLE_NAME_floatingCombatTextComboPoints"] = "Ganancias de puntos de combo",
    ["TOGGLE_NAME_floatingCombatTextReactives"] = "Procs reactivos",
    ["TOGGLE_NAME_floatingCombatTextPetMeleeDamage"] = "Daño cuerpo a cuerpo de mascota",

    ["TOGGLE_NAME_cameraBobbing"] = "Balanceo de cámara",
    ["TOGGLE_NAME_cameraWaterCollision"] = "Colisión de cámara con el agua",
    ["TOGGLE_NAME_flightAngleLookAhead"] = "Anticipación del ángulo de vuelo",
    ["TOGGLE_NAME_cameraDynamicPitch"] = "Inclinación dinámica de cámara",
    ["TOGGLE_NAME_cameraDistanceMaxZoomFactor"] = "Distancia máxima de alejamiento de cámara",
    ["TOGGLE_NAME_cameraYawMoveSpeed"] = "Velocidad de giro horizontal de cámara",
    ["TOGGLE_NAME_cameraPitchMoveSpeed"] = "Velocidad de inclinación vertical de cámara",
    ["TOGGLE_NAME_cameraZoomSpeed"] = "Velocidad de zoom de cámara",

    ["TOGGLE_NAME_chatBubbles"] = "Bocadillos de diálogo (/decir)",
    ["TOGGLE_NAME_chatBubblesParty"] = "Bocadillos de diálogo (Grupo)",
    ["TOGGLE_NAME_colorChatNamesByClass"] = "Colores de clase en el chat",
    ["TOGGLE_NAME_blockTrades"] = "Bloquear solicitudes de intercambio",
    ["TOGGLE_NAME_blockChannelInvites"] = "Bloquear invitaciones a canales",
    ["TOGGLE_NAME_guildMemberNotify"] = "Avisos de conexión de hermandad",
    ["TOGGLE_NAME_removeChatDelay"] = "Quitar retardo del chat",
    ["TOGGLE_NAME_chatMouseScroll"] = "Desplazar el chat con la rueda",
    ["TOGGLE_NAME_profanityFilter"] = "Filtro de lenguaje soez",
    ["TOGGLE_NAME_chatStyle"] = "Estilo de chat",

    ["TOGGLE_NAME_Sound_EnableAllSound"] = "Todo el sonido",
    ["TOGGLE_NAME_Sound_EnableMusic"] = "Música",
    ["TOGGLE_NAME_Sound_EnableSFX"] = "Efectos de sonido",
    ["TOGGLE_NAME_Sound_EnableDialog"] = "Diálogo / Voz",
    ["TOGGLE_NAME_Sound_EnableAmbience"] = "Ambiente",
    ["TOGGLE_NAME_Sound_EnablePetSounds"] = "Sonidos de mascota",
    ["TOGGLE_NAME_FootstepSounds"] = "Sonidos de pasos",
    ["TOGGLE_NAME_Sound_MasterVolume"] = "Volumen principal",
    ["TOGGLE_NAME_Sound_MusicVolume"] = "Volumen de música",
    ["TOGGLE_NAME_Sound_SFXVolume"] = "Volumen de efectos",

    ["TOGGLE_NAME_ffxDeath"] = "Efecto de pantalla de muerte",
    ["TOGGLE_NAME_ffxGlow"] = "Efecto de resplandor / bloom",
    ["TOGGLE_NAME_ffxNether"] = "Efecto visual del Vacío Abisal",
    ["TOGGLE_NAME_emphasizeMySpellEffects"] = "Resaltar mis efectos de hechizo",
    ["TOGGLE_NAME_doNotFlashLowHealthWarning"] = "Desactivar destello de salud baja",
    ["TOGGLE_NAME_hdPlayerModels"] = "Modelos de jugador en HD",
    ["TOGGLE_NAME_findYourselfAnywhere"] = "Resaltado del personaje",
    ["TOGGLE_NAME_gxVSync"] = "VSync",
    ["TOGGLE_NAME_gxTripleBuffer"] = "Triple búfer",
    ["TOGGLE_NAME_particleDensity"] = "Densidad de partículas",
    ["TOGGLE_NAME_maxFPS"] = "FPS máx. (primer plano)",
    ["TOGGLE_NAME_maxFPSBk"] = "FPS máx. (segundo plano)",
    ["TOGGLE_NAME_gxMaxFrameLatency"] = "Latencia máxima de fotogramas",
    ["TOGGLE_NAME_RenderScale"] = "Escala de renderizado",
    ["TOGGLE_NAME_graphicsQuality"] = "Preajuste de calidad gráfica",
    ["TOGGLE_NAME_ffxAntiAliasingMode"] = "Modo de suavizado de bordes",
    ["TOGGLE_NAME_colorblindMode"] = "Modo para daltónicos",

    ["TOGGLE_NAME_disableServerNagle"] = "Desactivar algoritmo de Nagle",
    ["TOGGLE_NAME_gxFixLag"] = "Corregir retardo de entrada",
    ["TOGGLE_NAME_reducedLagTolerance"] = "Tolerancia de retardo reducida",
    ["TOGGLE_NAME_SpellQueueWindow"] = "Ventana de cola de hechizos",

    ["TOGGLE_DESC_autoLootDefault"] = "Recoge automáticamente todo el botín sin hacer clic en cada objeto.",
    ["TOGGLE_DESC_autoSelfCast"] = "Lanza hechizos beneficiosos sobre ti mismo cuando no tienes ningún objetivo seleccionado.",
    ["TOGGLE_DESC_autoDismount"] = "Te baja automáticamente de la montura cuando intentas recolectar, hablar con PNJ o entrar en combate.",
    ["TOGGLE_DESC_autoDismountFlying"] = "Te desmonta automáticamente incluso en vuelo. Advertencia: ¡caerás!",
    ["TOGGLE_DESC_autoStand"] = "Te levantas automáticamente cuando intentas moverte o actuar estando sentado.",
    ["TOGGLE_DESC_autoUnshift"] = "Abandona automáticamente las formas cuando usas una habilidad que lo requiere.",
    ["TOGGLE_DESC_assistAttack"] = "Cuando asistes a un objetivo aliado, atacas automáticamente a su objetivo.",
    ["TOGGLE_DESC_ActionButtonUseKeyDown"] = "Activado: los hechizos se lanzan al instante al pulsar la tecla. Desactivado: los hechizos se lanzan al soltarla, permitiéndote ver primero el alcance.",
    ["TOGGLE_DESC_deselectOnClick"] = "Anula tu objetivo cuando haces clic en el suelo vacío.",
    ["TOGGLE_DESC_stopAutoAttackOnTargetChange"] = "Detiene el ataque automático cuando cambias a un nuevo objetivo.",
    ["TOGGLE_DESC_lootUnderMouse"] = "Abre la ventana de botín donde esté el cursor del ratón en lugar de en una posición fija.",
    ["TOGGLE_DESC_lootLeftmostBag"] = "Coloca el botín en tu bolsa más a la izquierda en lugar de la más a la derecha.",
    ["TOGGLE_DESC_interactOnLeftClick"] = "Haz clic izquierdo en PNJ y objetos para interactuar en lugar de clic derecho.",
    ["TOGGLE_DESC_autointeract"] = "Hacer clic derecho en un PNJ le habla o lo saquea automáticamente.",
    ["TOGGLE_DESC_autoClearAFK"] = "Quita automáticamente tu estado de ausencia cuando te mueves o realizas cualquier acción.",

    ["TOGGLE_DESC_countdownForCooldowns"] = "Muestra los números de la cuenta atrás en el centro de los iconos de habilidad durante la reutilización.",
    ["TOGGLE_DESC_displaySpellActivationOverlays"] = "Muestra bordes brillantes en las habilidades cuando se activan procs, como los procs de lanzamiento instantáneo.",
    ["TOGGLE_DESC_alwaysShowActionBars"] = "Mantiene las barras de acción visibles aunque estén vacías, evitando que se oculten.",
    ["TOGGLE_DESC_lockActionBars"] = "Evita arrastrar accidentalmente habilidades fuera de tus barras de acción.",
    ["TOGGLE_DESC_bottomLeftActionBar"] = "Muestra la barra de acción adicional sobre tu barra principal, en el lado izquierdo.",
    ["TOGGLE_DESC_bottomRightActionBar"] = "Muestra la barra de acción adicional sobre tu barra principal, en el lado derecho.",
    ["TOGGLE_DESC_rightActionBar"] = "Muestra la barra de acción vertical en el lado derecho de la pantalla.",
    ["TOGGLE_DESC_rightTwoActionBar"] = "Muestra una segunda barra de acción vertical en el lado derecho de la pantalla.",
    ["TOGGLE_DESC_displayFreeBagSlots"] = "Muestra el número de espacios de bolsa vacíos en tu barra de bolsas.",
    ["TOGGLE_DESC_buffDurations"] = "Muestra el tiempo restante de tus beneficios como números de cuenta atrás.",
    ["TOGGLE_DESC_showTargetOfTarget"] = "Muestra a quién tiene como objetivo tu objetivo. Útil para tanques y sanadores.",
    ["TOGGLE_DESC_showTargetCastbar"] = "Muestra una barra de lanzamiento para tu objetivo actual para que veas lo que está lanzando.",
    ["TOGGLE_DESC_fullSizeFocusFrame"] = "Usa un marco de unidad a tamaño completo para tu foco en lugar del marco pequeño.",
    ["TOGGLE_DESC_breakUpLargeNumbers"] = "Muestra los números grandes con separadores, como 1.000.000 en lugar de 1000000.",
    ["TOGGLE_DESC_alwaysCompareItems"] = "Muestra automáticamente la información comparativa al pasar sobre el equipo. No hace falta la tecla Mayús.",
    ["TOGGLE_DESC_missingTransmogSourceInItemTooltips"] = "Indica en la información del objeto si posees esta apariencia, pero no de esta fuente de objeto concreta.",
    ["TOGGLE_DESC_autoQuestWatch"] = "Añade automáticamente las nuevas misiones a tu seguidor de misiones en el lado derecho de la pantalla.",
    ["TOGGLE_DESC_autoQuestProgress"] = "Muestra avisos emergentes cuando progresas en una misión.",
    ["TOGGLE_DESC_mapFade"] = "Hace que el mapa se vuelva transparente al moverte para que sigas viendo el mundo del juego.",
    ["TOGGLE_DESC_rotateMinimap"] = "El minimapa gira según tu orientación como una brújula en lugar de mantenerse fijo con el norte arriba.",
    ["TOGGLE_DESC_useUiScale"] = "Permite personalizar la escala de la interfaz. Actívalo para usar el control deslizante de escala.",
    ["TOGGLE_DESC_uiScale"] = "Tamaño general de la interfaz. Requiere que la escala de interfaz personalizada esté activada.",

    ["TOGGLE_DESC_nameplateShowEnemies"] = "Muestra placas de identificación con barra de salud sobre las unidades enemigas.",
    ["TOGGLE_DESC_nameplateShowFriends"] = "Muestra placas de identificación con barra de salud sobre las unidades aliadas.",
    ["TOGGLE_DESC_nameplateShowSelf"] = "Muestra tu barra de recurso personal como una placa sobre tu personaje.",
    ["TOGGLE_DESC_nameplatePersonalShowAlways"] = "Muestra siempre tu placa de recurso personal, incluso fuera de combate.",
    ["TOGGLE_DESC_nameplatePersonalShowInCombat"] = "Muestra tu placa de recurso personal solo durante el combate.",
    ["TOGGLE_DESC_ShowClassColorInNameplate"] = "Colorea las placas enemigas por clase en JcJ.",
    ["TOGGLE_DESC_ShowClassColorInFriendlyNameplate"] = "Colorea las placas aliadas por clase.",
    ["TOGGLE_DESC_ShowNamePlateLoseAggroFlash"] = "Hace destellar una placa cuando pierdes la amenaza sobre un enemigo como tanque.",
    ["TOGGLE_DESC_namePlateEnemyClickThrough"] = "Permite hacer clic a través de las placas enemigas. Ves las barras de salud pero no puedes hacer clic para fijar objetivo.",
    ["TOGGLE_DESC_namePlateFriendlyClickThrough"] = "Permite hacer clic a través de las placas aliadas. Ves las barras de salud pero no puedes hacer clic para fijar aliados.",
    ["TOGGLE_DESC_nameplateMaxDistance"] = "Distancia máxima en metros a la que son visibles las placas. El máximo es 60 en mazmorras.",
    ["TOGGLE_DESC_nameplateGlobalScale"] = "Multiplicador de tamaño principal para todas las placas. Afecta a todo tras los demás ajustes de escala.",
    ["TOGGLE_DESC_namePlateEnemySize"] = "Multiplicador de tamaño de las placas enemigas. Mayor las hace más fáciles de ver en combate.",
    ["TOGGLE_DESC_namePlateFriendlySize"] = "Multiplicador de tamaño de las placas de jugadores aliados.",

    ["TOGGLE_DESC_enableFloatingCombatText"] = "Muestra números flotantes de daño y sanación que ascienden desde enemigos y aliados.",
    ["TOGGLE_DESC_enableCombatText"] = "Muestra números de daño y sanación en el área de texto de combate predeterminada, cerca de tu personaje.",
    ["TOGGLE_DESC_fctCombatState"] = "Muestra avisos de texto flotante como «¡Ahora estás en combate!» mediante el sistema de texto de combate predeterminado.",
    ["TOGGLE_DESC_floatingCombatTextCombatDamage"] = "Muestra el daño que infliges como números flotantes.",
    ["TOGGLE_DESC_floatingCombatTextCombatHealing"] = "Muestra la sanación que recibes como números verdes flotantes.",
    ["TOGGLE_DESC_floatingCombatTextCombatState"] = "Muestra la entrada y salida de combate como mensajes de texto flotantes.",
    ["TOGGLE_DESC_floatingCombatTextAuras"] = "Muestra como texto flotante cuándo ganas o pierdes beneficios y perjuicios.",
    ["TOGGLE_DESC_floatingCombatTextDodgeParryMiss"] = "Muestra los resultados de Esquivar, Parar y Fallar como texto flotante.",
    ["TOGGLE_DESC_floatingCombatTextHonorGains"] = "Muestra las ganancias de puntos de honor como texto flotante en JcJ.",
    ["TOGGLE_DESC_floatingCombatTextRepChanges"] = "Muestra las ganancias y pérdidas de reputación como texto flotante.",
    ["TOGGLE_DESC_floatingCombatTextEnergyGains"] = "Muestra las ganancias de energía, ira y maná como texto flotante.",
    ["TOGGLE_DESC_floatingCombatTextComboPoints"] = "Muestra las ganancias de puntos de combo como texto flotante.",
    ["TOGGLE_DESC_floatingCombatTextReactives"] = "Muestra los procs de habilidades reactivas como texto flotante.",
    ["TOGGLE_DESC_floatingCombatTextPetMeleeDamage"] = "Muestra el daño cuerpo a cuerpo de tu mascota como números flotantes.",

    ["TOGGLE_DESC_cameraBobbing"] = "La cámara se balancea suavemente arriba y abajo al andar y correr. Más inmersivo, pero puede causar mareo.",
    ["TOGGLE_DESC_cameraWaterCollision"] = "Evita que la cámara se sumerja cuando tu personaje está sobre la superficie.",
    ["TOGGLE_DESC_flightAngleLookAhead"] = "Tu montura voladora se inclina para mostrar la dirección que sigues, para una sensación más realista.",
    ["TOGGLE_DESC_cameraDynamicPitch"] = "La cámara se inclina automáticamente según tu dirección de movimiento. Es la función Action Cam.",
    ["TOGGLE_DESC_cameraDistanceMaxZoomFactor"] = "Multiplicador de la distancia máxima de alejamiento de la cámara. Valores más altos permiten alejarse más.",
    ["TOGGLE_DESC_cameraYawMoveSpeed"] = "Velocidad a la que la cámara gira a izquierda y derecha.",
    ["TOGGLE_DESC_cameraPitchMoveSpeed"] = "Velocidad a la que la cámara se inclina arriba y abajo.",
    ["TOGGLE_DESC_cameraZoomSpeed"] = "Velocidad a la que la cámara se acerca y se aleja con la rueda del ratón.",

    ["TOGGLE_DESC_chatBubbles"] = "Muestra bocadillos de diálogo sobre las cabezas de los personajes cuando usan /decir o /gritar.",
    ["TOGGLE_DESC_chatBubblesParty"] = "Muestra bocadillos de diálogo del chat de grupo y banda sobre las cabezas de los personajes.",
    ["TOGGLE_DESC_colorChatNamesByClass"] = "Colorea los nombres de jugador en el chat según su clase.",
    ["TOGGLE_DESC_blockTrades"] = "Evita que otros jugadores abran ventanas de intercambio contigo.",
    ["TOGGLE_DESC_blockChannelInvites"] = "Evita que otros jugadores te inviten a canales de chat.",
    ["TOGGLE_DESC_guildMemberNotify"] = "Muestra un mensaje en el chat cuando los miembros de la hermandad se conectan o desconectan.",
    ["TOGGLE_DESC_removeChatDelay"] = "Elimina el retardo antispam entre el envío de mensajes de chat.",
    ["TOGGLE_DESC_chatMouseScroll"] = "Desplázate por el historial del chat con la rueda del ratón.",
    ["TOGGLE_DESC_profanityFilter"] = "Sustituye las palabrotas por símbolos en el chat.",
    ["TOGGLE_DESC_chatStyle"] = "Clásico usa ventanas de chat separadas. Moderno usa un estilo de chat con pestañas.",

    ["TOGGLE_DESC_Sound_EnableAllSound"] = "Interruptor principal de todo el audio del juego. Desactivarlo silencia todo.",
    ["TOGGLE_DESC_Sound_EnableMusic"] = "Reproduce música de fondo en las zonas y durante los eventos.",
    ["TOGGLE_DESC_Sound_EnableSFX"] = "Reproduce efectos de sonido, incluidas habilidades, sonidos de combate y clics de interfaz.",
    ["TOGGLE_DESC_Sound_EnableDialog"] = "Reproduce el doblaje de los PNJ y el audio de los diálogos de misión.",
    ["TOGGLE_DESC_Sound_EnableAmbience"] = "Reproduce sonidos ambientales del entorno como viento, pájaros y agua.",
    ["TOGGLE_DESC_Sound_EnablePetSounds"] = "Reproduce sonidos de tu mascota como gruñidos y movimiento.",
    ["TOGGLE_DESC_FootstepSounds"] = "Reproduce sonidos de pasos al andar y correr.",
    ["TOGGLE_DESC_Sound_MasterVolume"] = "Volumen general del juego. Afecta a todos los demás controles de volumen.",
    ["TOGGLE_DESC_Sound_MusicVolume"] = "Volumen de la música de fondo.",
    ["TOGGLE_DESC_Sound_SFXVolume"] = "Volumen de los efectos de sonido, incluidas habilidades y combate.",

    ["TOGGLE_DESC_ffxDeath"] = "Muestra un efecto de pantalla en escala de grises desaturada cuando mueres.",
    ["TOGGLE_DESC_ffxGlow"] = "Activa el suave efecto de resplandor bloom alrededor de los objetos brillantes.",
    ["TOGGLE_DESC_ffxNether"] = "Activa efectos visuales especiales en el Vacío Abisal y zonas del vacío.",
    ["TOGGLE_DESC_emphasizeMySpellEffects"] = "Hace tus propios efectos de hechizo más visibles frente a los de otros jugadores.",
    ["TOGGLE_DESC_doNotFlashLowHealthWarning"] = "Desactiva el destello rojo de pantalla que aparece cuando tu salud es críticamente baja.",
    ["TOGGLE_DESC_hdPlayerModels"] = "Usa modelos de personaje en alta definición. Lucen mejor pero consumen más memoria.",
    ["TOGGLE_DESC_findYourselfAnywhere"] = "Muestra un círculo resaltado bajo tu personaje para encontrarte siempre entre la multitud.",
    ["TOGGLE_DESC_gxVSync"] = "Limita los fotogramas a la frecuencia de refresco de tu monitor. Evita el desgarro pero añade un pequeño retardo de entrada.",
    ["TOGGLE_DESC_gxTripleBuffer"] = "Triple búfer para un ritmo de fotogramas más fluido. Añade un ligero retardo de entrada.",
    ["TOGGLE_DESC_particleDensity"] = "Cuántos efectos de hechizo y partículas aparecen a la vez. Valores más bajos mejoran los FPS en bandas concurridas.",
    ["TOGGLE_DESC_maxFPS"] = "Fotogramas por segundo máximos cuando la ventana del juego está activa. Pon 0 para ilimitado.",
    ["TOGGLE_DESC_maxFPSBk"] = "Fotogramas por segundo máximos cuando la ventana del juego está en segundo plano. Valores más bajos ahorran energía al cambiar de ventana.",
    ["TOGGLE_DESC_gxMaxFrameLatency"] = "Máximo de fotogramas en cola para renderizar. Valores más bajos reducen el retardo de entrada. Valores más altos producen una salida más fluida.",
    ["TOGGLE_DESC_RenderScale"] = "Multiplicador de resolución interna. Valores por encima de 1.0 aplican supermuestreo para una imagen más nítida. Por debajo de 1.0 mejoran el rendimiento.",
    ["TOGGLE_DESC_graphicsQuality"] = "Preajuste principal de calidad gráfica. Cambiarlo ajusta automáticamente todos los demás ajustes gráficos.",
    ["TOGGLE_DESC_ffxAntiAliasingMode"] = "Suaviza los bordes dentados de los objetos. Los modos superiores ofrecen mejor calidad pero usan más recursos de GPU.",
    ["TOGGLE_DESC_colorblindMode"] = "Activa ajustes de color adaptados al daltonismo. Elige un modo que coincida con tu tipo de deficiencia de visión del color.",

    ["TOGGLE_DESC_disableServerNagle"] = "Reduce la latencia de red desactivando el agrupamiento de paquetes. Puede aumentar ligeramente el uso de ancho de banda.",
    ["TOGGLE_DESC_gxFixLag"] = "Reduce el retardo de entrada del cursor del ratón en algunos sistemas modificando la cola de renderizado.",
    ["TOGGLE_DESC_reducedLagTolerance"] = "Optimiza el rendimiento de red para conexiones de baja latencia. Puede afectar al encolado de hechizos.",
    ["TOGGLE_DESC_SpellQueueWindow"] = "Con cuántos milisegundos de antelación puedes encolar tu siguiente hechizo antes de que termine el actual. Valores más altos son más tolerantes con el ritmo.",

    ["TOGGLE_OPT_chatStyle_classic"] = "Clásico",
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
    ["TOGGLE_OPT_ffxAntiAliasingMode_2"] = "FXAA bajo",
    ["TOGGLE_OPT_ffxAntiAliasingMode_3"] = "FXAA alto",
    ["TOGGLE_OPT_colorblindMode_0"] = "No",
    ["TOGGLE_OPT_colorblindMode_1"] = "Protanopia",
    ["TOGGLE_OPT_colorblindMode_2"] = "Deuteranopia",
    ["TOGGLE_OPT_colorblindMode_3"] = "Tritanopia",

    ["BINDING_HEADER_ONEWOW_QOL"] = "|cFF00FF00OneWoW|r QoL",
    ["BINDING_NAME_QUESTITEM_1"] = "Objeto de misión 1",
    ["BINDING_NAME_QUESTITEM_2"] = "Objeto de misión 2",
    ["BINDING_NAME_QUESTITEM_3"] = "Objeto de misión 3",
    ["BINDING_NAME_QUESTITEM_4"] = "Objeto de misión 4",
    ["BINDING_NAME_BAGITEM_1"] = "Objeto de bolsa 1",
    ["BINDING_NAME_BAGITEM_2"] = "Objeto de bolsa 2",
    ["BINDING_NAME_BAGITEM_3"] = "Objeto de bolsa 3",
    ["BINDING_NAME_BAGITEM_4"] = "Objeto de bolsa 4",
    ["BINDING_NAME_COPY_TEXT"] = "Copiar texto",
})
