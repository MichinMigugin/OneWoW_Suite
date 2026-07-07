local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["MMSKIN_TITLE"] = "Strumenti mappa (mini)",
    ["MMSKIN_DESC"] = "Personalizza il blocco della minimappa: forma, bordo, testo della zona, orologio, azioni del clic, controlli dello zoom, visibilità degli elementi e altro. Compatibile con i temi e completamente configurabile.",

    ["MMSKIN_GROUP_SHAPE"] = "Forma e aspetto",
    ["MMSKIN_GROUP_INFO"] = "Sovrapposizioni informative",
    ["MMSKIN_GROUP_ZOOM"] = "Zoom e scorrimento",
    ["MMSKIN_GROUP_CLICKS"] = "Azioni del clic",
    ["MMSKIN_GROUP_ELEMENTS"] = "Visibilità degli elementi",
    ["MMSKIN_GROUP_EXTRAS"] = "Extra",
    ["MMSKIN_GROUP_COMPAT"] = "Compatibilità",

    ["MMSKIN_SQUARE"] = "Minimappa quadrata",
    ["MMSKIN_SQUARE_DESC"] = "Cambia la forma della minimappa da rotonda a quadrata. La disattivazione richiede il ricaricamento dell'interfaccia.",
    ["MMSKIN_BORDER"] = "Mostra bordo",
    ["MMSKIN_BORDER_DESC"] = "Mostra un bordo colorato attorno alla minimappa.",
    ["MMSKIN_CLASS_BORDER"] = "Bordo colore della classe",
    ["MMSKIN_CLASS_BORDER_DESC"] = "Usa il colore della tua classe per il bordo della minimappa invece del colore del tema.",
    ["MMSKIN_UNLOCK"] = "Sblocca minimappa",
    ["MMSKIN_UNLOCK_DESC"] = "Stacca la minimappa dalla posizione predefinita e la rende liberamente trascinabile.",
    ["MMSKIN_LOCK_POS"] = "Blocca posizione",
    ["MMSKIN_LOCK_POS_DESC"] = "Impedisce il trascinamento della minimappa mantenendola nella posizione attuale.",

    ["MMSKIN_ZONE_TEXT"] = "Testo della zona",
    ["MMSKIN_ZONE_TEXT_DESC"] = "Mostra il nome della zona attuale sopra la minimappa con colorazione di tipo PvP.",
    ["MMSKIN_CLOCK"] = "Orologio",
    ["MMSKIN_CLOCK_DESC"] = "Mostra un orologio sotto la minimappa. La descrizione mostra l'ora del reame/locale e i timer di azzeramento giornaliero/settimanale.",
    ["MMSKIN_CLASS_CLOCK_COLOR"] = "Orologio colore della classe",
    ["MMSKIN_CLASS_CLOCK_COLOR_DESC"] = "Usa il colore della tua classe per il testo dell'orologio invece del colore del tema.",
    ["MMSKIN_ZONE_ALIGN_LABEL"] = "Allineamento del nome della zona",
    ["MMSKIN_CLOCK_ALIGN_LABEL"] = "Allineamento dell'orologio",
    ["MMSKIN_ALIGN_LEFT"] = "Sinistra",
    ["MMSKIN_ALIGN_CENTER"] = "Centro",
    ["MMSKIN_ALIGN_RIGHT"] = "Destra",

    ["MMSKIN_ZONE_CLOCK_INSIDE"] = "Zona e orologio dentro la minimappa",
    ["MMSKIN_ZONE_CLOCK_INSIDE_DESC"] = "Ancora il nome della zona e l'orologio sui bordi interni della minimappa invece che sopra e sotto di essa.",

    ["MMSKIN_ZONE_CLOCK_DRAG"] = "Trascina zona e orologio (tieni premuto Maiusc)",
    ["MMSKIN_ZONE_CLOCK_DRAG_DESC"] = "Devi tenere premuto Maiusc mentre trascini il nome della zona o l'orologio per spostarli sullo schermo. Le posizioni vengono salvate. Rilascia Maiusc per i clic normali (l'orologio apre comunque la gestione del tempo).",

    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM"] = "Ancora zona e orologio alla minimappa",
    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM_DESC"] = "Quando il trascinamento è attivo, ancora il nome della zona e l'orologio alla minimappa così che la seguano quando viene spostata. Se li sovrapponi uno sull'altro, si muovono come uno solo.",

    ["MMSKIN_WHEEL_ZOOM"] = "Zoom con la rotellina",
    ["MMSKIN_WHEEL_ZOOM_DESC"] = "Ingrandisce e rimpicciolisce la minimappa con la rotellina del mouse.",
    ["MMSKIN_AUTO_ZOOM"] = "Rimpicciolimento automatico",
    ["MMSKIN_AUTO_ZOOM_DESC"] = "Rimpicciolisce automaticamente la minimappa dopo averla ingrandita.",

    ["MMSKIN_CLICK_ACTIONS"] = "Azioni del clic",
    ["MMSKIN_CLICK_ACTIONS_DESC"] = "Attiva le azioni di clic destro, clic centrale e pulsanti extra del mouse sulla minimappa.",

    ["MMSKIN_MAIL"] = "Indicatore posta",
    ["MMSKIN_MAIL_DESC"] = "Mostra l'indicatore della posta sulla minimappa.",
    ["MMSKIN_CRAFTING"] = "Ordini di creazione",
    ["MMSKIN_CRAFTING_DESC"] = "Mostra l'indicatore degli ordini di creazione sulla minimappa.",
    ["MMSKIN_DIFFICULTY"] = "Icona difficoltà",
    ["MMSKIN_DIFFICULTY_DESC"] = "Mostra l'icona della difficoltà dell'istanza sulla minimappa.",

    ["MMSKIN_TRACKING"] = "Filtro di tracciamento",
    ["MMSKIN_TRACKING_DESC"] = "Mostra il filtro di tracciamento della minimappa (menu a discesa risorse / erbe / minerali / ecc.). Disattivarlo rimuove il piccolo anello/controllo accanto alla minimappa.",
    ["MMSKIN_MISSIONS"] = "Pulsante missioni",
    ["MMSKIN_MISSIONS_DESC"] = "Mostra il pulsante della pagina dell'espansione / missioni.",
    ["MMSKIN_GAMETIME"] = "Icona calendario",
    ["MMSKIN_GAMETIME_DESC"] = "Mostra il pulsante del calendario (GameTime) sulla minimappa.",

    ["MMSKIN_PLUMBER_HIDE_BLIZZARD"] = "Nascondi il pulsante espansione doppione di Blizzard con Plumber",
    ["MMSKIN_PLUMBER_HIDE_BLIZZARD_DESC"] = "Quando Plumber è caricato, mantiene nascosto il pulsante espansione della minimappa di Blizzard così che venga mostrato solo il controllo Riepilogo Espansione di Plumber. Disattiva per mostrarli entrambi (non consigliato).",
    ["MMSKIN_PLUMBER_STATUS_ON"] = "Plumber è caricato — questa opzione è attiva.",
    ["MMSKIN_PLUMBER_STATUS_OFF"] = "Plumber non è caricato — attiva questa opzione prima di accedere, o ricarica dopo aver installato Plumber.",

    ["MMSKIN_HIDE_ADDONS"] = "Nascondi icone degli addon",
    ["MMSKIN_HIDE_ADDONS_DESC"] = "Nasconde i pulsanti degli addon sulla minimappa finché non passi il cursore sull'area della minimappa.",
    ["MMSKIN_COMBAT_FADE"] = "Dissolvenza in combattimento",
    ["MMSKIN_COMBAT_FADE_DESC"] = "Riduce l'opacità della minimappa durante il combattimento.",
    ["MMSKIN_PET_HIDE"] = "Nascondi durante le lotte tra mascotte",
    ["MMSKIN_PET_HIDE_DESC"] = "Nasconde la minimappa durante le lotte tra mascotte.",

    ["MMSKIN_SCALE_LABEL"] = "Scala del blocco della minimappa",
    ["MMSKIN_SECTION_BORDER"] = "Impostazioni del bordo",
    ["MMSKIN_BORDER_SIZE"] = "Dimensione del bordo",
    ["MMSKIN_BORDER_RED"] = "Rosso",
    ["MMSKIN_BORDER_GREEN"] = "Verde",
    ["MMSKIN_BORDER_BLUE"] = "Blu",
    ["MMSKIN_USE_THEME_COLOR"] = "Usa colore del tema",

    ["MMSKIN_ZONE_BG"] = "Sfondo della zona",
    ["MMSKIN_CLOCK_BG"] = "Sfondo dell'orologio",

    ["MMSKIN_AUTO_ZOOM_DELAY"] = "Ritardo del rimpicciolimento automatico",
    ["MMSKIN_SHOW_ZOOM_BTNS"] = "Mostra pulsanti dello zoom",

    ["MMSKIN_HIDE_WM_BTN"] = "Nascondi pulsante mappa del mondo",
    ["MMSKIN_HIDE_WM_BTN_DESC"] = "Nasconde il piccolo pulsante della mappa del mondo sulla minimappa (puoi comunque aprire la mappa con la sua scorciatoia).",

    ["MMSKIN_SECTION_COMBAT"] = "Impostazioni dissolvenza in combattimento",
    ["MMSKIN_COMBAT_ALPHA"] = "Opacità in combattimento",

    ["MMSKIN_SECTION_CLICKS"] = "Impostazioni assegnazione clic",
    ["MMSKIN_CLICK_RIGHT"] = "Clic destro",
    ["MMSKIN_CLICK_MIDDLE"] = "Clic centrale",
    ["MMSKIN_CLICK_BTN4"] = "Pulsante 4",
    ["MMSKIN_CLICK_BTN5"] = "Pulsante 5",
    ["MMSKIN_ACTION_NONE"] = "Nessuna",
    ["MMSKIN_ACTION_CALENDAR"] = "Calendario",
    ["MMSKIN_ACTION_TRACKING"] = "Tracciamento",
    ["MMSKIN_ACTION_MISSIONS"] = "Missioni",
    ["MMSKIN_ACTION_MAP"] = "Mappa",
    ["MMSKIN_WORLD_MAP_BUTTON"] = "Mappa del mondo",

    ["MMSKIN_SHOW_COMPARTMENT"] = "Scomparto degli addon",

    ["MMSKIN_CLOCK_TT_TOGGLE"] = "Clicca per aprire/chiudere la gestione del tempo",

    ["MMSKIN_UNCLAMP"] = "Sgancia dal bordo dello schermo",

    ["MMSKIN_ZONE_FONT_LABEL"] = "Carattere",
    ["MMSKIN_CLOCK_FONT_LABEL"] = "Carattere",
    ["MMSKIN_FONT_GLOBAL"] = "Carattere globale",
    ["MMSKIN_FONT_WOW_DEFAULT"] = "Predefinito di WoW (piccolo)",

    ["MMSKIN_SECTION_OPACITY"] = "Scala e opacità",
    ["MMSKIN_OPACITY"] = "Opacità della minimappa",

    ["MMSKIN_SECTION_DEBUG"] = "Strumenti per sviluppatori",
    ["MMSKIN_DEBUG_SHOW"] = "Mostra icone di debug",
    ["MMSKIN_DEBUG_HIDE"] = "Nascondi icone di debug",
    ["MMSKIN_DEBUG_DESC"] = "Forza la visibilità di tutte le icone tracciate con etichette colorate. Trascina un'etichetta per posizionare quell'icona sulla minimappa; le posizioni vengono salvate. Nascondi il debug per riportare le icone nel blocco (a meno che la minimappa non sia staccata). Utile quando le icone non si attivano da sole (es. nessuna posta nella cassetta).",
    ["MMSKIN_DEBUG_TT_DRAG_HINT"] = "Clic sinistro e trascina per spostare questa icona sulla minimappa.",
    ["MMSKIN_DEBUG_TT_POS_FMT"] = "Scostamento salvato: %.0f, %.0f",

    ["MMSKIN_RELOAD_PROMPT"] = "Cambiare la forma della minimappa richiede il ricaricamento dell'interfaccia.\nRicaricare ora?",
})
