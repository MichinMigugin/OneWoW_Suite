local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["MAPWORLD_TITLE"] = "Strumenti mappa (mondo)",
    ["MAPWORLD_DESC"] = "Mappa del mondo: rivela il terreno inesplorato dai dati del client, tinte opzionali, modifiche alla mappa del campo di battaglia, coordinate e piccole opzioni di comodità/pulizia.",

    ["MAPWORLD_GROUP_EXPLORE"] = "Esplorazione (grafica della mappa)",
    ["MAPWORLD_GROUP_FOGOVERLAY"] = "Sovrapposizione nebbia (strato scuro)",
    ["MAPWORLD_GROUP_FRAME"] = "Finestra della mappa",
    ["MAPWORLD_GROUP_COMFORT"] = "Comodità",
    ["MAPWORLD_GROUP_CLEANUP"] = "Pulizia",
    ["MAPWORLD_GROUP_COORDS"] = "Coordinate",
    ["MAPWORLD_GROUP_POI"] = "Punti d'interesse",
    ["MAPWORLD_GROUP_BATTLE"] = "Mappa del campo di battaglia",
    ["MAPWORLD_GROUP_POLISH"] = "Rifinitura",
    ["MAPWORLD_GROUP_CANVAS"] = "Sovrapposizione mappa intera",
    ["MAPWORLD_GROUP_MAP"] = "Finestra della mappa del mondo",

    ["MAPWORLD_REVEAL_MAP"] = "Mostra aree inesplorate",
    ["MAPWORLD_REVEAL_MAP_DESC"] = "Disegna le tessere di esplorazione mancanti usando i dati grafici della mappa inclusi (stessa idea della rivelazione della mappa cartacea). Funziona sulle mappe del mondo e del campo di battaglia.",

    ["MAPWORLD_TINT_UNEXPLORED"] = "Tinteggia aree inesplorate",
    ["MAPWORLD_TINT_UNEXPLORED_DESC"] = "Applica una tinta colorata alle tessere rivelate dall'opzione sopra (solo mappe di zona).",

    ["MAPWORLD_UNEX_R"] = "Inesplorato rosso",
    ["MAPWORLD_UNEX_G"] = "Inesplorato verde",
    ["MAPWORLD_UNEX_B"] = "Inesplorato blu",
    ["MAPWORLD_UNEX_A"] = "Opacità inesplorato",

    ["MAPWORLD_REMOVE_FOG"] = "Nascondi strato di nebbia scura",
    ["MAPWORLD_REMOVE_FOG_DESC"] = "Nasconde il frame della nebbia di guerra di Blizzard sopra la mappa (separato dal disegno della grafica di esplorazione mancante).",

    ["MAPWORLD_FOG_TINT"] = "Tinteggia strato di nebbia (NdG)",
    ["MAPWORLD_FOG_TINT_DESC"] = "Quando lo strato di nebbia scura è visibile, ne moltiplica il colore.",

    ["MAPWORLD_CLEAR_BLACKOUT"] = "Mondo cliccabile dietro la mappa",
    ["MAPWORLD_CLEAR_BLACKOUT_DESC"] = "Rende l'«oscuramento» attenuato dietro la mappa trasparente e non bloccante per i clic, così da vedere chiaramente il mondo.",

    ["MAPWORLD_NO_MAP_FADE"] = "Disattiva dissolvenza mappa in movimento",
    ["MAPWORLD_NO_MAP_FADE_DESC"] = "Imposta mapFade affinché la mappa non diventi semitrasparente quando il personaggio si muove.",

    ["MAPWORLD_NO_MAP_EMOTE"] = "Disattiva emote di lettura",
    ["MAPWORLD_NO_MAP_EMOTE_DESC"] = "Annulla l'emote di lettura all'apertura della mappa.",

    ["MAPWORLD_HIDE_FILTER_RESET"] = "Nascondi IU di reimpostazione filtri",
    ["MAPWORLD_HIDE_FILTER_RESET_DESC"] = "Nasconde il controllo di reimpostazione dei filtri della mappa del mondo e i relativi banner contatore.",

    ["MAPWORLD_HIDE_MAP_TUTORIAL"] = "Sopprimi tutorial della mappa",
    ["MAPWORLD_HIDE_MAP_TUTORIAL_DESC"] = "Nasconde il frame del tutorial della mappa del mondo e lo segna come chiuso nei frame informativi.",

    ["MAPWORLD_SHOW_COORDS"] = "Mostra coordinate",
    ["MAPWORLD_SHOW_COORDS_DESC"] = "Mostra la posizione del cursore e del giocatore nella finestra della mappa.",

    ["MAPWORLD_COORDS_LARGE"] = "Carattere coordinate grande",
    ["MAPWORLD_COORDS_LARGE_DESC"] = "Usa un carattere più grande per la lettura delle coordinate.",

    ["MAPWORLD_COORDS_BG"] = "Sfondo della barra delle coordinate",
    ["MAPWORLD_COORDS_BG_DESC"] = "Mostra una striscia scura dietro il testo delle coordinate.",

    ["MAPWORLD_HIDE_CONTINENT_POI"] = "Nascondi punti d'interesse cittadini sui continenti",
    ["MAPWORLD_HIDE_CONTINENT_POI_DESC"] = "Nasconde determinati segnaposto di dimora, fazione e città nelle viste dei continenti e della mappa del mondo.",

    ["MAPWORLD_ENHANCE_BATTLE_MAP"] = "Migliora mappa del campo di battaglia",
    ["MAPWORLD_ENHANCE_BATTLE_MAP_DESC"] = "Mostra il gruppo sulla mappa del campo di battaglia e attiva le opzioni qui sotto.",

    ["MAPWORLD_UNLOCK_BATTLEFIELD"] = "Trascina per spostare la mappa del campo di battaglia",
    ["MAPWORLD_UNLOCK_BATTLEFIELD_DESC"] = "Trascina la mappa del campo di battaglia dalla sua area interna.",

    ["MAPWORLD_BATTLE_CENTER"] = "Mantieni la mappa del campo di battaglia centrata sul giocatore",
    ["MAPWORLD_BATTLE_CENTER_DESC"] = "Ricentra la mappa del campo di battaglia sulla tua posizione. Tieni premuto Maiusc mentre trascini per mettere in pausa.",

    ["MAPWORLD_BATTLE_OPACITY"] = "Visibilità della mappa del campo di battaglia",
    ["MAPWORLD_BATTLE_GROUP"] = "Dimensione icone del gruppo",
    ["MAPWORLD_BATTLE_PLAYER"] = "Dimensione freccia del giocatore",

    ["MAPWORLD_TINT_MENU"] = "Interruttore tinta del menu mappa del mondo",
    ["MAPWORLD_TINT_MENU_DESC"] = "Aggiunge una casella «Tinteggia inesplorate» al menu di tracciamento della mappa (potrebbe non caricarsi se l'API del menu cambia).",

    ["MAPWORLD_CANVAS_TINT"] = "Sovrapposizione colore mappa intera",
    ["MAPWORLD_CANVAS_TINT_DESC"] = "Tinteggia l'intera area della mappa con un colore traslucido (separato dalla tinta di esplorazione).",

    ["MAPWORLD_MAP_ALPHA"] = "Opacità della mappa del mondo",
    ["MAPWORLD_MAP_ALPHA_DESC"] = "Riduce l'opacità dell'intera finestra della mappa del mondo (alfa del frame).",

    ["MAPWORLD_MAP_ALPHA_SLIDER"] = "Opacità della finestra della mappa",
    ["MAPWORLD_RED"] = "Rosso",
    ["MAPWORLD_GREEN"] = "Verde",
    ["MAPWORLD_BLUE"] = "Blu",

    ["MAPWORLD_CURSOR"] = "Cursore",
})
