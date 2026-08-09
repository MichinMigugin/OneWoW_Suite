local ADDON_NAME = ...

OneWoW.Locale:Register(ADDON_NAME, "esES", {

    ["CTX_OPEN_DD"] = "Abrir Direct Deposit",
    ["ADDON_TITLE"] = "Depósito Directo",
    ["ADDON_SUBTITLE"] = "Gestión Automática de Oro del Banco de la banda guerrera",


    ["TAB_GOLD"] = "Oro",

    ["DIRECT_DEPOSIT_TITLE"] = "Depósito Directo",
    ["DIRECT_DEPOSIT_DESCRIPTION"] = "Gestiona automáticamente el oro entre tu personaje y el Banco de la banda guerrera. Establece una cantidad objetivo para mantener en tu personaje, y el sistema depositará el exceso de oro o retirará cuando te falte. Perfecto para gestionar oro entre múltiples personajes.",
    ["DIRECT_DEPOSIT_ENABLE"] = "Habilitar Depósito Directo",
    ["DIRECT_DEPOSIT_ENABLE_DESC"] = "Depositar o retirar oro automáticamente del Banco de la banda guerrera para mantener una cantidad objetivo en tu personaje cuando abras el banco.",

    ["ACCOUNT_SETTINGS"] = "Configuración de Cuenta",
    ["ACCOUNT_SETTINGS_DESC"] = "Esta configuración se aplica a todos los personajes de tu cuenta.",

    ["CHARACTER_SETTINGS"] = "Anulación Específica del Personaje",
    ["CHARACTER_SETTINGS_DESC"] = "Anula la configuración de la cuenta con configuración personalizada para este personaje específico. Útil para alts bancarios o personajes con necesidades especiales de gestión de oro.",

    ["USE_CHAR_SETTINGS"] = "Usar Configuración Específica del Personaje",
    ["USE_CHAR_SETTINGS_DESC"] = "Habilita esto para usar diferentes configuraciones para este personaje en lugar de la configuración de la cuenta.",

    ["TARGET_GOLD"] = "Cantidad a Mantener en el Personaje",
    ["TARGET_GOLD_DESC"] = "Ingresa la cantidad de oro (en piezas de oro) que deseas mantener en tu personaje. Déjalo en blanco para desactivar los movimientos automáticos hasta que indiques un valor. 0 = no mantener oro en el personaje.",
    ["GOLD"] = "oro",

    ["DEPOSIT_ENABLE"] = "Depositar Oro al Banco de la banda guerrera",
    ["DEPOSIT_ENABLE_DESC"] = "Cuando tengas más de la cantidad objetivo, deposita automáticamente el exceso a tu Banco de la banda guerrera.",

    ["WITHDRAW_ENABLE"] = "Retirar Oro del Banco de la banda guerrera",
    ["WITHDRAW_ENABLE_DESC"] = "Cuando tengas menos de la cantidad objetivo, retira automáticamente del Banco de la banda guerrera para alcanzar el objetivo.",

    ["ITEM_DEPOSIT"] = "Auto-Depósito de Objetos",
    ["ITEM_DEPOSIT_ENABLE"] = "Habilitar Auto-Depósito de Objetos",
    ["ITEM_DEPOSIT_ENABLE_DESC"] = "Deposita automáticamente objetos específicos a tu banco elegido al abrir el banco.",
    ["ITEM_DEPOSIT_LIST"] = "Lista de Objetos para Auto-Depósito",
    ["ITEM_DEPOSIT_ADD_PROMPT"] = "Ingresa el ID del objeto o shift-clic en un objeto para añadir:",
    ["ITEM_DEPOSIT_WARBAND"] = "Banda guerrera",
    ["ITEM_DEPOSIT_PERSONAL"] = "Personal",

    ["CLEAR"] = "Limpiar",


    ["MINIMAP_TOOLTIP_HINT"] = "Clic para alternar la configuración",

    ["ADDON_CHAT_PREFIX"] = "|cFFFFD100Direct Deposit:|r",
    ["DEPOSIT_NOW"] = "Depositar Ahora",

    ["TAB_KEYBINDS"] = "Atajos de Teclado",

    ["KEYBIND_SECTION"] = "Atajos de Añadido Rápido",
    ["KEYBIND_DESC"] = "Pasa el cursor sobre cualquier objeto y pulsa un atajo para añadirlo al instante a la lista de depósito. Asigna teclas en Menú del Juego > Asignación de Teclas > OneWoW Direct Deposit.",
    ["KEYBIND_ADD_PERSONAL"] = "Añadir Objeto Señalado - Banco Personal",
    ["KEYBIND_ADD_WARBAND"] = "Añadir Objeto Señalado - Banco de la banda guerrera",
    ["KEYBIND_ADD_GUILD"] = "Añadir Objeto Señalado - Banco de Hermandad",
    ["KEYBIND_NO_ITEM"] = "No se encontró ningún objeto - pasa primero el cursor sobre uno.",

    ["WARBOUND_SECTION"] = "Depósito Automático de la banda guerrera",
    ["WARBOUND_ENABLE"] = "Depositar Automáticamente Todos los Objetos de la banda guerrera",
    ["WARBOUND_ENABLE_DESC"] = "Al abrir cualquier banco, deposita automáticamente todos los objetos vinculados a la banda guerrera (vinculados a la cuenta) de tus bolsas en el Banco de la banda guerrera. Los objetos que ya estén en tu lista de depósito de arriba quedan excluidos.",

    ["WARBOUND_EXCLUDE_KEYWORD_LABEL"] = "Conservar por Palabra Clave",
    ["WARBOUND_EXCLUDE_KEYWORD_DESC"] = "Los objetos que coincidan con esta expresión de palabra clave se conservan en tus bolsas y nunca se depositan automáticamente. Usa palabras clave como #potion, #flask, #elixir, #consumable, separadas por | para \"o\". Ejemplo: #potion | #flask",
    ["WARBOUND_EXCLUDE_KEYWORD_PLACEHOLDER"] = "p. ej. #potion | #flask",
    ["WARBOUND_EXCLUDE_ITEMS_LABEL"] = "Conservar Objetos Específicos",
    ["WARBOUND_EXCLUDE_ITEMS_DESC"] = "Estos objetos siempre se conservan en tus bolsas, incluso si están vinculados a la banda guerrera. Arrastra un objeto aquí o introduce su ID de objeto.",

    ["TOOLTIP_SECTION"] = "Superposición de Información",
    ["TOOLTIP_ENABLE"] = "Mostrar Estado de Depósito en la Información",
    ["TOOLTIP_ENABLE_DESC"] = "Los objetos en cola para depósito mostrarán su banco de destino al final de su información.",
    ["TOOLTIP_LABEL"] = "Depositando:",
    ["TOOLTIP_PERSONAL"] = "Personal",
    ["TOOLTIP_WARBAND"] = "Banda guerrera",

    ["BINDING_HEADER_ONEWOW_DIRECTDEPOSIT"] = "|cFF00FF00OneWoW|r Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_TOGGLE"] = "Alternar Ventana de Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_DEPOSIT"] = "Depositar Objetos Ahora",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_PERSONAL"] = "Añadido Rápido: Banco Personal",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_WARBAND"] = "Añadido Rápido: Banco de la banda guerrera",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_GUILD"] = "Añadido Rápido: Banco de Hermandad",
})
