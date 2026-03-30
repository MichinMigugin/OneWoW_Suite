local ADDON_NAME, OneWoW_DirectDeposit = ...

OneWoW_DirectDeposit.Locales = OneWoW_DirectDeposit.Locales or {}
OneWoW_DirectDeposit.Locales["esES"] = {
    ["ADDON_TITLE"] = "Depósito Directo",
    ["ADDON_SUBTITLE"] = "Gestión Automática de Oro del Banco de Grupo de Guerra",

    ["SETTINGS"] = "Configuración",
    ["STATUS"] = "Estado",
    ["ENABLED"] = "Habilitado",
    ["DISABLED"] = "Deshabilitado",

    ["TAB_GOLD"] = "Oro",
    ["TAB_ITEMS"] = "Objetos",
    ["TAB_SETTINGS"] = "Configuración",

    ["DIRECT_DEPOSIT_TITLE"] = "Depósito Directo",
    ["DIRECT_DEPOSIT_DESCRIPTION"] = "Gestiona automáticamente el oro entre tu personaje y el Banco de Grupo de Guerra. Establece una cantidad objetivo para mantener en tu personaje, y el sistema depositará el exceso de oro o retirará cuando te falte. Perfecto para gestionar oro entre múltiples personajes.",
    ["DIRECT_DEPOSIT_ENABLE"] = "Habilitar Depósito Directo",
    ["DIRECT_DEPOSIT_ENABLE_DESC"] = "Depositar o retirar oro automáticamente del Banco de Grupo de Guerra para mantener una cantidad objetivo en tu personaje cuando abras el banco.",

    ["ACCOUNT_SETTINGS"] = "Configuración de Cuenta",
    ["ACCOUNT_SETTINGS_DESC"] = "Esta configuración se aplica a todos los personajes de tu cuenta.",

    ["CHARACTER_SETTINGS"] = "Anulación Específica del Personaje",
    ["CHARACTER_SETTINGS_DESC"] = "Anula la configuración de la cuenta con configuración personalizada para este personaje específico. Útil para alts bancarios o personajes con necesidades especiales de gestión de oro.",

    ["USE_CHAR_SETTINGS"] = "Usar Configuración Específica del Personaje",
    ["USE_CHAR_SETTINGS_DESC"] = "Habilita esto para usar diferentes configuraciones para este personaje en lugar de la configuración de la cuenta.",

    ["TARGET_GOLD"] = "Cantidad a Mantener en el Personaje",
    ["TARGET_GOLD_DESC"] = "Ingresa la cantidad de oro (en piezas de oro) que deseas mantener en tu personaje.",
    ["GOLD"] = "oro",

    ["DEPOSIT_ENABLE"] = "Depositar Oro al Banco de Grupo de Guerra",
    ["DEPOSIT_ENABLE_DESC"] = "Cuando tengas más de la cantidad objetivo, deposita automáticamente el exceso a tu Banco de Grupo de Guerra.",

    ["WITHDRAW_ENABLE"] = "Retirar Oro del Banco de Grupo de Guerra",
    ["WITHDRAW_ENABLE_DESC"] = "Cuando tengas menos de la cantidad objetivo, retira automáticamente del Banco de Grupo de Guerra para alcanzar el objetivo.",

    ["ITEM_DEPOSIT"] = "Auto-Depósito de Objetos",
    ["ITEM_DEPOSIT_ENABLE"] = "Habilitar Auto-Depósito de Objetos",
    ["ITEM_DEPOSIT_ENABLE_DESC"] = "Deposita automáticamente objetos específicos a tu banco elegido al abrir el banco.",
    ["ITEM_DEPOSIT_LIST"] = "Lista de Objetos para Auto-Depósito",
    ["ITEM_DEPOSIT_ADD"] = "Añadir Objeto",
    ["ITEM_DEPOSIT_ADD_PROMPT"] = "Ingresa el ID del objeto o shift-clic en un objeto para añadir:",
    ["ITEM_DEPOSIT_REMOVE"] = "Eliminar",
    ["ITEM_DEPOSIT_WARBAND"] = "Grupo de Guerra",
    ["ITEM_DEPOSIT_PERSONAL"] = "Personal",
    ["ITEM_DEPOSIT_GUILD"] = "Hermandad",

    ["OK"] = "OK",
    ["CLOSE"] = "Cerrar",
    ["CLEAR"] = "Limpiar",
    ["CANCEL"] = "Cancelar",

    ["LANGUAGE_SELECTION"] = "Selección de Idioma",
    ["CURRENT_LANGUAGE"] = "Idioma Actual",
    ["SELECT_LANGUAGE"] = "Seleccionar Idioma",
    ["LANGUAGE_DESC"] = "Elige tu idioma preferido para la interfaz del addon. Los cambios se aplican instantáneamente.",
    ["ENGLISH"] = "English",
    ["SPANISH"] = "Español",
    ["KOREAN"] = "한국어",
    ["FRENCH"] = "Français",
    ["RUSSIAN"] = "Русский",
    ["GERMAN"] = "Deutsch",

    ["ABOUT_SECTION"] = "Acerca de Depósito Directo",
    ["ABOUT_TEXT"] = "Depósito Directo es un addon de calidad de vida del conjunto OneWoW. Este addon también está disponible como parte del conjunto completo OneWoW Suite, que incluye muchos otros addons útiles para mejorar tu experiencia en World of Warcraft. ¡Descubre más addons que pueden ayudarte a organizar tus aventuras y mejorar tu juego!",

    ["LINKS_SECTION"] = "Soporte y Comunidad",
    ["DISCORD_LABEL"] = "Únete a nuestra comunidad de Discord",
    ["DISCORD_URL"] = "https://discord.gg/wownotes",
    ["WEBSITE_LABEL"] = "Visita nuestro sitio web para soporte",
    ["WEBSITE_URL"] = "https://wow2.xyz/",
    ["COPY_HINT"] = "Haz clic para seleccionar, luego Ctrl+C para copiar",

    ["THEME_SECTION"] = "Tema de Color",
    ["THEME_DESC"] = "Elige un tema de color para la interfaz del addon. Los cambios se aplican instantáneamente sin recargar.",
    ["THEME_CURRENT"] = "Tema Actual",
    ["THEME_GREEN"] = "Verde Bosque",
    ["THEME_BLUE"] = "Azul Océano",
    ["THEME_PURPLE"] = "Púrpura Real",
    ["THEME_GOLD"] = "Oro Clásico",
    ["THEME_SLATE"] = "Gris Pizarra",
    ["THEME_ORANGE"] = "Naranja Atardecer",
    ["THEME_TEAL"] = "Verde Azulado Místico",
    ["THEME_CYAN"] = "Cian Ártico",
    ["THEME_PINK"] = "Rosa Rosado",
    ["THEME_DARK"] = "Oscuro Medianoche",
    ["THEME_AMBER"] = "Fuego Ámbar",

}

OneWoW_DirectDeposit.Locales["esMX"] = OneWoW_DirectDeposit.Locales["esES"]
