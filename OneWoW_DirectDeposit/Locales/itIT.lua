local ADDON_NAME = ...

-- Machine-drafted — itIT, pending native review.
OneWoW.Locale:Register(ADDON_NAME, "itIT", {

    ["CTX_OPEN_DD"] = "Apri Deposito Diretto",
    ["ADDON_TITLE"] = "Deposito Diretto",
    ["ADDON_SUBTITLE"] = "Gestione Automatica dell'Oro della Banca della Brigata",


    ["TAB_GOLD"] = "Oro",

    ["DIRECT_DEPOSIT_TITLE"] = "Deposito Diretto",
    ["DIRECT_DEPOSIT_DESCRIPTION"] = "Gestisci automaticamente l'oro tra il tuo personaggio e la Banca della Brigata. Imposta un importo obiettivo da tenere sul personaggio e il sistema depositerà l'oro in eccesso o lo preleverà quando ne manca. Perfetto per gestire l'oro tra più personaggi.",
    ["DIRECT_DEPOSIT_ENABLE"] = "Attiva Deposito Diretto",
    ["DIRECT_DEPOSIT_ENABLE_DESC"] = "Deposita o preleva automaticamente l'oro dalla tua Banca della Brigata per mantenere un importo obiettivo sul personaggio quando apri la banca.",

    ["ACCOUNT_SETTINGS"] = "Impostazioni per Tutto l'Account",
    ["ACCOUNT_SETTINGS_DESC"] = "Queste impostazioni si applicano a tutti i personaggi del tuo account.",

    ["CHARACTER_SETTINGS"] = "Override Specifico del Personaggio",
    ["CHARACTER_SETTINGS_DESC"] = "Sostituisci le impostazioni per tutto l'account con impostazioni personalizzate per questo personaggio specifico. Utile per personaggi-banca o personaggi con esigenze speciali di gestione dell'oro.",

    ["USE_CHAR_SETTINGS"] = "Usa Impostazioni Specifiche del Personaggio",
    ["USE_CHAR_SETTINGS_DESC"] = "Attiva questa opzione per usare impostazioni diverse per questo personaggio invece di quelle per tutto l'account.",

    ["TARGET_GOLD"] = "Importo da Tenere sul Personaggio",
    ["TARGET_GOLD_DESC"] = "Inserisci la quantità di oro (in pezzi d'oro) che vuoi mantenere sul personaggio. Lascia vuoto per nessuno spostamento automatico di oro finché non lo imposti. Inserisci 0 per non tenere oro sul personaggio.",
    ["GOLD"] = "oro",

    ["DEPOSIT_ENABLE"] = "Deposita Oro nella Banca della Brigata",
    ["DEPOSIT_ENABLE_DESC"] = "Quando hai più dell'importo obiettivo, deposita automaticamente l'eccesso nella tua Banca della Brigata.",

    ["WITHDRAW_ENABLE"] = "Preleva Oro dalla Banca della Brigata",
    ["WITHDRAW_ENABLE_DESC"] = "Quando hai meno dell'importo obiettivo, preleva automaticamente dalla tua Banca della Brigata per raggiungere l'obiettivo.",

    ["ITEM_DEPOSIT"] = "Deposito Automatico Oggetti",
    ["ITEM_DEPOSIT_ENABLE"] = "Attiva Deposito Automatico Oggetti",
    ["ITEM_DEPOSIT_ENABLE_DESC"] = "Deposita automaticamente oggetti specifici nella banca scelta all'apertura della banca.",
    ["ITEM_DEPOSIT_LIST"] = "Lista Oggetti per Deposito Automatico",
    ["ITEM_DEPOSIT_ADD_PROMPT"] = "Inserisci l'ID dell'oggetto o shift-clicca un oggetto per aggiungerlo:",
    ["ITEM_DEPOSIT_WARBAND"] = "Brigata",
    ["ITEM_DEPOSIT_PERSONAL"] = "Personale",

    ["CLEAR"] = "Cancella",


    ["MINIMAP_TOOLTIP_HINT"] = "Clicca per aprire le impostazioni",

    ["ADDON_CHAT_PREFIX"] = "|cFFFFD100Direct Deposit:|r",
    ["DEPOSIT_NOW"] = "Deposita Ora",

    ["TAB_KEYBINDS"] = "Scorciatoie",

    ["KEYBIND_SECTION"] = "Scorciatoie di Aggiunta Rapida",
    ["KEYBIND_DESC"] = "Passa il cursore su un oggetto qualsiasi e premi una scorciatoia per aggiungerlo subito alla lista di deposito. Assegna i tasti in Menu di Gioco > Scorciatoie da Tastiera > OneWoW Direct Deposit.",
    ["KEYBIND_ADD_PERSONAL"] = "Aggiungi Oggetto sotto il Cursore - Banca Personale",
    ["KEYBIND_ADD_WARBAND"] = "Aggiungi Oggetto sotto il Cursore - Banca della Brigata",
    ["KEYBIND_ADD_GUILD"] = "Aggiungi Oggetto sotto il Cursore - Banca di Gilda",
    ["KEYBIND_NO_ITEM"] = "Nessun oggetto trovato - passa prima il cursore su un oggetto.",

    ["WARBOUND_SECTION"] = "Deposito Automatico Brigata",
    ["WARBOUND_ENABLE"] = "Deposita Automaticamente Tutti gli Oggetti della Brigata",
    ["WARBOUND_ENABLE_DESC"] = "All'apertura di qualsiasi banca, deposita automaticamente tutti gli oggetti legati alla brigata (legati all'account) dalle tue borse nella Banca della Brigata. Gli oggetti già presenti nella lista di deposito qui sopra vengono esclusi.",

    ["WARBOUND_EXCLUDE_KEYWORD_LABEL"] = "Mantieni per Parola Chiave",
    ["WARBOUND_EXCLUDE_KEYWORD_DESC"] = "Gli oggetti che corrispondono a questa espressione di parole chiave vengono mantenuti nelle tue borse e mai depositati automaticamente. Usa parole chiave come #potion, #flask, #elixir, #consumable, separate da | per \"o\". Esempio: #potion | #flask",
    ["WARBOUND_EXCLUDE_KEYWORD_PLACEHOLDER"] = "es. #potion | #flask",
    ["WARBOUND_EXCLUDE_ITEMS_LABEL"] = "Mantieni Oggetti Specifici",
    ["WARBOUND_EXCLUDE_ITEMS_DESC"] = "Questi oggetti vengono sempre mantenuti nelle tue borse, anche se legati alla brigata. Trascina qui un oggetto o inserisci il suo ID oggetto.",

    ["TOOLTIP_SECTION"] = "Sovrapposizione Descrizione",
    ["TOOLTIP_ENABLE"] = "Mostra Stato del Deposito nelle Descrizioni",
    ["TOOLTIP_ENABLE_DESC"] = "Gli oggetti in coda per il deposito mostreranno la banca di destinazione in fondo alla loro descrizione.",
    ["TOOLTIP_LABEL"] = "In deposito:",
    ["TOOLTIP_PERSONAL"] = "Personale",
    ["TOOLTIP_WARBAND"] = "Brigata",

    ["BINDING_HEADER_ONEWOW_DIRECTDEPOSIT"] = "|cFF00FF00OneWoW|r Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_TOGGLE"] = "Mostra/Nascondi Finestra Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_DEPOSIT"] = "Deposita Oggetti Ora",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_PERSONAL"] = "Aggiunta Rapida: Banca Personale",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_WARBAND"] = "Aggiunta Rapida: Banca della Brigata",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_GUILD"] = "Aggiunta Rapida: Banca di Gilda",
})
